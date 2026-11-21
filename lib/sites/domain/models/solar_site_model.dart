import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SolarSiteTemplate {
  final String id;
  final String sector;
  final String name;
  final String category;
  final String description;
  final String bgImagePath;
  final int defaultPrimaryColor;
  final int defaultAccentColor;
  final bool defaultDarkTheme;

  const SolarSiteTemplate({
    required this.id,
    this.sector = 'solarPlant',
    required this.name,
    required this.category,
    required this.description,
    required this.bgImagePath,
    required this.defaultPrimaryColor,
    required this.defaultAccentColor,
    this.defaultDarkTheme = true,
  });

  static const List<SolarSiteTemplate> catalog = [
    SolarSiteTemplate(
      id: 'tpl_01',
      name: 'Solar Horizon',
      category: 'Residencial',
      description: 'Capa residencial iluminada com foco em economia familiar.',
      bgImagePath: 'assets/images/solar_page3_house.jpg',
      defaultPrimaryColor: 0xFFF59E0B,
      defaultAccentColor: 0xFF10B981,
      defaultDarkTheme: true,
    ),
    SolarSiteTemplate(
      id: 'tpl_02',
      name: 'Clean Sun Pro',
      category: 'Minimalista',
      description: 'Visual claro e limpo com destaque em azul e dourado.',
      bgImagePath: 'assets/images/onboarding/solar_card.jpg',
      defaultPrimaryColor: 0xFF0284C7,
      defaultAccentColor: 0xFFF59E0B,
      defaultDarkTheme: false,
    ),
    SolarSiteTemplate(
      id: 'tpl_03',
      name: 'Cyber Energy Dark',
      category: 'Tech & IA',
      description: 'Estilo futurista escuro com acentos em ciano e índigo.',
      bgImagePath: 'assets/images/dark_tech_bg.jpg',
      defaultPrimaryColor: 0xFF6366F1,
      defaultAccentColor: 0xFF06B6D4,
      defaultDarkTheme: true,
    ),
    SolarSiteTemplate(
      id: 'tpl_04',
      name: 'Eco Casa Inteligente',
      category: 'Residencial',
      description: 'Combina energia solar com casa conectada e sustentável.',
      bgImagePath: 'assets/images/smart_home_banner.jpg',
      defaultPrimaryColor: 0xFF10B981,
      defaultAccentColor: 0xFF38BDF8,
      defaultDarkTheme: true,
    ),
    SolarSiteTemplate(
      id: 'tpl_05',
      name: 'Executivo Gold',
      category: 'Corporativo',
      description: 'Paleta dourada sofisticada para empresas e comércios.',
      bgImagePath: 'assets/images/capa/modelo_proposta_1.jpg',
      defaultPrimaryColor: 0xFFD97706,
      defaultAccentColor: 0xFFFBBF24,
      defaultDarkTheme: true,
    ),
    SolarSiteTemplate(
      id: 'tpl_06',
      name: 'Smart Solar Hero',
      category: 'Residencial',
      description: 'Layout moderno com alto contraste para captação de leads.',
      bgImagePath: 'assets/images/smart_home_hero.jpg',
      defaultPrimaryColor: 0xFF4F46E5,
      defaultAccentColor: 0xFF10B981,
      defaultDarkTheme: true,
    ),
    SolarSiteTemplate(
      id: 'tpl_07',
      name: 'Arquitetura Solar',
      category: 'Residencial',
      description: 'Visual arquitetônico claro para imóveis de alto padrão.',
      bgImagePath: 'assets/images/smart_home_isometric.jpg',
      defaultPrimaryColor: 0xFF0F766E,
      defaultAccentColor: 0xFFF59E0B,
      defaultDarkTheme: false,
    ),
    SolarSiteTemplate(
      id: 'tpl_08',
      name: 'Engenharia Avançada',
      category: 'Industrial',
      description: 'Focado em usinas comerciais, galpões e demanda contratada.',
      bgImagePath: 'assets/images/onboarding/lateral_bg.jpg',
      defaultPrimaryColor: 0xFF2563EB,
      defaultAccentColor: 0xFF06B6D4,
      defaultDarkTheme: true,
    ),
    SolarSiteTemplate(
      id: 'tpl_09',
      name: 'Módulo Alta Potência',
      category: 'Técnico',
      description: 'Destaque na tecnologia fotovoltaica e garantia de 25 anos.',
      bgImagePath: 'assets/images/solar_panel_module.png',
      defaultPrimaryColor: 0xFF0EA5E9,
      defaultAccentColor: 0xFF10B981,
      defaultDarkTheme: true,
    ),
    SolarSiteTemplate(
      id: 'tpl_10',
      name: 'Agro & Rural Verde',
      category: 'Agro / Rural',
      description: 'Ideal para fazendas, irrigação e propriedades rurais.',
      bgImagePath: 'assets/images/solar_page3_house.jpg',
      defaultPrimaryColor: 0xFF059669,
      defaultAccentColor: 0xFFFBBF24,
      defaultDarkTheme: false,
    ),
    SolarSiteTemplate(
      id: 'tpl_11',
      name: 'Aurora Índigo',
      category: 'Moderno',
      description: 'Degradê índigo com visual clean e botões vibrantes.',
      bgImagePath: 'assets/images/onboarding/automation_card.jpg',
      defaultPrimaryColor: 0xFF6366F1,
      defaultAccentColor: 0xFFF59E0B,
      defaultDarkTheme: true,
    ),
    SolarSiteTemplate(
      id: 'tpl_12',
      name: 'Solar Prime Claro',
      category: 'Minimalista',
      description: 'Fundo branco editorial com foco total no simulador.',
      bgImagePath: 'assets/images/capa/modelo_proposta_1.jpg',
      defaultPrimaryColor: 0xFF1D4ED8,
      defaultAccentColor: 0xFF10B981,
      defaultDarkTheme: false,
    ),
    SolarSiteTemplate(
      id: 'tpl_13',
      name: 'Obsidian Tech',
      category: 'Premium Dark',
      description: 'Visual escuro elegante com detalhes em âmbar.',
      bgImagePath: 'assets/images/onboarding/dark_tech_bg.jpg',
      defaultPrimaryColor: 0xFFF59E0B,
      defaultAccentColor: 0xFF38BDF8,
      defaultDarkTheme: true,
    ),
    SolarSiteTemplate(
      id: 'tpl_14',
      name: 'Energia Direta',
      category: 'Comercial',
      description: 'Direto ao ponto para redução rápida da conta de luz.',
      bgImagePath: 'assets/images/onboarding/services_card.jpg',
      defaultPrimaryColor: 0xFFEA580C,
      defaultAccentColor: 0xFF0EA5E9,
      defaultDarkTheme: false,
    ),
    SolarSiteTemplate(
      id: 'tpl_15',
      name: 'Conforto & Economia',
      category: 'Residencial',
      description: 'Tons acolhedores voltados para famílias e condomínios.',
      bgImagePath: 'assets/images/onboarding/furniture_card.jpg',
      defaultPrimaryColor: 0xFF0D9488,
      defaultAccentColor: 0xFFF59E0B,
      defaultDarkTheme: false,
    ),
    SolarSiteTemplate(
      id: 'tpl_16',
      name: 'Matrix Solar',
      category: 'Tech & IA',
      description: 'Estética tecnológica com foco em monitoramento em nuvem.',
      bgImagePath: 'assets/images/dark_tech_bg.jpg',
      defaultPrimaryColor: 0xFF10B981,
      defaultAccentColor: 0xFF6366F1,
      defaultDarkTheme: true,
    ),
    SolarSiteTemplate(
      id: 'tpl_17',
      name: 'Indústria Limpa',
      category: 'Industrial',
      description: 'Voltado para médias e grandes empresas reduzirem custos.',
      bgImagePath: 'assets/images/smart_home_banner.jpg',
      defaultPrimaryColor: 0xFF334155,
      defaultAccentColor: 0xFFF59E0B,
      defaultDarkTheme: false,
    ),
    SolarSiteTemplate(
      id: 'tpl_18',
      name: 'Ciano Futura',
      category: 'Moderno',
      description: 'Visual ciano vibrante com foco em inovação solar.',
      bgImagePath: 'assets/images/smart_home_hero.jpg',
      defaultPrimaryColor: 0xFF06B6D4,
      defaultAccentColor: 0xFF8B5CF6,
      defaultDarkTheme: true,
    ),
    SolarSiteTemplate(
      id: 'tpl_19',
      name: 'Solar Royal',
      category: 'Corporativo',
      description: 'Azul marinho clássico com selos de garantia e confiança.',
      bgImagePath: 'assets/images/onboarding/solar_card.jpg',
      defaultPrimaryColor: 0xFF1E40AF,
      defaultAccentColor: 0xFFFBBF24,
      defaultDarkTheme: true,
    ),
    SolarSiteTemplate(
      id: 'tpl_20',
      name: 'Zero Conta Light',
      category: 'Minimalista',
      description: 'Foco em economia de até 95% na fatura de energia.',
      bgImagePath: 'assets/images/solar_page3_house.jpg',
      defaultPrimaryColor: 0xFF16A34A,
      defaultAccentColor: 0xFF0284C7,
      defaultDarkTheme: false,
    ),
  ];

  static SolarSiteTemplate byId(String id) {
    return catalog.firstWhere(
      (t) => t.id == id,
      orElse: () => catalog.first,
    );
  }
}

