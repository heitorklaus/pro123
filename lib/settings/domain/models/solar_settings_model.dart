import 'dart:convert';
import 'dart:math' as math;
import 'proposal_pages_models.dart';

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

/// Emblema/Ícone personalizável do rodapé da capa (Estilo Vertical Split)
class CoverFooterBadge {
  final String iconKey; // 'eco', 'bolt', 'chart', 'shield', 'sun', 'star', 'coins', 'home'
  final String label; // 'ECONOMIA', 'SUSTENTABILIDADE', etc.

  const CoverFooterBadge({
    required this.iconKey,
    required this.label,
  });

  CoverFooterBadge copyWith({
    String? iconKey,
    String? label,
  }) {
    return CoverFooterBadge(
      iconKey: iconKey ?? this.iconKey,
      label: label ?? this.label,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'iconKey': iconKey,
      'label': label,
    };
  }

  factory CoverFooterBadge.fromMap(Map<String, dynamic> map) {
    return CoverFooterBadge(
      iconKey: map['iconKey'] as String? ?? 'eco',
      label: map['label'] as String? ?? '',
    );
  }

  static List<CoverFooterBadge> defaultBadges() {
    return const [
      CoverFooterBadge(iconKey: 'eco', label: 'ECONOMIA'),
      CoverFooterBadge(iconKey: 'bolt', label: 'SUSTENTABILIDADE'),
      CoverFooterBadge(iconKey: 'chart', label: 'VALORIZAÇÃO'),
    ];
  }
}

/// Item de texto customizado adicional na capa da proposta
class CustomCoverTextItem {
  final String id;
  final String text;
  final double x; // Posição horizontal relativa (0.0 a 1.0)
  final double y; // Posição vertical relativa (0.0 a 1.0)
  final double fontSize;
  final int colorValue;
  final bool isBold;

  const CustomCoverTextItem({
    required this.id,
    required this.text,
    required this.x,
    required this.y,
    this.fontSize = 14.0,
    this.colorValue = 0xFF0F172A,
    this.isBold = true,
  });

  CustomCoverTextItem copyWith({
    String? id,
    String? text,
    double? x,
    double? y,
    double? fontSize,
    int? colorValue,
    bool? isBold,
  }) {
    return CustomCoverTextItem(
      id: id ?? this.id,
      text: text ?? this.text,
      x: x ?? this.x,
      y: y ?? this.y,
      fontSize: fontSize ?? this.fontSize,
      colorValue: colorValue ?? this.colorValue,
      isBold: isBold ?? this.isBold,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'x': x,
      'y': y,
      'fontSize': fontSize,
      'colorValue': colorValue,
      'isBold': isBold,
    };
  }

  factory CustomCoverTextItem.fromMap(Map<String, dynamic> map) {
    return CustomCoverTextItem(
      id: map['id'] as String? ?? 'txt_${DateTime.now().millisecondsSinceEpoch}',
      text: map['text'] as String? ?? 'Texto Personalizado',
      x: (map['x'] as num?)?.toDouble() ?? 0.5,
      y: (map['y'] as num?)?.toDouble() ?? 0.5,
      fontSize: (map['fontSize'] as num?)?.toDouble() ?? 14.0,
      colorValue: (map['colorValue'] as num?)?.toInt() ?? 0xFF0F172A,
      isBold: map['isBold'] as bool? ?? true,
    );
  }
}

/// Item de ícone customizado adicional na capa da proposta
class CustomCoverIconItem {
  final String id;
  final String iconKey; // 'solar_power', 'bolt', 'eco', 'shield', 'verified', 'star', 'phone', 'location', 'mail', 'lightbulb', 'handshake', 'award'
  final double x; // Posição horizontal relativa (0.0 a 1.0)
  final double y; // Posição vertical relativa (0.0 a 1.0)
  final double size;
  final int colorValue;

  const CustomCoverIconItem({
    required this.id,
    required this.iconKey,
    required this.x,
    required this.y,
    this.size = 28.0,
    this.colorValue = 0xFFEAB308,
  });

  CustomCoverIconItem copyWith({
    String? id,
    String? iconKey,
    double? x,
    double? y,
    double? size,
    int? colorValue,
  }) {
    return CustomCoverIconItem(
      id: id ?? this.id,
      iconKey: iconKey ?? this.iconKey,
      x: x ?? this.x,
      y: y ?? this.y,
      size: size ?? this.size,
      colorValue: colorValue ?? this.colorValue,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'iconKey': iconKey,
      'x': x,
      'y': y,
      'size': size,
      'colorValue': colorValue,
    };
  }

  factory CustomCoverIconItem.fromMap(Map<String, dynamic> map) {
    return CustomCoverIconItem(
      id: map['id'] as String? ?? 'ico_${DateTime.now().millisecondsSinceEpoch}',
      iconKey: map['iconKey'] as String? ?? 'solar_power',
      x: (map['x'] as num?)?.toDouble() ?? 0.5,
      y: (map['y'] as num?)?.toDouble() ?? 0.5,
      size: (map['size'] as num?)?.toDouble() ?? 28.0,
      colorValue: (map['colorValue'] as num?)?.toInt() ?? 0xFFEAB308,
    );
  }
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
  final String selectedCoverTemplate; // ex: 'modelo_proposta_1.jpg'
  final String selectedSvgTheme; // Armazena a cor/tema (ex: '#2563EB' ou 'azul_royal')
  final String webBackgroundTemplate; // ex: 'AdobeStock_1030854734.jpg'
  final String? companyName;
  final String? companyDocument;
  final String? companyPhone;
  final String? companyWebsite;
  final String? companyInstagram;
  final String? companySlogan; // ex: 'Energia que Transforma'

