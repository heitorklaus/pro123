import 'dart:math' as math;

/// Linha individual de Energia Injetada (GD I / GD II) extraída da fatura
class GdInjectedLineDTO {
  final String label;
  final double kwh;
  final double valueRs;
  final String regime; // 'GDI' ou 'GDII'

  const GdInjectedLineDTO({
    required this.label,
    required this.kwh,
    required this.valueRs,
    this.regime = 'GDII',
  });

  factory GdInjectedLineDTO.fromMap(Map<String, dynamic> map) {
    final labelStr = (map['label'] ?? map['description'] ?? 'Energia Atv Injetada').toString();
    final rawRegime = (map['regime'] ?? '').toString().toUpperCase();
    final detectedRegime = rawRegime.isNotEmpty
        ? (rawRegime.contains('GDII') || rawRegime.contains('GD2') || rawRegime.contains('II') ? 'GDII' : 'GDI')
        : (labelStr.toUpperCase().contains('GDII') || labelStr.toUpperCase().contains('GD II') ? 'GDII' : 'GDI');

    return GdInjectedLineDTO(
      label: labelStr,
      kwh: _toDouble(map['kwh']),
      valueRs: _toDouble(map['valueRs'] ?? map['value']).abs(),
      regime: detectedRegime,
    );
  }

  Map<String, dynamic> toMap() => {
        'label': label,
        'kwh': kwh,
        'valueRs': valueRs,
        'regime': regime,
      };
}

/// Beneficiário / Recebedor de Créditos Solares cadastrado no Firestore (`solar_credit_beneficiaries`)
class GdBeneficiaryDTO {
  final String id;
  final String companyId;
  final String clientName;
  final String clientPhone;
  final String accountHolderName;
  final String ucNumber;
  final String normalizedUcDigits;
  final String addressStreet;
  final String addressCity;
  final String addressState;
  final String generatorPlantId;
  final String generatorPlantName;
  final String generatorRegime; // 'gd1' | 'gd2'
  final double utilityAllocationPercent;
  final double clientDiscountPercent;
  final double lastAccumulatedBalanceKwh;
  final String status;

  const GdBeneficiaryDTO({
    required this.id,
    required this.companyId,
    required this.clientName,
    this.clientPhone = '',
    this.accountHolderName = '',
    required this.ucNumber,
    required this.normalizedUcDigits,
    this.addressStreet = '',
    this.addressCity = 'Cuiabá',
    this.addressState = 'MT',
    this.generatorPlantId = '',
    this.generatorPlantName = '',
    this.generatorRegime = 'gd2',
    this.utilityAllocationPercent = 0.0,
    this.clientDiscountPercent = 20.0,
    this.lastAccumulatedBalanceKwh = 0.0,
    this.status = 'active',
  });

