import 'dart:math' as math;

/// Modelo de Banco / Financeira para simulação de financiamento solar
class SolarFinancingBank {
  final String id;
  final String name;
  final String? logoUrl;
  final double monthlyInterestRate; // Taxa ao mês em % (ex: 1.19)
  final List<int> enabledInstallments; // Prazos habilitados (ex: [12, 24, 36, 48, 60, 72, 84, 90])
  final bool isActive;

  const SolarFinancingBank({
    required this.id,
    required this.name,
    this.logoUrl,
    required this.monthlyInterestRate,
    required this.enabledInstallments,
    this.isActive = true,
  });

  /// Calcula o valor da parcela usando a fórmula PMT padrão de juros compostos
  double calculateInstallment(double principal, int months) {
    if (principal <= 0 || months <= 0) return 0.0;
    if (monthlyInterestRate <= 0) return principal / months;
    final i = monthlyInterestRate / 100.0;
    final factor = math.pow(1 + i, months).toDouble();
    return principal * (i * factor) / (factor - 1);
  }

  SolarFinancingBank copyWith({
    String? id,
    String? name,
    String? logoUrl,
    double? monthlyInterestRate,
    List<int>? enabledInstallments,
    bool? isActive,
  }) {
    return SolarFinancingBank(
      id: id ?? this.id,
      name: name ?? this.name,
      logoUrl: logoUrl ?? this.logoUrl,
      monthlyInterestRate: monthlyInterestRate ?? this.monthlyInterestRate,
      enabledInstallments: enabledInstallments ?? this.enabledInstallments,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'logoUrl': logoUrl,
      'monthlyInterestRate': monthlyInterestRate,
      'enabledInstallments': enabledInstallments,
      'isActive': isActive,
    };
  }

