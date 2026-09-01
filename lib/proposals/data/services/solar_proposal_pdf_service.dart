import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../settings/data/services/solar_settings_service.dart';
import '../../../settings/domain/models/solar_settings_model.dart';
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
      final fileName = '${cleanPropNumber}_proposta.pdf';
      final path = 'propostas_mavis/$companyId/$userId/$fileName';

      final storage = FirebaseStorage.instanceFor(
        app: Firebase.app(),
        bucket: 'solardino-aea02.appspot.com',
      );
      final ref = storage.ref().child(path);
      final metadata = SettableMetadata(
        contentType: 'application/pdf',
        customMetadata: {
          'proposalId': proposal.id,
          'proposalNumber': proposal.proposalNumber,
          'companyId': companyId,
          'userId': userId,
          'clientName': proposal.clientName,
          'totalAmount': proposal.totalAmount.toString(),
          'generatedAt': DateTime.now().toIso8601String(),
        },
      );


      await ref.putData(pdfBytes, metadata);
      final downloadUrl = await ref.getDownloadURL();

      if (proposal.id.isNotEmpty) {
        await FirebaseFirestore.instance.collection('proposals').doc(proposal.id).update({
          'pdfUrl': downloadUrl,
          'pdfPath': path,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      return downloadUrl;
    } catch (e) {
      return null;
    }
  }

  /// Gera a proposta comercial solar completa de 6 páginas com design minimalista programático
  static Future<Uint8List> generateSolarProposalPdf(
    ProposalModel proposal, {
    SolarSettingsModel? solarSettings,
    bool autoUploadToStorage = true,
  }) async {

    final pdf = pw.Document();

    // Carrega ou usa configurações fornecidas
    final settings = solarSettings ?? await SolarSettingsService.loadSettings(companyId: proposal.companyId);

    // Cor primária dinâmica da proposta
    final primaryColor = PdfColor.fromInt(settings.themeColorValue);

    // Carrega a imagem da capa (Custom Base64 / Firebase Storage)
    Uint8List? coverImageBytes;
    if (settings.isCustomCoverMode && settings.customCoverImageBase64 != null && settings.customCoverImageBase64!.isNotEmpty) {
      try {
        coverImageBytes = base64Decode(settings.customCoverImageBase64!);
      } catch (_) {}
    }

    if (coverImageBytes == null) {
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
          totalPages: 6,
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
          totalPages: 6,
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
    // PÁGINA 4: ITENS DA USINA & FORMA DE PAGAMENTO
    // ─────────────────────────────────────────────────────────────────────────
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (context) => _buildProgrammaticPageLayout(
          pageTitle: 'ITENS DA USINA & PAGAMENTO',
          pageNumber: 4,
          totalPages: 6,
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
    // PÁGINA 5: ANÁLISE DE INVESTIMENTO & TABELA DE 20 ANOS
    // ─────────────────────────────────────────────────────────────────────────
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (context) => _buildProgrammaticPageLayout(
          pageTitle: 'ANÁLISE DE INVESTIMENTO',
          pageNumber: 5,
          totalPages: 6,
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
    // PÁGINA 6: FINANCIAMENTO BANCÁRIO & CARTÃO DE CRÉDITO
    // ─────────────────────────────────────────────────────────────────────────
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (context) => _buildProgrammaticPageLayout(
          pageTitle: 'FINANCIAMENTO & CONDIÇÕES',
          pageNumber: 6,
          totalPages: 6,
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
  static pw.Widget _buildCoverPage({
    required Uint8List? coverBytes,
    required ProposalModel proposal,
    required SolarSettingsModel settings,
    required double generationMonthly,
    required double kwp,
    required PdfColor primaryColor,
  }) {
    // Dimensões A4 em pontos (595.28 x 841.89)
    const a4W = 595.28;
    const a4H = 841.89;

    final badgeLeft = (a4W * settings.coverBadgePositionX).clamp(16.0, 360.0);
    final badgeTop = (a4H * settings.coverBadgePositionY).clamp(16.0, 480.0);

    final rawColor = PdfColor.fromInt(settings.coverBadgeColorValue);
    final badgeBgColor = PdfColor(rawColor.red, rawColor.green, rawColor.blue, settings.coverBadgeOpacity);

    return pw.Stack(
      fit: pw.StackFit.expand,
      children: [
        // Imagem de Fundo da Capa (com separador e rodapé 100% branco)
        if (coverBytes != null)
          pw.Image(pw.MemoryImage(coverBytes), fit: pw.BoxFit.cover)
        else
          pw.Container(
            color: PdfColors.white,
          ),

        // Retângulo e Título Customizável Posicionado pelo Usuário
        pw.Positioned(
          left: badgeLeft,
          top: badgeTop,
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: settings.coverShowBadge
                ? pw.BoxDecoration(
                    color: badgeBgColor,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
                    border: pw.Border.all(color: PdfColors.white, width: 1.5),
                  )
                : null,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Text(
                  settings.coverTitle.isNotEmpty ? settings.coverTitle : 'PROPOSTA COMERCIAL',
                  style: pw.TextStyle(
                    fontSize: settings.coverTitleFontSize,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromInt(settings.coverTitleColorValue),
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  settings.coverSubtitle.isNotEmpty ? settings.coverSubtitle : 'ENERGIA SOLAR FOTOVOLTAICA',
                  style: pw.TextStyle(
                    fontSize: settings.coverSubtitleFontSize,
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
                        decoration: pw.BoxDecoration(shape: pw.BoxShape.circle, color: PdfColor.fromHex('#94A3B8')),
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
                    settings.companyName?.isNotEmpty == true ? settings.companyName! : 'EMPRESA INTEGRADORA',
                    style: pw.TextStyle(fontSize: 12.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A')),
                  ),
                  if (settings.companyDocument?.isNotEmpty == true)
                    pw.Text(
                      'CNPJ: ${settings.companyDocument!}',
                      style: pw.TextStyle(fontSize: 9.5, color: PdfColor.fromHex('#475569')),
                    ),
                  if (settings.companyPhone?.isNotEmpty == true)
                    pw.Text(
                      'WhatsApp: ${settings.companyPhone!}',
                      style: pw.TextStyle(fontSize: 9.5, color: PdfColor.fromHex('#475569')),
                    ),
                  if (settings.companyWebsite?.isNotEmpty == true)
                    pw.Text(
                      settings.companyWebsite!,
                      style: pw.TextStyle(fontSize: 9.5, color: PdfColor.fromHex('#475569')),
                    ),
                  if (settings.companyInstagram?.isNotEmpty == true)
                    pw.Text(
                      settings.companyInstagram!,
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

