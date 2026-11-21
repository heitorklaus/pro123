import 'dart:convert';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/proposal_dto.dart';
import '../models/solar_settings_dto.dart';
import '../services/cover_image_cache_service.dart';
import 'cover_divider_svg_builder.dart';
import 'solar_pdf_icons.dart';

class SolarProposalPdfEngine {
  static final _currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  static final _numberFormat = NumberFormat.decimalPattern('pt_BR');

  static PdfColor _darkenPdfColor(PdfColor c, double amount) {
    final t = amount.clamp(0.0, 1.0);
    return PdfColor(
      (c.red * (1.0 - t) + 0.04 * t).clamp(0.0, 1.0),
      (c.green * (1.0 - t) + 0.06 * t).clamp(0.0, 1.0),
      (c.blue * (1.0 - t) + 0.08 * t).clamp(0.0, 1.0),
    );
  }

  static PdfColor _lightenPdfColor(PdfColor c, double amount) {
    final t = amount.clamp(0.0, 1.0);
    return PdfColor(
      (c.red + (1.0 - c.red) * t).clamp(0.0, 1.0),
      (c.green + (1.0 - c.green) * t).clamp(0.0, 1.0),
      (c.blue + (1.0 - c.blue) * t).clamp(0.0, 1.0),
    );
  }

  static String _pdfColorToHex(PdfColor c) {
    String h(double v) =>
        (v * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
    return '#${h(c.red)}${h(c.green)}${h(c.blue)}';
  }

  static bool _isDefaultDarkBgHex(String hex) {
    final norm = hex.replaceAll('#', '').trim().toUpperCase();
    return norm.isEmpty || norm == '0F172A' || norm == '0B1120';
  }

  static Future<Uint8List> generatePdf({
    required ProposalDTO proposal,
    SolarSettingsDTO? settings,
    Uint8List? coverBytes,
  }) async {
    final s = settings ?? const SolarSettingsDTO();
    final pdf = pw.Document();
    final isCoverThemedStyle = s.proposalStyle == 'corporateWave' ||
        s.proposalStyle == 'verticalSplit';
    final themeBase = isCoverThemedStyle
        ? PdfColor.fromInt(s.verticalSplitAccentColorValue)
        : PdfColor.fromInt(s.themeColorValue);
    final hasExplicitIconTheme = s.selectedSvgTheme.trim().startsWith('#');
    final primaryColor = (hasExplicitIconTheme || !isCoverThemedStyle)
        ? PdfColor.fromInt(s.themeColorValue)
        : _darkenPdfColor(themeBase, 0.22);
    final secNorm = s.secondaryThemeColor.replaceAll('#', '').trim().toUpperCase();
    final hasDefaultSecondary = secNorm.isEmpty || secNorm == '102C49';
    final secondaryColor = (isCoverThemedStyle && hasDefaultSecondary)
        ? themeBase
        : PdfColor.fromInt(s.secondaryThemeColorValue);

    final hiddenPages = s.hiddenPageIds;
    final customPages = s.customPages;

    int totalPages = 1; // page_1 (Capa)
    if (!hiddenPages.contains('page_2')) totalPages++;
    if (!hiddenPages.contains('page_3')) totalPages++;
    if (!hiddenPages.contains('page_5')) totalPages++;
    if (!hiddenPages.contains('page_6')) totalPages++;
    if (!hiddenPages.contains('page_7')) totalPages++;
    for (final cp in customPages) {
      if (!hiddenPages.contains(cp.id)) totalPages++;
    }

    int curPage = 1;

    // Carrega a imagem da capa (Custom Base64 / Firebase Storage / Web Background) — 100% igual ao CRM
    Uint8List? coverImageBytes = coverBytes;

    // 1. Foto customizada da empresa (upload)
    if (coverImageBytes == null &&
        s.customCoverImageBase64 != null &&
        s.customCoverImageBase64!.isNotEmpty) {
      try {
        final clean = s.customCoverImageBase64!.contains(',')
            ? s.customCoverImageBase64!.split(',').last
            : s.customCoverImageBase64!;
        coverImageBytes = base64Decode(clean);
      } catch (_) {}
    }

    final useCleanBgForDivider = s.proposalStyle == 'verticalSplit' ||
        (s.proposalStyle == 'modern' &&
            (s.isCustomCoverMode || s.customDividerStyle >= 0));

    if (coverImageBytes == null && useCleanBgForDivider) {
      final bg = s.webBackgroundTemplate;
      final cleanBg = (bg.isNotEmpty &&
              !bg.startsWith('modelo_') &&
              !bg.contains('energiasolar'))
          ? bg
          : 'AdobeStock_1028630041.jpg';
      coverImageBytes = await CoverImageCacheService.fetchWebBackgroundBytes(cleanBg);
      coverImageBytes ??=
          await CoverImageCacheService.fetchWebBackgroundBytes('AdobeStock_1028630041.jpg');
    }

    // 2. Capa oficial selecionada no catálogo (selectedCoverTemplate)
    if (coverImageBytes == null &&
        !useCleanBgForDivider &&
        s.selectedCoverTemplate.isNotEmpty) {
      coverImageBytes = await CoverImageCacheService.fetchCoverBytes(s.selectedCoverTemplate);
      coverImageBytes ??= await CoverImageCacheService.fetchWebBackgroundBytes(s.selectedCoverTemplate);
    }

    // 3. Template de Wallpaper Web configurado (webBackgroundTemplate)
    if (coverImageBytes == null && s.webBackgroundTemplate.isNotEmpty) {
      coverImageBytes = await CoverImageCacheService.fetchCoverBytes(s.webBackgroundTemplate);
      coverImageBytes ??= await CoverImageCacheService.fetchWebBackgroundBytes(s.webBackgroundTemplate);
    }

    // 4. Fallback padrão garantido
    if (coverImageBytes == null) {
      coverImageBytes = await CoverImageCacheService.fetchCoverBytes('modelo_proposta_1.jpg');
      coverImageBytes ??= await CoverImageCacheService.getCoverBytes(s.effectiveCoverUrl);
    }

    // Carrega foto panorâmica da residência para a Página 3 (com cache em memória)
    final page3HouseBytes = await CoverImageCacheService.fetchCoverBytes('solar_page3_house.jpg');

    ProposalItemDTO? solarItem;
    for (final it in proposal.items) {
      if (it.isSolarPlant || (it.solarKilowatts != null && it.solarKilowatts! > 0)) {
        solarItem = it;
        break;
      }
    }
    solarItem ??= proposal.items.isNotEmpty ? proposal.items.first : null;

    final kwp = solarItem?.solarKilowatts ??
        (proposal.totalAmount > 0 ? (proposal.totalAmount / 2300.0) : 8.68);
    double monthlyKwh = solarItem?.estimatedMonthlyKwh ?? 0.0;
    if (monthlyKwh <= 0) {
      final match = RegExp(r'(\d+(?:\.\d+)?)\s*kWh', caseSensitive: false)
          .firstMatch('${proposal.title} ${solarItem?.name ?? ""}');
      if (match != null) {
        monthlyKwh = double.tryParse(match.group(1)!) ?? 0.0;
      }
    }
    if (monthlyKwh <= 0 && (solarItem?.solarComponents == null || solarItem!.solarComponents!.isEmpty)) {
      monthlyKwh = (kwp * 115.2).clamp(100.0, 50000.0);
    }
    final dailyKwh = monthlyKwh / 30.0;

    int modulesCount = 0;
    int moduleWatts = 620;
    String inverterModel = '';
    double inverterKw = (kwp * 0.75).clamp(3.0, 100.0);
    final hasExplicitComponents =
        solarItem?.solarComponents != null && solarItem!.solarComponents!.isNotEmpty;

    if (solarItem != null) {
      if (solarItem.effectiveModuleWatts != null) {
        moduleWatts = solarItem.effectiveModuleWatts!.toInt();
      }
      if (solarItem.solarComponents != null) {
        for (final compStr in solarItem.solarComponents!) {
          final comp = compStr.trim();
          final lowerName = comp.toLowerCase();
          int compQty = 1;
          final qtyMatch =
              RegExp(r'^(\d+)\s*(?:x|un|unid|pc)?\b', caseSensitive: false).firstMatch(comp);
          if (qtyMatch != null) compQty = int.tryParse(qtyMatch.group(1)!) ?? 1;

          if (lowerName.contains('modulo') ||
              lowerName.contains('módulo') ||
              lowerName.contains('placa') ||
              lowerName.contains('painel') ||
              lowerName.contains('bifacial')) {
            modulesCount += compQty;
            final matchW =
                RegExp(r'(\d{3,4})\s*(?:w|watts|wp)\b', caseSensitive: false).firstMatch(comp);
            if (matchW != null) moduleWatts = int.tryParse(matchW.group(1)!) ?? 620;
          } else if (lowerName.contains('inversor') || lowerName.contains('microinversor')) {
            inverterModel = comp;
            final matchK =
                RegExp(r'(\d+(?:[\.,]\d+)?)\s*kw\b', caseSensitive: false).firstMatch(comp);
            if (matchK != null) {
              inverterKw = double.tryParse(matchK.group(1)!.replaceAll(',', '.')) ?? inverterKw;
            }
          }
        }
      }
    }

    if (!hasExplicitComponents) {
      if (modulesCount == 0) {
        modulesCount = ((kwp * 1000) / moduleWatts).round();
        if (modulesCount <= 0) modulesCount = 14;
      }
      if (inverterModel.isEmpty) {
        inverterModel = 'Inversor Solar Grid-Tie';
      }
    }

    final occupiedArea = modulesCount > 0 ? modulesCount * 2.6 : 0.0;
    if (modulesCount > 0 && monthlyKwh <= 0) {
      monthlyKwh = (kwp * 115.2).clamp(100.0, 50000.0);
    }
    final roofType = solarItem?.solarRoofType ?? 'Cerâmica';

    // ── PÁGINA 1: CAPA DINÂMICA (100% IDÊNTICA AO SISTEMA) ──
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (context) => _buildCoverPage(
          coverBytes: coverImageBytes,
          proposal: proposal,
          settings: s,
          generationMonthly: monthlyKwh,
          kwp: kwp,
          primaryColor: primaryColor,
        ),
      ),
    );
    curPage++;

