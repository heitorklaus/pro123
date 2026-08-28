import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../domain/models/proposal_item_model.dart';
import '../../domain/models/proposal_model.dart';

/// Serviço especializado na geração e renderização vetorial de PDFs para Propostas Comerciais
class ProposalPdfService {
  static final _currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  static final _dateFormat = DateFormat('dd/MM/yyyy');

  /// Gera o arquivo PDF binário (Uint8List) a partir do modelo da proposta
  static Future<Uint8List> generateProposalPdf(ProposalModel proposal) async {
    final pdf = pw.Document();

    // Paleta de Cores Dinâmica
    final primaryColor = PdfColor.fromInt(proposal.themeColorValue);
    final primaryLight = PdfColor(
      primaryColor.red,
      primaryColor.green,
      primaryColor.blue,
      0.08,
    );
    final textDark = PdfColor.fromHex('#0F172A');
    final textMuted = PdfColor.fromHex('#64748B');
    final borderCol = PdfColor.fromHex('#E2E8F0');
    final zebraBg = PdfColor.fromHex('#F8FAFC');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          // ── 1. CABEÇALHO DO DOCUMENTO ────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: primaryLight,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
              border: pw.Border.all(color: primaryColor, width: 1),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      children: [
                        pw.Container(
                          width: 28,
                          height: 28,
                          decoration: pw.BoxDecoration(
                            color: primaryColor,
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                          ),
                          child: pw.Center(
                            child: pw.Text(
                              'M',
                              style: pw.TextStyle(
                                color: PdfColors.white,
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        pw.SizedBox(width: 10),
                        pw.Text(
                          'Mavis CRM',
                          style: pw.TextStyle(
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Soluções Comerciais & Gestão Empresarial',
                      style: pw.TextStyle(fontSize: 10, color: textMuted),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: pw.BoxDecoration(
                        color: primaryColor,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                      ),
                      child: pw.Text(
                        'PROPOSTA COMERCIAL',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      proposal.proposalNumber,
                      style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                        color: textDark,
                      ),
                    ),
                    pw.Text(
                      'Emissão: ${_dateFormat.format(proposal.createdAt)}  |  Validade: ${_dateFormat.format(proposal.expirationDate)}',
                      style: pw.TextStyle(fontSize: 9, color: textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 18),

          // ── 2. DADOS DO CLIENTE & EMISSOR ────────────────────────────────
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Coluna Cliente / Destinatário
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: borderCol),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'DADOS DO CLIENTE / DESTINATÁRIO',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        proposal.clientName,
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: textDark,
                        ),
                      ),
                      if (proposal.clientDocument != null && proposal.clientDocument!.isNotEmpty)
                        pw.Text('Doc/CNPJ: ${proposal.clientDocument}', style: pw.TextStyle(fontSize: 9.5, color: textDark)),
                      if (proposal.clientEmail != null && proposal.clientEmail!.isNotEmpty)
                        pw.Text('E-mail: ${proposal.clientEmail}', style: pw.TextStyle(fontSize: 9.5, color: textDark)),
                      if (proposal.clientPhone != null && proposal.clientPhone!.isNotEmpty)
                        pw.Text('Telefone: ${proposal.clientPhone}', style: pw.TextStyle(fontSize: 9.5, color: textDark)),
                      if (proposal.clientAddress != null && proposal.clientAddress!.isNotEmpty)
                        pw.Text('Endereço: ${proposal.clientAddress}', style: pw.TextStyle(fontSize: 9.5, color: textDark)),
                    ],
                  ),
                ),
              ),

              pw.SizedBox(width: 14),

              // Coluna Detalhes da Proposta
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: borderCol),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'INFORMAÇÕES DA PROPOSTA',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        proposal.title,
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: textDark,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text('Condição: ${proposal.paymentTerms}', style: pw.TextStyle(fontSize: 9.5, color: textDark)),
                      pw.Text('Prazo de Validade: ${proposal.validityDays} dias corridos', style: pw.TextStyle(fontSize: 9.5, color: textDark)),
                      if (proposal.deliveryTime != null && proposal.deliveryTime!.isNotEmpty)
                        pw.Text('Prazo de Entrega: ${proposal.deliveryTime}', style: pw.TextStyle(fontSize: 9.5, color: textDark)),
                    ],
                  ),
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 18),

          // ── 3. TABELA DE ITENS / PRODUTOS ─────────────────────────────────
          pw.Text(
            'ITENS & SERVIÇOS INCLUÍDOS',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: primaryColor,
            ),
          ),
          pw.SizedBox(height: 6),

          pw.Table(
            border: pw.TableBorder.all(color: borderCol, width: 0.5),
            columnWidths: const {
              0: pw.FixedColumnWidth(26), // #
              1: pw.FlexColumnWidth(5),   // Descrição
              2: pw.FixedColumnWidth(42), // Unidade
              3: pw.FixedColumnWidth(42), // Qtd
              4: pw.FixedColumnWidth(75), // Preço Unit
              5: pw.FixedColumnWidth(45), // Desc %
              6: pw.FixedColumnWidth(80), // Total
            },
            children: [
              // Cabeçalho da Tabela
              pw.TableRow(
                decoration: pw.BoxDecoration(color: primaryColor),
                children: [
                  _headerCell('#'),
                  _headerCell('ITEM / DESCRIÇÃO'),
                  _headerCell('UNID', align: pw.TextAlign.center),
                  _headerCell('QTD', align: pw.TextAlign.center),
                  _headerCell('UNITÁRIO', align: pw.TextAlign.right),
                  _headerCell('DESC', align: pw.TextAlign.center),
                  _headerCell('TOTAL', align: pw.TextAlign.right),
                ],
              ),

              // Linhas de Produtos
              ...proposal.items.asMap().entries.map((entry) {
                final idx = entry.key + 1;
                final item = entry.value;
                final isZebra = idx % 2 == 0;

                return pw.TableRow(
                  decoration: pw.BoxDecoration(color: isZebra ? zebraBg : PdfColors.white),
                  children: [
                    _dataCell('$idx', align: pw.TextAlign.center),
                    _descriptionDataCell(
                      item,
                      textDark: textDark,
                      textMuted: textMuted,
                      primaryColor: primaryColor,
                    ),
                    _dataCell(item.unit, align: pw.TextAlign.center),
                    _dataCell(
                      item.quantity % 1 == 0
                          ? item.quantity.toInt().toString()
                          : item.quantity.toStringAsFixed(2),
                      align: pw.TextAlign.center,
                    ),
                    _dataCell(_currencyFormat.format(item.unitPrice), align: pw.TextAlign.right),
                    _dataCell(
                      item.discountPercent > 0 ? '${item.discountPercent.toStringAsFixed(0)}%' : '-',
                      align: pw.TextAlign.center,
                      textColor: item.discountPercent > 0 ? PdfColor.fromHex('#059669') : textMuted,
                    ),
                    _dataCell(
                      _currencyFormat.format(item.totalPrice),
                      align: pw.TextAlign.right,
                      isBold: true,
                    ),
                  ],
                );
              }),
            ],
          ),

          pw.SizedBox(height: 16),

          // ── 4. RESUMO FINANCEIRO & OBSERVAÇÕES ─────────────────────────────
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Observações e Termos
              pw.Expanded(
                flex: 3,
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: zebraBg,
                    border: pw.Border.all(color: borderCol),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'OBSERVAÇÕES & TERMOS DE FORNECIMENTO',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: textDark,
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      ...((proposal.notes?.isNotEmpty == true
                              ? proposal.notes!
                              : 'Proposta válida mediante confirmação dos itens em estoque.\nValores expressos em Reais (BRL) com todos os tributos inclusos.\nGarantia conforme termo e legislação vigente.')
                          .split('\n')
                          .where((l) => l.trim().isNotEmpty)
                          .map((line) {
                            final cleanLine = line.replaceAll('•', '').trim();
                            return pw.Padding(
                              padding: const pw.EdgeInsets.only(bottom: 3.5),
                              child: pw.Row(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Container(
                                    margin: const pw.EdgeInsets.only(top: 3.5, right: 5),
                                    width: 3.5,
                                    height: 3.5,
                                    decoration: pw.BoxDecoration(
                                      color: primaryColor,
                                      shape: pw.BoxShape.circle,
                                    ),
                                  ),
                                  pw.Expanded(
                                    child: pw.Text(
                                      cleanLine,
                                      style: pw.TextStyle(fontSize: 8, color: textDark, lineSpacing: 1.2),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          })),
                    ],
                  ),
                ),
              ),

              pw.SizedBox(width: 14),

              // Totalizadores
              pw.Expanded(
                flex: 2,
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: borderCol),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: pw.Column(
                    children: [
                      _summaryRow('Subtotal dos Itens:', _currencyFormat.format(proposal.subtotal), textDark),
                      if (proposal.discount > 0)
                        _summaryRow('Desconto:', '- ${_currencyFormat.format(proposal.discount)}', PdfColor.fromHex('#059669')),
                      if (proposal.shippingFee > 0)
                        _summaryRow('Frete / Entrega:', '+ ${_currencyFormat.format(proposal.shippingFee)}', textDark),
                      pw.Divider(color: borderCol, thickness: 0.8),
                      pw.SizedBox(height: 4),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: pw.BoxDecoration(
                          color: primaryColor,
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                        ),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'TOTAL:',
                              style: pw.TextStyle(
                                color: PdfColors.white,
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                            pw.Text(
                              _currencyFormat.format(proposal.totalAmount),
                              style: pw.TextStyle(
                                color: PdfColors.white,
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 13,
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

          pw.SizedBox(height: 36),

          // ── 5. ASSINATURAS & ACEITE ───────────────────────────────────────
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Column(
                  children: [
                    pw.Container(height: 1, color: textDark),
                    pw.SizedBox(height: 4),
                    pw.Text('Responsável Comercial / Emissor', style: pw.TextStyle(fontSize: 9, color: textDark, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Mavis CRM', style: pw.TextStyle(fontSize: 8, color: textMuted)),
                  ],
                ),
              ),
              pw.SizedBox(width: 40),
              pw.Expanded(
                child: pw.Column(
                  children: [
                    pw.Container(height: 1, color: textDark),
                    pw.SizedBox(height: 4),
                    pw.Text('Aceite do Cliente / Comprador', style: pw.TextStyle(fontSize: 9, color: textDark, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Data: ____ / ____ / ________', style: pw.TextStyle(fontSize: 8, color: textMuted)),
                  ],
                ),
              ),
            ],
          ),
        ],
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 10),
          child: pw.Text(
            'Página ${context.pageNumber} de ${context.pagesCount}  |  Mavis CRM Propostas',
            style: pw.TextStyle(color: textMuted, fontSize: 8),
          ),
        ),
      ),
    );

    return pdf.save();
  }

  static pw.Widget _headerCell(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontSize: 8.5,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  static pw.Widget _dataCell(
    String text, {
    pw.TextAlign align = pw.TextAlign.left,
    bool isBold = false,
    PdfColor? textColor,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 8.5,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: textColor ?? PdfColor.fromHex('#0F172A'),
        ),
      ),
    );
  }

  static pw.Widget _descriptionDataCell(
    ProposalItemModel item, {
    required PdfColor textDark,
    required PdfColor textMuted,
    required PdfColor primaryColor,
  }) {
    if (!item.isSolarPlant) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: pw.Text(
          item.name + (item.sku != null && item.sku!.isNotEmpty ? ' (${item.sku})' : ''),
          style: pw.TextStyle(
            fontSize: 8.5,
            fontWeight: pw.FontWeight.bold,
            color: textDark,
          ),
        ),
      );
    }

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#FEF3C7'),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                ),
                child: pw.Text(
                  'USINA SOLAR',
                  style: pw.TextStyle(
                    fontSize: 6.5,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#92400E'),
                  ),
                ),
              ),
              if (item.solarKilowatts != null && item.solarKilowatts! > 0) ...[
                pw.SizedBox(width: 4),
                pw.Text(
                  '${item.solarKilowatts!.toStringAsFixed(1)} kWp',
                  style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: textDark),
                ),
              ],
              if (item.solarRoofType != null && item.solarRoofType!.isNotEmpty) ...[
                pw.SizedBox(width: 4),
                pw.Text(
                  '| Telhado: ${item.solarRoofType}',
                  style: pw.TextStyle(fontSize: 7.5, color: textMuted),
                ),
              ],
            ],
          ),
          pw.SizedBox(height: 2.5),
          pw.Text(
            item.name,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: textDark,
            ),
          ),
          if (item.solarComponents != null && item.solarComponents!.isNotEmpty) ...[
            pw.SizedBox(height: 3),
            pw.Container(
              padding: const pw.EdgeInsets.all(4),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#FFFBEB'),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Composição do Conjunto da Usina:',
                    style: pw.TextStyle(
                      fontSize: 6.5,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#92400E'),
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  ...item.solarComponents!.map(
                    (comp) => pw.Padding(
                      padding: const pw.EdgeInsets.only(left: 3, bottom: 2),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Container(
                            width: 3,
                            height: 3,
                            decoration: pw.BoxDecoration(
                              color: PdfColor.fromHex('#D97706'),
                              shape: pw.BoxShape.circle,
                            ),
                          ),
                          pw.SizedBox(width: 4),
                          pw.Expanded(
                            child: pw.Text(
                              comp,
                              style: pw.TextStyle(
                                fontSize: 7.5,
                                color: PdfColor.fromHex('#451A03'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _summaryRow(String label, String value, PdfColor valueColor) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#64748B'))),
          pw.Text(value, style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: valueColor)),
        ],
      ),
    );
  }
}
