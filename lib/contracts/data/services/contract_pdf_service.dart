import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../settings/domain/models/company_model.dart';
import '../../domain/models/contract_model.dart';

/// Serviço de Geração e Impressão de PDF para Contratos Fotovoltaicos
class ContractPdfService {
  /// Gera o arquivo PDF formatado do contrato
  static Future<Uint8List> generatePdf({
    required ContractModel contract,
    CompanyModel? company,
  }) async {
    final pdf = pw.Document();

    // Carrega fontes padrão seguras
    final fontRegular = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();
    final fontItalic = await PdfGoogleFonts.interItalic();

    // Imagem da Logo da Empresa se existir
    pw.MemoryImage? companyLogo;
    if (company?.logoBase64 != null && company!.logoBase64!.isNotEmpty) {
      try {
        final cleanBase64 = company.logoBase64!.contains(',')
            ? company.logoBase64!.split(',').last
            : company.logoBase64!;
        companyLogo = pw.MemoryImage(base64Decode(cleanBase64));
      } catch (e) {
        debugPrint('Erro ao decodificar logo da empresa: $e');
      }
    }

    // Processa os blocos de texto do contrato
    final blocks = _parseMarkdownContent(contract.content);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 36),
        theme: pw.ThemeData.withFont(
          base: fontRegular,
          bold: fontBold,
          italic: fontItalic,
        ),
        header: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 12),
            margin: const pw.EdgeInsets.only(bottom: 14),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColor.fromInt(0xFFCBD5E1), width: 0.8),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Row(
                  children: [
                    if (companyLogo != null) ...[
                      pw.Image(companyLogo, width: 36, height: 36, fit: pw.BoxFit.contain),
                      pw.SizedBox(width: 10),
                    ],
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          company?.name.toUpperCase() ?? 'CONTRATO DE PRESTAÇÃO DE SERVIÇOS',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: const PdfColor.fromInt(0xFF1E293B),
                          ),
                        ),
                        if (company?.document != null)
                          pw.Text(
                            'CNPJ: ${company!.document}',
                            style: const pw.TextStyle(
                              fontSize: 7.5,
                              color: PdfColor.fromInt(0xFF64748B),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: const PdfColor.fromInt(0xFFF1F5F9),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    border: pw.Border.all(color: const PdfColor.fromInt(0xFFE2E8F0)),
                  ),
                  child: pw.Text(
                    contract.contractNumber,
                    style: pw.TextStyle(
                      fontSize: 8.5,
                      fontWeight: pw.FontWeight.bold,
                      color: const PdfColor.fromInt(0xFF475569),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(top: 10),
            margin: const pw.EdgeInsets.only(top: 14),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(color: PdfColor.fromInt(0xFFE2E8F0), width: 0.8),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  '${contract.title} • Proposta: ${contract.proposalNumber}',
                  style: const pw.TextStyle(fontSize: 7.5, color: PdfColor.fromInt(0xFF94A3B8)),
                ),
                pw.Text(
                  'Página ${context.pageNumber} de ${context.pagesCount}',
                  style: pw.TextStyle(
                    fontSize: 7.5,
                    fontWeight: pw.FontWeight.bold,
                    color: const PdfColor.fromInt(0xFF64748B),
                  ),
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          return blocks.map((block) => block.buildPdfWidget()).toList();
        },
      ),
    );

    return pdf.save();
  }

  /// Imprime o contrato diretamente na impressora do sistema
  static Future<void> printContract({
    required ContractModel contract,
    CompanyModel? company,
  }) async {
    final pdfBytes = await generatePdf(contract: contract, company: company);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: '${contract.contractNumber}_${contract.clientName.replaceAll(" ", "_")}.pdf',
    );
  }

  /// Compartilha ou baixa o PDF
  static Future<void> sharePdf({
    required ContractModel contract,
    CompanyModel? company,
  }) async {
    final pdfBytes = await generatePdf(contract: contract, company: company);
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: '${contract.contractNumber}_${contract.clientName.replaceAll(" ", "_")}.pdf',
    );
  }

  /// Parser simplificado de Markdown para elementos PDF
  static List<_PdfBlock> _parseMarkdownContent(String content) {
    final lines = content.split('\n');
    final blocks = <_PdfBlock>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      if (line.isEmpty) {
        blocks.add(_PdfBlock(type: _PdfBlockType.spacer, text: ''));
      } else if (line.startsWith('# ')) {
        blocks.add(_PdfBlock(type: _PdfBlockType.h1, text: line.substring(2).trim()));
      } else if (line.startsWith('## ')) {
        blocks.add(_PdfBlock(type: _PdfBlockType.h2, text: line.substring(3).trim()));
      } else if (line.startsWith('### ')) {
        blocks.add(_PdfBlock(type: _PdfBlockType.h3, text: line.substring(4).trim()));
      } else if (line == '---' || line == '***') {
        blocks.add(_PdfBlock(type: _PdfBlockType.divider, text: ''));
      } else if (line.startsWith('- ') || line.startsWith('• ') || line.startsWith('* ')) {
        blocks.add(_PdfBlock(type: _PdfBlockType.bullet, text: line.substring(2).trim()));
      } else {
        blocks.add(_PdfBlock(type: _PdfBlockType.paragraph, text: line));
      }
    }

    return blocks;
  }
}

