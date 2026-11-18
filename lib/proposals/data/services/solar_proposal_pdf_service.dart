import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../settings/data/services/solar_settings_service.dart';
import '../../../settings/domain/models/solar_settings_model.dart';
import '../../../settings/domain/models/proposal_pages_models.dart';
import '../../../solar_designer/data/repositories/roof_study_repository.dart';
import '../../../solar_designer/domain/models/roof_study_model.dart';
import '../../domain/models/proposal_item_model.dart';
import '../../domain/models/proposal_model.dart';
import 'cover_divider_svg_builder.dart';

class SolarProposalPdfService {
  static final _currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  static final _numberFormat = NumberFormat.decimalPattern('pt_BR');
  static Uint8List? _cachedPage3HouseBytes;

  /// Faz upload do PDF da proposta no Firebase Storage na estrutura: propostas_mavis/{companyId}/{userId}/{fileName}
  static Future<String?> uploadProposalPdfToStorage({
    required Uint8List pdfBytes,
    required ProposalModel proposal,
  }) async {
    try {
      final companyId = proposal.companyId != null && proposal.companyId!.isNotEmpty
          ? proposal.companyId!
          : 'default_company';
      final userId = proposal.createdByUserId != null && proposal.createdByUserId!.isNotEmpty
          ? proposal.createdByUserId!
          : 'default_user';
      final cleanPropNumber = proposal.proposalNumber.replaceAll('/', '_').replaceAll('-', '_');
      final fileName = 'proposta_${cleanPropNumber}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final storagePath = 'propostas_mavis/$companyId/$userId/$fileName';

      final ref = FirebaseStorage.instance.ref().child(storagePath);
      final metadata = SettableMetadata(
        contentType: 'application/pdf',
        customMetadata: {
          'proposalId': proposal.id,
          'proposalNumber': proposal.proposalNumber,
          'companyId': companyId,
          'clientName': proposal.clientName,
          'totalAmount': proposal.totalAmount.toString(),
        },
      );

      final uploadTask = await ref.putData(pdfBytes, metadata);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      // Grava a URL gerada no Firestore dentro do documento da proposta
      await FirebaseFirestore.instance.collection('proposals').doc(proposal.id).update({
        'pdfUrl': downloadUrl,
        'pdfGeneratedAt': FieldValue.serverTimestamp(),
      });

      return downloadUrl;
    } catch (e) {
      return null;
    }
  }

  /// Helper para obter fontes do Google Fonts no PDF
  static Future<pw.Font?> _getPdfFont(String family, {bool isBlack = false, bool isBold = false}) async {
    try {
      switch (family.toLowerCase()) {
        case 'roboto':
          return isBlack || isBold ? await PdfGoogleFonts.robotoBold() : await PdfGoogleFonts.robotoRegular();
        case 'inter':
          return isBlack || isBold ? await PdfGoogleFonts.interBold() : await PdfGoogleFonts.interRegular();
        case 'oswald':
          return isBlack || isBold ? await PdfGoogleFonts.oswaldBold() : await PdfGoogleFonts.oswaldRegular();
        case 'poppins':
          return isBlack || isBold ? await PdfGoogleFonts.poppinsBold() : await PdfGoogleFonts.poppinsRegular();
        case 'montserrat':
        default:
          if (isBlack) return await PdfGoogleFonts.montserratBlack();
          if (isBold) return await PdfGoogleFonts.montserratBold();
          return await PdfGoogleFonts.montserratRegular();
      }
    } catch (_) {
      return null;
    }
  }

