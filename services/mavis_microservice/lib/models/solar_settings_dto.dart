import 'dart:convert';
import 'dart:math' as math;

class SolarFinancingBankDTO {
  final String id;
  final String name;
  final String? logoUrl;
  final String? logoBase64;
  final double monthlyInterestRate;
  final List<int> enabledInstallments;
  final bool isActive;

  const SolarFinancingBankDTO({
    required this.id,
    required this.name,
    this.logoUrl,
    this.logoBase64,
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

  factory SolarFinancingBankDTO.fromMap(Map<String, dynamic> map) {
    return SolarFinancingBankDTO(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Banco',
      logoUrl: map['logoUrl']?.toString(),
      logoBase64: map['logoBase64']?.toString(),
      monthlyInterestRate: (map['monthlyInterestRate'] as num?)?.toDouble() ?? 1.29,
      enabledInstallments: (map['enabledInstallments'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          [12, 24, 36, 48, 60],
      isActive: map['isActive'] as bool? ?? true,
    );
  }

  static List<SolarFinancingBankDTO> defaultBanks() {
    return const [
      SolarFinancingBankDTO(
        id: 'solfacil',
        name: 'SolFácil',
        monthlyInterestRate: 1.25,
        enabledInstallments: [12, 24, 36, 48, 60],
        isActive: true,
      ),
      SolarFinancingBankDTO(
        id: 'santander',
        name: 'Santander',
        monthlyInterestRate: 1.19,
        enabledInstallments: [12, 24, 36, 48, 60],
        isActive: true,
      ),
      SolarFinancingBankDTO(
        id: 'sicredi',
        name: 'Sicredi',
        monthlyInterestRate: 1.15,
        enabledInstallments: [12, 24, 36, 60, 90],
        isActive: true,
      ),
      SolarFinancingBankDTO(
        id: 'bv',
        name: 'BV Financeira',
        monthlyInterestRate: 1.09,
        enabledInstallments: [12, 24, 36, 48, 60],
        isActive: true,
      ),
    ];
  }
}

class CreditCardInstallmentRateDTO {
  final int installment;
  final double feePercentage;
  final bool isActive;

  const CreditCardInstallmentRateDTO({
    required this.installment,
    required this.feePercentage,
    this.isActive = true,
  });

  double calculateInstallmentValue(double principal) {
    if (principal <= 0 || installment <= 0) return 0.0;
    final total = principal * (1 + (feePercentage / 100.0));
    return total / installment;
  }

  factory CreditCardInstallmentRateDTO.fromMap(Map<String, dynamic> map) {
    return CreditCardInstallmentRateDTO(
      installment: (map['installment'] as num?)?.toInt() ?? 1,
      feePercentage: (map['feePercentage'] as num?)?.toDouble() ?? 0.0,
      isActive: map['isActive'] as bool? ?? true,
    );
  }

  static List<CreditCardInstallmentRateDTO> defaultRates() {
    return const [
      CreditCardInstallmentRateDTO(installment: 1, feePercentage: 0.0),
      CreditCardInstallmentRateDTO(installment: 2, feePercentage: 3.5),
      CreditCardInstallmentRateDTO(installment: 3, feePercentage: 6.3),
      CreditCardInstallmentRateDTO(installment: 4, feePercentage: 7.2),
      CreditCardInstallmentRateDTO(installment: 5, feePercentage: 8.1),
      CreditCardInstallmentRateDTO(installment: 6, feePercentage: 8.76),
      CreditCardInstallmentRateDTO(installment: 7, feePercentage: 9.8),
      CreditCardInstallmentRateDTO(installment: 8, feePercentage: 10.5),
      CreditCardInstallmentRateDTO(installment: 9, feePercentage: 11.23),
      CreditCardInstallmentRateDTO(installment: 10, feePercentage: 12.1),
      CreditCardInstallmentRateDTO(installment: 11, feePercentage: 12.8),
      CreditCardInstallmentRateDTO(installment: 12, feePercentage: 13.08),
    ];
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

class CoverFooterBadgeDTO {
  final String iconKey;
  final String label;

  const CoverFooterBadgeDTO({
    required this.iconKey,
    required this.label,
  });

  factory CoverFooterBadgeDTO.fromMap(Map<String, dynamic> map) {
    return CoverFooterBadgeDTO(
      iconKey: map['iconKey']?.toString() ?? 'eco',
      label: map['label']?.toString() ?? '',
    );
  }

  static List<CoverFooterBadgeDTO> defaultBadges() {
    return const [
      CoverFooterBadgeDTO(iconKey: 'eco', label: 'ECONOMIA'),
      CoverFooterBadgeDTO(iconKey: 'bolt', label: 'SUSTENTABILIDADE'),
      CoverFooterBadgeDTO(iconKey: 'chart', label: 'VALORIZAÇÃO'),
    ];
  }
}

class CustomCoverTextItemDTO {
  final String id;
  final String text;
  final double x;
  final double y;
  final double fontSize;
  final int colorValue;
  final bool isBold;

  const CustomCoverTextItemDTO({
    required this.id,
    required this.text,
    required this.x,
    required this.y,
    this.fontSize = 14.0,
    this.colorValue = 0xFF0F172A,
    this.isBold = true,
  });

  factory CustomCoverTextItemDTO.fromMap(Map<String, dynamic> map) {
    return CustomCoverTextItemDTO(
      id: map['id']?.toString() ?? 'txt_${DateTime.now().millisecondsSinceEpoch}',
      text: map['text']?.toString() ?? 'Texto Personalizado',
      x: (map['x'] as num?)?.toDouble() ?? 0.5,
      y: (map['y'] as num?)?.toDouble() ?? 0.5,
      fontSize: (map['fontSize'] as num?)?.toDouble() ?? 14.0,
      colorValue: (map['colorValue'] as num?)?.toInt() ?? 0xFF0F172A,
      isBold: map['isBold'] as bool? ?? true,
    );
  }
}

class CustomCoverIconItemDTO {
  final String id;
  final String iconKey;
  final double x;
  final double y;
  final double size;
  final int colorValue;

  const CustomCoverIconItemDTO({
    required this.id,
    required this.iconKey,
    required this.x,
    required this.y,
    this.size = 28.0,
    this.colorValue = 0xFFEAB308,
  });

  factory CustomCoverIconItemDTO.fromMap(Map<String, dynamic> map) {
    return CustomCoverIconItemDTO(
      id: map['id']?.toString() ?? 'ico_${DateTime.now().millisecondsSinceEpoch}',
      iconKey: map['iconKey']?.toString() ?? 'solar_power',
      x: (map['x'] as num?)?.toDouble() ?? 0.5,
      y: (map['y'] as num?)?.toDouble() ?? 0.5,
      size: (map['size'] as num?)?.toDouble() ?? 28.0,
      colorValue: (map['colorValue'] as num?)?.toInt() ?? 0xFFEAB308,
    );
  }
}

class ProposalPageCardDTO {
  final String id;
  final String title;
  final String description;
  final String iconKey;
  final String colorHex;
  final bool isVisible;
  final int order;
  final String? badgeText;
  final String? cardBgColorHex;
  final String? cardBorderColorHex;

  const ProposalPageCardDTO({
    required this.id,
    required this.title,
    required this.description,
    required this.iconKey,
    this.colorHex = '#0284C7',
    this.isVisible = true,
    this.order = 0,
    this.badgeText,
    this.cardBgColorHex,
    this.cardBorderColorHex,
  });

  factory ProposalPageCardDTO.fromMap(Map<String, dynamic> map) {
    return ProposalPageCardDTO(
      id: map['id']?.toString() ?? 'card_${DateTime.now().millisecondsSinceEpoch}',
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      iconKey: map['iconKey']?.toString() ?? 'light',
      colorHex: map['colorHex']?.toString() ?? '#0284C7',
      isVisible: map['isVisible'] as bool? ?? true,
      order: (map['order'] as num?)?.toInt() ?? 0,
      badgeText: map['badgeText']?.toString(),
      cardBgColorHex: map['cardBgColorHex']?.toString(),
      cardBorderColorHex: map['cardBorderColorHex']?.toString(),
    );
  }
}

class ProposalCustomPageDTO {
  final String id;
  final String title;
  final String subtitle;
  final String bgType;
  final String bgColorHex;
  final String? bgImage;
  final List<ProposalPageCardDTO> cards;

  const ProposalCustomPageDTO({
    required this.id,
    required this.title,
    this.subtitle = '',
    this.bgType = 'white',
    this.bgColorHex = '#FFFFFF',
    this.bgImage,
    this.cards = const [],
  });

  factory ProposalCustomPageDTO.fromMap(Map<String, dynamic> map) {
    return ProposalCustomPageDTO(
      id: map['id']?.toString() ?? 'page_${DateTime.now().millisecondsSinceEpoch}',
      title: map['title']?.toString() ?? 'Nova Página Personalizada',
      subtitle: map['subtitle']?.toString() ?? '',
      bgType: map['bgType']?.toString() ?? 'white',
      bgColorHex: map['bgColorHex']?.toString() ?? '#FFFFFF',
      bgImage: map['bgImage']?.toString(),
      cards: (map['cards'] as List<dynamic>?)
              ?.whereType<Map>()
              .map((e) => ProposalPageCardDTO.fromMap(Map<String, dynamic>.from(e)))
              .toList() ??
          const [],
    );
  }
}

class SolarSettingsDTO {
  final String utilityCompany;
  final double energyTariff;
  final double fioBTariff;
  final double simultaneityRate;
  final bool useDetailedBillingCalc;
  final String defaultConnectionType;
  final double monoAvailabilityKwh;
  final double biAvailabilityKwh;
  final double triAvailabilityKwh;
  final double defaultPublicLightingRs;
  final double annualInflation;
  final int projectionYears;
  final double defaultSunHours;
  final List<SolarFinancingBankDTO> financingBanks;
  final List<CreditCardInstallmentRateDTO> creditCardRates;
  final String selectedCoverTemplate;
  final String selectedSvgTheme;
  final String secondaryThemeColor;
  final int? explicitThemeColorValue;
  final String webBackgroundTemplate;
  final String? coverImageUrl;
  final String companyName;
  final String companyDocument;
  final String companyPhone;
  final String companyWebsite;
  final String companyInstagram;
  final String? companySlogan;

  // Configurações do Editor em Tempo Real de Capa & Retângulo de Título
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
  final String? customCoverImageBase64;
  final int customDividerStyle;
  final String customDividerColor;
  final String customDividerBottomColor;
  final bool isCustomCoverMode;
  final String? companyLogoBase64;
  final bool coverShowLogo;
  final double coverLogoPositionX;
  final double coverLogoPositionY;
  final double coverLogoWidth;

  // Estilo das Propostas (modern, verticalSplit, corporateWave)
  final String proposalStyle;
  final String selectedVerticalSplitTemplate;
  final int verticalSplitDividerType;
  final String verticalSplitHeadline;
  final String verticalSplitSubheadline;
  final String verticalSplitLeftFooter;
  final String verticalSplitRightTitle;
  final String verticalSplitRightSubtitle;
  final String verticalSplitRightTagline;
  final double verticalSplitRightTitleFontSize;
  final double verticalSplitRightSubtitleFontSize;
  final double verticalSplitHeadlineFontSize;
  final String verticalSplitRightFooter;
  final bool verticalSplitShowRightDivider;
  final String verticalSplitRightDividerColor;
  final double verticalSplitRightDividerWidth;
  final double verticalSplitRightDividerHeight;
  final bool verticalSplitShowHeadlineDivider;
  final String verticalSplitHeadlineDividerColor;
  final double verticalSplitHeadlineDividerWidth;
  final double verticalSplitHeadlineDividerHeight;
  final String verticalSplitAccentColor;
  final List<CoverFooterBadgeDTO> verticalSplitFooterBadges;
  final String verticalSplitBadgesLayout;
  final double verticalSplitLeftFooterWidth;

  // Posições Relativas Customizadas dos Blocos (0.0 a 1.0)
  final double verticalSplitHeadlineTop;
  final double verticalSplitHeadlineLeft;
  final double verticalSplitRightBlockTop;
  final double verticalSplitRightBlockRight;
  final double verticalSplitLeftFooterBottom;
  final double verticalSplitLeftFooterLeft;
  final double verticalSplitRightFooterBottom;
  final double verticalSplitRightFooterRight;

  // Visibilidade dos Blocos Pré-definidos da Capa
  final bool verticalSplitShowHeadline;
  final bool verticalSplitShowLeftFooter;
  final bool verticalSplitShowRightBlock;
  final bool verticalSplitShowRightFooter;

  // Tipografia e Cores Customizáveis dos Blocos da Capa
  final String coverHeadlineFont;
  final String coverHeadlineColor;
  final String coverRightBlockFont;
  final String coverRightTitleColor;
  final String coverRightSubtitleColor;
  final String coverRightTaglineColor;
  final String coverBadgesTextColor;
  final String coverBadgesIconColor;
  final String coverFooterFont;
  final String coverFooterColor;
  final List<CustomCoverTextItemDTO> customTextItems;
  final List<CustomCoverIconItemDTO> customIconItems;

  // Bloco de Informações do Cliente & CPF/CNPJ
  final double coverClientInfoPositionX;
  final double coverClientInfoPositionY;
  final double coverClientInfoWidth;
  final double coverClientInfoFontSize;
  final String coverClientInfoColor;
  final String coverClientInfoSecondaryColor;
  final bool coverShowClientInfo;

  // Cabeçalho e Rodapé Customizáveis (10 Estilos)
  final int coverHeaderStyle;
  final bool coverShowHeader;
  final String coverHeaderText1;
  final String coverHeaderText2;
  final String coverHeaderText3;
  final String coverHeaderBgColor;
  final String coverHeaderTextColor;
  final String coverHeaderIconColor;

  final int coverFooterStyle;
  final bool coverShowFooter;
  final String coverFooterText1;
  final String coverFooterText2;
  final String coverFooterText3;
  final String coverFooterText4;
  final String coverFooterBgColor;
  final String coverFooterTextColor;
  final String coverFooterIconColor;

  // Gestão de Páginas, Templates e Cards da Página 2
  final String page2TemplateId;
  final String? page2CardsJson;
  final bool page2ShowIllustration;
  final String page2IllustrationType;
  final String? hiddenPagesJson;
  final String? customPagesJson;
  final String internalPagesLayoutPreset;

  const SolarSettingsDTO({
    this.utilityCompany = 'Amazonas Energia',
    this.energyTariff = 1.125,
    this.fioBTariff = 0.28,
    this.simultaneityRate = 13.0,
    this.useDetailedBillingCalc = false,
    this.defaultConnectionType = 'Bifásico',
    this.monoAvailabilityKwh = 30.0,
    this.biAvailabilityKwh = 50.0,
    this.triAvailabilityKwh = 100.0,
    this.defaultPublicLightingRs = 45.0,
    this.annualInflation = 5.0,
    this.projectionYears = 21,
    this.defaultSunHours = 4.8,
    this.financingBanks = const [
      SolarFinancingBankDTO(
        id: 'solfacil',
        name: 'SolFácil',
        monthlyInterestRate: 1.25,
        enabledInstallments: [12, 24, 36, 48, 60],
      ),
      SolarFinancingBankDTO(
        id: 'santander',
        name: 'Santander',
        monthlyInterestRate: 1.19,
        enabledInstallments: [12, 24, 36, 48, 60],
      ),
      SolarFinancingBankDTO(
        id: 'sicredi',
        name: 'Sicredi',
        monthlyInterestRate: 1.15,
        enabledInstallments: [12, 24, 36, 60, 90],
      ),
      SolarFinancingBankDTO(
        id: 'bv',
        name: 'BV Financeira',
        monthlyInterestRate: 1.09,
        enabledInstallments: [12, 24, 36, 48, 60],
      ),
    ],
    this.creditCardRates = const [
      CreditCardInstallmentRateDTO(installment: 1, feePercentage: 0.0),
      CreditCardInstallmentRateDTO(installment: 2, feePercentage: 3.5),
      CreditCardInstallmentRateDTO(installment: 3, feePercentage: 6.3),
      CreditCardInstallmentRateDTO(installment: 4, feePercentage: 7.2),
      CreditCardInstallmentRateDTO(installment: 5, feePercentage: 8.1),
      CreditCardInstallmentRateDTO(installment: 6, feePercentage: 8.76),
      CreditCardInstallmentRateDTO(installment: 7, feePercentage: 9.8),
      CreditCardInstallmentRateDTO(installment: 8, feePercentage: 10.5),
      CreditCardInstallmentRateDTO(installment: 9, feePercentage: 11.23),
      CreditCardInstallmentRateDTO(installment: 10, feePercentage: 12.1),
      CreditCardInstallmentRateDTO(installment: 11, feePercentage: 12.8),
      CreditCardInstallmentRateDTO(installment: 12, feePercentage: 13.08),
    ],
    this.selectedCoverTemplate = 'modelo_proposta_1.jpg',
    this.selectedSvgTheme = '#2563EB',
    this.secondaryThemeColor = '#102C49',
    this.explicitThemeColorValue,
    this.webBackgroundTemplate = 'AdobeStock_1030854734.jpg',
    this.coverImageUrl,
    this.companyName = '',
    this.companyDocument = '',
    this.companyPhone = '',
    this.companyWebsite = '',
    this.companyInstagram = '',
    this.companySlogan,
    this.coverTitle = 'PROPOSTA COMERCIAL',
    this.coverSubtitle = 'ENERGIA SOLAR FOTOVOLTAICA',
    this.coverShowBadge = true,
    this.coverBadgeColor = '#FFFFFF',
    this.coverBadgeOpacity = 0.92,
    this.coverTitleColor = '#0284C7',
    this.coverSubtitleColor = '#0F172A',
    this.coverTitleFontSize = 26.0,
    this.coverSubtitleFontSize = 11.0,
    this.coverBadgePositionX = 0.08,
    this.coverBadgePositionY = 0.06,
    this.customCoverImageBase64,
    this.customDividerStyle = 0,
    this.customDividerColor = '#0284C7',
    this.customDividerBottomColor = '#FFFFFF',
    this.isCustomCoverMode = false,
    this.companyLogoBase64,
    this.coverShowLogo = true,
    this.coverLogoPositionX = 0.65,
    this.coverLogoPositionY = 0.05,
    this.coverLogoWidth = 90.0,
    this.proposalStyle = 'modern',
    this.selectedVerticalSplitTemplate = 'vertical_split_1',
    this.verticalSplitDividerType = 0,
    this.verticalSplitHeadline = 'ENERGIA\nQUE MOVE\nO SEU\nAMANHÃ',
    this.verticalSplitSubheadline = 'MAIS ECONOMIA.\nMAIS LIBERDADE.\nUM FUTURO SUSTENTÁVEL.',
    this.verticalSplitLeftFooter = 'PESSOAS  -  TECNOLOGIA  -  UM PLANETA MELHOR',
    this.verticalSplitRightTitle = 'PROPOSTA',
    this.verticalSplitRightSubtitle = 'SOLAR',
    this.verticalSplitRightTagline = 'SOLUÇÕES EM ENERGIA\nPARA UM FUTURO MELHOR',
    this.verticalSplitRightTitleFontSize = 18.0,
    this.verticalSplitRightSubtitleFontSize = 46.0,
    this.verticalSplitHeadlineFontSize = 24.0,
    this.verticalSplitRightFooter = 'ENERGIA HOJE.\nMAIS POSSIBILIDADES\nAMANHÃ.',
    this.verticalSplitShowRightDivider = true,
    this.verticalSplitRightDividerColor = '',
    this.verticalSplitRightDividerWidth = 54.0,
    this.verticalSplitRightDividerHeight = 4.5,
    this.verticalSplitShowHeadlineDivider = true,
    this.verticalSplitHeadlineDividerColor = '',
    this.verticalSplitHeadlineDividerWidth = 48.0,
    this.verticalSplitHeadlineDividerHeight = 4.0,
    this.verticalSplitAccentColor = '#EAB308',
    this.verticalSplitFooterBadges = const [
      CoverFooterBadgeDTO(iconKey: 'eco', label: 'ECONOMIA'),
      CoverFooterBadgeDTO(iconKey: 'bolt', label: 'SUSTENTABILIDADE'),
      CoverFooterBadgeDTO(iconKey: 'chart', label: 'VALORIZAÇÃO'),
    ],
    this.verticalSplitBadgesLayout = 'horizontal',
    this.verticalSplitLeftFooterWidth = 0.60,
    this.verticalSplitHeadlineTop = 0.06,
    this.verticalSplitHeadlineLeft = 0.06,
    this.verticalSplitRightBlockTop = 0.20,
    this.verticalSplitRightBlockRight = 0.08,
    this.verticalSplitLeftFooterBottom = 0.04,
    this.verticalSplitLeftFooterLeft = 0.05,
    this.verticalSplitRightFooterBottom = 0.04,
    this.verticalSplitRightFooterRight = 0.08,
    this.verticalSplitShowHeadline = true,
    this.verticalSplitShowLeftFooter = true,
    this.verticalSplitShowRightBlock = true,
    this.verticalSplitShowRightFooter = true,
    this.coverHeadlineFont = 'Montserrat',
    this.coverHeadlineColor = '#FFFFFF',
    this.coverRightBlockFont = 'Montserrat',
    this.coverRightTitleColor = '#334155',
    this.coverRightSubtitleColor = '#0F172A',
    this.coverRightTaglineColor = '#475569',
    this.coverBadgesTextColor = '#FFFFFF',
    this.coverBadgesIconColor = '',
    this.coverFooterFont = 'Montserrat',
    this.coverFooterColor = '#64748B',
    this.customTextItems = const [],
    this.customIconItems = const [],
    this.coverClientInfoPositionX = 0.58,
    this.coverClientInfoPositionY = 0.88,
    this.coverClientInfoWidth = 240.0,
    this.coverClientInfoFontSize = 8.5,
    this.coverClientInfoColor = '#0F172A',
    this.coverClientInfoSecondaryColor = '#475569',
    this.coverShowClientInfo = true,
    this.coverHeaderStyle = 9,
    this.coverShowHeader = true,
    this.coverHeaderText1 = 'PROPOSTA COMERCIAL',
    this.coverHeaderText2 = 'ENERGIA SOLAR FOTOVOLTAICA',
    this.coverHeaderText3 = 'SOLUÇÕES SUSTENTÁVEIS DE ALTA PERFORMANCE',
    this.coverHeaderBgColor = '#0F172A',
    this.coverHeaderTextColor = '#FFFFFF',
    this.coverHeaderIconColor = '#38BDF8',
    this.coverFooterStyle = 1,
    this.coverShowFooter = true,
    this.coverFooterText1 = 'ENERGIA LIMPA - ECONOMIA REAL - VALORIZAÇÃO',
    this.coverFooterText2 = '(11) 00000-0000 - contato@suaempresa.com.br',
    this.coverFooterText3 = 'www.suaempresa.com.br',
    this.coverFooterText4 = 'Proposta válida por 10 dias corridos a partir da data de emissão.',
    this.coverFooterBgColor = '#0F172A',
    this.coverFooterTextColor = '#CBD5E1',
    this.coverFooterIconColor = '#38BDF8',
    this.page2TemplateId = 'tpl_01_tech_grid',
    this.page2CardsJson,
    this.page2ShowIllustration = true,
    this.page2IllustrationType = 'banner',
    this.hiddenPagesJson,
    this.customPagesJson,
    this.internalPagesLayoutPreset = 'preset_01',
  });

  // Getters de compatibilidade
  String get concessionaireName => utilityCompany;
  double get kwhTariffRate => energyTariff;
  double get annualTariffInflation => annualInflation;
  double get simultaneityFactor => simultaneityRate;
  String get companyCnpj => companyDocument;

  int get themeColorValue {
    final t = selectedSvgTheme.trim();
    if (t.isNotEmpty) {
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
    }
    if (explicitThemeColorValue != null) return explicitThemeColorValue!;
    return 0xFF2563EB;
  }

  List<ProposalPageCardDTO> get page2Cards {
    if (page2CardsJson != null && page2CardsJson!.isNotEmpty) {
      try {
        final list = jsonDecode(page2CardsJson!) as List<dynamic>;
        return list
            .whereType<Map>()
            .map((e) => ProposalPageCardDTO.fromMap(Map<String, dynamic>.from(e)))
            .toList();
      } catch (_) {}
    }
    return const [];
  }

  List<String> get hiddenPageIds {
    if (hiddenPagesJson != null && hiddenPagesJson!.isNotEmpty) {
      try {
        final list = jsonDecode(hiddenPagesJson!) as List<dynamic>;
        return list.map((e) => e.toString()).toList();
      } catch (_) {}
    }
    return const [];
  }

  List<ProposalCustomPageDTO> get customPages {
    if (customPagesJson != null && customPagesJson!.isNotEmpty) {
      try {
        final list = jsonDecode(customPagesJson!) as List<dynamic>;
        return list
            .whereType<Map>()
            .map((e) => ProposalCustomPageDTO.fromMap(Map<String, dynamic>.from(e)))
            .toList();
      } catch (_) {}
    }
    return const [];
  }

  String get effectiveCoverUrl {
    if (coverImageUrl != null && coverImageUrl!.isNotEmpty) return coverImageUrl!;
    final clean = selectedCoverTemplate
        .replaceFirst('assets/modelo_propostas/', '')
        .replaceFirst('capas/energiasolar/', '');
    final encoded = Uri.encodeComponent('capas/energiasolar/$clean');
    return 'https://firebasestorage.googleapis.com/v0/b/solardino-aea02.appspot.com/o/$encoded?alt=media';
  }

  int get secondaryThemeColorValue => _hexToColor(secondaryThemeColor, fallback: 0xFF102C49);

  int get coverBadgeColorValue => _hexToColor(coverBadgeColor, fallback: 0xFFFFFFFF);
  int get coverTitleColorValue => _hexToColor(coverTitleColor, fallback: 0xFF0284C7);
  int get coverSubtitleColorValue => _hexToColor(coverSubtitleColor, fallback: 0xFF0F172A);
  int get customDividerColorValue => _hexToColor(customDividerColor, fallback: 0xFF0284C7);
  int get customDividerBottomColorValue => _hexToColor(customDividerBottomColor, fallback: 0xFFFFFFFF);
  int get verticalSplitAccentColorValue => _hexToColor(verticalSplitAccentColor, fallback: 0xFFEAB308);
  int get coverHeadlineColorValue => _hexToColor(coverHeadlineColor, fallback: 0xFFFFFFFF);
  int get coverRightTitleColorValue => _hexToColor(coverRightTitleColor, fallback: 0xFF334155);
  int get coverRightSubtitleColorValue => _hexToColor(coverRightSubtitleColor, fallback: 0xFF0F172A);
  int get coverRightTaglineColorValue => _hexToColor(coverRightTaglineColor, fallback: 0xFF475569);
  int get coverBadgesTextColorValue => _hexToColor(coverBadgesTextColor, fallback: 0xFFFFFFFF);
  int get coverBadgesIconColorValue {
    if (coverBadgesIconColor.trim().isNotEmpty) {
      return _hexToColor(coverBadgesIconColor, fallback: coverBadgesTextColorValue);
    }
    return coverBadgesTextColorValue;
  }
  int get coverFooterColorValue => _hexToColor(coverFooterColor, fallback: 0xFF64748B);
  int get coverClientInfoColorValue => _hexToColor(coverClientInfoColor, fallback: 0xFF0F172A);
  int get coverClientInfoSecondaryColorValue => _hexToColor(coverClientInfoSecondaryColor, fallback: 0xFF475569);

  static int _hexToColor(String hexStr, {required int fallback}) {
    final hex = hexStr.replaceAll('#', '').trim();
    if (hex.length == 6) return int.tryParse('FF$hex', radix: 16) ?? fallback;
    if (hex.length == 8) return int.tryParse(hex, radix: 16) ?? fallback;
    return fallback;
  }

  double availabilityKwhForType(String? type) {
    final clean = (type ?? defaultConnectionType).toLowerCase();
    if (clean.contains('mono')) return monoAvailabilityKwh;
    if (clean.contains('tri')) return triAvailabilityKwh;
    return biAvailabilityKwh;
  }

  List<YearlySimulationItemDTO> calculateYearlySimulation({
    required double monthlyKwh,
    required double systemKwp,
    String? connectionTypeOverride,
    double? availabilityKwhOverride,
    double? publicLightingOverride,
  }) {
    final list = <YearlySimulationItemDTO>[];
    final currentYear = DateTime.now().year;
    final totalYears = projectionYears.clamp(10, 30);

    double currentTariff = energyTariff > 0 ? energyTariff : 1.125;
    final infl = (annualInflation > 0 ? annualInflation : 5.0) / 100.0;
    final simRate = (simultaneityRate > 0 ? simultaneityRate : 13.0) / 100.0;

    final availKwh = availabilityKwhOverride ?? availabilityKwhForType(connectionTypeOverride);
    final baseCipRs = publicLightingOverride ?? defaultPublicLightingRs;

    for (int i = 0; i < totalYears; i++) {
      final year = currentYear + i;

      final directSelfConsumption = monthlyKwh * simRate;
      final gridInjectedKwh = monthlyKwh - directSelfConsumption;

      if (useDetailedBillingCalc) {
        final cipThisYear = baseCipRs * math.pow(1 + infl, i);
        final availThisYear = availKwh * currentTariff;
        final baseWithoutSolar = (monthlyKwh * currentTariff) + cipThisYear;
        final fioBGrowth = math.pow(1 + (infl * 0.7), i);
        final minBill = (gridInjectedKwh * fioBTariff * 0.55 * fioBGrowth) + availThisYear + cipThisYear;
        final maxBill = (gridInjectedKwh * fioBTariff * 0.85 * fioBGrowth) + availThisYear + cipThisYear;

        list.add(YearlySimulationItemDTO(
          year: year,
          withSolarMin: minBill,
          withSolarMax: maxBill,
          withoutSolar: baseWithoutSolar,
        ));
      } else {
        final baseWithoutSolar = monthlyKwh * currentTariff;

        final minBill = (gridInjectedKwh * fioBTariff * 0.55) + 65.0;
        final maxBill = (gridInjectedKwh * fioBTariff * 0.85) + 95.0;

        list.add(YearlySimulationItemDTO(
          year: year,
          withSolarMin: minBill * math.pow(1 + (infl * 0.7), i),
          withSolarMax: maxBill * math.pow(1 + (infl * 0.7), i),
          withoutSolar: baseWithoutSolar,
        ));
      }

      currentTariff *= (1 + infl);
    }

    return list;
  }

  factory SolarSettingsDTO.fromMap(Map<String, dynamic> map) {
    final rawTheme = (map['selectedSvgTheme'] ?? map['selectedSvgFooter'] ?? map['selectedSvgHeader'])?.toString();
    final explicitThemeVal = (map['themeColorValue'] as num?)?.toInt();

    return SolarSettingsDTO(
      utilityCompany: map['utilityCompany']?.toString() ?? map['concessionaireName']?.toString() ?? 'Amazonas Energia',
      energyTariff: (map['energyTariff'] as num?)?.toDouble() ?? (map['kwhTariffRate'] as num?)?.toDouble() ?? 1.125,
      fioBTariff: (map['fioBTariff'] as num?)?.toDouble() ?? 0.28,
      simultaneityRate: (map['simultaneityRate'] as num?)?.toDouble() ?? (map['simultaneityFactor'] as num?)?.toDouble() ?? 13.0,
      useDetailedBillingCalc: map['useDetailedBillingCalc'] as bool? ?? false,
      defaultConnectionType: map['defaultConnectionType']?.toString() ?? 'Bifásico',
      monoAvailabilityKwh: (map['monoAvailabilityKwh'] as num?)?.toDouble() ?? 30.0,
      biAvailabilityKwh: (map['biAvailabilityKwh'] as num?)?.toDouble() ?? 50.0,
      triAvailabilityKwh: (map['triAvailabilityKwh'] as num?)?.toDouble() ?? 100.0,
      defaultPublicLightingRs: (map['defaultPublicLightingRs'] as num?)?.toDouble() ?? 45.0,
      annualInflation: (map['annualInflation'] as num?)?.toDouble() ?? (map['annualTariffInflation'] as num?)?.toDouble() ?? 5.0,
      projectionYears: (map['projectionYears'] as num?)?.toInt() ?? 21,
      defaultSunHours: (map['defaultSunHours'] as num?)?.toDouble() ?? 4.8,
      financingBanks: map['financingBanks'] is List
          ? (map['financingBanks'] as List)
              .whereType<Map>()
              .map((e) => SolarFinancingBankDTO.fromMap(Map<String, dynamic>.from(e)))
              .toList()
          : SolarFinancingBankDTO.defaultBanks(),
      creditCardRates: map['creditCardRates'] is List
          ? (map['creditCardRates'] as List)
              .whereType<Map>()
              .map((e) => CreditCardInstallmentRateDTO.fromMap(Map<String, dynamic>.from(e)))
              .toList()
          : CreditCardInstallmentRateDTO.defaultRates(),
      selectedCoverTemplate: map['selectedCoverTemplate']?.toString() ?? 'modelo_proposta_1.jpg',
      selectedSvgTheme: rawTheme ?? (explicitThemeVal != null ? '#${explicitThemeVal.toRadixString(16).padLeft(8, '0').substring(2)}' : '#2563EB'),
      secondaryThemeColor: map['secondaryThemeColor']?.toString() ?? '#102C49',
      explicitThemeColorValue: explicitThemeVal,
      webBackgroundTemplate: map['webBackgroundTemplate']?.toString() ?? 'AdobeStock_1030854734.jpg',
      coverImageUrl: map['coverImageUrl']?.toString(),
      companyName: map['companyName']?.toString() ?? '',
      companyDocument: map['companyDocument']?.toString() ?? map['companyCnpj']?.toString() ?? '',
      companyPhone: map['companyPhone']?.toString() ?? '',
      companyWebsite: map['companyWebsite']?.toString() ?? '',
      companyInstagram: map['companyInstagram']?.toString() ?? '',
      companySlogan: map['companySlogan']?.toString(),
      coverTitle: map['coverTitle']?.toString() ?? 'PROPOSTA COMERCIAL',
      coverSubtitle: map['coverSubtitle']?.toString() ?? 'ENERGIA SOLAR FOTOVOLTAICA',
      coverShowBadge: map['coverShowBadge'] as bool? ?? true,
      coverBadgeColor: map['coverBadgeColor']?.toString() ?? '#FFFFFF',
      coverBadgeOpacity: (map['coverBadgeOpacity'] as num?)?.toDouble() ?? 0.92,
      coverTitleColor: map['coverTitleColor']?.toString() ?? '#0284C7',
      coverSubtitleColor: map['coverSubtitleColor']?.toString() ?? '#0F172A',
      coverTitleFontSize: (map['coverTitleFontSize'] as num?)?.toDouble() ?? 26.0,
      coverSubtitleFontSize: (map['coverSubtitleFontSize'] as num?)?.toDouble() ?? 11.0,
      coverBadgePositionX: (map['coverBadgePositionX'] as num?)?.toDouble() ?? 0.08,
      coverBadgePositionY: (map['coverBadgePositionY'] as num?)?.toDouble() ?? 0.06,
      customCoverImageBase64: map['customCoverImageBase64']?.toString(),
      customDividerStyle: (map['customDividerStyle'] as num?)?.toInt() ?? 0,
      customDividerColor: map['customDividerColor']?.toString() ?? '#0284C7',
      customDividerBottomColor: map['customDividerBottomColor']?.toString() ?? '#FFFFFF',
      isCustomCoverMode: map['isCustomCoverMode'] as bool? ?? false,
      companyLogoBase64: map['companyLogoBase64']?.toString(),
      coverShowLogo: map['coverShowLogo'] as bool? ?? true,
      coverLogoPositionX: (map['coverLogoPositionX'] as num?)?.toDouble() ?? 0.65,
      coverLogoPositionY: (map['coverLogoPositionY'] as num?)?.toDouble() ?? 0.05,
      coverLogoWidth: (map['coverLogoWidth'] as num?)?.toDouble() ?? 90.0,
      proposalStyle: map['proposalStyle']?.toString() ?? 'modern',
      selectedVerticalSplitTemplate: map['selectedVerticalSplitTemplate']?.toString() ?? 'vertical_split_1',
      verticalSplitDividerType: (map['verticalSplitDividerType'] as num?)?.toInt() ?? 0,
      verticalSplitHeadline: map['verticalSplitHeadline']?.toString() ?? 'ENERGIA\nQUE MOVE\nO SEU\nAMANHÃ',
      verticalSplitSubheadline: map['verticalSplitSubheadline']?.toString() ?? 'MAIS ECONOMIA.\nMAIS LIBERDADE.\nUM FUTURO SUSTENTÁVEL.',
      verticalSplitLeftFooter: map['verticalSplitLeftFooter']?.toString() ?? 'PESSOAS  -  TECNOLOGIA  -  UM PLANETA MELHOR',
      verticalSplitRightTitle: map['verticalSplitRightTitle']?.toString() ?? 'PROPOSTA',
      verticalSplitRightSubtitle: map['verticalSplitRightSubtitle']?.toString() ?? 'SOLAR',
      verticalSplitRightTagline: map['verticalSplitRightTagline']?.toString() ?? 'SOLUÇÕES EM ENERGIA\nPARA UM FUTURO MELHOR',
      verticalSplitRightTitleFontSize: (map['verticalSplitRightTitleFontSize'] as num?)?.toDouble() ?? 18.0,
      verticalSplitRightSubtitleFontSize: (map['verticalSplitRightSubtitleFontSize'] as num?)?.toDouble() ?? 46.0,
      verticalSplitHeadlineFontSize: (map['verticalSplitHeadlineFontSize'] as num?)?.toDouble() ?? 24.0,
      verticalSplitRightFooter: map['verticalSplitRightFooter']?.toString() ?? 'ENERGIA HOJE.\nMAIS POSSIBILIDADES\nAMANHÃ.',
      verticalSplitShowRightDivider: map['verticalSplitShowRightDivider'] as bool? ?? true,
      verticalSplitRightDividerColor: map['verticalSplitRightDividerColor']?.toString() ?? '',
      verticalSplitRightDividerWidth: (map['verticalSplitRightDividerWidth'] as num?)?.toDouble() ?? 54.0,
      verticalSplitRightDividerHeight: (map['verticalSplitRightDividerHeight'] as num?)?.toDouble() ?? 4.5,
      verticalSplitShowHeadlineDivider: map['verticalSplitShowHeadlineDivider'] as bool? ?? true,
      verticalSplitHeadlineDividerColor: map['verticalSplitHeadlineDividerColor']?.toString() ?? '',
      verticalSplitHeadlineDividerWidth: (map['verticalSplitHeadlineDividerWidth'] as num?)?.toDouble() ?? 48.0,
      verticalSplitHeadlineDividerHeight: (map['verticalSplitHeadlineDividerHeight'] as num?)?.toDouble() ?? 4.0,
      verticalSplitAccentColor: map['verticalSplitAccentColor']?.toString() ?? '#EAB308',
      verticalSplitFooterBadges: map['verticalSplitFooterBadges'] is List
          ? (map['verticalSplitFooterBadges'] as List)
              .whereType<Map>()
              .map((e) => CoverFooterBadgeDTO.fromMap(Map<String, dynamic>.from(e)))
              .toList()
          : CoverFooterBadgeDTO.defaultBadges(),
      verticalSplitBadgesLayout: map['verticalSplitBadgesLayout']?.toString() ?? 'horizontal',
      verticalSplitLeftFooterWidth: (map['verticalSplitLeftFooterWidth'] as num?)?.toDouble() ?? 0.60,
      verticalSplitHeadlineTop: (map['verticalSplitHeadlineTop'] as num?)?.toDouble() ?? 0.06,
      verticalSplitHeadlineLeft: (map['verticalSplitHeadlineLeft'] as num?)?.toDouble() ?? 0.06,
      verticalSplitRightBlockTop: (map['verticalSplitRightBlockTop'] as num?)?.toDouble() ?? 0.20,
      verticalSplitRightBlockRight: (map['verticalSplitRightBlockRight'] as num?)?.toDouble() ?? 0.08,
      verticalSplitLeftFooterBottom: (map['verticalSplitLeftFooterBottom'] as num?)?.toDouble() ?? 0.04,
      verticalSplitLeftFooterLeft: (map['verticalSplitLeftFooterLeft'] as num?)?.toDouble() ?? 0.05,
      verticalSplitRightFooterBottom: (map['verticalSplitRightFooterBottom'] as num?)?.toDouble() ?? 0.04,
      verticalSplitRightFooterRight: (map['verticalSplitRightFooterRight'] as num?)?.toDouble() ?? 0.08,
      verticalSplitShowHeadline: map['verticalSplitShowHeadline'] as bool? ?? true,
      verticalSplitShowLeftFooter: map['verticalSplitShowLeftFooter'] as bool? ?? true,
      verticalSplitShowRightBlock: map['verticalSplitShowRightBlock'] as bool? ?? true,
      verticalSplitShowRightFooter: map['verticalSplitShowRightFooter'] as bool? ?? true,
      coverHeadlineFont: map['coverHeadlineFont']?.toString() ?? 'Montserrat',
      coverHeadlineColor: map['coverHeadlineColor']?.toString() ?? '#FFFFFF',
      coverRightBlockFont: map['coverRightBlockFont']?.toString() ?? 'Montserrat',
      coverRightTitleColor: map['coverRightTitleColor']?.toString() ?? '#334155',
      coverRightSubtitleColor: map['coverRightSubtitleColor']?.toString() ?? '#0F172A',
      coverRightTaglineColor: map['coverRightTaglineColor']?.toString() ?? '#475569',
      coverBadgesTextColor: map['coverBadgesTextColor']?.toString() ?? '#FFFFFF',
      coverBadgesIconColor: map['coverBadgesIconColor']?.toString() ?? '',
      coverFooterFont: map['coverFooterFont']?.toString() ?? 'Montserrat',
      coverFooterColor: map['coverFooterColor']?.toString() ?? '#64748B',
      customTextItems: map['customTextItems'] is List
          ? (map['customTextItems'] as List)
              .whereType<Map>()
              .map((e) => CustomCoverTextItemDTO.fromMap(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      customIconItems: map['customIconItems'] is List
          ? (map['customIconItems'] as List)
              .whereType<Map>()
              .map((e) => CustomCoverIconItemDTO.fromMap(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      coverClientInfoPositionX: (map['coverClientInfoPositionX'] as num?)?.toDouble() ?? 0.58,
      coverClientInfoPositionY: (map['coverClientInfoPositionY'] as num?)?.toDouble() ?? 0.88,
      coverClientInfoWidth: (map['coverClientInfoWidth'] as num?)?.toDouble() ?? 240.0,
      coverClientInfoFontSize: (map['coverClientInfoFontSize'] as num?)?.toDouble() ?? 8.5,
      coverClientInfoColor: map['coverClientInfoColor']?.toString() ?? '#0F172A',
      coverClientInfoSecondaryColor: map['coverClientInfoSecondaryColor']?.toString() ?? '#475569',
      coverShowClientInfo: map['coverShowClientInfo'] as bool? ?? true,
      coverHeaderStyle: (map['coverHeaderStyle'] as num?)?.toInt() ?? 9,
      coverShowHeader: map['coverShowHeader'] as bool? ?? true,
      coverHeaderText1: map['coverHeaderText1']?.toString() ?? 'PROPOSTA COMERCIAL',
      coverHeaderText2: map['coverHeaderText2']?.toString() ?? 'ENERGIA SOLAR FOTOVOLTAICA',
      coverHeaderText3: map['coverHeaderText3']?.toString() ?? 'SOLUÇÕES SUSTENTÁVEIS DE ALTA PERFORMANCE',
      coverHeaderBgColor: map['coverHeaderBgColor']?.toString() ?? '#0F172A',
      coverHeaderTextColor: map['coverHeaderTextColor']?.toString() ?? '#FFFFFF',
      coverHeaderIconColor: map['coverHeaderIconColor']?.toString() ?? '#38BDF8',
      coverFooterStyle: (map['coverFooterStyle'] as num?)?.toInt() ?? 1,
      coverShowFooter: map['coverShowFooter'] as bool? ?? true,
      coverFooterText1: map['coverFooterText1']?.toString() ?? 'ENERGIA LIMPA - ECONOMIA REAL - VALORIZAÇÃO',
      coverFooterText2: map['coverFooterText2']?.toString() ?? '(11) 00000-0000 - contato@suaempresa.com.br',
      coverFooterText3: map['coverFooterText3']?.toString() ?? 'www.suaempresa.com.br',
      coverFooterText4: map['coverFooterText4']?.toString() ?? 'Proposta válida por 10 dias corridos a partir da data de emissão.',
      coverFooterBgColor: map['coverFooterBgColor']?.toString() ?? '#0F172A',
      coverFooterTextColor: map['coverFooterTextColor']?.toString() ?? '#CBD5E1',
      coverFooterIconColor: map['coverFooterIconColor']?.toString() ?? '#38BDF8',
      page2TemplateId: map['page2TemplateId']?.toString() ?? 'tpl_01_tech_grid',
      page2CardsJson: map['page2CardsJson']?.toString(),
      page2ShowIllustration: map['page2ShowIllustration'] as bool? ?? true,
      page2IllustrationType: map['page2IllustrationType']?.toString() ?? 'banner',
      hiddenPagesJson: map['hiddenPagesJson']?.toString(),
      customPagesJson: map['customPagesJson']?.toString(),
      internalPagesLayoutPreset: map['internalPagesLayoutPreset']?.toString() ?? 'preset_01',
    );
  }
}