  // Configurações do Editor em Tempo Real de Capa & Retângulo de Título
  final String coverTitle; // Default: 'PROPOSTA COMERCIAL'
  final String coverSubtitle; // Default: 'ENERGIA SOLAR FOTOVOLTAICA'
  final bool coverShowBadge; // Se exibe retângulo de fundo
  final String coverBadgeColor; // Cor do retângulo (ex: '#FFFFFF')
  final double coverBadgeOpacity; // Opacidade do retângulo (0.0 a 1.0)
  final String coverTitleColor; // Cor do título (ex: '#0284C7')
  final String coverSubtitleColor; // Cor do subtítulo (ex: '#0F172A')
  final double coverTitleFontSize; // Tamanho da fonte do título (ex: 26.0)
  final double coverSubtitleFontSize; // Tamanho da fonte do subtítulo (ex: 11.0)
  final double coverBadgePositionX; // Posição horizontal relativa (0.0 a 1.0, default: 0.08)
  final double coverBadgePositionY; // Posição vertical relativa (0.0 a 1.0, default: 0.06)
  final String? customCoverImageBase64; // Foto customizada enviada pelo cliente
  final int customDividerStyle; // 0 a 9 (Estilo do decalque / separador)
  final String customDividerColor; // Cor do separador customizado
  final String customDividerBottomColor; // Cor da área inferior/branca da capa
  final bool isCustomCoverMode; // Se está no modo de capa customizada
  final String? companyLogoBase64; // Logomarca personalizada da empresa (Base64)
  final bool coverShowLogo; // Exibir logomarca na capa
  final double coverLogoPositionX; // Posição horizontal da logo (0.0 a 1.0)
  final double coverLogoPositionY; // Posição vertical da logo (0.0 a 1.0)
  final double coverLogoWidth; // Largura da logo em pixels na prévia (ex: 90.0)

  // ── Estilo das Propostas (Estilo Modern vs Estilo Vertical Split) ───────────
  final String proposalStyle; // 'modern' ou 'verticalSplit'
  final String selectedVerticalSplitTemplate; // ex: 'vertical_split_1'
  final int verticalSplitDividerType; // 0 = Diagonal, 1 = Raio de Energia, 2 = Sol Radiante
  final String verticalSplitHeadline; // ex: 'ENERGIA\nQUE MOVE\nO SEU\nAMANHÃ'
  final String verticalSplitSubheadline; // ex: 'MAIS ECONOMIA.\nMAIS LIBERDADE.\nUM FUTURO SUSTENTÁVEL.'
  final String verticalSplitLeftFooter; // ex: 'PESSOAS  •  TECNOLOGIA  •  UM PLANETA MELHOR'
  final String verticalSplitRightTitle; // ex: 'PROPOSTA'
  final String verticalSplitRightSubtitle; // ex: 'SOLAR'
  final String verticalSplitRightTagline; // ex: 'SOLUÇÕES EM ENERGIA\nPARA UM FUTURO MELHOR'
  final String verticalSplitRightFooter; // ex: 'ENERGIA HOJE.\nMAIS POSSIBILIDADES\nAMANHÃ.'
  final bool verticalSplitShowRightDivider; // Exibir barra sob o título Proposta Solar (default: true)
  final String verticalSplitRightDividerColor; // Cor da barra (default: '', fallback accent)
  final double verticalSplitRightDividerWidth; // Largura da barra em px (default: 54.0)
  final double verticalSplitRightDividerHeight; // Altura/espessura da barra em px (default: 4.5)
  final bool verticalSplitShowHeadlineDivider; // Exibir barra sob a frase de impacto (default: true)
  final String verticalSplitHeadlineDividerColor; // Cor da barra da frase de impacto (default: '', fallback accent)
  final double verticalSplitHeadlineDividerWidth; // Largura da barra da frase de impacto em px (default: 48.0)
  final double verticalSplitHeadlineDividerHeight; // Altura/espessura da barra da frase de impacto em px (default: 4.0)
  final String verticalSplitAccentColor; // ex: '#EAB308' (Amarelo Dourado)
  final List<CoverFooterBadge> verticalSplitFooterBadges; // Ícones customizáveis do rodapé
  final String verticalSplitBadgesLayout; // 'horizontal' | 'vertical' | 'wrap' (default: 'horizontal')
  final double verticalSplitLeftFooterWidth; // Largura relativa da área do rodapé da foto/badges (default: 0.60)

  // Posições Relativas Customizadas dos Blocos (0.0 a 1.0) para Arrastar e Soltar Livre
  final double verticalSplitHeadlineTop; // Posição vertical do título esquerdo (default: 0.06)
  final double verticalSplitHeadlineLeft; // Posição horizontal do título esquerdo (default: 0.06)
  final double verticalSplitRightBlockTop; // Posição vertical do bloco Proposta Solar (default: 0.20)
  final double verticalSplitRightBlockRight; // Posição horizontal direita do bloco Proposta Solar (default: 0.08)
  final double verticalSplitLeftFooterBottom; // Posição vertical inferior do rodapé esquerdo (default: 0.04)
  final double verticalSplitLeftFooterLeft; // Posição horizontal do rodapé esquerdo (default: 0.05)
  final double verticalSplitRightFooterBottom; // Posição vertical inferior do rodapé direito (default: 0.04)
  final double verticalSplitRightFooterRight; // Posição horizontal direita do rodapé direito (default: 0.08)

  // Visibilidade dos Blocos Pré-definidos da Capa
  final bool verticalSplitShowHeadline; // Exibir Título e Subtítulo da Foto (default: true)
  final bool verticalSplitShowLeftFooter; // Exibir Rodapé da Foto / Badges (default: true)
  final bool verticalSplitShowRightBlock; // Exibir Proposta Solar e Tagline (default: true)
  final bool verticalSplitShowRightFooter; // Exibir Rodapé Institucional Direito (default: true)

  // Tipografia e Cores Customizáveis dos Blocos da Capa (Vertical Split & Modern)
  final String coverHeadlineFont; // 'Montserrat' | 'Roboto' | 'Inter' | 'Outfit' | 'Oswald' | 'Poppins'
  final String coverHeadlineColor; // default: '#FFFFFF'
  final String coverRightBlockFont; // 'Montserrat' | 'Roboto' | 'Inter' | 'Outfit' | 'Oswald' | 'Poppins'
  final String coverRightTitleColor; // default: '#334155'
  final String coverRightSubtitleColor; // default: '#0F172A'
  final String coverRightTaglineColor; // default: '#475569'
  final String coverBadgesTextColor; // default: '#FFFFFF'
  final String coverBadgesIconColor; // default: '' (usa coverBadgesTextColor quando vazio)
  final String coverFooterFont; // 'Montserrat' | 'Roboto' | 'Inter' | 'Outfit' | 'Oswald' | 'Poppins'
  final String coverFooterColor; // default: '#64748B'
  final List<CustomCoverTextItem> customTextItems;
  final List<CustomCoverIconItem> customIconItems;

