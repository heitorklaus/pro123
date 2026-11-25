import 'dart:convert';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/solar_credit_dto.dart';
import 'solar7_logo_data.dart';

/// Motor Nativo Dart de Geração do PDF do Demonstrativo / Boleto GD (100% idêntico ao Padrão Solar 7 do CRM)
class SolarCreditBoletoEngine {
  static Future<Uint8List> generatePdf({
    required GdBillCalculationDTO calc,
    String companyName = 'SOLAR 7 ENERGIA E TECNOLOGIA LTDA',
    String companyDoc = '42.117.511/0001-38',
    String companyAddress = 'AV ISAAC POVOAS SALA 201 EDIFICIO WALL STREET',
    String companyWebsite = 'www.solar7.com.br',
    String? companyLogoBase64,
  }) async {
    final doc = pw.Document(
      title: 'Demonstrativo Solar - UC ${calc.ucNumber} - ${calc.referenceMonth}',
      author: companyName,
    );

    final shortBrand = companyName.toUpperCase().contains('SOLAR 7')
        ? 'Solar 7'
        : companyName.split(' ').take(2).join(' ');

    pw.MemoryImage? companyLogoImg;
    final effectiveLogoB64 = (companyLogoBase64 != null && companyLogoBase64.isNotEmpty)
        ? companyLogoBase64
        : solar7LogoBase64;
    if (effectiveLogoB64.isNotEmpty) {
      try {
        final clean = effectiveLogoB64.contains(',')
            ? effectiveLogoB64.split(',').last
            : effectiveLogoB64;
        companyLogoImg = pw.MemoryImage(base64Decode(clean));
      } catch (_) {}
    }

    pw.MemoryImage? qrCodeImg;
    if (calc.qrCodeImageBase64 != null && calc.qrCodeImageBase64!.trim().isNotEmpty) {
      try {
        final clean = calc.qrCodeImageBase64!.contains(',')
            ? calc.qrCodeImageBase64!.split(',').last
            : calc.qrCodeImageBase64!;
        qrCodeImg = pw.MemoryImage(base64Decode(clean));
      } catch (_) {}
    }

    final hasQrImage = qrCodeImg != null;
    final hasPixCode = calc.pixCopyPasteCode != null && calc.pixCopyPasteCode!.trim().isNotEmpty;
    final hasPaymentLink = calc.paymentLinkUrl != null && calc.paymentLinkUrl!.trim().isNotEmpty;
    final hasAnyPaymentInfo = hasQrImage || hasPixCode || hasPaymentLink;

    final fontRegular = pw.Font.helvetica();
    final fontMedium = pw.Font.helvetica();
    final fontSemiBold = pw.Font.helveticaBold();
    final fontBold = pw.Font.helveticaBold();

    const primaryBlue = PdfColor.fromInt(0xFF0088CC);
    const darkBlue = PdfColor.fromInt(0xFF0369A1);
    const lightBlueBg = PdfColor.fromInt(0xFFF0F9FF);
    const slateDark = PdfColor.fromInt(0xFF0F172A);
    const slateMuted = PdfColor.fromInt(0xFF475569);
    const borderGrey = PdfColor.fromInt(0xFFCBD5E1);
    const emeraldGreen = PdfColor.fromInt(0xFF059669);

    final cleanUc = calc.ucNumber;
    final displayAddressOrClient = calc.addressStreet.trim().isNotEmpty
        ? calc.addressStreet.trim().toUpperCase()
        : calc.beneficiary.clientName.trim().toUpperCase();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
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
                  padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
                            borderRadius: pw.BorderRadius.all(pw.Radius.circular(10)),
                          ),
                          alignment: pw.Alignment.center,
                          child: pw.Image(companyLogoImg, fit: pw.BoxFit.contain),
                        )
                      else
                        pw.Container(
                          width: 78,
                          height: 78,
                          decoration: pw.BoxDecoration(
                            color: PdfColors.white.shade(0.12),
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(14)),
                            border: pw.Border.all(color: PdfColors.white, width: 2),
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
                  padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 10),
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
                            style: pw.TextStyle(font: fontBold, fontSize: 13, color: slateDark),
                          ),
                          pw.Text(
                            calc.dueDate.isNotEmpty ? calc.dueDate : 'A definir',
                            style: pw.TextStyle(font: fontBold, fontSize: 14, color: primaryBlue),
                          ),
                        ],
                      ),
                      pw.Row(
                        children: [
                          pw.Text(
                            'CLIENTE:  ',
                            style: pw.TextStyle(font: fontBold, fontSize: 12, color: slateMuted),
                          ),
                          pw.Text(
                            calc.beneficiary.clientName.toUpperCase(),
                            style: pw.TextStyle(font: fontBold, fontSize: 12.5, color: slateDark),
                          ),
                        ],
                      ),
                      pw.Row(
                        children: [
                          pw.Text(
                            'REFERÊNCIA:  ',
                            style: pw.TextStyle(font: fontBold, fontSize: 13, color: slateDark),
                          ),
                          pw.Text(
                            calc.referenceMonth.toUpperCase(),
                            style: pw.TextStyle(font: fontBold, fontSize: 14, color: primaryBlue),
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
                  padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(color: slateDark, width: 1.8),
                    ),
                  ),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
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
                                    style: pw.TextStyle(font: fontMedium, fontSize: 13, color: slateDark),
                                  ),
                                ),
                                pw.Expanded(
                                  child: pw.Text(
                                    displayAddressOrClient,
                                    style: pw.TextStyle(font: fontBold, fontSize: 12.5, color: slateDark),
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
                                    style: pw.TextStyle(font: fontMedium, fontSize: 13, color: slateDark),
                                  ),
                                ),
                                pw.Expanded(
                                  child: pw.Text(
                                    cleanUc,
                                    style: pw.TextStyle(font: fontBold, fontSize: 13, color: slateDark),
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
                                    style: pw.TextStyle(font: fontMedium, fontSize: 13.5, color: slateDark),
                                  ),
                                ),
                                pw.Text(
                                  '${_fmtInt(calc.consumptionKwh)} Kilowatts',
                                  style: pw.TextStyle(font: fontBold, fontSize: 14, color: slateDark),
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
                                    style: pw.TextStyle(font: fontMedium, fontSize: 13.5, color: slateDark),
                                  ),
                                ),
                                pw.Text(
                                  '${_fmtInt(calc.totalInjectedKwh)} Kilowatts',
                                  style: pw.TextStyle(font: fontBold, fontSize: 14, color: primaryBlue),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      pw.Expanded(
                        flex: 4,
                        child: pw.Container(
                          padding: const pw.EdgeInsets.all(10),
                          decoration: pw.BoxDecoration(
                            color: const PdfColor.fromInt(0xFFF8FAFC),
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
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
                              if (calc.injectedGdiKwh > 0)
                                _buildMiniDetailRow(
                                  fontRegular,
                                  fontBold,
                                  'Injetada GD I:',
                                  '${_fmtInt(calc.injectedGdiKwh)} kWh (${_fmtCurrency(calc.injectedGdiValueRs)})',
                                ),
                              if (calc.injectedGdiiKwh > 0)
                                _buildMiniDetailRow(
                                  fontRegular,
                                  fontBold,
                                  'Injetada GD II:',
                                  '${_fmtInt(calc.injectedGdiiKwh)} kWh (${_fmtCurrency(calc.injectedGdiiValueRs)})',
                                ),
                              if (calc.gdAdjustmentValueRs > 0)
                                _buildMiniDetailRow(
                                  fontRegular,
                                  fontBold,
                                  'Ajuste GD II (Lei 14.300):',
                                  '- ${_fmtCurrency(calc.gdAdjustmentValueRs)}',
                                ),
                              _buildMiniDetailRow(
                                fontRegular,
                                fontBold,
                                'Saldo Acumulado na UC:',
                                '${_fmtInt(calc.accumulatedBalanceKwh)} kWh',
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
                          padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: const pw.BoxDecoration(
                            border: pw.Border(
                              right: pw.BorderSide(color: slateDark, width: 1),
                            ),
                          ),
                          child: pw.FittedBox(
                            fit: pw.BoxFit.scaleDown,
                            alignment: pw.Alignment.centerLeft,
                            child: pw.SizedBox(
                              width: 445,
                              child: pw.Column(
                                mainAxisSize: pw.MainAxisSize.min,
                                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                                children: [
                                  pw.Container(
                                    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                    decoration: pw.BoxDecoration(
                                      color: lightBlueBg,
                                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                                      border: pw.Border.all(color: primaryBlue, width: 1),
                                    ),
                                    child: pw.Row(
                                      children: [
                                        pw.SizedBox(
                                          width: 250,
                                          child: pw.Text(
                                            'O valor a pagar para $shortBrand é de:',
                                            style: pw.TextStyle(font: fontBold, fontSize: 13.5, color: slateDark),
                                          ),
                                        ),
                                        pw.Text(
                                          _fmtCurrency(calc.solarCompanyAmountToPayRs),
                                          style: pw.TextStyle(font: fontBold, fontSize: 15.5, color: darkBlue),
                                        ),
                                      ],
                                    ),
                                  ),
                                  pw.SizedBox(height: 8),

                                  pw.Padding(
                                    padding: const pw.EdgeInsets.symmetric(horizontal: 12),
                                    child: pw.Row(
                                      children: [
                                        pw.SizedBox(
                                          width: 250,
                                          child: pw.Text(
                                            'O valor a pagar para Energisa é de:',
                                            style: pw.TextStyle(font: fontMedium, fontSize: 13, color: slateDark),
                                          ),
                                        ),
                                        pw.Text(
                                          _fmtCurrency(calc.utilityBillTotalToPayRs),
                                          style: pw.TextStyle(font: fontBold, fontSize: 14, color: slateDark),
                                        ),
                                      ],
                                    ),
                                  ),

                                  pw.SizedBox(height: 10),
                                  pw.Divider(color: borderGrey, height: 1),
                                  pw.SizedBox(height: 10),

                                  pw.Padding(
                                    padding: const pw.EdgeInsets.symmetric(horizontal: 12),
                                    child: pw.Row(
                                      children: [
                                        pw.SizedBox(
                                          width: 250,
                                          child: pw.Text(
                                            'O valor final com a $shortBrand é de:',
                                            style: pw.TextStyle(font: fontMedium, fontSize: 13, color: slateDark),
                                          ),
                                        ),
                                        pw.Text(
                                          _fmtCurrency(calc.totalWithSolarCompanyRs),
                                          style: pw.TextStyle(font: fontBold, fontSize: 14, color: slateDark),
                                        ),
                                      ],
                                    ),
                                  ),
                                  pw.SizedBox(height: 6),

                                  pw.Padding(
                                    padding: const pw.EdgeInsets.symmetric(horizontal: 12),
                                    child: pw.Row(
                                      children: [
                                        pw.SizedBox(
                                          width: 250,
                                          child: pw.Text(
                                            'O valor final sem a $shortBrand SERIA de:',
                                            style: pw.TextStyle(font: fontMedium, fontSize: 13, color: slateMuted),
                                          ),
                                        ),
                                        pw.Text(
                                          _fmtCurrency(calc.totalWithoutSolarCompanyRs),
                                          style: pw.TextStyle(font: fontBold, fontSize: 14, color: slateMuted),
                                        ),
                                      ],
                                    ),
                                  ),

                                  pw.SizedBox(height: 10),
                              pw.Container(
                                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                decoration: pw.BoxDecoration(
                                  color: const PdfColor.fromInt(0xFFECFDF5),
                                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                                  border: pw.Border.all(color: emeraldGreen, width: 1),
                                ),
                                child: pw.Row(
                                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                  children: [
                                    pw.Row(
                                      children: [
                                        pw.SizedBox(
                                          width: 250,
                                          child: pw.Text(
                                            'Você economizou este mês:',
                                            style: pw.TextStyle(font: fontBold, fontSize: 13.5, color: primaryBlue),
                                          ),
                                        ),
                                        pw.Text(
                                          _fmtCurrency(calc.monthlySavingsRs),
                                          style: pw.TextStyle(font: fontBold, fontSize: 15.5, color: emeraldGreen),
                                        ),
                                      ],
                                    ),
                                    pw.Text(
                                      'Deságio: ${_fmtDec(calc.clientDiscountPercent)}%',
                                      style: pw.TextStyle(font: fontSemiBold, fontSize: 9.5, color: emeraldGreen),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
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
                                  mainAxisAlignment: pw.MainAxisAlignment.center,
                                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                                  children: [
                                    pw.Text(
                                      'PAGAMENTO $shortBrand (${_fmtCurrency(calc.solarCompanyAmountToPayRs)})',
                                      style: pw.TextStyle(font: fontBold, fontSize: 10, color: darkBlue),
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
                                          border: pw.Border.all(color: primaryBlue, width: 1.2),
                                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                                        ),
                                        child: pw.Image(qrCodeImg, fit: pw.BoxFit.contain),
                                      )
                                    else if (hasPixCode || hasPaymentLink)
                                      pw.Container(
                                        width: 100,
                                        height: 100,
                                        padding: const pw.EdgeInsets.all(5),
                                        decoration: pw.BoxDecoration(
                                          color: PdfColors.white,
                                          border: pw.Border.all(color: primaryBlue, width: 1.2),
                                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                                        ),
                                        child: pw.BarcodeWidget(
                                          barcode: pw.Barcode.qrCode(),
                                          data: hasPixCode
                                              ? calc.pixCopyPasteCode!.trim()
                                              : calc.paymentLinkUrl!.trim(),
                                        ),
                                      ),
                                    if (hasPixCode) ...[
                                      pw.SizedBox(height: 5),
                                      pw.Text(
                                        'PIX Copia e Cola / Chave:',
                                        style: pw.TextStyle(font: fontBold, fontSize: 8, color: slateMuted),
                                      ),
                                      pw.Text(
                                        calc.pixCopyPasteCode!.trim(),
                                        maxLines: 2,
                                        style: pw.TextStyle(font: fontRegular, fontSize: 7.5, color: slateDark),
                                        textAlign: pw.TextAlign.center,
                                      ),
                                    ],
                                    if (hasPaymentLink) ...[
                                      pw.SizedBox(height: 6),
                                      pw.UrlLink(
                                        destination: calc.paymentLinkUrl!.trim(),
                                        child: pw.Container(
                                          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                          decoration: const pw.BoxDecoration(
                                            color: primaryBlue,
                                            borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                                          ),
                                          child: pw.Text(
                                            'CLIQUE AQUI PARA PAGAR (LINK)',
                                            style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: PdfColors.white),
                                          ),
                                        ),
                                      ),
                                      pw.SizedBox(height: 2),
                                      pw.Text(
                                        calc.paymentLinkUrl!.trim(),
                                        maxLines: 1,
                                        style: pw.TextStyle(font: fontRegular, fontSize: 7, color: primaryBlue),
                                        textAlign: pw.TextAlign.center,
                                      ),
                                    ],
                                  ],
                                )
                              : pw.Column(
                                  mainAxisAlignment: pw.MainAxisAlignment.center,
                                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                                  children: [
                                    pw.Container(
                                      padding: const pw.EdgeInsets.all(12),
                                      decoration: pw.BoxDecoration(
                                        color: lightBlueBg,
                                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                                        border: pw.Border.all(color: borderGrey, width: 0.8),
                                      ),
                                      child: pw.Column(
                                        children: [
                                          pw.Text(
                                            'RESUMO DO SEU BENEFÍCIO SOLAR',
                                            style: pw.TextStyle(font: fontBold, fontSize: 9.5, color: darkBlue),
                                          ),
                                          pw.SizedBox(height: 6),
                                          pw.Text(
                                            'Usina Geradora: ${calc.beneficiary.generatorPlantName}',
                                            style: pw.TextStyle(font: fontMedium, fontSize: 9, color: slateDark),
                                            textAlign: pw.TextAlign.center,
                                          ),
                                          pw.SizedBox(height: 4),
                                          pw.Text(
                                            'Crédito Bruto Abatido: ${_fmtCurrency(calc.totalInjectedGrossValueRs)}',
                                            style: pw.TextStyle(font: fontRegular, fontSize: 8.5, color: slateMuted),
                                          ),
                                          if (calc.gdAdjustmentValueRs > 0) ...[
                                            pw.SizedBox(height: 2),
                                            pw.Text(
                                              'Ajuste GD II: ${_fmtCurrency(calc.gdAdjustmentValueRs)}',
                                              style: pw.TextStyle(font: fontRegular, fontSize: 8.5, color: slateMuted),
                                            ),
                                          ],
                                          pw.SizedBox(height: 2),
                                          pw.Text(
                                            'Crédito Líquido Base: ${_fmtCurrency(calc.netCompensatedCreditRs)}',
                                            style: pw.TextStyle(font: fontBold, fontSize: 9, color: slateDark),
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
                pw.Container(height: 1.5, color: slateDark),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 14),
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
                            _fmtCurrency(calc.annualProjectedSavingsRs),
                            style: pw.TextStyle(font: fontBold, fontSize: 22, color: PdfColors.white),
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

  static String _fmtCurrency(double v) {
    final fixed = v.toStringAsFixed(2);
    final parts = fixed.split('.');
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    final formattedInt = parts[0].replaceAllMapped(reg, (m) => '${m[1]}.');
    return 'R\$ $formattedInt,${parts[1]}';
  }

  static String _fmtInt(double v) {
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return v.round().toString().replaceAllMapped(reg, (m) => '${m[1]}.');
  }

  static String _fmtDec(double v) => v.toStringAsFixed(2).replaceAll('.', ',');
}
