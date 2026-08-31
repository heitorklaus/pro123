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

  /// Gera o arquivo PDF binário da Usina Solar de 6 páginas
  static Future<Uint8List> generatePdf({
    required ProposalDTO proposal,
    SolarSettingsDTO? settings,
    Uint8List? coverBytes,
  }) async {
    final s = settings ?? const SolarSettingsDTO();
    final pdf = pw.Document();

    final primaryColor = PdfColor.fromInt(s.themeColorValue);

    Uint8List? cover = coverBytes ?? await CoverImageCacheService.getCoverBytes(s.coverImageUrl);

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

    // ── PÁGINA 1: CAPA ──
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
            proposal: proposal,
            solarItem: solarItem,
            kwp: kwp,
            monthlyKwh: monthlyKwh,
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
    const a4Width = 595.28;
    const a4Height = 841.89;

    return pw.Stack(
      children: [
        if (coverBytes != null && coverBytes.isNotEmpty)
          pw.Positioned(
            left: 0,
            top: 0,
            child: pw.Image(
              pw.MemoryImage(coverBytes),
              width: a4Width,
              height: a4Height,
              fit: pw.BoxFit.cover,
            ),
          )
        else
          pw.Container(
            width: a4Width,
            height: a4Height,
            decoration: const pw.BoxDecoration(
              gradient: pw.LinearGradient(
                colors: [PdfColor.fromInt(0xFF0F172A), PdfColor.fromInt(0xFF0284C7)],
                begin: pw.Alignment.topLeft,
                end: pw.Alignment.bottomRight,
              ),
            ),
          ),

        // Selo Topo
        pw.Positioned(
          left: 36,
          top: 36,
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
              boxShadow: const [
                pw.BoxShadow(
                  color: PdfColor.fromInt(0x33000000),
                  blurRadius: 10,
                  offset: PdfPoint(0, 4),
                ),
              ],
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Text(
                  'PROPOSTA COMERCIAL',
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: primaryColor,
                    letterSpacing: 1.0,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'ENERGIA SOLAR FOTOVOLTAICA',
                  style: pw.TextStyle(
                    fontSize: 8.5,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#0F172A'),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Bloco de Dados Rodapé da Capa
        pw.Positioned(
          left: 40,
          right: 40,
          bottom: 45,
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  pw.Text(
                    'PROPOSTA COMERCIAL  •  ${proposal.proposalNumber}',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: primaryColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Row(
                    children: [
                      pw.Container(
                        width: 4,
                        height: 16,
                        margin: const pw.EdgeInsets.only(right: 8),
                        decoration: pw.BoxDecoration(
                          color: primaryColor,
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
                        ),
                      ),
                      pw.Text(
                        'Geração Estimada: ${_numberFormat.format(generationMonthly)} kWh/mês (${_numberFormat.format(kwp)} kWp)',
                        style: pw.TextStyle(
                          fontSize: 10.5,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#0F172A'),
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'Cliente: ${proposal.clientName.toUpperCase()}',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#1E293B'),
                    ),
                  ),
                  if (proposal.clientDocument != null && proposal.clientDocument!.isNotEmpty) ...[
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'CPF/CNPJ: ${proposal.clientDocument}',
                      style: pw.TextStyle(
                        fontSize: 8.5,
                        color: PdfColor.fromHex('#64748B'),
                      ),
                    ),
                  ],
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Emissão: ${DateFormat('dd/MM/yyyy').format(proposal.createdAt)}  •  Validade: ${proposal.validityDays} dias',
                    style: pw.TextStyle(
                      fontSize: 8.5,
                      color: PdfColor.fromHex('#64748B'),
                    ),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  pw.Text(
                    settings.companyName,
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#0F172A'),
                    ),
                  ),
                  if (settings.companyCnpj.isNotEmpty) ...[
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'CNPJ: ${settings.companyCnpj}',
                      style: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('#475569')),
                    ),
                  ],
                  if (settings.companyPhone.isNotEmpty) ...[
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'WhatsApp: ${settings.companyPhone}',
                      style: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('#475569')),
                    ),
                  ],
                  if (settings.companyWebsite.isNotEmpty) ...[
                    pw.SizedBox(height: 2),
                    pw.Text(
                      settings.companyWebsite,
                      style: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('#475569')),
                    ),
                  ],
                  if (settings.companyInstagram.isNotEmpty) ...[
                    pw.SizedBox(height: 2),
                    pw.Text(
                      settings.companyInstagram,
                      style: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('#475569')),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // LAYOUT PADRÃO PROGRAMÁTICO (PÁGINAS 2 A 6)
  // ───────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildProgrammaticPageLayout({
    required String pageTitle,
    required int pageNumber,
    required int totalPages,
    required PdfColor primaryColor,
    required SolarSettingsDTO settings,
    required ProposalDTO proposal,
    required pw.Widget content,
  }) {
    return pw.Container(
      width: 595.28,
      height: 841.89,
      padding: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 26),
      color: PdfColor.fromHex('#F8FAFC'),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Row(
                children: [
                  pw.Container(
                    width: 3.5,
                    height: 14,
                    margin: const pw.EdgeInsets.only(right: 8),
                    decoration: pw.BoxDecoration(
                      color: primaryColor,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
                    ),
                  ),
                  pw.Text(
                    pageTitle.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 10.5,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#0F172A'),
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
              pw.Text(
                proposal.proposalNumber,
                style: pw.TextStyle(
                  fontSize: 8.5,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#64748B'),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Stack(
            children: [
              pw.Container(height: 0.8, color: PdfColor.fromHex('#E2E8F0')),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Container(width: 75, height: 1.8, color: primaryColor),
              ),
            ],
          ),
          pw.SizedBox(height: 14),

          // Conteúdo Dinâmico Central
          pw.Expanded(child: content),

          // Footer
          pw.SizedBox(height: 10),
          pw.Stack(
            children: [
              pw.Container(height: 0.8, color: PdfColor.fromHex('#E2E8F0')),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Container(width: 75, height: 1.8, color: primaryColor),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                '⚡ ENERGIA QUE TRANSFORMA',
                style: pw.TextStyle(
                  fontSize: 7.5,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#64748B'),
                  letterSpacing: 0.5,
                ),
              ),
              pw.Text(
                'Página $pageNumber de $totalPages',
                style: pw.TextStyle(
                  fontSize: 7.5,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#64748B'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // PÁGINA 2: ESCOPO & VANTAGENS
  // ───────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildPage2Content(PdfColor primaryColor) {
    final hex = _colorToHex(primaryColor);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.SizedBox(height: 4),
        pw.Text(
          'Por que escolher a nossa solução solar?',
          style: pw.TextStyle(
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
            color: PdfColor.fromHex('#0F172A'),
          ),
        ),
        pw.SizedBox(height: 14),

        pw.Row(
          children: [
            pw.Expanded(
              child: _buildValueCard(
                title: 'Confiança se conquista',
                description: 'Atuamos do início ao fim da instalação, inclusive com pós-venda especializado e equipe própria dedicada.',
                svgIcon: SolarPdfIcons.shieldCheck(hex),
              ),
            ),
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: _buildValueCard(
                title: 'Bom negócio',
                description: 'Você se torna produtor da sua própria energia: investe com retorno rápido e lucra por mais de 25 anos.',
                svgIcon: SolarPdfIcons.dollar(hex),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 12),

        pw.Row(
          children: [
            pw.Expanded(
              child: _buildValueCard(
                title: 'Tecnologia de ponta',
                description: 'Trabalhamos exclusivamente com as melhores marcas globais de módulos Tier 1 e inversores certificados.',
                svgIcon: SolarPdfIcons.solarTech(hex),
              ),
            ),
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: _buildValueCard(
                title: 'Zero dor de cabeça',
                description: 'Processo ágil, seguro e padronizado. Instalação rápida concluída em poucos dias sem obras pesadas.',
                svgIcon: SolarPdfIcons.thumbsUp(hex),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 20),

        pw.Text(
          'Escopo do Projeto (Turn-Key)',
          style: pw.TextStyle(
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
            color: PdfColor.fromHex('#0F172A'),
          ),
        ),
        pw.SizedBox(height: 14),

        pw.Row(
          children: [
            pw.Expanded(
              child: _buildValueCard(
                title: 'Solução completa',
                description: 'Projeto Turn-Key integral: cuidamos do projeto executivo, ART, montagem, homologação e concessionária.',
                svgIcon: SolarPdfIcons.lightbulb(hex),
              ),
            ),
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: _buildValueCard(
                title: 'Aplicativo gratuito',
                description: 'Acompanhe na palma da mão, em tempo real, a geração de energia e a economia acumulada da sua usina 24h.',
                svgIcon: SolarPdfIcons.smartphone(hex),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 12),

        pw.Row(
          children: [
            pw.Expanded(
              child: _buildValueCard(
                title: 'Frete e seguro inclusos',
                description: 'Equipamentos entregues com frete e seguro 100% cobertos diretamente no endereço da instalação da usina.',
                svgIcon: SolarPdfIcons.truck(hex),
              ),
            ),
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: _buildValueCard(
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

  static pw.Widget _buildValueCard({
    required String title,
    required String description,
    required String svgIcon,
  }) {
    return pw.Container(
      height: 90,
      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
        border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0'), width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.SvgImage(svg: svgIcon, width: 22, height: 22),
          pw.SizedBox(height: 6),
          pw.Text(
            title,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: 9.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#0F172A'),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            description,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: 7.2,
              color: PdfColor.fromHex('#64748B'),
              lineSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // PÁGINA 3: SUA USINA SOLAR
  // ───────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildPage3Content({
    required ProposalDTO proposal,
    required ProposalItemDTO? solarItem,
    required double kwp,
    required double monthlyKwh,
    required PdfColor primaryColor,
  }) {
    final hex = _colorToHex(primaryColor);

    String inverterDescription = 'Inversor Solar Grid-Tie';
    int moduleCount = (kwp * 1000 / 615).round().clamp(2, 2000);
    double moduleWatts = 615.0;

    if (solarItem != null) {
      if (solarItem.effectiveModuleWatts != null) moduleWatts = solarItem.effectiveModuleWatts!;
      if (solarItem.solarComponents != null) {
        for (final comp in solarItem.solarComponents!) {
          final upper = comp.toUpperCase();
          if (upper.contains('INVERSOR') || upper.contains('MICRO')) {
            inverterDescription = comp;
          } else if (upper.contains('MÓDULO') || upper.contains('MODULO') || upper.contains('PAINEL')) {
            final match = RegExp(r'(\d+)\s*(?:PC|UN|X)', caseSensitive: false).firstMatch(comp);
            if (match != null) {
              moduleCount = int.tryParse(match.group(1)!) ?? moduleCount;
            }
          }
        }
      }
    }

    final roof = solarItem?.solarRoofType ?? 'Cerâmico';
    final estimatedArea = (moduleCount * 2.58).toStringAsFixed(2);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.SizedBox(height: 4),
        pw.Container(
          width: 44,
          height: 44,
          decoration: pw.BoxDecoration(
            color: primaryColor,
            shape: pw.BoxShape.circle,
          ),
          child: pw.Center(
            child: pw.SvgImage(
              svg: SolarPdfIcons.solarTech('#FFFFFF'),
              width: 24,
              height: 24,
            ),
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'Kit Solar Fotovoltaico de Alta Eficiência',
          style: pw.TextStyle(
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
            color: PdfColor.fromHex('#0F172A'),
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          'Módulos Monocristalinos & Inversor Grid-Tie com Conexão Wi-Fi Integrada',
          style: pw.TextStyle(
            fontSize: 8.5,
            color: PdfColor.fromHex('#64748B'),
          ),
        ),
        pw.SizedBox(height: 16),

        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: pw.BoxDecoration(
            color: PdfColors.white,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
            border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0'), width: 0.8),
          ),
          child: pw.Column(
            children: [
              _buildSpecRow('Potência do Sistema:', '${_numberFormat.format(kwp)} kWp', SolarPdfIcons.bolt('#FFFFFF'), primaryColor),
              _buildSpecRow('Quantidade de Painéis:', '$moduleCount módulos', SolarPdfIcons.solarPanel('#FFFFFF'), primaryColor),
              _buildSpecRow('Potência do Painel Solar:', '${moduleWatts.toStringAsFixed(0)} Watts', SolarPdfIcons.sunWatt('#FFFFFF'), primaryColor),
              _buildSpecRow('Modelo e Potência Inversor:', inverterDescription, SolarPdfIcons.inverter('#FFFFFF'), primaryColor),
              _buildSpecRow('Tipo de Estrutura:', roof, SolarPdfIcons.roof('#FFFFFF'), primaryColor),
              _buildSpecRow('Produção Média de Energia:', '${_numberFormat.format(monthlyKwh)} kWh/mês', SolarPdfIcons.trendingUp('#FFFFFF'), primaryColor),
              _buildSpecRow('Área Estimada Ocupada:', '$estimatedArea m²', SolarPdfIcons.rulerSquare('#FFFFFF'), primaryColor, isLast: true),
            ],
          ),
        ),
        pw.SizedBox(height: 18),

        pw.Row(
          children: [
            pw.Expanded(
              child: _buildMiniWarrantyCard('25 Anos de Garantia', 'Garantia linear de geração de fábrica.', SolarPdfIcons.award(hex)),
            ),
            pw.SizedBox(width: 10),
            pw.Expanded(
              child: _buildMiniWarrantyCard('Monitoramento Wi-Fi', 'Acompanhe a geração 24h no celular.', SolarPdfIcons.smartphone(hex)),
            ),
            pw.SizedBox(width: 10),
            pw.Expanded(
              child: _buildMiniWarrantyCard('Engenharia Turn-Key', 'Projeto executivo e homologação.', SolarPdfIcons.shieldCheck(hex)),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildSpecRow(String label, String value, String iconSvg, PdfColor primaryColor, {bool isLast = false}) {
    return pw.Column(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 7),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Row(
                children: [
                  pw.Container(
                    width: 22,
                    height: 22,
                    margin: const pw.EdgeInsets.only(right: 10),
                    decoration: pw.BoxDecoration(
                      color: primaryColor,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    child: pw.Center(
                      child: pw.SvgImage(svg: iconSvg, width: 13, height: 13),
                    ),
                  ),
                  pw.Text(
                    label,
                    style: pw.TextStyle(
                      fontSize: 9.5,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#0F172A'),
                    ),
                  ),
                ],
              ),
              pw.Text(
                value,
                style: pw.TextStyle(
                  fontSize: 9.5,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#1E293B'),
                ),
              ),
            ],
          ),
        ),
        if (!isLast) pw.Divider(color: PdfColor.fromHex('#F1F5F9'), height: 1),
      ],
    );
  }

  static pw.Widget _buildMiniWarrantyCard(String title, String subtitle, String iconSvg) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0'), width: 0.8),
      ),
      child: pw.Row(
        children: [
          pw.SvgImage(svg: iconSvg, width: 18, height: 18),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Text(title, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A'))),
                pw.SizedBox(height: 2),
                pw.Text(subtitle, style: pw.TextStyle(fontSize: 6.8, color: PdfColor.fromHex('#64748B'))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // PÁGINA 4: ITENS DA USINA & PAGAMENTO
  // ───────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildPage4Content({
    required ProposalDTO proposal,
    required ProposalItemDTO? solarItem,
    required PdfColor primaryColor,
  }) {
    final hex = _colorToHex(primaryColor);
    final components = solarItem?.solarComponents ?? [];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Equipamentos & Componentes Inclusos no Conjunto',
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: PdfColor.fromHex('#0F172A'),
          ),
        ),
        pw.SizedBox(height: 10),

        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
            color: PdfColors.white,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
            border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0'), width: 0.8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (components.isNotEmpty)
                ...components.map((comp) => _buildEquipmentRow(comp, hex, primaryColor))
              else ...[
                _buildEquipmentRow('MÓDULOS SOLARES FOTOVOLTAICOS MONOCRISTALINOS TIER 1', hex, primaryColor),
                _buildEquipmentRow('INVERSOR SOLAR GRID-TIE COM WI-FI INTEGRADO', hex, primaryColor),
                _buildEquipmentRow('ESTRUTURA DE FIXAÇÃO EM ALUMÍNIO ANODIZADO', hex, primaryColor),
                _buildEquipmentRow('QUADRO STRING BOX CC/CA COM DPS E CHAVE SECCIONADORA', hex, primaryColor),
                _buildEquipmentRow('CABOS SOLARES 1.8KV COM PROTEÇÃO UV E CONECTORES MC4', hex, primaryColor),
                _buildEquipmentRow('ENGENHARIA, PROJETO EXECUTIVO, ART E HOMOLOGAÇÃO', hex, primaryColor),
              ],
            ],
          ),
        ),
        pw.SizedBox(height: 18),

        pw.Text(
          'Forma de Pagamento',
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: PdfColor.fromHex('#0F172A'),
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          proposal.paymentTerms,
          style: pw.TextStyle(
            fontSize: 9.5,
            color: PdfColor.fromHex('#475569'),
          ),
        ),
        pw.Spacer(),

        pw.Row(
          children: [
            pw.Expanded(
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                  border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0'), width: 0.8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Investimento Total da Usina', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#64748B'))),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      _currencyFormat.format(proposal.totalAmount),
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#059669'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            pw.SizedBox(width: 14),
            pw.Expanded(
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                  border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0'), width: 0.8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Prazo de Entrega', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#64748B'))),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      proposal.deliveryTime ?? 'Imediata / 3 a 5 dias úteis',
                      style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#0F172A'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildEquipmentRow(String text, String hex, PdfColor primaryColor) {
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
                svg: SolarPdfIcons.solarTech('#FFFFFF'),
                width: 13,
                height: 13,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              text,
              style: pw.TextStyle(
                fontSize: 9.5,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#1E293B'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // PÁGINA 5: ANÁLISE 20 ANOS
  // ───────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildPage5Content({
    required ProposalDTO proposal,
    required SolarSettingsDTO settings,
    required double generationMonthly,
    required double kwp,
    required PdfColor primaryColor,
  }) {
    final yearlyData = settings.calculateYearlySimulation(monthlyKwh: generationMonthly, systemKwp: kwp);
    final dailyKwh = generationMonthly / 30.0;

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Coluna Esquerda: Simultaneidade & Economia
        pw.Expanded(
          flex: 5,
          child: pw.Column(
            children: [
              _buildSectionBox(
                title: 'Simultaneidade',
                primaryColor: primaryColor,
                rows: [
                  ['Concessionária', settings.concessionaireName],
                  ['Simultaneidade', '${settings.simultaneityFactor.toStringAsFixed(0)}%'],
                  ['Inflação Anual', '${settings.annualTariffInflation.toStringAsFixed(0)}%'],
                  ['Consumo Mensal', '${_numberFormat.format(generationMonthly)} kWh'],
                  ['Consumo Diário', '${dailyKwh.toStringAsFixed(2)} kWh'],
                  ['Autoconsumo', '${(dailyKwh * 0.13).toStringAsFixed(2)} kWh'],
                  ['Geração Mensal', '${_numberFormat.format(generationMonthly)} kWh'],
                  ['Geração Diária', '${dailyKwh.toStringAsFixed(2)} kWh'],
                  ['Injeção Diária', '${(dailyKwh * 0.87).toStringAsFixed(2)} kWh'],
                ],
              ),
              pw.SizedBox(height: 10),
              _buildSectionBox(
                title: 'Gasto Total até 2046',
                primaryColor: primaryColor,
                rows: [
                  ['Sem Energia Solar', 'R\$ 1.517.775,18'],
                  ['Com Energia Solar', 'R\$ 239.693,54'],
                ],
              ),
              pw.SizedBox(height: 10),
              _buildSectionBox(
                title: 'Simulação Média de Economia',
                primaryColor: primaryColor,
                rows: [
                  ['Economia 1º ano', 'R\$ 34.573,14'],
                  ['Economia acumulada', 'R\$ 1.278.081,64'],
                  ['Investimento', _currencyFormat.format(proposal.totalAmount)],
                  ['Tempo de Payback', '12 a 18 Meses'],
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(width: 14),

        // Coluna Direita: Tabela 20 Anos
        pw.Expanded(
          flex: 6,
          child: pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
              border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0'), width: 0.8),
            ),
            child: pw.Column(
              children: [
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(vertical: 6),
                  decoration: pw.BoxDecoration(
                    color: primaryColor,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Center(
                    child: pw.Text(
                      'Simulação de Conta de Energia Elétrica',
                      style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                    ),
                  ),
                ),
                pw.SizedBox(height: 8),

                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('ANO', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A'))),
                    pw.Text('COM SOLAR (VARIAÇÃO)', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A'))),
                    pw.Text('SEM SOLAR', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A'))),
                  ],
                ),
                pw.Divider(color: PdfColor.fromHex('#E2E8F0'), height: 6),

                ...yearlyData.map((d) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2.2),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('${d.year}', style: pw.TextStyle(fontSize: 6.8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A'))),
                      pw.Text(
                        'R\$ ${_numberFormat.format(d.withSolarMin)} à R\$ ${_numberFormat.format(d.withSolarMax)}',
                        style: pw.TextStyle(fontSize: 6.8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#059669')),
                      ),
                      pw.Text(
                        _currencyFormat.format(d.withoutSolar),
                        style: pw.TextStyle(fontSize: 6.8, color: PdfColor.fromHex('#334155')),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildSectionBox({
    required String title,
    required PdfColor primaryColor,
    required List<List<String>> rows,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0'), width: 0.8),
      ),
      child: pw.Column(
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(vertical: 4),
            decoration: pw.BoxDecoration(
              color: primaryColor,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Center(
              child: pw.Text(
                title,
                style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              ),
            ),
          ),
          pw.SizedBox(height: 6),
          ...rows.map((r) => pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 1.8),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(r[0], style: pw.TextStyle(fontSize: 7.2, color: PdfColor.fromHex('#475569'))),
                pw.Text(r[1], style: pw.TextStyle(fontSize: 7.2, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A'))),
              ],
            ),
          )),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // PÁGINA 6: FINANCIAMENTO & BANCOS
  // ───────────────────────────────────────────────────────────────────────────
  static pw.Widget _buildPage6Content({
    required ProposalDTO proposal,
    required SolarSettingsDTO settings,
    required PdfColor primaryColor,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Simulação de Financiamento Solar Bancário',
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: PdfColor.fromHex('#0F172A'),
          ),
        ),
        pw.SizedBox(height: 10),

        pw.Wrap(
          spacing: 12,
          runSpacing: 12,
          children: settings.financingBanks.map((banco) {
            return pw.Container(
              width: 250,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0'), width: 0.8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(banco.name, style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                  pw.SizedBox(height: 2),
                  pw.Text('Taxa: ${banco.monthlyInterestRate.toStringAsFixed(2)}% a.m.', style: pw.TextStyle(fontSize: 7.5, color: PdfColor.fromHex('#64748B'))),
                  pw.SizedBox(height: 6),
                  ...banco.enabledInstallments.take(4).map((m) {
                    final parcel = banco.calculateInstallment(proposal.totalAmount, m);
                    return pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 2),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('${m}x de', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A'))),
                          pw.Text(_currencyFormat.format(parcel), style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A'))),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            );
          }).toList(),
        ),
        pw.Spacer(),

        // Cartão de Crédito
        pw.Text('Parcelamento no Cartão de Crédito', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A'))),
        pw.SizedBox(height: 8),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
            color: PdfColors.white,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
            border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0'), width: 0.8),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Bandeiras Aceitas:', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A'))),
                  pw.SizedBox(height: 6),
                  pw.Text('VISA  •  MASTERCARD  •  ELO  •  AMEX  •  HIPERCARD', style: pw.TextStyle(fontSize: 7.5, color: PdfColor.fromHex('#475569'))),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('3x de ${_currencyFormat.format(proposal.totalAmount * 1.06 / 3)}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A'))),
                  pw.Text('6x de ${_currencyFormat.format(proposal.totalAmount * 1.09 / 6)}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A'))),
                  pw.Text('12x de ${_currencyFormat.format(proposal.totalAmount * 1.15 / 12)}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A'))),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _colorToHex(PdfColor color) {
    final r = (color.red * 255).round().toRadixString(16).padLeft(2, '0');
    final g = (color.green * 255).round().toRadixString(16).padLeft(2, '0');
    final b = (color.blue * 255).round().toRadixString(16).padLeft(2, '0');
    return '#$r$g$b';
  }
}