class SolarSiteServiceItem {
  final String title;
  final String description;
  final String iconName;

  const SolarSiteServiceItem({
    required this.title,
    required this.description,
    this.iconName = 'solar',
  });

  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'iconName': iconName,
      };

  factory SolarSiteServiceItem.fromMap(Map<String, dynamic> map) {
    return SolarSiteServiceItem(
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      iconName: map['iconName'] as String? ?? 'solar',
    );
  }

  IconData get iconData {
    switch (iconName) {
      case 'home':
        return Icons.home_work_rounded;
      case 'business':
        return Icons.business_rounded;
      case 'agro':
        return Icons.agriculture_rounded;
      case 'tools':
        return Icons.build_circle_rounded;
      case 'bolt':
        return Icons.bolt_rounded;
      default:
        return Icons.solar_power_rounded;
    }
  }
}

class SolarSiteClientItem {
  final String name;
  final String location;
  final String powerKwp;
  final String quote;

  const SolarSiteClientItem({
    required this.name,
    required this.location,
    required this.powerKwp,
    required this.quote,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'location': location,
        'powerKwp': powerKwp,
        'quote': quote,
      };

  factory SolarSiteClientItem.fromMap(Map<String, dynamic> map) {
    return SolarSiteClientItem(
      name: map['name'] as String? ?? '',
      location: map['location'] as String? ?? '',
      powerKwp: map['powerKwp'] as String? ?? '',
      quote: map['quote'] as String? ?? '',
    );
  }
}

class SolarSiteConfig {
  final String companyId;
  final String sector;
  final String slug;
  final bool isPublished;
  final String templateId;
  final int primaryColorValue;
  final int accentColorValue;
  final bool isDarkTheme;
  final String companyName;
  final String? logoUrl;
  final String whatsappPhone;
  final String email;
  final String address;
  final String cnpj;
  final String heroTitle;
  final String heroSubtitle;
  final String heroCtaText;
  final bool showCalculator;
  final bool showServices;
  final bool showClients;
  final bool showHowItWorks;
  final List<SolarSiteServiceItem> services;
  final List<SolarSiteClientItem> clients;
  final DateTime updatedAt;

