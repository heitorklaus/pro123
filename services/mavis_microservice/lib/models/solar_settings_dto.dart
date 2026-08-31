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
  final List<SolarFinancingBankDTO> financingBanks;

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
    this.coverImageUrl = 'https://firebasestorage.googleapis.com/v0/b/solardino-aea02.appspot.com/o/capas%2Fenergiasolar%2Fmodelo_proposta_3.jpg?alt=media',
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
  });

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
      concessionaireName: map['concessionaireName']?.toString() ?? 'Energisa',
      kwhTariffRate: (map['kwhTariffRate'] as num?)?.toDouble() ?? 1.05,
      annualTariffInflation: (map['annualTariffInflation'] as num?)?.toDouble() ?? 5.0,
      simultaneityFactor: (map['simultaneityFactor'] as num?)?.toDouble() ?? 13.0,
      companyName: map['companyName']?.toString() ?? 'Soli Energia Solar',
      companyCnpj: map['companyCnpj']?.toString() ?? '42.117.511/0001-38',
      companyPhone: map['companyPhone']?.toString() ?? '(92) 99999-9999',
      companyWebsite: map['companyWebsite']?.toString() ?? 'www.solienergiasolar.com.br',
      companyInstagram: map['companyInstagram']?.toString() ?? '@solienergiasolar',
      coverImageUrl: map['coverImageUrl']?.toString() ??
          'https://firebasestorage.googleapis.com/v0/b/solardino-aea02.appspot.com/o/capas%2Fenergiasolar%2Fmodelo_proposta_3.jpg?alt=media',
    );
  }
}
