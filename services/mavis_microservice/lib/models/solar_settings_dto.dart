import 'dart:math' as math;

class SolarFinancingBankDTO {
  final String id;
  final String name;
  final double monthlyInterestRate;
  final List<int> enabledInstallments;
  final bool isActive;

  const SolarFinancingBankDTO({
    required this.id,
    required this.name,
    required this.monthlyInterestRate,
    required this.enabledInstallments,
    this.isActive = true,
  });

  double calculateInstallment(double principal, int months) {
    if (principal <= 0 || months <= 0) return 0.0;
    if (monthlyInterestRate <= 0) return principal / months;
    final i = monthlyInterestRate / 100.0;
    final factor = math.pow(1 + i, months).toDouble();
    return principal * (i * factor) / (factor - 1);
  }
}

class YearlySimulationItemDTO {
  final int year;
  final double withoutSolar;
  final double withSolarMin;
  final double withSolarMax;

  const YearlySimulationItemDTO({
    required this.year,
    required this.withoutSolar,
    required this.withSolarMin,
    required this.withSolarMax,
  });
}

class SolarSettingsDTO {
  final int themeColorValue;
  final String concessionaireName;
  final double kwhTariffRate;
  final double annualTariffInflation;
  final double simultaneityFactor;
  final String companyName;
  final String companyCnpj;
  final String companyPhone;
  final String companyWebsite;
  final String companyInstagram;
  final String? coverImageUrl;
  final String selectedCoverTemplate;
  final List<SolarFinancingBankDTO> financingBanks;

  // Propriedades da Capa e Logo
  final String coverTitle;
  final String coverSubtitle;
  final bool coverShowBadge;
  final String coverBadgeColor;
  final double coverBadgeOpacity;
  final String coverTitleColor;
  final String coverSubtitleColor;
  final double coverTitleFontSize;
  final double coverSubtitleFontSize;
  final double coverBadgePositionX;
  final double coverBadgePositionY;
  final String? companyLogoBase64;
  final bool coverShowLogo;
  final double coverLogoPositionX;
  final double coverLogoPositionY;
  final double coverLogoWidth;
  final bool isCustomCoverMode;
  final String? customCoverImageBase64;

  const SolarSettingsDTO({
    this.themeColorValue = 0xFF0284C7,
    this.concessionaireName = 'Energisa',
    this.kwhTariffRate = 1.05,
    this.annualTariffInflation = 5.0,
    this.simultaneityFactor = 13.0,
    this.companyName = 'Soli Energia Solar',
    this.companyCnpj = '42.117.511/0001-38',
    this.companyPhone = '(92) 99999-9999',
    this.companyWebsite = 'www.solienergiasolar.com.br',
    this.companyInstagram = '@solienergiasolar',
    this.coverImageUrl,
    this.selectedCoverTemplate = 'modelo_proposta_64.jpg',
    this.financingBanks = const [
      SolarFinancingBankDTO(
        id: 'solfacil',
        name: 'SolFácil',
        monthlyInterestRate: 1.25,
        enabledInstallments: [12, 24, 36, 48, 60, 72, 84, 90],
      ),
      SolarFinancingBankDTO(
        id: 'santander',
        name: 'Santander',
        monthlyInterestRate: 1.19,
        enabledInstallments: [12, 24, 36, 48, 60, 72, 84],
      ),
      SolarFinancingBankDTO(
        id: 'sicredi',
        name: 'Sicredi',
        monthlyInterestRate: 1.15,
        enabledInstallments: [12, 24, 36, 48, 60, 72, 90],
      ),
      SolarFinancingBankDTO(
        id: 'bv',
        name: 'BV Financeira',
        monthlyInterestRate: 1.09,
        enabledInstallments: [12, 24, 36, 48, 60, 72],
      ),
    ],
    this.coverTitle = 'PROPOSTA COMERCIAL',
    this.coverSubtitle = 'ENERGIA SOLAR FOTOVOLTAICA',
    this.coverShowBadge = true,
    this.coverBadgeColor = '#FFFFFF',
    this.coverBadgeOpacity = 0.92,
    this.coverTitleColor = '#0284C7',
    this.coverSubtitleColor = '#0F172A',
    this.coverTitleFontSize = 13.0,
    this.coverSubtitleFontSize = 8.5,
    this.coverBadgePositionX = 0.08,
    this.coverBadgePositionY = 0.06,
    this.companyLogoBase64,
    this.coverShowLogo = false,
    this.coverLogoPositionX = 0.72,
    this.coverLogoPositionY = 0.70,
    this.coverLogoWidth = 90.0,
    this.isCustomCoverMode = false,
    this.customCoverImageBase64,
  });

  String get effectiveCoverUrl {
    if (coverImageUrl != null && coverImageUrl!.isNotEmpty) return coverImageUrl!;
    final clean = selectedCoverTemplate
        .replaceFirst('assets/modelo_propostas/', '')
        .replaceFirst('capas/energiasolar/', '');
    final encoded = Uri.encodeComponent('capas/energiasolar/$clean');
    return 'https://firebasestorage.googleapis.com/v0/b/solardino-aea02.appspot.com/o/$encoded?alt=media';
  }