  factory GdBeneficiaryDTO.fromMap(Map<String, dynamic> map, String id) {
    final uc = (map['ucNumber'] ?? '').toString().trim();
    final digits = (map['normalizedUcDigits'] ?? uc.replaceAll(RegExp(r'\D'), '')).toString();
    return GdBeneficiaryDTO(
      id: id,
      companyId: (map['companyId'] ?? '').toString().trim(),
      clientName: (map['clientName'] ?? '').toString().trim(),
      clientPhone: (map['clientPhone'] ?? '').toString().trim(),
      accountHolderName: (map['accountHolderName'] ?? '').toString().trim(),
      ucNumber: uc,
      normalizedUcDigits: digits,
      addressStreet: (map['addressStreet'] ?? '').toString().trim(),
      addressCity: (map['addressCity'] ?? 'Cuiabá').toString().trim(),
      addressState: (map['addressState'] ?? 'MT').toString().trim(),
      generatorPlantId: (map['generatorPlantId'] ?? '').toString().trim(),
      generatorPlantName: (map['generatorPlantName'] ?? '').toString().trim(),
      generatorRegime: (map['generatorRegime'] ?? 'gd2').toString().trim(),
      utilityAllocationPercent: _normalizePercent(_toDouble(map['utilityAllocationPercent'])),
      clientDiscountPercent: _normalizePercent(_toDouble(map['clientDiscountPercent'], fallback: 20.0)),
      lastAccumulatedBalanceKwh: _toDouble(map['lastAccumulatedBalanceKwh']),
      status: (map['status'] ?? 'active').toString().trim(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'companyId': companyId,
        'clientName': clientName,
        'clientPhone': clientPhone,
        'accountHolderName': accountHolderName,
        'ucNumber': ucNumber,
        'normalizedUcDigits': normalizedUcDigits,
        'addressStreet': addressStreet,
        'addressCity': addressCity,
        'addressState': addressState,
        'generatorPlantId': generatorPlantId,
        'generatorPlantName': generatorPlantName,
        'generatorRegime': generatorRegime,
        'utilityAllocationPercent': utilityAllocationPercent,
        'clientDiscountPercent': clientDiscountPercent,
        'lastAccumulatedBalanceKwh': lastAccumulatedBalanceKwh,
        'status': status,
      };
}

/// Resultado consolidado do Demonstrativo / Boleto GD (espelha a tela Créditos Solares do CRM)
class GdBillCalculationDTO {
  final GdBeneficiaryDTO beneficiary;
  final String referenceMonth;
  final String dueDate;
  final String ucNumber;
  final String addressStreet;
  final String accountHolderName;
  final double utilityAllocationPercent;
  final double clientDiscountPercent;
  final double accumulatedBalanceKwh;
  final List<GdInjectedLineDTO> injectedLines;

  final double consumptionKwh;
  final double consumptionValueRs;

  final double injectedGdiKwh;
  final double injectedGdiValueRs;
  final double injectedGdiiKwh;
  final double injectedGdiiValueRs;
  final double totalInjectedKwh;
  final double totalInjectedGrossValueRs;

  final double gdAdjustmentKwh;
  final double gdAdjustmentTariff;
  final double gdAdjustmentValueRs;

  final double publicLightingValueRs;
  final double finesAndInterestValueRs;
  final double otherChargesValueRs;
  final double utilityBillTotalToPayRs;

  final double netCompensatedCreditRs;
  final double discountAmountRs;
  final double solarCompanyAmountToPayRs;
  final double totalWithSolarCompanyRs;
  final double totalWithoutSolarCompanyRs;
  final double monthlySavingsRs;
  final double annualProjectedSavingsRs;

  final String? qrCodeImageBase64;
  final String? pixCopyPasteCode;
  final String? paymentLinkUrl;

  const GdBillCalculationDTO({
    required this.beneficiary,
    required this.referenceMonth,
    required this.dueDate,
    required this.ucNumber,
    required this.addressStreet,
    required this.accountHolderName,
    required this.utilityAllocationPercent,
    required this.clientDiscountPercent,
    required this.accumulatedBalanceKwh,
    required this.injectedLines,
    required this.consumptionKwh,
    required this.consumptionValueRs,
    required this.injectedGdiKwh,
    required this.injectedGdiValueRs,
    required this.injectedGdiiKwh,
    required this.injectedGdiiValueRs,
    required this.totalInjectedKwh,
    required this.totalInjectedGrossValueRs,
    required this.gdAdjustmentKwh,
    required this.gdAdjustmentTariff,
    required this.gdAdjustmentValueRs,
    required this.publicLightingValueRs,
    required this.finesAndInterestValueRs,
    required this.otherChargesValueRs,
    required this.utilityBillTotalToPayRs,
    required this.netCompensatedCreditRs,
    required this.discountAmountRs,
    required this.solarCompanyAmountToPayRs,
    required this.totalWithSolarCompanyRs,
    required this.totalWithoutSolarCompanyRs,
    required this.monthlySavingsRs,
    required this.annualProjectedSavingsRs,
    this.qrCodeImageBase64,
    this.pixCopyPasteCode,
    this.paymentLinkUrl,
  });

  factory GdBillCalculationDTO.fromBeneficiaryAndBill({
    required GdBeneficiaryDTO beneficiary,
    required Map<String, dynamic> billData,
  }) {
    final rawLines = billData['injectedLines'] as List<dynamic>? ?? [];
    final injectedLines = rawLines
        .whereType<Map>()
        .map((e) => GdInjectedLineDTO.fromMap(Map<String, dynamic>.from(e)))
        .toList();

    double gdiKwh = _toDouble(billData['injectedGdiKwh']);
    double gdiRs = _toDouble(billData['injectedGdiValueRs']).abs();
    double gdiiKwh = _toDouble(billData['injectedGdiiKwh']);
    double gdiiRs = _toDouble(billData['injectedGdiiValueRs']).abs();

    if (injectedLines.isNotEmpty) {
      gdiKwh = 0;
      gdiRs = 0;
      gdiiKwh = 0;
      gdiiRs = 0;
      for (final line in injectedLines) {
        if (line.regime == 'GDI') {
          gdiKwh += line.kwh;
          gdiRs += line.valueRs;
        } else {
          gdiiKwh += line.kwh;
          gdiiRs += line.valueRs;
        }
      }
    }

    final totalInjKwh = _toDouble(billData['totalInjectedKwh']) > 0
        ? _toDouble(billData['totalInjectedKwh'])
        : (gdiKwh + gdiiKwh);
    final totalInjRs = _toDouble(billData['totalInjectedGrossValueRs']) > 0
        ? _toDouble(billData['totalInjectedGrossValueRs'])
        : (gdiRs + gdiiRs);

    final gdAdjKwh = _toDouble(billData['gdAdjustmentKwh']);
    final gdAdjTariff = _toDouble(billData['gdAdjustmentTariff']);
    final gdAdjRs = _toDouble(billData['gdAdjustmentValueRs']).abs();

    final netCredit = math.max(0.0, totalInjRs - gdAdjRs);
    final discountPct = _toDouble(billData['clientDiscountPercent'], fallback: beneficiary.clientDiscountPercent);
    final discountAmt = netCredit * (discountPct / 100.0);
    final solarPay = netCredit - discountAmt;

    final utilityPay = _toDouble(billData['utilityBillTotalToPayRs'] ?? billData['totalToPayRs']);
    final totalWithSolar = solarPay + utilityPay;
    final totalWithoutSolar = netCredit + utilityPay;
    final savingsMonth = math.max(0.0, totalWithoutSolar - totalWithSolar);
    final savingsYear = savingsMonth * 12.0;

    final refMonth = (billData['referenceMonth'] ?? _defaultRefMonth()).toString().trim();
    final due = (billData['dueDate'] ?? '').toString().trim();
    final uc = (billData['ucNumber'] ?? beneficiary.ucNumber).toString().trim();
    final addr = (billData['addressStreet'] ?? beneficiary.addressStreet).toString().trim();
    final holder = (billData['accountHolderName'] ?? beneficiary.accountHolderName).toString().trim();
    final accBalance = _toDouble(billData['accumulatedBalanceKwh'], fallback: beneficiary.lastAccumulatedBalanceKwh);

    return GdBillCalculationDTO(
      beneficiary: beneficiary,
      referenceMonth: refMonth.isNotEmpty ? refMonth : _defaultRefMonth(),
      dueDate: due.isNotEmpty ? due : '-',
      ucNumber: uc.isNotEmpty ? uc : beneficiary.ucNumber,
      addressStreet: addr.isNotEmpty ? addr : beneficiary.addressStreet,
      accountHolderName: holder.isNotEmpty ? holder : beneficiary.accountHolderName,
      utilityAllocationPercent: _toDouble(
        billData['utilityAllocationPercent'],
        fallback: beneficiary.utilityAllocationPercent,
      ),
      clientDiscountPercent: discountPct,
      accumulatedBalanceKwh: accBalance,
      injectedLines: injectedLines,
      consumptionKwh: _toDouble(billData['consumptionKwh'], fallback: totalInjKwh),
      consumptionValueRs: _toDouble(billData['consumptionValueRs'], fallback: totalInjRs),
      injectedGdiKwh: gdiKwh,
      injectedGdiValueRs: gdiRs,
      injectedGdiiKwh: gdiiKwh,
      injectedGdiiValueRs: gdiiRs,
      totalInjectedKwh: totalInjKwh,
      totalInjectedGrossValueRs: totalInjRs,
      gdAdjustmentKwh: gdAdjKwh,
      gdAdjustmentTariff: gdAdjTariff,
      gdAdjustmentValueRs: gdAdjRs,
      publicLightingValueRs: _toDouble(billData['publicLightingValueRs']),
      finesAndInterestValueRs: _toDouble(billData['finesAndInterestValueRs']),
      otherChargesValueRs: _toDouble(billData['otherChargesValueRs']),
      utilityBillTotalToPayRs: utilityPay,
      netCompensatedCreditRs: netCredit,
      discountAmountRs: discountAmt,
      solarCompanyAmountToPayRs: solarPay,
      totalWithSolarCompanyRs: totalWithSolar,
      totalWithoutSolarCompanyRs: totalWithoutSolar,
      monthlySavingsRs: savingsMonth,
      annualProjectedSavingsRs: savingsYear,
      qrCodeImageBase64: billData['qrCodeImageBase64']?.toString(),
      pixCopyPasteCode: billData['pixCopyPasteCode']?.toString(),
      paymentLinkUrl: billData['paymentLinkUrl']?.toString(),
    );
  }

  Map<String, dynamic> toMap() => {
        'beneficiaryId': beneficiary.id,
        'clientName': beneficiary.clientName,
        'generatorPlantName': beneficiary.generatorPlantName,
        'referenceMonth': referenceMonth,
        'dueDate': dueDate,
        'ucNumber': ucNumber,
        'addressStreet': addressStreet,
        'accountHolderName': accountHolderName,
        'utilityAllocationPercent': utilityAllocationPercent,
        'clientDiscountPercent': clientDiscountPercent,
        'accumulatedBalanceKwh': accumulatedBalanceKwh,
        'injectedLines': injectedLines.map((e) => e.toMap()).toList(),
        'totalInjectedKwh': totalInjectedKwh,
        'totalInjectedGrossValueRs': totalInjectedGrossValueRs,
        'gdAdjustmentValueRs': gdAdjustmentValueRs,
        'netCompensatedCreditRs': netCompensatedCreditRs,
        'discountAmountRs': discountAmountRs,
        'solarCompanyAmountToPayRs': solarCompanyAmountToPayRs,
        'utilityBillTotalToPayRs': utilityBillTotalToPayRs,
        'totalWithSolarCompanyRs': totalWithSolarCompanyRs,
        'totalWithoutSolarCompanyRs': totalWithoutSolarCompanyRs,
        'monthlySavingsRs': monthlySavingsRs,
        'annualProjectedSavingsRs': annualProjectedSavingsRs,
      };

  /// Monta o resumo ilustrado para WhatsApp (com ícones e negrito) espelhando a tela do CRM
  String buildWhatsAppSummary({String brandName = 'Solar 7'}) {
    final buf = StringBuffer();
    buf.writeln('☀️ *CRÉDITOS SOLARES (GD) — RESUMO DA FATURA*');
    buf.writeln('');
    buf.writeln('👤 *Cliente:* *${beneficiary.clientName}*');
    if (beneficiary.generatorPlantName.isNotEmpty) {
      buf.writeln('🏭 *Usina Origem:* ${beneficiary.generatorPlantName}');
    }
    buf.writeln('🔌 *Número da UC:* *$ucNumber*');
    buf.writeln('📅 *Mês de Referência:* *$referenceMonth*  |  📆 *Vencimento:* *$dueDate*');
    if (addressStreet.isNotEmpty) {
      buf.writeln('📍 *Endereço da UC:* $addressStreet');
    }
    if (accountHolderName.isNotEmpty) {
      buf.writeln('🧾 *Titular da Conta:* $accountHolderName');
    }
    buf.writeln(
      '📊 *% Rateio:* ${_fmtPct(utilityAllocationPercent)}  |  🏷️ *Deságio:* *${_fmtPct(clientDiscountPercent)}*  |  🔋 *Saldo Acumulado:* *${_fmtInt(accumulatedBalanceKwh)} kWh*',
    );

    if (injectedLines.isNotEmpty) {
      buf.writeln('');
      buf.writeln('⚡ *Explosão da Fatura (${injectedLines.length} linhas somadas):*');
      for (final line in injectedLines) {
        buf.writeln(
          '   • [${line.regime}] ${line.label}: *${_fmtInt(line.kwh)} kWh* (- ${_fmtCurrency(line.valueRs)})',
        );
      }
    }

    buf.writeln('');
    buf.writeln('🧾 *Resumo do Demonstrativo / Boleto $brandName*');
    buf.writeln('━━━━━━━━━━━━━━━━━━━━');
    buf.writeln('⚡ Energia Injetada Total (${_fmtInt(totalInjectedKwh)} kWh): *${_fmtCurrency(totalInjectedGrossValueRs)}*');
    buf.writeln('⚖️ (-) Ajuste GD II (Lei 14.300/22): *- ${_fmtCurrency(gdAdjustmentValueRs)}*');
    buf.writeln('💎 (=) Crédito Líquido Abatido na Fatura: *${_fmtCurrency(netCompensatedCreditRs)}*');
    buf.writeln('🏷️ (-) Deságio do Cliente (${_fmtPct(clientDiscountPercent)}): *- ${_fmtCurrency(discountAmountRs)}*');
    buf.writeln('');
    buf.writeln('💵 *O valor a pagar para $brandName é de:* *${_fmtCurrency(solarCompanyAmountToPayRs)}*');
    buf.writeln('🏛️ *O valor a pagar para Energisa é de:* ${_fmtCurrency(utilityBillTotalToPayRs)}');
    buf.writeln('✅ *O valor final COM a $brandName é de:* *${_fmtCurrency(totalWithSolarCompanyRs)}*');
    buf.writeln('📄 *O valor final SEM a $brandName SERIA de:* ${_fmtCurrency(totalWithoutSolarCompanyRs)}');
    buf.writeln('');
    buf.writeln('🎉 *Você economizou este mês:* *${_fmtCurrency(monthlySavingsRs)}*');
    buf.writeln('📈 *Economia Anual neste ritmo:* *${_fmtCurrency(annualProjectedSavingsRs)} / ANO*');
    buf.writeln('━━━━━━━━━━━━━━━━━━━━');
    buf.writeln('👇 *Escolha uma opção abaixo para continuar:*');
    return buf.toString();
  }

  /// Botões pré-definidos para o agente no WhatsApp
  static List<Map<String, String>> predefinedButtons() => const [
        {
          'id': 'GD_GERAR_BOLETO',
          'title': 'GERAR BOLETO',
          'description': 'Gera o boleto demonstrativo em PDF e envia no WhatsApp',
        },
        {
          'id': 'GD_GERAR_PROPOSTA',
          'title': 'GERAR PROPOSTA PARA ESTA CONTA',
          'description': 'Segue o fluxo normal de proposta comercial',
        },
        {
          'id': 'GD_CANCELAR',
          'title': 'CANCELAR',
          'description': 'Cancela e reseta a conversa a qualquer hora',
        },
      ];
}

double _toDouble(dynamic value, {double fallback = 0.0}) {
  if (value == null) return fallback;
  if (value is num) return value.toDouble();
  final clean = value.toString().replaceAll('R\$', '').replaceAll(' ', '').replaceAll('.', '').replaceAll(',', '.');
  return double.tryParse(clean) ?? fallback;
}

double _normalizePercent(double raw) {
  if (raw > 0 && raw < 1) return raw * 100.0;
  return raw;
}

String _fmtCurrency(double v) {
  final fixed = v.toStringAsFixed(2);
  final parts = fixed.split('.');
  final intPart = parts[0];
  final decPart = parts[1];
  final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
  final formattedInt = intPart.replaceAllMapped(reg, (m) => '${m[1]}.');
  return 'R\$ $formattedInt,$decPart';
}

String _fmtInt(double v) {
  final intVal = v.round().toString();
  final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
  return intVal.replaceAllMapped(reg, (m) => '${m[1]}.');
}

String _fmtPct(double v) => '${v.toStringAsFixed(2).replaceAll('.', ',')}%';

String _defaultRefMonth() {
  const months = [
    'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
    'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
  ];
  final now = DateTime.now();
  return '${months[now.month - 1]} / ${now.year}';
}
