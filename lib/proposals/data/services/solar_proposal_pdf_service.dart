import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../settings/data/services/solar_settings_service.dart';
import '../../../settings/domain/models/solar_settings_model.dart';
import '../../../solar_designer/data/repositories/roof_study_repository.dart';
import '../../../solar_designer/domain/models/roof_study_model.dart';
import '../../domain/models/proposal_item_model.dart';
import '../../domain/models/proposal_model.dart';

class SolarProposalPdfService {
  static final _currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  static final _numberFormat = NumberFormat.decimalPattern('pt_BR');

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

    final int studyPagesCount = effectiveStudy != null ? (1 + effectivePhotos.length) : 0;
    final int totalPages = 6 + studyPagesCount;

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
    if (settings.proposalStyle == 'verticalSplit') {
      try {
        coverImageBytes = await SolarSettingsService.fetchWebBackgroundBytes(settings.webBackgroundTemplate);
      } catch (_) {}
      if (coverImageBytes == null) {
        final bgs = SolarSettingsService.getDefaultWebBackgroundList();
        if (bgs.isNotEmpty) {
          try {
            coverImageBytes = await SolarSettingsService.fetchWebBackgroundBytes(bgs.first);
          } catch (_) {}
        }
      }
    } else if (settings.isCustomCoverMode && settings.customCoverImageBase64 != null && settings.customCoverImageBase64!.isNotEmpty) {
      try {
        coverImageBytes = base64Decode(settings.customCoverImageBase64!);
      } catch (_) {}
    }