    // ── PÁGINA 2: PROPOSTA COMERCIAL & ESCOPO ──
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
            settings: s,
            proposal: proposal,
            content: _buildPage2Content(
              primaryColor,
              customCards: s.page2Cards,
            ),
          ),
        ),
      );
    }

    // ── PÁGINA 3: SUA USINA SOLAR ──
    if (!hiddenPages.contains('page_3')) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (context) => _buildProgrammaticPageLayout(
            pageTitle: 'SUA USINA SOLAR',
            pageNumber: curPage++,
            totalPages: totalPages,
            primaryColor: primaryColor,
            settings: s,
            proposal: proposal,
            fullBleedContent: true,
            content: _buildPage3Content(
              kwp: kwp,
              modulesCount: modulesCount,
              moduleWatts: moduleWatts,
              inverterModel: inverterModel,
              inverterKw: inverterKw,
              roofType: roofType,
              generationMonthly: monthlyKwh,
              occupiedArea: occupiedArea,
              primaryColor: primaryColor,
              secondaryColor: secondaryColor,
              houseImageBytes: page3HouseBytes,
            ),
          ),
        ),
      );
    }

    // ── PÁGINA 4 (page_5 no gerenciador): ITENS DA USINA & PAGAMENTO ──
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
            settings: s,
            proposal: proposal,
            fullBleedContent: true,
            content: _buildPage4Content(
              proposal: proposal,
              solarItem: solarItem,
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

    // ── PÁGINA 5 (page_6 no gerenciador): ANÁLISE DE INVESTIMENTO ──
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
            settings: s,
            proposal: proposal,
            fullBleedContent: true,
            content: _buildPage5Content(
              proposal: proposal,
              settings: s,
              generationMonthly: monthlyKwh,
              generationDaily: dailyKwh,
              kwp: kwp,
              primaryColor: primaryColor,
              secondaryColor: secondaryColor,
            ),
          ),
        ),
      );
    }

    // ── PÁGINA 6 (page_7 no gerenciador): FINANCIAMENTO & CONDIÇÕES ──
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
            settings: s,
            proposal: proposal,
            fullBleedContent: true,
            content: _buildPage6Content(
              proposal: proposal,
              settings: s,
              primaryColor: primaryColor,
              secondaryColor: secondaryColor,
            ),
          ),
        ),
      );
    }

    // ── PÁGINAS PERSONALIZADAS DO USUÁRIO ──
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
              settings: s,
              proposal: proposal,
              content: _buildCustomPageContent(cp, primaryColor),
            ),
          ),
        );
      }
    }

    return pdf.save();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // CONSTRUÇÃO DA CAPA (PÁGINA 1) — Corporate Wave, Vertical Split & Modern
  // ───────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildCorporateWavePdfCover({
    required Uint8List? coverBytes,
    required ProposalDTO proposal,
    required SolarSettingsDTO settings,
    required double generationMonthly,
    required double kwp,
  }) {
    final primaryHex = (settings.verticalSplitAccentColor.isNotEmpty
            ? settings.verticalSplitAccentColor
            : '#0284C7')
        .replaceAll('#', '')
        .trim();
    final primarySvgColor = '#$primaryHex';
    final primaryPdfColor = PdfColor.fromInt(settings.verticalSplitAccentColorValue);

    String toHex2(double c) =>
        (c * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
    final rL = (primaryPdfColor.red + (1.0 - primaryPdfColor.red) * 0.45).clamp(0.0, 1.0);
    final gL = (primaryPdfColor.green + (1.0 - primaryPdfColor.green) * 0.45).clamp(0.0, 1.0);
    final bL = (primaryPdfColor.blue + (1.0 - primaryPdfColor.blue) * 0.45).clamp(0.0, 1.0);
    final secondarySvgColor = '#${toHex2(rL)}${toHex2(gL)}${toHex2(bL)}';

    Uint8List? logoBytes;
    if (settings.coverShowLogo &&
        settings.companyLogoBase64 != null &&
        settings.companyLogoBase64!.isNotEmpty) {
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
                  settings.companyName.isNotEmpty
                      ? settings.companyName.toUpperCase()
                      : 'SUA EMPRESA',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: const PdfColor.fromInt(0xFF0F172A),
                  ),
                ),
              pw.SizedBox(height: 32),
              pw.Text(
                settings.coverTitle.isNotEmpty
                    ? settings.coverTitle.toUpperCase()
                    : 'PROPOSTA\nCOMERCIAL',
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                  fontSize: 26,
                  fontWeight: pw.FontWeight.bold,
                  color: const PdfColor.fromInt(0xFF0F172A),
                  lineSpacing: 2,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                settings.coverSubtitle.isNotEmpty
                    ? settings.coverSubtitle.toUpperCase()
                    : 'ENERGIA SOLAR FOTOVOLTAICA',
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
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
                style: const pw.TextStyle(
                  fontSize: 11,
                  color: PdfColor.fromInt(0xFF475569),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                '${kwp.toStringAsFixed(2)} kWp - ${generationMonthly.toStringAsFixed(0)} kWh/mês',
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: primaryPdfColor,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Brasil - 2026',
                textAlign: pw.TextAlign.right,
                style: const pw.TextStyle(
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
              if (settings.companyPhone.isNotEmpty)
                pw.Text(
                  'Tel: ${settings.companyPhone}',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.white),
                ),
              pw.Text(
                'Email: contato@empresa.com.br',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.white),
              ),
              if (settings.companyWebsite.isNotEmpty)
                pw.Text(
                  'Site: ${settings.companyWebsite}',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.white),
                ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildVerticalSplitPdfCover({
    required Uint8List? coverBytes,
    required ProposalDTO proposal,
    required SolarSettingsDTO settings,
    required double generationMonthly,
    required double kwp,
  }) {
    final accentHex = settings.verticalSplitAccentColor.replaceAll('#', '').trim();
    final accentSvgColor = '#$accentHex';
    final accentPdfColor = PdfColor.fromInt(settings.verticalSplitAccentColorValue);
    final divType = settings.verticalSplitDividerType;
    final badges = settings.verticalSplitFooterBadges;

    String svgOverlay;
    if (divType == 1) {
      svgOverlay = '''
<svg viewBox="0 0 595.28 841.89" width="595.28" height="841.89" xmlns="http://www.w3.org/2000/svg">
  <polygon points="405,0 595.28,0 595.28,841.89 208,841.89 321,547 250,547 386,269 285,269" fill="#FFFFFF" />
  <polyline points="405,0 285,269 386,269 250,547 321,547 208,841.89" fill="none" stroke="$accentSvgColor" stroke-width="4.5" stroke-linecap="round" stroke-linejoin="round" />
</svg>
''';
    } else if (divType == 2) {
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
    if (proposal.clientName.trim().isNotEmpty &&
        resolvedSubtitle.toUpperCase() == 'FAMÍLIA SILVA') {
      final cNameUpper = proposal.clientName.trim().toUpperCase();
      resolvedSubtitle = cNameUpper.startsWith('FAMÍLIA') ? cNameUpper : 'FAMÍLIA $cNameUpper';
    }

    Uint8List? logoBytes;
    if (settings.coverShowLogo &&
        settings.companyLogoBase64 != null &&
        settings.companyLogoBase64!.isNotEmpty) {
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
        if (coverBytes != null)
          pw.Image(pw.MemoryImage(coverBytes), fit: pw.BoxFit.cover)
        else
          pw.Container(color: const PdfColor.fromInt(0xFF0F172A)),

        pw.SvgImage(svg: svgOverlay),

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
                          ? _parsePdfColor(settings.verticalSplitHeadlineDividerColor,
                              fallback: accentPdfColor)
                          : accentPdfColor,
                    ),
                    pw.SizedBox(height: 12),
                  ] else ...[
                    pw.SizedBox(height: 12),
                  ],
                  pw.Text(
                    settings.verticalSplitSubheadline,
                    style: pw.TextStyle(
                      fontSize: 11.0,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromInt(settings.coverHeadlineColorValue),
                      lineSpacing: 1.8,
                    ),
                  ),
                ],
              ),
            ),
          ),

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
                                    _buildPdfCoverCustomIcon(badges[i].iconKey, 12,
                                        PdfColor.fromInt(settings.coverBadgesIconColorValue)),
                                    pw.SizedBox(width: 5),
                                    pw.Text(
                                      badges[i].label,
                                      style: pw.TextStyle(
                                        fontSize: 9.0,
                                        fontWeight: pw.FontWeight.bold,
                                        color:
                                            PdfColor.fromInt(settings.coverBadgesTextColorValue),
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
                                      _buildPdfCoverCustomIcon(badges[i].iconKey, 12,
                                          PdfColor.fromInt(settings.coverBadgesIconColorValue)),
                                      pw.SizedBox(width: 5),
                                      pw.Text(
                                        badges[i].label,
                                        style: pw.TextStyle(
                                          fontSize: 9.0,
                                          fontWeight: pw.FontWeight.bold,
                                          color: PdfColor.fromInt(
                                              settings.coverBadgesTextColorValue),
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (i < badges.length - 1)
                                    pw.Container(
                                      width: 1.5,
                                      height: 12,
                                      color: const PdfColor.fromInt(0x66FFFFFF),
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
                                      _buildPdfCoverCustomIcon(
                                          badges[i].iconKey, 12, accentPdfColor),
                                      pw.SizedBox(width: 5),
                                      pw.Text(
                                        badges[i].label,
                                        style: pw.TextStyle(
                                          fontSize: 9.0,
                                          fontWeight: pw.FontWeight.bold,
                                          color: PdfColor.fromInt(
                                              settings.coverBadgesTextColorValue),
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (i < badges.length - 1)
                                    pw.Container(
                                      width: 1.5,
                                      height: 12,
                                      color: const PdfColor.fromInt(0x66FFFFFF),
                                      margin: const pw.EdgeInsets.symmetric(horizontal: 6),
                                    ),
                                ],
                              ],
                            ),
            ),
          ),

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
                          ? _parsePdfColor(settings.verticalSplitRightDividerColor,
                              fallback: accentPdfColor)
                          : accentPdfColor,
                    ),
                    pw.SizedBox(height: 14),
                  ] else ...[
                    pw.SizedBox(height: 14),
                  ],
                  pw.Text(
                    settings.verticalSplitRightTagline,
                    style: pw.TextStyle(
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
                                fontSize: 10.5,
                                fontWeight: pw.FontWeight.bold,
                                color: const PdfColor.fromInt(0xFF1E293B),
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
                        fontSize: 10.0,
                        fontWeight: pw.FontWeight.bold,
                        color: const PdfColor.fromInt(0xFF0F172A),
                      ),
                    ),
                  ],
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Proposta: PROP-${proposal.proposalNumber}  |  $kwp kWp',
                    style: const pw.TextStyle(
                      fontSize: 7.5,
                      color: PdfColor.fromInt(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ),

        for (final textItem in settings.customTextItems)
          pw.Positioned(
            left: textItem.x * a4W,
            top: textItem.y * a4H,
            child: pw.Text(
              textItem.text,
              style: pw.TextStyle(
                fontSize: textItem.fontSize,
                fontWeight: textItem.isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: PdfColor.fromInt(textItem.colorValue),
              ),
            ),
          ),

        for (final iconItem in settings.customIconItems)
          pw.Positioned(
            left: iconItem.x * a4W,
            top: iconItem.y * a4H,
            child: _buildPdfCoverCustomIcon(
                iconItem.iconKey, iconItem.size, PdfColor.fromInt(iconItem.colorValue)),
          ),
      ],
    );
  }

  static pw.Widget _buildCoverPage({
    required Uint8List? coverBytes,
    required ProposalDTO proposal,
    required SolarSettingsDTO settings,
    required double generationMonthly,
    required double kwp,
    required PdfColor primaryColor,
  }) {
    if (settings.proposalStyle == 'corporateWave') {
      return _buildCorporateWavePdfCover(
        coverBytes: coverBytes,
        proposal: proposal,
        settings: settings,
        generationMonthly: generationMonthly,
        kwp: kwp,
      );
    }

    if (settings.proposalStyle == 'verticalSplit') {
      return _buildVerticalSplitPdfCover(
        coverBytes: coverBytes,
        proposal: proposal,
        settings: settings,
        generationMonthly: generationMonthly,
        kwp: kwp,
      );
    }

    const a4W = 595.28;
    const a4H = 841.89;
    final accentPdfColor = PdfColor.fromInt(settings.verticalSplitAccentColorValue);
    final accentHex = (settings.customDividerColor.isNotEmpty
            ? settings.customDividerColor
            : (settings.verticalSplitAccentColor.isNotEmpty
                ? settings.verticalSplitAccentColor
                : '#F59E0B'))
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
    if (proposal.clientName.trim().isNotEmpty &&
        resolvedSubtitle.toUpperCase() == 'FAMÍLIA SILVA') {
      final cNameUpper = proposal.clientName.trim().toUpperCase();
      resolvedSubtitle = cNameUpper.startsWith('FAMÍLIA') ? cNameUpper : 'FAMÍLIA $cNameUpper';
    }

    return pw.Stack(
      fit: pw.StackFit.expand,
      children: [
        // 1. Imagem de Fundo da Capa
        if (coverBytes != null && coverBytes.isNotEmpty)
          pw.Image(pw.MemoryImage(coverBytes), fit: pw.BoxFit.cover)
        else
          pw.Container(color: PdfColors.white),

        // 2. Separador Vetorial se for Capa Customizada (10 Estilos Matemáticos)
        if (settings.customDividerStyle >= 0)
          pw.SvgImage(
            svg: CoverDividerSvgBuilder.buildSvg(
              dividerType: settings.customDividerStyle,
              width: a4W,
              height: a4H,
              splitYRatio: 0.72,
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
              width: a4W * 0.88,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    settings.verticalSplitHeadline,
                    style: pw.TextStyle(
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
                          ? _parsePdfColor(settings.verticalSplitHeadlineDividerColor,
                              fallback: accentPdfColor)
                          : accentPdfColor,
                    ),
                    pw.SizedBox(height: 10),
                  ] else ...[
                    pw.SizedBox(height: 10),
                  ],
                  pw.Text(
                    settings.verticalSplitSubheadline,
                    style: pw.TextStyle(
                      fontSize: 10.5,
                      fontWeight: pw.FontWeight.bold,
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
                          ? const PdfColor.fromInt(0x60FFFFFF)
                          : const PdfColor.fromInt(0x40000000),
                      margin: const pw.EdgeInsets.symmetric(horizontal: 7),
                    ),
                ],
              ],
            ),
          ),

        // 5. Bloco Institucional na Área Branca Preservada
        if (settings.verticalSplitShowRightBlock)
          pw.Positioned(
            left: (a4W -
                    (settings.verticalSplitRightBlockRight * a4W) -
                    (a4W * 0.42))
                .clamp(-a4W * 0.4, a4W * 0.92),
            top: (settings.verticalSplitRightBlockTop * a4H)
                .clamp(-a4H * 0.2, a4H * 0.95),
            child: pw.SizedBox(
              width: a4W * 0.42,
              child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  resolvedTitle,
                  style: pw.TextStyle(
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
                        ? _parsePdfColor(settings.verticalSplitRightDividerColor,
                            fallback: accentPdfColor)
                        : accentPdfColor,
                  ),
                  pw.SizedBox(height: 9),
                ] else ...[
                  pw.SizedBox(height: 10),
                ],
                pw.Text(
                  settings.verticalSplitRightTagline,
                  style: pw.TextStyle(
                    fontSize: 9.5,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromInt(settings.coverRightTaglineColorValue),
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
            ),
          ),

        // 6. Logomarca Customizada Posicionada pelo Usuário
        if (settings.coverShowLogo &&
            settings.companyLogoBase64 != null &&
            settings.companyLogoBase64!.isNotEmpty)
          pw.Positioned(
            left: (a4W * settings.coverLogoPositionX).clamp(0.0, a4W - settings.coverLogoWidth),
            top: (a4H * settings.coverLogoPositionY).clamp(0.0, a4H - 50.0),
            child: pw.Image(
              pw.MemoryImage(base64Decode(
                settings.companyLogoBase64!.contains(',')
                    ? settings.companyLogoBase64!.split(',').last
                    : settings.companyLogoBase64!,
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
                      fontSize: 9.0,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromInt(settings.coverFooterColorValue),
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Emissão: ${DateFormat('dd/MM/yyyy').format(proposal.createdAt)}  -  Validade: ${proposal.validityDays} dias  -  Proposta: ${proposal.proposalNumber}',
                    style: const pw.TextStyle(
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
                        fontSize: settings.coverClientInfoFontSize,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromInt(settings.coverClientInfoColorValue),
                      ),
                      maxLines: 1,
                    ),
                  if (proposal.clientDocument != null &&
                      proposal.clientDocument!.trim().isNotEmpty) ...[
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'CPF/CNPJ: ${proposal.clientDocument!.trim()}',
                      style: pw.TextStyle(
                        fontSize: settings.coverClientInfoFontSize * 0.9,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromInt(settings.coverClientInfoSecondaryColorValue),
                      ),
                      maxLines: 1,
                    ),
                  ],
                  if (generationMonthly > 0 && kwp > 0) ...[
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Geração: ${_numberFormat.format(generationMonthly)} kWh/mês (${kwp.toStringAsFixed(2)} kWp)',
                      style: pw.TextStyle(
                        fontSize: settings.coverClientInfoFontSize * 0.9,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromInt(settings.coverClientInfoSecondaryColorValue),
                      ),
                      maxLines: 1,
                    ),
                  ],
                ],
              ),
            ),
          ),

        // 9. Textos Personalizados Extras Adicionados pelo Usuário
        for (final textItem in settings.customTextItems)
          pw.Positioned(
            left: textItem.x * a4W,
            top: textItem.y * a4H,
            child: pw.Text(
              textItem.text,
              style: pw.TextStyle(
                fontSize: textItem.fontSize,
                fontWeight: textItem.isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: PdfColor.fromInt(textItem.colorValue),
              ),
            ),
          ),

        // 10. Ícones Personalizados Extras Adicionados pelo Usuário
        for (final iconItem in settings.customIconItems)
          pw.Positioned(
            left: iconItem.x * a4W,
            top: iconItem.y * a4H,
            child: _buildPdfCoverCustomIcon(
                iconItem.iconKey, iconItem.size, PdfColor.fromInt(iconItem.colorValue)),
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
        svgContent =
            '<svg viewBox="0 0 24 24" width="$size" height="$size"><polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2" fill="$hex"/></svg>';
        break;
      case 'chart':
      case 'grafico':
      case 'valorizacao':
      case 'bar_chart':
      case 'trending_up':
      case 'show_chart':
        svgContent =
            '<svg viewBox="0 0 24 24" width="$size" height="$size"><rect x="3" y="12" width="4.5" height="9" rx="1" fill="$hex"/><rect x="9.75" y="4" width="4.5" height="17" rx="1" fill="$hex"/><rect x="16.5" y="8" width="4.5" height="13" rx="1" fill="$hex"/></svg>';
        break;
      case 'coins':
      case 'moedas':
      case 'dinheiro':
      case 'money':
      case 'attach_money':
      case 'savings':
      case 'economia':
        svgContent =
            '<svg viewBox="0 0 24 24" width="$size" height="$size"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 14.5h-2v-1.5c-1.3-.2-2-1.1-2-2.5h1.5c0 .8.5 1.5 1.5 1.5s1.5-.7 1.5-1.5c0-.9-.7-1.3-1.8-1.7-1.5-.5-2.7-1.1-2.7-2.8 0-1.4.9-2.3 2-2.5V4.5h2V6c1.1.2 1.8 1 1.8 2.2h-1.5c0-.7-.4-1.2-1.3-1.2s-1.2.5-1.2 1.2c0 .8.6 1.1 1.6 1.5 1.7.6 2.9 1.2 2.9 3 0 1.5-.9 2.5-2 2.8v1.5z" fill="$hex"/></svg>';
        break;
      case 'sun':
      case 'sol':
      case 'solar_power':
      case 'painel':
        svgContent =
            '<svg viewBox="0 0 24 24" width="$size" height="$size"><circle cx="12" cy="12" r="5" fill="$hex"/><path d="M12 1v2M12 21v2M4.22 4.22l1.42 1.42M18.36 18.36l1.42 1.42M1 12h2M21 12h2M4.22 19.78l1.42-1.42M18.36 5.64l1.42-1.42" stroke="$hex" stroke-width="2.5" stroke-linecap="round"/></svg>';
        break;
      case 'star':
      case 'estrela':
      case 'favorito':
        svgContent =
            '<svg viewBox="0 0 24 24" width="$size" height="$size"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2" fill="$hex"/></svg>';
        break;
      case 'shield':
      case 'seguranca':
      case 'garantia':
        svgContent =
            '<svg viewBox="0 0 24 24" width="$size" height="$size"><path d="M12 1L3 5v6c0 5.55 3.84 10.74 9 12 5.16-1.26 9-6.45 9-12V5l-9-4z" fill="$hex"/></svg>';
        break;
      case 'verified':
      case 'check':
      case 'qualidade':
        svgContent =
            '<svg viewBox="0 0 24 24" width="$size" height="$size"><path d="M12 2L9.19 3.63 6 3.17 4.13 5.8 1.5 7.19 1.72 10.42 0 12.81 1.72 15.2 1.5 18.43 4.13 19.82 6 22.45 9.19 21.99 12 23.62 14.81 21.99 18 22.45 19.87 19.82 22.5 18.43 22.28 15.2 24 12.81 22.28 10.42 22.5 7.19 19.87 5.8 18 3.17 14.81 3.63 12 2zm-1.5 14.5l-4-4 1.41-1.41L10.5 13.67l6.59-6.59 1.41 1.41-8 8z" fill="$hex"/></svg>';
        break;
      case 'phone':
      case 'whatsapp':
      case 'telefone':
      case 'contato':
        svgContent =
            '<svg viewBox="0 0 24 24" width="$size" height="$size"><path d="M6.62 10.79a15.053 15.053 0 006.59 6.59l2.2-2.2c.27-.27.67-.36 1.02-.24 1.12.37 2.33.57 3.57.57.55 0 1 .45 1 1V20c0 .55-.45 1-1 1-9.39 0-17-7.61-17-17 0-.55.45-1 1-1h3.5c.55 0 1 .45 1 1 0 1.25.2 2.45.57 3.57.11.35.03.74-.25 1.02l-2.2 2.2z" fill="$hex"/></svg>';
        break;
      case 'location':
      case 'localizacao':
      case 'endereco':
      case 'map':
        svgContent =
            '<svg viewBox="0 0 24 24" width="$size" height="$size"><path d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7zm0 9.5c-1.38 0-2.5-1.12-2.5-2.5s1.12-2.5 2.5-2.5 2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5z" fill="$hex"/></svg>';
        break;
      case 'mail':
      case 'email':
        svgContent =
            '<svg viewBox="0 0 24 24" width="$size" height="$size"><path d="M20 4H4c-1.1 0-1.99.9-1.99 2L2 18c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2zm0 4l-8 5-8-5V6l8 5 8-5v2z" fill="$hex"/></svg>';
        break;
      case 'home':
      case 'casa':
      case 'residencia':
        svgContent =
            '<svg viewBox="0 0 24 24" width="$size" height="$size"><path d="M10 20v-6h4v6h5v-8h3L12 3 2 12h3v8z" fill="$hex"/></svg>';
        break;
      case 'leaf':
      case 'eco':
      case 'nature':
      case 'sustentabilidade':
      default:
        svgContent =
            '<svg viewBox="0 0 24 24" width="$size" height="$size"><path d="M17 8C8 10 5.9 16.17 3.82 21.34l1.89.66.95-2.3c.48.17.98.3 1.34.3C19 20 22 3 22 3c-1 2-8 2.52-12.5 4.5" fill="none" stroke="$hex" stroke-width="2.5" stroke-linecap="round"/></svg>';
        break;
    }
    return pw.SvgImage(svg: svgContent, width: size, height: size);
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

  static bool _isDarkColor(PdfColor color) {
    return (color.red * 0.299 + color.green * 0.587 + color.blue * 0.114) < 0.60;
  }

  static pw.Widget _buildPdfCoverHeader({
    required int styleId,
    required String text1,
    required String text2,
    required String text3,
    required PdfColor accentColor,
    PdfColor? customBgColor,
    PdfColor? customTextColor,
    PdfColor? customIconColor,
  }) {
    final effectiveAccent = customIconColor ?? accentColor;
    final title = text1.trim().isNotEmpty ? text1 : 'PROPOSTA COMERCIAL';
    final subtitle = text2.trim().isNotEmpty ? text2 : '';
    final tag = text3.trim().isNotEmpty ? text3 : '';

    switch (styleId) {
      case 2:
        final bg = customBgColor ?? PdfColor.fromHex('#0F172A');
        final isDark = _isDarkColor(bg);
        final titleColor =
            customTextColor ?? (isDark ? PdfColors.white : PdfColor.fromHex('#0F172A'));
        final subColor =
            customTextColor ?? (isDark ? effectiveAccent : PdfColor.fromHex('#475569'));
        final tagColor =
            customTextColor ?? (isDark ? PdfColor.fromHex('#94A3B8') : PdfColor.fromHex('#64748B'));
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
                  pw.Text(title,
                      style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: titleColor,
                          letterSpacing: 1.2)),
                  if (subtitle.isNotEmpty)
                    pw.Text(subtitle, style: pw.TextStyle(fontSize: 7.5, color: subColor)),
                ],
              ),
              if (tag.isNotEmpty)
                pw.Text(tag, style: pw.TextStyle(fontSize: 8, color: tagColor)),
            ],
          ),
        );
      case 9:
        final bg = customBgColor ?? PdfColor.fromHex('#0F172A');
        final isDark = customBgColor != null ? _isDarkColor(customBgColor) : true;
        final titleColor =
            customTextColor ?? (isDark ? PdfColors.white : PdfColor.fromHex('#334155'));
        final subColor =
            customTextColor ?? (isDark ? PdfColor.fromHex('#CBD5E1') : PdfColor.fromHex('#64748B'));
        final tagColor = customTextColor ?? (isDark ? PdfColors.white : effectiveAccent);
        return pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 5),
          color: bg,
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(title,
                  style: pw.TextStyle(
                      fontSize: 8, fontWeight: pw.FontWeight.bold, color: titleColor)),
              if (subtitle.isNotEmpty)
                pw.Text(subtitle, style: pw.TextStyle(fontSize: 8, color: subColor)),
              if (tag.isNotEmpty)
                pw.Text(tag, style: pw.TextStyle(fontSize: 8, color: tagColor)),
            ],
          ),
        );
      case 1:
      default:
        final bg = customBgColor ?? PdfColors.white;
        final isDark = customBgColor != null ? _isDarkColor(customBgColor) : false;
        final titleColor =
            customTextColor ?? (isDark ? PdfColors.white : PdfColor.fromHex('#0F172A'));
        final subColor =
            customTextColor ?? (isDark ? PdfColor.fromHex('#E2E8F0') : PdfColor.fromHex('#64748B'));
        return pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          decoration: pw.BoxDecoration(
            color: bg,
            border: pw.Border(
                bottom: pw.BorderSide(
                    color: isDark ? effectiveAccent : const PdfColor.fromInt(0x30000000),
                    width: isDark ? 2.0 : 0.8)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  pw.Text(title,
                      style: pw.TextStyle(
                          fontSize: 11, fontWeight: pw.FontWeight.bold, color: titleColor)),
                  if (subtitle.isNotEmpty)
                    pw.Text(subtitle, style: pw.TextStyle(fontSize: 7.5, color: subColor)),
                ],
              ),
              if (tag.isNotEmpty)
                pw.Text(tag, style: pw.TextStyle(fontSize: 8, color: effectiveAccent)),
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
    PdfColor? customBgColor,
    PdfColor? customTextColor,
    PdfColor? customIconColor,
  }) {
    final effectiveAccent = customIconColor ?? accentColor;
    final bg = customBgColor ?? PdfColor.fromHex('#0F172A');
    final isDark = _isDarkColor(bg);
    final t1Color =
        customTextColor ?? (isDark ? effectiveAccent : PdfColor.fromHex('#0F172A'));
    final t2Color =
        customTextColor ?? (isDark ? PdfColor.fromHex('#CBD5E1') : PdfColor.fromHex('#475569'));
    final t4Color =
        customTextColor ?? (isDark ? PdfColor.fromHex('#94A3B8') : PdfColor.fromHex('#64748B'));

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      color: bg,
      child: pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          if (text1.isNotEmpty)
            pw.Text(text1.replaceAll('•', '-'),
                style: pw.TextStyle(
                    fontSize: 8.5,
                    fontWeight: pw.FontWeight.bold,
                    color: t1Color,
                    letterSpacing: 0.5)),
          if (text2.isNotEmpty || text3.isNotEmpty) ...[
            pw.SizedBox(height: 2),
            pw.Text('${text2.replaceAll('•', '-')}  -  ${text3.replaceAll('•', '-')}',
                style: pw.TextStyle(fontSize: 7.5, color: t2Color)),
          ],
          if (text4.isNotEmpty) ...[
            pw.SizedBox(height: 2),
            pw.Text(text4, style: pw.TextStyle(fontSize: 6.5, color: t4Color)),
          ],
        ],
      ),
    );
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
    required SolarSettingsDTO settings,
    required ProposalDTO proposal,
    bool fullBleedContent = false,
  }) {
    final textDark = PdfColor.fromHex('#0F172A');
    final textMuted = PdfColor.fromHex('#64748B');
    final lineGrey = PdfColor.fromHex('#E2E8F0');
    final slogan = (settings.companySlogan != null && settings.companySlogan!.trim().isNotEmpty)
        ? settings.companySlogan!.trim().toUpperCase()
        : 'ENERGIA QUE TRANSFORMA';

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

    final isCoverThemed = settings.proposalStyle == 'corporateWave' ||
        settings.proposalStyle == 'verticalSplit';
    final themedDarkBg = _darkenPdfColor(primaryColor, 0.58);
    final customHeaderBg =
        (isCoverThemed && _isDefaultDarkBgHex(settings.coverHeaderBgColor))
            ? themedDarkBg
            : (settings.coverHeaderBgColor.isNotEmpty
                ? _parsePdfColor(settings.coverHeaderBgColor)
                : themedDarkBg);
    final customHeaderTxt = settings.coverHeaderTextColor.isNotEmpty
        ? _parsePdfColor(settings.coverHeaderTextColor)
        : null;
    final customHeaderIcon = settings.coverHeaderIconColor.isNotEmpty
        ? _parsePdfColor(settings.coverHeaderIconColor)
        : null;

    final customFooterBg =
        (isCoverThemed && _isDefaultDarkBgHex(settings.coverFooterBgColor))
            ? themedDarkBg
            : (settings.coverFooterBgColor.isNotEmpty
                ? _parsePdfColor(settings.coverFooterBgColor)
                : themedDarkBg);
    final customFooterTxt = settings.coverFooterTextColor.isNotEmpty
        ? _parsePdfColor(settings.coverFooterTextColor)
        : null;
    final customFooterIcon = settings.coverFooterIconColor.isNotEmpty
        ? _parsePdfColor(settings.coverFooterIconColor)
        : null;

    pw.Widget topHeader;
    if (settings.coverShowHeader) {
      topHeader = _buildPdfCoverHeader(
        styleId: settings.coverHeaderStyle,
        text1: settings.coverHeaderText1.isNotEmpty ? settings.coverHeaderText1 : pageTitle,
        text2: settings.coverHeaderText2.isNotEmpty
            ? settings.coverHeaderText2
            : proposal.proposalNumber,
        text3: settings.coverHeaderText3.isNotEmpty
            ? settings.coverHeaderText3
            : 'Página $pageNumber de $totalPages',
        accentColor: primaryColor,
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
  // PÁGINA 2: APRESENTAÇÃO & ESCOPO
  // ───────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildPage2Content(
    PdfColor primaryColor, {
    List<ProposalPageCardDTO>? customCards,
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
            style: pw.TextStyle(
                fontSize: 17, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A')),
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
          style: pw.TextStyle(
              fontSize: 17, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A')),
        ),
        pw.SizedBox(height: 14),

        pw.Row(
          children: [
            pw.Expanded(
              child: _buildInfoCardBadge(
                title: 'Confiança se conquista',
                description:
                    'Atuamos do início ao fim da instalação, inclusive com pós-venda especializado e equipe própria dedicada.',
                svgIcon: SolarPdfIcons.shieldCheck(hex),
              ),
            ),
            pw.SizedBox(width: 14),
            pw.Expanded(
              child: _buildInfoCardBadge(
                title: 'Bom negócio',
                description:
                    'Você se torna produtor da sua própria energia: investe com retorno rápido e lucra por mais de 25 anos.',
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
                description:
                    'Trabalhamos exclusivamente com as melhores marcas globais de módulos Tier 1 e inversores certificados.',
                svgIcon: SolarPdfIcons.solarTech(hex),
              ),
            ),
            pw.SizedBox(width: 14),
            pw.Expanded(
              child: _buildInfoCardBadge(
                title: 'Zero dor de cabeça',
                description:
                    'Processo ágil, seguro e padronizado. Instalação rápida concluída em poucos dias sem obras pesadas.',
                svgIcon: SolarPdfIcons.thumbsUp(hex),
              ),
            ),
          ],
        ),

        pw.SizedBox(height: 24),
        pw.Text(
          'Escopo do Projeto (Turn-Key)',
          style: pw.TextStyle(
              fontSize: 17, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A')),
        ),
        pw.SizedBox(height: 14),

        pw.Row(
          children: [
            pw.Expanded(
              child: _buildInfoCardBadge(
                title: 'Solução completa',
                description:
                    'Projeto Turn-Key integral: cuidamos do projeto executivo, ART, montagem, homologação e concessionária.',
                svgIcon: SolarPdfIcons.lightbulb(hex),
              ),
            ),
            pw.SizedBox(width: 14),
            pw.Expanded(
              child: _buildInfoCardBadge(
                title: 'Aplicativo gratuito',
                description:
                    'Acompanhe na palma da mão, em tempo real, a geração de energia e a economia acumulada da sua usina 24h.',
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
                description:
                    'Equipamentos entregues com frete e seguro 100% cobertos diretamente no endereço da instalação da usina.',
                svgIcon: SolarPdfIcons.truck(hex),
              ),
            ),
            pw.SizedBox(width: 14),
            pw.Expanded(
              child: _buildInfoCardBadge(
                title: 'Certificação e garantias',
                description:
                    'Módulos e inversores homologados pelo INMETRO, com até 25 anos de garantia de fábrica estendida.',
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
    ProposalCustomPageDTO page,
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
                  color: PdfColor.fromHex(
                      c.cardBgColorHex != null && c.cardBgColorHex!.isNotEmpty
                          ? c.cardBgColorHex!
                          : '#F8FAFC'),
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(c.title,
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 11,
                            color: PdfColor.fromHex('#0F172A'))),
                    pw.SizedBox(height: 4),
                    pw.Text(c.description,
                        style: pw.TextStyle(fontSize: 9.5, color: PdfColor.fromHex('#475569'))),
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
                style: pw.TextStyle(
                    fontSize: 11.5,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#0F172A')),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                description,
                textAlign: pw.TextAlign.center,
                style:
                    pw.TextStyle(fontSize: 8.5, color: PdfColor.fromHex('#475569'), height: 1.25),
              ),
            ],
          ),
        ),
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
  // PÁGINA 3: SUA USINA SOLAR
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
        : '$inverterModel - ${inverterKw.toStringAsFixed(0)} kW';

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
                      style: const pw.TextStyle(
                        fontSize: 9.8,
                        color: PdfColor.fromInt(0xFFE2E8F0),
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
                if (modulesCount > 0) ...[
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
                ],
                if (inverterModel.trim().isNotEmpty)
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
                if (generationMonthly > 0)
                  _buildTechRow(
                    label: 'Produção Média de Energia:',
                    value: '${generationMonthly.toStringAsFixed(2)} kWh/mês',
                    svgIcon: SolarPdfIcons.trendingUp('#FFFFFF'),
                    primaryColor: primaryColor,
                  ),
                if (occupiedArea > 0)
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
    required ProposalDTO proposal,
    required ProposalItemDTO? solarItem,
    required PdfColor primaryColor,
    required PdfColor secondaryColor,
    int modulesCount = 12,
    int moduleWatts = 620,
    String inverterModel = 'Inversor Solar Grid-Tie',
    double inverterKw = 6.0,
    String roofType = 'Fibrocimento',
  }) {
    final rawComponents = solarItem?.solarComponents ?? [];
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
        if (modulesCount > 0)
          '$modulesCount× módulo fotovoltaico monocristalino $moduleWatts W Tier 1',
        if (inverterModel.trim().isNotEmpty)
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
                            if (proposal.paymentTerms.trim().isNotEmpty) ...[
                              pw.SizedBox(height: 3),
                              pw.Text(
                                proposal.paymentTerms.trim(),
                                style: pw.TextStyle(
                                  fontSize: 10.2,
                                  fontWeight: pw.FontWeight.bold,
                                  color: const PdfColor.fromInt(0xFF087344),
                                ),
                              ),
                            ],
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
                if (proposal.deliveryTime != null &&
                    proposal.deliveryTime!.trim().isNotEmpty)
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
                        proposal.deliveryTime!.trim(),
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
    required ProposalDTO proposal,
    required SolarSettingsDTO settings,
    required double generationMonthly,
    required double generationDaily,
    required double kwp,
    required PdfColor primaryColor,
    required PdfColor secondaryColor,
  }) {
    final yearlyData = settings.calculateYearlySimulation(
      monthlyKwh: generationMonthly,
      systemKwp: kwp,
      connectionTypeOverride: proposal.connectionType,
      availabilityKwhOverride: proposal.availabilityKwh,
      publicLightingOverride: proposal.publicLightingValueRs,
    );

    final rows21 = yearlyData.take(21).toList();
    final startYear = rows21.isNotEmpty ? rows21.first.year : DateTime.now().year;
    final endYear = rows21.isNotEmpty ? rows21.last.year : (DateTime.now().year + 20);

    final totalWithoutSolar =
        yearlyData.fold(0.0, (prev, item) => prev + (item.withoutSolar * 12));
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
    required ProposalDTO proposal,
    required SolarSettingsDTO settings,
    required PdfColor primaryColor,
    required PdfColor secondaryColor,
  }) {
    final activeBanks = settings.financingBanks.where((b) => b.isActive).toList();
    final banksToRender = <SolarFinancingBankDTO>[
      activeBanks.isNotEmpty
          ? activeBanks[0]
          : const SolarFinancingBankDTO(
              id: 'solfacil',
              name: 'SolFácil',
              monthlyInterestRate: 1.25,
              enabledInstallments: [12, 24, 36, 48, 60],
            ),
      activeBanks.length > 1
          ? activeBanks[1]
          : const SolarFinancingBankDTO(
              id: 'santander',
              name: 'Santander',
              monthlyInterestRate: 1.19,
              enabledInstallments: [12, 24, 36, 48, 60],
            ),
      activeBanks.length > 2
          ? activeBanks[2]
          : const SolarFinancingBankDTO(
              id: 'sicredi',
              name: 'Sicredi',
              monthlyInterestRate: 1.15,
              enabledInstallments: [12, 24, 36, 60, 90],
            ),
      activeBanks.length > 3
          ? activeBanks[3]
          : const SolarFinancingBankDTO(
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

    final cardFillHex = _pdfColorToHex(_darkenPdfColor(secondaryColor, 0.25));
    final cardStrokeHex = _pdfColorToHex(_lightenPdfColor(secondaryColor, 0.45));
    final cardDot1Hex = _pdfColorToHex(_lightenPdfColor(secondaryColor, 0.65));
    final cardDot2Hex = _pdfColorToHex(_lightenPdfColor(secondaryColor, 0.45));

    final cardIllustrationSvg = '''
<svg viewBox="0 0 110 68" width="90" height="56">
  <g transform="rotate(-10 55 34)">
    <rect x="10" y="10" width="84" height="50" rx="8" fill="$cardFillHex" stroke="$cardStrokeHex" stroke-width="1.2"/>
    <rect x="20" y="25" width="12" height="9" rx="2" fill="#FBBF24"/>
    <circle cx="72" cy="24" r="3.5" fill="$cardDot1Hex" opacity="0.85"/>
    <circle cx="77" cy="24" r="3.5" fill="$cardDot2Hex" opacity="0.85"/>
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
                          color: _lightenPdfColor(secondaryColor, 0.55),
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

                pw.Expanded(
                  flex: 54,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      ...[3, 6, 9, 12].map((installments) {
                        final rateItem = settings.creditCardRates.firstWhere(
                          (r) => r.installment == installments,
                          orElse: () => CreditCardInstallmentRateDTO(
                              installment: installments, feePercentage: installments * 1.05),
                        );
                        final val = rateItem.calculateInstallmentValue(proposal.totalAmount);

                        return pw.Container(
                          margin: pw.EdgeInsets.only(bottom: installments == 12 ? 0 : 6),
                          padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 7.5),
                          decoration: pw.BoxDecoration(
                            color: _darkenPdfColor(secondaryColor, 0.45),
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                            border: pw.Border.all(
                              color: _darkenPdfColor(secondaryColor, 0.25),
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
    SolarFinancingBankDTO bank,
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

  static pw.Widget _buildBankLogoWidget(SolarFinancingBankDTO bank, PdfColor primaryColor) {
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
    } else if (upper.contains('MÓDULO') ||
        upper.contains('MODULO') ||
        upper.contains('PAINEL') ||
        upper.contains('PLACA') ||
        upper.contains('FOTOVOLTAICO')) {
      return SolarPdfIcons.panelGrid(hex);
    } else if (upper.contains('ESTRUTURA') ||
        upper.contains('PERFIL') ||
        upper.contains('FIXAÇÃO') ||
        upper.contains('FIXACAO') ||
        upper.contains('TELHADO') ||
        upper.contains('TELHA')) {
      return SolarPdfIcons.roof(hex);
    } else if (upper.contains('STRING') ||
        upper.contains('DPS') ||
        upper.contains('CHAVE') ||
        upper.contains('QUADRO') ||
        upper.contains('PROTEÇÃO') ||
        upper.contains('PROTECAO')) {
      return SolarPdfIcons.shieldCheck(hex);
    } else if (upper.contains('CABO') || upper.contains('CONECTOR') || upper.contains('MC4')) {
      return SolarPdfIcons.cablePlug(hex);
    } else if (upper.contains('HOMOLOGAÇÃO') ||
        upper.contains('HOMOLOGACAO') ||
        upper.contains('ENGENHARIA') ||
        upper.contains('PROJETO') ||
        upper.contains('ART')) {
      return SolarPdfIcons.documentFile(hex);
    } else {
      return SolarPdfIcons.solarTech(hex);
    }
  }
}
