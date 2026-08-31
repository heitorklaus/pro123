import 'dart:convert';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/proposal_dto.dart';
import '../models/solar_settings_dto.dart';
import '../services/cover_image_cache_service.dart';
import 'solar_pdf_icons.dart';

class SolarProposalPdfEngine {
  static final _currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  static final _numberFormat = NumberFormat.decimalPattern('pt_BR');

  static Future<Uint8List> generatePdf({
    required ProposalDTO proposal,
    SolarSettingsDTO? settings,
    Uint8List? coverBytes,
  }) async {
    final s = settings ?? const SolarSettingsDTO();
    final pdf = pw.Document();
    final primaryColor = PdfColor.fromInt(s.themeColorValue);

    Uint8List? cover = coverBytes;
    if (cover == null) {
      if (s.isCustomCoverMode && s.customCoverImageBase64 != null && s.customCoverImageBase64!.isNotEmpty) {
        try {
          cover = base64Decode(s.customCoverImageBase64!);
        } catch (_) {}
      }
    }
    if (cover == null) {
      cover = await CoverImageCacheService.getCoverBytes(s.effectiveCoverUrl);
    }

    ProposalItemDTO? solarItem;
    for (final it in proposal.items) {
      if (it.isSolarPlant || (it.solarKilowatts != null && it.solarKilowatts! > 0)) {
        solarItem = it;
        break;
      }
    }
    solarItem ??= proposal.items.isNotEmpty ? proposal.items.first : null;

    final kwp = solarItem?.solarKilowatts ?? 9.0;
    double monthlyKwh = solarItem?.estimatedMonthlyKwh ?? 0.0;
    if (monthlyKwh <= 0) {
      final match = RegExp(r'(\d+(?:\.\d+)?)\s*kWh', caseSensitive: false)
          .firstMatch('${proposal.title} ${solarItem?.name ?? ""}');
      if (match != null) {
        monthlyKwh = double.tryParse(match.group(1)!) ?? 0.0;
      }
    }
    if (monthlyKwh <= 0) {
      monthlyKwh = (kwp * 135.0).roundToDouble();
    }
    final dailyKwh = monthlyKwh / 30.0;

    int modulesCount = 0;
    int moduleWatts = 615;
    String inverterModel = 'INVERSOR SOLAR GRID-TIE';
    double inverterKw = (kwp * 0.75).clamp(3.0, 100.0);

    if (solarItem != null) {
      if (solarItem.effectiveModuleWatts != null) {
        moduleWatts = solarItem.effectiveModuleWatts!.toInt();
      }
      if (solarItem.solarComponents != null) {
        for (final comp in solarItem.solarComponents!) {
          final upper = comp.toUpperCase();
          int compQty = 1;
          final qtyMatch = RegExp(r'^(\d+)\s*(?:x|un|unid|pc)?\b', caseSensitive: false).firstMatch(comp);
          if (qtyMatch != null) compQty = int.tryParse(qtyMatch.group(1)!) ?? 1;

          if (upper.contains('MODULO') || upper.contains('MÓDULO') || upper.contains('PLACA') || upper.contains('PAINEL')) {
            modulesCount += compQty;
            final matchW = RegExp(r'(\d{3,4})\s*(?:w|watts|wp)\b', caseSensitive: false).firstMatch(comp);
            if (matchW != null) moduleWatts = int.tryParse(matchW.group(1)!) ?? moduleWatts;
          } else if (upper.contains('INVERSOR') || upper.contains('MICROINVERSOR')) {
            inverterModel = comp;
            final matchK = RegExp(r'(\d+(?:[\.,]\d+)?)\s*kw\b', caseSensitive: false).firstMatch(comp);
            if (matchK != null) {
              inverterKw = double.tryParse(matchK.group(1)!.replaceAll(',', '.')) ?? inverterKw;
            }
          }
        }
      }
    }

    if (modulesCount == 0) {
      modulesCount = ((kwp * 1000) / moduleWatts).round();
      if (modulesCount <= 0) modulesCount = 14;
    }

    final occupiedArea = modulesCount * 2.6;
    final roofType = solarItem?.solarRoofType ?? 'Cerâmico';

    // ── PÁGINA 1: CAPA DINÂMICA ──
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (context) => _buildCoverPage(
          coverBytes: cover,
          proposal: proposal,
          settings: s,
          generationMonthly: monthlyKwh,
          kwp: kwp,
          primaryColor: primaryColor,
        ),
      ),
    );

    // ── PÁGINA 2: PROPOSTA COMERCIAL & ESCOPO ──
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (context) => _buildProgrammaticPageLayout(
          pageTitle: 'PROPOSTA COMERCIAL',
          pageNumber: 2,
          totalPages: 6,
          primaryColor: primaryColor,
          settings: s,
          proposal: proposal,
          content: _buildPage2Content(primaryColor),
        ),
      ),
    );

    // ── PÁGINA 3: SUA USINA SOLAR ──
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (context) => _buildProgrammaticPageLayout(
          pageTitle: 'SUA USINA SOLAR',
          pageNumber: 3,
          totalPages: 6,
          primaryColor: primaryColor,
          settings: s,
          proposal: proposal,
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
          ),
        ),
      ),
    );

    // ── PÁGINA 4: ITENS DA USINA & PAGAMENTO ──
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (context) => _buildProgrammaticPageLayout(
          pageTitle: 'ITENS DA USINA & PAGAMENTO',
          pageNumber: 4,
          totalPages: 6,
          primaryColor: primaryColor,
          settings: s,
          proposal: proposal,
          content: _buildPage4Content(
            proposal: proposal,
            solarItem: solarItem,
            primaryColor: primaryColor,
          ),
        ),
      ),
    );

    // ── PÁGINA 5: ANÁLISE DE INVESTIMENTO ──
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (context) => _buildProgrammaticPageLayout(
          pageTitle: 'ANÁLISE DE INVESTIMENTO',
          pageNumber: 5,
          totalPages: 6,
          primaryColor: primaryColor,
          settings: s,
          proposal: proposal,
          content: _buildPage5Content(
            proposal: proposal,
            settings: s,
            generationMonthly: monthlyKwh,
            generationDaily: dailyKwh,
            kwp: kwp,
            primaryColor: primaryColor,
          ),
        ),
      ),
    );

    // ── PÁGINA 6: FINANCIAMENTO & CONDIÇÕES ──
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (context) => _buildProgrammaticPageLayout(
          pageTitle: 'FINANCIAMENTO & CONDIÇÕES',
          pageNumber: 6,
          totalPages: 6,
          primaryColor: primaryColor,
          settings: s,
          proposal: proposal,
          content: _buildPage6Content(
            proposal: proposal,
            settings: s,
            primaryColor: primaryColor,
          ),
        ),
      ),
    );

    return pdf.save();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // CONSTRUÇÃO DA CAPA (PÁGINA 1)
  // ───────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildCoverPage({
    required Uint8List? coverBytes,
    required ProposalDTO proposal,
    required SolarSettingsDTO settings,
    required double generationMonthly,
    required double kwp,
    required PdfColor primaryColor,
  }) {
    const a4W = 595.28;
    const a4H = 841.89;

    final badgeLeft = (a4W * settings.coverBadgePositionX).clamp(16.0, 360.0);
    final badgeTop = (a4H * settings.coverBadgePositionY).clamp(16.0, 480.0);

    final rawColor = PdfColor.fromInt(settings.coverBadgeColorValue);
    final badgeBgColor = PdfColor(rawColor.red, rawColor.green, rawColor.blue, settings.coverBadgeOpacity);

    return pw.Stack(
      fit: pw.StackFit.expand,
      children: [
        if (coverBytes != null && coverBytes.isNotEmpty)
          pw.Image(pw.MemoryImage(coverBytes), fit: pw.BoxFit.cover)
        else
          pw.Container(
            color: PdfColors.white,
          ),

        // Retângulo de Título Customizável Posicionado pelo Usuário
        if (settings.coverShowBadge)
          pw.Positioned(
            left: badgeLeft,
            top: badgeTop,
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: pw.BoxDecoration(
                color: badgeBgColor,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
                border: pw.Border.all(color: PdfColors.white, width: 1.5),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  pw.Text(
                    settings.coverTitle.isNotEmpty ? settings.coverTitle : 'PROPOSTA COMERCIAL',
                    style: pw.TextStyle(
                      fontSize: settings.coverTitleFontSize > 0 ? settings.coverTitleFontSize : 13.0,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromInt(settings.coverTitleColorValue),
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    settings.coverSubtitle.isNotEmpty ? settings.coverSubtitle : 'ENERGIA SOLAR FOTOVOLTAICA',
                    style: pw.TextStyle(
                      fontSize: settings.coverSubtitleFontSize > 0 ? settings.coverSubtitleFontSize : 8.5,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromInt(settings.coverSubtitleColorValue),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Logomarca Customizada Posicionada pelo Usuário
        if (settings.coverShowLogo && settings.companyLogoBase64 != null && settings.companyLogoBase64!.isNotEmpty)
          pw.Positioned(
            left: a4W * settings.coverLogoPositionX,
            top: a4H * settings.coverLogoPositionY,
            child: pw.Image(
              pw.MemoryImage(base64Decode(settings.companyLogoBase64!)),
              width: (settings.coverLogoWidth / 340.0) * a4W,
              fit: pw.BoxFit.contain,
            ),
          ),

        // Conteúdo Inferior (Área Branca: Dados do Cliente, Sistema e Empresa)
        pw.Positioned(
          bottom: 32,
          left: 40,
          right: 40,
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              // Bloco Esquerdo: Cliente & Detalhes da Usina
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      pw.Text(
                        'PROPOSTA COMERCIAL',
                        style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: primaryColor),
                      ),
                      pw.SizedBox(width: 6),
                      pw.Container(
                        width: 3.5,
                        height: 3.5,
                        decoration: pw.BoxDecoration(shape: pw.BoxShape.circle, color: primaryColor),
                      ),
                      pw.SizedBox(width: 6),
                      pw.Text(
                        proposal.proposalNumber,
                        style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: primaryColor),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    children: [
                      pw.Container(width: 22, height: 3, color: primaryColor),
                      pw.SizedBox(width: 6),
                      pw.Text(
                        'Geração Estimada: ${_numberFormat.format(generationMonthly)} kWh/mês (${kwp.toStringAsFixed(2)} kWp)',
                        style: pw.TextStyle(fontSize: 11.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A')),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 5),
                  if (proposal.clientName.isNotEmpty) ...[
                    pw.Text(
                      'Cliente: ${proposal.clientName}',
                      style: pw.TextStyle(fontSize: 11.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1E293B')),
                    ),
                    if (proposal.clientDocument?.isNotEmpty == true)
                      pw.Text(
                        'CPF/CNPJ: ${proposal.clientDocument!}',
                        style: pw.TextStyle(fontSize: 9.5, color: PdfColor.fromHex('#64748B')),
                      ),
                  ],
                  pw.SizedBox(height: 3),
                  pw.Row(
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      pw.Text(
                        'Emissão: ${DateFormat('dd/MM/yyyy').format(proposal.createdAt)}',
                        style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#64748B')),
                      ),
                      pw.SizedBox(width: 5),
                      pw.Container(
                        width: 2.5,
                        height: 2.5,
                        decoration: const pw.BoxDecoration(shape: pw.BoxShape.circle, color: PdfColor.fromInt(0xFF94A3B8)),
                      ),
                      pw.SizedBox(width: 5),
                      pw.Text(
                        'Validade: ${proposal.validityDays} dias',
                        style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#64748B')),
                      ),
                    ],
                  ),
                ],
              ),

              // Bloco Direito: Dados do Integrador / Contatos
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    settings.companyName.isNotEmpty ? settings.companyName : 'SOLI ENERGIA SOLAR',
                    style: pw.TextStyle(fontSize: 12.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A')),
                  ),
                  if (settings.companyCnpj.isNotEmpty)
                    pw.Text(
                      'CNPJ: ${settings.companyCnpj}',
                      style: pw.TextStyle(fontSize: 9.5, color: PdfColor.fromHex('#475569')),
                    ),
                  if (settings.companyPhone.isNotEmpty)
                    pw.Text(
                      'WhatsApp: ${settings.companyPhone}',
                      style: pw.TextStyle(fontSize: 9.5, color: PdfColor.fromHex('#475569')),
                    ),
                  if (settings.companyWebsite.isNotEmpty)
                    pw.Text(
                      settings.companyWebsite,
                      style: pw.TextStyle(fontSize: 9.5, color: PdfColor.fromHex('#475569')),
                    ),
                  if (settings.companyInstagram.isNotEmpty)
                    pw.Text(
                      settings.companyInstagram,
                      style: pw.TextStyle(fontSize: 9.5, color: PdfColor.fromHex('#475569')),
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
  // LAYOUT MINIMALISTA PROGRAMÁTICO (CABEÇALHO & RODAPÉ NATIVOS)
  // ───────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildProgrammaticPageLayout({
    required pw.Widget content,
    required String pageTitle,
    required int pageNumber,
    required int totalPages,
    required PdfColor primaryColor,
    required SolarSettingsDTO settings,
    required ProposalDTO proposal,
  }) {
    final textDark = PdfColor.fromHex('#0F172A');
    final textMuted = PdfColor.fromHex('#64748B');
    final lineGrey = PdfColor.fromHex('#E2E8F0');
    const slogan = 'ENERGIA QUE TRANSFORMA';

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
        ],
      ),
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

        // Tabela de Especificações Técnicas
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
    required ProposalDTO proposal,
    required ProposalItemDTO? solarItem,
    required PdfColor primaryColor,
  }) {
    final components = solarItem?.solarComponents ?? [];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
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
                    (proposal.deliveryTime != null && proposal.deliveryTime!.isNotEmpty) ? proposal.deliveryTime! : 'Imediata / 3 a 5 dias úteis',
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
    required ProposalDTO proposal,
    required SolarSettingsDTO settings,
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
        // Coluna Esquerda
        pw.Expanded(
          flex: 5,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Container(
                decoration: pw.BoxDecoration(
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  border: pw.Border.all(color: PdfColor.fromHex('#CBD5E1')),
                ),
                child: pw.Column(
                  children: [
                    _buildParamHeader('Simultaneidade', primaryColor),
                    _buildParamRow('Concessionária', settings.concessionaireName),
                    _buildParamRow('Simultaneidade', '${settings.simultaneityFactor.toStringAsFixed(0)}%'),
                    _buildParamRow('Inflação Anual', '${settings.annualTariffInflation.toStringAsFixed(0)}%'),
                    _buildParamRow('Consumo Mensal', '${_numberFormat.format(generationMonthly)} kWh'),
                    _buildParamRow('Consumo Diário', '${(generationDaily).toStringAsFixed(2)} kWh'),
                    _buildParamRow('Autoconsumo', '${(generationDaily * (settings.simultaneityFactor / 100)).toStringAsFixed(2)} kWh'),
                    _buildParamRow('Geração Mensal', '${_numberFormat.format(generationMonthly)} kWh'),
                    _buildParamRow('Geração Diária', '${generationDaily.toStringAsFixed(2)} kWh'),
                    _buildParamRow('Injeção Diária', '${(generationDaily * (1 - (settings.simultaneityFactor / 100))).toStringAsFixed(2)} kWh', isLast: true),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),

              pw.Container(
                decoration: pw.BoxDecoration(
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  border: pw.Border.all(color: PdfColor.fromHex('#CBD5E1')),
                ),
                child: pw.Column(
                  children: [
                    _buildParamHeader('Gasto Total até ${DateTime.now().year + 20}', primaryColor),
                    _buildParamRow('Sem Energia Solar', _currencyFormat.format(totalWithoutSolar)),
                    _buildParamRow('Com Energia Solar', _currencyFormat.format(totalWithSolar), isLast: true),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),

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

        // Coluna Direita (Tabela)
        pw.Expanded(
          flex: 6,
          child: pw.Container(
            decoration: pw.BoxDecoration(
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              border: pw.Border.all(color: PdfColor.fromHex('#CBD5E1')),
            ),
            child: pw.Column(
              children: [
                _buildParamHeader('Simulação de Conta de Energia Elétrica', primaryColor),

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
    required ProposalDTO proposal,
    required SolarSettingsDTO settings,
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

        // Grid 2x2 dos Bancos
        pw.Row(
          children: [
            if (activeBanks.isNotEmpty)
              pw.Expanded(child: _buildBankCard(activeBanks[0], proposal.totalAmount, primaryColor))
            else
              pw.Expanded(child: _buildBankCard(const SolarFinancingBankDTO(id: 'solfacil', name: 'SolFácil', monthlyInterestRate: 1.25, enabledInstallments: [12, 24, 36, 48, 60]), proposal.totalAmount, primaryColor)),
            pw.SizedBox(width: 14),
            if (activeBanks.length > 1)
              pw.Expanded(child: _buildBankCard(activeBanks[1], proposal.totalAmount, primaryColor))
            else
              pw.Expanded(child: _buildBankCard(const SolarFinancingBankDTO(id: 'santander', name: 'Santander', monthlyInterestRate: 1.19, enabledInstallments: [12, 24, 36, 48, 60]), proposal.totalAmount, primaryColor)),
          ],
        ),
        pw.SizedBox(height: 12),

        pw.Row(
          children: [
            if (activeBanks.length > 2)
              pw.Expanded(child: _buildBankCard(activeBanks[2], proposal.totalAmount, primaryColor))
            else
              pw.Expanded(child: _buildBankCard(const SolarFinancingBankDTO(id: 'sicredi', name: 'Sicredi', monthlyInterestRate: 1.15, enabledInstallments: [12, 24, 36, 60, 90]), proposal.totalAmount, primaryColor)),
            pw.SizedBox(width: 14),
            if (activeBanks.length > 3)
              pw.Expanded(child: _buildBankCard(activeBanks[3], proposal.totalAmount, primaryColor))
            else
              pw.Expanded(child: _buildBankCard(const SolarFinancingBankDTO(id: 'bv', name: 'BV Financeira', monthlyInterestRate: 1.09, enabledInstallments: [12, 24, 36, 48, 60]), proposal.totalAmount, primaryColor)),
          ],
        ),

        pw.SizedBox(height: 22),

        // Cartão de Crédito
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

              pw.Expanded(
                flex: 5,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    ...[
                      {'months': 3, 'rate': 1.063},
                      {'months': 6, 'rate': 1.0876},
                      {'months': 9, 'rate': 1.1123},
                      {'months': 12, 'rate': 1.1308},
                    ].map((item) {
                      final months = item['months'] as int;
                      final rate = item['rate'] as double;
                      final val = (proposal.totalAmount * rate) / months;

                      return pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 3),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('$months' 'x no Cartão:', style: const pw.TextStyle(fontSize: 9, color: PdfColors.black)),
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

  static pw.Widget _buildBankCard(SolarFinancingBankDTO bank, double totalAmount, PdfColor primaryColor) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
        border: pw.Border.all(color: PdfColor.fromHex('#CBD5E1'), width: 0.8),
      ),
      child: pw.Row(
        children: [
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