    if (coverImageBytes == null && settings.proposalStyle != 'verticalSplit') {
      try {
        coverImageBytes = await SolarSettingsService.fetchCoverBytes(settings.selectedCoverTemplate);
      } catch (_) {}
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

    // ─────────────────────────────────────────────────────────────────────────
    // PÁGINA 2: PROPOSTA COMERCIAL & ESCOPO DO PROJETO
    // ─────────────────────────────────────────────────────────────────────────
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (context) => _buildProgrammaticPageLayout(
          pageTitle: 'PROPOSTA COMERCIAL',
          pageNumber: 2,
          totalPages: totalPages,
          primaryColor: primaryColor,
          settings: settings,
          proposal: proposal,
          content: _buildPage2Content(primaryColor),
        ),
      ),
    );

    // ─────────────────────────────────────────────────────────────────────────
    // PÁGINA 3: SUA USINA (FICHA TÉCNICA)
    // ─────────────────────────────────────────────────────────────────────────
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (context) => _buildProgrammaticPageLayout(
          pageTitle: 'SUA USINA SOLAR',
          pageNumber: 3,
          totalPages: totalPages,
          primaryColor: primaryColor,
          settings: settings,
          proposal: proposal,
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
          ),
        ),
      ),
    );

    // ─────────────────────────────────────────────────────────────────────────
    // ESTUDO SOLAR DE TELHADO & SOMBREAMENTO (SE VINCULADO)
    // INSERIDO EXATAMENTE ANTES DA PÁGINA "ITENS DA USINA & PAGAMENTO"
    // COM CABEÇALHO E RODAPÉ PADRONIZADOS DA PROPOSTA
    // ─────────────────────────────────────────────────────────────────────────
    if (effectiveStudy != null) {
      // 1. Folha do Estudo Técnico de Telhado & Sombreamento
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (context) => _buildProgrammaticPageLayout(
            pageTitle: 'ESTUDO DE TELHADO & SOMBREAMENTO',
            pageNumber: 4,
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
        final pageNum = 5 + i;
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: pw.EdgeInsets.zero,
            build: (context) => _buildProgrammaticPageLayout(
              pageTitle: 'SIMULAÇÃO SOLAR • ${_formatHour(photo.hourOfDay)}',
              pageNumber: pageNum,
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
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (context) => _buildProgrammaticPageLayout(
          pageTitle: 'ITENS DA USINA & PAGAMENTO',
          pageNumber: 4 + studyPagesCount,
          totalPages: totalPages,
          primaryColor: primaryColor,
          settings: settings,
          proposal: proposal,
          content: _buildPage4Content(
            proposal: proposal,
            solarPlantItem: solarPlantItem,
            primaryColor: primaryColor,
          ),
        ),
      ),
    );

    // ─────────────────────────────────────────────────────────────────────────
    // PÁGINA: ANÁLISE DE INVESTIMENTO & TABELA DE 20 ANOS
    // ─────────────────────────────────────────────────────────────────────────
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (context) => _buildProgrammaticPageLayout(
          pageTitle: 'ANÁLISE DE INVESTIMENTO',
          pageNumber: 5 + studyPagesCount,
          totalPages: totalPages,
          primaryColor: primaryColor,
          settings: settings,
          proposal: proposal,
          content: _buildPage5Content(
            proposal: proposal,
            settings: settings,
            generationMonthly: generationMonthly,
            generationDaily: generationDaily,
            kwp: kwp,
            primaryColor: primaryColor,
          ),
        ),
      ),
    );

    // ─────────────────────────────────────────────────────────────────────────
    // PÁGINA: FINANCIAMENTO BANCÁRIO & CARTÃO DE CRÉDITO
    // ─────────────────────────────────────────────────────────────────────────
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (context) => _buildProgrammaticPageLayout(
          pageTitle: 'FINANCIAMENTO & CONDIÇÕES',
          pageNumber: 6 + studyPagesCount,
          totalPages: totalPages,
          primaryColor: primaryColor,
          settings: settings,
          proposal: proposal,
          content: _buildPage6Content(
            proposal: proposal,
            settings: settings,
            primaryColor: primaryColor,
          ),
        ),
      ),
    );

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

    Uint8List? logoBytes;
    if (settings.coverShowLogo && settings.companyLogoBase64 != null && settings.companyLogoBase64!.isNotEmpty) {
      try {
        logoBytes = base64Decode(settings.companyLogoBase64!);
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
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromInt(settings.coverHeadlineColorValue),
                      lineSpacing: 2,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Container(
                    width: 48,
                    height: 4,
                    color: accentPdfColor,
                  ),
                  pw.SizedBox(height: 12),
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
                    settings.verticalSplitRightTitle,
                    style: pw.TextStyle(
                      font: rightBlockFontBold ?? fontMontserratBold,
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromInt(settings.coverRightTitleColorValue),
                      letterSpacing: 5.5,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    settings.verticalSplitRightSubtitle,
                    style: pw.TextStyle(
                      font: rightBlockFontBlack ?? fontMontserratBlack,
                      fontSize: 46,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromInt(settings.coverRightSubtitleColorValue),
                      letterSpacing: 2.0,
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  pw.Container(
                    width: 54,
                    height: 4.5,
                    color: accentPdfColor,
                  ),
                  pw.SizedBox(height: 14),
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
      case 'lampada':
      case 'ideia':
        svgContent = '<svg viewBox="0 0 24 24" width="$size" height="$size"><path d="M9 21c0 .55.45 1 1 1h4c.55 0 1-.45 1-1v-1H9v1zm3-19C8.14 2 5 5.14 5 9c0 2.38 1.19 4.47 3 5.74V17c0 .55.45 1 1 1h6c.55 0 1-.45 1-1v-2.26c1.81-1.27 3-3.36 3-5.74 0-3.86-3.14-7-7-7z" fill="$hex"/></svg>';
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
    final accentHex = settings.verticalSplitAccentColor.replaceAll('#', '').trim();
    final accentSvgColor = '#$accentHex';

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

        // 2. Separador Vetorial se for Capa Customizada (Upload próprio)
        if (settings.isCustomCoverMode)
          pw.SvgImage(
            svg: '''
<svg viewBox="0 0 595.28 841.89" width="595.28" height="841.89" xmlns="http://www.w3.org/2000/svg">
  <path d="M 0 589 Q 297.64 565 595.28 589 L 595.28 841.89 L 0 841.89 Z" fill="#FFFFFF" />
  <path d="M 0 589 Q 297.64 565 595.28 589" fill="none" stroke="$accentSvgColor" stroke-width="4.5" stroke-linecap="round" />
</svg>
''',
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
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromInt(settings.coverHeadlineColorValue),
                      lineSpacing: 2,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Container(
                    width: 44,
                    height: 3.5,
                    color: accentPdfColor,
                  ),
                  pw.SizedBox(height: 10),
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

        // 4. Badges Informativos na Foto
        if (settings.verticalSplitShowLeftFooter && settings.verticalSplitFooterBadges.isNotEmpty)
          pw.Positioned(
            left: (a4W * settings.verticalSplitLeftFooterLeft).clamp(0.0, a4W * 0.90),
            top: a4H - (settings.verticalSplitLeftFooterBottom * a4H) - 24,
            child: pw.Row(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                for (final badge in settings.verticalSplitFooterBadges) ...[
                  pw.Container(
                    margin: const pw.EdgeInsets.only(right: 8),
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: pw.BoxDecoration(
                      color: PdfColor(accentPdfColor.red, accentPdfColor.green, accentPdfColor.blue, 0.20),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                      border: pw.Border.all(color: accentPdfColor, width: 1.0),
                    ),
                    child: pw.Row(
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        _buildPdfCoverCustomIcon(badge.iconKey, 10, accentPdfColor),
                        pw.SizedBox(width: 5),
                        pw.Text(
                          badge.label,
                          style: pw.TextStyle(
                            font: fontMontserratBold,
                            fontSize: 8.5,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromInt(settings.coverBadgesTextColorValue),
                          ),
                        ),
                      ],
                    ),
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
                  settings.verticalSplitRightTitle,
                  style: pw.TextStyle(
                    font: rightBlockFontBold ?? fontMontserratBold,
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromInt(settings.coverRightTitleColorValue),
                    letterSpacing: 4.5,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  settings.verticalSplitRightSubtitle,
                  style: pw.TextStyle(
                    font: rightBlockFontBlack ?? fontMontserratBlack,
                    fontSize: 34,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromInt(settings.coverRightSubtitleColorValue),
                    letterSpacing: 1.5,
                  ),
                ),
                pw.SizedBox(height: 9),
                pw.Container(
                  width: 44,
                  height: 3.5,
                  color: accentPdfColor,
                ),
                pw.SizedBox(height: 9),
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
              pw.MemoryImage(base64Decode(settings.companyLogoBase64!)),
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

        // 8. Informações do Cliente e Usina (Canto inferior direito fixo)
        pw.Positioned(
          bottom: 24,
          right: 40,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              if (proposal.clientName.isNotEmpty)
                pw.Text(
                  'Cliente: ${proposal.clientName}',
                  style: pw.TextStyle(
                    font: fontMontserratBold,
                    fontSize: 10.0,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromInt(0xFF0F172A),
                  ),
                ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Geração: ${_numberFormat.format(generationMonthly)} kWh/mês (${kwp.toStringAsFixed(2)} kWp)',
                style: pw.TextStyle(
                  font: fontMontserratBold,
                  fontSize: 9.0,
                  fontWeight: pw.FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              if (settings.companyName?.isNotEmpty == true) ...[
                pw.SizedBox(height: 2),
                pw.Text(
                  settings.companyName!,
                  style: pw.TextStyle(
                    fontSize: 8.5,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromInt(0xFF475569),
                  ),
                ),
              ],
            ],
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

  // ───────────────────────────────────────────────────────────────────────────
  // LAYOUT MINIMALISTA PROGRAMÁTICO (CABEÇALHO & RODAPÉ NATIVOS)
  // ───────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildProgrammaticPageLayout({
    required pw.Widget content,
    required String pageTitle,
    required int pageNumber,
    required int totalPages,
    required PdfColor primaryColor,
    required SolarSettingsModel settings,
    ProposalModel? proposal,
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

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 26),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // ── 1. CABEÇALHO MINIMALISTA ──────────────────────────────────────
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      // Barra vertical sólida de destaque
                      pw.Container(
                        width: 3.5,
                        height: 14,
                        decoration: pw.BoxDecoration(
                          color: primaryColor,
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(1.5)),
                        ),
                      ),
                      pw.SizedBox(width: 8),
                      // Título da Seção
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
              // Linha divisória fina com segmento de destaque à direita
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

          // ── 2. MIOLO DA PÁGINA (CONTEÚDO) ─────────────────────────────────
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 16),
              child: content,
            ),
          ),

          // ── 3. RODAPÉ MINIMALISTA ─────────────────────────────────────────
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Linha divisória superior do rodapé com segmento de destaque à direita
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
                  // Ícone de usina/energia + Slogan
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
                  // Numeração da página
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
        ],
      ),
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
  // PÁGINA 2: APRESENTAÇÃO & ESCOPO
  // ───────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildPage2Content(PdfColor primaryColor) {
    final hex = _pdfColorToHex(primaryColor);

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
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Ilustração / Mockup Central da Usina
        pw.Container(
          height: 140,
          width: double.infinity,
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#F8FAFC'),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(14)),
            border: pw.Border.all(color: PdfColor.fromHex('#CBD5E1')),
          ),
          child: pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Container(
                  width: 48,
                  height: 48,
                  decoration: pw.BoxDecoration(
                    color: primaryColor,
                    shape: pw.BoxShape.circle,
                  ),
                  child: pw.Center(
                    child: pw.SvgImage(
                      svg: SolarPdfIcons.solarTech('#FFFFFF', size: 28),
                      width: 28,
                      height: 28,
                    ),
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Kit Solar Fotovoltaico de Alta Eficiência',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A')),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  'Módulos Monocristalinos & Inversor Grid-Tie com Conexão Wi-Fi Integrada',
                  style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#64748B')),
                ),
              ],
            ),
          ),
        ),
        pw.SizedBox(height: 14),

        // Tabela de Especificações Técnicas com Ícones em Quadrados Sólidos com SVG Branco
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
          label: 'Modelo e Potência Inversor / Microinversor:',
          value: '$inverterModel ${inverterKw.toStringAsFixed(0)} kWp',
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

        pw.SizedBox(height: 16),

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
    );
  }

  static pw.Widget _buildPage3MiniCard({
    required String title,
    required String subtitle,
    required String iconSvg,
    required PdfColor primaryColor,
  }) {
    return pw.Container(
      height: 64,
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#F8FAFC'),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
        border: pw.Border.all(color: PdfColor.fromHex('#CBD5E1'), width: 0.8),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(
            width: 24,
            height: 24,
            decoration: pw.BoxDecoration(
              color: primaryColor,
              shape: pw.BoxShape.circle,
            ),
            child: pw.Center(
              child: pw.SvgImage(
                svg: iconSvg,
                width: 13,
                height: 13,
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
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A')),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  subtitle,
                  style: pw.TextStyle(fontSize: 7.2, color: PdfColor.fromHex('#64748B'), height: 1.15),
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
      padding: const pw.EdgeInsets.symmetric(vertical: 7.5, horizontal: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColor.fromInt(0xFFE2E8F0), width: 0.8)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Row(
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
                    svg: svgIcon,
                    width: 14,
                    height: 14,
                  ),
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Text(
                label,
                style: pw.TextStyle(
                  fontSize: 10.5,
                  color: PdfColor.fromHex('#334155'),
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.bold,
              color: PdfColor.fromHex('#0F172A'),
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
  }) {
    final components = solarPlantItem.solarComponents ?? [];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Lista dos Itens
        pw.Text(
          'Equipamentos & Componentes Inclusos no Conjunto',
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A')),
        ),
        pw.SizedBox(height: 10),

        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#F8FAFC'),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
            border: pw.Border.all(color: PdfColor.fromHex('#CBD5E1')),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (components.isNotEmpty)
                ...components.map((item) {
                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 8),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Container(
                          margin: const pw.EdgeInsets.only(right: 10),
                          width: 22,
                          height: 22,
                          decoration: pw.BoxDecoration(
                            color: primaryColor,
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
                          ),
                          child: pw.Center(
                            child: pw.SvgImage(
                              svg: _getComponentIcon(item, '#FFFFFF'),
                              width: 13,
                              height: 13,
                            ),
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Text(
                            item.toUpperCase(),
                            style: pw.TextStyle(fontSize: 9.8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1E293B')),
                          ),
                        ),
                      ],
                    ),
                  );
                })
              else ...[
                _buildDefaultEquipmentRow('1 x INVERSOR SOLAR DE ALTA EFICIÊNCIA GRID-TIE', SolarPdfIcons.inverter('#FFFFFF'), primaryColor),
                _buildDefaultEquipmentRow('14 x MÓDULOS FOTOVOLTAICOS MONOCRISTALINOS TIER 1', SolarPdfIcons.solarPanel('#FFFFFF'), primaryColor),
                _buildDefaultEquipmentRow('1 x ESTRUTURA DE FIXAÇÃO COMPLETA EM ALUMÍNIO', SolarPdfIcons.roof('#FFFFFF'), primaryColor),
                _buildDefaultEquipmentRow('1 x CABOS SOLARES COM PROTEÇÃO UV E CONECTORES MC4', SolarPdfIcons.bolt('#FFFFFF'), primaryColor),
              ],
            ],
          ),
        ),

        pw.SizedBox(height: 24),

        // Forma de Pagamento
        pw.Text(
          'Forma de Pagamento',
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A')),
        ),
        pw.SizedBox(height: 6),
        pw.Container(width: double.infinity, height: 1, color: PdfColor.fromHex('#CBD5E1')),
        pw.SizedBox(height: 8),
        pw.Text(
          proposal.paymentTerms.isNotEmpty ? proposal.paymentTerms : 'À Vista, Financiamento Bancário em até 90x ou Cartão de Crédito em até 18x',
          style: pw.TextStyle(fontSize: 10.5, color: PdfColor.fromHex('#475569')),
        ),

        pw.Spacer(),

        // Total da Proposta & Prazo de Entrega
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#F8FAFC'),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
            border: pw.Border.all(color: PdfColor.fromHex('#CBD5E1')),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Investimento Total da Usina', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#64748B'))),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    _currencyFormat.format(proposal.totalAmount),
                    style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#059669')),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Prazo de Entrega', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#64748B'))),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    (proposal.deliveryTime != null && proposal.deliveryTime!.isNotEmpty) ? proposal.deliveryTime! : '60 dias',
                    style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
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
  }) {
    final yearlyData = settings.calculateYearlySimulation(
      monthlyKwh: generationMonthly,
      systemKwp: kwp,
    );

    final totalWithoutSolar = yearlyData.fold(0.0, (prev, item) => prev + (item.withoutSolar * 12));
    final totalWithSolar = yearlyData.fold(0.0, (prev, item) => prev + (((item.withSolarMin + item.withSolarMax) / 2) * 12));
    final firstYearSavings = (yearlyData.first.withoutSolar * 12) - (((yearlyData.first.withSolarMin + yearlyData.first.withSolarMax) / 2) * 12);
    final totalSavings = totalWithoutSolar - totalWithSolar;
    final paybackMonths = ((proposal.totalAmount / (firstYearSavings / 12)).round()).clamp(12, 60);

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // ── Coluna Esquerda: Cards de Parâmetros e Economia ──
        pw.Expanded(
          flex: 5,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Card 1: Simultaneidade
              pw.Container(
                decoration: pw.BoxDecoration(
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  border: pw.Border.all(color: PdfColor.fromHex('#CBD5E1')),
                ),
                child: pw.Column(
                  children: [
                    _buildParamHeader('Simultaneidade', primaryColor),
                    _buildParamRow('Concessionária', settings.utilityCompany),
                    _buildParamRow('Simultaneidade', '${settings.simultaneityRate.toStringAsFixed(0)}%'),
                    _buildParamRow('Inflação Anual', '${settings.annualInflation.toStringAsFixed(0)}%'),
                    _buildParamRow('Consumo Mensal', '${_numberFormat.format(generationMonthly)} kWh'),
                    _buildParamRow('Consumo Diário', '${(generationDaily).toStringAsFixed(2)} kWh'),
                    _buildParamRow('Autoconsumo', '${(generationDaily * (settings.simultaneityRate / 100)).toStringAsFixed(2)} kWh'),
                    _buildParamRow('Geração Mensal', '${_numberFormat.format(generationMonthly)} kWh'),
                    _buildParamRow('Geração Diária', '${generationDaily.toStringAsFixed(2)} kWh'),
                    _buildParamRow('Injeção Diária', '${(generationDaily * (1 - (settings.simultaneityRate / 100))).toStringAsFixed(2)} kWh', isLast: true),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),

              // Card 2: Gasto com Energia até 2046
              pw.Container(
                decoration: pw.BoxDecoration(
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  border: pw.Border.all(color: PdfColor.fromHex('#CBD5E1')),
                ),
                child: pw.Column(
                  children: [
                    _buildParamHeader('Gasto Total até ${DateTime.now().year + settings.projectionYears - 1}', primaryColor),
                    _buildParamRow('Sem Energia Solar', _currencyFormat.format(totalWithoutSolar)),
                    _buildParamRow('Com Energia Solar', _currencyFormat.format(totalWithSolar), isLast: true),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),

              // Card 3: Simulação média de economia
              pw.Container(
                decoration: pw.BoxDecoration(
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  border: pw.Border.all(color: PdfColor.fromHex('#CBD5E1')),
                ),
                child: pw.Column(
                  children: [
                    _buildParamHeader('Simulação Média de Economia', primaryColor),
                    _buildParamRow('Economia 1º ano', _currencyFormat.format(firstYearSavings)),
                    _buildParamRow('Economia acumulada', _currencyFormat.format(totalSavings)),
                    _buildParamRow('Investimento', _currencyFormat.format(proposal.totalAmount)),
                    _buildParamRow('Tempo de Payback', '$paybackMonths Meses', isLast: true),
                  ],
                ),
              ),
            ],
          ),
        ),

        pw.SizedBox(width: 14),

        // ── Coluna Direita: Tabela Ano a Ano ──
        pw.Expanded(
          flex: 6,
          child: pw.Container(
            decoration: pw.BoxDecoration(
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              border: pw.Border.all(color: PdfColor.fromHex('#CBD5E1')),
            ),
            child: pw.Column(
              children: [
                // Header Principal no padrão dos cards
                _buildParamHeader('Simulação de Conta de Energia Elétrica', primaryColor),

                // Sub-header das Colunas
                pw.Container(
                  decoration: const pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFF334155),
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColor.fromInt(0xFFCBD5E1), width: 0.5)),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Container(
                        width: 38,
                        padding: const pw.EdgeInsets.symmetric(vertical: 3.5),
                        child: pw.Text(
                          'ANO',
                          textAlign: pw.TextAlign.center,
                          style: const pw.TextStyle(color: PdfColors.white, fontSize: 7, fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Container(
                          padding: const pw.EdgeInsets.symmetric(vertical: 3.5, horizontal: 4),
                          alignment: pw.Alignment.center,
                          child: pw.Text(
                            'COM SOLAR (VARIAÇÃO)',
                            textAlign: pw.TextAlign.center,
                            style: const pw.TextStyle(color: PdfColor.fromInt(0xFF86EFAC), fontSize: 7, fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Container(
                          padding: const pw.EdgeInsets.symmetric(vertical: 3.5, horizontal: 4),
                          alignment: pw.Alignment.center,
                          child: pw.Text(
                            'SEM SOLAR',
                            textAlign: pw.TextAlign.center,
                            style: const pw.TextStyle(color: PdfColors.white, fontSize: 7, fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Linhas da Tabela
                ...yearlyData.take(21).map((item) {
                  final isLast = item == yearlyData.take(21).last;
                  return pw.Container(
                    decoration: pw.BoxDecoration(
                      border: isLast ? null : const pw.Border(bottom: pw.BorderSide(color: PdfColor.fromInt(0xFFE2E8F0), width: 0.5)),
                    ),
                    child: pw.Row(
                      children: [
                        pw.Container(
                          width: 38,
                          padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
                          child: pw.Text('${item.year}', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Expanded(
                          child: pw.Container(
                            padding: const pw.EdgeInsets.symmetric(vertical: 2.5, horizontal: 4),
                            color: const PdfColor.fromInt(0xFFF0FDF4),
                            child: pw.Text(
                              '${_currencyFormat.format(item.withSolarMin)} à ${_currencyFormat.format(item.withSolarMax)}',
                              textAlign: pw.TextAlign.center,
                              style: const pw.TextStyle(fontSize: 7.5, color: PdfColor.fromInt(0xFF15803D), fontWeight: pw.FontWeight.bold),
                            ),
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Container(
                            padding: const pw.EdgeInsets.symmetric(vertical: 2.5, horizontal: 4),
                            color: const PdfColor.fromInt(0xFFF1F5F9),
                            child: pw.Text(
                              _currencyFormat.format(item.withoutSolar),
                              textAlign: pw.TextAlign.center,
                              style: const pw.TextStyle(fontSize: 7.5, color: PdfColor.fromInt(0xFF334155)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildParamHeader(String title, PdfColor primaryColor) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: pw.BoxDecoration(
        color: primaryColor,
        borderRadius: const pw.BorderRadius.vertical(top: pw.Radius.circular(6)),
      ),
      child: pw.Text(
        title,
        textAlign: pw.TextAlign.center,
        style: const pw.TextStyle(color: PdfColors.white, fontSize: 8.5, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  static pw.Widget _buildParamRow(String label, String value, {bool isLast = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.5, horizontal: 6),
      decoration: pw.BoxDecoration(
        border: isLast ? null : const pw.Border(bottom: pw.BorderSide(color: PdfColor.fromInt(0xFFE2E8F0), width: 0.5)),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 6,
            child: pw.Text(label, style: const pw.TextStyle(fontSize: 7.5, color: PdfColor.fromInt(0xFF475569))),
          ),
          pw.Expanded(
            flex: 6,
            child: pw.Text(value, textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 7.5, color: PdfColor.fromInt(0xFF0F172A), fontWeight: pw.FontWeight.bold)),
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
  }) {
    final activeBanks = settings.financingBanks.where((b) => b.isActive).toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Simulação de Financiamento Solar Bancário',
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A')),
        ),
        pw.SizedBox(height: 12),

        // Grid dos Bancos (2x2)
        pw.Row(
          children: [
            if (activeBanks.isNotEmpty)
              pw.Expanded(child: _buildBankCard(activeBanks[0], proposal.totalAmount, primaryColor))
            else
              pw.Expanded(child: _buildBankCard(const SolarFinancingBank(id: 'solfacil', name: 'SolFácil', monthlyInterestRate: 1.25, enabledInstallments: [12, 24, 36, 48, 60]), proposal.totalAmount, primaryColor)),
            pw.SizedBox(width: 14),
            if (activeBanks.length > 1)
              pw.Expanded(child: _buildBankCard(activeBanks[1], proposal.totalAmount, primaryColor))
            else
              pw.Expanded(child: _buildBankCard(const SolarFinancingBank(id: 'santander', name: 'Santander', monthlyInterestRate: 1.19, enabledInstallments: [12, 24, 36, 48, 60]), proposal.totalAmount, primaryColor)),
          ],
        ),
        pw.SizedBox(height: 12),

        pw.Row(
          children: [
            if (activeBanks.length > 2)
              pw.Expanded(child: _buildBankCard(activeBanks[2], proposal.totalAmount, primaryColor))
            else
              pw.Expanded(child: _buildBankCard(const SolarFinancingBank(id: 'sicredi', name: 'Sicredi', monthlyInterestRate: 1.15, enabledInstallments: [12, 24, 36, 60, 90]), proposal.totalAmount, primaryColor)),
            pw.SizedBox(width: 14),
            if (activeBanks.length > 3)
              pw.Expanded(child: _buildBankCard(activeBanks[3], proposal.totalAmount, primaryColor))
            else
              pw.Expanded(child: _buildBankCard(const SolarFinancingBank(id: 'bv', name: 'BV Financeira', monthlyInterestRate: 1.09, enabledInstallments: [12, 24, 36, 48, 60]), proposal.totalAmount, primaryColor)),
          ],
        ),

        pw.SizedBox(height: 22),

        // Seção Cartão de Crédito
        pw.Text(
          'Parcelamento no Cartão de Crédito',
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A')),
        ),
        pw.SizedBox(height: 10),

        pw.Container(
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#F8FAFC'),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
            border: pw.Border.all(color: PdfColor.fromHex('#CBD5E1')),
          ),
          child: pw.Row(
            children: [
              // Bandeiras Aceitas
              pw.Expanded(
                flex: 5,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Bandeiras Aceitas:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#334155'))),
                    pw.SizedBox(height: 6),
                    pw.Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: ['VISA', 'MASTERCARD', 'ELO', 'AMEX', 'HIPERCARD', 'DINERS CLUB'].map((b) {
                        return pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.white,
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                            border: pw.Border.all(color: PdfColor.fromHex('#CBD5E1')),
                          ),
                          child: pw.Text(b, style: const pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

              pw.Container(width: 1, height: 75, color: PdfColor.fromHex('#CBD5E1')),
              pw.SizedBox(width: 14),

              // Parcelas
              pw.Expanded(
                flex: 5,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    ...[3, 6, 9, 12].map((installments) {
                      final rateItem = settings.creditCardRates.firstWhere(
                        (r) => r.installment == installments,
                        orElse: () => CreditCardInstallmentRate(installment: installments, feePercentage: installments * 1.05),
                      );
                      final val = rateItem.calculateInstallmentValue(proposal.totalAmount);

                      return pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 3),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('$installments' 'x no Cartão:', style: const pw.TextStyle(fontSize: 9, color: PdfColors.black)),
                            pw.Text(
                              _currencyFormat.format(val),
                              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A')),
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
    );
  }

  static pw.Widget _buildBankCard(SolarFinancingBank bank, double totalAmount, PdfColor primaryColor) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
        border: pw.Border.all(color: PdfColor.fromHex('#CBD5E1'), width: 0.8),
      ),
      child: pw.Row(
        children: [
          // Logo / Nome do Banco
          pw.Expanded(
            flex: 4,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  bank.name,
                  style: pw.TextStyle(fontSize: 11.5, fontWeight: pw.FontWeight.bold, color: primaryColor),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Taxa: ${bank.monthlyInterestRate.toStringAsFixed(2)}% a.m.',
                  style: pw.TextStyle(fontSize: 7.5, color: PdfColor.fromHex('#64748B')),
                ),
              ],
            ),
          ),

          pw.SizedBox(width: 8),

          // Prazos e Parcelas
          pw.Expanded(
            flex: 6,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: bank.enabledInstallments.take(5).map((months) {
                final installmentVal = bank.calculateInstallment(totalAmount, months);
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 1.5),
                  child: pw.Text(
                    '$months' 'x de ${_currencyFormat.format(installmentVal)}',
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A')),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
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
      return SolarPdfIcons.inverter(hex);
    } else if (upper.contains('MÓDULO') || upper.contains('MODULO') || upper.contains('PAINEL') || upper.contains('PLACA') || upper.contains('FOTOVOLTAICO')) {
      return SolarPdfIcons.solarPanel(hex);
    } else if (upper.contains('ESTRUTURA') || upper.contains('PERFIL') || upper.contains('FIXAÇÃO') || upper.contains('FIXACAO') || upper.contains('TELHADO')) {
      return SolarPdfIcons.roof(hex);
    } else if (upper.contains('STRING') || upper.contains('DPS') || upper.contains('CHAVE') || upper.contains('QUADRO') || upper.contains('PROTEÇÃO') || upper.contains('PROTECAO')) {
      return SolarPdfIcons.shieldCheck(hex);
    } else if (upper.contains('CABO') || upper.contains('CONECTOR') || upper.contains('MC4')) {
      return SolarPdfIcons.bolt(hex);
    } else if (upper.contains('HOMOLOGAÇÃO') || upper.contains('HOMOLOGACAO') || upper.contains('ENGENHARIA') || upper.contains('PROJETO') || upper.contains('ART')) {
      return SolarPdfIcons.award(hex);
    } else {
      return SolarPdfIcons.solarTech(hex);
    }
  }

  static pw.Widget _buildDefaultEquipmentRow(String text, String svg, PdfColor primaryColor) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(
            margin: const pw.EdgeInsets.only(right: 10),
            width: 22,
            height: 22,
            decoration: pw.BoxDecoration(
              color: primaryColor,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
            ),
            child: pw.Center(
              child: pw.SvgImage(
                svg: svg,
                width: 13,
                height: 13,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              text,
              style: pw.TextStyle(fontSize: 9.8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1E293B')),
            ),
          ),
        ],
      ),
    );
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
}