  const SolarSiteConfig({
    required this.companyId,
    this.sector = 'solarPlant',
    required this.slug,
    this.isPublished = true,
    this.templateId = 'tpl_01',
    this.primaryColorValue = 0xFFF59E0B,
    this.accentColorValue = 0xFF10B981,
    this.isDarkTheme = true,
    required this.companyName,
    this.logoUrl,
    this.whatsappPhone = '',
    this.email = '',
    this.address = '',
    this.cnpj = '',
    this.heroTitle = 'Reduza até 95% da sua conta de energia com Energia Solar',
    this.heroSubtitle =
        'Projetos personalizados, homologação completa na concessionária e garantia de até 25 anos para residências, comércios e agronegócio.',
    this.heroCtaText = 'Simular Economia Grátis',
    this.showCalculator = true,
    this.showServices = true,
    this.showClients = true,
    this.showHowItWorks = true,
    this.services = const [
      SolarSiteServiceItem(
        title: 'Energia Solar Residencial',
        description:
            'Economia imediata na fatura de luz e valorização do seu imóvel com instalação rápida e limpa.',
        iconName: 'home',
      ),
      SolarSiteServiceItem(
        title: 'Comercial & Industrial',
        description:
            'Reduza custos fixos da sua empresa e aumente sua margem de lucro com usinas de alta performance.',
        iconName: 'business',
      ),
      SolarSiteServiceItem(
        title: 'Agronegócio & Rural',
        description:
            'Sistemas robustos para fazendas, irrigação, granjas e propriedades rurais com retorno garantido.',
        iconName: 'agro',
      ),
      SolarSiteServiceItem(
        title: 'Projeto & Homologação',
        description:
            'Cuidamos de toda a engenharia, ART e aprovação junto à concessionária sem dor de cabeça.',
        iconName: 'tools',
      ),
    ],
    this.clients = const [
      SolarSiteClientItem(
        name: 'Supermercado Central',
        location: 'Cuiabá - MT',
        powerKwp: '45,5 kWp',
        quote:
            'Nossa conta caiu de R\$ 5.400 para apenas a taxa mínima. Atendimento excelente do projeto à entrega!',
      ),
      SolarSiteClientItem(
        name: 'Residência Família Silva',
        location: 'Várzea Grande - MT',
        powerKwp: '9,8 kWp',
        quote:
            'Instalação concluída em 2 dias e já estamos economizando desde o primeiro mês.',
      ),
      SolarSiteClientItem(
        name: 'Fazenda Boa Vista',
        location: 'Sorriso - MT',
        powerKwp: '75,0 kWp',
        quote:
            'Sistema rodando com força total e monitoramento direto pelo celular.',
      ),
    ],
    required this.updatedAt,
  });

