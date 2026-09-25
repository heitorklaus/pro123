import 'dart:convert';
import 'proposal_pages_models.dart';

/// Nó Cibernético de Automação Flutuante na Fachada da Residência
class AutomationCyberNode {
  final String id;
  final String label;
  final String iconName; // 'light', 'music', 'temp', 'camera', 'lock', 'wifi', 'curtain'
  final double posX;
  final double posY;
  final double targetX;
  final double targetY;
  final String colorHex;
  final bool showConnectorLine;

  const AutomationCyberNode({
    required this.id,
    required this.label,
    required this.iconName,
    required this.posX,
    required this.posY,
    this.targetX = 0.5,
    this.targetY = 0.5,
    this.colorHex = '#38BDF8',
    this.showConnectorLine = true,
  });

  AutomationCyberNode copyWith({
    String? id,
    String? label,
    String? iconName,
    double? posX,
    double? posY,
    double? targetX,
    double? targetY,
    String? colorHex,
    bool? showConnectorLine,
  }) {
    return AutomationCyberNode(
      id: id ?? this.id,
      label: label ?? this.label,
      iconName: iconName ?? this.iconName,
      posX: posX ?? this.posX,
      posY: posY ?? this.posY,
      targetX: targetX ?? this.targetX,
      targetY: targetY ?? this.targetY,
      colorHex: colorHex ?? this.colorHex,
      showConnectorLine: showConnectorLine ?? this.showConnectorLine,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'iconName': iconName,
      'posX': posX,
      'posY': posY,
      'targetX': targetX,
      'targetY': targetY,
      'colorHex': colorHex,
      'showConnectorLine': showConnectorLine,
    };
  }

  factory AutomationCyberNode.fromMap(Map<String, dynamic> map) {
    return AutomationCyberNode(
      id: map['id'] as String? ?? 'node_${DateTime.now().millisecondsSinceEpoch}',
      label: map['label'] as String? ?? 'Ponto de Automação',
      iconName: map['iconName'] as String? ?? 'light',
      posX: (map['posX'] as num?)?.toDouble() ?? 0.5,
      posY: (map['posY'] as num?)?.toDouble() ?? 0.5,
      targetX: (map['targetX'] as num?)?.toDouble() ?? 0.5,
      targetY: (map['targetY'] as num?)?.toDouble() ?? 0.5,
      colorHex: map['colorHex'] as String? ?? '#38BDF8',
      showConnectorLine: map['showConnectorLine'] as bool? ?? true,
    );
  }

  static List<AutomationCyberNode> defaultNodes() {
    return const [
      AutomationCyberNode(id: 'node_light', label: 'Iluminação Cênica', iconName: 'light', posX: 0.54, posY: 0.31, targetX: 0.50, targetY: 0.35, colorHex: '#38BDF8'),
      AutomationCyberNode(id: 'node_music', label: 'Áudio Multiroom', iconName: 'music', posX: 0.40, posY: 0.52, targetX: 0.38, targetY: 0.58, colorHex: '#38BDF8'),
      AutomationCyberNode(id: 'node_temp', label: 'Climatização HVAC', iconName: 'temp', posX: 0.93, posY: 0.29, targetX: 0.88, targetY: 0.32, colorHex: '#38BDF8'),
      AutomationCyberNode(id: 'node_camera', label: 'Monitoramento AI', iconName: 'camera', posX: 0.94, posY: 0.46, targetX: 0.90, targetY: 0.48, colorHex: '#38BDF8'),
      AutomationCyberNode(id: 'node_lock', label: 'Controle de Acesso', iconName: 'lock', posX: 0.78, posY: 0.58, targetX: 0.76, targetY: 0.62, colorHex: '#38BDF8'),
    ];
  }
}

/// Item de texto customizado adicional na capa da proposta PDF
class CustomCoverTextItem {
  final String id;
  final String text;
  final double x;
  final double y;
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

/// Item de badge/ícone no rodapé da capa da proposta PDF
class CoverFooterBadge {
  final String iconKey;
  final String label;

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
      iconKey: map['iconKey'] as String? ?? 'bolt',
      label: map['label'] as String? ?? '',
    );
  }

  static List<CoverFooterBadge> defaultBadges() {
    return const [
      CoverFooterBadge(iconKey: 'light', label: 'ILUMINAÇÃO CÊNICA'),
      CoverFooterBadge(iconKey: 'music', label: 'ÁUDIO HIGH-END'),
      CoverFooterBadge(iconKey: 'temp', label: 'CLIMATIZAÇÃO IA'),
      CoverFooterBadge(iconKey: 'lock', label: 'ACESSO BIOMÉTRICO'),
    ];
  }
}

/// Item de ícone customizado flutuante na capa da proposta PDF
class CustomCoverIconItem {
  final String id;
  final String iconKey;
  final double x;
  final double y;
  final double size;
  final int colorValue;

  const CustomCoverIconItem({
    required this.id,
    required this.iconKey,
    required this.x,
    required this.y,
    this.size = 28.0,
    this.colorValue = 0xFF38BDF8,
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
      iconKey: map['iconKey'] as String? ?? 'light',
      x: (map['x'] as num?)?.toDouble() ?? 0.5,
      y: (map['y'] as num?)?.toDouble() ?? 0.5,
      size: (map['size'] as num?)?.toDouble() ?? 28.0,
      colorValue: (map['colorValue'] as num?)?.toInt() ?? 0xFF38BDF8,
    );
  }
}