enum _PdfBlockType { h1, h2, h3, paragraph, bullet, divider, spacer }

class _PdfBlock {
  final _PdfBlockType type;
  final String text;

  const _PdfBlock({required this.type, required this.text});

  pw.Widget buildPdfWidget() {
    switch (type) {
      case _PdfBlockType.h1:
        return pw.Padding(
          padding: const pw.EdgeInsets.only(top: 10, bottom: 8),
          child: pw.Center(
            child: pw.Text(
              _cleanMarkdown(text),
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: const PdfColor.fromInt(0xFF0F172A),
                decoration: pw.TextDecoration.underline,
              ),
            ),
          ),
        );
      case _PdfBlockType.h2:
        return pw.Padding(
          padding: const pw.EdgeInsets.only(top: 10, bottom: 6),
          child: pw.Text(
            _cleanMarkdown(text),
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: const PdfColor.fromInt(0xFF1E293B),
            ),
          ),
        );
      case _PdfBlockType.h3:
        return pw.Padding(
          padding: const pw.EdgeInsets.only(top: 8, bottom: 4),
          child: pw.Text(
            _cleanMarkdown(text),
            style: pw.TextStyle(
              fontSize: 9.5,
              fontWeight: pw.FontWeight.bold,
              color: const PdfColor.fromInt(0xFF334155),
            ),
          ),
        );
      case _PdfBlockType.divider:
        return pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 6),
          child: pw.Divider(color: const PdfColor.fromInt(0xFFCBD5E1), thickness: 0.6),
        );
      case _PdfBlockType.spacer:
        return pw.SizedBox(height: 4);
      case _PdfBlockType.bullet:
        return pw.Padding(
          padding: const pw.EdgeInsets.only(left: 12, bottom: 3),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('• ', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
              pw.Expanded(
                child: _buildRichText(text, fontSize: 8.5),
              ),
            ],
          ),
        );
      case _PdfBlockType.paragraph:
        // Linhas de assinatura com traços
        if (text.startsWith('_____')) {
          return pw.Padding(
            padding: const pw.EdgeInsets.only(top: 16, bottom: 4),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: 250,
                  height: 0.8,
                  color: const PdfColor.fromInt(0xFF0F172A),
                ),
              ],
            ),
          );
        }
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 5),
          child: _buildRichText(text, fontSize: 8.5),
        );
    }
  }

  pw.Widget _buildRichText(String rawText, {double fontSize = 8.5}) {
    final spans = <pw.TextSpan>[];
    final regex = RegExp(r'(\*\*.*?\*\*|\*.*?\*)');
    int lastEnd = 0;

    for (final match in regex.allMatches(rawText)) {
      if (match.start > lastEnd) {
        spans.add(pw.TextSpan(text: rawText.substring(lastEnd, match.start)));
      }

      final matchedText = match.group(0)!;
      if (matchedText.startsWith('**') && matchedText.endsWith('**')) {
        spans.add(
          pw.TextSpan(
            text: matchedText.substring(2, matchedText.length - 2),
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        );
      } else if (matchedText.startsWith('*') && matchedText.endsWith('*')) {
        spans.add(
          pw.TextSpan(
            text: matchedText.substring(1, matchedText.length - 1),
            style: pw.TextStyle(fontStyle: pw.FontStyle.italic),
          ),
        );
      }
      lastEnd = match.end;
    }

    if (lastEnd < rawText.length) {
      spans.add(pw.TextSpan(text: rawText.substring(lastEnd)));
    }

    return pw.RichText(
      textAlign: pw.TextAlign.justify,
      text: pw.TextSpan(
        style: pw.TextStyle(
          fontSize: fontSize,
          color: const PdfColor.fromInt(0xFF1E293B),
          lineSpacing: 2.0,
        ),
        children: spans.isEmpty ? [pw.TextSpan(text: rawText)] : spans,
      ),
    );
  }

  String _cleanMarkdown(String text) {
    return text.replaceAll('**', '').replaceAll('*', '').replaceAll('__', '');
  }
}