  SolarSiteTemplate get template => SolarSiteTemplate.byId(templateId);

  factory SolarSiteConfig.defaultForCompany({
    required String companyId,
    required String companyName,
    String? logoUrl,
    String whatsappPhone = '',
    String email = '',
    String address = '',
    String cnpj = '',
  }) {
    final cleanSlug = companyName
        .toLowerCase()
        .replaceAll(RegExp(r'[áàãâä]'), 'a')
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[íìîï]'), 'i')
        .replaceAll(RegExp(r'[óòõôö]'), 'o')
        .replaceAll(RegExp(r'[úùûü]'), 'u')
        .replaceAll('ç', 'c')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final fallbackSlug = cleanSlug.isNotEmpty
        ? cleanSlug
        : 'solar-${companyId.substring(0, companyId.length >= 6 ? 6 : companyId.length).toLowerCase()}';

    return SolarSiteConfig(
      companyId: companyId,
      slug: fallbackSlug,
      companyName: companyName.isNotEmpty ? companyName : 'Energia Solar',
      logoUrl: logoUrl,
      whatsappPhone: whatsappPhone,
      email: email,
      address: address,
      cnpj: cnpj,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'companyId': companyId,
        'sector': sector,
        'slug': slug.toLowerCase().trim(),
        'isPublished': isPublished,
        'templateId': templateId,
        'primaryColorValue': primaryColorValue,
        'accentColorValue': accentColorValue,
        'isDarkTheme': isDarkTheme,
        'companyName': companyName,
        'logoUrl': logoUrl,
        'whatsappPhone': whatsappPhone,
        'email': email,
        'address': address,
        'cnpj': cnpj,
        'heroTitle': heroTitle,
        'heroSubtitle': heroSubtitle,
        'heroCtaText': heroCtaText,
        'showCalculator': showCalculator,
        'showServices': showServices,
        'showClients': showClients,
        'showHowItWorks': showHowItWorks,
        'services': services.map((s) => s.toMap()).toList(),
        'clients': clients.map((c) => c.toMap()).toList(),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  factory SolarSiteConfig.fromMap(Map<String, dynamic> map, String companyId) {
    final rawServices = map['services'] as List<dynamic>? ?? const [];
    final rawClients = map['clients'] as List<dynamic>? ?? const [];
    return SolarSiteConfig(
      companyId: map['companyId'] as String? ?? companyId,
      sector: map['sector'] as String? ?? 'solarPlant',
      slug: map['slug'] as String? ?? companyId,
      isPublished: map['isPublished'] as bool? ?? true,
      templateId: map['templateId'] as String? ?? 'tpl_01',
      primaryColorValue:
          (map['primaryColorValue'] as num?)?.toInt() ?? 0xFFF59E0B,
      accentColorValue:
          (map['accentColorValue'] as num?)?.toInt() ?? 0xFF10B981,
      isDarkTheme: map['isDarkTheme'] as bool? ?? true,
      companyName: map['companyName'] as String? ?? 'Energia Solar',
      logoUrl: map['logoUrl'] as String?,
      whatsappPhone: map['whatsappPhone'] as String? ?? '',
      email: map['email'] as String? ?? '',
      address: map['address'] as String? ?? '',
      cnpj: map['cnpj'] as String? ?? '',
      heroTitle: map['heroTitle'] as String? ??
          'Reduza até 95% da sua conta de energia com Energia Solar',
      heroSubtitle: map['heroSubtitle'] as String? ??
          'Projetos personalizados, homologação completa na concessionária e garantia de até 25 anos.',
      heroCtaText:
          map['heroCtaText'] as String? ?? 'Simular Economia Grátis',
      showCalculator: map['showCalculator'] as bool? ?? true,
      showServices: map['showServices'] as bool? ?? true,
      showClients: map['showClients'] as bool? ?? true,
      showHowItWorks: map['showHowItWorks'] as bool? ?? true,
      services: rawServices
          .map((e) =>
              SolarSiteServiceItem.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      clients: rawClients
          .map((e) =>
              SolarSiteClientItem.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  SolarSiteConfig copyWith({
    String? sector,
    String? slug,
    bool? isPublished,
    String? templateId,
    int? primaryColorValue,
    int? accentColorValue,
    bool? isDarkTheme,
    String? companyName,
    String? logoUrl,
    String? whatsappPhone,
    String? email,
    String? address,
    String? cnpj,
    String? heroTitle,
    String? heroSubtitle,
    String? heroCtaText,
    bool? showCalculator,
    bool? showServices,
    bool? showClients,
    bool? showHowItWorks,
    List<SolarSiteServiceItem>? services,
    List<SolarSiteClientItem>? clients,
    DateTime? updatedAt,
  }) {
    return SolarSiteConfig(
      companyId: companyId,
      sector: sector ?? this.sector,
      slug: slug ?? this.slug,
      isPublished: isPublished ?? this.isPublished,
      templateId: templateId ?? this.templateId,
      primaryColorValue: primaryColorValue ?? this.primaryColorValue,
      accentColorValue: accentColorValue ?? this.accentColorValue,
      isDarkTheme: isDarkTheme ?? this.isDarkTheme,
      companyName: companyName ?? this.companyName,
      logoUrl: logoUrl ?? this.logoUrl,
      whatsappPhone: whatsappPhone ?? this.whatsappPhone,
      email: email ?? this.email,
      address: address ?? this.address,
      cnpj: cnpj ?? this.cnpj,
      heroTitle: heroTitle ?? this.heroTitle,
      heroSubtitle: heroSubtitle ?? this.heroSubtitle,
      heroCtaText: heroCtaText ?? this.heroCtaText,
      showCalculator: showCalculator ?? this.showCalculator,
      showServices: showServices ?? this.showServices,
      showClients: showClients ?? this.showClients,
      showHowItWorks: showHowItWorks ?? this.showHowItWorks,
      services: services ?? this.services,
      clients: clients ?? this.clients,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
