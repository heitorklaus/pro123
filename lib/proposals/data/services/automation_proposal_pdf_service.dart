import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../products/domain/models/product_model.dart';
import '../../../products/domain/models/automation_study_model.dart';
import '../../../settings/data/services/automation_settings_service.dart';
import '../../../settings/domain/models/automation_settings_model.dart';
import '../../../settings/domain/models/proposal_pages_models.dart';
import '../../domain/models/proposal_model.dart';
import 'cover_divider_svg_builder.dart';

/// Serviço de Compilação, Geração e Download de Propostas de Automação Residencial em PDF A4
class AutomationProposalPdfService {
  static final _currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

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

  /// Gera o arquivo PDF da Proposta de Automação em formato Uint8List (Pronto para impressão / download)
  static Future<Uint8List> generateProposalPdf({
    ProductModel? studyProduct,
    required AutomationSettingsModel settings,
    ProposalModel? proposal,
  }) async {
    final pdf = pw.Document();
    final effectiveProduct = studyProduct ?? _buildSampleProduct();
    final effectiveProposal = proposal ?? _buildSampleProposal(settings);

    // Fontes
    final fontRegular = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();
    final fontOutfit = await PdfGoogleFonts.outfitBold();

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

    final primaryColor = _parsePdfColor(settings.primaryColorHex);
    final environments = effectiveProduct.automationEnvironments;

    // 1. Custom base64 da Capa
    Uint8List? coverBytes;
    if (settings.customCoverImageBase64 != null && settings.customCoverImageBase64!.isNotEmpty) {
      try {
        final clean = settings.customCoverImageBase64!.contains(',')
            ? settings.customCoverImageBase64!.split(',').last
            : settings.customCoverImageBase64!;
        coverBytes = base64Decode(clean);
      } catch (_) {}
    }

    // 2. Extrai imagem configurada no Tema da Proposta do Produto (se houver)
    String? preferredImage;
    final productTheme = effectiveProduct.specificAttributes['proposalTheme'] as Map<String, dynamic>?;
    final productBg = productTheme?['backgroundImageUrl'] as String?;
    if (productBg != null && productBg.trim().isNotEmpty) {
      preferredImage = productBg.trim();
    }

    // 3. Fallback para selectedCoverTemplate / webBackgroundTemplate / coverImageUrl
    if (preferredImage == null || preferredImage.isEmpty) {
      if (settings.selectedCoverTemplate.isNotEmpty) {
        preferredImage = settings.selectedCoverTemplate;
      } else if (settings.webBackgroundTemplate.isNotEmpty) {
        preferredImage = settings.webBackgroundTemplate;
      } else if (settings.coverImageUrl.isNotEmpty) {
        preferredImage = settings.coverImageUrl;
      }
    }

    if (coverBytes == null && preferredImage != null && preferredImage.isNotEmpty) {
      try {
        coverBytes = await AutomationSettingsService.fetchCoverBytes(preferredImage);
      } catch (_) {}
      if (coverBytes == null) {
        try {
          coverBytes = await AutomationSettingsService.fetchWebBackgroundBytes(preferredImage);
        } catch (_) {}
      }
    }

    // 4. Se ainda null, tenta o template de wallpaper web configurado
    if (coverBytes == null && settings.webBackgroundTemplate.isNotEmpty) {
      try {
        coverBytes = await AutomationSettingsService.fetchWebBackgroundBytes(settings.webBackgroundTemplate);
      } catch (_) {}
    }

    // 5. Fallback padrão garantido: AdobeStock_1030854734.jpg (Mansão azul noturna)
    if (coverBytes == null) {
      try {
        coverBytes = await AutomationSettingsService.fetchWebBackgroundBytes('AdobeStock_1030854734.jpg');
      } catch (_) {}
    }

    // 6. Fallback final para modelo_automacao_1.jpg
    if (coverBytes == null) {
      try {
        coverBytes = await AutomationSettingsService.fetchCoverBytes('modelo_automacao_1.jpg');
      } catch (_) {}
    }

    // -------------------------------------------------------------
    // 📄 PÁGINA 1: CAPA FIEL AO ESTÚDIO INTERATIVO A4 (CLONE USINA SOLAR)
    // -------------------------------------------------------------
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (context) => _buildCoverPage(
          coverBytes: coverBytes,
          proposal: effectiveProposal,
          settings: settings,
          primaryColor: primaryColor,
          fontMontserratBlack: fontMontserratBlack ?? fontOutfit,
          fontMontserratBold: fontMontserratBold ?? fontBold,
          fontMontserratSemiBold: fontMontserratSemiBold ?? fontBold,
          headlineFontBold: headlineFontBold ?? fontBold,
          headlineFontBlack: headlineFontBlack ?? fontOutfit,
          rightBlockFontBold: rightBlockFontBold ?? fontBold,
          rightBlockFontBlack: rightBlockFontBlack ?? fontOutfit,
          footerFontBold: footerFontBold ?? fontBold,
        ),
      ),
    );

    final hiddenPages = settings.hiddenPageIds;
    final customPages = settings.customPages;

    int totalPages = 1; // Capa (page_1)
    if (!hiddenPages.contains('page_2')) totalPages++;
    if (!hiddenPages.contains('page_3')) totalPages++;
    if (!hiddenPages.contains('page_4')) totalPages++;
    if (!hiddenPages.contains('page_5')) totalPages++;
    for (final cp in customPages) {
      if (!hiddenPages.contains(cp.id)) totalPages++;
    }

    int curPage = 1;
    // Capa (Página 1)
    curPage++;

    // -------------------------------------------------------------
    // 📄 PÁGINA 2: BENEFÍCIOS DA AUTOMAÇÃO & ESCOPO DO PROJETO (CARDS 2x2)
    // -------------------------------------------------------------
    Uint8List? smartHomeBannerBytes;
    try {
      final imgPath = (settings.page2IllustrationType.toLowerCase() == 'isometric')
          ? 'assets/images/smart_home_isometric.jpg'
          : 'assets/images/smart_home_banner.jpg';
      final data = await rootBundle.load(imgPath);
      smartHomeBannerBytes = data.buffer.asUint8List();
    } catch (_) {}

    Uint8List? defaultRoomHeroBytes;
    try {
      final heroData = await rootBundle.load('assets/images/smart_home_hero.jpg');
      defaultRoomHeroBytes = heroData.buffer.asUint8List();
    } catch (_) {}

    if (!hiddenPages.contains('page_2')) {
      pdf.addPage(
        _buildProgrammaticPage(
          settings: settings,
          primaryColor: primaryColor,
          fontBold: fontBold,
          fontSemiBold: fontMontserratSemiBold,
          pageNumber: curPage++,
          totalPages: totalPages,
          content: _buildPage2CardsContent(
            primaryColor,
            fontOutfit,
            fontBold,
            fontRegular,
            bannerImageBytes: smartHomeBannerBytes,
            customCards: settings.page2Cards,
            showIllustration: settings.page2ShowIllustration,
            illustrationType: settings.page2IllustrationType,
          ),
        ),
      );
    }

    // -------------------------------------------------------------
    // 📄 PÁGINA 3: PORTFÓLIO & CLIENTES (CASES DE SUCESSO)
    // -------------------------------------------------------------
    if (!hiddenPages.contains('page_3')) {
      final p3BgColor = _parsePdfColor(settings.page3BgColor.isNotEmpty ? settings.page3BgColor : '#0B132B');
      final p3CardBgColor = _parsePdfColor(settings.page3CardBgColor.isNotEmpty ? settings.page3CardBgColor : '#111C38');
      final p3BorderColor = _parsePdfColor(settings.page3BorderColor.isNotEmpty ? settings.page3BorderColor : '#00E5FF');
      final p3TitleColor = _parsePdfColor(settings.page3TitleColor.isNotEmpty ? settings.page3TitleColor : '#FFFFFF');
      final p3SubtitleColor = _parsePdfColor(settings.page3SubtitleColor.isNotEmpty ? settings.page3SubtitleColor : '#94A3B8');
      final p3AccentColor = _parsePdfColor(settings.page3AccentColor.isNotEmpty ? settings.page3AccentColor : '#00E5FF');

      final portfolioItems = settings.page3PortfolioItems.where((c) => c.isVisible).toList();
      final effectiveItems = portfolioItems.isNotEmpty ? portfolioItems : AutomationPortfolioItem.defaultItems();

      pdf.addPage(
        _buildProgrammaticPage(
          settings: settings,
          primaryColor: primaryColor,
          fontBold: fontBold,
          fontSemiBold: fontMontserratSemiBold,
          pageNumber: curPage++,
          totalPages: totalPages,
          pageBgColor: p3BgColor,
          content: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildPdfHeader(
                settings.page3Subtitle.isNotEmpty ? settings.page3Subtitle : 'Cases de Sucesso e Obras Concluídas',
                settings.page3Title.isNotEmpty ? settings.page3Title : 'PORTFÓLIO & CLIENTES',
                p3AccentColor,
                fontOutfit,
                fontRegular,
                titleColor: p3TitleColor,
                subtitleColor: p3AccentColor,
              ),
              pw.SizedBox(height: 12),
              ...effectiveItems.take(3).map((item) {
                final idx = effectiveItems.indexOf(item);
                Uint8List? fallback = (idx == 0)
                    ? defaultRoomHeroBytes
                    : (idx == 1 ? smartHomeBannerBytes : defaultRoomHeroBytes);
                return _buildPdfPortfolioCard(
                  item: item,
                  cardBgColor: p3CardBgColor,
                  borderColor: p3BorderColor,
                  titleColor: p3TitleColor,
                  subtitleColor: p3SubtitleColor,
                  accentColor: p3AccentColor,
                  fontBold: fontBold,
                  fontRegular: fontRegular,
                  fontOutfit: fontOutfit,
                  fallbackPhotoBytes: fallback,
                );
              }),
            ],
          ),
        ),
      );
    }

    // -------------------------------------------------------------
    // 📄 PÁGINA 4: DETALHAMENTO DE EQUIPAMENTOS POR CÔMODO (CARDS PROPOSTA WEB - IMAGEM 1)
    // -------------------------------------------------------------
    if (!hiddenPages.contains('page_4')) {
      final p4BgColor = _parsePdfColor(settings.page4BgColor.isNotEmpty ? settings.page4BgColor : '#0B132B');
      final p4CardBgColor = _parsePdfColor(settings.page4CardBgColor.isNotEmpty ? settings.page4CardBgColor : '#111C38');
      final p4BorderColor = _parsePdfColor(settings.page4BorderColor.isNotEmpty ? settings.page4BorderColor : '#00E5FF');
      final p4TitleColor = _parsePdfColor(settings.page4TitleColor.isNotEmpty ? settings.page4TitleColor : '#FFFFFF');
      final p4SubtitleColor = _parsePdfColor(settings.page4SubtitleColor.isNotEmpty ? settings.page4SubtitleColor : '#94A3B8');
      final p4AccentColor = _parsePdfColor(settings.page4AccentColor.isNotEmpty ? settings.page4AccentColor : '#00E5FF');

      // Ambientes efetivos
      final effectiveEnvironments = environments.isNotEmpty
          ? environments
          : [
              AutomationEnvironment(
                id: 'demo_env',
                name: 'Ambiente Principal Integrado',
                description: 'Automação residencial completa de iluminação, climatização e conforto.',
                items: [
                  AutomationItem(
                    id: 'it_1',
                    name: effectiveProduct.name.isNotEmpty ? effectiveProduct.name : 'Central de Automação & Módulos',
                    quantity: 1,
                    unitPrice: effectiveProduct.salePrice > 0 ? effectiveProduct.salePrice : 5000.0,
                    categoryTitle: 'Automação',
                    manufacturer: (effectiveProduct.supplierName != null && effectiveProduct.supplierName!.isNotEmpty)
                        ? effectiveProduct.supplierName!
                        : settings.companyName,
                  ),
                ],
              ),
            ];

      // Divide os ambientes em páginas (máximo 2 ambientes por página se forem curtos, ou 1 por página se tiver mais de 4 itens)
      final List<List<AutomationEnvironment>> envPages = [];
      List<AutomationEnvironment> currentBatch = [];
      int currentItemsInBatch = 0;

      for (final env in effectiveEnvironments) {
        final int count = env.items.length;
        if (currentBatch.isNotEmpty && (currentBatch.length >= 2 || currentItemsInBatch + count > 5)) {
          envPages.add(List.from(currentBatch));
          currentBatch = [];
          currentItemsInBatch = 0;
        }
        currentBatch.add(env);
        currentItemsInBatch += count;
      }
      if (currentBatch.isNotEmpty) {
        envPages.add(currentBatch);
      }

      for (int i = 0; i < envPages.length; i++) {
        final pageBatch = envPages[i];
        final isFirstPage = i == 0;

        pdf.addPage(
          _buildProgrammaticPage(
            settings: settings,
            primaryColor: primaryColor,
            fontBold: fontBold,
            fontSemiBold: fontMontserratSemiBold,
            pageNumber: curPage++,
            totalPages: totalPages,
            pageBgColor: p4BgColor,
            content: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildPdfHeader(
                  isFirstPage ? 'CATÁLOGO & EQUIPAMENTOS' : 'CATÁLOGO & EQUIPAMENTOS (CONTINUAÇÃO)',
                  'Detalhamento Técnico por Ambiente',
                  p4AccentColor,
                  fontOutfit,
                  fontRegular,
                  titleColor: p4TitleColor,
                  subtitleColor: p4AccentColor,
                ),
                pw.SizedBox(height: 12),
                ...pageBatch.map((env) => _buildPdfEnvironmentCard(
                      env: env,
                      proposalTotal: effectiveProposal.totalAmount,
                      cardBgColor: p4CardBgColor,
                      borderColor: p4BorderColor,
                      titleColor: p4TitleColor,
                      subtitleColor: p4SubtitleColor,
                      accentColor: p4AccentColor,
                      fontBold: fontBold,
                      fontRegular: fontRegular,
                      fontOutfit: fontOutfit,
                      defaultRoomPhotoBytes: defaultRoomHeroBytes,
                    )),
              ],
            ),
          ),
        );
      }
    }

    // -------------------------------------------------------------
    // 📄 PÁGINA 5: RESUMO FINANCEIRO & TERMOS DE GARANTIA
    // -------------------------------------------------------------
    final attrs = effectiveProduct.specificAttributes;
    final labor = (attrs['laborPrice'] as num?)?.toDouble() ?? 0.0;
    final productsTotal = effectiveProduct.salePrice;
    final grandTotal = productsTotal + labor;

    if (!hiddenPages.contains('page_5')) {
      pdf.addPage(
        _buildProgrammaticPage(
          settings: settings,
          primaryColor: primaryColor,
          fontBold: fontBold,
          fontSemiBold: fontMontserratSemiBold,
          pageNumber: curPage++,
          totalPages: totalPages,
          content: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildPdfHeader('RESUMO FINANCEIRO & CONDIÇÕES', 'Investimento & Garantias da Solução', primaryColor, fontOutfit, fontRegular),
              pw.SizedBox(height: 20),
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F8FAFC'),
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: primaryColor, width: 1.5),
                ),
                child: pw.Column(
                  children: [
                    _buildFinanceRow('VALOR DOS EQUIPAMENTOS:', _currencyFormat.format(productsTotal), fontRegular, fontBold),
                    pw.SizedBox(height: 6),
                    _buildFinanceRow('MÃO DE OBRA & CONFIGURAÇÃO:', _currencyFormat.format(labor), fontRegular, fontBold),
                    pw.SizedBox(height: 10),
                    pw.Divider(color: primaryColor),
                    pw.SizedBox(height: 10),
                    _buildFinanceRow('INVESTIMENTO TOTAL:', _currencyFormat.format(grandTotal), fontBold, fontOutfit, isTotal: true, color: primaryColor),
                  ],
                ),
              ),
              pw.SizedBox(height: 24),
              pw.Text('TERMOS, GARANTIAS & VALIDADE:', style: pw.TextStyle(font: fontOutfit, fontSize: 12, color: PdfColor.fromHex('#0F172A'))),
              pw.SizedBox(height: 8),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F1F5F9'),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Text(
                  settings.pdfTermsText.isNotEmpty
                      ? settings.pdfTermsText
                      : '• Validade desta proposta: 10 dias corridos.\n• Garantia dos equipamentos conforme fabricante (12 a 60 meses).\n• Instalação homologada com equipe especializada e suporte dedicado.',
                  style: pw.TextStyle(font: fontRegular, fontSize: 9, color: PdfColor.fromHex('#475569')),
                ),
              ),
              pw.Spacer(),
              pw.Center(
                child: pw.Text(
                  'Obrigado por escolher a ${settings.companyName}!',
                  style: pw.TextStyle(font: fontOutfit, fontSize: 12, color: primaryColor),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // -------------------------------------------------------------
    // 📄 PÁGINAS PERSONALIZADAS DO USUÁRIO
    // -------------------------------------------------------------
    for (final cp in customPages) {
      if (!hiddenPages.contains(cp.id)) {
        pdf.addPage(
          _buildProgrammaticPage(
            settings: settings,
            primaryColor: primaryColor,
            fontBold: fontBold,
            fontSemiBold: fontMontserratSemiBold,
            pageNumber: curPage++,
            totalPages: totalPages,
            content: _buildCustomPageContent(cp, primaryColor, fontOutfit, fontBold, fontRegular),
          ),
        );
      }
    }

    return pdf.save();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // LAYOUT DAS PÁGINAS INTERNAS (CABEÇALHO & RODAPÉ AUTOMÁTICOS - FUNDO BRANCO PURO)
  // ───────────────────────────────────────────────────────────────────────────
  static pw.Page _buildProgrammaticPage({
    required pw.Widget content,
    required AutomationSettingsModel settings,
    required PdfColor primaryColor,
    pw.Font? fontBold,
    pw.Font? fontSemiBold,
    int? pageNumber,
    int? totalPages,
    PdfColor? pageBgColor,
  }) {
    final customHeaderBg = settings.coverHeaderBgColor.isNotEmpty ? _parsePdfColor(settings.coverHeaderBgColor) : null;
    final customHeaderTxt = settings.coverHeaderTextColor.isNotEmpty ? _parsePdfColor(settings.coverHeaderTextColor) : null;
    final customHeaderIcon = settings.coverHeaderIconColor.isNotEmpty ? _parsePdfColor(settings.coverHeaderIconColor) : null;

    final customFooterBg = settings.coverFooterBgColor.isNotEmpty ? _parsePdfColor(settings.coverFooterBgColor) : null;
    final customFooterTxt = settings.coverFooterTextColor.isNotEmpty ? _parsePdfColor(settings.coverFooterTextColor) : null;
    final customFooterIcon = settings.coverFooterIconColor.isNotEmpty ? _parsePdfColor(settings.coverFooterIconColor) : null;

    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (pw.Context context) {
        return pw.Container(
          color: pageBgColor ?? PdfColors.white,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // 1. Cabeçalho das Páginas Internas
              if (settings.coverShowHeader)
                _buildPdfCoverHeader(
                  styleId: settings.coverHeaderStyle,
                  text1: settings.coverHeaderText1.isNotEmpty ? settings.coverHeaderText1 : 'AUTOMAÇÃO RESIDENCIAL',
                  text2: settings.coverHeaderText2.isNotEmpty ? settings.coverHeaderText2 : settings.companyName,
                  text3: settings.coverHeaderText3.isNotEmpty ? settings.coverHeaderText3 : (pageNumber != null ? 'Página $pageNumber de $totalPages' : ''),
                  accentColor: primaryColor,
                  fontBold: fontBold,
                  fontSemiBold: fontSemiBold,
                  customBgColor: customHeaderBg,
                  customTextColor: customHeaderTxt,
                  customIconColor: customHeaderIcon,
                ),

              // 2. Miolo da Página (Conteúdo)
              pw.Expanded(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 20),
                  child: content,
                ),
              ),

              // 3. Rodapé das Páginas Internas
              if (settings.coverShowFooter)
                _buildPdfCoverFooter(
                  styleId: settings.coverFooterStyle,
                  text1: settings.coverFooterText1.isNotEmpty ? settings.coverFooterText1 : 'A CASA QUE ENTENDE VOCÊ • EXPERIÊNCIA ÚNICA',
                  text2: settings.coverFooterText2.isNotEmpty ? settings.coverFooterText2 : (settings.companyPhone.isNotEmpty ? '${settings.companyPhone}  •  ${settings.companyEmail}' : settings.companyEmail),
                  text3: settings.coverFooterText3.isNotEmpty ? settings.coverFooterText3 : settings.companyWebsite,
                  text4: settings.coverFooterText4.isNotEmpty ? settings.coverFooterText4 : (pageNumber != null ? 'Página $pageNumber de $totalPages' : ''),
                  accentColor: primaryColor,
                  fontBold: fontBold,
                  fontSemiBold: fontSemiBold,
                  customBgColor: customFooterBg,
                  customTextColor: customFooterTxt,
                  customIconColor: customFooterIcon,
                ),
            ],
          ),
        );
      },
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // CONSTRUÇÃO DA CAPA (PÁGINA 1) — VERTICAL SPLIT & MODERN
  // ───────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildCoverPage({
    required Uint8List? coverBytes,
    required ProposalModel proposal,
    required AutomationSettingsModel settings,
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

    // Estilo Modern (Full Bleed com elementos interativos)
    const a4W = 595.28;
    const a4H = 841.89;
    final accentPdfColor = PdfColor.fromInt(settings.verticalSplitAccentColorValue);
    final accentHex = (settings.customDividerColor.isNotEmpty
            ? settings.customDividerColor
            : (settings.verticalSplitAccentColor.isNotEmpty ? settings.verticalSplitAccentColor : '#38BDF8'))
        .replaceAll('#', '')
        .trim();
    final accentSvgColor = '#${accentHex.isNotEmpty ? accentHex : '38BDF8'}';
    final bottomAreaHex = (settings.customDividerBottomColor.isNotEmpty
            ? settings.customDividerBottomColor
            : '#FFFFFF')
        .replaceAll('#', '')
        .trim();
    final bottomAreaSvgColor = '#${bottomAreaHex.isNotEmpty ? bottomAreaHex : 'FFFFFF'}';

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
        // 1. Imagem de Fundo da Capa
        if (coverBytes != null)
          pw.Image(pw.MemoryImage(coverBytes), fit: pw.BoxFit.cover)
        else
          pw.Container(
            color: PdfColor.fromHex('#0F172A'),
          ),

        // 2. Separador Vetorial se ativo (10 Estilos Matemáticos)
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
                      fontSize: 22,
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

        // 5. Bloco Institucional
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

        // 6. Logomarca Customizada
        if (logoBytes != null && settings.coverShowLogo)
          pw.Positioned(
            left: (a4W * settings.coverLogoPositionX).clamp(0.0, a4W - settings.coverLogoWidth),
            top: (a4H * settings.coverLogoPositionY).clamp(0.0, a4H - 50.0),
            child: pw.Image(
              pw.MemoryImage(logoBytes),
              width: settings.coverLogoWidth,
              fit: pw.BoxFit.contain,
            ),
          ),

        // 7. Rodapé Institucional
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

        // 8. Informações do Cliente e Projeto Posicionadas pelo Usuário
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
                    'Solução: ${proposal.title.isNotEmpty ? proposal.title : 'Automação Residencial Smart'}',
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

        // 9. Textos Personalizados Extras
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

        // 10. Ícones Personalizados Extras
        for (final iconItem in settings.customIconItems)
          pw.Positioned(
            left: iconItem.x * a4W,
            top: iconItem.y * a4H,
            child: _buildPdfCoverCustomIcon(iconItem.iconKey, iconItem.size, PdfColor.fromInt(iconItem.colorValue)),
          ),

        // 11. Linhas Cibernéticas & Nós de Automação (Cyber Nodes)
        if (settings.nodes.isNotEmpty) ...[
          pw.SvgImage(
            svg: _buildCyberConnectorsSvg(settings.nodes, a4W, a4H),
          ),
          for (final node in settings.nodes) ...[
            pw.Positioned(
              left: (node.posX * a4W) - 15,
              top: (node.posY * a4H) - 15,
              child: pw.Container(
                width: 30,
                height: 30,
                decoration: pw.BoxDecoration(
                  shape: pw.BoxShape.circle,
                  color: PdfColor.fromHex('#0F172A'),
                  border: pw.Border.all(
                    color: _parsePdfColor(node.colorHex),
                    width: 1.8,
                  ),
                ),
                child: pw.Center(
                  child: _buildPdfCoverCustomIcon(
                    node.iconName,
                    15,
                    _parsePdfColor(node.colorHex),
                  ),
                ),
              ),
            ),
            pw.Positioned(
              left: (node.posX * a4W) - 45,
              top: (node.posY * a4H) + 16,
              child: pw.SizedBox(
                width: 90,
                child: pw.Center(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#0F172A'),
                      borderRadius: pw.BorderRadius.circular(3),
                      border: pw.Border.all(
                        color: _parsePdfColor(node.colorHex, alpha: 0.5),
                        width: 0.6,
                      ),
                    ),
                    child: pw.Text(
                      node.label.toUpperCase(),
                      style: pw.TextStyle(
                        font: fontMontserratBold,
                        fontSize: (settings.coverNodesLabelFontSize * 0.85).clamp(4.0, 16.0),
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                      maxLines: 1,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],




      ],
    );
  }

  /// Constrói a Capa Vertical Split multipadrão com vetor e layout A4 editorial
  static pw.Widget _buildVerticalSplitPdfCover({
    required Uint8List? coverBytes,
    required ProposalModel proposal,
    required AutomationSettingsModel settings,
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
    final rightSideFillHex = (settings.customDividerBottomColor.isNotEmpty
            ? settings.customDividerBottomColor
            : '#FFFFFF')
        .replaceAll('#', '')
        .trim();
    final rightSideSvgColor = '#${rightSideFillHex.isNotEmpty ? rightSideFillHex : 'FFFFFF'}';

    // SVG Overlay vetorial: máscara cobrindo o lado direito e linha de destaque
    String svgOverlay;
    if (divType == 1) {
      // Tipo 1: Raio de Energia (Zig-zag)
      svgOverlay = '''
<svg viewBox="0 0 595.28 841.89" width="595.28" height="841.89" xmlns="http://www.w3.org/2000/svg">
  <polygon points="405,0 595.28,0 595.28,841.89 208,841.89 321,547 250,547 386,269 285,269" fill="$rightSideSvgColor" />
  <polyline points="405,0 285,269 386,269 250,547 321,547 208,841.89" fill="none" stroke="$accentSvgColor" stroke-width="4.5" stroke-linecap="round" stroke-linejoin="round" />
</svg>
''';
    } else if (divType == 2) {
      // Tipo 2: Sol Radiante / Arco Tech
      svgOverlay = '''
<svg viewBox="0 0 595.28 841.89" width="595.28" height="841.89" xmlns="http://www.w3.org/2000/svg">
  <path d="M 210 0 L 595.28 0 L 595.28 841.89 L 360 841.89 L 260 620 A 210 210 0 0 0 260 210 Z" fill="$rightSideSvgColor" />
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
      // Tipo 0: Corte Diagonal Reto
      svgOverlay = '''
<svg viewBox="0 0 595.28 841.89" width="595.28" height="841.89" xmlns="http://www.w3.org/2000/svg">
  <polygon points="392,0 595.28,0 595.28,841.89 208,841.89" fill="$rightSideSvgColor" />
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
                      fontSize: 24,
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
                      : pw.Row(
                          mainAxisSize: pw.MainAxisSize.min,
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
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
                                  margin: const pw.EdgeInsets.symmetric(horizontal: 6),
                                ),
                            ],
                          ],
                        ),
            ),
          ),

        // 5. Lado Direito (Institucional)
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

        // 6. Logomarca da Empresa
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

        // 7. Rodapé do Lado Direito
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
                    'Proposta: PROP-${proposal.proposalNumber}  |  Automação Residencial',
                    style: pw.TextStyle(
                      fontSize: 7.5,
                      color: PdfColor.fromInt(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // 8. Textos Personalizados Extras
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

        // 9. Ícones Personalizados Extras
        for (final iconItem in settings.customIconItems)
          pw.Positioned(
            left: iconItem.x * a4W,
            top: iconItem.y * a4H,
            child: _buildPdfCoverCustomIcon(iconItem.iconKey, iconItem.size, PdfColor.fromInt(iconItem.colorValue)),
          ),

        // 10. Linhas Cibernéticas & Nós de Automação (Cyber Nodes)
        if (settings.nodes.isNotEmpty) ...[
          pw.SvgImage(
            svg: _buildCyberConnectorsSvg(settings.nodes, a4W, a4H),
          ),
          for (final node in settings.nodes) ...[
            pw.Positioned(
              left: (node.posX * a4W) - 15,
              top: (node.posY * a4H) - 15,
              child: pw.Container(
                width: 30,
                height: 30,
                decoration: pw.BoxDecoration(
                  shape: pw.BoxShape.circle,
                  color: PdfColor.fromHex('#0F172A'),
                  border: pw.Border.all(
                    color: _parsePdfColor(node.colorHex),
                    width: 1.8,
                  ),
                ),
                child: pw.Center(
                  child: _buildPdfCoverCustomIcon(
                    node.iconName,
                    15,
                    _parsePdfColor(node.colorHex),
                  ),
                ),
              ),
            ),
            pw.Positioned(
              left: (node.posX * a4W) - 45,
              top: (node.posY * a4H) + 16,
              child: pw.SizedBox(
                width: 90,
                child: pw.Center(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#0F172A'),
                      borderRadius: pw.BorderRadius.circular(3),
                      border: pw.Border.all(
                        color: _parsePdfColor(node.colorHex, alpha: 0.5),
                        width: 0.6,
                      ),
                    ),
                    child: pw.Text(
                      node.label.toUpperCase(),
                      style: pw.TextStyle(
                        font: fontMontserratBold,
                        fontSize: (settings.coverNodesLabelFontSize * 0.85).clamp(4.0, 16.0),
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                      maxLines: 1,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],




      ],
    );
  }

  static pw.Widget _buildPdfCoverCustomIcon(String iconKey, double size, PdfColor color) {
    final hex = '#${color.toInt().toRadixString(16).padLeft(8, '0').substring(2)}';
    String svgContent;
    switch (iconKey.toLowerCase()) {
      case 'bolt':
      case 'power':
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
      case 'pie':
      case 'pie_chart':
      case 'pizza':
      case 'representatividade':
        svgContent = '<svg viewBox="0 0 24 24" width="$size" height="$size"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 2.07c3.61.45 6.48 3.32 6.93 6.93H13V4.07zM4 12c0-4.07 3.06-7.44 7-7.93v15.87c-3.94-.5-7-3.87-7-7.94zm9 7.93V13h6.93c-.45 3.61-3.32 6.48-6.93 6.93z" fill="$hex"/></svg>';
        break;
      case 'inventory':
      case 'box':
      case 'caixa':
      case 'equipamento':
      case 'equipamentos':
        svgContent = '<svg viewBox="0 0 24 24" width="$size" height="$size"><path d="M20 2H4c-1 0-2 .9-2 2v3.01c0 .72.43 1.34 1 1.69V20c0 1.1 1.1 2 2 2h14c.9 0 2-.9 2-2V8.7c.57-.35 1-.97 1-1.69V4c0-1.1-1-2-2-2zm-5 12H9v-2h6v2zm5-7H4V4h16v3z" fill="$hex"/></svg>';
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
      case 'diamond':
      case 'diamante':
        svgContent = '<svg viewBox="0 0 24 24" width="$size" height="$size"><path d="M19 3H5L2 9l10 12L22 9l-3-6zM9 5h6l1.5 3h-9L9 5zM4.5 9l2-3.5h1.8L6.8 9H4.5zm7.5 9.5L6.2 10h11.6L12 18.5zm3.7-9.5l-1.5-3.5h1.8l2 3.5h-2.3z" fill="$hex"/></svg>';
        break;
      case 'phone':
      case 'whatsapp':
      case 'telefone':
        svgContent = '<svg viewBox="0 0 24 24" width="$size" height="$size"><path d="M6.62 10.79a15.053 15.053 0 006.59 6.59l2.2-2.2c.27-.27.67-.36 1.02-.24 1.12.37 2.33.57 3.57.57.55 0 1 .45 1 1V20c0 .55-.45 1-1 1-9.39 0-17-7.61-17-17 0-.55.45-1 1-1h3.5c.55 0 1 .45 1 1 0 1.25.2 2.45.57 3.57.11.35.03.74-.25 1.02l-2.2 2.2z" fill="$hex"/></svg>';
        break;
      case 'home':
      case 'residencia':
      case 'casa':
        svgContent = '<svg viewBox="0 0 24 24" width="$size" height="$size"><path d="M10 20v-6h4v6h5v-8h3L12 3 2 12h3v8z" fill="$hex"/></svg>';
        break;
      case 'car':
      case 'garage':
      case 'garagem':
      case 'estacionamento':
        svgContent = '<svg viewBox="0 0 24 24" width="$size" height="$size"><path d="M18.92 6.01C18.72 5.42 18.16 5 17.5 5h-11c-.66 0-1.21.42-1.42 1.01L3 12v8c0 .55.45 1 1 1h1c.55 0 1-.45 1-1v-1h12v1c0 .55.45 1 1 1h1c.55 0 1-.45 1-1v-8l-2.08-5.99zM6.85 7h10.29l1.04 3H5.81l1.04-3zM19 17H5v-4.66l.12-.34h13.77l.11.34V17z" fill="$hex"/><circle cx="7.5" cy="14.5" r="1.5" fill="$hex"/><circle cx="16.5" cy="14.5" r="1.5" fill="$hex"/></svg>';
        break;
      case 'bed':
      case 'quarto':
      case 'dormitorio':
      case 'suite':
      case 'suite_master':
      case 'cama':
        svgContent = '<svg viewBox="0 0 24 24" width="$size" height="$size"><path d="M19 7h-8v8H3V5H1v15h2v-3h18v3h2v-9c0-2.21-1.79-4-4-4zm1 8h-8V9h7c.55 0 1 .45 1 1v5z" fill="$hex"/><circle cx="7" cy="11" r="2" fill="$hex"/></svg>';
        break;
      case 'service':
      case 'wash':
      case 'lavanderia':
      case 'area_servico':
      case 'servico':
        svgContent = '<svg viewBox="0 0 24 24" width="$size" height="$size"><path d="M18 2.01L6 2c-1.11 0-2 .89-2 2v16c0 1.11.89 2 2 2h12c1.11 0 2-.89 2-2V4c0-1.11-.89-1.99-2-1.99zM18 20H6v-9.02h12V20zm0-11H6V4h12v5z" fill="$hex"/><circle cx="12" cy="15" r="3" fill="$hex"/><circle cx="8" cy="6.5" r="1" fill="$hex"/><circle cx="11" cy="6.5" r="1" fill="$hex"/></svg>';
        break;
      case 'kitchen':
      case 'cozinha':
      case 'gourmet':
      case 'copa':
        svgContent = '<svg viewBox="0 0 24 24" width="$size" height="$size"><path d="M18 2.01L6 2c-1.1 0-2 .89-2 2v16c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V4c0-1.11-.9-1.99-2-1.99zM8 4h3v5H8V4zm-2 7h5v9H6v-9zm12 9h-5V4h5v16z" fill="$hex"/></svg>';
        break;
      case 'living':
      case 'sofa':
      case 'sala':
        svgContent = '<svg viewBox="0 0 24 24" width="$size" height="$size"><path d="M20 10V7c0-1.1-.9-2-2-2H6c-1.1 0-2 .9-2 2v3c-1.1 0-2 .9-2 2v5h2v2h2v-2h12v2h2v-2h2v-5c0-1.1-.9-2-2-2zm-14-3h12v3H6V7zm14 8H4v-3c0-.55.45-1 1-1h14c.55 0 1 .45 1 1v3z" fill="$hex"/></svg>';
        break;
      case 'bath':
      case 'banheiro':
      case 'lavabo':
      case 'bwc':
      case 'wc':
        svgContent = '<svg viewBox="0 0 24 24" width="$size" height="$size"><path d="M20 13V4.83C20 3.27 18.73 2 17.17 2c-.75 0-1.47.3-2 .83l-1.25 1.25c-.16-.05-.33-.08-.51-.08-.83 0-1.5.67-1.5 1.5v.68l-2-2V3c0-.55-.45-1-1-1s-1 .45-1 1v3.17l-3.29-3.3a.996.996 0 10-1.41 1.41L5.17 6.5C3.32 8.35 3.03 11.23 4.29 13.4L2 15.69V20h20v-4.31l-2-2.69zM6.59 7.91l1.41-1.41 1.41 1.41-1.41 1.41-1.41-1.41zM20 18H4v-1.19l1.63-1.63c.12-.12.2-.27.24-.44.75-3.05 3.32-5.3 6.43-5.48l3.7 3.7V14h4v4z" fill="$hex"/></svg>';
        break;
      case 'pool':
      case 'piscina':
      case 'deck':
      case 'externo':
      case 'jardim':
        svgContent = '<svg viewBox="0 0 24 24" width="$size" height="$size"><path d="M22 21c-1.11 0-1.73-.37-2.18-.64-.39-.23-.6-.36-1.82-.36s-1.43.13-1.82.36c-.45.27-1.07.64-2.18.64s-1.73-.37-2.18-.64c-.39-.23-.6-.36-1.82-.36s-1.43.13-1.82.36c-.45.27-1.07.64-2.18.64s-1.73-.37-2.18-.64c-.39-.23-.6-.36-1.82-.36s-1.43.13-1.82.36c-.45.27-1.07.64-2.18.64v-2c.6 0 .97-.22 1.34-.44.49-.3 1.15-.69 2.66-.69s2.17.4 2.66.69c.38.23.74.44 1.34.44s.97-.22 1.34-.44c.49-.3 1.15-.69 2.66-.69s2.17.4 2.66.69c.38.23.74.44 1.34.44s.97-.22 1.34-.44c.49-.3 1.15-.69 2.66-.69s2.17.4 2.66.69c.38.23.74.44 1.34.44v2zm-12-8.5c0-.83.67-1.5 1.5-1.5s1.5.67 1.5 1.5-.67 1.5-1.5 1.5-1.5-.67-1.5-1.5zM8.5 7A1.5 1.5 0 0010 8.5 1.5 1.5 0 008.5 10 1.5 1.5 0 007 8.5 1.5 1.5 0 008.5 7zm4.1-3.69L11.5 4.4 7.21.11a1 1 0 00-1.41 0L4.38 1.53a1 1 0 000 1.41L5.8 4.36 4.38 5.77a1 1 0 000 1.41l1.41 1.41a1 1 0 001.41 0L8.62 7.18l4.49 4.49a1 1 0 001.41 0l1.41-1.41a1 1 0 000-1.41L12.6 5.54l1.41-1.41a1 1 0 000-1.41l-1.41-1.41z" fill="$hex"/></svg>';
        break;
      case 'light':
      case 'lampada':
      case 'iluminacao':
      case 'lightbulb':
        svgContent = '<svg viewBox="0 0 24 24" width="$size" height="$size"><path d="M9 21c0 .55.45 1 1 1h4c.55 0 1-.45 1-1v-1H9v1zm3-19C8.14 2 5 5.14 5 9c0 2.38 1.19 4.47 3 5.74V17c0 .55.45 1 1 1h6c.55 0 1-.45 1-1v-2.26c1.81-1.27 3-3.36 3-5.74 0-3.86-3.14-7-7-7z" fill="$hex"/></svg>';
        break;
      case 'sensors':
      case 'sensor':
      case 'ondas':
      case 'atuador':
      case 'atuadores':
        svgContent = '<svg viewBox="0 0 24 24" width="$size" height="$size"><path d="M12 15c-1.66 0-3-1.34-3-3s1.34-3 3-3 3 1.34 3 3-1.34 3-3 3zm0-8c-2.76 0-5 2.24-5 5s2.24 5 5 5 5-2.24 5-5-2.24-5-5-5zm0-4C7.03 3 3 7.03 3 12s4.03 9 9 9 9-4.03 9-9-4.03-9-9-9z" fill="$hex"/></svg>';
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
      case 'camera':
      case 'camera_alt':
      case 'photo':
      case 'foto':
      case 'monitoramento':
      case 'video':
        svgContent = '<svg viewBox="0 0 24 24" width="$size" height="$size"><circle cx="12" cy="12" r="3.2" fill="$hex"/><path d="M9 2L7.17 4H4c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2h-3.17L15 2H9zm3 15c-2.76 0-5 2.24-5 5s2.24-5 5-5 5 2.24 5 5-2.24 5-5 5z" fill="$hex"/></svg>';
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
      case 'wifi':
      case 'rede':
        svgContent = '<svg viewBox="0 0 24 24" width="$size" height="$size"><path d="M12 3C7.95 3 4.21 4.34 1.2 6.6L3 9c2.47-1.85 5.56-3 9-3s6.53 1.15 9 3l1.8-2.4C19.79 4.34 16.05 3 12 3zm0 6c-2.9 0-5.58.97-7.74 2.6L6 14c1.7-1.28 3.75-2 6-2s4.3.72 6 2l1.74-2.4C17.58 9.97 14.9 9 12 9zm0 6c-1.57 0-3.03.54-4.2 1.44L12 21l4.2-4.56C15.03 15.54 13.57 15 12 15z" fill="$hex"/></svg>';
        break;
      case 'curtain':
      case 'cortina':
      case 'persiana':
        svgContent = '<svg viewBox="0 0 24 24" width="$size" height="$size"><path d="M20 19V3H4v16H2v2h20v-2h-2zM6 5h5v4H6V5zm0 6h5v4H6v-4zm12 8H6v-2h12v2zm0-4h-5v-4h5v4zm0-6h-5V5h5v4z" fill="$hex"/></svg>';
        break;
      case 'tv':
      case 'cinema':
      case 'theater':
        svgContent = '<svg viewBox="0 0 24 24" width="$size" height="$size"><path d="M21 3H3c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h5v2h8v-2h5c1.1 0 1.99-.9 1.99-2L23 5c0-1.1-.9-2-2-2zm0 14H3V5h18v12z" fill="$hex"/></svg>';
        break;
      default:
        svgContent = '<svg viewBox="0 0 24 24" width="$size" height="$size"><circle cx="12" cy="12" r="8" fill="$hex"/></svg>';
        break;
    }
    return pw.SvgImage(svg: svgContent, width: size, height: size);
  }

  /// Retorna o nome da chave SVG adequada para o ambiente/cômodo
  static String _getRoomIconKey(String roomName) {
    final lower = roomName.toLowerCase().trim();
    if (lower.contains('garagem') || lower.contains('estacionamento') || lower.contains('carro')) {
      return 'car';
    }
    if (lower.contains('quarto') || lower.contains('dorm') || lower.contains('suite') || lower.contains('suíte') || lower.contains('cama')) {
      return 'bed';
    }
    if (lower.contains('serviço') || lower.contains('servico') || lower.contains('lavand') || lower.contains('lavagem')) {
      return 'service';
    }
    if (lower.contains('cozinha') || lower.contains('gourmet') || lower.contains('copa') || lower.contains('jantar')) {
      return 'kitchen';
    }
    if (lower.contains('sala') || lower.contains('living') || lower.contains('estar') || lower.contains('tv') || lower.contains('visita')) {
      return 'living';
    }
    if (lower.contains('banheiro') || lower.contains('lavabo') || lower.contains('bwc') || lower.contains('wc')) {
      return 'bath';
    }
    if (lower.contains('piscina') || lower.contains('extern') || lower.contains('deck') || lower.contains('jardim') || lower.contains('sacada') || lower.contains('varanda')) {
      return 'pool';
    }
    if (lower.contains('cinema') || lower.contains('theater') || lower.contains('áudio') || lower.contains('audio')) {
      return 'tv';
    }
    return 'home';
  }

  /// Obtém o perfil visual de categorias para renderização fiel dos cards da Proposta Web
  static _PdfCategoryVisual _getPdfCategoryVisual(String? catTitle) {
    final title = catTitle ?? '';
    final lower = title.toLowerCase().trim();
    if (lower.contains('ilumina') || lower.contains('luz') || lower.contains('dimmer') || lower.contains('led') || lower.contains('lamp')) {
      return const _PdfCategoryVisual(
        iconKey: 'light',
        color: PdfColor.fromInt(0xFFF59E0B),
        bgColor: PdfColor.fromInt(0xFF261A05),
        badgeBgColor: PdfColor.fromInt(0xFF2B1D08),
        displayName: 'Iluminação & Cenas',
      );
    }
    if (lower.contains('sensor') || lower.contains('presença') || lower.contains('presenca') || lower.contains('atuador') || lower.contains('rele') || lower.contains('relé')) {
      return const _PdfCategoryVisual(
        iconKey: 'sensors',
        color: PdfColor.fromInt(0xFFEC4899),
        bgColor: PdfColor.fromInt(0xFF2D0B1F),
        badgeBgColor: PdfColor.fromInt(0xFF310E23),
        displayName: 'Sensores & Atuadores',
      );
    }
    if (lower.contains('audio') || lower.contains('áudio') || lower.contains('som') || lower.contains('video') || lower.contains('vídeo') || lower.contains('tv') || lower.contains('home')) {
      return const _PdfCategoryVisual(
        iconKey: 'music',
        color: PdfColor.fromInt(0xFF8B5CF6),
        bgColor: PdfColor.fromInt(0xFF1B0F38),
        badgeBgColor: PdfColor.fromInt(0xFF221445),
        displayName: 'Áudio & Home Theater',
      );
    }
    if (lower.contains('clima') || lower.contains('ar') || lower.contains('ac') || lower.contains('temperatura') || lower.contains('termostato')) {
      return const _PdfCategoryVisual(
        iconKey: 'temp',
        color: PdfColor.fromInt(0xFF06B6D4),
        bgColor: PdfColor.fromInt(0xFF06242E),
        badgeBgColor: PdfColor.fromInt(0xFF082D3A),
        displayName: 'Climatização & AC',
      );
    }
    if (lower.contains('persiana') || lower.contains('cortina') || lower.contains('motor')) {
      return const _PdfCategoryVisual(
        iconKey: 'curtain',
        color: PdfColor.fromInt(0xFF6366F1),
        bgColor: PdfColor.fromInt(0xFF13163A),
        badgeBgColor: PdfColor.fromInt(0xFF191C4A),
        displayName: 'Persianas & Cortinas',
      );
    }
    if (lower.contains('seguran') || lower.contains('fechadura') || lower.contains('alarme') || lower.contains('camera') || lower.contains('câmera') || lower.contains('acesso')) {
      return const _PdfCategoryVisual(
        iconKey: 'lock',
        color: PdfColor.fromInt(0xFF10B981),
        bgColor: PdfColor.fromInt(0xFF062419),
        badgeBgColor: PdfColor.fromInt(0xFF092E20),
        displayName: 'Segurança & Acesso',
      );
    }
    if (lower.contains('rede') || lower.contains('wifi') || lower.contains('wi-fi') || lower.contains('router')) {
      return const _PdfCategoryVisual(
        iconKey: 'wifi',
        color: PdfColor.fromInt(0xFF38BDF8),
        bgColor: PdfColor.fromInt(0xFF082236),
        badgeBgColor: PdfColor.fromInt(0xFF0A2942),
        displayName: 'Rede & Wi-Fi',
      );
    }
    return _PdfCategoryVisual(
      iconKey: 'inventory',
      color: const PdfColor.fromInt(0xFF00E5FF),
      bgColor: const PdfColor.fromInt(0xFF072433),
      badgeBgColor: const PdfColor.fromInt(0xFF0A2D3F),
      displayName: title.isNotEmpty ? title : 'Automação Geral',
    );
  }

  static String _buildCyberConnectorsSvg(List<AutomationCyberNode> nodes, double w, double h) {
    final buffer = StringBuffer();
    buffer.writeln('<svg viewBox="0 0 $w $h" width="$w" height="$h" xmlns="http://www.w3.org/2000/svg">');
    for (final node in nodes) {
      if (!node.showConnectorLine) continue;
      final colorHex = node.colorHex.startsWith('#') ? node.colorHex : '#${node.colorHex}';
      final startX = node.posX * w;
      final startY = node.posY * h;
      final targetX = node.targetX * w;
      final targetY = node.targetY * h;

      final isVerticalFirst = (targetY - startY).abs() >= (targetX - startX).abs();
      final d = isVerticalFirst
          ? 'M $startX $startY L $startX $targetY L $targetX $targetY'
          : 'M $startX $startY L $targetX $startY L $targetX $targetY';

      // Brilho exterior da linha
      buffer.writeln('<path d="$d" stroke="$colorHex" stroke-width="4.5" stroke-linecap="round" stroke-linejoin="round" fill="none" opacity="0.35"/>');
      // Linha nítida principal
      buffer.writeln('<path d="$d" stroke="$colorHex" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" fill="none" opacity="0.95"/>');
      // Anel alvo e ponto central
      buffer.writeln('<circle cx="$targetX" cy="$targetY" r="8" stroke="$colorHex" stroke-width="1" fill="none" opacity="0.30"/>');
      buffer.writeln('<circle cx="$targetX" cy="$targetY" r="5.5" stroke="$colorHex" stroke-width="1.8" fill="none" opacity="0.95"/>');
      buffer.writeln('<circle cx="$targetX" cy="$targetY" r="2.2" fill="$colorHex" opacity="0.95"/>');
    }
    buffer.writeln('</svg>');
    return buffer.toString();
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
                pw.Text('$text2  •  $text3', style: pw.TextStyle(font: fontSemiBold, fontSize: 7.5, color: t2Color)),
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
              pw.Text('$text2  ${text3.isNotEmpty ? "• $text3" : ""}', style: pw.TextStyle(font: fontSemiBold, fontSize: 7.5, color: t2Color)),
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
                pw.Text('$text2 ${text3.isNotEmpty ? "• $text3" : ""}', style: pw.TextStyle(font: fontSemiBold, fontSize: 7, color: t2Color)),
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
              [text1, text2, text3].where((s) => s.isNotEmpty).join('  •  '),
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
                pw.Text('$text2  •  $text3', style: pw.TextStyle(font: fontSemiBold, fontSize: 7.5, color: t2Color)),
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

  static String _pdfColorToHex(PdfColor color) {
    final r = (color.red * 255).round().toRadixString(16).padLeft(2, '0');
    final g = (color.green * 255).round().toRadixString(16).padLeft(2, '0');
    final b = (color.blue * 255).round().toRadixString(16).padLeft(2, '0');
    return '#$r$g$b';
  }

  // ───────────────────────────────────────────────────────────────────────────
  // PÁGINA 2: CARDS DE BENEFÍCIOS & ESCOPO DA AUTOMAÇÃO (DINÂMICOS & TEMPLATES)
  // ───────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildPage2CardsContent(
    PdfColor primaryColor,
    pw.Font fontOutfit,
    pw.Font fontBold,
    pw.Font fontRegular, {
    Uint8List? bannerImageBytes,
    List<ProposalPageCard>? customCards,
    bool showIllustration = true,
    String illustrationType = 'banner',
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
                  svgIcon: _resolveAutomationIcon(c1.iconKey, hex),
                  fontBold: fontBold,
                  fontRegular: fontRegular,
                ),
              ),
              if (c2 != null) ...[
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: _buildInfoCardBadge(
                    title: c2.title,
                    description: c2.description,
                    svgIcon: _resolveAutomationIcon(c2.iconKey, hex),
                    fontBold: fontBold,
                    fontRegular: fontRegular,
                  ),
                ),
              ] else
                pw.Expanded(child: pw.SizedBox()),
            ],
          ),
        );
        cardRows.add(pw.SizedBox(height: 10));
      }

      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.SizedBox(height: 2),
          pw.Text(
            'Diferenciais & Escopo Personalizado',
            style: pw.TextStyle(font: fontOutfit, fontSize: 15.5, color: PdfColor.fromHex('#0F172A')),
          ),
          pw.SizedBox(height: 10),
          ...cardRows,
          if (showIllustration)
            _buildSpecificPage2Illustration(
              primaryColor,
              fontOutfit,
              fontBold,
              fontRegular,
              bannerImageBytes: bannerImageBytes,
              illustrationType: illustrationType,
            ),
        ],
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.SizedBox(height: 2),
        pw.Text(
          'Por que escolher a nossa solução de automação?',
          style: pw.TextStyle(font: fontOutfit, fontSize: 15.5, color: PdfColor.fromHex('#0F172A')),
        ),
        pw.SizedBox(height: 10),

        // 4 Cards de Apresentação (2x2) com Badges de Ícone no Topo
        pw.Row(
          children: [
            pw.Expanded(
              child: _buildInfoCardBadge(
                title: 'Conforto & Cenas Inteligentes',
                description: 'Iluminação, climatização, áudio e cortinas sincronizados em cenas personalizadas para cada momento.',
                svgIcon: AutomationPdfIcons.sceneComfort(hex),
                fontBold: fontBold,
                fontRegular: fontRegular,
              ),
            ),
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: _buildInfoCardBadge(
                title: 'Segurança Ativa 24h',
                description: 'Controle biométrico, fechaduras inteligentes, câmeras e sensores com notificações instantâneas no celular.',
                svgIcon: AutomationPdfIcons.shieldSecurity(hex),
                fontBold: fontBold,
                fontRegular: fontRegular,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Row(
          children: [
            pw.Expanded(
              child: _buildInfoCardBadge(
                title: 'Eficiência Energética',
                description: 'Gestão inteligente de consumo com desligamento programado, climatização otimizada e zero desperdício.',
                svgIcon: AutomationPdfIcons.ecoEnergy(hex),
                fontBold: fontBold,
                fontRegular: fontRegular,
              ),
            ),
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: _buildInfoCardBadge(
                title: 'Valorização Imobiliária',
                description: 'Residências modernas com automação de ponta são altamente desejadas e valorizadas pelo mercado.',
                svgIcon: AutomationPdfIcons.smartHome(hex),
                fontBold: fontBold,
                fontRegular: fontRegular,
              ),
            ),
          ],
        ),

        pw.SizedBox(height: 18),
        pw.Text(
          'Escopo do Projeto & Solução Turn-Key',
          style: pw.TextStyle(font: fontOutfit, fontSize: 15.5, color: PdfColor.fromHex('#0F172A')),
        ),
        pw.SizedBox(height: 10),

        // 4 Cards de Escopo (2x2) com Badges de Ícone no Topo
        pw.Row(
          children: [
            pw.Expanded(
              child: _buildInfoCardBadge(
                title: 'Engenharia & Projeto Executivo',
                description: 'Estudo completo de infraestrutura, cabeamento estruturado, rede Wi-Fi Mesh e posicionamento acústico.',
                svgIcon: AutomationPdfIcons.projectBlueprint(hex),
                fontBold: fontBold,
                fontRegular: fontRegular,
              ),
            ),
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: _buildInfoCardBadge(
                title: 'Aplicativo Único & Comando de Voz',
                description: 'Controle toda a residência pela tela do smartphone, tablet, comando de voz (Alexa/Google/Siri) ou keypads.',
                svgIcon: AutomationPdfIcons.smartphoneApp(hex),
                fontBold: fontBold,
                fontRegular: fontRegular,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Row(
          children: [
            pw.Expanded(
              child: _buildInfoCardBadge(
                title: 'Equipamentos Homologados',
                description: 'Módulos, atuadores e sensores de padrão internacional com homologação Anatel e alta confiabilidade.',
                svgIcon: AutomationPdfIcons.awardCert(hex),
                fontBold: fontBold,
                fontRegular: fontRegular,
              ),
            ),
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: _buildInfoCardBadge(
                title: 'Instalação, Cenas & Suporte',
                description: 'Montagem limpa por especialistas certificados, programação sob medida, treinamento e garantia de fábrica.',
                svgIcon: AutomationPdfIcons.supportHandshake(hex),
                fontBold: fontBold,
                fontRegular: fontRegular,
              ),
            ),
          ],
        ),
        if (showIllustration)
          _buildSpecificPage2Illustration(
            primaryColor,
            fontOutfit,
            fontBold,
            fontRegular,
            bannerImageBytes: bannerImageBytes,
            illustrationType: illustrationType,
          ),
      ],
    );
  }

  static String _resolveAutomationIcon(String? iconKey, String hex) {
    switch (iconKey?.toLowerCase()) {
      case 'scene':
      case 'light':
      case 'lightbulb':
        return AutomationPdfIcons.sceneComfort(hex);
      case 'security':
      case 'shield':
      case 'lock':
        return AutomationPdfIcons.shieldSecurity(hex);
      case 'eco':
      case 'energy':
      case 'leaf':
        return AutomationPdfIcons.ecoEnergy(hex);
      case 'blueprint':
      case 'engineering':
      case 'project':
        return AutomationPdfIcons.projectBlueprint(hex);
      case 'smartphone':
      case 'phone':
      case 'app':
        return AutomationPdfIcons.smartphoneApp(hex);
      case 'award':
      case 'star':
      case 'cert':
        return AutomationPdfIcons.awardCert(hex);
      case 'support':
      case 'handshake':
        return AutomationPdfIcons.supportHandshake(hex);
      case 'home':
      case 'smart_home':
      default:
        return AutomationPdfIcons.smartHome(hex);
    }
  }

  static pw.Widget _buildCustomPageContent(
    ProposalCustomPage page,
    PdfColor primaryColor,
    pw.Font fontOutfit,
    pw.Font fontBold,
    pw.Font fontRegular,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildPdfHeader(page.title.toUpperCase(), '', primaryColor, fontOutfit, fontRegular),
        pw.SizedBox(height: 16),
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
                    pw.Text(c.title, style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColor.fromHex('#0F172A'))),
                    pw.SizedBox(height: 4),
                    pw.Text(c.description, style: pw.TextStyle(font: fontRegular, fontSize: 9.5, color: PdfColor.fromHex('#475569'))),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  static pw.Widget _buildSpecificPage2Illustration(
    PdfColor primaryColor,
    pw.Font fontOutfit,
    pw.Font fontBold,
    pw.Font fontRegular, {
    Uint8List? bannerImageBytes,
    String illustrationType = 'banner',
  }) {
    String headerLabel = 'ECOSSISTEMA RESIDENCIAL INTEGRADO & IOT';
    String headerSub = 'Wi-Fi 6 Mesh • Controle Inteligente • Climatização • Segurança • Áudio Hi-Fi';
    PdfColor headerColor = primaryColor;
    PdfColor bgColor = PdfColors.white;
    PdfColor borderColor = PdfColor.fromHex('#E2E8F0');
    bool isDark = false;

    switch (illustrationType.toLowerCase()) {
      case 'cyberdark':
        headerLabel = 'INFRAESTRUTURA CIBERNÉTICA & SEGURANÇA LOCAL';
        headerSub = 'Criptografia Local AES-256 • Conexão Local sem Nuvem • Latência Zero';
        headerColor = PdfColor.fromHex('#38BDF8');
        bgColor = PdfColor.fromHex('#090D16');
        borderColor = PdfColor.fromHex('#1E293B');
        isDark = true;
        break;
      case 'blueprint':
        headerLabel = 'PROJETO TÉCNICO & INFRAESTRUTURA DE ENGENHARIA';
        headerSub = 'Normas ABNT NBR 5410 • Cabeamento Estruturado Cat6A • ART/CREA';
        headerColor = PdfColor.fromHex('#60A5FA');
        bgColor = PdfColor.fromHex('#0F2744');
        borderColor = PdfColor.fromHex('#1E40AF');
        isDark = true;
        break;
      case 'luxurygold':
        headerLabel = 'PADRÃO ALTA NOBREZA & DESIGN EUROPEU';
        headerSub = 'Metais Nobres Escovados • Keypads de Vidro • Atendimento Concierge VIP';
        headerColor = PdfColor.fromHex('#F59E0B');
        bgColor = PdfColor.fromHex('#1C1917');
        borderColor = PdfColor.fromHex('#D97706');
        isDark = true;
        break;
      case 'timeline':
        headerLabel = 'JORNADA DO CLIENTE & PROCESSO TURN-KEY DE ENTREGA';
        headerSub = '1. Projeto ➔ 2. Infraestrutura ➔ 3. Programação ➔ 4. Entrega Técnica';
        headerColor = PdfColor.fromHex('#10B981');
        bgColor = PdfColor.fromHex('#F1F5F9');
        borderColor = PdfColor.fromHex('#CBD5E1');
        break;
      case 'solarflow':
        headerLabel = 'FLUXO ENERGÉTICO DO GERADOR SOLAR FOTOVOLTAICO';
        headerSub = 'Módulos Fotovoltaicos ➔ Inversor Grid-Tie ➔ Quadro Geral ➔ Consumo & Rede';
        headerColor = PdfColor.fromHex('#D97706');
        bgColor = PdfColor.fromHex('#FEF3C7');
        borderColor = PdfColor.fromHex('#F59E0B');
        break;
      case 'iotnetwork':
        headerLabel = 'TOPOLOGIA DE REDE MESH & HUB CENTRAL IOT';
        headerSub = 'Protocolos Zigbee 3.0 • Matter • Thread • Wi-Fi 6 Corporativo';
        headerColor = PdfColor.fromHex('#4338CA');
        bgColor = PdfColor.fromHex('#EEF2FF');
        borderColor = PdfColor.fromHex('#818CF8');
        break;
      case 'greeneco':
        headerLabel = 'EFICIÊNCIA ENERGÉTICA & PRESERVAÇÃO AMBIENTAL';
        headerSub = 'Redução de Emissões de CO2 • Certificação Verde • Economia Sustentável';
        headerColor = PdfColor.fromHex('#047857');
        bgColor = PdfColor.fromHex('#ECFDF5');
        borderColor = PdfColor.fromHex('#10B981');
        break;
      case 'isometric':
        headerLabel = 'CORTE ISOMÉTRICO DOS AMBIENTES RESIDENCIAIS';
        headerSub = 'Living Integrado • Gourmet • Suítes • Home Cinema • Automação Total';
        break;
    }

    pw.Widget contentWidget;

    switch (illustrationType.toLowerCase()) {
      case 'cyberdark':
        contentWidget = pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _buildPdfCyberBadge('GATEWAY LOCAL', 'AES-256', PdfColor.fromHex('#38BDF8'), fontBold, fontRegular),
              _buildPdfCyberBadge('REDE MESH', 'Zero Latência', PdfColor.fromHex('#06B6D4'), fontBold, fontRegular),
              _buildPdfCyberBadge('DISPOSITIVOS', 'Matter / Zigbee', PdfColor.fromHex('#818CF8'), fontBold, fontRegular),
              _buildPdfCyberBadge('STATUS GERAL', '100% Online', PdfColor.fromHex('#10B981'), fontBold, fontRegular),
            ],
          ),
        );
        break;

      case 'blueprint':
        contentWidget = pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _buildPdfBlueprintStep('1. TUBULAÇÃO', 'Conduítes Secos', fontBold, fontRegular),
              pw.Text('➔', style: pw.TextStyle(color: PdfColor.fromHex('#60A5FA'), fontSize: 11)),
              _buildPdfBlueprintStep('2. RACK CAT6A', 'Patch Panel', fontBold, fontRegular),
              pw.Text('➔', style: pw.TextStyle(color: PdfColor.fromHex('#60A5FA'), fontSize: 11)),
              _buildPdfBlueprintStep('3. QUADRO QDA', 'Disjuntores & DPS', fontBold, fontRegular),
              pw.Text('➔', style: pw.TextStyle(color: PdfColor.fromHex('#60A5FA'), fontSize: 11)),
              _buildPdfBlueprintStep('4. COMISSIONAMENTO', 'Testes Ponto a Ponto', fontBold, fontRegular),
            ],
          ),
        );
        break;

      case 'luxurygold':
        contentWidget = pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _buildPdfLuxuryBadge('ALTA NOBREZA', 'Materiais Europeus', fontBold, fontRegular),
              _buildPdfLuxuryBadge('SONORIZAÇÃO HI-RES', 'Amplificadores DSP', fontBold, fontRegular),
              _buildPdfLuxuryBadge('GARANTIA VIP', '3 Anos com Troca', fontBold, fontRegular),
              _buildPdfLuxuryBadge('CONCIERGE DEDICADO', 'Suporte Prioritário', fontBold, fontRegular),
            ],
          ),
        );
        break;

      case 'timeline':
        contentWidget = pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _buildPdfTimelineStep(1, 'Projeto', 'Estudo & Dimensionamento', PdfColor.fromHex('#0284C7'), fontBold, fontRegular),
              pw.Text('➔', style: pw.TextStyle(color: PdfColor.fromHex('#94A3B8'), fontSize: 11)),
              _buildPdfTimelineStep(2, 'Infraestrutura', 'Tubulações & Cabos', PdfColor.fromHex('#0284C7'), fontBold, fontRegular),
              pw.Text('➔', style: pw.TextStyle(color: PdfColor.fromHex('#94A3B8'), fontSize: 11)),
              _buildPdfTimelineStep(3, 'Instalação', 'Módulos & Keypads', PdfColor.fromHex('#0284C7'), fontBold, fontRegular),
              pw.Text('➔', style: pw.TextStyle(color: PdfColor.fromHex('#94A3B8'), fontSize: 11)),
              _buildPdfTimelineStep(4, 'Treinamento', 'Cenas & Entrega', PdfColor.fromHex('#10B981'), fontBold, fontRegular),
            ],
          ),
        );
        break;

      case 'solarflow':
        contentWidget = pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _buildPdfFlowStep('Painéis Solares', 'Captação Solar', PdfColor.fromHex('#D97706'), fontBold, fontRegular),
              pw.Text('➔', style: pw.TextStyle(color: PdfColor.fromHex('#F59E0B'), fontSize: 11)),
              _buildPdfFlowStep('Inversor Grid-Tie', 'Conversão CC/CA', PdfColor.fromHex('#0284C7'), fontBold, fontRegular),
              pw.Text('➔', style: pw.TextStyle(color: PdfColor.fromHex('#F59E0B'), fontSize: 11)),
              _buildPdfFlowStep('Quadro Geral', 'Alimentação da Casa', PdfColor.fromHex('#10B981'), fontBold, fontRegular),
              pw.Text('➔', style: pw.TextStyle(color: PdfColor.fromHex('#F59E0B'), fontSize: 11)),
              _buildPdfFlowStep('Rede Concessionária', 'Créditos em kWh', PdfColor.fromHex('#6366F1'), fontBold, fontRegular),
            ],
          ),
        );
        break;

      case 'iotnetwork':
        contentWidget = pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _buildPdfNetworkNode('Iluminação', PdfColor.fromHex('#6366F1'), fontBold),
              _buildPdfNetworkNode('Segurança', PdfColor.fromHex('#0284C7'), fontBold),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#4338CA'),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Text('HUB CENTRAL\nMATTER', textAlign: pw.TextAlign.center, style: pw.TextStyle(font: fontBold, fontSize: 8, color: PdfColors.white)),
              ),
              _buildPdfNetworkNode('Clima', PdfColor.fromHex('#059669'), fontBold),
              _buildPdfNetworkNode('Áudio Hi-Fi', PdfColor.fromHex('#D97706'), fontBold),
            ],
          ),
        );
        break;

      case 'greeneco':
        contentWidget = pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _buildPdfEcoBadge('ENERGIA LIMPA', '100% Renovável', PdfColor.fromHex('#10B981'), fontBold, fontRegular),
              _buildPdfEcoBadge('MENOS CO2', '-2.4 Ton/ano', PdfColor.fromHex('#059669'), fontBold, fontRegular),
              _buildPdfEcoBadge('EFICIÊNCIA A+', 'Zero Desperdício', PdfColor.fromHex('#047857'), fontBold, fontRegular),
              _buildPdfEcoBadge('ECONOMIA', 'Até 95% Menos', PdfColor.fromHex('#0284C7'), fontBold, fontRegular),
            ],
          ),
        );
        break;

      case 'isometric':
      case 'banner':
      default:
        if (bannerImageBytes != null && bannerImageBytes.isNotEmpty) {
          contentWidget = pw.ClipRRect(
            horizontalRadius: 6,
            verticalRadius: 6,
            child: pw.Image(
              pw.MemoryImage(bannerImageBytes),
              height: 104,
              fit: pw.BoxFit.contain,
            ),
          );
        } else {
          final hex = _pdfColorToHex(primaryColor);
          contentWidget = pw.Center(
            child: pw.SvgImage(
              svg: AutomationPdfIcons.smartHomeTechScene(hex),
              width: 480,
              height: 76,
            ),
          );
        }
        break;
    }

    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(top: 10),
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: pw.BoxDecoration(
        color: bgColor,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
        border: pw.Border.all(color: borderColor, width: 1.0),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Row(
                children: [
                  pw.Container(
                    width: 6,
                    height: 6,
                    decoration: pw.BoxDecoration(
                      color: headerColor,
                      shape: pw.BoxShape.circle,
                    ),
                  ),
                  pw.SizedBox(width: 5),
                  pw.Text(
                    headerLabel,
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 8.2,
                      letterSpacing: 0.6,
                      color: headerColor,
                    ),
                  ),
                ],
              ),
              pw.Text(
                headerSub,
                style: pw.TextStyle(
                  font: fontRegular,
                  fontSize: 7.2,
                  color: isDark ? PdfColor.fromHex('#94A3B8') : PdfColor.fromHex('#64748B'),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          contentWidget,
        ],
      ),
    );
  }

  static pw.Widget _buildPdfCyberBadge(String title, String subtitle, PdfColor color, pw.Font fontBold, pw.Font fontRegular) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#0F172A'),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: color, width: 0.8),
      ),
      child: pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(title, style: pw.TextStyle(font: fontBold, fontSize: 8, color: PdfColors.white)),
          pw.SizedBox(height: 2),
          pw.Text(subtitle, style: pw.TextStyle(font: fontRegular, fontSize: 6.8, color: color)),
        ],
      ),
    );
  }

  static pw.Widget _buildPdfBlueprintStep(String title, String subtitle, pw.Font fontBold, pw.Font fontRegular) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#1E3A5F'),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: PdfColor.fromHex('#3B82F6'), width: 0.8),
      ),
      child: pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(title, style: pw.TextStyle(font: fontBold, fontSize: 7.5, color: PdfColors.white)),
          pw.SizedBox(height: 2),
          pw.Text(subtitle, style: pw.TextStyle(font: fontRegular, fontSize: 6.5, color: PdfColor.fromHex('#93C5FD'))),
        ],
      ),
    );
  }

  static pw.Widget _buildPdfLuxuryBadge(String title, String subtitle, pw.Font fontBold, pw.Font fontRegular) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#292524'),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: PdfColor.fromHex('#D97706'), width: 0.8),
      ),
      child: pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(title, style: pw.TextStyle(font: fontBold, fontSize: 8, color: PdfColor.fromHex('#FEF3C7'))),
          pw.SizedBox(height: 2),
          pw.Text(subtitle, style: pw.TextStyle(font: fontRegular, fontSize: 6.8, color: PdfColor.fromHex('#D97706'))),
        ],
      ),
    );
  }

  static pw.Widget _buildPdfTimelineStep(int num, String title, String subtitle, PdfColor color, pw.Font fontBold, pw.Font fontRegular) {
    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Container(
          width: 16,
          height: 16,
          decoration: pw.BoxDecoration(color: color, shape: pw.BoxShape.circle),
          child: pw.Center(
            child: pw.Text('$num', style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: PdfColors.white)),
          ),
        ),
        pw.SizedBox(height: 3),
        pw.Text(title, style: pw.TextStyle(font: fontBold, fontSize: 7.5, color: PdfColor.fromHex('#0F172A'))),
        pw.Text(subtitle, style: pw.TextStyle(font: fontRegular, fontSize: 6.5, color: PdfColor.fromHex('#64748B'))),
      ],
    );
  }

  static pw.Widget _buildPdfFlowStep(String title, String subtitle, PdfColor color, pw.Font fontBold, pw.Font fontRegular) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: color, width: 0.8),
      ),
      child: pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(title, style: pw.TextStyle(font: fontBold, fontSize: 7.5, color: PdfColor.fromHex('#0F172A'))),
          pw.SizedBox(height: 2),
          pw.Text(subtitle, style: pw.TextStyle(font: fontRegular, fontSize: 6.5, color: color)),
        ],
      ),
    );
  }

  static pw.Widget _buildPdfNetworkNode(String label, PdfColor color, pw.Font fontBold) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: color, width: 0.8),
      ),
      child: pw.Text(label, style: pw.TextStyle(font: fontBold, fontSize: 7.5, color: color)),
    );
  }

  static pw.Widget _buildPdfEcoBadge(String title, String subtitle, PdfColor color, pw.Font fontBold, pw.Font fontRegular) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: color, width: 0.8),
      ),
      child: pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(title, style: pw.TextStyle(font: fontBold, fontSize: 7.5, color: PdfColor.fromHex('#065F46'))),
          pw.SizedBox(height: 2),
          pw.Text(subtitle, style: pw.TextStyle(font: fontRegular, fontSize: 6.5, color: color)),
        ],
      ),
    );
  }

  static pw.Widget _buildInfoCardBadge({
    required String title,
    required String description,
    required String svgIcon,
    required pw.Font fontBold,
    required pw.Font fontRegular,
  }) {
    return pw.Stack(
      alignment: pw.Alignment.topCenter,
      children: [
        // Card Retangular Branco com dimensões ampliadas
        pw.Container(
          width: double.infinity,
          height: 94,
          margin: const pw.EdgeInsets.only(top: 14),
          padding: const pw.EdgeInsets.only(top: 20, bottom: 8, left: 12, right: 12),
          decoration: pw.BoxDecoration(
            color: PdfColors.white,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
            border: pw.Border.all(color: PdfColor.fromHex('#CBD5E1'), width: 1.0),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(
                title,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColor.fromHex('#0F172A')),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                description,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(font: fontRegular, fontSize: 8.2, color: PdfColor.fromHex('#475569'), height: 1.25),
              ),
            ],
          ),
        ),

        // Badge Circular Sobreposto no Topo
        pw.Positioned(
          top: 0,
          child: pw.Container(
            width: 28,
            height: 28,
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              shape: pw.BoxShape.circle,
              border: pw.Border.all(color: PdfColor.fromHex('#CBD5E1'), width: 1.2),
            ),
            child: pw.Center(
              child: pw.SvgImage(
                svg: svgIcon,
                width: 15,
                height: 15,
              ),
            ),
          ),
        ),
      ],
    );
  }

  static ProductModel _buildSampleProduct() {
    return ProductModel(
      id: 'sample_automation_study',
      name: 'Estudo de Automação Residencial Modelo ARBO',
      sector: ProductSector.homeAutomation,
      salePrice: 24500.0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      specificAttributes: {
        'automationEnvironments': [
          {
            'id': 'env_living',
            'name': 'Living Noturno & Home Cinema',
            'description': 'Iluminação cênica, climatização e som surround.',
            'items': [
              {'id': 'i1', 'name': 'Módulo Dimmer 6 Circuitos Zigbee', 'quantity': 2, 'unitPrice': 450.0},
              {'id': 'i2', 'name': 'Keypad Touch de Luxo 4 Teclas', 'quantity': 1, 'unitPrice': 680.0},
              {'id': 'i3', 'name': 'Amplificador Multiroom Streaming', 'quantity': 1, 'unitPrice': 4200.0},
            ],
          },
          {
            'id': 'env_gourmet',
            'name': 'Espaço Gourmet & Varanda',
            'description': 'Áudio de alta fidelidade e cenas de luz cênica.',
            'items': [
              {'id': 'i4', 'name': 'Caixas de Embutir Ângulo 8 polegadas', 'quantity': 4, 'unitPrice': 850.0},
              {'id': 'i5', 'name': 'Interface de Climatização HVAC', 'quantity': 1, 'unitPrice': 1200.0},
            ],
          },
        ],
        'laborPrice': 3500.0,
      },
    );
  }

  static ProposalModel _buildSampleProposal(AutomationSettingsModel settings) {
    return ProposalModel(
      id: 'preview_sample_prop',
      proposalNumber: settings.proposalCode.isNotEmpty ? settings.proposalCode : 'PROP-2026/001',
      title: settings.coverSubtitle.isNotEmpty ? settings.coverSubtitle : 'Automação Residencial High-End',
      clientName: settings.clientName.isNotEmpty ? settings.clientName : 'Cliente Exemplo Proposta',
      clientEmail: 'cliente@exemplo.com.br',
      clientPhone: '(11) 98765-4321',
      subtotal: 28000.0,
      totalAmount: 28000.0,
      validityDays: 10,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      items: [],
    );
  }

  static pw.Widget _buildPdfHeader(
    String subtitle,
    String title,
    PdfColor primaryColor,
    pw.Font fontT,
    pw.Font fontS, {
    PdfColor? titleColor,
    PdfColor? subtitleColor,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(subtitle.toUpperCase(), style: pw.TextStyle(font: fontS, fontSize: 9, color: subtitleColor ?? primaryColor)),
        pw.SizedBox(height: 2),
        pw.Text(title, style: pw.TextStyle(font: fontT, fontSize: 18, color: titleColor ?? PdfColor.fromHex('#0F172A'))),
        pw.SizedBox(height: 8),
        pw.Divider(color: primaryColor, thickness: 1.5),
      ],
    );
  }

  static pw.Widget _buildFinanceRow(String title, String val, pw.Font fontT, pw.Font fontV, {bool isTotal = false, PdfColor? color}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(title, style: pw.TextStyle(font: fontT, fontSize: isTotal ? 12 : 10, color: isTotal ? PdfColor.fromHex('#0F172A') : PdfColor.fromHex('#475569'))),
        pw.Text(val, style: pw.TextStyle(font: fontV, fontSize: isTotal ? 14 : 10, color: color ?? PdfColor.fromHex('#0F172A'))),
      ],
    );
  }

  static pw.Widget _buildPdfPortfolioCard({
    required AutomationPortfolioItem item,
    required PdfColor cardBgColor,
    required PdfColor borderColor,
    required PdfColor titleColor,
    required PdfColor subtitleColor,
    required PdfColor accentColor,
    required pw.Font fontBold,
    required pw.Font fontRegular,
    required pw.Font fontOutfit,
    Uint8List? fallbackPhotoBytes,
  }) {
    Uint8List? photoBytes;
    if (item.imageBase64 != null && item.imageBase64!.trim().isNotEmpty) {
      try {
        final clean = item.imageBase64!.contains(',')
            ? item.imageBase64!.split(',').last
            : item.imageBase64!;
        photoBytes = base64Decode(clean);
      } catch (_) {}
    }
    photoBytes ??= fallbackPhotoBytes;

    final tagsList = item.tags.split(RegExp(r'[•,\n]')).map((t) => t.trim()).where((t) => t.isNotEmpty).toList();

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      decoration: pw.BoxDecoration(
        color: cardBgColor,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: borderColor, width: 1.1),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // 1. Coluna Esquerda: Foto Real da Obra
          pw.Container(
            width: 155,
            height: 105,
            child: pw.ClipRRect(
              horizontalRadius: 7,
              verticalRadius: 7,
              child: pw.Stack(
                fit: pw.StackFit.expand,
                children: [
                  if (photoBytes != null)
                    pw.Image(
                      pw.MemoryImage(photoBytes),
                      fit: pw.BoxFit.cover,
                    )
                  else
                    pw.Container(color: const PdfColor.fromInt(0xFF0F172A)),
                  // Badge de Status / Entrega
                  pw.Positioned(
                    top: 6,
                    left: 6,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                      decoration: pw.BoxDecoration(
                        color: const PdfColor.fromInt(0xFF061424),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        border: pw.Border.all(color: accentColor, width: 0.8),
                      ),
                      child: pw.Row(
                        mainAxisSize: pw.MainAxisSize.min,
                        children: [
                          _buildPdfCoverCustomIcon('verified', 8, accentColor),
                          pw.SizedBox(width: 4),
                          pw.Text(
                            item.completionDate.isNotEmpty ? item.completionDate : 'Case Concluído',
                            style: pw.TextStyle(font: fontBold, fontSize: 6.8, color: PdfColors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Coluna Direita: Informações & Especificações Técnicas
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Título e Localização
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(
                        child: pw.Text(
                          item.title.toUpperCase(),
                          style: pw.TextStyle(
                            font: fontOutfit,
                            fontSize: 10.5,
                            color: titleColor,
                          ),
                          maxLines: 1,
                        ),
                      ),
                      if (item.clientOrLocation.isNotEmpty) ...[
                        pw.SizedBox(width: 6),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: pw.BoxDecoration(
                            color: const PdfColor.fromInt(0xFF082B3E),
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                            border: pw.Border.all(color: accentColor, width: 0.7),
                          ),
                          child: pw.Text(
                            item.clientOrLocation,
                            style: pw.TextStyle(font: fontBold, fontSize: 6.5, color: accentColor),
                          ),
                        ),
                      ],
                    ],
                  ),
                  pw.SizedBox(height: 5),

                  // Chips de Tags / Serviços Realizados
                  if (tagsList.isNotEmpty)
                    pw.Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: tagsList.take(4).map((tag) {
                        return pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: pw.BoxDecoration(
                            color: const PdfColor.fromInt(0xFF0B2136),
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                            border: pw.Border.all(color: const PdfColor.fromInt(0xFF1E3A5F), width: 0.6),
                          ),
                          child: pw.Text(
                            tag,
                            style: pw.TextStyle(font: fontBold, fontSize: 6.2, color: accentColor),
                          ),
                        );
                      }).toList(),
                    ),
                  pw.SizedBox(height: 6),

                  pw.Divider(height: 1, thickness: 0.6, color: const PdfColor.fromInt(0xFF163048)),
                  pw.SizedBox(height: 5),

                  // Especificação Técnica Detalhada
                  pw.Text(
                    'ESPECIFICAÇÃO DO PROJETO:',
                    style: pw.TextStyle(font: fontBold, fontSize: 6.8, color: accentColor),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    item.description,
                    style: pw.TextStyle(font: fontRegular, fontSize: 7.2, color: subtitleColor, lineSpacing: 1.3),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPdfEnvironmentCard({
    required AutomationEnvironment env,
    required double proposalTotal,
    required PdfColor cardBgColor,
    required PdfColor borderColor,
    required PdfColor titleColor,
    required PdfColor subtitleColor,
    required PdfColor accentColor,
    required pw.Font fontBold,
    required pw.Font fontRegular,
    required pw.Font fontOutfit,
    Uint8List? defaultRoomPhotoBytes,
  }) {
    final grandTotal = proposalTotal > 0 ? proposalTotal : 1.0;
    final envPct = (env.subtotal / grandTotal) * 100.0;
    final roomPhotoBytes = defaultRoomPhotoBytes;

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      decoration: pw.BoxDecoration(
        color: cardBgColor,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
        border: pw.Border.all(color: borderColor, width: 1.2),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // ── 1. CABEÇALHO DO CARD DE AMBIENTE ──
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFF071829),
              borderRadius: pw.BorderRadius.only(
                topLeft: pw.Radius.circular(9),
                topRight: pw.Radius.circular(9),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Row(
                  children: [
                    pw.Container(
                      width: 28,
                      height: 28,
                      decoration: pw.BoxDecoration(
                        color: const PdfColor.fromInt(0xFF092537),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                        border: pw.Border.all(color: accentColor, width: 1),
                      ),
                      child: pw.Center(
                        child: _buildPdfCoverCustomIcon(_getRoomIconKey(env.name), 15, accentColor),
                      ),
                    ),
                    pw.SizedBox(width: 10),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          children: [
                            pw.Text(
                              env.name.toUpperCase(),
                              style: pw.TextStyle(
                                font: fontOutfit,
                                fontSize: 11,
                                color: titleColor,
                              ),
                            ),
                            pw.SizedBox(width: 8),
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: pw.BoxDecoration(
                                color: const PdfColor.fromInt(0xFF082B3E),
                                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                                border: pw.Border.all(color: accentColor, width: 0.8),
                              ),
                              child: pw.Text(
                                '${env.totalItemsCount} ${env.totalItemsCount == 1 ? "dispositivo" : "dispositivos"}',
                                style: pw.TextStyle(font: fontBold, fontSize: 7.2, color: accentColor),
                              ),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          env.miniexplanation,
                          style: pw.TextStyle(font: fontRegular, fontSize: 7.5, color: subtitleColor),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'SUBTOTAL DO AMBIENTE',
                      style: pw.TextStyle(font: fontBold, fontSize: 6.8, color: subtitleColor),
                    ),
                    pw.SizedBox(height: 1),
                    pw.Text(
                      _currencyFormat.format(env.subtotal),
                      style: pw.TextStyle(font: fontOutfit, fontSize: 13, color: accentColor),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.Divider(height: 1, thickness: 1, color: const PdfColor.fromInt(0xFF132B42)),

          // ── 2. CORPO DO CARD (COLUNA ESQUERDA: FOTO/RESUMO + COLUNA DIREITA: EQUIPAMENTOS) ──
          pw.Padding(
            padding: const pw.EdgeInsets.all(10),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Coluna Esquerda: Box Cenário Integrado + Representatividade
                pw.Container(
                  width: 140,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Box Ilustrativo do Cenário com Foto Real HD
                      pw.Container(
                        height: 82,
                        decoration: pw.BoxDecoration(
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(7)),
                          border: pw.Border.all(color: const PdfColor.fromInt(0xFF1E3A5F), width: 1),
                        ),
                        child: pw.ClipRRect(
                          horizontalRadius: 6,
                          verticalRadius: 6,
                          child: pw.Stack(
                            fit: pw.StackFit.expand,
                            children: [
                              if (roomPhotoBytes != null)
                                pw.Image(
                                  pw.MemoryImage(roomPhotoBytes),
                                  fit: pw.BoxFit.cover,
                                )
                              else
                                pw.Container(color: const PdfColor.fromInt(0xFF0A192F)),
                              pw.Positioned(
                                top: 5,
                                left: 5,
                                child: pw.Container(
                                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                  decoration: pw.BoxDecoration(
                                    color: const PdfColor.fromInt(0xFF061424),
                                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                                    border: pw.Border.all(color: const PdfColor.fromInt(0xFF1E3A5F), width: 0.8),
                                  ),
                                  child: pw.Row(
                                    mainAxisSize: pw.MainAxisSize.min,
                                    children: [
                                      _buildPdfCoverCustomIcon('camera_alt', 8, accentColor),
                                      pw.SizedBox(width: 4),
                                      pw.Text(
                                        'Cenário Integrado',
                                        style: pw.TextStyle(font: fontBold, fontSize: 6.8, color: PdfColors.white),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 6),

                      // Card de Representatividade no Projeto
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: pw.BoxDecoration(
                          color: const PdfColor.fromInt(0xFF071A2B),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                          border: pw.Border.all(color: const PdfColor.fromInt(0xFF1E3A5F), width: 0.8),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'Representatividade no Projeto',
                              style: pw.TextStyle(font: fontRegular, fontSize: 6.8, color: subtitleColor),
                            ),
                            pw.SizedBox(height: 3),
                            pw.Row(
                              children: [
                                _buildPdfCoverCustomIcon('pie_chart', 9, accentColor),
                                pw.SizedBox(width: 4),
                                pw.Text(
                                  '${envPct.toStringAsFixed(1)}% do valor total da proposta',
                                  style: pw.TextStyle(font: fontBold, fontSize: 7.2, color: titleColor),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 10),

                // Coluna Direita: Equipamentos Adotados
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Row(
                            children: [
                              _buildPdfCoverCustomIcon('inventory', 11, accentColor),
                              pw.SizedBox(width: 5),
                              pw.Text(
                                'EQUIPAMENTOS ADOTADOS (${env.items.length})',
                                style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: titleColor),
                              ),
                            ],
                          ),
                          pw.Text(
                            'Hardware & Módulos Oficiais',
                            style: pw.TextStyle(font: fontRegular, fontSize: 7, color: subtitleColor),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 5),

                      if (env.items.isEmpty)
                        pw.Container(
                          padding: const pw.EdgeInsets.all(8),
                          decoration: const pw.BoxDecoration(
                            color: PdfColor.fromInt(0xFF071829),
                            borderRadius: pw.BorderRadius.all(pw.Radius.circular(5)),
                          ),
                          child: pw.Center(
                            child: pw.Text(
                              'Nenhum equipamento listado para este ambiente.',
                              style: pw.TextStyle(font: fontRegular, fontSize: 7.5, color: subtitleColor),
                            ),
                          ),
                        )
                      else
                        ...env.items.map((eq) {
                          final catVisual = _getPdfCategoryVisual(eq.categoryTitle);
                          return pw.Container(
                            margin: const pw.EdgeInsets.only(bottom: 5),
                            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            decoration: pw.BoxDecoration(
                              color: const PdfColor.fromInt(0xFF081B2D),
                              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                              border: pw.Border.all(color: const PdfColor.fromInt(0xFF163048), width: 0.8),
                            ),
                            child: pw.Row(
                              crossAxisAlignment: pw.CrossAxisAlignment.center,
                              children: [
                                // 1. Ícone quadrado colorido da categoria
                                pw.Container(
                                  width: 26,
                                  height: 26,
                                  decoration: pw.BoxDecoration(
                                    color: catVisual.bgColor,
                                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
                                    border: pw.Border.all(color: catVisual.color, width: 1),
                                  ),
                                  child: pw.Center(
                                    child: _buildPdfCoverCustomIcon(catVisual.iconKey, 13, catVisual.color),
                                  ),
                                ),
                                pw.SizedBox(width: 8),

                                // 2. Informações do Equipamento
                                pw.Expanded(
                                  child: pw.Column(
                                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                                    children: [
                                      pw.Text(
                                        eq.name,
                                        style: pw.TextStyle(font: fontBold, fontSize: 8.2, color: titleColor),
                                        maxLines: 1,
                                      ),
                                      pw.SizedBox(height: 2),
                                      pw.Row(
                                        children: [
                                          pw.Container(
                                            padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                            decoration: pw.BoxDecoration(
                                              color: catVisual.badgeBgColor,
                                              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                                              border: pw.Border.all(color: catVisual.color, width: 0.7),
                                            ),
                                            child: pw.Text(
                                              eq.categoryTitle.isNotEmpty ? eq.categoryTitle : catVisual.displayName,
                                              style: pw.TextStyle(font: fontBold, fontSize: 6.2, color: catVisual.color),
                                            ),
                                          ),
                                          pw.SizedBox(width: 5),
                                          pw.Text(
                                            'Marca: ${(eq.manufacturer != null && eq.manufacturer!.isNotEmpty) ? eq.manufacturer! : "A definir"}',
                                            style: pw.TextStyle(font: fontRegular, fontSize: 6.5, color: subtitleColor),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                pw.SizedBox(width: 8),

                                // 3. Quantidade e Preços
                                pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                                  children: [
                                    pw.Container(
                                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                      decoration: pw.BoxDecoration(
                                        color: const PdfColor.fromInt(0xFF052538),
                                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                                        border: pw.Border.all(color: accentColor, width: 0.8),
                                      ),
                                      child: pw.Text(
                                        '${eq.quantity} UN',
                                        style: pw.TextStyle(font: fontBold, fontSize: 6.8, color: accentColor),
                                      ),
                                    ),
                                    pw.SizedBox(height: 2),
                                    pw.Text(
                                      _currencyFormat.format(eq.unitPrice * eq.quantity),
                                      style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: accentColor),
                                    ),
                                    pw.Text(
                                      '${_currencyFormat.format(eq.unitPrice)} un.',
                                      style: pw.TextStyle(font: fontRegular, fontSize: 6, color: subtitleColor),
                                    ),
                                  ],
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
      return fallback ?? PdfColor.fromHex('#38BDF8');
    } catch (_) {
      return fallback ?? PdfColor.fromHex('#38BDF8');
    }
  }

  /// Upload do PDF para o Firebase Storage
  static Future<String?> uploadPdfToStorage({
    required Uint8List pdfBytes,
    required ProposalModel proposal,
  }) async {
    try {
      final companyId = proposal.companyId ?? 'default_company';
      final fileName = 'proposta_automacao_${proposal.id}.pdf';
      final ref = FirebaseStorage.instance.ref().child('propostas_mavis/$companyId/$fileName');
      final task = await ref.putData(pdfBytes, SettableMetadata(contentType: 'application/pdf'));
      return await task.ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }
}

/// Ícones SVG Vetoriais Nativos para o PDF de Automação Residencial
class AutomationPdfIcons {
  static String _svgWrap(String paths, {String color = '#0F172A', int size = 24, double strokeWidth = 2.0}) {
    return '<svg width="$size" height="$size" viewBox="0 0 24 24" fill="none" stroke="$color" stroke-width="$strokeWidth" stroke-linecap="round" stroke-linejoin="round">$paths</svg>';
  }

  /// 1. Cenas Inteligentes / Lâmpada (Conforto)
  static String sceneComfort(String color, {int size = 24}) => _svgWrap(
    '<path d="M15 14c.2-1 .7-1.7 1.5-2.5 1-.9 1.5-2.2 1.5-3.5A6 6 0 0 0 6 8c0 1 .2 2.2 1.5 3.5.7.7 1.3 1.5 1.5 2.5"/><path d="M9 18h6"/><path d="M10 22h4"/>',
    color: color,
    size: size,
  );

  /// 2. Escudo de Segurança Ativa (Proteção 24h)
  static String shieldSecurity(String color, {int size = 24}) => _svgWrap(
    '<path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/><path d="m9 12 2 2 4-4"/>',
    color: color,
    size: size,
  );

  /// 3. Folha Eco / Eficiência Energética
  static String ecoEnergy(String color, {int size = 24}) => _svgWrap(
    '<path d="M11 20A7 7 0 0 1 9.8 6.1C15.5 5 17 4.48 19 2c1 2 2 4.18 2 8 0 5.5-4.78 10-10 10Z"/><path d="M2 21c0-3 1.85-5.36 5.08-6C9.5 14.52 12 13 13 12"/>',
    color: color,
    size: size,
  );

  /// 4. Casa Inteligente / Valorização
  static String smartHome(String color, {int size = 24}) => _svgWrap(
    '<path d="m3 9 9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><polyline points="9 22 9 12 15 12 15 22"/>',
    color: color,
    size: size,
  );

  /// 5. Projeto Executivo / Arquitetura
  static String projectBlueprint(String color, {int size = 24}) => _svgWrap(
    '<rect width="18" height="18" x="3" y="3" rx="2"/><path d="M3 9h18"/><path d="M9 21V9"/>',
    color: color,
    size: size,
  );

  /// 6. Smartphone / App Conectado
  static String smartphoneApp(String color, {int size = 24}) => _svgWrap(
    '<rect width="14" height="20" x="5" y="2" rx="2" ry="2"/><path d="M12 18h.01"/>',
    color: color,
    size: size,
  );

  /// 7. Certificação / Selo de Garantia Anatel
  static String awardCert(String color, {int size = 24}) => _svgWrap(
    '<circle cx="12" cy="8" r="6"/><path d="m15.477 12.89 1.515 8.526a.5.5 0 0 1-.724.522L12 19.8l-4.268 2.138a.5.5 0 0 1-.724-.522l1.515-8.526"/>',
    color: color,
    size: size,
  );

  /// 8. Suporte & Instalação Dedicada
  static String supportHandshake(String color, {int size = 24}) => _svgWrap(
    '<path d="M7 10v12"/><path d="M15 5.88 14 10h5.83a2 2 0 0 1 1.92 2.56l-2.33 8A2 2 0 0 1 17.5 22H4a2 2 0 0 1-2-2v-8a2 2 0 0 1 2-2h3"/><path d="M10 5a3 3 0 0 1 6 0"/>',
    color: color,
    size: size,
  );

  /// 9. Ilustração Panorâmica Vetorial: Casa Inteligente Arquitetônica & Rede de Tecnologia
  static String smartHomeTechScene(String primaryColor, {String accentColor = '#38BDF8'}) {
    return '''
<svg width="490" height="78" viewBox="0 0 520 85" xmlns="http://www.w3.org/2000/svg">
  <!-- Linha de Base / Solo Tecnológico -->
  <line x1="20" y1="76" x2="500" y2="76" stroke="#CBD5E1" stroke-width="1.5" stroke-linecap="round" />
  <circle cx="260" cy="76" r="3" fill="$primaryColor" />
  <circle cx="165" cy="76" r="2.5" fill="$accentColor" />
  <circle cx="355" cy="76" r="2.5" fill="$accentColor" />

  <!-- Casa Inteligente Arquitetônica Moderna (Centro) -->
  <!-- Asa Esquerda / Garagem / Suíte -->
  <rect x="165" y="36" width="50" height="40" rx="2" fill="#F8FAFC" stroke="#64748B" stroke-width="1.5" />
  <line x1="160" y1="36" x2="215" y2="36" stroke="$primaryColor" stroke-width="2.5" stroke-linecap="round" />
  <rect x="175" y="44" width="30" height="20" rx="2" fill="#E0F2FE" stroke="$accentColor" stroke-width="1.2" />
  <line x1="190" y1="44" x2="190" y2="64" stroke="$accentColor" stroke-width="1" />

  <!-- Bloco Principal com Telhado Geométrico Moderno -->
  <polygon points="215,26 260,2 305,26" fill="#F8FAFC" stroke="$primaryColor" stroke-width="2" stroke-linejoin="round" />
  <rect x="215" y="26" width="90" height="50" rx="2" fill="#FFFFFF" stroke="$primaryColor" stroke-width="2" />

  <!-- Janelas Inteligentes com Luz Cênica Azulada -->
  <rect x="226" y="33" width="26" height="16" rx="1.5" fill="#E0F2FE" stroke="$accentColor" stroke-width="1.2" />
  <rect x="268" y="33" width="26" height="16" rx="1.5" fill="#E0F2FE" stroke="$accentColor" stroke-width="1.2" />

  <!-- Entrada Principal / Porta com Controle de Acesso -->
  <rect x="249" y="52" width="22" height="24" rx="1" fill="#0F172A" stroke="$primaryColor" stroke-width="1.2" />
  <circle cx="267" cy="64" r="1.5" fill="#10B981" />

  <!-- Ondas Wi-Fi / Conectividade no Topo do Telhado -->
  <path d="M 252, -2 A 10 10 0 0 1 268, -2" fill="none" stroke="$primaryColor" stroke-width="1.8" stroke-linecap="round" />
  <path d="M 244, -8 A 18 18 0 0 1 276, -8" fill="none" stroke="$accentColor" stroke-width="1.8" stroke-linecap="round" />

  <!-- Circuitos de Conexão Lado Esquerdo -->
  <polyline points="215,24 165,12 110,12" fill="none" stroke="$accentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" />
  <polyline points="165,50 120,50 85,38" fill="none" stroke="#94A3B8" stroke-width="1.2" stroke-linecap="round" stroke-linejoin="round" />
  <polyline points="165,66 115,66 65,66" fill="none" stroke="$primaryColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" />

  <!-- Circuitos de Conexão Lado Direito -->
  <polyline points="305,24 355,12 410,12" fill="none" stroke="$accentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" />
  <polyline points="305,50 350,50 435,38" fill="none" stroke="#94A3B8" stroke-width="1.2" stroke-linecap="round" stroke-linejoin="round" />
  <polyline points="305,66 360,66 455,66" fill="none" stroke="$primaryColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" />

  <!-- Nós IoT e Dispositivos Conectados -->
  <!-- 1. Iluminação (Top Left) -->
  <circle cx="110" cy="12" r="11" fill="#FFFFFF" stroke="$accentColor" stroke-width="1.5" />
  <path d="M 108,10 c0.2,-0.8 0.5,-1.2 1,-1.5 a2.5 2.5 0 0 1 3,0 c0.5,0.3 0.8,0.7 1,1.5 M 108.5,13.5 h3 M 109.5,15 h1" fill="none" stroke="$accentColor" stroke-width="1.1" stroke-linecap="round" />

  <!-- 2. Segurança / Fechadura (Mid Left) -->
  <circle cx="85" cy="38" r="11" fill="#FFFFFF" stroke="#64748B" stroke-width="1.5" />
  <path d="M 85,44 s3.5,-1.8 3.5,-4.5 V 34 l-3.5,-1.2 -3.5,1.2 v4.3 c0,2.7 3.5,4.5 3.5,4.5 z" fill="none" stroke="#64748B" stroke-width="1.1" stroke-linejoin="round" />

  <!-- 3. Smartphone App (Bottom Left) -->
  <circle cx="65" cy="66" r="11" fill="#FFFFFF" stroke="$primaryColor" stroke-width="1.5" />
  <rect x="61.5" y="60" width="7" height="12" rx="1.2" fill="none" stroke="$primaryColor" stroke-width="1.1" />
  <circle cx="65" cy="69.5" r="0.6" fill="$primaryColor" />

  <!-- 4. Wi-Fi / Rede Mesh (Top Right) -->
  <circle cx="410" cy="12" r="11" fill="#FFFFFF" stroke="$accentColor" stroke-width="1.5" />
  <path d="M 406,10 a5 5 0 0 1 8,0 M 407.5,12.5 a2.5 2.5 0 0 1 5,0" fill="none" stroke="$accentColor" stroke-width="1.1" stroke-linecap="round" />
  <circle cx="410" cy="15" r="0.7" fill="$accentColor" />

  <!-- 5. Climatização Inteligente (Mid Right) -->
  <circle cx="435" cy="38" r="11" fill="#FFFFFF" stroke="#64748B" stroke-width="1.5" />
  <path d="M 435,41 v-5 a1.2 1.2 0 0 0 -2.4,0 v5 a2 2 0 1 0 2.4,0 z" fill="none" stroke="#64748B" stroke-width="1.1" />

  <!-- 6. Áudio & Multiroom (Bottom Right) -->
  <circle cx="455" cy="66" r="11" fill="#FFFFFF" stroke="$primaryColor" stroke-width="1.5" />
  <path d="M 453,69 v-6 l4,-1.2 v5 M 451.5,69 a1.5 1.2 0 1 0 1.5,0 M 455.5,67.8 a1.5 1.2 0 1 0 1.5,0" fill="none" stroke="$primaryColor" stroke-width="1.1" />
</svg>
''';
  }
}

/// Estrutura para estilização consistente e fiel dos cards de categoria no PDF
class _PdfCategoryVisual {
  final String iconKey;
  final PdfColor color;
  final PdfColor bgColor;
  final PdfColor badgeBgColor;
  final String displayName;

  const _PdfCategoryVisual({
    required this.iconKey,
    required this.color,
    required this.bgColor,
    required this.badgeBgColor,
    required this.displayName,
  });
}