  // Bloco de Informações do Cliente & CPF/CNPJ (Arrastável, Redimensionável e com Cores)
  final double coverClientInfoPositionX; // default: 0.58
  final double coverClientInfoPositionY; // default: 0.88
  final double coverClientInfoWidth; // default: 240.0
  final double coverClientInfoFontSize; // default: 8.5
  final String coverClientInfoColor; // default: '#0F172A'
  final String coverClientInfoSecondaryColor; // default: '#475569'
  final bool coverShowClientInfo; // default: true

  // ── Cabeçalho e Rodapé Customizáveis (10 Estilos) ─────────────
  final int coverHeaderStyle; // 0 = Desativado, 1 a 10 = Estilos
  final bool coverShowHeader;
  final String coverHeaderText1;
  final String coverHeaderText2;
  final String coverHeaderText3;
  final String coverHeaderBgColor;
  final String coverHeaderTextColor;
  final String coverHeaderIconColor;

  final int coverFooterStyle; // 0 = Desativado, 1 a 10 = Estilos
  final bool coverShowFooter;
  final String coverFooterText1;
  final String coverFooterText2;
  final String coverFooterText3;
  final String coverFooterText4;
  final String coverFooterBgColor;
  final String coverFooterTextColor;
  final String coverFooterIconColor;

  // ── Gestão de Páginas, Templates e Cards da Página 2 ─────────────
  final String page2TemplateId;
  final String? page2CardsJson;
  final bool page2ShowIllustration;
  final String page2IllustrationType;
  final String? hiddenPagesJson;
  final String? customPagesJson;
  final String internalPagesLayoutPreset;

