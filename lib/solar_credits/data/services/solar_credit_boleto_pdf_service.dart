import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../domain/models/solar_credit_models.dart';

/// Serviço de Geração do PDF do Demonstrativo / Boleto de Créditos de Energia Solar (Padrão Solar 7)
class SolarCreditBoletoPdfService {
  static final _currencyFmt =
      NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  static final _numFmt = NumberFormat('#,##0', 'pt_BR');
  static final _decFmt = NumberFormat('#,##0.00', 'pt_BR');

  static Future<Uint8List> generateBoletoPdf({
    required SolarCreditBillModel bill,
    String? customCompanyName,
    String? customCompanyDoc,
    String? customCompanyAddress,
    String? customCompanyWebsite,
    String? customCompanyLogoBase64,
  }) async {
    final doc = pw.Document(
      title: 'Demonstrativo Solar - UC ${bill.ucNumber} - ${bill.referenceMonth}',
      author: customCompanyName ?? 'SOLAR 7 ENERGIA E TECNOLOGIA LTDA',
    );

    // Dados oficiais da Solar 7 Energia e Tecnologia Ltda
    final String companyName =
        customCompanyName ?? 'SOLAR 7 ENERGIA E TECNOLOGIA LTDA';
    final String companyDoc = customCompanyDoc ?? '42.117.511/0001-38';
    final String companyAddress =
        customCompanyAddress ?? 'AV ISAAC POVOAS SALA 201 EDIFICIO WALL STREET';
    final String companyWebsite = customCompanyWebsite ?? 'www.solar7.com.br';
    final String? logoBase64 = customCompanyLogoBase64;

    // Nome curto da marca (ex: "Solar 7")
    final shortBrand = companyName.toUpperCase().contains('SOLAR 7')
        ? 'Solar 7'
        : (companyName.split(' ').take(2).join(' '));

    pw.MemoryImage? companyLogoImg;
    if (logoBase64 != null && logoBase64.isNotEmpty) {
      try {
        final clean = logoBase64.contains(',')
            ? logoBase64.split(',').last
            : logoBase64;
        companyLogoImg = pw.MemoryImage(base64Decode(clean));
      } catch (_) {}
    }

    // Carrega a logo oficial da Solar 7 dos assets (c:\mavis\assets\images\solar7_logo.png)
    if (companyLogoImg == null) {
      try {
        final byteData = await rootBundle.load('assets/images/solar7_logo.png');
        companyLogoImg = pw.MemoryImage(byteData.buffer.asUint8List());
      } catch (_) {}
    }

    pw.MemoryImage? qrCodeImg;
    if (bill.qrCodeImageBase64 != null &&
        bill.qrCodeImageBase64!.trim().isNotEmpty) {
      try {
        final clean = bill.qrCodeImageBase64!.contains(',')
            ? bill.qrCodeImageBase64!.split(',').last
            : bill.qrCodeImageBase64!;
        qrCodeImg = pw.MemoryImage(base64Decode(clean));
      } catch (_) {}
    }

    final hasQrImage = qrCodeImg != null;
    final hasPixCode =
        bill.pixCopyPasteCode != null && bill.pixCopyPasteCode!.trim().isNotEmpty;
    final hasPaymentLink =
        bill.paymentLinkUrl != null && bill.paymentLinkUrl!.trim().isNotEmpty;
    final hasAnyPaymentInfo = hasQrImage || hasPixCode || hasPaymentLink;

    final fontRegular = await PdfGoogleFonts.interRegular();
    final fontMedium = await PdfGoogleFonts.interMedium();
    final fontSemiBold = await PdfGoogleFonts.interSemiBold();
    final fontBold = await PdfGoogleFonts.interBold();

    const primaryBlue = PdfColor.fromInt(0xFF0088CC);
    const darkBlue = PdfColor.fromInt(0xFF0369A1);
    const lightBlueBg = PdfColor.fromInt(0xFFF0F9FF);
    const slateDark = PdfColor.fromInt(0xFF0F172A);
    const slateMuted = PdfColor.fromInt(0xFF475569);
    const borderGrey = PdfColor.fromInt(0xFFCBD5E1);
    const emeraldGreen = PdfColor.fromInt(0xFF059669);

    final cleanUc = bill.ucNumber.replaceAll(RegExp(r'[^0-9]'), '').isNotEmpty
        ? bill.ucNumber
        : bill.ucNumber;

    final displayAddressOrClient = bill.addressStreet.trim().isNotEmpty
        ? bill.addressStreet.trim().toUpperCase()
        : bill.clientName.trim().toUpperCase();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        theme: pw.ThemeData.withFont(
          base: fontRegular,
          bold: fontBold,
        ),
        build: (context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              border: pw.Border.all(color: slateDark, width: 1.5),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // ─────────────────────────────────────────────────────────────
                // 1. CABEÇALHO INSTITUCIONAL AZUL (PADRÃO SOLAR 7)
                // ─────────────────────────────────────────────────────────────
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  decoration: const pw.BoxDecoration(
                    gradient: pw.LinearGradient(
                      colors: [primaryBlue, darkBlue],
                      begin: pw.Alignment.topLeft,
                      end: pw.Alignment.bottomRight,
                    ),
                    borderRadius: pw.BorderRadius.only(
                      topLeft: pw.Radius.circular(4.5),
                      topRight: pw.Radius.circular(4.5),
                    ),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              companyName,
                              style: pw.TextStyle(
                                font: fontBold,
                                fontSize: 20,
                                color: PdfColors.white,
                                letterSpacing: 0.4,
                              ),
                            ),
                            pw.SizedBox(height: 5),
                            pw.Text(
                              companyDoc,
                              style: pw.TextStyle(
                                font: fontMedium,
                                fontSize: 13.5,
                                color: const PdfColor.fromInt(0xFFE0F2FE),
                              ),
                            ),
                            pw.SizedBox(height: 3),
                            pw.Text(
                              companyAddress,
                              style: pw.TextStyle(
                                font: fontSemiBold,
                                fontSize: 10.5,
                                color: PdfColors.white,
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              companyWebsite,
                              style: pw.TextStyle(
                                font: fontBold,
                                fontSize: 13,
                                color: PdfColors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (companyLogoImg != null)
                        pw.Container(
                          width: 96,
                          height: 82,
                          padding: const pw.EdgeInsets.all(6),
                          decoration: const pw.BoxDecoration(
                            color: PdfColors.white,
                            borderRadius: pw.BorderRadius.all(
                              pw.Radius.circular(10),
                            ),
                          ),
                          alignment: pw.Alignment.center,
                          child: pw.Image(
                            companyLogoImg,
                            fit: pw.BoxFit.contain,
                          ),
                        )
                      else
                        // Emblema estilizado Solar 7
                        pw.Container(
                          width: 78,
                          height: 78,
                          decoration: pw.BoxDecoration(
                            color: PdfColors.white.shade(0.12),
                            borderRadius: const pw.BorderRadius.all(
                              pw.Radius.circular(14),
                            ),
                            border: pw.Border.all(
                              color: PdfColors.white,
                              width: 2,
                            ),
                          ),
                          alignment: pw.Alignment.center,
                          child: pw.Text(
                            'S7',
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 34,
                              color: PdfColors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // ─────────────────────────────────────────────────────────────
                // 2. FAIXA DE VENCIMENTO, REFERÊNCIA E CLIENTE
                // ─────────────────────────────────────────────────────────────
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 10,
                  ),
                  decoration: const pw.BoxDecoration(
                    color: lightBlueBg,
                    border: pw.Border(
                      top: pw.BorderSide(color: primaryBlue, width: 1),
                      bottom: pw.BorderSide(color: primaryBlue, width: 1.8),
                    ),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Row(
                        children: [
                          pw.Text(
                            'VENCIMENTO:  ',
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 13,
                              color: slateDark,
                            ),
                          ),
                          pw.Text(
                            bill.dueDate.isNotEmpty ? bill.dueDate : 'A definir',
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 14,
                              color: primaryBlue,
                            ),
                          ),
                        ],
                      ),
                      pw.Row(
                        children: [
                          pw.Text(
                            'CLIENTE:  ',
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 12,
                              color: slateMuted,
                            ),
                          ),
                          pw.Text(
                            bill.clientName.toUpperCase(),
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 12.5,
                              color: slateDark,
                            ),
                          ),
                        ],
                      ),
                      pw.Row(
                        children: [
                          pw.Text(
                            'REFERÊNCIA:  ',
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 13,
                              color: slateDark,
                            ),
                          ),
                          pw.Text(
                            bill.referenceMonth.toUpperCase(),
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 14,
                              color: primaryBlue,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ─────────────────────────────────────────────────────────────
                // 3. BLOCO DE DADOS DA UC E ENERGIA (CONSUMO vs INJETADA)
                // ─────────────────────────────────────────────────────────────
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(color: slateDark, width: 1.8),
                    ),
                  ),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      // Coluna Esquerda: Olá, Endereço, UC, Consumo e Injetada
                      pw.Expanded(
                        flex: 6,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Row(
                              children: [
                                pw.SizedBox(
                                  width: 245,
                                  child: pw.Text(
                                    'Olá,',
                                    style: pw.TextStyle(
                                      font: fontMedium,
                                      fontSize: 13,
                                      color: slateDark,
                                    ),
                                  ),
                                ),
                                pw.Expanded(
                                  child: pw.Text(
                                    displayAddressOrClient,
                                    style: pw.TextStyle(
                                      font: fontBold,
                                      fontSize: 12.5,
                                      color: slateDark,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            pw.SizedBox(height: 5),
                            pw.Row(
                              children: [
                                pw.SizedBox(
                                  width: 245,
                                  child: pw.Text(
                                    'Segue o demonstrativo da UC:',
                                    style: pw.TextStyle(
                                      font: fontMedium,
                                      fontSize: 13,
                                      color: slateDark,
                                    ),
                                  ),
                                ),
                                pw.Expanded(
                                  child: pw.Text(
                                    cleanUc,
                                    style: pw.TextStyle(
                                      font: fontBold,
                                      fontSize: 13,
                                      color: slateDark,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            pw.SizedBox(height: 8),
                            pw.Row(
                              children: [
                                pw.SizedBox(
                                  width: 245,
                                  child: pw.Text(
                                    'Seu consumo total foi:',
                                    style: pw.TextStyle(
                                      font: fontMedium,
                                      fontSize: 13.5,
                                      color: slateDark,
                                    ),
                                  ),
                                ),
                                pw.Text(
                                  '${_numFmt.format(bill.consumptionKwh)} Kilowatts',
                                  style: pw.TextStyle(
                                    font: fontBold,
                                    fontSize: 14,
                                    color: slateDark,
                                  ),
                                ),
                              ],
                            ),
                            pw.SizedBox(height: 5),
                            pw.Row(
                              children: [
                                pw.SizedBox(
                                  width: 245,
                                  child: pw.Text(
                                    'A energia injetada pela $shortBrand foi:',
                                    style: pw.TextStyle(
                                      font: fontMedium,
                                      fontSize: 13.5,
                                      color: slateDark,
                                    ),
                                  ),
                                ),
                                pw.Text(
                                  '${_numFmt.format(bill.totalInjectedKwh)} Kilowatts',
                                  style: pw.TextStyle(
                                    font: fontBold,
                                    fontSize: 14,
                                    color: primaryBlue,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Coluna Direita: Resumo técnico de transparência (Saldo / Regime / Desconto)
                      pw.Expanded(
                        flex: 4,
                        child: pw.Container(
                          padding: const pw.EdgeInsets.all(10),
                          decoration: pw.BoxDecoration(
                            color: const PdfColor.fromInt(0xFFF8FAFC),
                            borderRadius: const pw.BorderRadius.all(
                              pw.Radius.circular(8),
                            ),
                            border: pw.Border.all(color: borderGrey, width: 0.8),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'DETALHAMENTO DOS CRÉDITOS SOLARES',
                                style: pw.TextStyle(
                                  font: fontBold,
                                  fontSize: 8.5,
                                  color: primaryBlue,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              pw.SizedBox(height: 4),
                              if (bill.injectedGdiKwh > 0)
                                _buildMiniDetailRow(
                                  fontRegular,
                                  fontBold,
                                  'Injetada GD I:',
                                  '${_numFmt.format(bill.injectedGdiKwh)} kWh (${_currencyFmt.format(bill.injectedGdiValueRs)})',
                                ),
                              if (bill.injectedGdiiKwh > 0)
                                _buildMiniDetailRow(
                                  fontRegular,
                                  fontBold,
                                  'Injetada GD II:',
                                  '${_numFmt.format(bill.injectedGdiiKwh)} kWh (${_currencyFmt.format(bill.injectedGdiiValueRs)})',
                                ),
                              if (bill.gdAdjustmentValueRs > 0)
                                _buildMiniDetailRow(
                                  fontRegular,
                                  fontBold,
                                  'Ajuste GD II (Lei 14.300):',
                                  '- ${_currencyFmt.format(bill.gdAdjustmentValueRs)}',
                                ),
                              _buildMiniDetailRow(
                                fontRegular,
                                fontBold,
                                'Saldo Acumulado na UC:',
                                '${_numFmt.format(bill.accumulatedBalanceKwh)} kWh',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ─────────────────────────────────────────────────────────────
                // 4. CORPO CENTRAL: FINANCEIRO (ESQUERDA) + PAGAMENTO/QR CODE (DIREITA)
                // ─────────────────────────────────────────────────────────────
                pw.Expanded(
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      // COLUNA ESQUERDA: COMPARATIVO DE VALORES
                      pw.Expanded(
                        flex: 62,
                        child: pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 14,
                          ),
                          decoration: const pw.BoxDecoration(
                            border: pw.Border(
                              right: pw.BorderSide(color: slateDark, width: 1),
                            ),
                          ),
                          child: pw.Column(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  // Valor a pagar para Solar 7 (Destaque principal)
                                  pw.Container(
                                    padding: const pw.EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 7,
                                    ),
                                    decoration: pw.BoxDecoration(
                                      color: lightBlueBg,
                                      borderRadius: const pw.BorderRadius.all(
                                        pw.Radius.circular(6),
                                      ),
                                      border: pw.Border.all(
                                        color: primaryBlue,
                                        width: 1,
                                      ),
                                    ),
                                    child: pw.Row(
                                      children: [
                                        pw.SizedBox(
                                          width: 250,
                                          child: pw.Text(
                                            'O valor a pagar para $shortBrand é de:',
                                            style: pw.TextStyle(
                                              font: fontBold,
                                              fontSize: 13.5,
                                              color: slateDark,
                                            ),
                                          ),
                                        ),
                                        pw.Text(
                                          _currencyFmt.format(
                                            bill.solarCompanyAmountToPayRs,
                                          ),
                                          style: pw.TextStyle(
                                            font: fontBold,
                                            fontSize: 15.5,
                                            color: darkBlue,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  pw.SizedBox(height: 8),

                                  // Valor a pagar para Energisa
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: pw.Row(
                                      children: [
                                        pw.SizedBox(
                                          width: 250,
                                          child: pw.Text(
                                            'O valor a pagar para Energisa é de:',
                                            style: pw.TextStyle(
                                              font: fontMedium,
                                              fontSize: 13,
                                              color: slateDark,
                                            ),
                                          ),
                                        ),
                                        pw.Text(
                                          _currencyFmt.format(
                                            bill.utilityBillTotalToPayRs,
                                          ),
                                          style: pw.TextStyle(
                                            font: fontBold,
                                            fontSize: 14,
                                            color: slateDark,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  pw.SizedBox(height: 10),
                                  pw.Divider(color: borderGrey, height: 1),
                                  pw.SizedBox(height: 10),

                                  // Valor final COM Solar 7
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: pw.Row(
                                      children: [
                                        pw.SizedBox(
                                          width: 250,
                                          child: pw.Text(
                                            'O valor final com a $shortBrand é de:',
                                            style: pw.TextStyle(
                                              font: fontMedium,
                                              fontSize: 13,
                                              color: slateDark,
                                            ),
                                          ),
                                        ),
                                        pw.Text(
                                          _currencyFmt.format(
                                            bill.totalWithSolarCompanyRs,
                                          ),
                                          style: pw.TextStyle(
                                            font: fontBold,
                                            fontSize: 14,
                                            color: slateDark,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  pw.SizedBox(height: 6),

                                  // Valor final SEM Solar 7 SERIA de
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: pw.Row(
                                      children: [
                                        pw.SizedBox(
                                          width: 250,
                                          child: pw.Text(
                                            'O valor final sem a $shortBrand SERIA de:',
                                            style: pw.TextStyle(
                                              font: fontMedium,
                                              fontSize: 13,
                                              color: slateMuted,
                                            ),
                                          ),
                                        ),
                                        pw.Text(
                                          _currencyFmt.format(
                                            bill.totalWithoutSolarCompanyRs,
                                          ),
                                          style: pw.TextStyle(
                                            font: fontBold,
                                            fontSize: 14,
                                            color: slateMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              // Você economizou este mês
                              pw.Container(
                                padding: const pw.EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: pw.BoxDecoration(
                                  color: const PdfColor.fromInt(0xFFECFDF5),
                                  borderRadius: const pw.BorderRadius.all(
                                    pw.Radius.circular(6),
                                  ),
                                  border: pw.Border.all(
                                    color: emeraldGreen,
                                    width: 1,
                                  ),
                                ),
                                child: pw.Row(
                                  mainAxisAlignment:
                                      pw.MainAxisAlignment.spaceBetween,
                                  children: [
                                    pw.Row(
                                      children: [
                                        pw.SizedBox(
                                          width: 250,
                                          child: pw.Text(
                                            'Você economizou este mês:',
                                            style: pw.TextStyle(
                                              font: fontBold,
                                              fontSize: 13.5,
                                              color: primaryBlue,
                                            ),
                                          ),
                                        ),
                                        pw.Text(
                                          _currencyFmt.format(
                                            bill.monthlySavingsRs,
                                          ),
                                          style: pw.TextStyle(
                                            font: fontBold,
                                            fontSize: 15.5,
                                            color: emeraldGreen,
                                          ),
                                        ),
                                      ],
                                    ),
                                    pw.Text(
                                      'Deságio: ${_decFmt.format(bill.clientDiscountPercent)}%',
                                      style: pw.TextStyle(
                                        font: fontSemiBold,
                                        fontSize: 9.5,
                                        color: emeraldGreen,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // COLUNA DIREITA: ÁREA DE PAGAMENTO OPCIONAL (QR CODE / LINK / PIX)
                      pw.Expanded(
                        flex: 38,
                        child: pw.Container(
                          padding: const pw.EdgeInsets.all(14),
                          alignment: pw.Alignment.center,
                          child: hasAnyPaymentInfo
                              ? pw.Column(
                                  mainAxisAlignment:
                                      pw.MainAxisAlignment.center,
                                  crossAxisAlignment:
                                      pw.CrossAxisAlignment.center,
                                  children: [
                                    pw.Text(
                                      'PAGAMENTO $shortBrand (${_currencyFmt.format(bill.solarCompanyAmountToPayRs)})',
                                      style: pw.TextStyle(
                                        font: fontBold,
                                        fontSize: 10,
                                        color: darkBlue,
                                      ),
                                      textAlign: pw.TextAlign.center,
                                    ),
                                    pw.SizedBox(height: 6),
                                    if (qrCodeImg != null)
                                      pw.Container(
                                        width: 105,
                                        height: 105,
                                        padding: const pw.EdgeInsets.all(4),
                                        decoration: pw.BoxDecoration(
                                          color: PdfColors.white,
                                          border: pw.Border.all(
                                            color: primaryBlue,
                                            width: 1.2,
                                          ),
                                          borderRadius:
                                              const pw.BorderRadius.all(
                                            pw.Radius.circular(6),
                                          ),
                                        ),
                                        child: pw.Image(
                                          qrCodeImg,
                                          fit: pw.BoxFit.contain,
                                        ),
                                      )
                                    else if (hasPixCode || hasPaymentLink)
                                      pw.Container(
                                        width: 100,
                                        height: 100,
                                        padding: const pw.EdgeInsets.all(5),
                                        decoration: pw.BoxDecoration(
                                          color: PdfColors.white,
                                          border: pw.Border.all(
                                            color: primaryBlue,
                                            width: 1.2,
                                          ),
                                          borderRadius:
                                              const pw.BorderRadius.all(
                                            pw.Radius.circular(6),
                                          ),
                                        ),
                                        child: pw.BarcodeWidget(
                                          barcode: pw.Barcode.qrCode(),
                                          data: hasPixCode
                                              ? bill.pixCopyPasteCode!.trim()
                                              : bill.paymentLinkUrl!.trim(),
                                        ),
                                      ),
                                    if (hasPixCode) ...[
                                      pw.SizedBox(height: 5),
                                      pw.Text(
                                        'PIX Copia e Cola / Chave:',
                                        style: pw.TextStyle(
                                          font: fontBold,
                                          fontSize: 8,
                                          color: slateMuted,
                                        ),
                                      ),
                                      pw.Text(
                                        bill.pixCopyPasteCode!.trim(),
                                        maxLines: 2,
                                        style: pw.TextStyle(
                                          font: fontRegular,
                                          fontSize: 7.5,
                                          color: slateDark,
                                        ),
                                        textAlign: pw.TextAlign.center,
                                      ),
                                    ],
                                    if (hasPaymentLink) ...[
                                      pw.SizedBox(height: 6),
                                      pw.UrlLink(
                                        destination:
                                            bill.paymentLinkUrl!.trim(),
                                        child: pw.Container(
                                          padding:
                                              const pw.EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 5,
                                          ),
                                          decoration: const pw.BoxDecoration(
                                            color: primaryBlue,
                                            borderRadius: pw.BorderRadius.all(
                                              pw.Radius.circular(4),
                                            ),
                                          ),
                                          child: pw.Text(
                                            'CLIQUE AQUI PARA PAGAR (LINK)',
                                            style: pw.TextStyle(
                                              font: fontBold,
                                              fontSize: 8.5,
                                              color: PdfColors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                      pw.SizedBox(height: 2),
                                      pw.Text(
                                        bill.paymentLinkUrl!.trim(),
                                        maxLines: 1,
                                        style: pw.TextStyle(
                                          font: fontRegular,
                                          fontSize: 7,
                                          color: primaryBlue,
                                        ),
                                        textAlign: pw.TextAlign.center,
                                      ),
                                    ],
                                  ],
                                )
                              : pw.Column(
                                  mainAxisAlignment:
                                      pw.MainAxisAlignment.center,
                                  crossAxisAlignment:
                                      pw.CrossAxisAlignment.center,
                                  children: [
                                    pw.Container(
                                      padding: const pw.EdgeInsets.all(12),
                                      decoration: pw.BoxDecoration(
                                        color: lightBlueBg,
                                        borderRadius:
                                            const pw.BorderRadius.all(
                                          pw.Radius.circular(8),
                                        ),
                                        border: pw.Border.all(
                                          color: borderGrey,
                                          width: 0.8,
                                        ),
                                      ),
                                      child: pw.Column(
                                        children: [
                                          pw.Text(
                                            'RESUMO DO SEU BENEFÍCIO SOLAR',
                                            style: pw.TextStyle(
                                              font: fontBold,
                                              fontSize: 9.5,
                                              color: darkBlue,
                                            ),
                                          ),
                                          pw.SizedBox(height: 6),
                                          pw.Text(
                                            'Usina Geradora: ${bill.generatorPlantName}',
                                            style: pw.TextStyle(
                                              font: fontMedium,
                                              fontSize: 9,
                                              color: slateDark,
                                            ),
                                            textAlign: pw.TextAlign.center,
                                          ),
                                          pw.SizedBox(height: 4),
                                          pw.Text(
                                            'Crédito Bruto Abatido: ${_currencyFmt.format(bill.totalInjectedGrossValueRs)}',
                                            style: pw.TextStyle(
                                              font: fontRegular,
                                              fontSize: 8.5,
                                              color: slateMuted,
                                            ),
                                          ),
                                          if (bill.gdAdjustmentValueRs > 0) ...[
                                            pw.SizedBox(height: 2),
                                            pw.Text(
                                              'Ajuste GD II: ${_currencyFmt.format(bill.gdAdjustmentValueRs)}',
                                              style: pw.TextStyle(
                                                font: fontRegular,
                                                fontSize: 8.5,
                                                color: slateMuted,
                                              ),
                                            ),
                                          ],
                                          pw.SizedBox(height: 2),
                                          pw.Text(
                                            'Crédito Líquido Base: ${_currencyFmt.format(bill.netCompensatedCreditRs)}',
                                            style: pw.TextStyle(
                                              font: fontBold,
                                              fontSize: 9,
                                              color: slateDark,
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
                ),

                // ─────────────────────────────────────────────────────────────
                // 5. RODAPÉ AZUL DE CELEBRAÇÃO DA ECONOMIA ANUAL
                // ─────────────────────────────────────────────────────────────
                pw.Container(
                  height: 1.5,
                  color: slateDark,
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  decoration: const pw.BoxDecoration(
                    gradient: pw.LinearGradient(
                      colors: [primaryBlue, darkBlue],
                      begin: pw.Alignment.centerLeft,
                      end: pw.Alignment.centerRight,
                    ),
                    borderRadius: pw.BorderRadius.only(
                      bottomLeft: pw.Radius.circular(4.5),
                      bottomRight: pw.Radius.circular(4.5),
                    ),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'PARABÉNS, NESTE RITMO VOCÊ ESTÁ ECONOMIZANDO',
                        style: pw.TextStyle(
                          font: fontSemiBold,
                          fontSize: 15,
                          color: PdfColors.white,
                          letterSpacing: 0.6,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                      pw.SizedBox(height: 6),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Text(
                            _currencyFmt.format(bill.annualProjectedSavingsRs),
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 22,
                              color: PdfColors.white,
                            ),
                          ),
                          pw.SizedBox(width: 18),
                          pw.Text(
                            'ANUAL',
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 13.5,
                              color: const PdfColor.fromInt(0xFFE0F2FE),
                              letterSpacing: 1.0,
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
        },
      ),
    );

    return doc.save();
  }

  static pw.Widget _buildMiniDetailRow(
    pw.Font regularFont,
    pw.Font boldFont,
    String label,
    String value,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              font: regularFont,
              fontSize: 8.5,
              color: const PdfColor.fromInt(0xFF475569),
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              font: boldFont,
              fontSize: 8.5,
              color: const PdfColor.fromInt(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}

/// Modal executivo para Pré-visualizar, Baixar e Imprimir o Demonstrativo / Boleto PDF
class SolarCreditBoletoPreviewDialog extends StatelessWidget {
  final SolarCreditBillModel bill;

  const SolarCreditBoletoPreviewDialog({
    super.key,
    required this.bill,
  });

  static Future<void> show(BuildContext context, SolarCreditBillModel bill) {
    return showDialog(
      context: context,
      builder: (_) => SolarCreditBoletoPreviewDialog(bill: bill),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cleanFileName =
        'Demonstrativo_Solar_UC_${bill.ucNumber.replaceAll(RegExp(r'[^0-9]'), '')}_${bill.referenceMonth.replaceAll(' ', '').replaceAll('/', '_')}.pdf';

    return Dialog(
      backgroundColor: const Color(0xFF0F172A),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF334155)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1020, maxHeight: 760),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(
                  bottom: BorderSide(color: Color(0xFF334155)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: Color(0xFF38BDF8),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Demonstrativo / Boleto de Créditos Solares — ${bill.clientName}',
                          style: GoogleFonts.outfit(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'UC: ${bill.ucNumber} • Ref: ${bill.referenceMonth} • Vencimento: ${bill.dueDate}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fechar',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  ),
                ],
              ),
            ),

            // Preview PDF
            Expanded(
              child: PdfPreview(
                build: (_) =>
                    SolarCreditBoletoPdfService.generateBoletoPdf(bill: bill),
                pdfFileName: cleanFileName,
                canChangeOrientation: false,
                canChangePageFormat: false,
                canDebug: false,
                loadingWidget: const Center(
                  child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