/// Modelo Global de Configurações do Nicho de Automação Residencial
class AutomationSettingsModel {
  static const List<String> availableWebBackgrounds = [
    'AdobeStock_1030854734.jpg',
    'AdobeStock_1031317586.jpg',
    'AdobeStock_1031317666.jpg',
    'AdobeStock_1031317730.jpg',
    'AdobeStock_1031317777.jpg',
    'AdobeStock_1031317804.jpg',
    'AdobeStock_1044458319.jpg',
    'AdobeStock_1052673238.jpg',
    'AdobeStock_1054366699.jpg',
    'AdobeStock_1079374092.jpg',
    'AdobeStock_1082596489.jpg',
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

  final String companyId;

  // 🏢 1. Dados da Empresa
  final String companyName;
  final String companyDoc;
  final String companyPhone;
  final String companyEmail;
  final String companyWebsite;
  final String companyInstagram;
  final String companySlogan;
  final String? companyLogoBase64;

  // 📍 Endereço da Empresa (ViaCEP)
  final String cep;
  final String logradouro;
  final String numero;
  final String complemento;
  final String bairro;
  final String cidade;
  final String uf;

  // 📄 2. Configurações da Capa da Proposta PDF A4
  final String activeCategory; // 'Cyber Mansion' ou 'Cyber Divider'
  final String activePresetId;
  final bool isCustomCoverMode;
  final bool isFullPhoto;
  final String proposalStyle; // 'modern' ou 'verticalSplit'
  final String selectedCoverTemplate; // ex: 'modelo_automacao_1.jpg'
  final String webBackgroundTemplate; // ex: 'AdobeStock_1030854734.jpg'

  final String coverTitle;
  final String coverSubtitle;
  final String coverTag;
  final String coverHeadline;
  final String coverSubheadline;
  final String coverTitleColor;
  final String coverSubtitleColor;
  final double coverTitleFontSize;
  final double coverSubtitleFontSize;
  final String coverFontFamily;
  final String coverBadgeColor;
  final double coverBadgeOpacity;
  final bool coverShowBadge;
  final double coverBadgePositionX;
  final double coverBadgePositionY;

  final String clientTitle;
  final String clientName;
  final String proposalCode;

  final String coverImageUrl;
  final String? customCoverImageBase64;
  final int customDividerStyle; // 0 a 9 (10 Opções Matemáticas)
  final String customDividerColor;
  final String customDividerBottomColor;
  final String customDividerDarkColor;
  final String primaryColorHex;

  final bool showCoverTag;
  final bool showCoverHeadline;
  final bool showCoverSubheadline;
  final bool showClientCard;
  final bool showProposalCode;
  final bool showLogo;

  final double logoPosX;
  final double logoPosY;
  final double logoWidth;

  // Aliases compatíveis com SolarCoverCustomizer
  bool get coverShowLogo => showLogo;
  double get coverLogoPositionX => logoPosX;
  double get coverLogoPositionY => logoPosY;
  double get coverLogoWidth => logoWidth;

  final String cardBgColorHex;
  final double cardOpacity;
  final double clientCardPosX;
  final double clientCardPosY;

  // 📐 Vertical Split Studio Fields
  final int verticalSplitDividerType; // 0 = Diagonal, 1 = Raio/Zigzag, 2 = Arco
  final String verticalSplitHeadline;
  final String verticalSplitSubheadline;
  final String verticalSplitRightTitle;
  final String verticalSplitRightSubtitle;
  final String verticalSplitRightTagline;
  final String verticalSplitLeftFooter;
  final String verticalSplitRightFooter;
  final String verticalSplitAccentColor;
  final double verticalSplitHeadlineTop;
  final double verticalSplitHeadlineLeft;
  final double verticalSplitRightBlockTop;
  final double verticalSplitRightBlockRight;
  final double verticalSplitLeftFooterBottom;
  final double verticalSplitLeftFooterLeft;
  final double verticalSplitLeftFooterWidth;
  final double verticalSplitRightFooterBottom;
  final double verticalSplitRightFooterRight;
  final bool verticalSplitShowHeadline;
  final bool verticalSplitShowRightBlock;
  final bool verticalSplitShowLeftFooter;
  final bool verticalSplitShowRightFooter;
  final String verticalSplitBadgesLayout; // 'horizontal', 'vertical', 'wrap'
  final bool verticalSplitShowRightDivider;
  final String verticalSplitRightDividerColor;
  final double verticalSplitRightDividerWidth;
  final double verticalSplitRightDividerHeight;
  final bool verticalSplitShowHeadlineDivider;
  final String verticalSplitHeadlineDividerColor;
  final double verticalSplitHeadlineDividerWidth;
  final double verticalSplitHeadlineDividerHeight;
  final double coverNodesLabelFontSize;
  final List<CoverFooterBadge> verticalSplitFooterBadges;

  // Fontes e Cores Estendidas
  final String coverHeadlineFont;
  final String coverRightBlockFont;
  final String coverFooterFont;
  final String coverHeadlineColor;
  final String coverRightTitleColor;
  final String coverRightSubtitleColor;
  final String coverRightTaglineColor;
  final String coverFooterColor;
  final String coverBadgesTextColor;
  final String coverBadgesIconColor; // default: '' (usa coverBadgesTextColor quando vazio)

  // Itens Livres (Drag & Drop Canvas)
  final List<CustomCoverTextItem> customTextItems;
  final List<CoverFooterBadge> customIconBadges;
  final List<CustomCoverIconItem> customIconItems;
  final List<AutomationCyberNode> nodes;

  final double headerPosX;
  final double headerPosY;
  final double headlinePosX;
  final double headlinePosY;

  final String pdfTermsText;

  // Bloco de Informações do Cliente & CPF/CNPJ (Arrastável, Redimensionável e com Cores)
  final double coverClientInfoPositionX; // default: 0.58
  final double coverClientInfoPositionY; // default: 0.88
  final double coverClientInfoWidth; // default: 240.0
  final double coverClientInfoFontSize; // default: 8.5
  final String coverClientInfoColor; // default: '#0F172A'
  final String coverClientInfoSecondaryColor; // default: '#38BDF8'
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

  // ── Customização da Página 3 (Portfólio & Clientes) ───────────────
  final String page3Title;
  final String page3Subtitle;
  final String? page3PortfolioJson;
  final String page3BgColor;
  final String page3CardBgColor;
  final String page3BorderColor;
  final String page3TitleColor;
  final String page3SubtitleColor;
  final String page3AccentColor;

  // ── Customização Visual da Página 4 (Ambientes & Equipamentos) ──────
  final String page4BgColor;
  final String page4CardBgColor;
  final String page4BorderColor;
  final String page4TitleColor;
  final String page4SubtitleColor;
  final String page4AccentColor;

  List<AutomationPortfolioItem> get page3PortfolioItems {
    if (page3PortfolioJson != null && page3PortfolioJson!.isNotEmpty) {
      try {
        final list = jsonDecode(page3PortfolioJson!) as List<dynamic>;
        return list.map((e) => AutomationPortfolioItem.fromMap(e as Map<String, dynamic>)).toList();
      } catch (_) {}
    }
    return AutomationPortfolioItem.defaultItems();
  }

  List<ProposalPageCard> get page2Cards {
    if (page2CardsJson != null && page2CardsJson!.isNotEmpty) {
      try {
        final list = jsonDecode(page2CardsJson!) as List<dynamic>;
        return list.map((e) => ProposalPageCard.fromMap(e as Map<String, dynamic>)).toList();
      } catch (_) {}
    }
    return ProposalPageCard.defaultAutomationCards();
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

  static int _hexToColor(String hexStr, {required int fallback}) {
    final hex = hexStr.replaceAll('#', '').trim();
    if (hex.length == 6) return int.tryParse('FF$hex', radix: 16) ?? fallback;
    if (hex.length == 8) return int.tryParse(hex, radix: 16) ?? fallback;
    return fallback;
  }

  // Helpers de Cores Int
  int get verticalSplitAccentColorValue => _hexToColor(verticalSplitAccentColor, fallback: 0xFF38BDF8);
  int get coverHeadlineColorValue => _hexToColor(coverHeadlineColor, fallback: 0xFFFFFFFF);
  int get coverRightTitleColorValue => _hexToColor(coverRightTitleColor, fallback: 0xFF0284C7);
  int get coverRightSubtitleColorValue => _hexToColor(coverRightSubtitleColor, fallback: 0xFFFFFFFF);
  int get coverRightTaglineColorValue => _hexToColor(coverRightTaglineColor, fallback: 0xFFCBD5E1);
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
  int get coverFooterColorValue => _hexToColor(coverFooterColor, fallback: 0xFF94A3B8);
  int get coverBadgesTextColorValue => _hexToColor(coverBadgesTextColor, fallback: 0xFFFFFFFF);
  int get coverBadgesIconColorValue {
    if (coverBadgesIconColor.trim().isNotEmpty) {
      return _hexToColor(coverBadgesIconColor, fallback: coverBadgesTextColorValue);
    }
    return coverBadgesTextColorValue;
  }
  int get customDividerBottomColorValue {
    final hex = customDividerBottomColor.replaceAll('#', '').trim();
    if (hex.length == 6) return int.tryParse('FF$hex', radix: 16) ?? 0xFFFFFFFF;
    if (hex.length == 8) return int.tryParse(hex, radix: 16) ?? 0xFFFFFFFF;
    return 0xFFFFFFFF;
  }

  int get coverClientInfoColorValue {
    final hex = coverClientInfoColor.replaceAll('#', '').trim();
    if (hex.length == 6) return int.tryParse('FF$hex', radix: 16) ?? 0xFF0F172A;
    if (hex.length == 8) return int.tryParse(hex, radix: 16) ?? 0xFF0F172A;
    return 0xFF0F172A;
  }

  int get coverClientInfoSecondaryColorValue {
    final hex = coverClientInfoSecondaryColor.replaceAll('#', '').trim();
    if (hex.length == 6) return int.tryParse('FF$hex', radix: 16) ?? 0xFF38BDF8;
    if (hex.length == 8) return int.tryParse(hex, radix: 16) ?? 0xFF38BDF8;
    return 0xFF38BDF8;
  }

  const AutomationSettingsModel({
    this.companyId = '',
    this.companyName = 'ARBO AUTOMAÇÃO',
    this.companyDoc = '12.345.678/0001-90',
    this.companyPhone = '(11) 98765-4321',
    this.companyEmail = 'contato@arboautomacao.com.br',
    this.companyWebsite = 'www.arboautomacao.com.br',
    this.companyInstagram = '@arbo.automacao',
    this.companySlogan = 'Arquitetura & Tecnologia Integradas',
    this.companyLogoBase64,
    this.cep = '01001-000',
    this.logradouro = 'Praça da Sé',
    this.numero = '100',
    this.complemento = 'Bloco A - Conjunto 12',
    this.bairro = 'Sé',
    this.cidade = 'São Paulo',
    this.uf = 'SP',
    this.activeCategory = 'Cyber Mansion',
    this.activePresetId = 'auto_cover_01',
    this.isCustomCoverMode = false,
    this.isFullPhoto = true,
    this.proposalStyle = 'modern',
    this.selectedCoverTemplate = 'modelo_automacao_1.jpg',
    this.webBackgroundTemplate = 'AdobeStock_1030854734.jpg',
    this.coverTitle = 'PROPOSTA COMERCIAL',
    this.coverSubtitle = 'AUTOMAÇÃO RESIDENCIAL HIGH-END',
    this.coverTag = 'PROPOSTA / 2026',
    this.coverHeadline = 'A casa que entende você.',
    this.coverSubheadline = 'Arquitetura, conforto e tecnologia integrados em uma experiência única.',
    this.coverTitleColor = '#38BDF8',
    this.coverSubtitleColor = '#FFFFFF',
    this.coverTitleFontSize = 26.0,
    this.coverSubtitleFontSize = 11.0,
    this.coverFontFamily = 'Montserrat',
    this.coverBadgeColor = '#0F172A',
    this.coverBadgeOpacity = 0.85,
    this.coverShowBadge = true,
    this.coverBadgePositionX = 0.08,
    this.coverBadgePositionY = 0.06,
    this.clientTitle = 'RESIDÊNCIA',
    this.clientName = 'Família Klaus',
    this.proposalCode = 'ARBO-2026-001',
    this.coverImageUrl = 'modelo_automacao_1.jpg',
    this.customCoverImageBase64,
    this.customDividerStyle = 0,
    this.customDividerColor = '#38BDF8',
    this.customDividerBottomColor = '#FFFFFF',
    this.customDividerDarkColor = '#0F172A',
    this.primaryColorHex = '#38BDF8',
    this.showCoverTag = true,
    this.showCoverHeadline = true,
    this.showCoverSubheadline = true,
    this.showClientCard = true,
    this.showProposalCode = true,
    this.showLogo = true,
    this.logoPosX = 0.78,
    this.logoPosY = 0.06,
    this.logoWidth = 90.0,
    this.cardBgColorHex = '#0F172A',
    this.cardOpacity = 0.85,
    this.clientCardPosX = 0.06,
    this.clientCardPosY = 0.88,
    this.verticalSplitDividerType = 0,
    this.verticalSplitHeadline = 'A CASA QUE\nENTENDE\nVOCÊ',
    this.verticalSplitSubheadline = 'ARQUITETURA, CONFORTO\nE TECNOLOGIA\nEM UMA EXPERIÊNCIA ÚNICA.',
    this.verticalSplitRightTitle = 'PROPOSTA',
    this.verticalSplitRightSubtitle = 'AUTOMAÇÃO',
    this.verticalSplitRightTagline = 'PROJETO DE AUTOMAÇÃO\nRESIDENCIAL HIGH-END',
    this.verticalSplitLeftFooter = 'CONFORTO HOJE.\nMAIS INTELIGÊNCIA\nAMANHÃ.',
    this.verticalSplitRightFooter = 'SOLUÇÕES EXCLUSIVAS EM\nAUTOMAÇÃO RESIDENCIAL',
    this.verticalSplitAccentColor = '#38BDF8',
    this.verticalSplitHeadlineTop = 0.50,
    this.verticalSplitHeadlineLeft = 0.06,
    this.verticalSplitRightBlockTop = 0.04,
    this.verticalSplitRightBlockRight = 0.48,
    this.verticalSplitLeftFooterBottom = 0.26,
    this.verticalSplitLeftFooterLeft = 0.06,
    this.verticalSplitLeftFooterWidth = 0.44,
    this.verticalSplitRightFooterBottom = 0.06,
    this.verticalSplitRightFooterRight = 0.06,
    this.verticalSplitShowHeadline = true,
    this.verticalSplitShowRightBlock = true,
    this.verticalSplitShowLeftFooter = true,
    this.verticalSplitShowRightFooter = true,
    this.verticalSplitBadgesLayout = 'horizontal',
    this.verticalSplitShowRightDivider = true,
    this.verticalSplitRightDividerColor = '',
    this.verticalSplitRightDividerWidth = 54.0,
    this.verticalSplitRightDividerHeight = 4.5,
    this.verticalSplitShowHeadlineDivider = true,
    this.verticalSplitHeadlineDividerColor = '',
    this.verticalSplitHeadlineDividerWidth = 44.0,
    this.verticalSplitHeadlineDividerHeight = 3.5,
    this.coverNodesLabelFontSize = 7.5,
    this.verticalSplitFooterBadges = const [
      CoverFooterBadge(iconKey: 'light', label: 'ILUMINAÇÃO CÊNICA'),
      CoverFooterBadge(iconKey: 'music', label: 'ÁUDIO HIGH-END'),
      CoverFooterBadge(iconKey: 'temp', label: 'CLIMATIZAÇÃO IA'),
      CoverFooterBadge(iconKey: 'lock', label: 'ACESSO BIOMÉTRICO'),
    ],
    this.coverHeadlineFont = 'Montserrat',
    this.coverRightBlockFont = 'Montserrat',
    this.coverFooterFont = 'Montserrat',
    this.coverHeadlineColor = '#FFFFFF',
    this.coverRightTitleColor = '#0F172A',
    this.coverRightSubtitleColor = '#38BDF8',
    this.coverRightTaglineColor = '#64748B',
    this.coverFooterColor = '#64748B',
    this.coverBadgesTextColor = '#38BDF8',
    this.coverBadgesIconColor = '',
    this.customTextItems = const [],
    this.customIconBadges = const [
      CoverFooterBadge(iconKey: 'light', label: 'ILUMINAÇÃO CÊNICA'),
      CoverFooterBadge(iconKey: 'music', label: 'ÁUDIO MULTIROOM'),
      CoverFooterBadge(iconKey: 'temp', label: 'CLIMATIZAÇÃO IA'),
    ],
    this.customIconItems = const [],
    this.nodes = const [
      AutomationCyberNode(id: 'node_light', label: 'Iluminação Cênica', iconName: 'light', posX: 0.54, posY: 0.31, targetX: 0.50, targetY: 0.35, colorHex: '#38BDF8'),
      AutomationCyberNode(id: 'node_music', label: 'Áudio Multiroom', iconName: 'music', posX: 0.40, posY: 0.52, targetX: 0.38, targetY: 0.58, colorHex: '#38BDF8'),
      AutomationCyberNode(id: 'node_temp', label: 'Climatização HVAC', iconName: 'temp', posX: 0.93, posY: 0.29, targetX: 0.88, targetY: 0.32, colorHex: '#38BDF8'),
      AutomationCyberNode(id: 'node_camera', label: 'Monitoramento AI', iconName: 'camera', posX: 0.94, posY: 0.46, targetX: 0.90, targetY: 0.48, colorHex: '#38BDF8'),
      AutomationCyberNode(id: 'node_lock', label: 'Controle de Acesso', iconName: 'lock', posX: 0.78, posY: 0.58, targetX: 0.76, targetY: 0.62, colorHex: '#38BDF8'),
    ],
    this.headerPosX = 0.06,
    this.headerPosY = 0.05,
    this.headlinePosX = 0.06,
    this.headlinePosY = 0.12,
    this.pdfTermsText = '50% na aprovação do projeto e 50% na conclusão da programação final. Garantia de 12 meses para serviços de infraestrutura e programação.',
    this.coverClientInfoPositionX = 0.58,
    this.coverClientInfoPositionY = 0.88,
    this.coverClientInfoWidth = 240.0,
    this.coverClientInfoFontSize = 8.5,
    this.coverClientInfoColor = '#0F172A',
    this.coverClientInfoSecondaryColor = '#38BDF8',
    this.coverShowClientInfo = true,
    this.coverHeaderStyle = 9,
    this.coverShowHeader = true,
    this.coverHeaderText1 = 'PROPOSTA EXECUTIVA',
    this.coverHeaderText2 = 'AUTOMAÇÃO RESIDENCIAL HIGH-END',
    this.coverHeaderText3 = 'CONFORTO, SEGURANÇA E TECNOLOGIA INTEGRADA',
    this.coverHeaderBgColor = '#0F172A',
    this.coverHeaderTextColor = '#FFFFFF',
    this.coverHeaderIconColor = '#38BDF8',
    this.coverFooterStyle = 1,
    this.coverShowFooter = true,
    this.coverFooterText1 = 'A CASA QUE ENTENDE VOCÊ • EXPERIÊNCIA ÚNICA',
    this.coverFooterText2 = '(11) 00000-0000 • contato@suaempresa.com.br',
    this.coverFooterText3 = 'www.suaempresa.com.br',
    this.coverFooterText4 = 'Proposta técnica e comercial válida por 15 dias corridos.',
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
    this.page3Title = 'PORTFÓLIO & CLIENTES',
    this.page3Subtitle = 'Cases de Sucesso e Obras Concluídas',
    this.page3PortfolioJson,
    this.page3BgColor = '#0B132B',
    this.page3CardBgColor = '#111C38',
    this.page3BorderColor = '#00E5FF',
    this.page3TitleColor = '#FFFFFF',
    this.page3SubtitleColor = '#94A3B8',
    this.page3AccentColor = '#00E5FF',
    this.page4BgColor = '#0B132B',
    this.page4CardBgColor = '#111C38',
    this.page4BorderColor = '#00E5FF',
    this.page4TitleColor = '#FFFFFF',
    this.page4SubtitleColor = '#94A3B8',
    this.page4AccentColor = '#00E5FF',
  });

  AutomationSettingsModel copyWith({
    String? page2TemplateId,
    String? page2CardsJson,
    bool? page2ShowIllustration,
    String? page2IllustrationType,
    String? hiddenPagesJson,
    String? customPagesJson,
    String? internalPagesLayoutPreset,
    String? page3Title,
    String? page3Subtitle,
    String? page3PortfolioJson,
    String? page3BgColor,
    String? page3CardBgColor,
    String? page3BorderColor,
    String? page3TitleColor,
    String? page3SubtitleColor,
    String? page3AccentColor,
    String? page4BgColor,
    String? page4CardBgColor,
    String? page4BorderColor,
    String? page4TitleColor,
    String? page4SubtitleColor,
    String? page4AccentColor,
    String? companyId,
    String? companyName,
    String? companyDoc,
    String? companyPhone,
    String? companyEmail,
    String? companyWebsite,
    String? companyInstagram,
    String? companySlogan,
    String? companyLogoBase64,
    String? cep,
    String? logradouro,
    String? numero,
    String? complemento,
    String? bairro,
    String? cidade,
    String? uf,
    String? activeCategory,
    String? activePresetId,
    bool? isCustomCoverMode,
    bool? isFullPhoto,
    String? proposalStyle,
    String? selectedCoverTemplate,
    String? webBackgroundTemplate,
    String? coverTitle,
    String? coverSubtitle,
    String? coverTag,
    String? coverHeadline,
    String? coverSubheadline,
    String? coverTitleColor,
    String? coverSubtitleColor,
    double? coverTitleFontSize,
    double? coverSubtitleFontSize,
    String? coverFontFamily,
    String? coverBadgeColor,
    double? coverBadgeOpacity,
    bool? coverShowBadge,
    double? coverBadgePositionX,
    double? coverBadgePositionY,
    String? clientTitle,
    String? clientName,
    String? proposalCode,
    String? coverImageUrl,
    String? customCoverImageBase64,
    int? customDividerStyle,
    String? customDividerColor,
    String? customDividerBottomColor,
    String? customDividerDarkColor,
    String? primaryColorHex,
    bool? showCoverTag,
    bool? showCoverHeadline,
    bool? showCoverSubheadline,
    bool? showClientCard,
    bool? showProposalCode,
    bool? showLogo,
    double? logoPosX,
    double? logoPosY,
    double? logoWidth,
    bool? coverShowLogo,
    double? coverLogoPositionX,
    double? coverLogoPositionY,
    double? coverLogoWidth,
    String? cardBgColorHex,
    double? cardOpacity,
    double? clientCardPosX,
    double? clientCardPosY,
    int? verticalSplitDividerType,
    String? verticalSplitHeadline,
    String? verticalSplitSubheadline,
    String? verticalSplitRightTitle,
    String? verticalSplitRightSubtitle,
    String? verticalSplitRightTagline,
    String? verticalSplitLeftFooter,
    String? verticalSplitRightFooter,
    String? verticalSplitAccentColor,
    double? verticalSplitHeadlineTop,
    double? verticalSplitHeadlineLeft,
    double? verticalSplitRightBlockTop,
    double? verticalSplitRightBlockRight,
    double? verticalSplitLeftFooterBottom,
    double? verticalSplitLeftFooterLeft,
    double? verticalSplitLeftFooterWidth,
    double? verticalSplitRightFooterBottom,
    double? verticalSplitRightFooterRight,
    bool? verticalSplitShowHeadline,
    bool? verticalSplitShowRightBlock,
    bool? verticalSplitShowLeftFooter,
    bool? verticalSplitShowRightFooter,
    String? verticalSplitBadgesLayout,
    bool? verticalSplitShowRightDivider,
    String? verticalSplitRightDividerColor,
    double? verticalSplitRightDividerWidth,
    double? verticalSplitRightDividerHeight,
    bool? verticalSplitShowHeadlineDivider,
    String? verticalSplitHeadlineDividerColor,
    double? verticalSplitHeadlineDividerWidth,
    double? verticalSplitHeadlineDividerHeight,
    double? coverNodesLabelFontSize,
    List<CoverFooterBadge>? verticalSplitFooterBadges,
    String? coverHeadlineFont,
    String? coverRightBlockFont,
    String? coverFooterFont,
    String? coverHeadlineColor,
    String? coverRightTitleColor,
    String? coverRightSubtitleColor,
    String? coverRightTaglineColor,
    String? coverFooterColor,
    String? coverBadgesTextColor,
    String? coverBadgesIconColor,
    List<CustomCoverTextItem>? customTextItems,
    List<CoverFooterBadge>? customIconBadges,
    List<CustomCoverIconItem>? customIconItems,
    List<AutomationCyberNode>? nodes,
    double? headerPosX,
    double? headerPosY,
    double? headlinePosX,
    double? headlinePosY,
    String? pdfTermsText,
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
  }) {
    final effectiveCoverTemplate = selectedCoverTemplate ?? this.selectedCoverTemplate;
    final effectiveCoverUrl = coverImageUrl ?? selectedCoverTemplate ?? this.coverImageUrl;

    return AutomationSettingsModel(
      companyId: companyId ?? this.companyId,
      companyName: companyName ?? this.companyName,
      companyDoc: companyDoc ?? this.companyDoc,
      companyPhone: companyPhone ?? this.companyPhone,
      companyEmail: companyEmail ?? this.companyEmail,
      companyWebsite: companyWebsite ?? this.companyWebsite,
      companyInstagram: companyInstagram ?? this.companyInstagram,
      companySlogan: companySlogan ?? this.companySlogan,
      companyLogoBase64: companyLogoBase64 ?? this.companyLogoBase64,
      cep: cep ?? this.cep,
      logradouro: logradouro ?? this.logradouro,
      numero: numero ?? this.numero,
      complemento: complemento ?? this.complemento,
      bairro: bairro ?? this.bairro,
      cidade: cidade ?? this.cidade,
      uf: uf ?? this.uf,
      activeCategory: activeCategory ?? this.activeCategory,
      activePresetId: activePresetId ?? this.activePresetId,
      isCustomCoverMode: isCustomCoverMode ?? this.isCustomCoverMode,
      isFullPhoto: isFullPhoto ?? this.isFullPhoto,
      proposalStyle: proposalStyle ?? this.proposalStyle,
      selectedCoverTemplate: effectiveCoverTemplate,
      webBackgroundTemplate: webBackgroundTemplate ?? this.webBackgroundTemplate,
      coverTitle: coverTitle ?? this.coverTitle,
      coverSubtitle: coverSubtitle ?? this.coverSubtitle,
      coverTag: coverTag ?? this.coverTag,
      coverHeadline: coverHeadline ?? this.coverHeadline,
      coverSubheadline: coverSubheadline ?? this.coverSubheadline,
      coverTitleColor: coverTitleColor ?? this.coverTitleColor,
      coverSubtitleColor: coverSubtitleColor ?? this.coverSubtitleColor,
      coverTitleFontSize: coverTitleFontSize ?? this.coverTitleFontSize,
      coverSubtitleFontSize: coverSubtitleFontSize ?? this.coverSubtitleFontSize,
      coverFontFamily: coverFontFamily ?? this.coverFontFamily,
      coverBadgeColor: coverBadgeColor ?? this.coverBadgeColor,
      coverBadgeOpacity: coverBadgeOpacity ?? this.coverBadgeOpacity,
      coverShowBadge: coverShowBadge ?? this.coverShowBadge,
      coverBadgePositionX: coverBadgePositionX ?? this.coverBadgePositionX,
      coverBadgePositionY: coverBadgePositionY ?? this.coverBadgePositionY,
      clientTitle: clientTitle ?? this.clientTitle,
      clientName: clientName ?? this.clientName,
      proposalCode: proposalCode ?? this.proposalCode,
      coverImageUrl: effectiveCoverUrl,
      customCoverImageBase64: customCoverImageBase64 ?? this.customCoverImageBase64,
      customDividerStyle: customDividerStyle ?? this.customDividerStyle,
      customDividerColor: customDividerColor ?? this.customDividerColor,
      customDividerBottomColor: customDividerBottomColor ?? this.customDividerBottomColor,
      customDividerDarkColor: customDividerDarkColor ?? this.customDividerDarkColor,
      primaryColorHex: primaryColorHex ?? this.primaryColorHex,
      showCoverTag: showCoverTag ?? this.showCoverTag,
      showCoverHeadline: showCoverHeadline ?? this.showCoverHeadline,
      showCoverSubheadline: showCoverSubheadline ?? this.showCoverSubheadline,
      showClientCard: showClientCard ?? this.showClientCard,
      showProposalCode: showProposalCode ?? this.showProposalCode,
      showLogo: coverShowLogo ?? showLogo ?? this.showLogo,
      logoPosX: coverLogoPositionX ?? logoPosX ?? this.logoPosX,
      logoPosY: coverLogoPositionY ?? logoPosY ?? this.logoPosY,
      logoWidth: coverLogoWidth ?? logoWidth ?? this.logoWidth,
      cardBgColorHex: cardBgColorHex ?? this.cardBgColorHex,
      cardOpacity: cardOpacity ?? this.cardOpacity,
      clientCardPosX: clientCardPosX ?? this.clientCardPosX,
      clientCardPosY: clientCardPosY ?? this.clientCardPosY,
      verticalSplitDividerType: verticalSplitDividerType ?? this.verticalSplitDividerType,
      verticalSplitHeadline: verticalSplitHeadline ?? this.verticalSplitHeadline,
      verticalSplitSubheadline: verticalSplitSubheadline ?? this.verticalSplitSubheadline,
      verticalSplitRightTitle: verticalSplitRightTitle ?? this.verticalSplitRightTitle,
      verticalSplitRightSubtitle: verticalSplitRightSubtitle ?? this.verticalSplitRightSubtitle,
      verticalSplitRightTagline: verticalSplitRightTagline ?? this.verticalSplitRightTagline,
      verticalSplitLeftFooter: verticalSplitLeftFooter ?? this.verticalSplitLeftFooter,
      verticalSplitRightFooter: verticalSplitRightFooter ?? this.verticalSplitRightFooter,
      verticalSplitAccentColor: verticalSplitAccentColor ?? this.verticalSplitAccentColor,
      verticalSplitHeadlineTop: verticalSplitHeadlineTop ?? this.verticalSplitHeadlineTop,
      verticalSplitHeadlineLeft: verticalSplitHeadlineLeft ?? this.verticalSplitHeadlineLeft,
      verticalSplitRightBlockTop: verticalSplitRightBlockTop ?? this.verticalSplitRightBlockTop,
      verticalSplitRightBlockRight: verticalSplitRightBlockRight ?? this.verticalSplitRightBlockRight,
      verticalSplitLeftFooterBottom: verticalSplitLeftFooterBottom ?? this.verticalSplitLeftFooterBottom,
      verticalSplitLeftFooterLeft: verticalSplitLeftFooterLeft ?? this.verticalSplitLeftFooterLeft,
      verticalSplitLeftFooterWidth: verticalSplitLeftFooterWidth ?? this.verticalSplitLeftFooterWidth,
      verticalSplitRightFooterBottom: verticalSplitRightFooterBottom ?? this.verticalSplitRightFooterBottom,
      verticalSplitRightFooterRight: verticalSplitRightFooterRight ?? this.verticalSplitRightFooterRight,
      verticalSplitShowHeadline: verticalSplitShowHeadline ?? this.verticalSplitShowHeadline,
      verticalSplitShowRightBlock: verticalSplitShowRightBlock ?? this.verticalSplitShowRightBlock,
      verticalSplitShowLeftFooter: verticalSplitShowLeftFooter ?? this.verticalSplitShowLeftFooter,
      verticalSplitShowRightFooter: verticalSplitShowRightFooter ?? this.verticalSplitShowRightFooter,
      verticalSplitBadgesLayout: verticalSplitBadgesLayout ?? this.verticalSplitBadgesLayout,
      verticalSplitShowRightDivider: verticalSplitShowRightDivider ?? this.verticalSplitShowRightDivider,
      verticalSplitRightDividerColor: verticalSplitRightDividerColor ?? this.verticalSplitRightDividerColor,
      verticalSplitRightDividerWidth: verticalSplitRightDividerWidth ?? this.verticalSplitRightDividerWidth,
      verticalSplitRightDividerHeight: verticalSplitRightDividerHeight ?? this.verticalSplitRightDividerHeight,
      verticalSplitShowHeadlineDivider: verticalSplitShowHeadlineDivider ?? this.verticalSplitShowHeadlineDivider,
      verticalSplitHeadlineDividerColor: verticalSplitHeadlineDividerColor ?? this.verticalSplitHeadlineDividerColor,
      verticalSplitHeadlineDividerWidth: verticalSplitHeadlineDividerWidth ?? this.verticalSplitHeadlineDividerWidth,
      verticalSplitHeadlineDividerHeight: verticalSplitHeadlineDividerHeight ?? this.verticalSplitHeadlineDividerHeight,
      coverNodesLabelFontSize: coverNodesLabelFontSize ?? this.coverNodesLabelFontSize,
      verticalSplitFooterBadges: verticalSplitFooterBadges ?? this.verticalSplitFooterBadges,
      coverHeadlineFont: coverHeadlineFont ?? this.coverHeadlineFont,
      coverRightBlockFont: coverRightBlockFont ?? this.coverRightBlockFont,
      coverFooterFont: coverFooterFont ?? this.coverFooterFont,
      coverHeadlineColor: coverHeadlineColor ?? this.coverHeadlineColor,
      coverRightTitleColor: coverRightTitleColor ?? this.coverRightTitleColor,
      coverRightSubtitleColor: coverRightSubtitleColor ?? this.coverRightSubtitleColor,
      coverRightTaglineColor: coverRightTaglineColor ?? this.coverRightTaglineColor,
      coverFooterColor: coverFooterColor ?? this.coverFooterColor,
      coverBadgesTextColor: coverBadgesTextColor ?? this.coverBadgesTextColor,
      coverBadgesIconColor: coverBadgesIconColor ?? this.coverBadgesIconColor,
      customTextItems: customTextItems ?? this.customTextItems,
      customIconBadges: customIconBadges ?? this.customIconBadges,
      customIconItems: customIconItems ?? this.customIconItems,
      nodes: nodes ?? this.nodes,
      headerPosX: headerPosX ?? this.headerPosX,
      headerPosY: headerPosY ?? this.headerPosY,
      headlinePosX: headlinePosX ?? this.headlinePosX,
      headlinePosY: headlinePosY ?? this.headlinePosY,
      pdfTermsText: pdfTermsText ?? this.pdfTermsText,
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
      page3Title: page3Title ?? this.page3Title,
      page3Subtitle: page3Subtitle ?? this.page3Subtitle,
      page3PortfolioJson: page3PortfolioJson ?? this.page3PortfolioJson,
      page3BgColor: page3BgColor ?? this.page3BgColor,
      page3CardBgColor: page3CardBgColor ?? this.page3CardBgColor,
      page3BorderColor: page3BorderColor ?? this.page3BorderColor,
      page3TitleColor: page3TitleColor ?? this.page3TitleColor,
      page3SubtitleColor: page3SubtitleColor ?? this.page3SubtitleColor,
      page3AccentColor: page3AccentColor ?? this.page3AccentColor,
      page4BgColor: page4BgColor ?? this.page4BgColor,
      page4CardBgColor: page4CardBgColor ?? this.page4CardBgColor,
      page4BorderColor: page4BorderColor ?? this.page4BorderColor,
      page4TitleColor: page4TitleColor ?? this.page4TitleColor,
      page4SubtitleColor: page4SubtitleColor ?? this.page4SubtitleColor,
      page4AccentColor: page4AccentColor ?? this.page4AccentColor,
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
      'companyId': companyId,
      'companyName': companyName,
      'companyDoc': companyDoc,
      'companyPhone': companyPhone,
      'companyEmail': companyEmail,
      'companyWebsite': companyWebsite,
      'companyInstagram': companyInstagram,
      'companySlogan': companySlogan,
      'companyLogoBase64': companyLogoBase64,
      'cep': cep,
      'logradouro': logradouro,
      'numero': numero,
      'complemento': complemento,
      'bairro': bairro,
      'cidade': cidade,
      'uf': uf,
      'activeCategory': activeCategory,
      'activePresetId': activePresetId,
      'isCustomCoverMode': isCustomCoverMode,
      'isFullPhoto': isFullPhoto,
      'proposalStyle': proposalStyle,
      'selectedCoverTemplate': selectedCoverTemplate,
      'webBackgroundTemplate': webBackgroundTemplate,
      'coverTitle': coverTitle,
      'coverSubtitle': coverSubtitle,
      'coverTag': coverTag,
      'coverHeadline': coverHeadline,
      'coverSubheadline': coverSubheadline,
      'coverTitleColor': coverTitleColor,
      'coverSubtitleColor': coverSubtitleColor,
      'coverTitleFontSize': coverTitleFontSize,
      'coverSubtitleFontSize': coverSubtitleFontSize,
      'coverFontFamily': coverFontFamily,
      'coverBadgeColor': coverBadgeColor,
      'coverBadgeOpacity': coverBadgeOpacity,
      'coverShowBadge': coverShowBadge,
      'coverBadgePositionX': coverBadgePositionX,
      'coverBadgePositionY': coverBadgePositionY,
      'clientTitle': clientTitle,
      'clientName': clientName,
      'proposalCode': proposalCode,
      'coverImageUrl': coverImageUrl,
      'customCoverImageBase64': customCoverImageBase64,
      'customDividerStyle': customDividerStyle,
      'customDividerColor': customDividerColor,
      'customDividerBottomColor': customDividerBottomColor,
      'customDividerDarkColor': customDividerDarkColor,
      'primaryColorHex': primaryColorHex,
      'showCoverTag': showCoverTag,
      'showCoverHeadline': showCoverHeadline,
      'showCoverSubheadline': showCoverSubheadline,
      'showClientCard': showClientCard,
      'showProposalCode': showProposalCode,
      'showLogo': showLogo,
      'logoPosX': logoPosX,
      'logoPosY': logoPosY,
      'logoWidth': logoWidth,
      'cardBgColorHex': cardBgColorHex,
      'cardOpacity': cardOpacity,
      'clientCardPosX': clientCardPosX,
      'clientCardPosY': clientCardPosY,
      'verticalSplitDividerType': verticalSplitDividerType,
      'verticalSplitHeadline': verticalSplitHeadline,
      'verticalSplitSubheadline': verticalSplitSubheadline,
      'verticalSplitRightTitle': verticalSplitRightTitle,
      'verticalSplitRightSubtitle': verticalSplitRightSubtitle,
      'verticalSplitRightTagline': verticalSplitRightTagline,
      'verticalSplitLeftFooter': verticalSplitLeftFooter,
      'verticalSplitRightFooter': verticalSplitRightFooter,
      'verticalSplitAccentColor': verticalSplitAccentColor,
      'verticalSplitHeadlineTop': verticalSplitHeadlineTop,
      'verticalSplitHeadlineLeft': verticalSplitHeadlineLeft,
      'verticalSplitRightBlockTop': verticalSplitRightBlockTop,
      'verticalSplitRightBlockRight': verticalSplitRightBlockRight,
      'verticalSplitLeftFooterBottom': verticalSplitLeftFooterBottom,
      'verticalSplitLeftFooterLeft': verticalSplitLeftFooterLeft,
      'verticalSplitLeftFooterWidth': verticalSplitLeftFooterWidth,
      'verticalSplitRightFooterBottom': verticalSplitRightFooterBottom,
      'verticalSplitRightFooterRight': verticalSplitRightFooterRight,
      'verticalSplitShowHeadline': verticalSplitShowHeadline,
      'verticalSplitShowRightBlock': verticalSplitShowRightBlock,
      'verticalSplitShowLeftFooter': verticalSplitShowLeftFooter,
      'verticalSplitShowRightFooter': verticalSplitShowRightFooter,
      'verticalSplitBadgesLayout': verticalSplitBadgesLayout,
      'verticalSplitShowRightDivider': verticalSplitShowRightDivider,
      'verticalSplitRightDividerColor': verticalSplitRightDividerColor,
      'verticalSplitRightDividerWidth': verticalSplitRightDividerWidth,
      'verticalSplitRightDividerHeight': verticalSplitRightDividerHeight,
      'verticalSplitShowHeadlineDivider': verticalSplitShowHeadlineDivider,
      'verticalSplitHeadlineDividerColor': verticalSplitHeadlineDividerColor,
      'verticalSplitHeadlineDividerWidth': verticalSplitHeadlineDividerWidth,
      'verticalSplitHeadlineDividerHeight': verticalSplitHeadlineDividerHeight,
      'coverNodesLabelFontSize': coverNodesLabelFontSize,
      'verticalSplitFooterBadges': verticalSplitFooterBadges.map((x) => x.toMap()).toList(),
      'coverHeadlineFont': coverHeadlineFont,
      'coverRightBlockFont': coverRightBlockFont,
      'coverFooterFont': coverFooterFont,
      'coverHeadlineColor': coverHeadlineColor,
      'coverRightTitleColor': coverRightTitleColor,
      'coverRightSubtitleColor': coverRightSubtitleColor,
      'coverRightTaglineColor': coverRightTaglineColor,
      'coverFooterColor': coverFooterColor,
      'coverBadgesTextColor': coverBadgesTextColor,
      'coverBadgesIconColor': coverBadgesIconColor,
      'customTextItems': customTextItems.map((x) => x.toMap()).toList(),
      'customIconBadges': customIconBadges.map((x) => x.toMap()).toList(),
      'customIconItems': customIconItems.map((x) => x.toMap()).toList(),
      'nodes': nodes.map((x) => x.toMap()).toList(),
      'headerPosX': headerPosX,
      'headerPosY': headerPosY,
      'headlinePosX': headlinePosX,
      'headlinePosY': headlinePosY,
      'pdfTermsText': pdfTermsText,
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
      'page3Title': page3Title,
      'page3Subtitle': page3Subtitle,
      'page3PortfolioJson': page3PortfolioJson,
      'page3BgColor': page3BgColor,
      'page3CardBgColor': page3CardBgColor,
      'page3BorderColor': page3BorderColor,
      'page3TitleColor': page3TitleColor,
      'page3SubtitleColor': page3SubtitleColor,
      'page3AccentColor': page3AccentColor,
      'page4BgColor': page4BgColor,
      'page4CardBgColor': page4CardBgColor,
      'page4BorderColor': page4BorderColor,
      'page4TitleColor': page4TitleColor,
      'page4SubtitleColor': page4SubtitleColor,
      'page4AccentColor': page4AccentColor,
    };
  }

  factory AutomationSettingsModel.fromMap(Map<String, dynamic> map) {
    final coverImg = map['coverImageUrl'] as String? ?? 'modelo_automacao_1.jpg';
    final selCover = map['selectedCoverTemplate'] as String? ?? (coverImg.isNotEmpty ? coverImg : 'modelo_automacao_1.jpg');

    return AutomationSettingsModel(
      companyId: map['companyId'] as String? ?? '',
      companyName: map['companyName'] as String? ?? 'ARBO AUTOMAÇÃO',
      companyDoc: map['companyDoc'] as String? ?? '',
      companyPhone: map['companyPhone'] as String? ?? '',
      companyEmail: map['companyEmail'] as String? ?? '',
      companyWebsite: map['companyWebsite'] as String? ?? '',
      companyInstagram: map['companyInstagram'] as String? ?? '',
      companySlogan: map['companySlogan'] as String? ?? '',
      companyLogoBase64: map['companyLogoBase64'] as String?,
      cep: map['cep'] as String? ?? '',
      logradouro: map['logradouro'] as String? ?? '',
      numero: map['numero'] as String? ?? '',
      complemento: map['complemento'] as String? ?? '',
      bairro: map['bairro'] as String? ?? '',
      cidade: map['cidade'] as String? ?? '',
      uf: map['uf'] as String? ?? '',
      activeCategory: map['activeCategory'] as String? ?? 'Cyber Mansion',
      activePresetId: map['activePresetId'] as String? ?? 'auto_cover_01',
      isCustomCoverMode: map['isCustomCoverMode'] as bool? ?? false,
      isFullPhoto: map['isFullPhoto'] as bool? ?? true,
      proposalStyle: map['proposalStyle'] as String? ?? 'modern',
      selectedCoverTemplate: selCover,
      webBackgroundTemplate: map['webBackgroundTemplate'] as String? ?? 'AdobeStock_1030854734.jpg',
      coverTitle: map['coverTitle'] as String? ?? 'PROPOSTA COMERCIAL',
      coverSubtitle: map['coverSubtitle'] as String? ?? 'AUTOMAÇÃO RESIDENCIAL HIGH-END',
      coverTag: map['coverTag'] as String? ?? 'PROPOSTA / 2026',
      coverHeadline: map['coverHeadline'] as String? ?? 'A casa que entende você.',
      coverSubheadline: map['coverSubheadline'] as String? ?? 'Arquitetura, conforto e tecnologia integrados em uma experiência única.',
      coverTitleColor: map['coverTitleColor'] as String? ?? '#38BDF8',
      coverSubtitleColor: map['coverSubtitleColor'] as String? ?? '#FFFFFF',
      coverTitleFontSize: (map['coverTitleFontSize'] as num?)?.toDouble() ?? 26.0,
      coverSubtitleFontSize: (map['coverSubtitleFontSize'] as num?)?.toDouble() ?? 11.0,
      coverFontFamily: map['coverFontFamily'] as String? ?? 'Montserrat',
      coverBadgeColor: map['coverBadgeColor'] as String? ?? '#0F172A',
      coverBadgeOpacity: (map['coverBadgeOpacity'] as num?)?.toDouble() ?? 0.85,
      coverShowBadge: map['coverShowBadge'] as bool? ?? true,
      coverBadgePositionX: (map['coverBadgePositionX'] as num?)?.toDouble() ?? 0.08,
      coverBadgePositionY: (map['coverBadgePositionY'] as num?)?.toDouble() ?? 0.06,
      clientTitle: map['clientTitle'] as String? ?? 'RESIDÊNCIA',
      clientName: map['clientName'] as String? ?? 'Família Klaus',
      proposalCode: map['proposalCode'] as String? ?? 'ARBO-2026-001',
      coverImageUrl: coverImg,
      customCoverImageBase64: map['customCoverImageBase64'] as String?,
      customDividerStyle: (map['customDividerStyle'] as num?)?.toInt() ?? 0,
      customDividerColor: map['customDividerColor'] as String? ?? '#38BDF8',
      customDividerBottomColor: map['customDividerBottomColor'] as String? ?? '#FFFFFF',
      customDividerDarkColor: map['customDividerDarkColor'] as String? ?? '#0F172A',
      primaryColorHex: map['primaryColorHex'] as String? ?? '#38BDF8',
      showCoverTag: map['showCoverTag'] as bool? ?? true,
      showCoverHeadline: map['showCoverHeadline'] as bool? ?? true,
      showCoverSubheadline: map['showCoverSubheadline'] as bool? ?? true,
      showClientCard: map['showClientCard'] as bool? ?? true,
      showProposalCode: map['showProposalCode'] as bool? ?? true,
      showLogo: map['showLogo'] as bool? ?? (map['coverShowLogo'] as bool? ?? true),
      logoPosX: (map['logoPosX'] as num?)?.toDouble() ?? ((map['coverLogoPositionX'] as num?)?.toDouble() ?? 0.78),
      logoPosY: (map['logoPosY'] as num?)?.toDouble() ?? ((map['coverLogoPositionY'] as num?)?.toDouble() ?? 0.06),
      logoWidth: (map['logoWidth'] as num?)?.toDouble() ?? ((map['coverLogoWidth'] as num?)?.toDouble() ?? 90.0),
      cardBgColorHex: map['cardBgColorHex'] as String? ?? '#0F172A',
      cardOpacity: (map['cardOpacity'] as num?)?.toDouble() ?? 0.85,
      clientCardPosX: (map['clientCardPosX'] as num?)?.toDouble() ?? 0.06,
      clientCardPosY: (map['clientCardPosY'] as num?)?.toDouble() ?? 0.88,
      verticalSplitDividerType: (map['verticalSplitDividerType'] as num?)?.toInt() ?? 0,
      verticalSplitHeadline: map['verticalSplitHeadline'] as String? ?? 'A CASA QUE\nENTENDE\nVOCÊ',
      verticalSplitSubheadline: map['verticalSplitSubheadline'] as String? ?? 'ARQUITETURA, CONFORTO\nE TECNOLOGIA\nEM UMA EXPERIÊNCIA ÚNICA.',
      verticalSplitRightTitle: map['verticalSplitRightTitle'] as String? ?? 'PROPOSTA',
      verticalSplitRightSubtitle: map['verticalSplitRightSubtitle'] as String? ?? 'AUTOMAÇÃO',
      verticalSplitRightTagline: map['verticalSplitRightTagline'] as String? ?? 'PROJETO DE AUTOMAÇÃO\nRESIDENCIAL HIGH-END',
      verticalSplitLeftFooter: map['verticalSplitLeftFooter'] as String? ?? 'CONFORTO HOJE.\nMAIS INTELIGÊNCIA\nAMANHÃ.',
      verticalSplitRightFooter: map['verticalSplitRightFooter'] as String? ?? 'SOLUÇÕES EXCLUSIVAS EM\nAUTOMAÇÃO RESIDENCIAL',
      verticalSplitAccentColor: map['verticalSplitAccentColor'] as String? ?? '#38BDF8',
      verticalSplitHeadlineTop: (map['verticalSplitHeadlineTop'] as num?)?.toDouble() ?? 0.50,
      verticalSplitHeadlineLeft: (map['verticalSplitHeadlineLeft'] as num?)?.toDouble() ?? 0.06,
      verticalSplitRightBlockTop: (map['verticalSplitRightBlockTop'] as num?)?.toDouble() ?? 0.04,
      verticalSplitRightBlockRight: (map['verticalSplitRightBlockRight'] as num?)?.toDouble() ?? 0.48,
      verticalSplitLeftFooterBottom: (map['verticalSplitLeftFooterBottom'] as num?)?.toDouble() ?? 0.26,
      verticalSplitLeftFooterLeft: (map['verticalSplitLeftFooterLeft'] as num?)?.toDouble() ?? 0.06,
      verticalSplitLeftFooterWidth: (map['verticalSplitLeftFooterWidth'] as num?)?.toDouble() ?? 0.44,
      verticalSplitRightFooterBottom: (map['verticalSplitRightFooterBottom'] as num?)?.toDouble() ?? 0.06,
      verticalSplitRightFooterRight: (map['verticalSplitRightFooterRight'] as num?)?.toDouble() ?? 0.06,
      verticalSplitShowHeadline: map['verticalSplitShowHeadline'] as bool? ?? true,
      verticalSplitShowRightBlock: map['verticalSplitShowRightBlock'] as bool? ?? true,
      verticalSplitShowLeftFooter: map['verticalSplitShowLeftFooter'] as bool? ?? true,
      coverClientInfoPositionX: (map['coverClientInfoPositionX'] as num?)?.toDouble() ?? 0.58,
      coverClientInfoPositionY: (map['coverClientInfoPositionY'] as num?)?.toDouble() ?? 0.88,
      coverClientInfoWidth: (map['coverClientInfoWidth'] as num?)?.toDouble() ?? 240.0,
      coverClientInfoFontSize: (map['coverClientInfoFontSize'] as num?)?.toDouble() ?? 8.5,
      coverClientInfoColor: map['coverClientInfoColor'] as String? ?? '#0F172A',
      coverClientInfoSecondaryColor: map['coverClientInfoSecondaryColor'] as String? ?? '#38BDF8',
      coverShowClientInfo: map['coverShowClientInfo'] as bool? ?? true,
      verticalSplitShowRightFooter: map['verticalSplitShowRightFooter'] as bool? ?? true,
      verticalSplitBadgesLayout: map['verticalSplitBadgesLayout'] as String? ?? 'horizontal',
      verticalSplitShowRightDivider: map['verticalSplitShowRightDivider'] as bool? ?? true,
      verticalSplitRightDividerColor: map['verticalSplitRightDividerColor'] as String? ?? '',
      verticalSplitRightDividerWidth: (map['verticalSplitRightDividerWidth'] as num?)?.toDouble() ?? 54.0,
      verticalSplitRightDividerHeight: (map['verticalSplitRightDividerHeight'] as num?)?.toDouble() ?? 4.5,
      verticalSplitShowHeadlineDivider: map['verticalSplitShowHeadlineDivider'] as bool? ?? true,
      verticalSplitHeadlineDividerColor: map['verticalSplitHeadlineDividerColor'] as String? ?? '',
      verticalSplitHeadlineDividerWidth: (map['verticalSplitHeadlineDividerWidth'] as num?)?.toDouble() ?? 44.0,
      verticalSplitHeadlineDividerHeight: (map['verticalSplitHeadlineDividerHeight'] as num?)?.toDouble() ?? 3.5,
      coverNodesLabelFontSize: (map['coverNodesLabelFontSize'] as num?)?.toDouble() ?? 7.5,
      verticalSplitFooterBadges: map['verticalSplitFooterBadges'] != null
          ? List<CoverFooterBadge>.from(
              (map['verticalSplitFooterBadges'] as List).map((x) {
                if (x is String) {
                  return CoverFooterBadge(iconKey: x, label: x.toUpperCase());
                }
                return CoverFooterBadge.fromMap(x as Map<String, dynamic>);
              }))
          : const [
              CoverFooterBadge(iconKey: 'light', label: 'ILUMINAÇÃO CÊNICA'),
              CoverFooterBadge(iconKey: 'music', label: 'ÁUDIO HIGH-END'),
              CoverFooterBadge(iconKey: 'temp', label: 'CLIMATIZAÇÃO IA'),
              CoverFooterBadge(iconKey: 'lock', label: 'ACESSO BIOMÉTRICO'),
            ],
      coverHeadlineFont: map['coverHeadlineFont'] as String? ?? 'Montserrat',
      coverRightBlockFont: map['coverRightBlockFont'] as String? ?? 'Montserrat',
      coverFooterFont: map['coverFooterFont'] as String? ?? 'Montserrat',
      coverHeadlineColor: map['coverHeadlineColor'] as String? ?? '#FFFFFF',
      coverRightTitleColor: map['coverRightTitleColor'] as String? ?? '#0F172A',
      coverRightSubtitleColor: map['coverRightSubtitleColor'] as String? ?? '#38BDF8',
      coverRightTaglineColor: map['coverRightTaglineColor'] as String? ?? '#64748B',
      coverFooterColor: map['coverFooterColor'] as String? ?? '#64748B',
      coverBadgesTextColor: map['coverBadgesTextColor'] as String? ?? '#38BDF8',
      coverBadgesIconColor: map['coverBadgesIconColor'] as String? ?? '',
      customTextItems: map['customTextItems'] != null
          ? List<CustomCoverTextItem>.from(
              (map['customTextItems'] as List).map((x) => CustomCoverTextItem.fromMap(x)))
          : const [],
      customIconBadges: map['customIconBadges'] != null
          ? List<CoverFooterBadge>.from(
              (map['customIconBadges'] as List).map((x) => CoverFooterBadge.fromMap(x)))
          : CoverFooterBadge.defaultBadges(),
      customIconItems: map['customIconItems'] != null
          ? List<CustomCoverIconItem>.from(
              (map['customIconItems'] as List).map((x) => CustomCoverIconItem.fromMap(x)))
          : const [],
      nodes: map['nodes'] != null
          ? List<AutomationCyberNode>.from(
              (map['nodes'] as List).map((x) => AutomationCyberNode.fromMap(x)))
          : AutomationCyberNode.defaultNodes(),
      headerPosX: (map['headerPosX'] as num?)?.toDouble() ?? 0.06,
      headerPosY: (map['headerPosY'] as num?)?.toDouble() ?? 0.05,
      headlinePosX: (map['headlinePosX'] as num?)?.toDouble() ?? 0.06,
      headlinePosY: (map['headlinePosY'] as num?)?.toDouble() ?? 0.12,
      pdfTermsText: map['pdfTermsText'] as String? ?? '50% na aprovação do projeto e 50% na conclusão da programação final.',
      coverHeaderStyle: (map['coverHeaderStyle'] as num?)?.toInt() ?? 9,
      coverShowHeader: map['coverShowHeader'] as bool? ?? true,
      coverHeaderText1: map['coverHeaderText1'] as String? ?? 'PROPOSTA EXECUTIVA',
      coverHeaderText2: map['coverHeaderText2'] as String? ?? 'AUTOMAÇÃO RESIDENCIAL HIGH-END',
      coverHeaderText3: map['coverHeaderText3'] as String? ?? 'CONFORTO, SEGURANÇA E TECNOLOGIA INTEGRADA',
      coverHeaderBgColor: map['coverHeaderBgColor'] as String? ?? '#0F172A',
      coverHeaderTextColor: map['coverHeaderTextColor'] as String? ?? '#FFFFFF',
      coverHeaderIconColor: map['coverHeaderIconColor'] as String? ?? '#38BDF8',
      coverFooterStyle: (map['coverFooterStyle'] as num?)?.toInt() ?? 1,
      coverShowFooter: map['coverShowFooter'] as bool? ?? true,
      coverFooterText1: map['coverFooterText1'] as String? ?? 'A CASA QUE ENTENDE VOCÊ • EXPERIÊNCIA ÚNICA',
      coverFooterText2: map['coverFooterText2'] as String? ?? '(11) 00000-0000 • contato@suaempresa.com.br',
      coverFooterText3: map['coverFooterText3'] as String? ?? 'www.suaempresa.com.br',
      coverFooterText4: map['coverFooterText4'] as String? ?? 'Proposta técnica e comercial válida por 15 dias corridos.',
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
      page3Title: map['page3Title'] as String? ?? 'PORTFÓLIO & CLIENTES',
      page3Subtitle: map['page3Subtitle'] as String? ?? 'Cases de Sucesso e Obras Concluídas',
      page3PortfolioJson: map['page3PortfolioJson'] as String?,
      page3BgColor: map['page3BgColor'] as String? ?? '#0B132B',
      page3CardBgColor: map['page3CardBgColor'] as String? ?? '#111C38',
      page3BorderColor: map['page3BorderColor'] as String? ?? '#00E5FF',
      page3TitleColor: map['page3TitleColor'] as String? ?? '#FFFFFF',
      page3SubtitleColor: map['page3SubtitleColor'] as String? ?? '#94A3B8',
      page3AccentColor: map['page3AccentColor'] as String? ?? '#00E5FF',
      page4BgColor: map['page4BgColor'] as String? ?? '#0B132B',
      page4CardBgColor: map['page4CardBgColor'] as String? ?? '#111C38',
      page4BorderColor: map['page4BorderColor'] as String? ?? '#00E5FF',
      page4TitleColor: map['page4TitleColor'] as String? ?? '#FFFFFF',
      page4SubtitleColor: map['page4SubtitleColor'] as String? ?? '#94A3B8',
      page4AccentColor: map['page4AccentColor'] as String? ?? '#00E5FF',
    );
  }

  String toJson() => json.encode(toMap());
  factory AutomationSettingsModel.fromJson(String source) => AutomationSettingsModel.fromMap(json.decode(source));
}