  List<ProposalPageCard> get page2Cards {
    if (page2CardsJson != null && page2CardsJson!.isNotEmpty) {
      try {
        final list = jsonDecode(page2CardsJson!) as List<dynamic>;
        return list.map((e) => ProposalPageCard.fromMap(e as Map<String, dynamic>)).toList();
      } catch (_) {}
    }
    return ProposalPageCard.defaultSolarCards();
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

  List<ProposalCustomPage> get customPages {
    if (customPagesJson != null && customPagesJson!.isNotEmpty) {
      try {
        final list = jsonDecode(customPagesJson!) as List<dynamic>;
        return list.map((e) => ProposalCustomPage.fromMap(e as Map<String, dynamic>)).toList();
      } catch (_) {}
    }
    return const [];
  }

  // Getters para compatibilidade retroativa
  String get selectedSvgHeader => selectedSvgTheme;
  String get selectedSvgFooter => selectedSvgTheme;

  /// Retorna o valor numérico inteiro (0xFFRRGGBB) da cor do retângulo de capa
  int get coverBadgeColorValue {
    final hex = coverBadgeColor.replaceAll('#', '').trim();
    if (hex.length == 6) return int.tryParse('FF$hex', radix: 16) ?? 0xFFFFFFFF;
    if (hex.length == 8) return int.tryParse(hex, radix: 16) ?? 0xFFFFFFFF;
    return 0xFFFFFFFF;
  }

  /// Retorna o valor numérico inteiro (0xFFRRGGBB) da cor do título
  int get coverTitleColorValue {
    final hex = coverTitleColor.replaceAll('#', '').trim();
    if (hex.length == 6) return int.tryParse('FF$hex', radix: 16) ?? 0xFF0284C7;
    if (hex.length == 8) return int.tryParse(hex, radix: 16) ?? 0xFF0284C7;
    return 0xFF0284C7;
  }

  /// Retorna o valor numérico inteiro (0xFFRRGGBB) da cor do subtítulo
  int get coverSubtitleColorValue {
    final hex = coverSubtitleColor.replaceAll('#', '').trim();
    if (hex.length == 6) return int.tryParse('FF$hex', radix: 16) ?? 0xFF0F172A;
    if (hex.length == 8) return int.tryParse(hex, radix: 16) ?? 0xFF0F172A;
    return 0xFF0F172A;
  }

  /// Retorna o valor numérico inteiro (0xFFRRGGBB) da cor do separador customizado
  int get customDividerColorValue {
    final hex = customDividerColor.replaceAll('#', '').trim();
    if (hex.length == 6) return int.tryParse('FF$hex', radix: 16) ?? 0xFF0284C7;
    if (hex.length == 8) return int.tryParse(hex, radix: 16) ?? 0xFF0284C7;
    return 0xFF0284C7;
  }

  /// Retorna o valor numérico inteiro (0xFFRRGGBB) da cor da área inferior customizada
  int get customDividerBottomColorValue {
    final hex = customDividerBottomColor.replaceAll('#', '').trim();
    if (hex.length == 6) return int.tryParse('FF$hex', radix: 16) ?? 0xFFFFFFFF;
    if (hex.length == 8) return int.tryParse(hex, radix: 16) ?? 0xFFFFFFFF;
    return 0xFFFFFFFF;
  }

  /// Retorna o valor numérico inteiro (0xFFRRGGBB) da cor de destaque vertical split
  int get verticalSplitAccentColorValue {
    final hex = verticalSplitAccentColor.replaceAll('#', '').trim();
    if (hex.length == 6) return int.tryParse('FF$hex', radix: 16) ?? 0xFFEAB308;
    if (hex.length == 8) return int.tryParse(hex, radix: 16) ?? 0xFFEAB308;
    return 0xFFEAB308;
  }

  int get coverHeadlineColorValue => _hexToColor(coverHeadlineColor, fallback: 0xFFFFFFFF);
  int get coverRightTitleColorValue => _hexToColor(coverRightTitleColor, fallback: 0xFF334155);
  int get coverRightSubtitleColorValue => _hexToColor(coverRightSubtitleColor, fallback: 0xFF0F172A);
  int get coverRightTaglineColorValue => _hexToColor(coverRightTaglineColor, fallback: 0xFF475569);
  int get verticalSplitRightDividerColorValue {
    if (verticalSplitRightDividerColor.trim().isNotEmpty) {
      return _hexToColor(verticalSplitRightDividerColor, fallback: verticalSplitAccentColorValue);
    }
    return verticalSplitAccentColorValue;
  }
  int get verticalSplitHeadlineDividerColorValue {
    if (verticalSplitHeadlineDividerColor.trim().isNotEmpty) {
      return _hexToColor(verticalSplitHeadlineDividerColor, fallback: verticalSplitAccentColorValue);
    }
    return verticalSplitAccentColorValue;
  }
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
    this.selectedCoverTemplate = 'modelo_proposta_1.jpg',
    this.selectedSvgTheme = '#2563EB',
    this.webBackgroundTemplate = 'AdobeStock_1030854734.jpg',
    this.companyName,
    this.companyDocument,
    this.companyPhone,
    this.companyWebsite,
    this.companyInstagram,
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
    this.verticalSplitLeftFooter = 'PESSOAS  •  TECNOLOGIA  •  UM PLANETA MELHOR',
    this.verticalSplitRightTitle = 'PROPOSTA',
    this.verticalSplitRightSubtitle = 'SOLAR',
    this.verticalSplitRightTagline = 'SOLUÇÕES EM ENERGIA\nPARA UM FUTURO MELHOR',
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
      CoverFooterBadge(iconKey: 'eco', label: 'ECONOMIA'),
      CoverFooterBadge(iconKey: 'bolt', label: 'SUSTENTABILIDADE'),
      CoverFooterBadge(iconKey: 'chart', label: 'VALORIZAÇÃO'),
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
    this.coverFooterText1 = 'ENERGIA LIMPA • ECONOMIA REAL • VALORIZAÇÃO',
    this.coverFooterText2 = '(11) 00000-0000 • contato@suaempresa.com.br',
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
    String? coverTitle,
    String? coverSubtitle,
    bool? coverShowBadge,
    String? coverBadgeColor,
    double? coverBadgeOpacity,
    String? coverTitleColor,
    String? coverSubtitleColor,
    double? coverTitleFontSize,
    double? coverSubtitleFontSize,
    double? coverBadgePositionX,
    double? coverBadgePositionY,
    String? customCoverImageBase64,
    int? customDividerStyle,
    String? customDividerColor,
    String? customDividerBottomColor,
    bool? isCustomCoverMode,
    String? companyLogoBase64,
    bool? coverShowLogo,
    double? coverLogoPositionX,
    double? coverLogoPositionY,
    double? coverLogoWidth,
    String? proposalStyle,
    String? selectedVerticalSplitTemplate,
    int? verticalSplitDividerType,
    String? verticalSplitHeadline,
    String? verticalSplitSubheadline,
    String? verticalSplitLeftFooter,
    String? verticalSplitRightTitle,
    String? verticalSplitRightSubtitle,
    String? verticalSplitRightTagline,
    String? verticalSplitRightFooter,
    bool? verticalSplitShowRightDivider,
    String? verticalSplitRightDividerColor,
    double? verticalSplitRightDividerWidth,
    double? verticalSplitRightDividerHeight,
    bool? verticalSplitShowHeadlineDivider,
    String? verticalSplitHeadlineDividerColor,
    double? verticalSplitHeadlineDividerWidth,
    double? verticalSplitHeadlineDividerHeight,
    String? verticalSplitAccentColor,
    List<CoverFooterBadge>? verticalSplitFooterBadges,
    String? verticalSplitBadgesLayout,
    double? verticalSplitLeftFooterWidth,
    double? verticalSplitHeadlineTop,
    double? verticalSplitHeadlineLeft,
    double? verticalSplitRightBlockTop,
    double? verticalSplitRightBlockRight,
    double? verticalSplitLeftFooterBottom,
    double? verticalSplitLeftFooterLeft,
    double? verticalSplitRightFooterBottom,
    double? verticalSplitRightFooterRight,
    bool? verticalSplitShowHeadline,
    bool? verticalSplitShowLeftFooter,
    bool? verticalSplitShowRightBlock,
    bool? verticalSplitShowRightFooter,
    String? coverHeadlineFont,
    String? coverHeadlineColor,
    String? coverRightBlockFont,
    String? coverRightTitleColor,
    String? coverRightSubtitleColor,
    String? coverRightTaglineColor,
    String? coverBadgesTextColor,
    String? coverBadgesIconColor,
    String? coverFooterFont,
    String? coverFooterColor,
    List<CustomCoverTextItem>? customTextItems,
    List<CustomCoverIconItem>? customIconItems,
    double? coverClientInfoPositionX,
    double? coverClientInfoPositionY,
    double? coverClientInfoWidth,
    double? coverClientInfoFontSize,
    String? coverClientInfoColor,
    String? coverClientInfoSecondaryColor,
    bool? coverShowClientInfo,
    int? coverHeaderStyle,
    bool? coverShowHeader,
    String? coverHeaderText1,
    String? coverHeaderText2,
    String? coverHeaderText3,
    String? coverHeaderBgColor,
    String? coverHeaderTextColor,
    String? coverHeaderIconColor,
    int? coverFooterStyle,
    bool? coverShowFooter,
    String? coverFooterText1,
    String? coverFooterText2,
    String? coverFooterText3,
    String? coverFooterText4,
    String? coverFooterBgColor,
    String? coverFooterTextColor,
    String? coverFooterIconColor,
    String? page2TemplateId,
    String? page2CardsJson,
    bool? page2ShowIllustration,
    String? page2IllustrationType,
    String? hiddenPagesJson,
    String? customPagesJson,
    String? internalPagesLayoutPreset,
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
      coverTitle: coverTitle ?? this.coverTitle,
      coverSubtitle: coverSubtitle ?? this.coverSubtitle,
      coverShowBadge: coverShowBadge ?? this.coverShowBadge,
      coverBadgeColor: coverBadgeColor ?? this.coverBadgeColor,
      coverBadgeOpacity: coverBadgeOpacity ?? this.coverBadgeOpacity,
      coverTitleColor: coverTitleColor ?? this.coverTitleColor,
      coverSubtitleColor: coverSubtitleColor ?? this.coverSubtitleColor,
      coverTitleFontSize: coverTitleFontSize ?? this.coverTitleFontSize,
      coverSubtitleFontSize: coverSubtitleFontSize ?? this.coverSubtitleFontSize,
      coverBadgePositionX: coverBadgePositionX ?? this.coverBadgePositionX,
      coverBadgePositionY: coverBadgePositionY ?? this.coverBadgePositionY,
      customCoverImageBase64: customCoverImageBase64 ?? this.customCoverImageBase64,
      customDividerStyle: customDividerStyle ?? this.customDividerStyle,
      customDividerColor: customDividerColor ?? this.customDividerColor,
      customDividerBottomColor: customDividerBottomColor ?? this.customDividerBottomColor,
      isCustomCoverMode: isCustomCoverMode ?? this.isCustomCoverMode,
      companyLogoBase64: companyLogoBase64 ?? this.companyLogoBase64,
      coverShowLogo: coverShowLogo ?? this.coverShowLogo,
      coverLogoPositionX: coverLogoPositionX ?? this.coverLogoPositionX,
      coverLogoPositionY: coverLogoPositionY ?? this.coverLogoPositionY,
      coverLogoWidth: coverLogoWidth ?? this.coverLogoWidth,
      proposalStyle: proposalStyle ?? this.proposalStyle,
      selectedVerticalSplitTemplate: selectedVerticalSplitTemplate ?? this.selectedVerticalSplitTemplate,
      verticalSplitDividerType: verticalSplitDividerType ?? this.verticalSplitDividerType,
      verticalSplitHeadline: verticalSplitHeadline ?? this.verticalSplitHeadline,
      verticalSplitSubheadline: verticalSplitSubheadline ?? this.verticalSplitSubheadline,
      verticalSplitLeftFooter: verticalSplitLeftFooter ?? this.verticalSplitLeftFooter,
      verticalSplitRightTitle: verticalSplitRightTitle ?? this.verticalSplitRightTitle,
      verticalSplitRightSubtitle: verticalSplitRightSubtitle ?? this.verticalSplitRightSubtitle,
      verticalSplitRightTagline: verticalSplitRightTagline ?? this.verticalSplitRightTagline,
      verticalSplitRightFooter: verticalSplitRightFooter ?? this.verticalSplitRightFooter,
      verticalSplitShowRightDivider: verticalSplitShowRightDivider ?? this.verticalSplitShowRightDivider,
      verticalSplitRightDividerColor: verticalSplitRightDividerColor ?? this.verticalSplitRightDividerColor,
      verticalSplitRightDividerWidth: verticalSplitRightDividerWidth ?? this.verticalSplitRightDividerWidth,
      verticalSplitRightDividerHeight: verticalSplitRightDividerHeight ?? this.verticalSplitRightDividerHeight,
      verticalSplitShowHeadlineDivider: verticalSplitShowHeadlineDivider ?? this.verticalSplitShowHeadlineDivider,
      verticalSplitHeadlineDividerColor: verticalSplitHeadlineDividerColor ?? this.verticalSplitHeadlineDividerColor,
      verticalSplitHeadlineDividerWidth: verticalSplitHeadlineDividerWidth ?? this.verticalSplitHeadlineDividerWidth,
      verticalSplitHeadlineDividerHeight: verticalSplitHeadlineDividerHeight ?? this.verticalSplitHeadlineDividerHeight,
      verticalSplitAccentColor: verticalSplitAccentColor ?? this.verticalSplitAccentColor,
      verticalSplitFooterBadges: verticalSplitFooterBadges ?? this.verticalSplitFooterBadges,
      verticalSplitBadgesLayout: verticalSplitBadgesLayout ?? this.verticalSplitBadgesLayout,
      verticalSplitLeftFooterWidth: verticalSplitLeftFooterWidth ?? this.verticalSplitLeftFooterWidth,
      verticalSplitHeadlineTop: verticalSplitHeadlineTop ?? this.verticalSplitHeadlineTop,
      verticalSplitHeadlineLeft: verticalSplitHeadlineLeft ?? this.verticalSplitHeadlineLeft,
      verticalSplitRightBlockTop: verticalSplitRightBlockTop ?? this.verticalSplitRightBlockTop,
      verticalSplitRightBlockRight: verticalSplitRightBlockRight ?? this.verticalSplitRightBlockRight,
      verticalSplitLeftFooterBottom: verticalSplitLeftFooterBottom ?? this.verticalSplitLeftFooterBottom,
      verticalSplitLeftFooterLeft: verticalSplitLeftFooterLeft ?? this.verticalSplitLeftFooterLeft,
      verticalSplitRightFooterBottom: verticalSplitRightFooterBottom ?? this.verticalSplitRightFooterBottom,
      verticalSplitRightFooterRight: verticalSplitRightFooterRight ?? this.verticalSplitRightFooterRight,
      verticalSplitShowHeadline: verticalSplitShowHeadline ?? this.verticalSplitShowHeadline,
      verticalSplitShowLeftFooter: verticalSplitShowLeftFooter ?? this.verticalSplitShowLeftFooter,
      verticalSplitShowRightBlock: verticalSplitShowRightBlock ?? this.verticalSplitShowRightBlock,
      verticalSplitShowRightFooter: verticalSplitShowRightFooter ?? this.verticalSplitShowRightFooter,
      coverHeadlineFont: coverHeadlineFont ?? this.coverHeadlineFont,
      coverHeadlineColor: coverHeadlineColor ?? this.coverHeadlineColor,
      coverRightBlockFont: coverRightBlockFont ?? this.coverRightBlockFont,
      coverRightTitleColor: coverRightTitleColor ?? this.coverRightTitleColor,
      coverRightSubtitleColor: coverRightSubtitleColor ?? this.coverRightSubtitleColor,
      coverRightTaglineColor: coverRightTaglineColor ?? this.coverRightTaglineColor,
      coverBadgesTextColor: coverBadgesTextColor ?? this.coverBadgesTextColor,
      coverBadgesIconColor: coverBadgesIconColor ?? this.coverBadgesIconColor,
      coverFooterFont: coverFooterFont ?? this.coverFooterFont,
      customTextItems: customTextItems ?? this.customTextItems,
      customIconItems: customIconItems ?? this.customIconItems,
      coverClientInfoPositionX: coverClientInfoPositionX ?? this.coverClientInfoPositionX,
      coverClientInfoPositionY: coverClientInfoPositionY ?? this.coverClientInfoPositionY,
      coverClientInfoWidth: coverClientInfoWidth ?? this.coverClientInfoWidth,
      coverClientInfoFontSize: coverClientInfoFontSize ?? this.coverClientInfoFontSize,
      coverClientInfoColor: coverClientInfoColor ?? this.coverClientInfoColor,
      coverClientInfoSecondaryColor: coverClientInfoSecondaryColor ?? this.coverClientInfoSecondaryColor,
      coverShowClientInfo: coverShowClientInfo ?? this.coverShowClientInfo,
      coverHeaderStyle: coverHeaderStyle ?? this.coverHeaderStyle,
      coverShowHeader: coverShowHeader ?? this.coverShowHeader,
      coverHeaderText1: coverHeaderText1 ?? this.coverHeaderText1,
      coverHeaderText2: coverHeaderText2 ?? this.coverHeaderText2,
      coverHeaderText3: coverHeaderText3 ?? this.coverHeaderText3,
      coverHeaderBgColor: coverHeaderBgColor ?? this.coverHeaderBgColor,
      coverHeaderTextColor: coverHeaderTextColor ?? this.coverHeaderTextColor,
      coverHeaderIconColor: coverHeaderIconColor ?? this.coverHeaderIconColor,
      coverFooterStyle: coverFooterStyle ?? this.coverFooterStyle,
      coverShowFooter: coverShowFooter ?? this.coverShowFooter,
      coverFooterText1: coverFooterText1 ?? this.coverFooterText1,
      coverFooterText2: coverFooterText2 ?? this.coverFooterText2,
      coverFooterText3: coverFooterText3 ?? this.coverFooterText3,
      coverFooterText4: coverFooterText4 ?? this.coverFooterText4,
      coverFooterBgColor: coverFooterBgColor ?? this.coverFooterBgColor,
      coverFooterTextColor: coverFooterTextColor ?? this.coverFooterTextColor,
      coverFooterIconColor: coverFooterIconColor ?? this.coverFooterIconColor,
      page2TemplateId: page2TemplateId ?? this.page2TemplateId,
      page2CardsJson: page2CardsJson ?? this.page2CardsJson,
      page2ShowIllustration: page2ShowIllustration ?? this.page2ShowIllustration,
      page2IllustrationType: page2IllustrationType ?? this.page2IllustrationType,
      hiddenPagesJson: hiddenPagesJson ?? this.hiddenPagesJson,
      customPagesJson: customPagesJson ?? this.customPagesJson,
      internalPagesLayoutPreset: internalPagesLayoutPreset ?? this.internalPagesLayoutPreset,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'page2TemplateId': page2TemplateId,
      'page2CardsJson': page2CardsJson,
      'page2ShowIllustration': page2ShowIllustration,
      'page2IllustrationType': page2IllustrationType,
      'hiddenPagesJson': hiddenPagesJson,
      'customPagesJson': customPagesJson,
      'internalPagesLayoutPreset': internalPagesLayoutPreset,
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
      'coverTitle': coverTitle,
      'coverSubtitle': coverSubtitle,
      'coverShowBadge': coverShowBadge,
      'coverBadgeColor': coverBadgeColor,
      'coverBadgeOpacity': coverBadgeOpacity,
      'coverTitleColor': coverTitleColor,
      'coverSubtitleColor': coverSubtitleColor,
      'coverTitleFontSize': coverTitleFontSize,
      'coverSubtitleFontSize': coverSubtitleFontSize,
      'coverBadgePositionX': coverBadgePositionX,
      'coverBadgePositionY': coverBadgePositionY,
      'customCoverImageBase64': customCoverImageBase64,
      'customDividerStyle': customDividerStyle,
      'customDividerColor': customDividerColor,
      'customDividerBottomColor': customDividerBottomColor,
      'isCustomCoverMode': isCustomCoverMode,
      'companyLogoBase64': companyLogoBase64,
      'coverShowLogo': coverShowLogo,
      'coverLogoPositionX': coverLogoPositionX,
      'coverLogoPositionY': coverLogoPositionY,
      'coverLogoWidth': coverLogoWidth,
      'proposalStyle': proposalStyle,
      'selectedVerticalSplitTemplate': selectedVerticalSplitTemplate,
      'verticalSplitDividerType': verticalSplitDividerType,
      'verticalSplitHeadline': verticalSplitHeadline,
      'verticalSplitSubheadline': verticalSplitSubheadline,
      'verticalSplitLeftFooter': verticalSplitLeftFooter,
      'verticalSplitRightTitle': verticalSplitRightTitle,
      'verticalSplitRightSubtitle': verticalSplitRightSubtitle,
      'verticalSplitRightTagline': verticalSplitRightTagline,
      'verticalSplitRightFooter': verticalSplitRightFooter,
      'verticalSplitShowRightDivider': verticalSplitShowRightDivider,
      'verticalSplitRightDividerColor': verticalSplitRightDividerColor,
      'verticalSplitRightDividerWidth': verticalSplitRightDividerWidth,
      'verticalSplitRightDividerHeight': verticalSplitRightDividerHeight,
      'verticalSplitShowHeadlineDivider': verticalSplitShowHeadlineDivider,
      'verticalSplitHeadlineDividerColor': verticalSplitHeadlineDividerColor,
      'verticalSplitHeadlineDividerWidth': verticalSplitHeadlineDividerWidth,
      'verticalSplitHeadlineDividerHeight': verticalSplitHeadlineDividerHeight,
      'verticalSplitAccentColor': verticalSplitAccentColor,
      'verticalSplitFooterBadges': verticalSplitFooterBadges.map((b) => b.toMap()).toList(),
      'verticalSplitBadgesLayout': verticalSplitBadgesLayout,
      'verticalSplitLeftFooterWidth': verticalSplitLeftFooterWidth,
      'verticalSplitHeadlineTop': verticalSplitHeadlineTop,
      'verticalSplitHeadlineLeft': verticalSplitHeadlineLeft,
      'verticalSplitRightBlockTop': verticalSplitRightBlockTop,
      'verticalSplitRightBlockRight': verticalSplitRightBlockRight,
      'verticalSplitLeftFooterBottom': verticalSplitLeftFooterBottom,
      'verticalSplitLeftFooterLeft': verticalSplitLeftFooterLeft,
      'verticalSplitRightFooterBottom': verticalSplitRightFooterBottom,
      'verticalSplitRightFooterRight': verticalSplitRightFooterRight,
      'verticalSplitShowHeadline': verticalSplitShowHeadline,
      'verticalSplitShowLeftFooter': verticalSplitShowLeftFooter,
      'verticalSplitShowRightBlock': verticalSplitShowRightBlock,
      'verticalSplitShowRightFooter': verticalSplitShowRightFooter,
      'coverHeadlineFont': coverHeadlineFont,
      'coverHeadlineColor': coverHeadlineColor,
      'coverRightBlockFont': coverRightBlockFont,
      'coverRightTitleColor': coverRightTitleColor,
      'coverRightSubtitleColor': coverRightSubtitleColor,
      'coverRightTaglineColor': coverRightTaglineColor,
      'coverBadgesTextColor': coverBadgesTextColor,
      'coverBadgesIconColor': coverBadgesIconColor,
      'coverFooterFont': coverFooterFont,
      'coverFooterColor': coverFooterColor,
      'customTextItems': customTextItems.map((t) => t.toMap()).toList(),
      'customIconItems': customIconItems.map((i) => i.toMap()).toList(),
      'coverClientInfoPositionX': coverClientInfoPositionX,
      'coverClientInfoPositionY': coverClientInfoPositionY,
      'coverClientInfoWidth': coverClientInfoWidth,
      'coverClientInfoFontSize': coverClientInfoFontSize,
      'coverClientInfoColor': coverClientInfoColor,
      'coverClientInfoSecondaryColor': coverClientInfoSecondaryColor,
      'coverShowClientInfo': coverShowClientInfo,
      'coverHeaderStyle': coverHeaderStyle,
      'coverShowHeader': coverShowHeader,
      'coverHeaderText1': coverHeaderText1,
      'coverHeaderText2': coverHeaderText2,
      'coverHeaderText3': coverHeaderText3,
      'coverHeaderBgColor': coverHeaderBgColor,
      'coverHeaderTextColor': coverHeaderTextColor,
      'coverHeaderIconColor': coverHeaderIconColor,
      'coverFooterStyle': coverFooterStyle,
      'coverShowFooter': coverShowFooter,
      'coverFooterText1': coverFooterText1,
      'coverFooterText2': coverFooterText2,
      'coverFooterText3': coverFooterText3,
      'coverFooterText4': coverFooterText4,
      'coverFooterBgColor': coverFooterBgColor,
      'coverFooterTextColor': coverFooterTextColor,
      'coverFooterIconColor': coverFooterIconColor,
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
      selectedCoverTemplate: map['selectedCoverTemplate'] as String? ?? 'modelo_proposta_1.jpg',
      selectedSvgTheme: (map['selectedSvgTheme'] ?? map['selectedSvgFooter'] ?? map['selectedSvgHeader']) as String? ?? '#2563EB',
      webBackgroundTemplate: map['webBackgroundTemplate'] as String? ?? 'AdobeStock_1030854734.jpg',
      companyName: map['companyName'] as String?,
      companyDocument: map['companyDocument'] as String?,
      companyPhone: map['companyPhone'] as String?,
      companyWebsite: map['companyWebsite'] as String?,
      companyInstagram: map['companyInstagram'] as String?,
      companySlogan: map['companySlogan'] as String?,
      coverTitle: map['coverTitle'] as String? ?? 'PROPOSTA COMERCIAL',
      coverSubtitle: map['coverSubtitle'] as String? ?? 'ENERGIA SOLAR FOTOVOLTAICA',
      coverShowBadge: map['coverShowBadge'] as bool? ?? true,
      coverBadgeColor: map['coverBadgeColor'] as String? ?? '#FFFFFF',
      coverBadgeOpacity: (map['coverBadgeOpacity'] as num?)?.toDouble() ?? 0.92,
      coverTitleColor: map['coverTitleColor'] as String? ?? '#0284C7',
      coverSubtitleColor: map['coverSubtitleColor'] as String? ?? '#0F172A',
      coverTitleFontSize: (map['coverTitleFontSize'] as num?)?.toDouble() ?? 26.0,
      coverSubtitleFontSize: (map['coverSubtitleFontSize'] as num?)?.toDouble() ?? 11.0,
      coverBadgePositionX: (map['coverBadgePositionX'] as num?)?.toDouble() ?? 0.08,
      coverBadgePositionY: (map['coverBadgePositionY'] as num?)?.toDouble() ?? 0.06,
      customCoverImageBase64: map['customCoverImageBase64'] as String?,
      customDividerStyle: (map['customDividerStyle'] as num?)?.toInt() ?? 0,
      customDividerColor: map['customDividerColor'] as String? ?? '#0284C7',
      customDividerBottomColor: map['customDividerBottomColor'] as String? ?? '#FFFFFF',
      isCustomCoverMode: map['isCustomCoverMode'] as bool? ?? false,
      companyLogoBase64: map['companyLogoBase64'] as String?,
      coverShowLogo: map['coverShowLogo'] as bool? ?? true,
      coverLogoPositionX: (map['coverLogoPositionX'] as num?)?.toDouble() ?? 0.65,
      coverLogoPositionY: (map['coverLogoPositionY'] as num?)?.toDouble() ?? 0.05,
      coverLogoWidth: (map['coverLogoWidth'] as num?)?.toDouble() ?? 90.0,
      proposalStyle: map['proposalStyle'] as String? ?? 'modern',
      selectedVerticalSplitTemplate: map['selectedVerticalSplitTemplate'] as String? ?? 'vertical_split_1',
      verticalSplitDividerType: (map['verticalSplitDividerType'] as num?)?.toInt() ?? 0,
      verticalSplitHeadline: map['verticalSplitHeadline'] as String? ?? 'ENERGIA\nQUE MOVE\nO SEU\nAMANHÃ',
      verticalSplitSubheadline: map['verticalSplitSubheadline'] as String? ?? 'MAIS ECONOMIA.\nMAIS LIBERDADE.\nUM FUTURO SUSTENTÁVEL.',
      verticalSplitLeftFooter: map['verticalSplitLeftFooter'] as String? ?? 'PESSOAS  •  TECNOLOGIA  •  UM PLANETA MELHOR',
      verticalSplitRightTitle: map['verticalSplitRightTitle'] as String? ?? 'PROPOSTA',
      verticalSplitRightSubtitle: map['verticalSplitRightSubtitle'] as String? ?? 'SOLAR',
      verticalSplitRightTagline: map['verticalSplitRightTagline'] as String? ?? 'SOLUÇÕES EM ENERGIA\nPARA UM FUTURO MELHOR',
      verticalSplitRightFooter: map['verticalSplitRightFooter'] as String? ?? 'ENERGIA HOJE.\nMAIS POSSIBILIDADES\nAMANHÃ.',
      verticalSplitShowRightDivider: map['verticalSplitShowRightDivider'] as bool? ?? true,
      verticalSplitRightDividerColor: map['verticalSplitRightDividerColor'] as String? ?? '',
      verticalSplitRightDividerWidth: (map['verticalSplitRightDividerWidth'] as num?)?.toDouble() ?? 54.0,
      verticalSplitRightDividerHeight: (map['verticalSplitRightDividerHeight'] as num?)?.toDouble() ?? 4.5,
      verticalSplitShowHeadlineDivider: map['verticalSplitShowHeadlineDivider'] as bool? ?? true,
      verticalSplitHeadlineDividerColor: map['verticalSplitHeadlineDividerColor'] as String? ?? '',
      verticalSplitHeadlineDividerWidth: (map['verticalSplitHeadlineDividerWidth'] as num?)?.toDouble() ?? 48.0,
      verticalSplitHeadlineDividerHeight: (map['verticalSplitHeadlineDividerHeight'] as num?)?.toDouble() ?? 4.0,
      verticalSplitAccentColor: map['verticalSplitAccentColor'] as String? ?? '#EAB308',
      verticalSplitFooterBadges: map['verticalSplitFooterBadges'] is List
          ? (map['verticalSplitFooterBadges'] as List)
              .whereType<Map>()
              .map((e) => CoverFooterBadge.fromMap(Map<String, dynamic>.from(e)))
              .toList()
          : CoverFooterBadge.defaultBadges(),
      verticalSplitBadgesLayout: map['verticalSplitBadgesLayout'] as String? ?? 'horizontal',
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
      coverHeadlineFont: map['coverHeadlineFont'] as String? ?? 'Montserrat',
      coverHeadlineColor: map['coverHeadlineColor'] as String? ?? '#FFFFFF',
      coverRightBlockFont: map['coverRightBlockFont'] as String? ?? 'Montserrat',
      coverRightTitleColor: map['coverRightTitleColor'] as String? ?? '#334155',
      coverRightSubtitleColor: map['coverRightSubtitleColor'] as String? ?? '#0F172A',
      coverRightTaglineColor: map['coverRightTaglineColor'] as String? ?? '#475569',
      coverBadgesTextColor: map['coverBadgesTextColor'] as String? ?? '#FFFFFF',
      coverBadgesIconColor: map['coverBadgesIconColor'] as String? ?? '',
      coverFooterFont: map['coverFooterFont'] as String? ?? 'Montserrat',
      coverFooterColor: map['coverFooterColor'] as String? ?? '#64748B',
      customTextItems: map['customTextItems'] is List
          ? (map['customTextItems'] as List)
              .whereType<Map>()
              .map((e) => CustomCoverTextItem.fromMap(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      customIconItems: map['customIconItems'] is List
          ? (map['customIconItems'] as List)
              .whereType<Map>()
              .map((e) => CustomCoverIconItem.fromMap(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      coverClientInfoPositionX: (map['coverClientInfoPositionX'] as num?)?.toDouble() ?? 0.58,
      coverClientInfoPositionY: (map['coverClientInfoPositionY'] as num?)?.toDouble() ?? 0.88,
      coverClientInfoWidth: (map['coverClientInfoWidth'] as num?)?.toDouble() ?? 240.0,
      coverClientInfoFontSize: (map['coverClientInfoFontSize'] as num?)?.toDouble() ?? 8.5,
      coverClientInfoColor: map['coverClientInfoColor'] as String? ?? '#0F172A',
      coverClientInfoSecondaryColor: map['coverClientInfoSecondaryColor'] as String? ?? '#475569',
      coverShowClientInfo: map['coverShowClientInfo'] as bool? ?? true,
      coverHeaderStyle: (map['coverHeaderStyle'] as num?)?.toInt() ?? 9,
      coverShowHeader: map['coverShowHeader'] as bool? ?? true,
      coverHeaderText1: map['coverHeaderText1'] as String? ?? 'PROPOSTA COMERCIAL',
      coverHeaderText2: map['coverHeaderText2'] as String? ?? 'ENERGIA SOLAR FOTOVOLTAICA',
      coverHeaderText3: map['coverHeaderText3'] as String? ?? 'SOLUÇÕES SUSTENTÁVEIS DE ALTA PERFORMANCE',
      coverHeaderBgColor: map['coverHeaderBgColor'] as String? ?? '#0F172A',
      coverHeaderTextColor: map['coverHeaderTextColor'] as String? ?? '#FFFFFF',
      coverHeaderIconColor: map['coverHeaderIconColor'] as String? ?? '#38BDF8',
      coverFooterStyle: (map['coverFooterStyle'] as num?)?.toInt() ?? 1,
      coverShowFooter: map['coverShowFooter'] as bool? ?? true,
      coverFooterText1: map['coverFooterText1'] as String? ?? 'ENERGIA LIMPA • ECONOMIA REAL • VALORIZAÇÃO',
      coverFooterText2: map['coverFooterText2'] as String? ?? '(11) 00000-0000 • contato@suaempresa.com.br',
      coverFooterText3: map['coverFooterText3'] as String? ?? 'www.suaempresa.com.br',
      coverFooterText4: map['coverFooterText4'] as String? ?? 'Proposta válida por 10 dias corridos a partir da data de emissão.',
      coverFooterBgColor: map['coverFooterBgColor'] as String? ?? '#0F172A',
      coverFooterTextColor: map['coverFooterTextColor'] as String? ?? '#CBD5E1',
      coverFooterIconColor: map['coverFooterIconColor'] as String? ?? '#38BDF8',
      page2TemplateId: map['page2TemplateId'] as String? ?? 'tpl_01_tech_grid',
      page2CardsJson: map['page2CardsJson'] as String?,
      page2ShowIllustration: map['page2ShowIllustration'] as bool? ?? true,
      page2IllustrationType: map['page2IllustrationType'] as String? ?? 'banner',
      hiddenPagesJson: map['hiddenPagesJson'] as String?,
      customPagesJson: map['customPagesJson'] as String?,
      internalPagesLayoutPreset: map['internalPagesLayoutPreset'] as String? ?? 'preset_01',
    );
  }

  static SolarSettingsModel initial() {
    return SolarSettingsModel(
      financingBanks: SolarFinancingBank.defaultBanks(),
      creditCardRates: CreditCardInstallmentRate.defaultRates(),
    );
  }
}