  /// Gera o arquivo PDF completo da proposta solar comercial com suporte dinâmico a estudo de telhado vinculado
  static Future<Uint8List> generateSolarProposalPdf(
    ProposalModel proposal, {
    SolarSettingsModel? solarSettings,
    RoofStudyModel? roofStudy,
    bool autoUploadToStorage = false,
  }) async {
    final pdf = pw.Document();
    final settings = solarSettings ?? await SolarSettingsService.loadSettings(companyId: proposal.companyId);
    final primaryColor = PdfColor.fromInt(settings.themeColorValue);
    final secondaryColor = PdfColor.fromInt(settings.secondaryThemeColorValue);

    // Resolve Estudo de Telhado & Sombreamento vinculado (se existir)
    RoofStudyModel? effectiveStudy = roofStudy ?? proposal.linkedRoofStudy;
    String? studyIdToLoad = proposal.roofStudyId;
    if ((studyIdToLoad == null || studyIdToLoad.isEmpty) && effectiveStudy == null) {
      for (final item in proposal.items) {
        if (item.roofStudyId != null && item.roofStudyId!.isNotEmpty) {
          studyIdToLoad = item.roofStudyId;
          break;
        }
      }
    }
    if (effectiveStudy == null && studyIdToLoad != null && studyIdToLoad.isNotEmpty) {
      try {
        effectiveStudy = await RoofStudyRepository().getStudyById(studyIdToLoad);
      } catch (_) {}
    }

    // Carrega fotos completas do estudo caso necessário
    List<RoofStudyPhoto> effectivePhotos = [];
    if (effectiveStudy != null) {
      if (effectiveStudy.id.isNotEmpty) {
        try {
          final subPhotos = await RoofStudyRepository().getStudyPhotos(effectiveStudy.id);
          if (subPhotos.isNotEmpty) {
            effectivePhotos = subPhotos;
          }
        } catch (_) {}
      }
      if (effectivePhotos.isEmpty) {
        effectivePhotos = effectiveStudy.studyPhotos.where((p) => p.imageBase64.isNotEmpty).toList();
      }
    }

    final hiddenPages = settings.hiddenPageIds;
    final customPages = settings.customPages;

    final int studyPagesCount = (effectiveStudy != null && !hiddenPages.contains('page_4')) ? (1 + effectivePhotos.length) : 0;
    int totalPages = 1; // page_1 (Capa)
    if (!hiddenPages.contains('page_2')) totalPages++;
    if (!hiddenPages.contains('page_3')) totalPages++;
    totalPages += studyPagesCount;
    if (!hiddenPages.contains('page_5')) totalPages++; // Itens da Usina
    if (!hiddenPages.contains('page_6')) totalPages++; // Análise Financeira
    if (!hiddenPages.contains('page_7')) totalPages++; // Financiamento
    for (final cp in customPages) {
      if (!hiddenPages.contains(cp.id)) totalPages++;
    }

    int curPage = 1;

    // Carrega fontes Montserrat e fontes customizadas oficiais via PdfGoogleFonts
    pw.Font? fontMontserratBlack;
    pw.Font? fontMontserratBold;
    pw.Font? fontMontserratSemiBold;
    pw.Font? headlineFontBold;
    pw.Font? headlineFontBlack;
    pw.Font? rightBlockFontBold;
    pw.Font? rightBlockFontBlack;
    pw.Font? footerFontBold;
    try {
      fontMontserratBlack = await PdfGoogleFonts.montserratBlack();
      fontMontserratBold = await PdfGoogleFonts.montserratBold();
      fontMontserratSemiBold = await PdfGoogleFonts.montserratSemiBold();
      headlineFontBold = await _getPdfFont(settings.coverHeadlineFont, isBold: true);
      headlineFontBlack = await _getPdfFont(settings.coverHeadlineFont, isBlack: true);
      rightBlockFontBold = await _getPdfFont(settings.coverRightBlockFont, isBold: true);
      rightBlockFontBlack = await _getPdfFont(settings.coverRightBlockFont, isBlack: true);
      footerFontBold = await _getPdfFont(settings.coverFooterFont, isBold: true);
    } catch (_) {}

    // Carrega a imagem da capa (Custom Base64 / Firebase Storage / Web Background)
    Uint8List? coverImageBytes;

    // 1. Foto customizada da empresa (upload)
    if (settings.customCoverImageBase64 != null && settings.customCoverImageBase64!.isNotEmpty) {
      try {
        final clean = settings.customCoverImageBase64!.contains(',')
            ? settings.customCoverImageBase64!.split(',').last
            : settings.customCoverImageBase64!;
        coverImageBytes = base64Decode(clean);
      } catch (_) {}
    }

    // 2. Capa oficial selecionada no catálogo (selectedCoverTemplate)
    if (coverImageBytes == null && settings.selectedCoverTemplate.isNotEmpty) {
      try {
        coverImageBytes = await SolarSettingsService.fetchCoverBytes(settings.selectedCoverTemplate);
      } catch (_) {}
      if (coverImageBytes == null) {
        try {
          coverImageBytes = await SolarSettingsService.fetchWebBackgroundBytes(settings.selectedCoverTemplate);
        } catch (_) {}
      }
    }

    // 3. Template de Wallpaper Web configurado (webBackgroundTemplate)
    if (coverImageBytes == null && settings.webBackgroundTemplate.isNotEmpty) {
      try {
        coverImageBytes = await SolarSettingsService.fetchCoverBytes(settings.webBackgroundTemplate);
      } catch (_) {}
      if (coverImageBytes == null) {
        try {
          coverImageBytes = await SolarSettingsService.fetchWebBackgroundBytes(settings.webBackgroundTemplate);
        } catch (_) {}
      }
    }

    // 4. Fallback padrão garantido
    if (coverImageBytes == null) {
      try {
        coverImageBytes = await SolarSettingsService.fetchCoverBytes('modelo_proposta_1.jpg');
      } catch (_) {}
      if (coverImageBytes == null) {
        final bgs = SolarSettingsService.getDefaultWebBackgroundList();
        if (bgs.isNotEmpty) {
          try {
            coverImageBytes = await SolarSettingsService.fetchWebBackgroundBytes(bgs.first);
          } catch (_) {}
        }
      }
    }

    // Extrai dados da usina da proposta
    final solarPlantItem = proposal.items.firstWhere(
      (item) => item.isSolarPlant,
      orElse: () => proposal.items.isNotEmpty
          ? proposal.items.first
          : ProposalItemModel(name: 'Usina Solar', quantity: 1, unitPrice: proposal.totalAmount, totalPrice: proposal.totalAmount),
    );

    final kwp = solarPlantItem.solarPowerKwp ?? (proposal.totalAmount > 0 ? (proposal.totalAmount / 2300.0) : 8.68);
    final generationMonthly = (kwp * 115.2).clamp(100.0, 50000.0);
    final generationDaily = generationMonthly / 30.0;
    final roofType = solarPlantItem.solarRoofType ?? 'Cerâmica';

    // Identifica módulos e inversores nos componentes
    final components = solarPlantItem.solarComponents ?? [];
    int modulesCount = 0;
    int moduleWatts = 620;
    String inverterModel = 'Inversor Solar Grid-Tie';
    double inverterKw = (kwp * 0.75).clamp(3.0, 100.0);

    for (final compStr in components) {
      final comp = compStr.trim();
      final lowerName = comp.toLowerCase();

      int compQty = 1;
      final qtyMatch = RegExp(r'^(\d+)\s*(?:x|un|unid)?\b', caseSensitive: false).firstMatch(comp);
      if (qtyMatch != null) {
        compQty = int.tryParse(qtyMatch.group(1)!) ?? 1;
      }

      if (lowerName.contains('modulo') ||
          lowerName.contains('módulo') ||
          lowerName.contains('placa') ||
          lowerName.contains('painel') ||
          lowerName.contains('bifacial')) {
        modulesCount += compQty;
        final matchW = RegExp(r'(\d{3,4})\s*(?:w|watts|wp)\b', caseSensitive: false).firstMatch(comp);
        if (matchW != null) {
          moduleWatts = int.tryParse(matchW.group(1)!) ?? 620;
        }
      } else if (lowerName.contains('inversor') || lowerName.contains('microinversor')) {
        inverterModel = comp;
        final matchK = RegExp(r'(\d+(?:[\.,]\d+)?)\s*kw\b', caseSensitive: false).firstMatch(comp);
        if (matchK != null) {
          inverterKw = double.tryParse(matchK.group(1)!.replaceAll(',', '.')) ?? inverterKw;
        }
      }
    }

    if (modulesCount == 0) {
      modulesCount = ((kwp * 1000) / moduleWatts).round();
      if (modulesCount <= 0) modulesCount = 14;
    }

    final occupiedArea = modulesCount * 2.6; // m² médio por módulo comercial

    // ─────────────────────────────────────────────────────────────────────────
    // PÁGINA 1: CAPA COM O TEMPLATE DO FIREBASE STORAGE
    // ─────────────────────────────────────────────────────────────────────────
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (context) => _buildCoverPage(
          coverBytes: coverImageBytes,
          proposal: proposal,
          settings: settings,
          generationMonthly: generationMonthly,
          kwp: kwp,
          primaryColor: primaryColor,
          fontMontserratBlack: fontMontserratBlack,
          fontMontserratBold: fontMontserratBold,
          fontMontserratSemiBold: fontMontserratSemiBold,
          headlineFontBold: headlineFontBold,
          headlineFontBlack: headlineFontBlack,
          rightBlockFontBold: rightBlockFontBold,
          rightBlockFontBlack: rightBlockFontBlack,
          footerFontBold: footerFontBold,
        ),
      ),
    );

    // Capa (Página 1)
    curPage++;

    // ─────────────────────────────────────────────────────────────────────────
    // PÁGINA 2: PROPOSTA COMERCIAL & ESCOPO DO PROJETO
    // ─────────────────────────────────────────────────────────────────────────
    if (!hiddenPages.contains('page_2')) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (context) => _buildProgrammaticPageLayout(
            pageTitle: 'PROPOSTA COMERCIAL',
            pageNumber: curPage++,
            totalPages: totalPages,
            primaryColor: primaryColor,
            settings: settings,
            proposal: proposal,
            content: _buildPage2Content(
              primaryColor,
              customCards: settings.page2Cards,
              showIllustration: settings.page2ShowIllustration,
            ),
          ),
        ),
      );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // PÁGINA 3: SUA USINA (FICHA TÉCNICA)
    // ─────────────────────────────────────────────────────────────────────────
    if (!hiddenPages.contains('page_3')) {
      if (_cachedPage3HouseBytes == null) {
        try {
          final bd = await rootBundle.load('assets/images/solar_page3_house.jpg');
          _cachedPage3HouseBytes = bd.buffer.asUint8List();
        } catch (_) {}
      }

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (context) => _buildProgrammaticPageLayout(
            pageTitle: 'SUA USINA SOLAR',
            pageNumber: curPage++,
            totalPages: totalPages,
            primaryColor: primaryColor,
            settings: settings,
            proposal: proposal,
            fullBleedContent: true,
            content: _buildPage3Content(
              kwp: kwp,
              modulesCount: modulesCount,
              moduleWatts: moduleWatts,
              inverterModel: inverterModel,
              inverterKw: inverterKw,
              roofType: roofType,
              generationMonthly: generationMonthly,
              occupiedArea: occupiedArea,
              primaryColor: primaryColor,
              secondaryColor: secondaryColor,
              houseImageBytes: _cachedPage3HouseBytes,
            ),
          ),
        ),
      );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // ESTUDO SOLAR DE TELHADO & SOMBREAMENTO (SE VINCULADO)
    // INSERIDO EXATAMENTE ANTES DA PÁGINA "ITENS DA USINA & PAGAMENTO"
    // COM CABEÇALHO E RODAPÉ PADRONIZADOS DA PROPOSTA
    // ─────────────────────────────────────────────────────────────────────────
    if (effectiveStudy != null && !hiddenPages.contains('page_4')) {
      // 1. Folha do Estudo Técnico de Telhado & Sombreamento
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (context) => _buildProgrammaticPageLayout(
            pageTitle: 'ESTUDO DE TELHADO & SOMBREAMENTO',
            pageNumber: curPage++,
            totalPages: totalPages,
            primaryColor: primaryColor,
            settings: settings,
            proposal: proposal,
            content: _buildStudySummaryPageContent(
              study: effectiveStudy!,
              primaryColor: primaryColor,
              settings: settings,
              photos: effectivePhotos,
            ),
          ),
        ),
      );

      // 2. Folhas Individuais Dedicadas para Cada Foto da Simulação Solar
      for (int i = 0; i < effectivePhotos.length; i++) {
        final photo = effectivePhotos[i];
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: pw.EdgeInsets.zero,
            build: (context) => _buildProgrammaticPageLayout(
              pageTitle: 'SIMULAÇÃO SOLAR • ${_formatHour(photo.hourOfDay)}',
              pageNumber: curPage++,
              totalPages: totalPages,
              primaryColor: primaryColor,
              settings: settings,
              proposal: proposal,
              content: _buildStudyPhotoPageContent(
                photo: photo,
                study: effectiveStudy!,
                primaryColor: primaryColor,
                settings: settings,
              ),
            ),
          ),
        );
      }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // PÁGINA: ITENS DA USINA & FORMA DE PAGAMENTO
    // ─────────────────────────────────────────────────────────────────────────
    if (!hiddenPages.contains('page_5')) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (context) => _buildProgrammaticPageLayout(
            pageTitle: 'ITENS DA USINA & PAGAMENTO',
            pageNumber: curPage++,
            totalPages: totalPages,
            primaryColor: primaryColor,
            settings: settings,
            proposal: proposal,
            fullBleedContent: true,
            content: _buildPage4Content(
              proposal: proposal,
              solarPlantItem: solarPlantItem,
              primaryColor: primaryColor,
              secondaryColor: secondaryColor,
              modulesCount: modulesCount,
              moduleWatts: moduleWatts,
              inverterModel: inverterModel,
              inverterKw: inverterKw,
              roofType: roofType,
            ),
          ),
        ),
      );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // PÁGINA: ANÁLISE DE INVESTIMENTO & TABELA DE 20 ANOS
    // ─────────────────────────────────────────────────────────────────────────
    if (!hiddenPages.contains('page_6')) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (context) => _buildProgrammaticPageLayout(
            pageTitle: 'ANÁLISE DE INVESTIMENTO',
            pageNumber: curPage++,
            totalPages: totalPages,
            primaryColor: primaryColor,
            settings: settings,
            proposal: proposal,
            fullBleedContent: true,
            content: _buildPage5Content(
              proposal: proposal,
              settings: settings,
              generationMonthly: generationMonthly,
              generationDaily: generationDaily,
              kwp: kwp,
              primaryColor: primaryColor,
              secondaryColor: secondaryColor,
            ),
          ),
        ),
      );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // PÁGINA: FINANCIAMENTO BANCÁRIO & CARTÃO DE CRÉDITO
    // ─────────────────────────────────────────────────────────────────────────
    if (!hiddenPages.contains('page_7')) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (context) => _buildProgrammaticPageLayout(
            pageTitle: 'FINANCIAMENTO & CONDIÇÕES',
            pageNumber: curPage++,
            totalPages: totalPages,
            primaryColor: primaryColor,
            settings: settings,
            proposal: proposal,
            fullBleedContent: true,
            content: _buildPage6Content(
              proposal: proposal,
              settings: settings,
              primaryColor: primaryColor,
              secondaryColor: secondaryColor,
            ),
          ),
        ),
      );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // PÁGINAS PERSONALIZADAS DO USUÁRIO
    // ─────────────────────────────────────────────────────────────────────────
    for (final cp in customPages) {
      if (!hiddenPages.contains(cp.id)) {
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: pw.EdgeInsets.zero,
            build: (context) => _buildProgrammaticPageLayout(
              pageTitle: cp.title.toUpperCase(),
              pageNumber: curPage++,
              totalPages: totalPages,
              primaryColor: primaryColor,
              settings: settings,
              proposal: proposal,
              content: _buildCustomPageContent(cp, primaryColor),
            ),
          ),
        );
      }
    }

    final bytes = await pdf.save();
    if (autoUploadToStorage) {
      // Faz upload do PDF em background para o Firebase Storage na pasta proposals/companyId/userId/
      uploadProposalPdfToStorage(pdfBytes: bytes, proposal: proposal);
    }
    return bytes;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // CONSTRUÇÃO DA CAPA (PÁGINA 1)
  // ───────────────────────────────────────────────────────────────────────────
  /// Constrói a Capa Corporate Wave no padrão editorial A4 com ondas, pontilhados e janela fluida para Energia Solar
  static pw.Widget _buildCorporateWavePdfCover({
    required Uint8List? coverBytes,
    required ProposalModel proposal,
    required SolarSettingsModel settings,
    required double generationMonthly,
    required double kwp,
    pw.Font? fontMontserratBlack,
    pw.Font? fontMontserratBold,
    pw.Font? fontMontserratSemiBold,
  }) {
    final primaryHex = (settings.verticalSplitAccentColor.isNotEmpty ? settings.verticalSplitAccentColor : '#0284C7')
        .replaceAll('#', '')
        .trim();
    final primarySvgColor = '#$primaryHex';
    final primaryPdfColor = PdfColor.fromInt(settings.verticalSplitAccentColorValue);

    final secondaryHex = (settings.coverTitleColor.isNotEmpty ? settings.coverTitleColor : '#38BDF8')
        .replaceAll('#', '')
        .trim();
    final secondarySvgColor = '#$secondaryHex';

    Uint8List? logoBytes;
    if (settings.coverShowLogo && settings.companyLogoBase64 != null && settings.companyLogoBase64!.isNotEmpty) {
      try {
        final cleanLogo = settings.companyLogoBase64!.contains(',')
            ? settings.companyLogoBase64!.split(',').last
            : settings.companyLogoBase64!;
        logoBytes = base64Decode(cleanLogo);
      } catch (_) {}
    }

    final svgOverlay = '''
<svg viewBox="0 0 595.28 841.89" width="595.28" height="841.89" xmlns="http://www.w3.org/2000/svg">
  <path d="M 0 0 L 310 0 C 275 100 190 185 215 270 C 225 300 120 320 0 350 Z" fill="$secondarySvgColor" opacity="0.40" />
  <path d="M 0 0 L 260 0 C 225 85 140 170 165 240 C 180 270 85 285 0 310 Z" fill="$primarySvgColor" />
  <circle cx="28" cy="28" r="2.2" fill="#FFFFFF" opacity="0.35" />
  <circle cx="56" cy="28" r="2.2" fill="#FFFFFF" opacity="0.35" />
  <circle cx="84" cy="28" r="2.2" fill="#FFFFFF" opacity="0.35" />
  <circle cx="112" cy="28" r="2.2" fill="#FFFFFF" opacity="0.35" />
  <circle cx="140" cy="28" r="2.2" fill="#FFFFFF" opacity="0.35" />
  <circle cx="168" cy="28" r="2.2" fill="#FFFFFF" opacity="0.35" />
  <circle cx="196" cy="28" r="2.2" fill="#FFFFFF" opacity="0.35" />
  <circle cx="28" cy="56" r="2.2" fill="#FFFFFF" opacity="0.35" />
  <circle cx="56" cy="56" r="2.2" fill="#FFFFFF" opacity="0.35" />
  <circle cx="84" cy="56" r="2.2" fill="#FFFFFF" opacity="0.35" />
  <circle cx="112" cy="56" r="2.2" fill="#FFFFFF" opacity="0.35" />
  <circle cx="140" cy="56" r="2.2" fill="#FFFFFF" opacity="0.35" />
  <circle cx="168" cy="56" r="2.2" fill="#FFFFFF" opacity="0.35" />
  <circle cx="28" cy="84" r="2.2" fill="#FFFFFF" opacity="0.35" />
  <circle cx="56" cy="84" r="2.2" fill="#FFFFFF" opacity="0.35" />
  <circle cx="84" cy="84" r="2.2" fill="#FFFFFF" opacity="0.35" />
  <circle cx="112" cy="84" r="2.2" fill="#FFFFFF" opacity="0.35" />
  <circle cx="140" cy="84" r="2.2" fill="#FFFFFF" opacity="0.35" />
  <circle cx="28" cy="112" r="2.2" fill="#FFFFFF" opacity="0.35" />
  <circle cx="56" cy="112" r="2.2" fill="#FFFFFF" opacity="0.35" />
  <circle cx="84" cy="112" r="2.2" fill="#FFFFFF" opacity="0.35" />
  <circle cx="112" cy="112" r="2.2" fill="#FFFFFF" opacity="0.35" />
  <circle cx="28" cy="140" r="2.2" fill="#FFFFFF" opacity="0.35" />
  <circle cx="56" cy="140" r="2.2" fill="#FFFFFF" opacity="0.35" />
  <circle cx="84" cy="140" r="2.2" fill="#FFFFFF" opacity="0.35" />
  <circle cx="28" cy="168" r="2.2" fill="#FFFFFF" opacity="0.35" />
  <circle cx="56" cy="168" r="2.2" fill="#FFFFFF" opacity="0.35" />
  <circle cx="28" cy="196" r="2.2" fill="#FFFFFF" opacity="0.35" />
  <path d="M 595.28 220 C 385 390 355 520 310 620 C 240 700 105 710 0 730 L 0 841.89 L 595.28 841.89 Z" fill="$secondarySvgColor" opacity="0.35" />
  <path d="M 595.28 270 C 430 405 405 540 345 640 C 275 710 130 715 0 755 L 0 841.89 L 595.28 841.89 Z" fill="$primarySvgColor" />
  <path d="M 595.28 270 C 430 405 405 540 345 640 C 275 710 130 715 0 755" fill="none" stroke="#FFFFFF" stroke-width="2.5" opacity="0.40" />
</svg>
''';

    return pw.Stack(
      fit: pw.StackFit.expand,
      children: [
        pw.Container(color: PdfColors.white),
        if (coverBytes != null)
          pw.Positioned(
            top: 275,
            left: 0,
            right: 120,
            bottom: 85,
            child: pw.ClipRRect(
              horizontalRadius: 18,
              verticalRadius: 18,
              child: pw.Image(
                pw.MemoryImage(coverBytes),
                fit: pw.BoxFit.cover,
              ),
            ),
          ),
        pw.SvgImage(svg: svgOverlay),
        pw.Positioned(
          top: 48,
          right: 42,
          left: 240,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              if (logoBytes != null)
                pw.Image(pw.MemoryImage(logoBytes), height: 48, fit: pw.BoxFit.contain)
              else
                pw.Text(
                  (settings.companyName != null && settings.companyName!.isNotEmpty)
                    ? settings.companyName!.toUpperCase()
                    : 'SUA EMPRESA',
                  style: pw.TextStyle(
                    font: fontMontserratBlack,
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromInt(0xFF0F172A),
                  ),
                ),
              pw.SizedBox(height: 32),
              pw.Text(
                settings.coverTitle.isNotEmpty ? settings.coverTitle.toUpperCase() : 'PROPOSTA\nCOMERCIAL',
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                  font: fontMontserratBlack,
                  fontSize: 26,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromInt(0xFF0F172A),
                  lineSpacing: 2,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                settings.coverSubtitle.isNotEmpty ? settings.coverSubtitle.toUpperCase() : 'ENERGIA SOLAR FOTOVOLTAICA',
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                  font: fontMontserratBold,
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: primaryPdfColor,
                  letterSpacing: 1.5,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Cliente: ${proposal.clientName}',
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                  font: fontMontserratSemiBold,
                  fontSize: 11,
                  color: PdfColor.fromInt(0xFF475569),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                '${kwp.toStringAsFixed(2)} kWp • ${generationMonthly.toStringAsFixed(0)} kWh/mês',
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                  font: fontMontserratBold,
                  fontSize: 10,
                  color: primaryPdfColor,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Brasil • 2026',
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                  font: fontMontserratSemiBold,
                  fontSize: 10,
                  color: PdfColor.fromInt(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
        pw.Positioned(
          bottom: 24,
          left: 36,
          right: 36,
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              if (settings.companyPhone != null && settings.companyPhone!.isNotEmpty)
                pw.Text(
                  'Tel: ${settings.companyPhone!}',
                  style: pw.TextStyle(font: fontMontserratSemiBold, fontSize: 10, color: PdfColors.white),
                ),
              pw.Text(
                'Email: contato@empresa.com.br',
                style: pw.TextStyle(font: fontMontserratSemiBold, fontSize: 10, color: PdfColors.white),
              ),
              if (settings.companyWebsite != null && settings.companyWebsite!.isNotEmpty)
                pw.Text(
                  'Site: ${settings.companyWebsite!}',
                  style: pw.TextStyle(font: fontMontserratSemiBold, fontSize: 10, color: PdfColors.white),
                ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildVerticalSplitPdfCover({
    required Uint8List? coverBytes,
    required ProposalModel proposal,
    required SolarSettingsModel settings,
    required double generationMonthly,
    required double kwp,
    pw.Font? fontMontserratBlack,
    pw.Font? fontMontserratBold,
    pw.Font? fontMontserratSemiBold,
    pw.Font? headlineFontBold,
    pw.Font? headlineFontBlack,
    pw.Font? rightBlockFontBold,
    pw.Font? rightBlockFontBlack,
    pw.Font? footerFontBold,
  }) {
    final accentHex = settings.verticalSplitAccentColor.replaceAll('#', '').trim();
    final accentSvgColor = '#$accentHex';
    final accentPdfColor = PdfColor.fromInt(settings.verticalSplitAccentColorValue);
    final divType = settings.verticalSplitDividerType;
    final badges = settings.verticalSplitFooterBadges;

    // SVG Overlay vetorial: máscara branca cobrindo o lado direito e linha dourada
    String svgOverlay;
    if (divType == 1) {
      // Tipo 1: Raio de Energia (Zig-zag) — SEM watermark de sol
      svgOverlay = '''
<svg viewBox="0 0 595.28 841.89" width="595.28" height="841.89" xmlns="http://www.w3.org/2000/svg">
  <polygon points="405,0 595.28,0 595.28,841.89 208,841.89 321,547 250,547 386,269 285,269" fill="#FFFFFF" />
  <polyline points="405,0 285,269 386,269 250,547 321,547 208,841.89" fill="none" stroke="$accentSvgColor" stroke-width="4.5" stroke-linecap="round" stroke-linejoin="round" />
</svg>
''';
    } else if (divType == 2) {
      // Tipo 2: Sol Radiante (Arco) — com raios solares
      svgOverlay = '''
<svg viewBox="0 0 595.28 841.89" width="595.28" height="841.89" xmlns="http://www.w3.org/2000/svg">
  <path d="M 210 0 L 595.28 0 L 595.28 841.89 L 360 841.89 L 260 620 A 210 210 0 0 0 260 210 Z" fill="#FFFFFF" />
  <path d="M 210 0 L 260 210 A 210 210 0 0 1 260 620 L 360 841.89" fill="none" stroke="$accentSvgColor" stroke-width="4.5" stroke-linecap="round" />
  <line x1="380" y1="260" x2="430" y2="230" stroke="$accentSvgColor" stroke-width="3" stroke-linecap="round" />
  <line x1="420" y1="340" x2="480" y2="330" stroke="$accentSvgColor" stroke-width="3" stroke-linecap="round" />
  <line x1="430" y1="430" x2="490" y2="430" stroke="$accentSvgColor" stroke-width="3" stroke-linecap="round" />
  <line x1="410" y1="510" x2="470" y2="525" stroke="$accentSvgColor" stroke-width="3" stroke-linecap="round" />
  <line x1="360" y1="580" x2="410" y2="610" stroke="$accentSvgColor" stroke-width="3" stroke-linecap="round" />
  <circle cx="580" cy="740" r="230" fill="none" stroke="#F1F5F9" stroke-width="32" />
</svg>
''';
    } else {
      // Tipo 0: Corte Diagonal Reto — SEM watermark de sol
      svgOverlay = '''
<svg viewBox="0 0 595.28 841.89" width="595.28" height="841.89" xmlns="http://www.w3.org/2000/svg">
  <polygon points="392,0 595.28,0 595.28,841.89 208,841.89" fill="#FFFFFF" />
  <line x1="392" y1="0" x2="208" y2="841.89" stroke="$accentSvgColor" stroke-width="4.5" stroke-linecap="round" />
</svg>
''';
    }

    const double a4W = 595.28;
    const double a4H = 841.89;

    final double effectiveRightBlockTop = settings.verticalSplitRightBlockTop * a4H;
    final double effectiveRightBlockRight = settings.verticalSplitRightBlockRight * a4W;
    final double effectiveHeadlineLeft = settings.verticalSplitHeadlineLeft * a4W;
    final double effectiveHeadlineTop = settings.verticalSplitHeadlineTop * a4H;
    final double effectiveLeftFooterLeft = settings.verticalSplitLeftFooterLeft * a4W;
    final double effectiveLeftFooterBottom = settings.verticalSplitLeftFooterBottom * a4H;
    final double effectiveRightFooterRight = settings.verticalSplitRightFooterRight * a4W;
    final double effectiveRightFooterBottom = settings.verticalSplitRightFooterBottom * a4H;

    final String resolvedTitle = settings.verticalSplitRightTitle
        .replaceAll('{cliente}', proposal.clientName)
        .replaceAll('{nome}', proposal.clientName);
    String resolvedSubtitle = settings.verticalSplitRightSubtitle
        .replaceAll('{cliente}', proposal.clientName)
        .replaceAll('{nome}', proposal.clientName);
    if (proposal.clientName.trim().isNotEmpty && resolvedSubtitle.toUpperCase() == 'FAMÍLIA SILVA') {
      final cNameUpper = proposal.clientName.trim().toUpperCase();
      resolvedSubtitle = cNameUpper.startsWith('FAMÍLIA') ? cNameUpper : 'FAMÍLIA $cNameUpper';
    }

    Uint8List? logoBytes;
    if (settings.coverShowLogo && settings.companyLogoBase64 != null && settings.companyLogoBase64!.isNotEmpty) {
      try {
        final cleanLogo = settings.companyLogoBase64!.contains(',')
            ? settings.companyLogoBase64!.split(',').last
            : settings.companyLogoBase64!;
        logoBytes = base64Decode(cleanLogo);
      } catch (_) {}
    }

    return pw.Stack(
      fit: pw.StackFit.expand,
      children: [
        // 1. Imagem de fundo limpa da Capa
        if (coverBytes != null)
          pw.Image(pw.MemoryImage(coverBytes), fit: pw.BoxFit.cover)
        else
          pw.Container(color: PdfColor.fromInt(0xFF0F172A)),

        // 2. Sobreposição Vetorial
        pw.SvgImage(svg: svgOverlay),

        // 3. Textos do Lado Esquerdo (Foto)
        if (settings.verticalSplitShowHeadline)
          pw.Positioned(
            left: effectiveHeadlineLeft,
            top: effectiveHeadlineTop,
            child: pw.SizedBox(
              width: a4W * 0.44,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    settings.verticalSplitHeadline,
                    style: pw.TextStyle(
                      font: headlineFontBlack ?? fontMontserratBlack,
                      fontSize: settings.verticalSplitHeadlineFontSize,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromInt(settings.coverHeadlineColorValue),
                      lineSpacing: 2,
                    ),
                  ),
                  if (settings.verticalSplitShowHeadlineDivider) ...[
                    pw.SizedBox(height: 8),
                    pw.Container(
                      width: settings.verticalSplitHeadlineDividerWidth,
                      height: settings.verticalSplitHeadlineDividerHeight,
                      color: settings.verticalSplitHeadlineDividerColor.isNotEmpty
                          ? _parsePdfColor(settings.verticalSplitHeadlineDividerColor, fallback: accentPdfColor)
                          : accentPdfColor,
                    ),
                    pw.SizedBox(height: 12),
                  ] else ...[
                    pw.SizedBox(height: 12),
                  ],
                  pw.Text(
                    settings.verticalSplitSubheadline,
                    style: pw.TextStyle(
                      font: headlineFontBold ?? fontMontserratBold,
                      fontSize: 11.0,
                      color: PdfColor.fromInt(settings.coverHeadlineColorValue),
                      lineSpacing: 1.8,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // 4. Rodapé do Lado Esquerdo
        if (settings.verticalSplitShowLeftFooter)
          pw.Positioned(
            left: effectiveLeftFooterLeft,
            bottom: effectiveLeftFooterBottom,
            child: pw.SizedBox(
              width: a4W * settings.verticalSplitLeftFooterWidth.clamp(0.20, 0.95),
              child: divType == 2
                  ? pw.Text(
                      settings.verticalSplitLeftFooter,
                      style: pw.TextStyle(
                        font: fontMontserratBold,
                        fontSize: 9.5,
                        color: PdfColors.white,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    )
                  : settings.verticalSplitBadgesLayout == 'vertical'
                      ? pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          mainAxisSize: pw.MainAxisSize.min,
                          children: [
                            for (int i = 0; i < badges.length; i++)
                              pw.Padding(
                                padding: const pw.EdgeInsets.only(bottom: 6),
                                child: pw.Row(
                                  mainAxisSize: pw.MainAxisSize.min,
                                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                                  children: [
                                    _buildPdfCoverCustomIcon(badges[i].iconKey, 12, PdfColor.fromInt(settings.coverBadgesIconColorValue)),
                                    pw.SizedBox(width: 5),
                                    pw.Text(
                                      badges[i].label,
                                      style: pw.TextStyle(
                                        font: fontMontserratBold,
                                        fontSize: 9.0,
                                        fontWeight: pw.FontWeight.bold,
                                        color: PdfColor.fromInt(settings.coverBadgesTextColorValue),
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        )
                      : settings.verticalSplitBadgesLayout == 'wrap'
                          ? pw.Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              crossAxisAlignment: pw.WrapCrossAlignment.center,
                              children: [
                                for (int i = 0; i < badges.length; i++) ...[
                                  pw.Row(
                                    mainAxisSize: pw.MainAxisSize.min,
                                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                                    children: [
                                      _buildPdfCoverCustomIcon(badges[i].iconKey, 12, PdfColor.fromInt(settings.coverBadgesIconColorValue)),
                                      pw.SizedBox(width: 5),
                                      pw.Text(
                                        badges[i].label,
                                        style: pw.TextStyle(
                                          font: fontMontserratBold,
                                          fontSize: 9.0,
                                          fontWeight: pw.FontWeight.bold,
                                          color: PdfColor.fromInt(settings.coverBadgesTextColorValue),
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (i < badges.length - 1)
                                    pw.Container(
                                      width: 1.5,
                                      height: 12,
                                      color: PdfColor.fromInt(0x66FFFFFF),
                                      margin: const pw.EdgeInsets.symmetric(horizontal: 4),
                                    ),
                                ],
                              ],
                            )
                          : pw.Row(
                              mainAxisSize: pw.MainAxisSize.min,
                              crossAxisAlignment: pw.CrossAxisAlignment.center,
                              children: [
                                for (int i = 0; i < badges.length; i++) ...[
                                  pw.Row(
                                    mainAxisSize: pw.MainAxisSize.min,
                                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                                    children: [
                                      _buildPdfCoverCustomIcon(badges[i].iconKey, 12, accentPdfColor),
                                      pw.SizedBox(width: 5),
                                      pw.Text(
                                        badges[i].label,
                                        style: pw.TextStyle(
                                          font: fontMontserratBold,
                                          fontSize: 9.0,
                                          fontWeight: pw.FontWeight.bold,
                                          color: PdfColor.fromInt(settings.coverBadgesTextColorValue),
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (i < badges.length - 1)
                                    pw.Container(
                                      width: 1.5,
                                      height: 12,
                                      color: PdfColor.fromInt(0x66FFFFFF),
                                      margin: const pw.EdgeInsets.symmetric(horizontal: 6),
                                    ),
                                ],
                              ],
                            ),
            ),
          ),

        // 5. Lado Direito (Institucional - Montserrat & alinhamento harmônico)
        if (settings.verticalSplitShowRightBlock)
          pw.Positioned(
            right: effectiveRightBlockRight,
            top: effectiveRightBlockTop,
            child: pw.SizedBox(
              width: a4W * 0.42,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    resolvedTitle,
                    style: pw.TextStyle(
                      font: rightBlockFontBold ?? fontMontserratBold,
                      fontSize: settings.verticalSplitRightTitleFontSize,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromInt(settings.coverRightTitleColorValue),
                      letterSpacing: 5.5,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    resolvedSubtitle,
                    style: pw.TextStyle(
                      font: rightBlockFontBlack ?? fontMontserratBlack,
                      fontSize: settings.verticalSplitRightSubtitleFontSize,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromInt(settings.coverRightSubtitleColorValue),
                      letterSpacing: 2.0,
                    ),
                  ),
                  if (settings.verticalSplitShowRightDivider) ...[
                    pw.SizedBox(height: 12),
                    pw.Container(
                      width: settings.verticalSplitRightDividerWidth,
                      height: settings.verticalSplitRightDividerHeight,
                      color: settings.verticalSplitRightDividerColor.isNotEmpty
                          ? _parsePdfColor(settings.verticalSplitRightDividerColor, fallback: accentPdfColor)
                          : accentPdfColor,
                    ),
                    pw.SizedBox(height: 14),
                  ] else ...[
                    pw.SizedBox(height: 14),
                  ],
                  pw.Text(
                    settings.verticalSplitRightTagline,
                    style: pw.TextStyle(
                      font: rightBlockFontBold ?? fontMontserratBold,
                      fontSize: 11.5,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromInt(settings.coverRightTaglineColorValue),
                      lineSpacing: 2,
                    ),
                  ),
                  if (divType == 2 && badges.isNotEmpty) ...[
                    pw.SizedBox(height: 24),
                    for (final badge in badges) ...[
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 10),
                        child: pw.Row(
                          children: [
                            _buildPdfCoverCustomIcon(badge.iconKey, 14, accentPdfColor),
                            pw.SizedBox(width: 8),
                            pw.Text(
                              badge.label,
                              style: pw.TextStyle(
                                font: fontMontserratBold,
                                fontSize: 10.5,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColor.fromInt(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),

        // 6. Logomarca da Empresa (se habilitada)
        if (logoBytes != null && settings.coverShowLogo)
          pw.Positioned(
            left: a4W * settings.coverLogoPositionX,
            top: a4H * settings.coverLogoPositionY,
            child: pw.Image(
              pw.MemoryImage(logoBytes),
              width: settings.coverLogoWidth,
              fit: pw.BoxFit.contain,
            ),
          ),

        // 7. Rodapé do Lado Direito (somente texto)
        if (settings.verticalSplitShowRightFooter)
          pw.Positioned(
            right: effectiveRightFooterRight,
            bottom: effectiveRightFooterBottom,
            child: pw.SizedBox(
              width: a4W * 0.40,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    settings.verticalSplitRightFooter,
                    style: pw.TextStyle(
                      font: footerFontBold ?? fontMontserratSemiBold,
                      fontSize: 10.0,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromInt(settings.coverFooterColorValue),
                      lineSpacing: 1.8,
                    ),
                  ),
                  if (proposal.clientName.isNotEmpty) ...[
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'Cliente: ${proposal.clientName}',
                      style: pw.TextStyle(
                        font: fontMontserratBold,
                        fontSize: 10.0,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromInt(0xFF0F172A),
                      ),
                    ),
                  ],
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Proposta: PROP-${proposal.proposalNumber}  |  $kwp kWp',
                    style: pw.TextStyle(
                      fontSize: 7.5,
                      color: PdfColor.fromInt(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // 8. Textos Personalizados Extras Adicionados pelo Usuário
        for (final textItem in settings.customTextItems)
          pw.Positioned(
            left: textItem.x * a4W,
            top: textItem.y * a4H,
            child: pw.Text(
              textItem.text,
              style: pw.TextStyle(
                font: textItem.isBold ? fontMontserratBold : fontMontserratSemiBold,
                fontSize: textItem.fontSize,
                fontWeight: textItem.isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: PdfColor.fromInt(textItem.colorValue),
              ),
            ),
          ),

        // 9. Ícones Personalizados Extras Adicionados pelo Usuário
        for (final iconItem in settings.customIconItems)
          pw.Positioned(
            left: iconItem.x * a4W,
            top: iconItem.y * a4H,
            child: _buildPdfCoverCustomIcon(iconItem.iconKey, iconItem.size, PdfColor.fromInt(iconItem.colorValue)),
          ),

      ],
    );
  }

  static pw.Widget _buildPdfCoverCustomIcon(String iconKey, double size, PdfColor color) {
    final hex = '#${color.toInt().toRadixString(16).padLeft(8, '0').substring(2)}';
    String svgContent;
    switch (iconKey.toLowerCase()) {
      case 'bolt':
      case 'energia':
      case 'raio':
        svgContent = '<svg viewBox="0 0 24 24" width="$size" height="$size"><polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2" fill="$hex"/></svg>';
        break;
      case 'chart':
      case 'grafico':
      case 'valorizacao':
      case 'bar_chart':
      case 'trending_up':
      case 'show_chart':
        svgContent = '<svg viewBox="0 0 24 24" width="$size" height="$size"><rect x="3" y="12" width="4.5" height="9" rx="1" fill="$hex"/><rect x="9.75" y="4" width="4.5" height="17" rx="1" fill="$hex"/><rect x="16.5" y="8" width="4.5" height="13" rx="1" fill="$hex"/></svg>';
        break;
      case 'coins':
      case 'moedas':
      case 'dinheiro':
      case 'money':
      case 'attach_money':
      case 'savings':
      case 'economia':
        svgContent = '<svg viewBox="0 0 24 24" width="$size" height="$size"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 14.5h-2v-1.5c-1.3-.2-2-1.1-2-2.5h1.5c0 .8.5 1.5 1.5 1.5s1.5-.7 1.5-1.5c0-.9-.7-1.3-1.8-1.7-1.5-.5-2.7-1.1-2.7-2.8 0-1.4.9-2.3 2-2.5V4.5h2V6c1.1.2 1.8 1 1.8 2.2h-1.5c0-.7-.4-1.2-1.3-1.2s-1.2.5-1.2 1.2c0 .8.6 1.1 1.6 1.5 1.7.6 2.9 1.2 2.9 3 0 1.5-.9 2.5-2 2.8v1.5z" fill="$hex"/></svg>';
        break;
      case 'sun':
      case 'sol':
      case 'solar_power':
      case 'painel':
        svgContent = '<svg viewBox="0 0 24 24" width="$size" height="$size"><circle cx="12" cy="12" r="5" fill="$hex"/><path d="M12 1v2M12 21v2M4.22 4.22l1.42 1.42M18.36 18.36l1.42 1.42M1 12h2M21 12h2M4.22 19.78l1.42-1.42M18.36 5.64l1.42-1.42" stroke="$hex" stroke-width="2.5" stroke-linecap="round"/></svg>';
        break;
      case 'star':
      case 'estrela':
      case 'favorito':
        svgContent = '<svg viewBox="0 0 24 24" width="$size" height="$size"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2" fill="$hex"/></svg>';
        break;
      case 'shield':
      case 'seguranca':
      case 'garantia':
        svgContent = '<svg viewBox="0 0 24 24" width="$size" height="$size"><path d="M12 1L3 5v6c0 5.55 3.84 10.74 9 12 5.16-1.26 9-6.45 9-12V5l-9-4z" fill="$hex"/></svg>';
        break;
      case 'verified':
      case 'check':
      case 'qualidade':
        svgContent = '<svg viewBox="0 0 24 24" width="$size" height="$size"><path d="M12 2L9.19 3.63 6 3.17 4.13 5.8 1.5 7.19 1.72 10.42 0 12.81 1.72 15.2 1.5 18.43 4.13 19.82 6 22.45 9.19 21.99 12 23.62 14.81 21.99 18 22.45 19.87 19.82 22.5 18.43 22.28 15.2 24 12.81 22.28 10.42 22.5 7.19 19.87 5.8 18 3.17 14.81 3.63 12 2zm-1.5 14.5l-4-4 1.41-1.41L10.5 13.67l6.59-6.59 1.41 1.41-8 8z" fill="$hex"/></svg>';
        break;
      case 'battery':
      case 'bateria':
        svgContent = '<svg viewBox="0 0 24 24" width="$size" height="$size"><path d="M15.67 4H14V2h-4v2H8.33C7.6 4 7 4.6 7 5.33v15.33C7 21.4 7.6 22 8.33 22h7.33c.74 0 1.34-.6 1.34-1.33V5.33C17 4.6 16.4 4 15.67 4zM11 20v-5.5H9L13 7v5.5h2L11 20z" fill="$hex"/></svg>';
        break;
      case 'percent':
      case 'desconto':
        svgContent = '<svg viewBox="0 0 24 24" width="$size" height="$size"><path d="M7.5 4C5.57 4 4 5.57 4 7.5S5.57 11 7.5 11 11 9.43 11 7.5 9.43 4 7.5 4zm0 4.5c-.83 0-1.5-.67-1.5-1.5S6.67 5.5 7.5 5.5 9 6.17 9 7 8.33 8.5 7.5 8.5zM19.71 4.29a1 1 0 00-1.42 0l-14 14a1 1 0 101.42 1.42l14-14a1 1 0 000-1.42zM16.5 13c-1.93 0-3.5 1.57-3.5 3.5s1.57 3.5 3.5 3.5 3.5-1.57 3.5-3.5-1.57-3.5-3.5-3.5zm0 4.5c-.83 0-1.5-.67-1.5-1.5s.67-1.5 1.5-1.5 1.5.67 1.5 1.5-.67 1.5-1.5 1.5z" fill="$hex"/></svg>';
        break;
      case 'handshake':
      case 'parceria':
        svgContent = '<svg viewBox="0 0 24 24" width="$size" height="$size"><path d="M19 8l-4 4h3c0 3.31-2.69 6-6 6-1.01 0-1.97-.25-2.8-.7l-1.46 1.46C8.97 19.54 10.43 20 12 20c4.42 0 8-3.58 8-8h3l-4-4zM6 12c0-3.31 2.69-6 6-6 1.01 0 1.97.25 2.8.7l1.46-1.46C15.03 4.46 13.57 4 12 4c-4.42 0-8 3.58-8 8H1l4 4 4-4H6z" fill="$hex"/></svg>';
        break;
      case 'rocket':
      case 'foguete':
        svgContent = '<svg viewBox="0 0 24 24" width="$size" height="$size"><path d="M12 2.5s4 3 4 8.5c0 2-.5 4-1.5 5.5l1.5 3.5-3-1-3 1 1.5-3.5C10.5 15 10 13 10 11c0-5.5 4-8.5 4-8.5z" fill="$hex"/><circle cx="12" cy="9" r="1.5" fill="#FFFFFF"/></svg>';
        break;
      case 'diamond':
      case 'diamante':
        svgContent = '<svg viewBox="0 0 24 24" width="$size" height="$size"><path d="M19 3H5L2 9l10 12L22 9l-3-6zM9 5h6l1.5 3h-9L9 5zM4.5 9l2-3.5h1.8L6.8 9H4.5zm7.5 9.5L6.2 10h11.6L12 18.5zm3.7-9.5l-1.5-3.5h1.8l2 3.5h-2.3z" fill="$hex"/></svg>';
        break;
      case 'water_drop':
      case 'agua':
        svgContent = '<svg viewBox="0 0 24 24" width="$size" height="$size"><path d="M12 2.69l5.66 5.66a8 8 0 11-11.31 0z" fill="$hex"/></svg>';
        break;
      case 'phone':
      case 'whatsapp':
      case 'telefone':
      case 'contato':
        svgContent = '<svg viewBox="0 0 24 24" width="$size" height="$size"><path d="M6.62 10.79a15.053 15.053 0 006.59 6.59l2.2-2.2c.27-.27.67-.36 1.02-.24 1.12.37 2.33.57 3.57.57.55 0 1 .45 1 1V20c0 .55-.45 1-1 1-9.39 0-17-7.61-17-17 0-.55.45-1 1-1h3.5c.55 0 1 .45 1 1 0 1.25.2 2.45.57 3.57.11.35.03.74-.25 1.02l-2.2 2.2z" fill="$hex"/></svg>';
        break;
      case 'location':
      case 'localizacao':
      case 'endereco':
      case 'map':
        svgContent = '<svg viewBox="0 0 24 24" width="$size" height="$size"><path d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7zm0 9.5c-1.38 0-2.5-1.12-2.5-2.5s1.12-2.5 2.5-2.5 2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5z" fill="$hex"/></svg>';
        break;
      case 'mail':
      case 'email':
        svgContent = '<svg viewBox="0 0 24 24" width="$size" height="$size"><path d="M20 4H4c-1.1 0-1.99.9-1.99 2L2 18c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2zm0 4l-8 5-8-5V6l8 5 8-5v2z" fill="$hex"/></svg>';
        break;
      case 'lightbulb':
      case 'light':
      case 'lampada':
      case 'iluminacao':
      case 'ideia':
        svgContent = '<svg viewBox="0 0 24 24" width="$size" height="$size"><path d="M9 21c0 .55.45 1 1 1h4c.55 0 1-.45 1-1v-1H9v1zm3-19C8.14 2 5 5.14 5 9c0 2.38 1.19 4.47 3 5.74V17c0 .55.45 1 1 1h6c.55 0 1-.45 1-1v-2.26c1.81-1.27 3-3.36 3-5.74 0-3.86-3.14-7-7-7z" fill="$hex"/></svg>';
        break;
      case 'music':
      case 'audio':
      case 'som':
        svgContent = '<svg viewBox="0 0 24 24" width="$size" height="$size"><path d="M12 3v10.55c-.59-.34-1.27-.55-2-.55-2.21 0-4 1.79-4 4s1.79 4 4 4 4-1.79 4-4V7h4V3h-6z" fill="$hex"/></svg>';
        break;
      case 'temp':
      case 'clima':
      case 'climatizacao':
      case 'climate':
      case 'hvac':
      case 'thermostat':
        svgContent = '<svg viewBox="0 0 24 24" width="$size" height="$size"><path d="M15 13V5c0-1.66-1.34-3-3-3S9 3.34 9 5v8c-1.21.91-2 2.37-2 4 0 2.76 2.24 5 5 5s5-2.24 5-5c0-1.63-.79-3.09-2-4zm-3-8c.55 0 1 .45 1 1v3h-2V6c0-.55.45-1 1-1z" fill="$hex"/></svg>';
        break;
      case 'lock':
      case 'acesso':
      case 'fechadura':
      case 'cadeado':
      case 'biometria':
      case 'biometric':
      case 'fingerprint':
        svgContent = '<svg viewBox="0 0 24 24" width="$size" height="$size"><path d="M18 8h-1V6c0-2.76-2.24-5-5-5S7 3.24 7 6v2H6c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V10c0-1.1-.9-2-2-2zm-6 9c-1.1 0-2-.9-2-2s.9-2 2-2 2 .9 2 2-.9 2-2 2zm3.1-9H8.9V6c0-1.71 1.39-3.1 3.1-3.1 1.71 0 3.1 1.39 3.1 3.1v2z" fill="$hex"/></svg>';
        break;
      case 'camera':
      case 'monitoramento':
      case 'video':
        svgContent = '<svg viewBox="0 0 24 24" width="$size" height="$size"><path d="M17 10.5V7c0-.55-.45-1-1-1H4c-.55 0-1 .45-1 1v10c0 .55.45 1 1 1h12c.55 0 1-.45 1-1v-3.5l4 4v-11l-4 4z" fill="$hex"/></svg>';
        break;
      case 'wifi':
      case 'rede':
        svgContent = '<svg viewBox="0 0 24 24" width="$size" height="$size"><path d="M12 3C7.95 3 4.21 4.34 1.2 6.6L3 9c2.47-1.85 5.56-3 9-3s6.53 1.15 9 3l1.8-2.4C19.79 4.34 16.05 3 12 3zm0 6c-2.9 0-5.58.97-7.74 2.6L6 14c1.7-1.28 3.75-2 6-2s4.3.72 6 2l1.74-2.4C17.58 9.97 14.9 9 12 9zm0 6c-1.57 0-3.03.54-4.2 1.44L12 21l4.2-4.56C15.03 15.54 13.57 15 12 15z" fill="$hex"/></svg>';
        break;
      case 'curtain':
      case 'cortina':
      case 'persiana':
        svgContent = '<svg viewBox="0 0 24 24" width="$size" height="$size"><path d="M20 19V3H4v16H2v2h20v-2h-2zM6 5h5v4H6V5zm0 6h5v4H6v-4zm12 8H6v-2h12v2zm0-4h-5v-4h5v4zm0-6h-5V5h5v4z" fill="$hex"/></svg>';
        break;
      case 'home':
      case 'casa':
      case 'residencia':
        svgContent = '<svg viewBox="0 0 24 24" width="$size" height="$size"><path d="M10 20v-6h4v6h5v-8h3L12 3 2 12h3v8z" fill="$hex"/></svg>';
        break;
      case 'leaf':
      case 'eco':
      case 'nature':
      case 'sustentabilidade':
      default:
        svgContent = '<svg viewBox="0 0 24 24" width="$size" height="$size"><path d="M17 8C8 10 5.9 16.17 3.82 21.34l1.89.66.95-2.3c.48.17.98.3 1.34.3C19 20 22 3 22 3c-1 2-8 2.52-12.5 4.5" fill="none" stroke="$hex" stroke-width="2.5" stroke-linecap="round"/></svg>';
        break;
    }
    return pw.SvgImage(svg: svgContent, width: size, height: size);
  }

  static bool _isDarkColor(PdfColor color) {
    return (color.red * 0.299 + color.green * 0.587 + color.blue * 0.114) < 0.60;
  }

  static pw.Widget _buildPdfCoverHeader({
    required int styleId,
    required String text1,
    required String text2,
    required String text3,
    required PdfColor accentColor,
    pw.Font? fontBold,
    pw.Font? fontSemiBold,
    PdfColor? customBgColor,
    PdfColor? customTextColor,
    PdfColor? customIconColor,
  }) {
    final effectiveAccent = customIconColor ?? accentColor;
    final title = text1.trim().isNotEmpty ? text1 : 'PROPOSTA COMERCIAL';
    final subtitle = text2.trim().isNotEmpty ? text2 : '';
    final tag = text3.trim().isNotEmpty ? text3 : '';

    switch (styleId) {
      case 2: // Faixa Executiva Escura
        final bg = customBgColor ?? PdfColor.fromHex('#0F172A');
        final isDark = _isDarkColor(bg);
        final titleColor = customTextColor ?? (isDark ? PdfColors.white : PdfColor.fromHex('#0F172A'));
        final subColor = customTextColor ?? (isDark ? effectiveAccent : PdfColor.fromHex('#475569'));
        final tagColor = customTextColor ?? (isDark ? PdfColor.fromHex('#94A3B8') : PdfColor.fromHex('#64748B'));
        return pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          color: bg,
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  pw.Text(title, style: pw.TextStyle(font: fontBold, fontSize: 11, fontWeight: pw.FontWeight.bold, color: titleColor, letterSpacing: 1.2)),
                  if (subtitle.isNotEmpty)
                    pw.Text(subtitle, style: pw.TextStyle(font: fontSemiBold, fontSize: 7.5, color: subColor)),
                ],
              ),
              if (tag.isNotEmpty)
                pw.Text(tag, style: pw.TextStyle(font: fontSemiBold, fontSize: 8, color: tagColor)),
            ],
          ),
        );
      case 3: // Gradiente Tech / Accent Bar
        final bg = customBgColor ?? PdfColor.fromHex('#0B1120');
        final isDark = _isDarkColor(bg);
        final titleColor = customTextColor ?? (isDark ? PdfColors.white : PdfColor.fromHex('#0F172A'));
        final subColor = customTextColor ?? (isDark ? PdfColor.fromHex('#38BDF8') : PdfColor.fromHex('#475569'));
        return pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          decoration: pw.BoxDecoration(
            color: bg,
            border: pw.Border(bottom: pw.BorderSide(color: effectiveAccent, width: 2.5)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(title, style: pw.TextStyle(font: fontBold, fontSize: 12, fontWeight: pw.FontWeight.bold, color: titleColor, letterSpacing: 1.5)),
              if (subtitle.isNotEmpty || tag.isNotEmpty)
                pw.Text('$subtitle ${tag.isNotEmpty ? "• $tag" : ""}', style: pw.TextStyle(font: fontSemiBold, fontSize: 8, color: subColor)),
            ],
          ),
        );
      case 4: // Corporate Clean
        final bg = customBgColor ?? PdfColors.white;
        final isDark = customBgColor != null ? _isDarkColor(customBgColor) : false;
        final titleColor = customTextColor ?? (isDark ? PdfColors.white : PdfColor.fromHex('#0F172A'));
        final subColor = customTextColor ?? (isDark ? PdfColor.fromHex('#CBD5E1') : PdfColor.fromHex('#64748B'));
        return pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          decoration: pw.BoxDecoration(
            color: bg,
            border: pw.Border(bottom: pw.BorderSide(color: isDark ? effectiveAccent : const PdfColor.fromInt(0xFFE2E8F0), width: isDark ? 2.0 : 1.0)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  pw.Text(title, style: pw.TextStyle(font: fontBold, fontSize: 11, fontWeight: pw.FontWeight.bold, color: titleColor)),
                  if (subtitle.isNotEmpty)
                    pw.Text(subtitle, style: pw.TextStyle(font: fontSemiBold, fontSize: 8, color: subColor)),
                ],
              ),
              if (tag.isNotEmpty)
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: pw.BoxDecoration(
                    color: isDark ? const PdfColor.fromInt(0x30FFFFFF) : PdfColor.fromHex('#F1F5F9'),
                    borderRadius: pw.BorderRadius.circular(4),
                    border: pw.Border.all(color: isDark ? effectiveAccent : PdfColor.fromHex('#CBD5E1')),
                  ),
                  child: pw.Text(tag, style: pw.TextStyle(font: fontBold, fontSize: 7.5, color: isDark ? PdfColors.white : PdfColor.fromHex('#334155'))),
                ),
            ],
          ),
        );
      case 5: // Dupla Linha
        final bg = customBgColor;
        final isDark = customBgColor != null ? _isDarkColor(customBgColor) : false;
        final titleColor = customTextColor ?? (isDark ? PdfColors.white : PdfColor.fromHex('#0F172A'));
        final tagColor = customTextColor ?? (isDark ? PdfColor.fromHex('#CBD5E1') : PdfColor.fromHex('#64748B'));
        return pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          decoration: pw.BoxDecoration(
            color: bg,
            border: pw.Border(bottom: pw.BorderSide(color: effectiveAccent, width: 2)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(title, style: pw.TextStyle(font: fontBold, fontSize: 11, fontWeight: pw.FontWeight.bold, color: titleColor)),
              if (tag.isNotEmpty)
                pw.Text(tag, style: pw.TextStyle(font: fontSemiBold, fontSize: 8, color: tagColor)),
            ],
          ),
        );
      case 6: // Glass Card / Dark Floating
        final bg = customBgColor ?? PdfColor.fromHex('#0F172A');
        final isDark = _isDarkColor(bg);
        final titleColor = customTextColor ?? (isDark ? PdfColors.white : PdfColor.fromHex('#0F172A'));
        final subColor = customTextColor ?? (isDark ? effectiveAccent : PdfColor.fromHex('#475569'));
        return pw.Container(
          margin: const pw.EdgeInsets.all(12),
          padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: pw.BoxDecoration(
            color: bg,
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border.all(color: isDark ? PdfColor.fromHex('#334155') : PdfColor.fromHex('#CBD5E1')),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(title, style: pw.TextStyle(font: fontBold, fontSize: 10, fontWeight: pw.FontWeight.bold, color: titleColor)),
              if (subtitle.isNotEmpty)
                pw.Text(subtitle, style: pw.TextStyle(font: fontSemiBold, fontSize: 8, color: subColor)),
            ],
          ),
        );
      case 7: // Bilateral com Validade
        final bg = customBgColor ?? PdfColor.fromHex('#1E293B');
        final isDark = _isDarkColor(bg);
        final titleColor = customTextColor ?? (isDark ? PdfColors.white : PdfColor.fromHex('#0F172A'));
        final subColor = customTextColor ?? (isDark ? PdfColor.fromHex('#94A3B8') : PdfColor.fromHex('#64748B'));
        return pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          color: bg,
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  pw.Text(title, style: pw.TextStyle(font: fontBold, fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: titleColor)),
                  if (subtitle.isNotEmpty)
                    pw.Text(subtitle, style: pw.TextStyle(font: fontSemiBold, fontSize: 7.5, color: subColor)),
                ],
              ),
              if (tag.isNotEmpty)
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: effectiveAccent,
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(tag, style: pw.TextStyle(font: fontBold, fontSize: 8, color: isDark ? PdfColor.fromHex('#0F172A') : PdfColors.white)),
                ),
            ],
          ),
        );
      case 8: // Cyber Grid Futurista
        final bg = customBgColor ?? PdfColor.fromHex('#030712');
        final titleColor = customTextColor ?? effectiveAccent;
        return pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          decoration: pw.BoxDecoration(
            color: bg,
            border: pw.Border(bottom: pw.BorderSide(color: effectiveAccent, width: 2)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('[SYSTEM] $title', style: pw.TextStyle(font: fontBold, fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: titleColor)),
              if (tag.isNotEmpty)
                pw.Text('AUTH: $tag', style: pw.TextStyle(font: fontSemiBold, fontSize: 8, color: customTextColor ?? PdfColors.white)),
            ],
          ),
        );
      case 9: // Compacto Micro
        final bg = customBgColor ?? PdfColor.fromHex('#0F172A');
        final isDark = customBgColor != null ? _isDarkColor(customBgColor) : true;
        final titleColor = customTextColor ?? (isDark ? PdfColors.white : PdfColor.fromHex('#334155'));
        final subColor = customTextColor ?? (isDark ? PdfColor.fromHex('#CBD5E1') : PdfColor.fromHex('#64748B'));
        final tagColor = customTextColor ?? (isDark ? PdfColors.white : effectiveAccent);
        return pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 5),
          color: bg,
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(title, style: pw.TextStyle(font: fontBold, fontSize: 8, color: titleColor)),
              if (subtitle.isNotEmpty)
                pw.Text(subtitle, style: pw.TextStyle(font: fontSemiBold, fontSize: 8, color: subColor)),
              if (tag.isNotEmpty)
                pw.Text(tag, style: pw.TextStyle(font: fontSemiBold, fontSize: 8, color: tagColor)),
            ],
          ),
        );
      case 10: // Bold Accent Banner
        final bg = customBgColor ?? effectiveAccent;
        final isDark = _isDarkColor(bg);
        final titleColor = customTextColor ?? (isDark ? PdfColors.white : PdfColor.fromHex('#0F172A'));
        final subColor = customTextColor ?? (isDark ? PdfColor.fromHex('#CBD5E1') : PdfColor.fromHex('#1E293B'));
        return pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          color: bg,
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  pw.Text(title, style: pw.TextStyle(font: fontBold, fontSize: 12, fontWeight: pw.FontWeight.bold, color: titleColor)),
                  if (subtitle.isNotEmpty)
                    pw.Text(subtitle, style: pw.TextStyle(font: fontSemiBold, fontSize: 8, color: subColor)),
                ],
              ),
              if (tag.isNotEmpty)
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: isDark ? const PdfColor.fromInt(0x30FFFFFF) : PdfColor.fromHex('#0F172A'),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(tag, style: pw.TextStyle(font: fontBold, fontSize: 8, color: isDark ? PdfColors.white : PdfColors.white)),
                ),
            ],
          ),
        );
      case 1: // Modern Minimalist
      default:
        final bg = customBgColor ?? PdfColors.white;
        final isDark = customBgColor != null ? _isDarkColor(customBgColor) : false;
        final titleColor = customTextColor ?? (isDark ? PdfColors.white : PdfColor.fromHex('#0F172A'));
        final subColor = customTextColor ?? (isDark ? PdfColor.fromHex('#E2E8F0') : PdfColor.fromHex('#64748B'));
        return pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          decoration: pw.BoxDecoration(
            color: bg,
            border: pw.Border(bottom: pw.BorderSide(color: isDark ? effectiveAccent : const PdfColor.fromInt(0x30000000), width: isDark ? 2.0 : 0.8)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  pw.Text(title, style: pw.TextStyle(font: fontBold, fontSize: 11, fontWeight: pw.FontWeight.bold, color: titleColor)),
                  if (subtitle.isNotEmpty)
                    pw.Text(subtitle, style: pw.TextStyle(font: fontSemiBold, fontSize: 7.5, color: subColor)),
                ],
              ),
              if (tag.isNotEmpty)
                pw.Text(tag, style: pw.TextStyle(font: fontSemiBold, fontSize: 8, color: effectiveAccent)),
            ],
          ),
        );
    }
  }

  static pw.Widget _buildPdfCoverFooter({
    required int styleId,
    required String text1,
    required String text2,
    required String text3,
    required String text4,
    required PdfColor accentColor,
    pw.Font? fontBold,
    pw.Font? fontSemiBold,
    PdfColor? customBgColor,
    PdfColor? customTextColor,
    PdfColor? customIconColor,
  }) {
    final effectiveAccent = customIconColor ?? accentColor;
    switch (styleId) {
      case 2: // Slogan & Badges
        final bg = customBgColor ?? PdfColor.fromHex('#1E293B');
        final isDark = _isDarkColor(bg);
        final t1Color = customTextColor ?? (isDark ? effectiveAccent : PdfColor.fromHex('#0F172A'));
        final t2Color = customTextColor ?? (isDark ? PdfColor.fromHex('#CBD5E1') : PdfColor.fromHex('#475569'));
        final t4Color = customTextColor ?? (isDark ? PdfColor.fromHex('#94A3B8') : PdfColor.fromHex('#64748B'));
        return pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          color: bg,
          child: pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              if (text1.isNotEmpty)
                pw.Text(text1, style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: t1Color)),
              if (text2.isNotEmpty || text3.isNotEmpty) ...[
                pw.SizedBox(height: 3),
                pw.Text('$text2  -  $text3', style: pw.TextStyle(font: fontSemiBold, fontSize: 7.5, color: t2Color)),
              ],
              if (text4.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Text(text4, style: pw.TextStyle(font: fontSemiBold, fontSize: 6.5, color: t4Color)),
              ],
            ],
          ),
        );
      case 3: // Faixa Legal
        final bg = customBgColor ?? PdfColor.fromHex('#0B1120');
        final isDark = _isDarkColor(bg);
        final t1Color = customTextColor ?? (isDark ? PdfColor.fromHex('#94A3B8') : PdfColor.fromHex('#475569'));
        final t4Color = customTextColor ?? (isDark ? effectiveAccent : PdfColor.fromHex('#0F172A'));
        return pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 7),
          color: bg,
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(text1.isNotEmpty ? text1 : text2, style: pw.TextStyle(font: fontSemiBold, fontSize: 7.5, color: t1Color)),
              if (text4.isNotEmpty)
                pw.Text(text4, style: pw.TextStyle(font: fontBold, fontSize: 7.5, color: t4Color)),
            ],
          ),
        );
      case 4: // Minimalista Paginação
        final bg = customBgColor ?? PdfColors.white;
        final isDark = customBgColor != null ? _isDarkColor(customBgColor) : false;
        final t1Color = customTextColor ?? (isDark ? PdfColors.white : PdfColor.fromHex('#64748B'));
        final t3Color = customTextColor ?? effectiveAccent;
        return pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          decoration: pw.BoxDecoration(
            color: bg,
            border: pw.Border(top: pw.BorderSide(color: isDark ? effectiveAccent : const PdfColor.fromInt(0x30000000), width: 0.8)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(text1.isNotEmpty ? text1 : text2, style: pw.TextStyle(font: fontSemiBold, fontSize: 8, color: t1Color)),
              if (text3.isNotEmpty)
                pw.Text(text3, style: pw.TextStyle(font: fontBold, fontSize: 8, color: t3Color)),
            ],
          ),
        );
      case 5: // Duas Colunas
        final bg = customBgColor ?? PdfColor.fromHex('#0F172A');
        final isDark = _isDarkColor(bg);
        final t1Color = customTextColor ?? (isDark ? PdfColors.white : PdfColor.fromHex('#0F172A'));
        final t2Color = customTextColor ?? (isDark ? PdfColor.fromHex('#94A3B8') : PdfColor.fromHex('#475569'));
        final t3Color = customTextColor ?? (isDark ? effectiveAccent : PdfColor.fromHex('#0284C7'));
        final t4Color = customTextColor ?? (isDark ? PdfColor.fromHex('#64748B') : PdfColor.fromHex('#94A3B8'));
        return pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          color: bg,
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  if (text1.isNotEmpty)
                    pw.Text(text1, style: pw.TextStyle(font: fontBold, fontSize: 8, color: t1Color)),
                  if (text2.isNotEmpty)
                    pw.Text(text2, style: pw.TextStyle(font: fontSemiBold, fontSize: 7, color: t2Color)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  if (text3.isNotEmpty)
                    pw.Text(text3, style: pw.TextStyle(font: fontBold, fontSize: 7.5, color: t3Color)),
                  if (text4.isNotEmpty)
                    pw.Text(text4, style: pw.TextStyle(font: fontSemiBold, fontSize: 6.5, color: t4Color)),
                ],
              ),
            ],
          ),
        );
      case 6: // Aviso Legal & Validade
        final bg = customBgColor ?? PdfColor.fromHex('#F8FAFC');
        final isDark = _isDarkColor(bg);
        final t4Color = customTextColor ?? (isDark ? PdfColors.white : PdfColor.fromHex('#475569'));
        final t2Color = customTextColor ?? (isDark ? effectiveAccent : PdfColor.fromHex('#0F172A'));
        return pw.Container(
          margin: const pw.EdgeInsets.all(12),
          padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: pw.BoxDecoration(
            color: bg,
            borderRadius: pw.BorderRadius.circular(6),
            border: pw.Border.all(color: isDark ? PdfColor.fromHex('#334155') : PdfColor.fromHex('#CBD5E1')),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Text(text4.isNotEmpty ? text4 : text1, style: pw.TextStyle(font: fontSemiBold, fontSize: 7, color: t4Color)),
              ),
              if (text2.isNotEmpty)
                pw.Text(text2, style: pw.TextStyle(font: fontBold, fontSize: 7.5, color: t2Color)),
            ],
          ),
        );
      case 7: // Borda Superior Neon
        final bg = customBgColor ?? PdfColor.fromHex('#0F172A');
        final isDark = _isDarkColor(bg);
        final t1Color = customTextColor ?? (isDark ? PdfColors.white : PdfColor.fromHex('#0F172A'));
        final t2Color = customTextColor ?? (isDark ? PdfColor.fromHex('#94A3B8') : PdfColor.fromHex('#475569'));
        return pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          decoration: pw.BoxDecoration(
            color: bg,
            border: pw.Border(top: pw.BorderSide(color: effectiveAccent, width: 2)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              if (text1.isNotEmpty)
                pw.Text(text1, style: pw.TextStyle(font: fontBold, fontSize: 8, color: t1Color)),
              pw.Text('$text2  ${text3.isNotEmpty ? "- $text3" : ""}', style: pw.TextStyle(font: fontSemiBold, fontSize: 7.5, color: t2Color)),
            ],
          ),
        );
      case 8: // Sustentabilidade & Futuro
        final bg = customBgColor ?? PdfColor.fromHex('#064E3B');
        final isDark = _isDarkColor(bg);
        final t1Color = customTextColor ?? (isDark ? PdfColors.white : PdfColor.fromHex('#064E3B'));
        final t2Color = customTextColor ?? (isDark ? PdfColor.fromHex('#A7F3D0') : PdfColor.fromHex('#047857'));
        return pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          color: bg,
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(text1.isNotEmpty ? text1 : 'ENERGIA SUSTENTÁVEL PARA O FUTURO', style: pw.TextStyle(font: fontBold, fontSize: 8, color: t1Color)),
              if (text2.isNotEmpty || text3.isNotEmpty)
                pw.Text('$text2 ${text3.isNotEmpty ? "- $text3" : ""}', style: pw.TextStyle(font: fontSemiBold, fontSize: 7, color: t2Color)),
            ],
          ),
        );
      case 9: // Compact Contacts
        final bg = customBgColor ?? PdfColor.fromHex('#0F172A');
        final isDark = _isDarkColor(bg);
        final tColor = customTextColor ?? (isDark ? PdfColors.white : PdfColor.fromHex('#0F172A'));
        return pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 7),
          color: bg,
          child: pw.Center(
            child: pw.Text(
              [text1, text2, text3].where((s) => s.isNotEmpty).join('  -  '),
              style: pw.TextStyle(font: fontSemiBold, fontSize: 7.5, color: tColor),
            ),
          ),
        );
      case 10: // Autenticação & Hash Digital
        final bg = customBgColor ?? PdfColor.fromHex('#030712');
        final isDark = _isDarkColor(bg);
        final t1Color = customTextColor ?? effectiveAccent;
        final t4Color = customTextColor ?? (isDark ? PdfColor.fromHex('#94A3B8') : PdfColor.fromHex('#64748B'));
        return pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 7),
          color: bg,
          decoration: pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: effectiveAccent, width: 1.5)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('DOCUMENTO AUTENTICADO DIGITALMENTE', style: pw.TextStyle(font: fontBold, fontSize: 7, color: t1Color)),
              if (text4.isNotEmpty || text3.isNotEmpty)
                pw.Text(text4.isNotEmpty ? text4 : text3, style: pw.TextStyle(font: fontSemiBold, fontSize: 6.5, color: t4Color)),
            ],
          ),
        );
      case 1: // Institucional Completo
      default:
        final bg = customBgColor ?? PdfColor.fromHex('#0F172A');
        final isDark = _isDarkColor(bg);
        final t1Color = customTextColor ?? (isDark ? effectiveAccent : PdfColor.fromHex('#0F172A'));
        final t2Color = customTextColor ?? (isDark ? PdfColor.fromHex('#CBD5E1') : PdfColor.fromHex('#475569'));
        final t4Color = customTextColor ?? (isDark ? PdfColor.fromHex('#94A3B8') : PdfColor.fromHex('#64748B'));
        return pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          color: bg,
          child: pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              if (text1.isNotEmpty)
                pw.Text(text1, style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: t1Color, letterSpacing: 0.5)),
              if (text2.isNotEmpty || text3.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Text('$text2  -  $text3', style: pw.TextStyle(font: fontSemiBold, fontSize: 7.5, color: t2Color)),
              ],
              if (text4.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Text(text4, style: pw.TextStyle(font: fontSemiBold, fontSize: 6.5, color: t4Color)),
              ],
            ],
          ),
        );
    }
  }

  static pw.Widget _buildCoverPage({
    required Uint8List? coverBytes,
    required ProposalModel proposal,
    required SolarSettingsModel settings,
    required double generationMonthly,
    required double kwp,
    required PdfColor primaryColor,
    pw.Font? fontMontserratBlack,
    pw.Font? fontMontserratBold,
    pw.Font? fontMontserratSemiBold,
    pw.Font? headlineFontBold,
    pw.Font? headlineFontBlack,
    pw.Font? rightBlockFontBold,
    pw.Font? rightBlockFontBlack,
    pw.Font? footerFontBold,
  }) {
    if (settings.proposalStyle == 'corporateWave') {
      return _buildCorporateWavePdfCover(
        coverBytes: coverBytes,
        proposal: proposal,
        settings: settings,
        generationMonthly: generationMonthly,
        kwp: kwp,
        fontMontserratBlack: fontMontserratBlack,
        fontMontserratBold: fontMontserratBold,
        fontMontserratSemiBold: fontMontserratSemiBold,
      );
    }

    if (settings.proposalStyle == 'verticalSplit') {
      return _buildVerticalSplitPdfCover(
        coverBytes: coverBytes,
        proposal: proposal,
        settings: settings,
        generationMonthly: generationMonthly,
        kwp: kwp,
        fontMontserratBlack: fontMontserratBlack,
        fontMontserratBold: fontMontserratBold,
        fontMontserratSemiBold: fontMontserratSemiBold,
        headlineFontBold: headlineFontBold,
        headlineFontBlack: headlineFontBlack,
        rightBlockFontBold: rightBlockFontBold,
        rightBlockFontBlack: rightBlockFontBlack,
        footerFontBold: footerFontBold,
      );
    }

    // Dimensões A4 em pontos (595.28 x 841.89)
    const a4W = 595.28;
    const a4H = 841.89;
    final accentPdfColor = PdfColor.fromInt(settings.verticalSplitAccentColorValue);
    final accentHex = (settings.customDividerColor.isNotEmpty
            ? settings.customDividerColor
            : (settings.verticalSplitAccentColor.isNotEmpty ? settings.verticalSplitAccentColor : '#F59E0B'))
        .replaceAll('#', '')
        .trim();
    final accentSvgColor = '#${accentHex.isNotEmpty ? accentHex : 'F59E0B'}';
    final bottomAreaHex = (settings.customDividerBottomColor.isNotEmpty
            ? settings.customDividerBottomColor
            : '#FFFFFF')
        .replaceAll('#', '')
        .trim();
    final bottomAreaSvgColor = '#${bottomAreaHex.isNotEmpty ? bottomAreaHex : 'FFFFFF'}';

    final String resolvedTitle = settings.verticalSplitRightTitle
        .replaceAll('{cliente}', proposal.clientName)
        .replaceAll('{nome}', proposal.clientName);
    String resolvedSubtitle = settings.verticalSplitRightSubtitle
        .replaceAll('{cliente}', proposal.clientName)
        .replaceAll('{nome}', proposal.clientName);
    if (proposal.clientName.trim().isNotEmpty && resolvedSubtitle.toUpperCase() == 'FAMÍLIA SILVA') {
      final cNameUpper = proposal.clientName.trim().toUpperCase();
      resolvedSubtitle = cNameUpper.startsWith('FAMÍLIA') ? cNameUpper : 'FAMÍLIA $cNameUpper';
    }

    return pw.Stack(
      fit: pw.StackFit.expand,
      children: [
        // 1. Imagem de Fundo da Capa
        if (coverBytes != null)
          pw.Image(pw.MemoryImage(coverBytes), fit: pw.BoxFit.cover)
        else
          pw.Container(
            color: PdfColors.white,
          ),

        // 2. Separador Vetorial se for Capa Customizada (10 Estilos Matemáticos)
        if (settings.customDividerStyle >= 0)
          pw.SvgImage(
            svg: CoverDividerSvgBuilder.buildSvg(
              dividerType: settings.customDividerStyle,
              width: a4W,
              height: a4H,
              splitYRatio: 0.70,
              primaryColorHex: accentSvgColor,
              bottomAreaColorHex: bottomAreaSvgColor,
            ),
          ),

        // 3. Frase de Impacto da Foto (Headline & Subheadline)
        if (settings.verticalSplitShowHeadline)
          pw.Positioned(
            left: (a4W * settings.verticalSplitHeadlineLeft).clamp(0.0, a4W * 0.90),
            top: (a4H * settings.verticalSplitHeadlineTop).clamp(0.0, a4H * 0.90),
            child: pw.SizedBox(
              width: a4W * 0.70,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    settings.verticalSplitHeadline,
                    style: pw.TextStyle(
                      font: headlineFontBlack ?? fontMontserratBlack,
                      fontSize: settings.verticalSplitHeadlineFontSize,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromInt(settings.coverHeadlineColorValue),
                      lineSpacing: 2,
                    ),
                  ),
                  if (settings.verticalSplitShowHeadlineDivider) ...[
                    pw.SizedBox(height: 6),
                    pw.Container(
                      width: settings.verticalSplitHeadlineDividerWidth * 0.9,
                      height: settings.verticalSplitHeadlineDividerHeight * 0.9,
                      color: settings.verticalSplitHeadlineDividerColor.isNotEmpty
                          ? _parsePdfColor(settings.verticalSplitHeadlineDividerColor, fallback: accentPdfColor)
                          : accentPdfColor,
                    ),
                    pw.SizedBox(height: 10),
                  ] else ...[
                    pw.SizedBox(height: 10),
                  ],
                  pw.Text(
                    settings.verticalSplitSubheadline,
                    style: pw.TextStyle(
                      font: headlineFontBold ?? fontMontserratBold,
                      fontSize: 10.5,
                      color: PdfColor.fromInt(settings.coverHeadlineColorValue),
                      lineSpacing: 1.8,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // 4. Badges Informativos na Foto (Estilo limpo com ícones e divisores verticais)
        if (settings.verticalSplitShowLeftFooter && settings.verticalSplitFooterBadges.isNotEmpty)
          pw.Positioned(
            left: (a4W * settings.verticalSplitLeftFooterLeft).clamp(0.0, a4W * 0.90),
            top: a4H - (settings.verticalSplitLeftFooterBottom * a4H) - 20,
            child: pw.Row(
              mainAxisSize: pw.MainAxisSize.min,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                for (int i = 0; i < settings.verticalSplitFooterBadges.length; i++) ...[
                  pw.Row(
                    mainAxisSize: pw.MainAxisSize.min,
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      _buildPdfCoverCustomIcon(
                        settings.verticalSplitFooterBadges[i].iconKey,
                        12,
                        PdfColor.fromInt(settings.coverBadgesIconColorValue),
                      ),
                      pw.SizedBox(width: 5),
                      pw.Text(
                        settings.verticalSplitFooterBadges[i].label,
                        style: pw.TextStyle(
                          font: fontMontserratBold,
                          fontSize: 8.5,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromInt(settings.coverBadgesTextColorValue),
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                  if (i < settings.verticalSplitFooterBadges.length - 1)
                    pw.Container(
                      width: 1.5,
                      height: 11,
                      color: PdfColor.fromInt(settings.coverBadgesTextColorValue).luminance > 0.5
                          ? PdfColor.fromInt(0x60FFFFFF)
                          : PdfColor.fromInt(0x40000000),
                      margin: const pw.EdgeInsets.symmetric(horizontal: 7),
                    ),
                ],
              ],
            ),
          ),

        // 5. Bloco Institucional na Área Branca Preservada
        if (settings.verticalSplitShowRightBlock)
          pw.Positioned(
            left: a4W - (settings.verticalSplitRightBlockRight * a4W) - (a4W * 0.42),
            top: settings.verticalSplitRightBlockTop * a4H,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  resolvedTitle,
                  style: pw.TextStyle(
                    font: rightBlockFontBold ?? fontMontserratBold,
                    fontSize: settings.verticalSplitRightTitleFontSize,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromInt(settings.coverRightTitleColorValue),
                    letterSpacing: 4.5,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  resolvedSubtitle,
                  style: pw.TextStyle(
                    font: rightBlockFontBlack ?? fontMontserratBlack,
                    fontSize: settings.verticalSplitRightSubtitleFontSize,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromInt(settings.coverRightSubtitleColorValue),
                    letterSpacing: 1.5,
                  ),
                ),
                if (settings.verticalSplitShowRightDivider) ...[
                  pw.SizedBox(height: 9),
                  pw.Container(
                    width: settings.verticalSplitRightDividerWidth * 0.8,
                    height: settings.verticalSplitRightDividerHeight * 0.8,
                    color: settings.verticalSplitRightDividerColor.isNotEmpty
                        ? _parsePdfColor(settings.verticalSplitRightDividerColor, fallback: accentPdfColor)
                        : accentPdfColor,
                  ),
                  pw.SizedBox(height: 9),
                ] else ...[
                  pw.SizedBox(height: 10),
                ],
                pw.Text(
                  settings.verticalSplitRightTagline,
                  style: pw.TextStyle(
                    font: rightBlockFontBold ?? fontMontserratBold,
                    fontSize: 9.5,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromInt(settings.coverRightTaglineColorValue),
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),

        // 6. Logomarca Customizada Posicionada pelo Usuário
        if (settings.coverShowLogo && settings.companyLogoBase64 != null && settings.companyLogoBase64!.isNotEmpty)
          pw.Positioned(
            left: (a4W * settings.coverLogoPositionX).clamp(0.0, a4W - settings.coverLogoWidth),
            top: (a4H * settings.coverLogoPositionY).clamp(0.0, a4H - 50.0),
            child: pw.Image(
              pw.MemoryImage(base64Decode(
                settings.companyLogoBase64!.contains(',')
                    ? settings.companyLogoBase64!.split(',').last
                    : settings.companyLogoBase64!
              )),
              width: settings.coverLogoWidth,
              fit: pw.BoxFit.contain,
            ),
          ),

        // 7. Rodapé Institucional Posicionado pelo Usuário
        if (settings.verticalSplitShowRightFooter)
          pw.Positioned(
            left: a4W - (settings.verticalSplitRightFooterRight * a4W) - (a4W * 0.45),
            bottom: (a4H * settings.verticalSplitRightFooterBottom).clamp(10.0, a4H * 0.40),
            child: pw.SizedBox(
              width: a4W * 0.45,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  pw.Text(
                    settings.verticalSplitRightFooter,
                    style: pw.TextStyle(
                      font: footerFontBold ?? fontMontserratSemiBold,
                      fontSize: 9.0,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromInt(settings.coverFooterColorValue),
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Emissão: ${DateFormat('dd/MM/yyyy').format(proposal.createdAt)}  •  Validade: ${proposal.validityDays} dias  •  Proposta: ${proposal.proposalNumber}',
                    style: pw.TextStyle(
                      fontSize: 8.0,
                      color: PdfColor.fromInt(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // 8. Informações do Cliente e Usina Posicionadas pelo Usuário
        if (settings.coverShowClientInfo)
          pw.Positioned(
            left: (a4W * settings.coverClientInfoPositionX).clamp(0.0, a4W - 50.0),
            top: (a4H * settings.coverClientInfoPositionY).clamp(0.0, a4H - 30.0),
            child: pw.SizedBox(
              width: settings.coverClientInfoWidth.clamp(100.0, a4W),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  if (proposal.clientName.isNotEmpty)
                    pw.Text(
                      'Cliente: ${proposal.clientName}',
                      style: pw.TextStyle(
                        font: fontMontserratBold,
                        fontSize: settings.coverClientInfoFontSize,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromInt(settings.coverClientInfoColorValue),
                      ),
                      maxLines: 1,
                    ),
                  if (proposal.clientDocument != null && proposal.clientDocument!.trim().isNotEmpty) ...[
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'CPF/CNPJ: ${proposal.clientDocument!.trim()}',
                      style: pw.TextStyle(
                        font: fontMontserratBold,
                        fontSize: settings.coverClientInfoFontSize * 0.9,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromInt(settings.coverClientInfoSecondaryColorValue),
                      ),
                      maxLines: 1,
                    ),
                  ],
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Geração: ${_numberFormat.format(generationMonthly)} kWh/mês (${kwp.toStringAsFixed(2)} kWp)',
                    style: pw.TextStyle(
                      font: fontMontserratBold,
                      fontSize: settings.coverClientInfoFontSize * 0.9,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromInt(settings.coverClientInfoSecondaryColorValue),
                    ),
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          ),

        // 8. Textos Personalizados Extras Adicionados pelo Usuário
        for (final textItem in settings.customTextItems)
          pw.Positioned(
            left: textItem.x * a4W,
            top: textItem.y * a4H,
            child: pw.Text(
              textItem.text,
              style: pw.TextStyle(
                font: textItem.isBold ? fontMontserratBold : fontMontserratSemiBold,
                fontSize: textItem.fontSize,
                fontWeight: textItem.isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: PdfColor.fromInt(textItem.colorValue),
              ),
            ),
          ),

        // 9. Ícones Personalizados Extras Adicionados pelo Usuário
        for (final iconItem in settings.customIconItems)
          pw.Positioned(
            left: iconItem.x * a4W,
            top: iconItem.y * a4H,
            child: _buildPdfCoverCustomIcon(iconItem.iconKey, iconItem.size, PdfColor.fromInt(iconItem.colorValue)),
          ),




      ],
    );
  }

  static PdfColor _parsePdfColor(String hex, {double alpha = 1.0, PdfColor? fallback}) {
    try {
      var clean = hex.replaceAll('#', '').replaceAll('0x', '').trim();
      if (clean.length == 8) {
        clean = clean.substring(2);
      }
      if (clean.length == 6) {
        final r = int.parse(clean.substring(0, 2), radix: 16) / 255.0;
        final g = int.parse(clean.substring(2, 4), radix: 16) / 255.0;
        final b = int.parse(clean.substring(4, 6), radix: 16) / 255.0;
        return PdfColor(r, g, b, alpha);
      }
      return fallback ?? PdfColor.fromHex('#EAB308');
    } catch (_) {
      return fallback ?? PdfColor.fromHex('#EAB308');
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // LAYOUT MINIMALISTA PROGRAMÁTICO (CABEÇALHO & RODAPÉ NATIVOS / PERSONALIZADOS)
  // ───────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildProgrammaticPageLayout({
    required pw.Widget content,
    required String pageTitle,
    required int pageNumber,
    required int totalPages,
    required PdfColor primaryColor,
    required SolarSettingsModel settings,
    ProposalModel? proposal,
    pw.Font? fontBold,
    pw.Font? fontSemiBold,
    bool fullBleedContent = false,
  }) {
    final textDark = PdfColor.fromHex('#0F172A');
    final textMuted = PdfColor.fromHex('#64748B');
    final lineGrey = PdfColor.fromHex('#E2E8F0');
    final slogan = (settings.companySlogan != null && settings.companySlogan!.trim().isNotEmpty)
        ? settings.companySlogan!.trim().toUpperCase()
        : 'ENERGIA QUE TRANSFORMA';

    // SVG vetorial nítido de Painel Solar com Sol no canto esquerdo
    final hexR = (primaryColor.red * 255).round().toRadixString(16).padLeft(2, '0');
    final hexG = (primaryColor.green * 255).round().toRadixString(16).padLeft(2, '0');
    final hexB = (primaryColor.blue * 255).round().toRadixString(16).padLeft(2, '0');
    final colorHex = '#$hexR$hexG$hexB';

    final solarIconSvg = '''
<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="$colorHex" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
  <path d="M12 2v2"/>
  <path d="M4.93 4.93l1.41 1.41"/>
  <path d="M2 12h2"/>
  <path d="M19.07 4.93l-1.41 1.41"/>
  <path d="M6 10l-3 10h18l-3-10H6z"/>
  <path d="M6 15h12"/>
  <path d="M12 10v10"/>
</svg>
''';

    final customHeaderBg = settings.coverHeaderBgColor.isNotEmpty ? _parsePdfColor(settings.coverHeaderBgColor) : null;
    final customHeaderTxt = settings.coverHeaderTextColor.isNotEmpty ? _parsePdfColor(settings.coverHeaderTextColor) : null;
    final customHeaderIcon = settings.coverHeaderIconColor.isNotEmpty ? _parsePdfColor(settings.coverHeaderIconColor) : null;

    final customFooterBg = settings.coverFooterBgColor.isNotEmpty ? _parsePdfColor(settings.coverFooterBgColor) : null;
    final customFooterTxt = settings.coverFooterTextColor.isNotEmpty ? _parsePdfColor(settings.coverFooterTextColor) : null;
    final customFooterIcon = settings.coverFooterIconColor.isNotEmpty ? _parsePdfColor(settings.coverFooterIconColor) : null;

    pw.Widget topHeader;
    if (settings.coverShowHeader) {
      topHeader = _buildPdfCoverHeader(
        styleId: settings.coverHeaderStyle,
        text1: settings.coverHeaderText1.isNotEmpty ? settings.coverHeaderText1 : pageTitle,
        text2: settings.coverHeaderText2.isNotEmpty ? settings.coverHeaderText2 : (proposal?.proposalNumber ?? ''),
        text3: settings.coverHeaderText3.isNotEmpty ? settings.coverHeaderText3 : 'Página $pageNumber de $totalPages',
        accentColor: primaryColor,
        fontBold: fontBold,
        fontSemiBold: fontSemiBold,
        customBgColor: customHeaderBg,
        customTextColor: customHeaderTxt,
        customIconColor: customHeaderIcon,
      );
    } else {
      topHeader = pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 12),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Container(
                      width: 3.5,
                      height: 14,
                      decoration: pw.BoxDecoration(
                        color: primaryColor,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(1.5)),
                      ),
                    ),
                    pw.SizedBox(width: 8),
                    pw.Text(
                      pageTitle.toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 10.5,
                        fontWeight: pw.FontWeight.bold,
                        color: textDark,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                if (proposal != null && proposal.proposalNumber.isNotEmpty)
                  pw.Text(
                    proposal.proposalNumber,
                    style: pw.TextStyle(
                      fontSize: 8.5,
                      fontWeight: pw.FontWeight.bold,
                      color: textMuted,
                    ),
                  ),
              ],
            ),
            pw.SizedBox(height: 7),
            pw.Stack(
              children: [
                pw.Container(
                  height: 0.8,
                  width: double.infinity,
                  color: lineGrey,
                ),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Container(
                    height: 1.8,
                    width: 75,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    pw.Widget bottomFooter;
    if (settings.coverShowFooter) {
      bottomFooter = _buildPdfCoverFooter(
        styleId: settings.coverFooterStyle,
        text1: settings.coverFooterText1.trim(),
        text2: settings.coverFooterText2.trim(),
        text3: settings.coverFooterText3.trim(),
        text4: settings.coverFooterText4.trim(),
        accentColor: primaryColor,
        fontBold: fontBold,
        fontSemiBold: fontSemiBold,
        customBgColor: customFooterBg,
        customTextColor: customFooterTxt,
        customIconColor: customFooterIcon,
      );
    } else {
      bottomFooter = pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 12),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Stack(
              children: [
                pw.Container(
                  height: 0.8,
                  width: double.infinity,
                  color: lineGrey,
                ),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Container(
                    height: 1.8,
                    width: 75,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 7),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.SvgImage(
                      svg: solarIconSvg,
                      width: 14,
                      height: 14,
                    ),
                    pw.SizedBox(width: 6),
                    pw.Text(
                      slogan,
                      style: pw.TextStyle(
                        fontSize: 7.5,
                        fontWeight: pw.FontWeight.bold,
                        color: textMuted,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                pw.Text(
                  'Página $pageNumber de $totalPages',
                  style: pw.TextStyle(
                    fontSize: 8,
                    color: textMuted,
                    fontWeight: pw.FontWeight.normal,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        topHeader,
        pw.Expanded(
          child: fullBleedContent
              ? content
              : pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 12),
                  child: content,
                ),
        ),
        bottomFooter,
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // COMPONENTES DO ESTUDO SOLAR DE TELHADO & SOMBREAMENTO NA PROPOSTA
  // ───────────────────────────────────────────────────────────────────────────
  static String _formatHour(double h) {
    final hour = h.floor();
    final minute = ((h - hour) * 60).round();
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  static pw.Widget _buildStudyKpiCard({
    required String title,
    required String value,
    required String sub,
    required PdfColor primaryColor,
  }) {
    final textMuted = PdfColor.fromHex('#64748B');
    final cardBg = PdfColor.fromHex('#F8FAFC');
    final borderCol = PdfColor.fromHex('#E2E8F0');

    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: pw.BoxDecoration(
          color: cardBg,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          border: pw.Border.all(color: borderCol, width: 0.8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(fontSize: 6.8, fontWeight: pw.FontWeight.bold, color: textMuted),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              value,
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: primaryColor),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              sub,
              style: pw.TextStyle(fontSize: 6.5, color: textMuted),
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildTableHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 7.0, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#475569')),
      ),
    );
  }

  static pw.Widget _buildTableCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 7.2, color: PdfColor.fromHex('#0F172A')),
      ),
    );
  }

  /// Constrói o miolo da página de Resumo Técnico do Estudo de Telhado
  static pw.Widget _buildStudySummaryPageContent({
    required RoofStudyModel study,
    required PdfColor primaryColor,
    required SolarSettingsModel settings,
    List<RoofStudyPhoto>? photos,
  }) {
    final textDark = PdfColor.fromHex('#0F172A');
    final textMuted = PdfColor.fromHex('#64748B');
    final cardBg = PdfColor.fromHex('#F8FAFC');
    final borderCol = PdfColor.fromHex('#E2E8F0');

    pw.MemoryImage? snapshotImage;

    // 1. Tenta recuperar preferencialmente a imagem HD do estudo (hdSnapshotBase64)
    final hdSnap = study.hdSnapshotBase64;
    if (hdSnap != null && hdSnap.isNotEmpty) {
      try {
        final clean = hdSnap.contains(',') ? hdSnap.split(',').last : hdSnap;
        snapshotImage = pw.MemoryImage(base64Decode(clean));
      } catch (_) {}
    }

    // 2. Tenta recuperar imagem em alta resolução da lista de fotos (photos ou studyPhotos)
    if (snapshotImage == null) {
      final allPhotos = (photos != null && photos.isNotEmpty) ? photos : study.studyPhotos;
      for (final photo in allPhotos) {
        if (photo.imageBase64.isNotEmpty) {
          try {
            final clean = photo.imageBase64.contains(',')
                ? photo.imageBase64.split(',').last
                : photo.imageBase64;
            snapshotImage = pw.MemoryImage(base64Decode(clean));
            break;
          } catch (_) {}
        }
      }
    }

    // 3. Fallback para droneImageUrl caso seja data base64
    if (snapshotImage == null && study.droneImageUrl != null && study.droneImageUrl!.isNotEmpty) {
      try {
        final url = study.droneImageUrl!;
        if (url.startsWith('data:image') || url.length > 500) {
          final clean = url.contains(',') ? url.split(',').last : url;
          snapshotImage = pw.MemoryImage(base64Decode(clean));
        }
      } catch (_) {}
    }

    // 4. Fallback final para thumbnailBase64 caso nada mais esteja disponível
    if (snapshotImage == null && study.thumbnailBase64 != null && study.thumbnailBase64!.isNotEmpty) {
      try {
        final clean = study.thumbnailBase64!.contains(',')
            ? study.thumbnailBase64!.split(',').last
            : study.thumbnailBase64!;
        snapshotImage = pw.MemoryImage(base64Decode(clean));
      } catch (_) {}
    }

    final totalModules = study.totalModulesCount;
    final totalKwp = study.totalKwp;
    final estimatedGen = study.estimatedMonthlyKwh;
    final hsp = study.dailyHsp ?? 5.0;

    final sections = study.sections.isNotEmpty
        ? study.sections
        : (study.mapsSections.isNotEmpty ? study.mapsSections : study.droneSections);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // 1. Linha com 4 KPIs Executivos do Estudo
        pw.Row(
          children: [
            _buildStudyKpiCard(
              title: 'POTÊNCIA DO ARRANJO',
              value: '${totalKwp.toStringAsFixed(2)} kWp',
              sub: 'Capacidade Total Instalada',
              primaryColor: primaryColor,
            ),
            pw.SizedBox(width: 8),
            _buildStudyKpiCard(
              title: 'MÓDULOS FOTOVOLTAICOS',
              value: '$totalModules un',
              sub: 'Placas dimensionadas',
              primaryColor: primaryColor,
            ),
            pw.SizedBox(width: 8),
            _buildStudyKpiCard(
              title: 'GERAÇÃO MÉDIA MENSAL',
              value: '~${estimatedGen.toStringAsFixed(0)} kWh',
              sub: 'Estimativa mensal prevista',
              primaryColor: primaryColor,
            ),
            pw.SizedBox(width: 8),
            _buildStudyKpiCard(
              title: 'IRRADIAÇÃO SOLAR LOCAL',
              value: '${hsp.toStringAsFixed(2)} HSP',
              sub: study.stateUf != null ? 'Atlas Solar / CRESESB (${study.stateUf})' : 'Horas de Sol Pico',
              primaryColor: primaryColor,
            ),
          ],
        ),
        pw.SizedBox(height: 12),

        // 2. Imagem da Usina no Telhado / Implantação Solar
        pw.Expanded(
          flex: 5,
          child: pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: cardBg,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
              border: pw.Border.all(color: borderCol, width: 1),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'LAYOUT DO TELHADO & ARRANJO FOTOVOLTAICO 3D',
                      style: pw.TextStyle(
                        fontSize: 8.5,
                        fontWeight: pw.FontWeight.bold,
                        color: primaryColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                    pw.Text(
                      study.formattedAddress.isNotEmpty ? study.formattedAddress : 'Local de Instalação Mapeado',
                      style: pw.TextStyle(fontSize: 7.5, color: textMuted),
                    ),
                  ],
                ),
                pw.SizedBox(height: 6),
                pw.Expanded(
                  child: snapshotImage != null
                      ? pw.Center(
                          child: pw.ClipRRect(
                            horizontalRadius: 6,
                            verticalRadius: 6,
                            child: pw.Image(snapshotImage, fit: pw.BoxFit.contain),
                          ),
                        )
                      : pw.Center(
                          child: pw.Column(
                            mainAxisAlignment: pw.MainAxisAlignment.center,
                            children: [
                              pw.Text(
                                '📐 Estudo Geométrico Computadorizado',
                                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: textDark),
                              ),
                              pw.SizedBox(height: 4),
                              pw.Text(
                                'Georreferenciamento e disposição angular dos módulos no plano de cobertura.',
                                style: pw.TextStyle(fontSize: 9, color: textMuted),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
        pw.SizedBox(height: 12),

        // 3. Detalhamento Técnico das Águas e Parecer de Engenharia
        pw.Expanded(
          flex: 4,
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Detalhamento das Águas / Planos de Telhado
              pw.Expanded(
                flex: 6,
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: cardBg,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                    border: pw.Border.all(color: borderCol, width: 1),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'DISTRIBUIÇÃO DOS MÓDULOS POR ÁGUA DO TELHADO',
                        style: pw.TextStyle(
                          fontSize: 8.5,
                          fontWeight: pw.FontWeight.bold,
                          color: textDark,
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Table(
                        border: pw.TableBorder(
                          horizontalInside: pw.BorderSide(color: borderCol, width: 0.5),
                        ),
                        children: [
                          pw.TableRow(
                            decoration: pw.BoxDecoration(color: PdfColor.fromHex('#F1F5F9')),
                            children: [
                              _buildTableHeaderCell('Água / Plano'),
                              _buildTableHeaderCell('Placas'),
                              _buildTableHeaderCell('Potência'),
                              _buildTableHeaderCell('Estrutura'),
                              _buildTableHeaderCell('Inclinação'),
                            ],
                          ),
                          for (int i = 0; i < (sections.isNotEmpty ? sections.length : 1); i++) ...[
                            if (sections.isNotEmpty)
                              pw.TableRow(
                                children: [
                                  _buildTableCell(sections[i].name),
                                  _buildTableCell('${sections[i].activeModuleCount} un'),
                                  _buildTableCell('${((sections[i].activeModuleCount * sections[i].moduleSpec.watts) / 1000.0).toStringAsFixed(2)} kWp'),
                                  _buildTableCell(sections[i].roofType.name == 'gabledCeramic' ? 'Cerâmico' : (sections[i].roofType.name == 'monoPitch' ? 'Metálico' : 'Platibanda')),
                                  _buildTableCell('${sections[i].tiltDegrees.toStringAsFixed(0)}°'),
                                ],
                              )
                            else
                              pw.TableRow(
                                children: [
                                  _buildTableCell('Plano 1'),
                                  _buildTableCell('$totalModules un'),
                                  _buildTableCell('${totalKwp.toStringAsFixed(2)} kWp'),
                                  _buildTableCell('Telhado Padrão'),
                                  _buildTableCell('12°'),
                                ],
                              ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 8),

              // Parecer de Engenharia
              pw.Expanded(
                flex: 4,
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#F0FDF4'),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                    border: pw.Border.all(color: PdfColor.fromHex('#BBF7D0'), width: 1),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        children: [
                          pw.Container(
                            width: 6,
                            height: 6,
                            decoration: const pw.BoxDecoration(
                              color: PdfColor.fromInt(0xFF10B981),
                              shape: pw.BoxShape.circle,
                            ),
                          ),
                          pw.SizedBox(width: 6),
                          pw.Text(
                            'PARECER DE VIABILIDADE TÉCNICA',
                            style: pw.TextStyle(
                              fontSize: 8.0,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColor.fromHex('#166534'),
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        'A disposição foi planejada respeitando recuos de segurança para circulação técnica e manutenção, além de evitar zonas de turbulência e sombreamento severo por platibandas ou obstáculos.',
                        style: pw.TextStyle(fontSize: 7.2, color: PdfColor.fromHex('#15803D'), lineSpacing: 1.3),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        'Orientação angular otimizada para capturar o maior índice de irradiação solar ao longo do ano.',
                        style: pw.TextStyle(fontSize: 7.2, color: PdfColor.fromHex('#15803D'), lineSpacing: 1.3),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Constrói o miolo de uma página dedicada a uma foto grande da Simulação Solar
  static pw.Widget _buildStudyPhotoPageContent({
    required RoofStudyPhoto photo,
    required RoofStudyModel study,
    required PdfColor primaryColor,
    required SolarSettingsModel settings,
  }) {
    final textDark = PdfColor.fromHex('#0F172A');
    final textMuted = PdfColor.fromHex('#64748B');
    final cardBg = PdfColor.fromHex('#F8FAFC');
    final borderCol = PdfColor.fromHex('#E2E8F0');

    pw.MemoryImage? photoImg;
    if (photo.imageBase64.isNotEmpty) {
      try {
        final clean = photo.imageBase64.contains(',')
            ? photo.imageBase64.split(',').last
            : photo.imageBase64;
        photoImg = pw.MemoryImage(base64Decode(clean));
      } catch (_) {}
    }

    final totalMods = photo.totalModules ?? study.totalModulesCount;
    final shaded = photo.shadedCount ?? 0;
    final sunCount = (totalMods - shaded).clamp(0, totalMods);
    final ratio = photo.sunRatio ?? (totalMods > 0 ? (sunCount / totalMods) : 1.0);
    final hourFormatted = _formatHour(photo.hourOfDay);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // 1. Barra de Diagnóstico Astronômico e Sombreamento
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: pw.BoxDecoration(
            color: cardBg,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            border: pw.Border.all(color: borderCol, width: 1),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Row(
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: pw.BoxDecoration(
                      color: primaryColor,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    ),
                    child: pw.Text(
                      'HORÁRIO: $hourFormatted',
                      style: pw.TextStyle(
                        fontSize: 8.5,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 12),
                  pw.Text(
                    'Altitude Solar: ${photo.sunElevation?.toStringAsFixed(1) ?? '--'}°  •  Azimute: ${photo.sunAzimuth?.toStringAsFixed(1) ?? '--'}°',
                    style: pw.TextStyle(fontSize: 8.0, color: textDark, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
              pw.Row(
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: pw.BoxDecoration(
                      color: ratio >= 0.8
                          ? const PdfColor.fromInt(0xFFD1FAE5)
                          : const PdfColor.fromInt(0xFFFEF3C7),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
                    ),
                    child: pw.Text(
                      '${(ratio * 100).toStringAsFixed(0)}% APROVEITAMENTO SOLAR',
                      style: pw.TextStyle(
                        fontSize: 8.0,
                        fontWeight: pw.FontWeight.bold,
                        color: ratio >= 0.8
                            ? const PdfColor.fromInt(0xFF059669)
                            : const PdfColor.fromInt(0xFFD97706),
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Text(
                    '$sunCount de $totalMods módulos livres',
                    style: pw.TextStyle(fontSize: 8.0, color: textMuted),
                  ),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 10),

        // 2. Imagem Grande Nítida da Simulação
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
              border: pw.Border.all(color: borderCol, width: 1.2),
            ),
            child: photoImg != null
                ? pw.Center(
                    child: pw.ClipRRect(
                      horizontalRadius: 6,
                      verticalRadius: 6,
                      child: pw.Image(photoImg, fit: pw.BoxFit.contain),
                    ),
                  )
                : pw.Center(
                    child: pw.Text('Registro fotográfico indisponível', style: pw.TextStyle(fontSize: 10, color: textMuted)),
                  ),
          ),
        ),
        pw.SizedBox(height: 8),

        // 3. Rodapé Explicativo do Estudo
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#F8FAFC'),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          ),
          child: pw.Text(
            'Nota: Simulação de radiação e sombreamento em tempo real calculada conforme as coordenadas geográficas (${study.latitude.toStringAsFixed(4)}, ${study.longitude.toStringAsFixed(4)}) e inclinação geométrica das águas.',
            style: pw.TextStyle(fontSize: 7.0, color: textMuted),
            textAlign: pw.TextAlign.center,
          ),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // PÁGINA 2: APRESENTAÇÃO & ESCOPO (DINÂMICOS & TEMPLATES)
  // ───────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildPage2Content(
    PdfColor primaryColor, {
    List<ProposalPageCard>? customCards,
    bool showIllustration = true,
  }) {
    final hex = _pdfColorToHex(primaryColor);

    if (customCards != null && customCards.isNotEmpty) {
      final List<pw.Widget> cardRows = [];
      for (int i = 0; i < customCards.length; i += 2) {
        final c1 = customCards[i];
        final c2 = (i + 1 < customCards.length) ? customCards[i + 1] : null;

        cardRows.add(
          pw.Row(
            children: [
              pw.Expanded(
                child: _buildInfoCardBadge(
                  title: c1.title,
                  description: c1.description,
                  svgIcon: _resolveSolarIcon(c1.iconKey, hex),
                ),
              ),
              if (c2 != null) ...[
                pw.SizedBox(width: 14),
                pw.Expanded(
                  child: _buildInfoCardBadge(
                    title: c2.title,
                    description: c2.description,
                    svgIcon: _resolveSolarIcon(c2.iconKey, hex),
                  ),
                ),
              ] else
                pw.Expanded(child: pw.SizedBox()),
            ],
          ),
        );
        cardRows.add(pw.SizedBox(height: 12));
      }

      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.SizedBox(height: 4),
          pw.Text(
            'Diferenciais & Escopo da Usina Solar',
            style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A')),
          ),
          pw.SizedBox(height: 14),
          ...cardRows,
        ],
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.SizedBox(height: 4),
        pw.Text(
          'Por que escolher a nossa solução solar?',
          style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A')),
        ),
        pw.SizedBox(height: 14),

        // 4 Cards de Apresentação (2x2) com Badges de Ícone no Topo
        pw.Row(
          children: [
            pw.Expanded(
              child: _buildInfoCardBadge(
                title: 'Confiança se conquista',
                description: 'Atuamos do início ao fim da instalação, inclusive com pós-venda especializado e equipe própria dedicada.',
                svgIcon: SolarPdfIcons.shieldCheck(hex),
              ),
            ),
            pw.SizedBox(width: 14),
            pw.Expanded(
              child: _buildInfoCardBadge(
                title: 'Bom negócio',
                description: 'Você se torna produtor da sua própria energia: investe com retorno rápido e lucra por mais de 25 anos.',
                svgIcon: SolarPdfIcons.dollar(hex),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 14),
        pw.Row(
          children: [
            pw.Expanded(
              child: _buildInfoCardBadge(
                title: 'Tecnologia de ponta',
                description: 'Trabalhamos exclusivamente com as melhores marcas globais de módulos Tier 1 e inversores certificados.',
                svgIcon: SolarPdfIcons.solarTech(hex),
              ),
            ),
            pw.SizedBox(width: 14),
            pw.Expanded(
              child: _buildInfoCardBadge(
                title: 'Zero dor de cabeça',
                description: 'Processo ágil, seguro e padronizado. Instalação rápida concluída em poucos dias sem obras pesadas.',
                svgIcon: SolarPdfIcons.thumbsUp(hex),
              ),
            ),
          ],
        ),

        pw.SizedBox(height: 24),
        pw.Text(
          'Escopo do Projeto (Turn-Key)',
          style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A')),
        ),
        pw.SizedBox(height: 14),

        // 4 Cards de Escopo (2x2) com Badges de Ícone no Topo
        pw.Row(
          children: [
            pw.Expanded(
              child: _buildInfoCardBadge(
                title: 'Solução completa',
                description: 'Projeto Turn-Key integral: cuidamos do projeto executivo, ART, montagem, homologação e concessionária.',
                svgIcon: SolarPdfIcons.lightbulb(hex),
              ),
            ),
            pw.SizedBox(width: 14),
            pw.Expanded(
              child: _buildInfoCardBadge(
                title: 'Aplicativo gratuito',
                description: 'Acompanhe na palma da mão, em tempo real, a geração de energia e a economia acumulada da sua usina 24h.',
                svgIcon: SolarPdfIcons.smartphone(hex),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 14),
        pw.Row(
          children: [
            pw.Expanded(
              child: _buildInfoCardBadge(
                title: 'Frete e seguro inclusos',
                description: 'Equipamentos entregues com frete e seguro 100% cobertos diretamente no endereço da instalação da usina.',
                svgIcon: SolarPdfIcons.truck(hex),
              ),
            ),
            pw.SizedBox(width: 14),
            pw.Expanded(
              child: _buildInfoCardBadge(
                title: 'Certificação e garantias',
                description: 'Módulos e inversores homologados pelo INMETRO, com até 25 anos de garantia de fábrica estendida.',
                svgIcon: SolarPdfIcons.award(hex),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static String _resolveSolarIcon(String? iconKey, String hex) {
    switch (iconKey?.toLowerCase()) {
      case 'shield':
      case 'security':
      case 'lock':
        return SolarPdfIcons.shieldCheck(hex);
      case 'dollar':
      case 'money':
      case 'coins':
      case 'finance':
        return SolarPdfIcons.dollar(hex);
      case 'tech':
      case 'solar_power':
      case 'solar_tech':
        return SolarPdfIcons.solarTech(hex);
      case 'like':
      case 'thumbs_up':
      case 'thumb_up':
        return SolarPdfIcons.thumbsUp(hex);
      case 'lightbulb':
      case 'light':
      case 'lamp':
        return SolarPdfIcons.lightbulb(hex);
      case 'smartphone':
      case 'phone':
      case 'app':
        return SolarPdfIcons.smartphone(hex);
      case 'truck':
      case 'shipping':
      case 'freight':
        return SolarPdfIcons.truck(hex);
      case 'award':
      case 'cert':
      case 'star':
        return SolarPdfIcons.award(hex);
      case 'bolt':
      case 'energy':
      case 'power':
        return SolarPdfIcons.bolt(hex);
      case 'panel':
      case 'solar_panel':
      default:
        return SolarPdfIcons.solarPanel(hex);
    }
  }

  static pw.Widget _buildCustomPageContent(
    ProposalCustomPage page,
    PdfColor primaryColor,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (page.cards.isNotEmpty)
          pw.Wrap(
            spacing: 12,
            runSpacing: 12,
            children: page.cards.map((c) {
              return pw.Container(
                width: 250,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex(c.cardBgColorHex != null && c.cardBgColorHex!.isNotEmpty ? c.cardBgColorHex! : '#F8FAFC'),
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(c.title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColor.fromHex('#0F172A'))),
                    pw.SizedBox(height: 4),
                    pw.Text(c.description, style: pw.TextStyle(fontSize: 9.5, color: PdfColor.fromHex('#475569'))),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  static pw.Widget _buildInfoCardBadge({
    required String title,
    required String description,
    required String svgIcon,
  }) {
    return pw.Stack(
      alignment: pw.Alignment.topCenter,
      children: [
        // Card Retangular Branco com dimensões ampliadas
        pw.Container(
          width: double.infinity,
          height: 100,
          margin: const pw.EdgeInsets.only(top: 15),
          padding: const pw.EdgeInsets.only(top: 22, bottom: 10, left: 14, right: 14),
          decoration: pw.BoxDecoration(
            color: PdfColors.white,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
            border: pw.Border.all(color: PdfColor.fromHex('#CBD5E1'), width: 1.0),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(
                title,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontSize: 11.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A')),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                description,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontSize: 8.5, color: PdfColor.fromHex('#475569'), height: 1.25),
              ),
            ],
          ),
        ),

        // Badge Circular Sobreposto no Topo
        pw.Positioned(
          top: 0,
          child: pw.Container(
            width: 30,
            height: 30,
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              shape: pw.BoxShape.circle,
              border: pw.Border.all(color: PdfColor.fromHex('#CBD5E1'), width: 1.2),
            ),
            child: pw.Center(
              child: pw.SvgImage(
                svg: svgIcon,
                width: 16,
                height: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // PÁGINA 3: SUA USINA
  // ───────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildPage3Content({
    required double kwp,
    required int modulesCount,
    required int moduleWatts,
    required String inverterModel,
    required double inverterKw,
    required String roofType,
    required double generationMonthly,
    required double occupiedArea,
    required PdfColor primaryColor,
    required PdfColor secondaryColor,
    Uint8List? houseImageBytes,
  }) {
    final hasKwInModel = RegExp(r'\b\d+(?:[\.,]\d+)?\s*kwp?\b', caseSensitive: false)
        .hasMatch(inverterModel);
    final inverterDisplay = hasKwInModel
        ? inverterModel
        : '$inverterModel • ${inverterKw.toStringAsFixed(0)} kW';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // 1. Foto Panorâmica da Residência com Usina Solar (Full-Bleed Horizontal)
        if (houseImageBytes != null && houseImageBytes.isNotEmpty)
          pw.SizedBox(
            height: 242,
            width: double.infinity,
            child: pw.Image(
              pw.MemoryImage(houseImageBytes),
              fit: pw.BoxFit.cover,
            ),
          )
        else
          pw.Container(
            height: 180,
            width: double.infinity,
            color: PdfColor.fromHex('#0F172A'),
          ),

        // 2. Faixa Azul-Marinho Escura com Ícone, Divisor Vertical e Título (Full-Bleed Horizontal)
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 14),
          color: secondaryColor,
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Container(
                width: 44,
                height: 44,
                decoration: pw.BoxDecoration(
                  color: primaryColor,
                  shape: pw.BoxShape.circle,
                ),
                child: pw.Center(
                  child: pw.SvgImage(
                    svg: SolarPdfIcons.solarTech('#FFFFFF', size: 26),
                    width: 26,
                    height: 26,
                  ),
                ),
              ),
              pw.SizedBox(width: 16),
              pw.Container(
                width: 1.5,
                height: 38,
                color: PdfColors.white,
              ),
              pw.SizedBox(width: 16),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Text(
                      'Kit Solar Fotovoltaico de Alta Eficiência',
                      style: pw.TextStyle(
                        fontSize: 17.5,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      'Módulos Monocristalinos & Inversor Grid-Tie com Conexão Wi-Fi Integrada',
                      style: pw.TextStyle(
                        fontSize: 9.8,
                        color: const PdfColor.fromInt(0xFFE2E8F0),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 3. Especificações Técnicas + 3 Cards Inferiores
        pw.Expanded(
          child: pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(28, 10, 28, 14),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                _buildTechRow(
                  label: 'Potência do Sistema:',
                  value: '${kwp.toStringAsFixed(2)} kWp',
                  svgIcon: SolarPdfIcons.bolt('#FFFFFF'),
                  primaryColor: primaryColor,
                  isBold: true,
                ),
                _buildTechRow(
                  label: 'Quantidade de Painéis:',
                  value: '$modulesCount módulos',
                  svgIcon: SolarPdfIcons.solarPanel('#FFFFFF'),
                  primaryColor: primaryColor,
                ),
                _buildTechRow(
                  label: 'Potência do Painel Solar:',
                  value: '$moduleWatts Watts',
                  svgIcon: SolarPdfIcons.sunWatt('#FFFFFF'),
                  primaryColor: primaryColor,
                ),
                _buildTechRow(
                  label: 'Modelo e Potência do Inversor:',
                  value: inverterDisplay,
                  svgIcon: SolarPdfIcons.inverter('#FFFFFF'),
                  primaryColor: primaryColor,
                ),
                _buildTechRow(
                  label: 'Tipo de Estrutura:',
                  value: roofType,
                  svgIcon: SolarPdfIcons.roof('#FFFFFF'),
                  primaryColor: primaryColor,
                ),
                _buildTechRow(
                  label: 'Produção Média de Energia:',
                  value: '${generationMonthly.toStringAsFixed(2)} kWh/mês',
                  svgIcon: SolarPdfIcons.trendingUp('#FFFFFF'),
                  primaryColor: primaryColor,
                ),
                _buildTechRow(
                  label: 'Área Estimada Ocupada:',
                  value: '${occupiedArea.toStringAsFixed(2)} m²',
                  svgIcon: SolarPdfIcons.rulerSquare('#FFFFFF'),
                  primaryColor: primaryColor,
                ),

                pw.Spacer(),

                // 3 Cards de Destaque Executivo de Garantia & Engenharia
                pw.Row(
                  children: [
                    pw.Expanded(
                      child: _buildPage3MiniCard(
                        title: '25 Anos de Garantia',
                        subtitle: 'Módulos Tier 1 com garantia linear.',
                        iconSvg: SolarPdfIcons.award('#FFFFFF'),
                        primaryColor: primaryColor,
                      ),
                    ),
                    pw.SizedBox(width: 10),
                    pw.Expanded(
                      child: _buildPage3MiniCard(
                        title: 'Monitoramento Wi-Fi',
                        subtitle: 'Geração 24h no app do celular.',
                        iconSvg: SolarPdfIcons.smartphone('#FFFFFF'),
                        primaryColor: primaryColor,
                      ),
                    ),
                    pw.SizedBox(width: 10),
                    pw.Expanded(
                      child: _buildPage3MiniCard(
                        title: 'Engenharia Turn-Key',
                        subtitle: 'Projeto executivo e homologação.',
                        iconSvg: SolarPdfIcons.shieldCheck('#FFFFFF'),
                        primaryColor: primaryColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildPage3MiniCard({
    required String title,
    required String subtitle,
    required String iconSvg,
    required PdfColor primaryColor,
  }) {
    return pw.Container(
      height: 70,
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#F1F5F9'),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
        border: pw.Border.all(color: PdfColor.fromHex('#CBD5E1'), width: 0.9),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(
            width: 30,
            height: 30,
            decoration: pw.BoxDecoration(
              color: primaryColor,
              shape: pw.BoxShape.circle,
            ),
            child: pw.Center(
              child: pw.SvgImage(
                svg: iconSvg,
                width: 15,
                height: 15,
              ),
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: 9.2,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#0F172A'),
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  subtitle,
                  style: pw.TextStyle(
                    fontSize: 7.6,
                    color: PdfColor.fromHex('#334155'),
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTechRow({
    required String label,
    required String value,
    required String svgIcon,
    required PdfColor primaryColor,
    bool isBold = false,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 7.0, horizontal: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColor.fromInt(0xFFCBD5E1), width: 0.7)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Expanded(
            flex: 5,
            child: pw.Row(
              children: [
                pw.Container(
                  width: 26,
                  height: 26,
                  decoration: pw.BoxDecoration(
                    color: primaryColor,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6.5)),
                  ),
                  child: pw.Center(
                    child: pw.SvgImage(
                      svg: svgIcon,
                      width: 14,
                      height: 14,
                    ),
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: pw.Text(
                    label,
                    style: pw.TextStyle(
                      fontSize: 10.8,
                      color: PdfColor.fromHex('#0F172A'),
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            flex: 5,
            child: pw.Text(
              value,
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                fontSize: 11.2,
                fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.bold,
                color: PdfColor.fromHex('#0F172A'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // PÁGINA 4: ITENS DA USINA & CONDIÇÕES
  // ───────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildPage4Content({
    required ProposalModel proposal,
    required ProposalItemModel solarPlantItem,
    required PdfColor primaryColor,
    required PdfColor secondaryColor,
    int modulesCount = 12,
    int moduleWatts = 620,
    String inverterModel = 'Inversor Solar Grid-Tie',
    double inverterKw = 6.0,
    String roofType = 'Fibrocimento',
  }) {
    final rawComponents = solarPlantItem.solarComponents ?? [];
    final List<String> equipmentItems = [];

    if (rawComponents.isNotEmpty) {
      equipmentItems.addAll(rawComponents);
      final joinedLower = rawComponents.join(' ').toLowerCase();

      if (!joinedLower.contains('estrutura') &&
          !joinedLower.contains('perfil') &&
          !joinedLower.contains('fixa')) {
        equipmentItems.add('Estrutura de fixação para telha ${roofType.toLowerCase()}');
      }
      if (!joinedLower.contains('string') &&
          !joinedLower.contains('dps') &&
          !joinedLower.contains('proteção') &&
          !joinedLower.contains('protecao')) {
        equipmentItems.add('Quadro string box CC/CA com DPS e proteção');
      }
      if (!joinedLower.contains('cabo') && !joinedLower.contains('mc4')) {
        equipmentItems.add('Cabos solares 1,8 kV com proteção UV e conectores MC4');
      }
      if (!joinedLower.contains('homolog') &&
          !joinedLower.contains('engenharia') &&
          !joinedLower.contains('projeto')) {
        equipmentItems.add('Engenharia, projeto executivo, ART e homologação');
      }
    } else {
      equipmentItems.addAll([
        '$modulesCount× módulo fotovoltaico monocristalino $moduleWatts W Tier 1',
        '$inverterModel (${inverterKw.toStringAsFixed(0)} kW) com monitoramento Wi-Fi',
        'Estrutura de fixação para telha ${roofType.toLowerCase()}',
        'Quadro string box CC/CA com DPS e proteção',
        'Cabos solares 1,8 kV com proteção UV e conectores MC4',
        'Engenharia, projeto executivo, ART e homologação',
      ]);
    }

    final primaryHex = _pdfColorToHex(primaryColor);
    final heroIllustrationSvg = '''
<svg viewBox="0 0 330 200" width="215" height="130">
  <circle cx="244" cy="62" r="43" fill="#164263"/>
  <circle cx="244" cy="62" r="28" fill="$primaryHex"/>
  <path d="M37 172h260M153 150v22m-37 0h75M218 123h31v25h15" fill="none" stroke="#71c4e5" stroke-width="3" stroke-linecap="round"/>
  <polygon points="59.1,72 243.1,72 216.1,155 32.1,155" fill="#0a6f9e" stroke="#82d1ed" stroke-width="3" stroke-linejoin="round"/>
  <path d="M50.3 99 L234.3 99 M41.2 127 L225.2 127 M105.1 72 L78.1 155 M151.1 72 L124.1 155 M197.1 72 L170.1 155" fill="none" stroke="#82d1ed" stroke-width="2"/>
  <rect x="264" y="111" width="43" height="54" rx="8" fill="#e1f5fc"/>
  <rect x="274" y="122" width="23" height="12" rx="3" fill="$primaryHex"/>
  <path d="M284 141l-5 7h6l-3 7 10-11h-7l3-3" fill="$primaryHex"/>
</svg>
''';

    final isCompactList = equipmentItems.length > 6;
    final rowVerticalPad = isCompactList ? 6.0 : 8.5;

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 26, vertical: 12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // 1. Hero Banner Escuro com Ilustração Vetorial
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 22, vertical: 18),
            decoration: pw.BoxDecoration(
              color: secondaryColor,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(14)),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Expanded(
                  flex: 55,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.Text(
                        'Equipamentos e\ncomponentes inclusos',
                        style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                          lineSpacing: 2,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'Conheça o conjunto fotovoltaico da sua proposta.',
                        style: const pw.TextStyle(
                          fontSize: 10.5,
                          color: PdfColor.fromInt(0xFFC3E6F4),
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  flex: 45,
                  child: pw.Center(
                    child: pw.SvgImage(
                      svg: heroIllustrationSvg,
                      width: 205,
                      height: 124,
                    ),
                  ),
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 14),

          // 2. Seção: Itens inclusos no conjunto
          pw.Text(
            'Itens inclusos no conjunto',
            style: pw.TextStyle(
              fontSize: 15,
              fontWeight: pw.FontWeight.bold,
              color: const PdfColor.fromInt(0xFF102C49),
            ),
          ),
          pw.SizedBox(height: 8),

          pw.Container(
            decoration: pw.BoxDecoration(
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(11)),
              border: pw.Border.all(color: const PdfColor.fromInt(0xFFD8E5EE), width: 1.0),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                for (int i = 0; i < equipmentItems.length; i++) ...[
                  if (i > 0)
                    pw.Container(
                      height: 0.8,
                      color: const PdfColor.fromInt(0xFFD8E5EE),
                    ),
                  pw.Container(
                    padding: pw.EdgeInsets.symmetric(horizontal: 12, vertical: rowVerticalPad),
                    decoration: pw.BoxDecoration(
                      color: i.isEven
                          ? const PdfColor.fromInt(0xFFF5F9FC)
                          : PdfColors.white,
                      borderRadius: i == 0
                          ? const pw.BorderRadius.vertical(top: pw.Radius.circular(10))
                          : (i == equipmentItems.length - 1
                              ? const pw.BorderRadius.vertical(bottom: pw.Radius.circular(10))
                              : null),
                    ),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Container(
                          width: 26,
                          height: 26,
                          decoration: pw.BoxDecoration(
                            color: primaryColor,
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6.5)),
                          ),
                          child: pw.Center(
                            child: pw.SvgImage(
                              svg: _getComponentIcon(equipmentItems[i], '#FFFFFF'),
                              width: 15,
                              height: 15,
                            ),
                          ),
                        ),
                        pw.SizedBox(width: 11),
                        pw.Expanded(
                          child: pw.Text(
                            equipmentItems[i],
                            style: pw.TextStyle(
                              fontSize: isCompactList ? 9.5 : 10.5,
                              fontWeight: pw.FontWeight.bold,
                              color: const PdfColor.fromInt(0xFF102C49),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          pw.Spacer(),

          // 3. Seção: Formas de pagamento (2 Cards Lado a Lado)
          pw.Text(
            'Formas de pagamento',
            style: pw.TextStyle(
              fontSize: 15,
              fontWeight: pw.FontWeight.bold,
              color: const PdfColor.fromInt(0xFF102C49),
            ),
          ),
          pw.SizedBox(height: 8),

          pw.Row(
            children: [
              // Opção 1: À vista via Pix
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  decoration: pw.BoxDecoration(
                    color: const PdfColor.fromInt(0xFFEEF6FA),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(11)),
                    border: pw.Border.all(color: const PdfColor.fromInt(0xFFD8E5EE), width: 1.0),
                  ),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        width: 26,
                        height: 26,
                        decoration: pw.BoxDecoration(
                          color: primaryColor,
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6.5)),
                        ),
                        child: pw.Center(
                          child: pw.SvgImage(
                            svg: SolarPdfIcons.pix('#FFFFFF'),
                            width: 15,
                            height: 15,
                          ),
                        ),
                      ),
                      pw.SizedBox(width: 10),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'À vista via Pix',
                              style: pw.TextStyle(
                                fontSize: 11.2,
                                fontWeight: pw.FontWeight.bold,
                                color: const PdfColor.fromInt(0xFF102C49),
                              ),
                            ),
                            pw.SizedBox(height: 3),
                            pw.Text(
                              '5% de desconto',
                              style: pw.TextStyle(
                                fontSize: 10.2,
                                fontWeight: pw.FontWeight.bold,
                                color: const PdfColor.fromInt(0xFF087344),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 10),

              // Opção 2: Financiamento solar
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  decoration: pw.BoxDecoration(
                    color: const PdfColor.fromInt(0xFFEEF6FA),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(11)),
                    border: pw.Border.all(color: const PdfColor.fromInt(0xFFD8E5EE), width: 1.0),
                  ),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        width: 26,
                        height: 26,
                        decoration: pw.BoxDecoration(
                          color: primaryColor,
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6.5)),
                        ),
                        child: pw.Center(
                          child: pw.SvgImage(
                            svg: SolarPdfIcons.bank('#FFFFFF'),
                            width: 15,
                            height: 15,
                          ),
                        ),
                      ),
                      pw.SizedBox(width: 10),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'Financiamento solar',
                              style: pw.TextStyle(
                                fontSize: 11.2,
                                fontWeight: pw.FontWeight.bold,
                                color: const PdfColor.fromInt(0xFF102C49),
                              ),
                            ),
                            pw.SizedBox(height: 3),
                            pw.Text(
                              'Financiamento bancário',
                              style: const pw.TextStyle(
                                fontSize: 10.2,
                                color: PdfColor.fromInt(0xFF48627A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 14),

          // 4. Barra de Resumo Inferior: Investimento Total & Prazo de Entrega
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: pw.BoxDecoration(
              color: secondaryColor,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(11)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Investimento total da usina',
                      style: const pw.TextStyle(
                        fontSize: 9.5,
                        color: PdfColor.fromInt(0xFFC3E6F4),
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      _currencyFormat.format(proposal.totalAmount),
                      style: pw.TextStyle(
                        fontSize: 20.5,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Prazo de entrega',
                      style: const pw.TextStyle(
                        fontSize: 9.5,
                        color: PdfColor.fromInt(0xFFC3E6F4),
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      (proposal.deliveryTime != null && proposal.deliveryTime!.isNotEmpty)
                          ? proposal.deliveryTime!
                          : 'Imediata / 3 a 5 dias úteis',
                      style: pw.TextStyle(
                        fontSize: 12.0,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // PÁGINA 5: ANÁLISE DE INVESTIMENTO & TABELA DE 20 ANOS
  // ───────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildPage5Content({
    required ProposalModel proposal,
    required SolarSettingsModel settings,
    required double generationMonthly,
    required double generationDaily,
    required double kwp,
    required PdfColor primaryColor,
    required PdfColor secondaryColor,
  }) {
    final yearlyData = settings.calculateYearlySimulation(
      monthlyKwh: generationMonthly,
      systemKwp: kwp,
    );

    final rows21 = yearlyData.take(21).toList();
    final startYear = rows21.isNotEmpty ? rows21.first.year : DateTime.now().year;
    final endYear = rows21.isNotEmpty ? rows21.last.year : (DateTime.now().year + 20);

    final totalWithoutSolar = yearlyData.fold(0.0, (prev, item) => prev + (item.withoutSolar * 12));
    final totalWithSolar = yearlyData.fold(
        0.0, (prev, item) => prev + (((item.withSolarMin + item.withSolarMax) / 2) * 12));
    final firstYearSavings = (yearlyData.first.withoutSolar * 12) -
        (((yearlyData.first.withSolarMin + yearlyData.first.withSolarMax) / 2) * 12);
    final totalSavings = totalWithoutSolar - totalWithSolar;
    final paybackMonths =
        ((proposal.totalAmount / (firstYearSavings / 12)).round()).clamp(12, 60);

    final autoConsumptionDaily = generationDaily * (settings.simultaneityRate / 100.0);
    final dailyInjection = generationDaily * (1.0 - (settings.simultaneityRate / 100.0));

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // 1. Banner Principal Escuro
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 11),
            decoration: pw.BoxDecoration(
              color: secondaryColor,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Container(
                  width: 24,
                  height: 24,
                  decoration: pw.BoxDecoration(
                    color: primaryColor,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Center(
                    child: pw.SvgImage(
                      svg: SolarPdfIcons.trendingUp('#FFFFFF', size: 14),
                      width: 14,
                      height: 14,
                    ),
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Simulação de economia com energia solar',
                        style: pw.TextStyle(
                          fontSize: 17.5,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                      pw.SizedBox(height: 2.5),
                      pw.Text(
                        'Projeção da conta de energia elétrica de $startYear a $endYear',
                        style: const pw.TextStyle(
                          fontSize: 9.0,
                          color: PdfColor.fromInt(0xFFCBD5E1),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 8),

          // 2. Linha com os 4 KPI Cards de Indicadores
          pw.Row(
            children: [
              pw.Expanded(
                child: _buildEconomyKpiCard(
                  label: 'Economia no 1º ano',
                  value: _currencyFormat.format(firstYearSavings),
                  svgIcon: SolarPdfIcons.bolt('#FFFFFF'),
                  primaryColor: primaryColor,
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: _buildEconomyKpiCard(
                  label: 'Economia acumulada',
                  value: _currencyFormat.format(totalSavings),
                  svgIcon: SolarPdfIcons.trendingUp('#FFFFFF'),
                  primaryColor: primaryColor,
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: _buildEconomyKpiCard(
                  label: 'Investimento',
                  value: _currencyFormat.format(proposal.totalAmount),
                  svgIcon: SolarPdfIcons.calendarTable('#FFFFFF'),
                  primaryColor: primaryColor,
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: _buildEconomyKpiCard(
                  label: 'Tempo de payback',
                  value: '$paybackMonths meses',
                  svgIcon: SolarPdfIcons.clock('#FFFFFF'),
                  primaryColor: primaryColor,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),

          // 3. Bloco Duplo Central: Premissas da Simulação (Esquerda) + Gasto Total (Direita)
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Card Esquerdo: Premissas da simulação (2 colunas internas)
              pw.Expanded(
                flex: 65,
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                    border: pw.Border.all(color: const PdfColor.fromInt(0xFFE2E8F0), width: 0.8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        children: [
                          pw.Container(
                            width: 20,
                            height: 20,
                            decoration: pw.BoxDecoration(
                              color: primaryColor,
                              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
                            ),
                            child: pw.Center(
                              child: pw.SvgImage(
                                svg: SolarPdfIcons.bolt('#FFFFFF'),
                                width: 11,
                                height: 11,
                              ),
                            ),
                          ),
                          pw.SizedBox(width: 7),
                          pw.Text(
                            'Premissas da simulação',
                            style: pw.TextStyle(
                              fontSize: 10.0,
                              fontWeight: pw.FontWeight.bold,
                              color: const PdfColor.fromInt(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 6),
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Expanded(
                            child: pw.Column(
                              children: [
                                _buildParamRow('Concessionária', settings.utilityCompany),
                                _buildParamRow('Simultaneidade',
                                    '${settings.simultaneityRate.toStringAsFixed(0)}%'),
                                _buildParamRow('Inflação anual',
                                    '${settings.annualInflation.toStringAsFixed(0)}%'),
                                _buildParamRow('Consumo mensal',
                                    '${_numberFormat.format(generationMonthly)} kWh'),
                                _buildParamRow(
                                    'Consumo diário',
                                    '${generationDaily.toStringAsFixed(2).replaceAll('.', ',')} kWh',
                                    isLast: true),
                              ],
                            ),
                          ),
                          pw.SizedBox(width: 14),
                          pw.Expanded(
                            child: pw.Column(
                              children: [
                                _buildParamRow(
                                    'Autoconsumo',
                                    '${autoConsumptionDaily.toStringAsFixed(2).replaceAll('.', ',')} kWh'),
                                _buildParamRow('Geração mensal',
                                    '${_numberFormat.format(generationMonthly)} kWh'),
                                _buildParamRow(
                                    'Geração diária',
                                    '${generationDaily.toStringAsFixed(2).replaceAll('.', ',')} kWh'),
                                _buildParamRow(
                                    'Injeção diária',
                                    '${dailyInjection.toStringAsFixed(2).replaceAll('.', ',')} kWh',
                                    isLast: true),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 8),

              // Card Direito: Gasto total até 2046
              pw.Expanded(
                flex: 35,
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                    border: pw.Border.all(color: const PdfColor.fromInt(0xFFE2E8F0), width: 0.8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      pw.Row(
                        children: [
                          pw.Container(
                            width: 20,
                            height: 20,
                            decoration: pw.BoxDecoration(
                              color: primaryColor,
                              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
                            ),
                            child: pw.Center(
                              child: pw.SvgImage(
                                svg: SolarPdfIcons.trendingUp('#FFFFFF'),
                                width: 11,
                                height: 11,
                              ),
                            ),
                          ),
                          pw.SizedBox(width: 7),
                          pw.Text(
                            'Gasto total até $endYear',
                            style: pw.TextStyle(
                              fontSize: 10.0,
                              fontWeight: pw.FontWeight.bold,
                              color: const PdfColor.fromInt(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 8),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6.5),
                        decoration: const pw.BoxDecoration(
                          color: PdfColor.fromInt(0xFFEEF2F6),
                          borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'Sem energia solar',
                              style: const pw.TextStyle(
                                fontSize: 7.0,
                                color: PdfColor.fromInt(0xFF64748B),
                              ),
                            ),
                            pw.SizedBox(height: 2),
                            pw.Text(
                              _currencyFormat.format(totalWithoutSolar),
                              style: pw.TextStyle(
                                fontSize: 11.2,
                                fontWeight: pw.FontWeight.bold,
                                color: const PdfColor.fromInt(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6.5),
                        decoration: const pw.BoxDecoration(
                          color: PdfColor.fromInt(0xFFE8F8EE),
                          borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'Com energia solar',
                              style: const pw.TextStyle(
                                fontSize: 7.0,
                                color: PdfColor.fromInt(0xFF15803D),
                              ),
                            ),
                            pw.SizedBox(height: 2),
                            pw.Text(
                              _currencyFormat.format(totalWithSolar),
                              style: pw.TextStyle(
                                fontSize: 11.2,
                                fontWeight: pw.FontWeight.bold,
                                color: const PdfColor.fromInt(0xFF15803D),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),

          // 4. Tabela Principal Full-Width: Simulação da conta de energia elétrica
          pw.Container(
            decoration: pw.BoxDecoration(
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              border: pw.Border.all(color: const PdfColor.fromInt(0xFFE2E8F0), width: 0.8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // Cabeçalho Azul com Ícone
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 6.5),
                  decoration: pw.BoxDecoration(
                    color: primaryColor,
                    borderRadius: const pw.BorderRadius.vertical(top: pw.Radius.circular(7.5)),
                  ),
                  child: pw.Row(
                    children: [
                      pw.SvgImage(
                        svg: SolarPdfIcons.calendarTable('#FFFFFF', size: 13),
                        width: 13,
                        height: 13,
                      ),
                      pw.SizedBox(width: 8),
                      pw.Text(
                        'Simulação da conta de energia elétrica',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 10.2,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                // Sub-header Escuro
                pw.Container(
                  color: secondaryColor,
                  padding: const pw.EdgeInsets.symmetric(vertical: 4.5),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                        flex: 18,
                        child: pw.Text(
                          'ANO',
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 7.2,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Expanded(
                        flex: 54,
                        child: pw.Text(
                          'COM SOLAR (VARIAÇÃO)',
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 7.2,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Expanded(
                        flex: 28,
                        child: pw.Text(
                          'SEM SOLAR',
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 7.2,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 21 Linhas Zebradas
                for (int idx = 0; idx < rows21.length; idx++)
                  pw.Container(
                    decoration: pw.BoxDecoration(
                      border: idx == rows21.length - 1
                          ? null
                          : const pw.Border(
                              bottom: pw.BorderSide(
                                color: PdfColor.fromInt(0xFFE2E8F0),
                                width: 0.4,
                              ),
                            ),
                    ),
                    child: pw.Row(
                      children: [
                        pw.Expanded(
                          flex: 18,
                          child: pw.Container(
                            padding: const pw.EdgeInsets.symmetric(vertical: 3.1),
                            color: idx.isEven
                                ? PdfColors.white
                                : const PdfColor.fromInt(0xFFF8FAFC),
                            child: pw.Text(
                              '${rows21[idx].year}',
                              textAlign: pw.TextAlign.center,
                              style: pw.TextStyle(
                                fontSize: 7.5,
                                fontWeight: pw.FontWeight.bold,
                                color: const PdfColor.fromInt(0xFF0F172A),
                              ),
                            ),
                          ),
                        ),
                        pw.Expanded(
                          flex: 54,
                          child: pw.Container(
                            padding: const pw.EdgeInsets.symmetric(vertical: 3.1, horizontal: 4),
                            color: idx.isEven
                                ? const PdfColor.fromInt(0xFFE2F5EA)
                                : const PdfColor.fromInt(0xFFEDF9F2),
                            child: pw.Text(
                              '${_currencyFormat.format(rows21[idx].withSolarMin)} a ${_currencyFormat.format(rows21[idx].withSolarMax)}',
                              textAlign: pw.TextAlign.center,
                              style: pw.TextStyle(
                                fontSize: 7.5,
                                color: const PdfColor.fromInt(0xFF15803D),
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        pw.Expanded(
                          flex: 28,
                          child: pw.Container(
                            padding: const pw.EdgeInsets.symmetric(vertical: 3.1, horizontal: 4),
                            color: idx.isEven
                                ? PdfColors.white
                                : const PdfColor.fromInt(0xFFF8FAFC),
                            child: pw.Text(
                              _currencyFormat.format(rows21[idx].withoutSolar),
                              textAlign: pw.TextAlign.center,
                              style: const pw.TextStyle(
                                fontSize: 7.5,
                                color: PdfColor.fromInt(0xFF1E293B),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildEconomyKpiCard({
    required String label,
    required String value,
    required String svgIcon,
    required PdfColor primaryColor,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7.5),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: const PdfColor.fromInt(0xFFE2E8F0), width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 20,
            height: 20,
            decoration: pw.BoxDecoration(
              color: primaryColor,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
            ),
            child: pw.Center(
              child: pw.SvgImage(
                svg: svgIcon,
                width: 11.5,
                height: 11.5,
              ),
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            label,
            style: const pw.TextStyle(
              fontSize: 7.2,
              color: PdfColor.fromInt(0xFF64748B),
            ),
          ),
          pw.SizedBox(height: 1.5),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 11.8,
              fontWeight: pw.FontWeight.bold,
              color: primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildParamRow(String label, String value, {bool isLast = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.8, horizontal: 2),
      decoration: pw.BoxDecoration(
        border: isLast
            ? null
            : const pw.Border(
                bottom: pw.BorderSide(color: PdfColor.fromInt(0xFFF1F5F9), width: 0.6),
              ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 7.4, color: PdfColor.fromInt(0xFF64748B)),
          ),
          pw.Text(
            value,
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(
              fontSize: 7.4,
              color: const PdfColor.fromInt(0xFF0F172A),
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // PÁGINA 6: FINANCIAMENTO BANCÁRIO & CARTÃO DE CRÉDITO
  // ───────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildPage6Content({
    required ProposalModel proposal,
    required SolarSettingsModel settings,
    required PdfColor primaryColor,
    required PdfColor secondaryColor,
  }) {
    final activeBanks = settings.financingBanks.where((b) => b.isActive).toList();
    final banksToRender = <SolarFinancingBank>[
      activeBanks.isNotEmpty
          ? activeBanks[0]
          : const SolarFinancingBank(
              id: 'solfacil',
              name: 'SolFácil',
              monthlyInterestRate: 1.25,
              enabledInstallments: [12, 24, 36, 48, 60],
            ),
      activeBanks.length > 1
          ? activeBanks[1]
          : const SolarFinancingBank(
              id: 'santander',
              name: 'Santander',
              monthlyInterestRate: 1.19,
              enabledInstallments: [12, 24, 36, 48, 60],
            ),
      activeBanks.length > 2
          ? activeBanks[2]
          : const SolarFinancingBank(
              id: 'sicredi',
              name: 'Sicredi',
              monthlyInterestRate: 1.15,
              enabledInstallments: [12, 24, 36, 60, 90],
            ),
      activeBanks.length > 3
          ? activeBanks[3]
          : const SolarFinancingBank(
              id: 'bv',
              name: 'BV Financeira',
              monthlyInterestRate: 1.09,
              enabledInstallments: [12, 24, 36, 48, 60],
            ),
    ];

    final primaryHex = _pdfColorToHex(primaryColor);

    final heroPanelSvg = '''
<svg viewBox="0 0 210 120" width="170" height="96">
  <circle cx="152" cy="36" r="30" fill="#164263"/>
  <circle cx="152" cy="36" r="20" fill="#205E83"/>
  <circle cx="152" cy="36" r="11" fill="#FBBF24"/>
  <circle cx="98" cy="24" r="1.8" fill="#58C4F6"/>
  <circle cx="192" cy="70" r="1.8" fill="#58C4F6"/>
  <path d="M55 110 L155 110 M82 96 L76 110 M128 96 L134 110" stroke="#7DD3FC" stroke-width="2" stroke-linecap="round"/>
  <polygon points="62,48 148,48 136,96 50,96" fill="#0A6F9E" stroke="#7DD3FC" stroke-width="2.2" stroke-linejoin="round"/>
  <path d="M58 64 L144 64 M54 80 L140 80 M83 48 L71 96 M105 48 L93 96 M127 48 L115 96" stroke="#7DD3FC" stroke-width="1.4"/>
</svg>
''';

    final cardIllustrationSvg = '''
<svg viewBox="0 0 110 68" width="90" height="56">
  <g transform="rotate(-10 55 34)">
    <rect x="10" y="10" width="84" height="50" rx="8" fill="#1E73BE" stroke="#38BDF8" stroke-width="1.2"/>
    <rect x="20" y="25" width="12" height="9" rx="2" fill="#FBBF24"/>
    <circle cx="72" cy="24" r="3.5" fill="#7DD3FC" opacity="0.85"/>
    <circle cx="77" cy="24" r="3.5" fill="#38BDF8" opacity="0.85"/>
  </g>
</svg>
''';

    return pw.Container(
      color: const PdfColor.fromInt(0xFFF3F7FA),
      padding: const pw.EdgeInsets.symmetric(horizontal: 26, vertical: 14),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // 1. Hero Banner Escuro
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            decoration: pw.BoxDecoration(
              color: secondaryColor,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(14)),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Expanded(
                  flex: 62,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'OPÇÕES DE PAGAMENTO',
                        style: pw.TextStyle(
                          fontSize: 7.5,
                          fontWeight: pw.FontWeight.bold,
                          color: const PdfColor.fromInt(0xFF38BDF8),
                          letterSpacing: 1.0,
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        'Simulação e\nparcelamento solar',
                        style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                          lineSpacing: 1.5,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'Compare o financiamento e as parcelas no cartão.',
                        style: const pw.TextStyle(
                          fontSize: 9.5,
                          color: PdfColor.fromInt(0xFFCBD5E1),
                        ),
                      ),
                    ],
                  ),
                ),
                pw.Expanded(
                  flex: 38,
                  child: pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.SvgImage(
                      svg: heroPanelSvg,
                      width: 170,
                      height: 96,
                    ),
                  ),
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 14),

          // 2. Seção Financiamento bancário
          pw.Text(
            'Financiamento bancário',
            style: pw.TextStyle(
              fontSize: 14.5,
              fontWeight: pw.FontWeight.bold,
              color: const PdfColor.fromInt(0xFF102C49),
            ),
          ),
          pw.SizedBox(height: 10),

          // Grid 2x2 dos Bancos
          pw.Row(
            children: [
              pw.Expanded(child: _buildBankCard(banksToRender[0], proposal.totalAmount, primaryColor, primaryHex)),
              pw.SizedBox(width: 12),
              pw.Expanded(child: _buildBankCard(banksToRender[1], proposal.totalAmount, primaryColor, primaryHex)),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            children: [
              pw.Expanded(child: _buildBankCard(banksToRender[2], proposal.totalAmount, primaryColor, primaryHex)),
              pw.SizedBox(width: 12),
              pw.Expanded(child: _buildBankCard(banksToRender[3], proposal.totalAmount, primaryColor, primaryHex)),
            ],
          ),

          pw.Spacer(),

          // 3. Seção Parcelamento no cartão de crédito
          pw.Text(
            'Parcelamento no cartão de crédito',
            style: pw.TextStyle(
              fontSize: 14.5,
              fontWeight: pw.FontWeight.bold,
              color: const PdfColor.fromInt(0xFF102C49),
            ),
          ),
          pw.SizedBox(height: 10),

          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: secondaryColor,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(14)),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                // Lado Esquerdo: Ilustração + Bandeiras Aceitas
                pw.Expanded(
                  flex: 46,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.SvgImage(
                        svg: cardIllustrationSvg,
                        width: 90,
                        height: 56,
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'BANDEIRAS ACEITAS',
                        style: pw.TextStyle(
                          fontSize: 7.2,
                          fontWeight: pw.FontWeight.bold,
                          color: const PdfColor.fromInt(0xFF38BDF8),
                          letterSpacing: 0.8,
                        ),
                      ),
                      pw.SizedBox(height: 7),
                      pw.Row(
                        children: ['VISA', 'MASTERCARD', 'ELO'].map((b) => _buildCardBrandBadge(b)).toList(),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Row(
                        children: ['AMEX', 'HIPERCARD', 'DINERS CLUB'].map((b) => _buildCardBrandBadge(b)).toList(),
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(width: 14),

                // Lado Direito: 4 Parcelas em Caixas Arredondadas
                pw.Expanded(
                  flex: 54,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      ...[3, 6, 9, 12].map((installments) {
                        final rateItem = settings.creditCardRates.firstWhere(
                          (r) => r.installment == installments,
                          orElse: () => CreditCardInstallmentRate(
                              installment: installments, feePercentage: installments * 1.05),
                        );
                        final val = rateItem.calculateInstallmentValue(proposal.totalAmount);

                        return pw.Container(
                          margin: pw.EdgeInsets.only(bottom: installments == 12 ? 0 : 6),
                          padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 7.5),
                          decoration: pw.BoxDecoration(
                            color: const PdfColor.fromInt(0xFF183B5E),
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                            border: pw.Border.all(
                              color: const PdfColor.fromInt(0xFF284F78),
                              width: 0.7,
                            ),
                          ),
                          child: pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(
                                '$installments' 'x no cartão',
                                style: const pw.TextStyle(
                                  fontSize: 9.2,
                                  color: PdfColor.fromInt(0xFFCBD5E1),
                                ),
                              ),
                              pw.Text(
                                _currencyFormat.format(val),
                                style: pw.TextStyle(
                                  fontSize: 12.0,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.white,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildCardBrandBadge(String brand) {
    return pw.Expanded(
      child: pw.Container(
        margin: const pw.EdgeInsets.only(right: 5),
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4.5),
        decoration: const pw.BoxDecoration(
          color: PdfColors.white,
          borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
        ),
        child: pw.Center(
          child: pw.Text(
            brand,
            style: pw.TextStyle(
              fontSize: 6.5,
              fontWeight: pw.FontWeight.bold,
              color: const PdfColor.fromInt(0xFF102C49),
            ),
            maxLines: 1,
          ),
        ),
      ),
    );
  }

  static pw.Widget _buildBankCard(
    SolarFinancingBank bank,
    double totalAmount,
    PdfColor primaryColor,
    String primaryHex,
  ) {
    final lowerName = '${bank.id} ${bank.name}'.toLowerCase();
    PdfColor ratePillBg = const PdfColor.fromInt(0xFFEFF6FF);
    PdfColor ratePillText = const PdfColor.fromInt(0xFF0284C7);
    if (lowerName.contains('solfacil') || lowerName.contains('solfácil') || lowerName.contains('sicredi')) {
      ratePillBg = const PdfColor.fromInt(0xFFEAF7EE);
      ratePillText = const PdfColor.fromInt(0xFF15803D);
    } else if (lowerName.contains('santander')) {
      ratePillBg = const PdfColor.fromInt(0xFFFEF2F2);
      ratePillText = const PdfColor.fromInt(0xFFDC2626);
    }

    final installments = bank.enabledInstallments.take(5).toList();

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
        border: pw.Border.all(color: const PdfColor.fromInt(0xFFE2E8F0), width: 0.9),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // Cabeçalho do Card: Logo à esquerda + Pílula da Taxa à direita
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              _buildBankLogoWidget(bank, primaryColor),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                decoration: pw.BoxDecoration(
                  color: ratePillBg,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
                ),
                child: pw.Text(
                  '${bank.monthlyInterestRate.toStringAsFixed(2).replaceAll('.', ',')}% a.m.',
                  style: pw.TextStyle(
                    fontSize: 7.5,
                    fontWeight: pw.FontWeight.bold,
                    color: ratePillText,
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 10),

          // Tabela de Parcelas (12x .. 60x/90x)
          for (int i = 0; i < installments.length; i++)
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3.5),
              decoration: pw.BoxDecoration(
                color: i.isEven ? const PdfColor.fromInt(0xFFF4F8FB) : PdfColors.white,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    '${installments[i]}x',
                    style: pw.TextStyle(
                      fontSize: 8.5,
                      fontWeight: pw.FontWeight.bold,
                      color: const PdfColor.fromInt(0xFF475569),
                    ),
                  ),
                  pw.Text(
                    _currencyFormat.format(bank.calculateInstallment(totalAmount, installments[i])),
                    style: pw.TextStyle(
                      fontSize: 9.5,
                      fontWeight: pw.FontWeight.bold,
                      color: const PdfColor.fromInt(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static pw.Widget _buildBankLogoWidget(SolarFinancingBank bank, PdfColor primaryColor) {
    // 1. Se o usuário enviou logo customizada nas configurações, renderiza a imagem
    if (bank.logoBase64 != null && bank.logoBase64!.trim().isNotEmpty) {
      try {
        final clean = bank.logoBase64!.contains(',')
            ? bank.logoBase64!.split(',').last
            : bank.logoBase64!;
        final bytes = base64Decode(clean.trim());
        if (bytes.isNotEmpty) {
          return pw.SizedBox(
            height: 22,
            child: pw.Image(pw.MemoryImage(bytes), height: 22, fit: pw.BoxFit.contain),
          );
        }
      } catch (_) {}
    }

    // 2. Logos vetoriais oficiais padrão para SolFácil, Santander, Sicredi e BV Financeira
    final key = '${bank.id} ${bank.name}'.toLowerCase();

    if (key.contains('solfacil') || key.contains('solfácil')) {
      return pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text('s', style: const pw.TextStyle(fontSize: 17, color: PdfColor.fromInt(0xFF111827))),
          pw.SizedBox(width: 1),
          pw.SvgImage(
            svg: '<svg viewBox="0 0 24 24" width="15" height="15"><circle cx="12" cy="12" r="5" fill="#FACC15"/><path d="M12 1v3M12 20v3M4.2 4.2l2.1 2.1M17.7 17.7l2.1 2.1M1 12h3M20 12h3M4.2 19.8l2.1-2.1M17.7 6.3l2.1-2.1" stroke="#FACC15" stroke-width="2.4" stroke-linecap="round"/></svg>',
            width: 15,
            height: 15,
          ),
          pw.SizedBox(width: 1),
          pw.Text('lfácil', style: const pw.TextStyle(fontSize: 17, color: PdfColor.fromInt(0xFF111827))),
        ],
      );
    }

    if (key.contains('santander')) {
      return pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.SvgImage(
            svg: '<svg viewBox="0 0 24 24" width="16" height="16"><path d="M12 2c-.4 3.1-3.4 4.5-3.4 7.7 0 1.4.8 2.6 1.7 3.4-.5-1.3-.1-2.8 1-3.9.4 1.6 1.8 2.3 1.8 4.2 0 1.3-.7 2.4-1.7 3.2 2.9-.4 5.1-2.6 5.1-5.6 0-3.2-3.4-4.7-4.5-9zM7 11.2c-2.6.9-4.5 2.7-4.5 4.8 0 2.8 4.2 5 9.5 5s9.5-2.2 9.5-5c0-2-1.8-3.8-4.3-4.7.6 1.1.8 2.3.5 3.6-1.1 1.6-3.4 2.5-5.7 2.5-2.6 0-4.9-1.1-5.8-2.9-.2-1.1.1-2.2.8-3.3z" fill="#EC0000"/></svg>',
            width: 16,
            height: 16,
          ),
          pw.SizedBox(width: 5),
          pw.Text(
            'Santander',
            style: pw.TextStyle(
              fontSize: 14.5,
              fontWeight: pw.FontWeight.bold,
              color: const PdfColor.fromInt(0xFFEC0000),
            ),
          ),
        ],
      );
    }

    if (key.contains('sicredi')) {
      return pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.SvgImage(
            svg: '<svg viewBox="0 0 24 24" width="16" height="16"><circle cx="12" cy="12" r="10" fill="none"/><path d="M12 2c2 3 2 6 0 8-2-2-2-5 0-8zM22 12c-3 2-6 2-8 0 2-2 5-2 8 0zM12 22c-2-3-2-6 0-8 2 2 2 5 0 8zM2 12c3-2 6-2 8 0-2 2-5 2-8 0zM19.1 4.9c-.7 3.5-2.8 5.6-5.6 5.6 0-2.8 2.1-4.9 5.6-5.6zM19.1 19.1c-3.5-.7-5.6-2.8-5.6-5.6 2.8 0 4.9 2.1 5.6 5.6zM4.9 19.1c.7-3.5 2.8-5.6 5.6-5.6 0 2.8-2.1 4.9-5.6 5.6zM4.9 4.9c3.5.7 5.6 2.8 5.6 5.6-2.8 0-4.9-2.1-5.6-5.6z" fill="#3FA110"/></svg>',
            width: 16,
            height: 16,
          ),
          pw.SizedBox(width: 5),
          pw.Text(
            'Sicredi',
            style: pw.TextStyle(
              fontSize: 15.5,
              fontWeight: pw.FontWeight.bold,
              color: const PdfColor.fromInt(0xFF3FA110),
            ),
          ),
        ],
      );
    }

    if (key.contains('bv')) {
      return pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.SvgImage(
            svg: '<svg viewBox="0 0 28 24" width="22" height="18"><path d="M2 2h7c3 0 5 1.5 5 4.2 0 1.8-1 3.1-2.5 3.6 1.9.5 3 2 3 4.1 0 3-2.3 5.1-5.8 5.1H2V2zm4.2 6.4h2.4c1.2 0 1.9-.6 1.9-1.6s-.7-1.6-1.9-1.6H6.2v3.2zm0 7.2h2.8c1.4 0 2.2-.7 2.2-1.8 0-1.1-.8-1.8-2.2-1.8H6.2v3.6z" fill="#1D4ED8"/><path d="M13 6h4.2l3.1 9.5L23.4 6H27.5l-5.3 15h-4L13 6z" fill="#06B6D4"/></svg>',
            width: 22,
            height: 18,
          ),
          pw.SizedBox(width: 5),
          pw.Text(
            bank.name,
            style: pw.TextStyle(
              fontSize: 11.5,
              fontWeight: pw.FontWeight.bold,
              color: const PdfColor.fromInt(0xFF102C49),
            ),
          ),
        ],
      );
    }

    // 3. Fallback elegante para outras financeiras sem logo enviada
    return pw.Text(
      bank.name,
      style: pw.TextStyle(
        fontSize: 12.5,
        fontWeight: pw.FontWeight.bold,
        color: primaryColor,
      ),
    );
  }

  static String _pdfColorToHex(PdfColor color) {
    final r = (color.red * 255).round().toRadixString(16).padLeft(2, '0');
    final g = (color.green * 255).round().toRadixString(16).padLeft(2, '0');
    final b = (color.blue * 255).round().toRadixString(16).padLeft(2, '0');
    return '#$r$g$b';
  }

  static String _getComponentIcon(String item, String hex) {
    final upper = item.toUpperCase();
    if (upper.contains('INVERSOR') || upper.contains('MICRO')) {
      return SolarPdfIcons.inverterBox(hex);
    } else if (upper.contains('MÓDULO') || upper.contains('MODULO') || upper.contains('PAINEL') || upper.contains('PLACA') || upper.contains('FOTOVOLTAICO')) {
      return SolarPdfIcons.panelGrid(hex);
    } else if (upper.contains('ESTRUTURA') || upper.contains('PERFIL') || upper.contains('FIXAÇÃO') || upper.contains('FIXACAO') || upper.contains('TELHADO') || upper.contains('TELHA')) {
      return SolarPdfIcons.roof(hex);
    } else if (upper.contains('STRING') || upper.contains('DPS') || upper.contains('CHAVE') || upper.contains('QUADRO') || upper.contains('PROTEÇÃO') || upper.contains('PROTECAO')) {
      return SolarPdfIcons.shieldCheck(hex);
    } else if (upper.contains('CABO') || upper.contains('CONECTOR') || upper.contains('MC4')) {
      return SolarPdfIcons.cablePlug(hex);
    } else if (upper.contains('HOMOLOGAÇÃO') || upper.contains('HOMOLOGACAO') || upper.contains('ENGENHARIA') || upper.contains('PROJETO') || upper.contains('ART')) {
      return SolarPdfIcons.documentFile(hex);
    } else {
      return SolarPdfIcons.solarTech(hex);
    }
  }
}

/// Biblioteca de Ícones Vetoriais SVG Ultra-Sharp para o PDF Solar
class SolarPdfIcons {
  static String _svgWrap(String paths, {String color = '#0F172A', int size = 24, double strokeWidth = 2.0}) {
    return '<svg width="$size" height="$size" viewBox="0 0 24 24" fill="none" stroke="$color" stroke-width="$strokeWidth" stroke-linecap="round" stroke-linejoin="round">$paths</svg>';
  }

  /// 1. Escudo com Check (Confiança)
  static String shieldCheck(String color, {int size = 24}) => _svgWrap(
    '<path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/><path d="m9 12 2 2 4-4"/>',
    color: color,
    size: size,
  );

  /// 2. Moeda / Dinheiro (Bom Negócio / Investimento)
  static String dollar(String color, {int size = 24}) => _svgWrap(
    '<circle cx="12" cy="12" r="10"/><path d="M16 8h-6a2 2 0 1 0 0 4h4a2 2 0 1 1 0 4H8"/><path d="M12 6v12"/>',
    color: color,
    size: size,
  );

  /// 3. Painel Solar com Sol (Tecnologia)
  static String solarTech(String color, {int size = 24}) => _svgWrap(
    '<path d="M12 2v2"/><path d="M4.93 4.93l1.41 1.41"/><path d="M2 12h2"/><path d="M19.07 4.93l-1.41 1.41"/><path d="M6 10l-3 10h18l-3-10H6z"/><path d="M6 15h12"/><path d="M12 10v10"/>',
    color: color,
    size: size,
  );

  /// 4. Polegar / Like (Zero Dor de Cabeça)
  static String thumbsUp(String color, {int size = 24}) => _svgWrap(
    '<path d="M7 10v12"/><path d="M15 5.88 14 10h5.83a2 2 0 0 1 1.92 2.56l-2.33 8A2 2 0 0 1 17.5 22H4a2 2 0 0 1-2-2v-8a2 2 0 0 1 2-2h3"/><path d="M10 5a3 3 0 0 1 6 0"/>',
    color: color,
    size: size,
  );

  /// 5. Lâmpada de Ideias (Solução Completa Turn-Key)
  static String lightbulb(String color, {int size = 24}) => _svgWrap(
    '<path d="M15 14c.2-1 .7-1.7 1.5-2.5 1-.9 1.5-2.2 1.5-3.5A6 6 0 0 0 6 8c0 1 .2 2.2 1.5 3.5.7.7 1.3 1.5 1.5 2.5"/><path d="M9 18h6"/><path d="M10 22h4"/>',
    color: color,
    size: size,
  );

  /// 6. Smartphone (App Gratuito de Monitoramento)
  static String smartphone(String color, {int size = 24}) => _svgWrap(
    '<rect width="14" height="20" x="5" y="2" rx="2" ry="2"/><path d="M12 18h.01"/>',
    color: color,
    size: size,
  );

  /// 7. Caminhão de Entrega (Frete Incluso)
  static String truck(String color, {int size = 24}) => _svgWrap(
    '<path d="M14 18V6a2 2 0 0 0-2-2H4a2 2 0 0 0-2 2v11a1 1 0 0 0 1 1h2"/><path d="M15 18H9"/><path d="M19 18h2a1 1 0 0 0 1-1v-3.65a1 1 0 0 0-.22-.62l-3.48-4.35A1 1 0 0 0 17.52 8H14v10"/><circle cx="17" cy="18.5" r="2.5"/><circle cx="7" cy="18.5" r="2.5"/>',
    color: color,
    size: size,
  );

  /// 8. Certificado / Selo INMETRO & Garantias
  static String award(String color, {int size = 24}) => _svgWrap(
    '<circle cx="12" cy="8" r="6"/><path d="m15.477 12.89 1.515 8.526a.5.5 0 0 1-.724.522L12 19.8l-4.268 2.138a.5.5 0 0 1-.724-.522l1.515-8.526"/>',
    color: color,
    size: size,
  );

  /// 9. Raio / Potência do Sistema
  static String bolt(String color, {int size = 24}) => _svgWrap(
    '<path d="M13 2 3 14h9l-1 8 10-12h-9l1-8z"/>',
    color: color,
    size: size,
  );

  /// 10. Grade de Módulos Solares
  static String solarPanel(String color, {int size = 24}) => _svgWrap(
    '<rect x="3" y="3" width="18" height="18" rx="2"/><path d="M3 12h18"/><path d="M12 3v18"/>',
    color: color,
    size: size,
  );

  /// 11. Potência do Módulo em Watts
  static String sunWatt(String color, {int size = 24}) => _svgWrap(
    '<circle cx="12" cy="12" r="4"/><path d="M12 2v2"/><path d="M12 20v2"/><path d="m4.93 4.93 1.41 1.41"/><path d="m17.66 17.66 1.41 1.41"/><path d="M2 12h2"/><path d="M20 12h2"/><path d="m6.34 17.66-1.41 1.41"/><path d="m19.07 4.93-1.41 1.41"/>',
    color: color,
    size: size,
  );

  /// 12. Inversor / Microinversor Grid-Tie
  static String inverter(String color, {int size = 24}) => _svgWrap(
    '<rect width="16" height="16" x="4" y="4" rx="2"/><path d="m9 9 6 6"/><path d="m15 9-6 6"/><path d="M9 1v3"/><path d="M15 1v3"/><path d="M9 20v3"/><path d="M15 20v3"/>',
    color: color,
    size: size,
  );

  /// 13. Telhado / Estrutura
  static String roof(String color, {int size = 24}) => _svgWrap(
    '<path d="m3 9 9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><polyline points="9 22 9 12 15 12 15 22"/>',
    color: color,
    size: size,
  );

  /// 14. Gráfico de Produção de Energia
  static String trendingUp(String color, {int size = 24}) => _svgWrap(
    '<polyline points="22 7 13.5 15.5 8.5 10.5 2 17"/><polyline points="16 7 22 7 22 13"/>',
    color: color,
    size: size,
  );

  /// 15. Régua / Área Ocupada
  static String rulerSquare(String color, {int size = 24}) => _svgWrap(
    '<path d="M21.3 15.3a2.4 2.4 0 0 1 0 3.4l-2.6 2.6a2.4 2.4 0 0 1-3.4 0L2.7 8.7a2.41 2.41 0 0 1 0-3.4l2.6-2.6a2.41 2.41 0 0 1 3.4 0Z"/><path d="m14.5 12.5 2-2"/><path d="m11.5 9.5 2-2"/><path d="m8.5 6.5 2-2"/><path d="m17.5 15.5 2-2"/>',
    color: color,
    size: size,
  );

  /// 16. Tabela / Calendário Financeiro
  static String calendarTable(String color, {int size = 24}) => _svgWrap(
    '<rect width="18" height="16" x="3" y="4" rx="2"/><line x1="3" x2="21" y1="10" y2="10"/><line x1="8" x2="8" y1="2" y2="6"/><line x1="16" x2="16" y1="2" y2="6"/>',
    color: color,
    size: size,
  );

  /// 17. Relógio / Payback
  static String clock(String color, {int size = 24}) => _svgWrap(
    '<circle cx="12" cy="12" r="9"/><polyline points="12 7 12 12 15.5 14"/>',
    color: color,
    size: size,
  );

  /// 18. Painel Solar 3x2 (Lista de Equipamentos)
  static String panelGrid(String color, {int size = 24}) => _svgWrap(
    '<path d="M3 5h18v14H3zM3 12h18M9 5v14m6-14v14"/>',
    color: color,
    size: size,
    strokeWidth: 1.65,
  );

  /// 19. Inversor com Raio (Lista de Equipamentos)
  static String inverterBox(String color, {int size = 24}) => _svgWrap(
    '<path d="M6 3h12v18H6zM9 7h6m-3 3-3 5h4l-1 3"/>',
    color: color,
    size: size,
    strokeWidth: 1.65,
  );

  /// 20. Cabo Solar / Conector MC4 (Lista de Equipamentos)
  static String cablePlug(String color, {int size = 24}) => _svgWrap(
    '<path d="M7 3v5m4-5v5M5 8h8v3a4 4 0 0 1-8 0zm4 7v2a3 3 0 0 0 6 0v-3a3 3 0 0 1 6 0v5"/>',
    color: color,
    size: size,
    strokeWidth: 1.65,
  );

  /// 21. Documento / Projeto Executivo & ART
  static String documentFile(String color, {int size = 24}) => _svgWrap(
    '<path d="M6 3h8l4 4v14H6zm8 0v5h4M9 12h6m-6 4h6"/>',
    color: color,
    size: size,
    strokeWidth: 1.65,
  );

  /// 22. Ícone Pix
  static String pix(String color, {int size = 24}) => _svgWrap(
    '<path d="M12 3l9 9-9 9-9-9zm-5 9 5 5 5-5m-10 0 5-5 5 5"/>',
    color: color,
    size: size,
    strokeWidth: 1.65,
  );

  /// 23. Ícone Banco / Financiamento
  static String bank(String color, {int size = 24}) => _svgWrap(
    '<path d="M3 9l9-5 9 5H3zm3 3v6m6-6v6m6-6v6M3 21h18"/>',
    color: color,
    size: size,
    strokeWidth: 1.65,
  );
}