  factory SolarFinancingBank.fromMap(Map<String, dynamic> map) {
    return SolarFinancingBank(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? 'Banco',
      logoUrl: map['logoUrl'] as String?,
      monthlyInterestRate: (map['monthlyInterestRate'] as num?)?.toDouble() ?? 1.29,
      enabledInstallments: (map['enabledInstallments'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          [12, 24, 36, 48, 60],
      isActive: map['isActive'] as bool? ?? true,
    );
  }

  static List<SolarFinancingBank> defaultBanks() {
    return const [
      SolarFinancingBank(
        id: 'solfacil',
        name: 'SolFácil',
        monthlyInterestRate: 1.25,
        enabledInstallments: [12, 24, 36, 48, 60],
        isActive: true,
      ),
      SolarFinancingBank(
        id: 'santander',
        name: 'Santander',
        monthlyInterestRate: 1.19,
        enabledInstallments: [12, 24, 36, 48, 60],
        isActive: true,
      ),
      SolarFinancingBank(
        id: 'sicredi',
        name: 'Sicredi',
        monthlyInterestRate: 1.15,
        enabledInstallments: [12, 24, 36, 60, 90],
        isActive: true,
      ),
      SolarFinancingBank(
        id: 'bv',
        name: 'BV Financeira',
        monthlyInterestRate: 1.09,
        enabledInstallments: [12, 24, 36, 48, 60],
        isActive: true,
      ),
    ];
  }
}

/// Taxa e configuração de parcelamento em cartão de crédito
class CreditCardInstallmentRate {
  final int installment; // 1 a 18
  final double feePercentage; // Taxa total em % para esse parcelamento
  final bool isActive;

  const CreditCardInstallmentRate({
    required this.installment,
    required this.feePercentage,
    this.isActive = true,
  });

  double calculateInstallmentValue(double principal) {
    if (principal <= 0 || installment <= 0) return 0.0;
    final total = principal * (1 + (feePercentage / 100.0));
    return total / installment;
  }

  Map<String, dynamic> toMap() => {
        'installment': installment,
        'feePercentage': feePercentage,
        'isActive': isActive,
      };

  factory CreditCardInstallmentRate.fromMap(Map<String, dynamic> map) {
    return CreditCardInstallmentRate(
      installment: (map['installment'] as num?)?.toInt() ?? 1,
      feePercentage: (map['feePercentage'] as num?)?.toDouble() ?? 0.0,
      isActive: map['isActive'] as bool? ?? true,
    );
  }

  static List<CreditCardInstallmentRate> defaultRates() {
    return const [
      CreditCardInstallmentRate(installment: 1, feePercentage: 0.0),
      CreditCardInstallmentRate(installment: 2, feePercentage: 3.5),
      CreditCardInstallmentRate(installment: 3, feePercentage: 6.3),
      CreditCardInstallmentRate(installment: 4, feePercentage: 7.2),
      CreditCardInstallmentRate(installment: 5, feePercentage: 8.1),
      CreditCardInstallmentRate(installment: 6, feePercentage: 8.76),
      CreditCardInstallmentRate(installment: 7, feePercentage: 9.8),
      CreditCardInstallmentRate(installment: 8, feePercentage: 10.5),
      CreditCardInstallmentRate(installment: 9, feePercentage: 11.23),
      CreditCardInstallmentRate(installment: 10, feePercentage: 12.1),
      CreditCardInstallmentRate(installment: 11, feePercentage: 12.8),
      CreditCardInstallmentRate(installment: 12, feePercentage: 13.08),
    ];
  }
}

/// Item anual da simulação de conta de energia
class EnergyBillYearItem {
  final int year;
  final double withSolarMin;
  final double withSolarMax;
  final double withoutSolar;

  const EnergyBillYearItem({
    required this.year,
    required this.withSolarMin,
    required this.withSolarMax,
    required this.withoutSolar,
  });
}

/// Modelo Completo de Configurações do Ramo Usina Solar
class SolarSettingsModel {
  final String utilityCompany; // Concessionária (ex: Amazonas, Energisa, Enel, CPFL, Cemig...)
  final double energyTariff; // Tarifa R$/kWh (ex: 1.125)
  final double fioBTariff; // Fio B / Taxa de rede R$/kWh (ex: 0.28)
  final double simultaneityRate; // % de simultaneidade (ex: 13.0)
  final double annualInflation; // % de inflação anual da energia (ex: 5.0)
  final int projectionYears; // Anos de projeção (ex: 20 ou 25 anos)
  final double defaultSunHours; // HSP médio diário (ex: 4.8)
  final List<SolarFinancingBank> financingBanks;
  final List<CreditCardInstallmentRate> creditCardRates;
  final String selectedCoverTemplate; // ex: 'capa-1.jpeg'
  final String selectedSvgTheme; // Armazena a cor/tema (ex: '#2563EB' ou 'azul_royal')
  final String webBackgroundTemplate; // ex: 'AdobeStock_1030854734.jpg'
  final String? companyName;
  final String? companyDocument;
  final String? companyPhone;
  final String? companyWebsite;
  final String? companyInstagram;
  final String? companySlogan; // ex: 'Energia que Transforma'

  // Getters para compatibilidade retroativa
  String get selectedSvgHeader => selectedSvgTheme;
  String get selectedSvgFooter => selectedSvgTheme;

  /// Lista de todos os 34 papéis de parede em alta resolução para a Proposta Web
  static const List<String> availableWebBackgrounds = [
    'AdobeStock_1030854734.jpg',
    'AdobeStock_1063373137.jpg',
    'AdobeStock_1068541528.jpg',
    'AdobeStock_1069629961.jpg',
    'AdobeStock_1082859153.jpg',
    'AdobeStock_1112102843.jpg',
    'AdobeStock_1118255841.jpg',
    'AdobeStock_1120115310.jpg',
    'AdobeStock_1125570181.jpg',
    'AdobeStock_1164262430.jpg',
    'AdobeStock_1176157580.jpg',
    'AdobeStock_1187954830.jpg',
    'AdobeStock_1189457356.jpg',
    'AdobeStock_1193597432.jpg',
    'AdobeStock_1204356135.jpg',
    'AdobeStock_1215761001.jpg',
    'AdobeStock_1223719368.jpg',
    'AdobeStock_1247773962.jpg',
    'AdobeStock_1259926111.jpg',
    'AdobeStock_1288787002.jpg',
    'AdobeStock_1310256944.jpg',
    'AdobeStock_1310260953.jpg',
    'AdobeStock_1332131708.jpg',
    'AdobeStock_1378554669.jpg',
    'AdobeStock_1463615955.jpg',
    'AdobeStock_229285539.jpg',
    'AdobeStock_359002997.jpg',
    'AdobeStock_414986171.jpg',
    'AdobeStock_485578686.jpg',
    'AdobeStock_700923583.jpg',
    'AdobeStock_790069273.jpg',
    'AdobeStock_863610560.jpg',
    'AdobeStock_986162055.jpg',
    'AdobeStock_996874425.jpg',
  ];

  /// Retorna o valor numérico inteiro (0xFFRRGGBB) da cor tema selecionada
  int get themeColorValue {
    final t = selectedSvgTheme.trim();
    if (t.startsWith('#')) {
      final hex = t.replaceAll('#', '');
      if (hex.length == 6) return int.tryParse('FF$hex', radix: 16) ?? 0xFF2563EB;
      if (hex.length == 8) return int.tryParse(hex, radix: 16) ?? 0xFF2563EB;
    }
    if (t.contains('yellow') || t.contains('amarelo')) return 0xFFF59E0B;
    if (t.contains('laranja') || t.contains('orange')) return 0xFFF97316;
    if (t.contains('grem') || t.contains('verde_claro')) return 0xFF10B981;
    if (t.contains('verde')) return 0xFF059669;
    if (t.contains('purple') || t.contains('roxo')) return 0xFF8B5CF6;
    if (t.contains('red') || t.contains('vermelho')) return 0xFFEF4444;
    if (t.contains('black') || t.contains('preto')) return 0xFF0F172A;
    if (t.contains('light_blue') || t.contains('azul_claro')) return 0xFF0EA5E9;
    if (t.contains('dark_blue') || t.contains('azul_preto')) return 0xFF1E3A8A;
    return 0xFF2563EB; // Azul Royal Padrão
  }

  /// Retorna o código hexadecimal (#RRGGBB) da cor tema
  String get themeColorHex {
    final val = themeColorValue;
    return '#${val.toRadixString(16).substring(2).toUpperCase()}';
  }

  const SolarSettingsModel({
    this.utilityCompany = 'Amazonas Energia',
    this.energyTariff = 1.125,
    this.fioBTariff = 0.28,
    this.simultaneityRate = 13.0,
    this.annualInflation = 5.0,
    this.projectionYears = 21,
    this.defaultSunHours = 4.8,
    this.financingBanks = const [],
    this.creditCardRates = const [],
    this.selectedCoverTemplate = 'capa-1.jpeg',
    this.selectedSvgTheme = '#2563EB',
    this.webBackgroundTemplate = 'AdobeStock_1030854734.jpg',
    this.companyName = 'Soli Energia Solar',
    this.companyDocument = '42.117.511/0001-38',
    this.companyPhone = '(92) 99999-9999',
    this.companyWebsite = 'www.solienergiasolar.com.br',
    this.companyInstagram = '@solienergiasolar',
    this.companySlogan = 'Energia que Transforma',
  });

  /// Gera a simulação ano a ano comparando Com Solar vs Sem Solar
  List<EnergyBillYearItem> calculateYearlySimulation({
    required double monthlyKwh,
    required double systemKwp,
  }) {
    final list = <EnergyBillYearItem>[];
    final currentYear = DateTime.now().year;
    final totalYears = projectionYears.clamp(10, 30);

    double currentTariff = energyTariff > 0 ? energyTariff : 1.125;
    final infl = (annualInflation > 0 ? annualInflation : 5.0) / 100.0;
    final simRate = (simultaneityRate > 0 ? simultaneityRate : 13.0) / 100.0;

    for (int i = 0; i < totalYears; i++) {
      final year = currentYear + i;
      final baseWithoutSolar = monthlyKwh * currentTariff;

      // Com solar: paga taxa de disponibilidade/fio B + consumo não simultâneo residual
      final directSelfConsumption = monthlyKwh * simRate;
      final gridInjectedKwh = monthlyKwh - directSelfConsumption;
      
      // Variação mínima e máxima considerando fio B progressivo e iluminação pública
      final minBill = (gridInjectedKwh * fioBTariff * 0.55) + 65.0;
      final maxBill = (gridInjectedKwh * fioBTariff * 0.85) + 95.0;

      list.add(EnergyBillYearItem(
        year: year,
        withSolarMin: minBill * math.pow(1 + (infl * 0.7), i),
        withSolarMax: maxBill * math.pow(1 + (infl * 0.7), i),
        withoutSolar: baseWithoutSolar,
      ));

      // Atualiza tarifa com inflação anual
      currentTariff *= (1 + infl);
    }

    return list;
  }

  SolarSettingsModel copyWith({
    String? utilityCompany,
    double? energyTariff,
    double? fioBTariff,
    double? simultaneityRate,
    double? annualInflation,
    int? projectionYears,
    double? defaultSunHours,
    List<SolarFinancingBank>? financingBanks,
    List<CreditCardInstallmentRate>? creditCardRates,
    String? selectedCoverTemplate,
    String? selectedSvgTheme,
    String? webBackgroundTemplate,
    String? companyName,
    String? companyDocument,
    String? companyPhone,
    String? companyWebsite,
    String? companyInstagram,
    String? companySlogan,
  }) {
    return SolarSettingsModel(
      utilityCompany: utilityCompany ?? this.utilityCompany,
      energyTariff: energyTariff ?? this.energyTariff,
      fioBTariff: fioBTariff ?? this.fioBTariff,
      simultaneityRate: simultaneityRate ?? this.simultaneityRate,
      annualInflation: annualInflation ?? this.annualInflation,
      projectionYears: projectionYears ?? this.projectionYears,
      defaultSunHours: defaultSunHours ?? this.defaultSunHours,
      financingBanks: financingBanks ?? this.financingBanks,
      creditCardRates: creditCardRates ?? this.creditCardRates,
      selectedCoverTemplate: selectedCoverTemplate ?? this.selectedCoverTemplate,
      selectedSvgTheme: selectedSvgTheme ?? this.selectedSvgTheme,
      webBackgroundTemplate: webBackgroundTemplate ?? this.webBackgroundTemplate,
      companyName: companyName ?? this.companyName,
      companyDocument: companyDocument ?? this.companyDocument,
      companyPhone: companyPhone ?? this.companyPhone,
      companyWebsite: companyWebsite ?? this.companyWebsite,
      companyInstagram: companyInstagram ?? this.companyInstagram,
      companySlogan: companySlogan ?? this.companySlogan,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'utilityCompany': utilityCompany,
      'energyTariff': energyTariff,
      'fioBTariff': fioBTariff,
      'simultaneityRate': simultaneityRate,
      'annualInflation': annualInflation,
      'projectionYears': projectionYears,
      'defaultSunHours': defaultSunHours,
      'financingBanks': financingBanks.map((b) => b.toMap()).toList(),
      'creditCardRates': creditCardRates.map((c) => c.toMap()).toList(),
      'selectedCoverTemplate': selectedCoverTemplate,
      'selectedSvgTheme': selectedSvgTheme,
      'webBackgroundTemplate': webBackgroundTemplate,
      'companyName': companyName,
      'companyDocument': companyDocument,
      'companyPhone': companyPhone,
      'companyWebsite': companyWebsite,
      'companyInstagram': companyInstagram,
      'companySlogan': companySlogan,
    };
  }

  factory SolarSettingsModel.fromMap(Map<String, dynamic> map) {
    return SolarSettingsModel(
      utilityCompany: map['utilityCompany'] as String? ?? 'Amazonas Energia',
      energyTariff: (map['energyTariff'] as num?)?.toDouble() ?? 1.125,
      fioBTariff: (map['fioBTariff'] as num?)?.toDouble() ?? 0.28,
      simultaneityRate: (map['simultaneityRate'] as num?)?.toDouble() ?? 13.0,
      annualInflation: (map['annualInflation'] as num?)?.toDouble() ?? 5.0,
      projectionYears: (map['projectionYears'] as num?)?.toInt() ?? 21,
      defaultSunHours: (map['defaultSunHours'] as num?)?.toDouble() ?? 4.8,
      financingBanks: map['financingBanks'] is List
          ? (map['financingBanks'] as List)
              .whereType<Map>()
              .map((e) => SolarFinancingBank.fromMap(Map<String, dynamic>.from(e)))
              .toList()
          : SolarFinancingBank.defaultBanks(),
      creditCardRates: map['creditCardRates'] is List
          ? (map['creditCardRates'] as List)
              .whereType<Map>()
              .map((e) => CreditCardInstallmentRate.fromMap(Map<String, dynamic>.from(e)))
              .toList()
          : CreditCardInstallmentRate.defaultRates(),
      selectedCoverTemplate: map['selectedCoverTemplate'] as String? ?? 'capa-1.jpeg',
      selectedSvgTheme: (map['selectedSvgTheme'] ?? map['selectedSvgFooter'] ?? map['selectedSvgHeader']) as String? ?? '#2563EB',
      webBackgroundTemplate: map['webBackgroundTemplate'] as String? ?? 'AdobeStock_1030854734.jpg',
      companyName: map['companyName'] as String? ?? 'Soli Energia Solar',
      companyDocument: map['companyDocument'] as String? ?? '42.117.511/0001-38',
      companyPhone: map['companyPhone'] as String? ?? '(92) 99999-9999',
      companyWebsite: map['companyWebsite'] as String? ?? 'www.solienergiasolar.com.br',
      companyInstagram: map['companyInstagram'] as String? ?? '@solienergiasolar',
      companySlogan: map['companySlogan'] as String? ?? 'Energia que Transforma',
    );
  }

  static SolarSettingsModel initial() {
    return SolarSettingsModel(
      financingBanks: SolarFinancingBank.defaultBanks(),
      creditCardRates: CreditCardInstallmentRate.defaultRates(),
    );
  }
}