  int get coverBadgeColorValue {
    final hex = coverBadgeColor.replaceAll('#', '').trim();
    if (hex.length == 6) return int.tryParse('FF$hex', radix: 16) ?? 0xFFFFFFFF;
    if (hex.length == 8) return int.tryParse(hex, radix: 16) ?? 0xFFFFFFFF;
    return 0xFFFFFFFF;
  }

  int get coverTitleColorValue {
    final hex = coverTitleColor.replaceAll('#', '').trim();
    if (hex.length == 6) return int.tryParse('FF$hex', radix: 16) ?? 0xFF0284C7;
    if (hex.length == 8) return int.tryParse(hex, radix: 16) ?? 0xFF0284C7;
    return 0xFF0284C7;
  }

  int get coverSubtitleColorValue {
    final hex = coverSubtitleColor.replaceAll('#', '').trim();
    if (hex.length == 6) return int.tryParse('FF$hex', radix: 16) ?? 0xFF0F172A;
    if (hex.length == 8) return int.tryParse(hex, radix: 16) ?? 0xFF0F172A;
    return 0xFF0F172A;
  }

  List<YearlySimulationItemDTO> calculateYearlySimulation({
    required double monthlyKwh,
    required double systemKwp,
    int startYear = 2026,
    int totalYears = 20,
  }) {
    final list = <YearlySimulationItemDTO>[];
    final inflationDecimal = annualTariffInflation / 100.0;
    double currentTariff = kwhTariffRate;

    for (int i = 0; i < totalYears; i++) {
      final year = startYear + i;
      final withoutSolar = monthlyKwh * currentTariff;
      final availabilityFee = 50.0 * currentTariff;
      final withSolarMin = availabilityFee * 1.1;
      final withSolarMax = (withoutSolar * 0.15) + availabilityFee;

      list.add(YearlySimulationItemDTO(
        year: year,
        withoutSolar: withoutSolar,
        withSolarMin: withSolarMin,
        withSolarMax: withSolarMax,
      ));

      currentTariff *= (1 + inflationDecimal);
    }
    return list;
  }

  factory SolarSettingsDTO.fromMap(Map<String, dynamic> map) {
    return SolarSettingsDTO(
      themeColorValue: (map['themeColorValue'] as num?)?.toInt() ?? 0xFF0284C7,
      concessionaireName: map['concessionaireName']?.toString() ?? map['utilityCompany']?.toString() ?? 'Energisa',
      kwhTariffRate: (map['kwhTariffRate'] as num?)?.toDouble() ?? (map['energyTariff'] as num?)?.toDouble() ?? 1.05,
      annualTariffInflation: (map['annualTariffInflation'] as num?)?.toDouble() ?? (map['annualInflation'] as num?)?.toDouble() ?? 5.0,
      simultaneityFactor: (map['simultaneityFactor'] as num?)?.toDouble() ?? (map['simultaneityRate'] as num?)?.toDouble() ?? 13.0,
      companyName: map['companyName']?.toString() ?? 'Soli Energia Solar',
      companyCnpj: map['companyCnpj']?.toString() ?? map['companyDocument']?.toString() ?? '42.117.511/0001-38',
      companyPhone: map['companyPhone']?.toString() ?? '(92) 99999-9999',
      companyWebsite: map['companyWebsite']?.toString() ?? 'www.solienergiasolar.com.br',
      companyInstagram: map['companyInstagram']?.toString() ?? '@solienergiasolar',
      coverImageUrl: map['coverImageUrl']?.toString(),
      selectedCoverTemplate: map['selectedCoverTemplate']?.toString() ?? 'modelo_proposta_64.jpg',
      coverTitle: map['coverTitle']?.toString() ?? 'PROPOSTA COMERCIAL',
      coverSubtitle: map['coverSubtitle']?.toString() ?? 'ENERGIA SOLAR FOTOVOLTAICA',
      coverShowBadge: map['coverShowBadge'] as bool? ?? true,
      coverBadgeColor: map['coverBadgeColor']?.toString() ?? '#FFFFFF',
      coverBadgeOpacity: (map['coverBadgeOpacity'] as num?)?.toDouble() ?? 0.92,
      coverTitleColor: map['coverTitleColor']?.toString() ?? '#0284C7',
      coverSubtitleColor: map['coverSubtitleColor']?.toString() ?? '#0F172A',
      coverTitleFontSize: (map['coverTitleFontSize'] as num?)?.toDouble() ?? 13.0,
      coverSubtitleFontSize: (map['coverSubtitleFontSize'] as num?)?.toDouble() ?? 8.5,
      coverBadgePositionX: (map['coverBadgePositionX'] as num?)?.toDouble() ?? 0.08,
      coverBadgePositionY: (map['coverBadgePositionY'] as num?)?.toDouble() ?? 0.06,
      companyLogoBase64: map['companyLogoBase64']?.toString(),
      coverShowLogo: map['coverShowLogo'] as bool? ?? (map['companyLogoBase64'] != null),
      coverLogoPositionX: (map['coverLogoPositionX'] as num?)?.toDouble() ?? 0.72,
      coverLogoPositionY: (map['coverLogoPositionY'] as num?)?.toDouble() ?? 0.70,
      coverLogoWidth: (map['coverLogoWidth'] as num?)?.toDouble() ?? 90.0,
      isCustomCoverMode: map['isCustomCoverMode'] as bool? ?? false,
      customCoverImageBase64: map['customCoverImageBase64']?.toString(),
    );
  }
}

