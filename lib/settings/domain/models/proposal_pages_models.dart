import 'package:flutter/material.dart';

/// Card individual configurável da Página 2 ou de Páginas Customizadas
class ProposalPageCard {
  final String id;
  final String title;
  final String description;
  final String iconKey; // chave do ícone (ex: 'light', 'shield', 'wifi', 'solar_power', etc.)
  final String colorHex;
  final bool isVisible;
  final int order;
  final String? badgeText;
  final String? cardBgColorHex;
  final String? cardBorderColorHex;
  final double? customWidth;
  final double? customHeight;
  final double? posX; // Posição livre X (0.0 - 1.0) se aplicável
  final double? posY; // Posição livre Y (0.0 - 1.0) se aplicável

  const ProposalPageCard({
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
    this.customWidth,
    this.customHeight,
    this.posX,
    this.posY,
  });

  ProposalPageCard copyWith({
    String? id,
    String? title,
    String? description,
    String? iconKey,
    String? colorHex,
    bool? isVisible,
    int? order,
    String? badgeText,
    String? cardBgColorHex,
    String? cardBorderColorHex,
    double? customWidth,
    double? customHeight,
    double? posX,
    double? posY,
  }) {
    return ProposalPageCard(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      iconKey: iconKey ?? this.iconKey,
      colorHex: colorHex ?? this.colorHex,
      isVisible: isVisible ?? this.isVisible,
      order: order ?? this.order,
      badgeText: badgeText ?? this.badgeText,
      cardBgColorHex: cardBgColorHex ?? this.cardBgColorHex,
      cardBorderColorHex: cardBorderColorHex ?? this.cardBorderColorHex,
      customWidth: customWidth ?? this.customWidth,
      customHeight: customHeight ?? this.customHeight,
      posX: posX ?? this.posX,
      posY: posY ?? this.posY,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'iconKey': iconKey,
      'colorHex': colorHex,
      'isVisible': isVisible,
      'order': order,
      if (badgeText != null) 'badgeText': badgeText,
      if (cardBgColorHex != null) 'cardBgColorHex': cardBgColorHex,
      if (cardBorderColorHex != null) 'cardBorderColorHex': cardBorderColorHex,
      if (customWidth != null) 'customWidth': customWidth,
      if (customHeight != null) 'customHeight': customHeight,
      if (posX != null) 'posX': posX,
      if (posY != null) 'posY': posY,
    };
  }

  factory ProposalPageCard.fromMap(Map<String, dynamic> map) {
    return ProposalPageCard(
      id: map['id'] as String? ?? 'card_${DateTime.now().millisecondsSinceEpoch}',
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      iconKey: map['iconKey'] as String? ?? 'light',
      colorHex: map['colorHex'] as String? ?? '#0284C7',
      isVisible: map['isVisible'] as bool? ?? true,
      order: (map['order'] as num?)?.toInt() ?? 0,
      badgeText: map['badgeText'] as String?,
      cardBgColorHex: map['cardBgColorHex'] as String?,
      cardBorderColorHex: map['cardBorderColorHex'] as String?,
      customWidth: (map['customWidth'] as num?)?.toDouble(),
      customHeight: (map['customHeight'] as num?)?.toDouble(),
      posX: (map['posX'] as num?)?.toDouble(),
      posY: (map['posY'] as num?)?.toDouble(),
    );
  }

  static List<ProposalPageCard> defaultAutomationCards() {
    return const [
      ProposalPageCard(
        id: 'card_conforto',
        title: 'Conforto & Cenas Inteligentes',
        description: 'Iluminação, climatização, áudio e cortinas sincronizados em cenas personalizadas para cada momento.',
        iconKey: 'lightbulb',
        colorHex: '#38BDF8',
        order: 0,
      ),
      ProposalPageCard(
        id: 'card_seguranca',
        title: 'Segurança Ativa 24h',
        description: 'Controle biométrico, fechaduras inteligentes, câmeras e sensores com notificações instantâneas no celular.',
        iconKey: 'shield',
        colorHex: '#0284C7',
        order: 1,
      ),
      ProposalPageCard(
        id: 'card_eficiencia',
        title: 'Eficiência Energética',
        description: 'Gestão inteligente de consumo com desligamento programado, climatização otimizada e zero desperdício.',
        iconKey: 'eco',
        colorHex: '#10B981',
        order: 2,
      ),
      ProposalPageCard(
        id: 'card_valorizacao',
        title: 'Valorização Imobiliária',
        description: 'Residências modernas com automação de ponta são altamente desejadas e valorizadas pelo mercado.',
        iconKey: 'home',
        colorHex: '#6366F1',
        order: 3,
      ),
      ProposalPageCard(
        id: 'card_engenharia',
        title: 'Engenharia & Projeto Executivo',
        description: 'Estudo completo de infraestrutura, cabeamento estruturado, rede Wi-Fi Mesh e posicionamento acústico.',
        iconKey: 'blueprint',
        colorHex: '#0284C7',
        order: 4,
      ),
      ProposalPageCard(
        id: 'card_app_voz',
        title: 'Aplicativo Único & Comando de Voz',
        description: 'Controle toda a residência pela tela do smartphone, tablet, comando de voz (Alexa/Google/Siri) ou keypads.',
        iconKey: 'phone',
        colorHex: '#8B5CF6',
        order: 5,
      ),
      ProposalPageCard(
        id: 'card_equipamentos',
        title: 'Equipamentos Homologados',
        description: 'Módulos, atuadores e sensores de padrão internacional com homologação Anatel e alta confiabilidade.',
        iconKey: 'award',
        colorHex: '#F59E0B',
        order: 6,
      ),
      ProposalPageCard(
        id: 'card_instalacao',
        title: 'Instalação, Cenas & Suporte',
        description: 'Montagem limpa por especialistas certificados, programação sob medida, treinamento e garantia de fábrica.',
        iconKey: 'handshake',
        colorHex: '#10B981',
        order: 7,
      ),
    ];
  }

  static List<ProposalPageCard> defaultSolarCards() {
    return const [
      ProposalPageCard(
        id: 'card_solar_economia',
        title: 'Economia Imediata de até 95%',
        description: 'Reduza drasticamente a conta de energia gerando sua própria eletricidade limpa a partir da luz solar.',
        iconKey: 'coins',
        colorHex: '#10B981',
        order: 0,
      ),
      ProposalPageCard(
        id: 'card_solar_payback',
        title: 'Retorno Rápido do Investimento',
        description: 'Payback atrativo entre 3 a 5 anos com rentabilidade financeira muito superior à renda fixa.',
        iconKey: 'chart',
        colorHex: '#F59E0B',
        order: 1,
      ),
      ProposalPageCard(
        id: 'card_solar_garantia',
        title: 'Garantia de Geração 25 a 30 Anos',
        description: 'Módulos fotovoltaicos Tier-1 de altíssima eficiência com durabilidade e garantia linear de produção.',
        iconKey: 'shield',
        colorHex: '#0284C7',
        order: 2,
      ),
      ProposalPageCard(
        id: 'card_solar_valorizacao',
        title: 'Valorização Imediata do Imóvel',
        description: 'Imóveis equipados com usinas solares próprias possuem maior liquidez e valor de mercado expressivo.',
        iconKey: 'home',
        colorHex: '#6366F1',
        order: 3,
      ),
      ProposalPageCard(
        id: 'card_solar_engenharia',
        title: 'Engenharia & Homologação na Concessionária',
        description: 'Projeto elétrico executivo completo com emissão de ART e aprovação junto à concessionária de energia.',
        iconKey: 'engineering',
        colorHex: '#0284C7',
        order: 4,
      ),
      ProposalPageCard(
        id: 'card_solar_monitoramento',
        title: 'Monitoramento em Tempo Real via App',
        description: 'Acompanhe a geração da sua usina solar minuto a minuto na palma da sua mão com gráficos e alertas.',
        iconKey: 'phone',
        colorHex: '#38BDF8',
        order: 5,
      ),
      ProposalPageCard(
        id: 'card_solar_sustentavel',
        title: 'Energia 100% Limpa & Renovável',
        description: 'Evite toneladas de emissão de CO2 na atmosfera e contribua ativamente para o futuro sustentável.',
        iconKey: 'eco',
        colorHex: '#10B981',
        order: 6,
      ),
      ProposalPageCard(
        id: 'card_solar_instalacao',
        title: 'Instalação Especializada Turn-Key',
        description: 'Equipe própria certificada NR10/NR35 com entrega rápida, testes de carga e suporte técnico contínuo.',
        iconKey: 'handshake',
        colorHex: '#F59E0B',
        order: 7,
      ),
    ];
  }
}

/// Imagem livre inserida em uma página personalizada
class ProposalFreeImageItem {
  final String id;
  final String imageBase64OrUrl;
  final double x; // Posição X (0.0 - 1.0)
  final double y; // Posição Y (0.0 - 1.0)
  final double width;
  final double height;
  final double borderRadius;

  const ProposalFreeImageItem({
    required this.id,
    required this.imageBase64OrUrl,
    required this.x,
    required this.y,
    this.width = 220,
    this.height = 140,
    this.borderRadius = 8,
  });

  ProposalFreeImageItem copyWith({
    String? id,
    String? imageBase64OrUrl,
    double? x,
    double? y,
    double? width,
    double? height,
    double? borderRadius,
  }) {
    return ProposalFreeImageItem(
      id: id ?? this.id,
      imageBase64OrUrl: imageBase64OrUrl ?? this.imageBase64OrUrl,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      borderRadius: borderRadius ?? this.borderRadius,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'imageBase64OrUrl': imageBase64OrUrl,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'borderRadius': borderRadius,
    };
  }

  factory ProposalFreeImageItem.fromMap(Map<String, dynamic> map) {
    return ProposalFreeImageItem(
      id: map['id'] as String? ?? 'img_${DateTime.now().millisecondsSinceEpoch}',
      imageBase64OrUrl: map['imageBase64OrUrl'] as String? ?? '',
      x: (map['x'] as num?)?.toDouble() ?? 0.1,
      y: (map['y'] as num?)?.toDouble() ?? 0.2,
      width: (map['width'] as num?)?.toDouble() ?? 220,
      height: (map['height'] as num?)?.toDouble() ?? 140,
      borderRadius: (map['borderRadius'] as num?)?.toDouble() ?? 8,
    );
  }
}

/// Página customizada criada pelo usuário
class ProposalCustomPage {
  final String id;
  final String title;
  final String subtitle;
  final String bgType; // 'white', 'color', 'image'
  final String bgColorHex;
  final String? bgImage;
  final List<ProposalPageCard> cards;
  final List<ProposalFreeImageItem> freeImages;

  const ProposalCustomPage({
    required this.id,
    required this.title,
    this.subtitle = '',
    this.bgType = 'white',
    this.bgColorHex = '#FFFFFF',
    this.bgImage,
    this.cards = const [],
    this.freeImages = const [],
  });

  ProposalCustomPage copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? bgType,
    String? bgColorHex,
    String? bgImage,
    List<ProposalPageCard>? cards,
    List<ProposalFreeImageItem>? freeImages,
  }) {
    return ProposalCustomPage(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      bgType: bgType ?? this.bgType,
      bgColorHex: bgColorHex ?? this.bgColorHex,
      bgImage: bgImage ?? this.bgImage,
      cards: cards ?? this.cards,
      freeImages: freeImages ?? this.freeImages,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'bgType': bgType,
      'bgColorHex': bgColorHex,
      if (bgImage != null) 'bgImage': bgImage,
      'cards': cards.map((c) => c.toMap()).toList(),
      'freeImages': freeImages.map((i) => i.toMap()).toList(),
    };
  }

  factory ProposalCustomPage.fromMap(Map<String, dynamic> map) {
    return ProposalCustomPage(
      id: map['id'] as String? ?? 'page_${DateTime.now().millisecondsSinceEpoch}',
      title: map['title'] as String? ?? 'Nova Página Personalizada',
      subtitle: map['subtitle'] as String? ?? '',
      bgType: map['bgType'] as String? ?? 'white',
      bgColorHex: map['bgColorHex'] as String? ?? '#FFFFFF',
      bgImage: map['bgImage'] as String?,
      cards: (map['cards'] as List<dynamic>?)
              ?.map((e) => ProposalPageCard.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      freeImages: (map['freeImages'] as List<dynamic>?)
              ?.map((e) => ProposalFreeImageItem.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// 20 Templates Oficiais de Página 2 (Com disposições, badges e ilustrações finais)
class ProposalPage2TemplateInfo {
  final String id;
  final String title;
  final String category;
  final String description;
  final String layoutType; // 'grid2x2', 'isometric', 'split5050', 'cyberDark', 'luxuryGold', etc.
  final IconData icon;
  final String defaultPrimaryColor;
  final String illustrationKey; // 'banner', 'isometric', 'blueprint', 'cyberDark', 'luxuryGold', 'timeline', 'solarFlow', 'iotNetwork', 'greenEco', 'none'
  final List<ProposalPageCard> defaultCards;

  const ProposalPage2TemplateInfo({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.layoutType,
    required this.icon,
    required this.defaultPrimaryColor,
    this.illustrationKey = 'banner',
    this.defaultCards = const [],
  });

  static List<ProposalPage2TemplateInfo> getAllTemplates() {
    return const [
      // 1. Tech Grid 2x2 Clássico
      ProposalPage2TemplateInfo(
        id: 'tpl_01_tech_grid',
        title: '1. Tech Grid 2x2 Clássico',
        category: 'High-Tech',
        description: '4 Cards de diferenciais + 4 Cards de escopo com badges circulares e banner panorâmico.',
        layoutType: 'grid2x2',
        icon: Icons.grid_view_rounded,
        defaultPrimaryColor: '#0284C7',
        illustrationKey: 'banner',
        defaultCards: [
          ProposalPageCard(id: 'c1', title: 'Conforto & Cenas Inteligentes', description: 'Iluminação, climatização, áudio e cortinas sincronizados em cenas para cada momento.', iconKey: 'light', colorHex: '#0284C7', order: 0),
          ProposalPageCard(id: 'c2', title: 'Segurança Ativa 24h', description: 'Controle biométrico, fechaduras inteligentes, câmeras e sensores com notificações no celular.', iconKey: 'shield', colorHex: '#0284C7', order: 1),
          ProposalPageCard(id: 'c3', title: 'Eficiência Energética', description: 'Gestão inteligente de consumo com desligamento programado e zero desperdício.', iconKey: 'eco', colorHex: '#0284C7', order: 2),
          ProposalPageCard(id: 'c4', title: 'Valorização Imobiliária', description: 'Residências modernas com automação de ponta são altamente valorizadas pelo mercado.', iconKey: 'home', colorHex: '#0284C7', order: 3),
          ProposalPageCard(id: 'c5', title: 'Engenharia & Projeto Executivo', description: 'Estudo de infraestrutura, cabeamento estruturado, rede Wi-Fi Mesh e posicionamento acústico.', iconKey: 'blueprint', colorHex: '#0284C7', order: 4),
          ProposalPageCard(id: 'c6', title: 'Aplicativo Único & Comando de Voz', description: 'Controle total por smartphone, tablet ou comandos de voz Alexa, Google e Siri.', iconKey: 'phone', colorHex: '#0284C7', order: 5),
          ProposalPageCard(id: 'c7', title: 'Equipamentos Homologados', description: 'Módulos e sensores certificados com garantia de fábrica e alta durabilidade.', iconKey: 'award', colorHex: '#0284C7', order: 6),
          ProposalPageCard(id: 'c8', title: 'Instalação, Cenas & Suporte', description: 'Montagem limpa, programação sob medida e suporte pós-venda contínuo.', iconKey: 'handshake', colorHex: '#0284C7', order: 7),
        ],
      ),

      // 2. Corte Isométrico Arquitetura
      ProposalPage2TemplateInfo(
        id: 'tpl_02_isometric_cutaway',
        title: '2. Corte Isométrico Arquitetura',
        category: 'Arquitetura',
        description: 'Cards horizontais compactos combinados com ilustração em corte isométrico dos ambientes.',
        layoutType: 'isometric',
        icon: Icons.layers_rounded,
        defaultPrimaryColor: '#2563EB',
        illustrationKey: 'isometric',
        defaultCards: [
          ProposalPageCard(id: 'c1', title: 'Living & Home Theater 4K', description: 'Controle integrado de áudio multicanal, projetor, telão e iluminação cênica de cinema.', iconKey: 'music', colorHex: '#2563EB', order: 0),
          ProposalPageCard(id: 'c2', title: 'Espaço Gourmet & Som Externo', description: 'Caixas de som marinadas com resistência IP66 e controle direto pelo celular.', iconKey: 'wifi', colorHex: '#2563EB', order: 1),
          ProposalPageCard(id: 'c3', title: 'Suítes Climatizadas Inteligentes', description: 'Termostatos inteligentes com agendamento de temperatura ideal para sono perfeito.', iconKey: 'thermostat', colorHex: '#2563EB', order: 2),
          ProposalPageCard(id: 'c4', title: 'Acesso Biométrico & Fechadura Digital', description: 'Senhas temporárias para hóspedes e funcionários com relatório de entradas em tempo real.', iconKey: 'lock', colorHex: '#2563EB', order: 3),
          ProposalPageCard(id: 'c5', title: 'Cortinas & Persianas Motorizadas', description: 'Abertura suave ao nascer do sol e fechamento automático para proteger móveis.', iconKey: 'light', colorHex: '#2563EB', order: 4),
          ProposalPageCard(id: 'c6', title: 'Controle de Bombas e Paisagismo', description: 'Automação de cascata, hidro da piscina e irrigação de jardim com sensor de umidade.', iconKey: 'eco', colorHex: '#2563EB', order: 5),
        ],
      ),

      // 3. Split 50/50 Editorial Blueprint
      ProposalPage2TemplateInfo(
        id: 'tpl_03_split_5050',
        title: '3. Split Editorial & Prancheta',
        category: 'Editorial',
        description: 'Design técnico arrojado com prancheta blueprint de infraestrutura e cards estruturados.',
        layoutType: 'split5050',
        icon: Icons.vertical_split_rounded,
        defaultPrimaryColor: '#0F172A',
        illustrationKey: 'blueprint',
        defaultCards: [
          ProposalPageCard(id: 'c1', title: 'Infraestrutura Embutida Limpa', description: 'Sem canaletas ou fiação aparente: tubulações projetadas direto na planta arquitetônica.', iconKey: 'blueprint', colorHex: '#0F172A', order: 0),
          ProposalPageCard(id: 'c2', title: 'Rack Centralizador & Cabeamento Cat6', description: 'Patch panel organizado, nobreak senoidal puro e refrigeração forçada.', iconKey: 'wifi', colorHex: '#0F172A', order: 1),
          ProposalPageCard(id: 'c3', title: 'Keypads Touchscreen de Vidro', description: 'Acabamentos nobres em vidro temperado com gravação a laser personalizada dos cômodos.', iconKey: 'phone', colorHex: '#0F172A', order: 2),
          ProposalPageCard(id: 'c4', title: 'Supervisão Técnica e ART/CREA', description: 'Acompanhamento do engenheiro responsável com emissão de Anotação de Responsabilidade Técnica.', iconKey: 'award', colorHex: '#0F172A', order: 3),
        ],
      ),

      // 4. Cyber Dark Minimalist
      ProposalPage2TemplateInfo(
        id: 'tpl_04_cyber_dark',
        title: '4. Cyber Dark Minimalist',
        category: 'High-Tech',
        description: 'Fundo Dark Slate com cards escuros, bordas em neon ciano e circuito cibernético IoT.',
        layoutType: 'cyberDark',
        icon: Icons.dark_mode_rounded,
        defaultPrimaryColor: '#38BDF8',
        illustrationKey: 'cyberDark',
        defaultCards: [
          ProposalPageCard(id: 'c1', title: 'Backbone Criptografado Local', description: 'Todos os comandos rodam em rede local com chave AES-256 e privacidade absoluta sem nuvem.', iconKey: 'shield', colorHex: '#38BDF8', order: 0),
          ProposalPageCard(id: 'c2', title: 'Sensores de Presença Micro-Ondas', description: 'Detecção de presença estática: a luz permanece ligada mesmo se a pessoa estiver imóvel lendo.', iconKey: 'light', colorHex: '#38BDF8', order: 1),
          ProposalPageCard(id: 'c3', title: 'Inteligência Artificial Preditiva', description: 'O sistema aprende sua rotina e prepara a casa automaticamente antes do seu retorno.', iconKey: 'bolt', colorHex: '#38BDF8', order: 2),
          ProposalPageCard(id: 'c4', title: 'Interface Cibernética Unificada', description: 'Painéis táteis de parede integrados com comandos em milissegundos.', iconKey: 'phone', colorHex: '#38BDF8', order: 3),
        ],
      ),

      // 5. Luxury Gold Premium
      ProposalPage2TemplateInfo(
        id: 'tpl_05_luxury_gold',
        title: '5. Luxury Gold Premium',
        category: 'Luxo',
        description: 'Linhas nobres em tom âmbar/champanhe, tipografia sofisticada e selo de alta nobreza.',
        layoutType: 'luxuryGold',
        icon: Icons.workspace_premium_rounded,
        defaultPrimaryColor: '#D97706',
        illustrationKey: 'luxuryGold',
        defaultCards: [
          ProposalPageCard(id: 'c1', title: 'Design Europeu & Metais Nobres', description: 'Pulsadores com acabamento em latão escovado, bronze champanhe e níquel acetinado.', iconKey: 'award', colorHex: '#D97706', order: 0),
          ProposalPageCard(id: 'c2', title: 'Sonorização Audiófila Hi-Res', description: 'Amplificadores Classe D de alta fidelidade com processamento digital DSP surround.', iconKey: 'music', colorHex: '#D97706', order: 1),
          ProposalPageCard(id: 'c3', title: 'Adega Climatizada de Precisão', description: 'Monitoramento contínuo de temperatura e umidade com alertas de oscilação.', iconKey: 'thermostat', colorHex: '#D97706', order: 2),
          ProposalPageCard(id: 'c4', title: 'Concierge & Atendimento VIP', description: 'Suporte concierge com atendimento prioritário 24 horas por dia, 7 dias por semana.', iconKey: 'handshake', colorHex: '#D97706', order: 3),
        ],
      ),

      // 6. Jornada & Linha do Tempo Turnkey
      ProposalPage2TemplateInfo(
        id: 'tpl_06_turnkey_timeline',
        title: '6. Jornada & Linha do Tempo',
        category: 'Processos',
        description: 'Cards em fluxo sequencial numerado (Projeto ➔ Homologação ➔ Montagem ➔ Suporte).',
        layoutType: 'timeline',
        icon: Icons.timeline_rounded,
        defaultPrimaryColor: '#10B981',
        illustrationKey: 'timeline',
        defaultCards: [
          ProposalPageCard(id: 'c1', title: 'Etapa 1: Diagnóstico & Projeto Executivo', description: 'Levantamento minucioso dos hábitos da família e plantas de engenharia completas.', iconKey: 'blueprint', colorHex: '#10B981', order: 0),
          ProposalPageCard(id: 'c2', title: 'Etapa 2: Tubulação & Passagem de Cabos', description: 'Acompanhamento do gesso e alvenaria sem quebra desnecessária ou retrabalho.', iconKey: 'wifi', colorHex: '#10B981', order: 1),
          ProposalPageCard(id: 'c3', title: 'Etapa 3: Instalação & Parametrização', description: 'Conexão dos módulos de controle e afinação acústica dos alto-falantes.', iconKey: 'bolt', colorHex: '#10B981', order: 2),
          ProposalPageCard(id: 'c4', title: 'Etapa 4: Treinamento & Garantia Estendida', description: 'Apresentação prática da residência com entrega do manual interativo da casa.', iconKey: 'award', colorHex: '#10B981', order: 3),
        ],
      ),

      // 7. Pílulas Minimalistas 3x2
      ProposalPage2TemplateInfo(
        id: 'tpl_07_pill_minimalist',
        title: '7. Pílulas Minimalistas 3x2',
        category: 'Minimalista',
        description: 'Cards em formato de pílula arredondada com paleta suave e ícones duotone modernos.',
        layoutType: 'pill3x2',
        icon: Icons.panorama_fish_eye_rounded,
        defaultPrimaryColor: '#6366F1',
        illustrationKey: 'banner',
        defaultCards: [
          ProposalPageCard(id: 'c1', title: 'Dimerização Suave 0-100%', description: 'Transição perfeita de luzes sem efeito de piscar ou ruídos nos interruptores.', iconKey: 'light', colorHex: '#6366F1', order: 0),
          ProposalPageCard(id: 'c2', title: 'Modo Férias Simulado', description: 'Acionamento aleatório de iluminação e TV para simular presença na casa durante viagens.', iconKey: 'shield', colorHex: '#6366F1', order: 1),
          ProposalPageCard(id: 'c3', title: 'Autonomia Total sem Internet', description: 'Todos os interruptores de parede continuam funcionando mesmo sem internet externa.', iconKey: 'wifi', colorHex: '#6366F1', order: 2),
          ProposalPageCard(id: 'c4', title: 'Atualizações Automáticas OTA', description: 'Novas funcionalidades e protocolos de segurança adicionados periodicamente via software.', iconKey: 'bolt', colorHex: '#6366F1', order: 3),
          ProposalPageCard(id: 'c5', title: 'Keypads Touchscreen de Parede', description: 'Telas elegantes de alta sensibilidade para controle rápido de todos os ambientes.', iconKey: 'phone', colorHex: '#6366F1', order: 4),
          ProposalPageCard(id: 'c6', title: 'Eficiência de Consumo em Standby', description: 'Módulos de baixíssimo consumo elétrico com certificação internacional A+.', iconKey: 'eco', colorHex: '#6366F1', order: 5),
        ],
      ),

      // 8. Cards Flutuantes & Sombras
      ProposalPage2TemplateInfo(
        id: 'tpl_08_floating_elevation',
        title: '8. Cards Flutuantes & Sombras',
        category: 'Moderno',
        description: 'Cards brancos com elevação suave, bordas arredondadas e cabeçalhos em gradiente.',
        layoutType: 'floating',
        icon: Icons.filter_none_rounded,
        defaultPrimaryColor: '#0284C7',
        illustrationKey: 'isometric',
        defaultCards: [
          ProposalPageCard(id: 'c1', title: 'Cenários com 1 Único Toque', description: 'Com apenas um clique no botão "Cinema", a TV liga, as cortinas descem e as luzes se apagam.', iconKey: 'light', colorHex: '#0284C7', order: 0),
          ProposalPageCard(id: 'c2', title: 'Câmeras IP com IA Integrada', description: 'Reconhecimento de veículos de moradores, visitantes e pets com gravação contínua no NVR.', iconKey: 'camera', colorHex: '#0284C7', order: 1),
          ProposalPageCard(id: 'c3', title: 'Integração com Assistentes', description: 'Total compatibilidade com Siri (Apple Home), Google Home e Amazon Alexa.', iconKey: 'phone', colorHex: '#0284C7', order: 2),
          ProposalPageCard(id: 'c4', title: 'Fechaduras Digitais Biométricas', description: 'Abertura rápida por impressão digital, leitor facial 3D e tag NFC criptografada.', iconKey: 'lock', colorHex: '#0284C7', order: 3),
        ],
      ),

      // 9. Comparativo com vs. sem Solução (Solar / Automação)
      ProposalPage2TemplateInfo(
        id: 'tpl_09_comparative_table',
        title: '9. Comparativo com vs. sem Solução',
        category: 'Comercial',
        description: 'Tabela comparativa direta: residência convencional vs. residência inteligente/solar.',
        layoutType: 'comparative',
        icon: Icons.compare_arrows_rounded,
        defaultPrimaryColor: '#10B981',
        illustrationKey: 'solarFlow',
        defaultCards: [
          ProposalPageCard(id: 'c1', title: 'Casa Convencional: 10 Controles Remotos', description: 'Controles espalhados, luzes esquecidas acesas e insegurança ao viajar.', iconKey: 'shield', colorHex: '#EF4444', order: 0),
          ProposalPageCard(id: 'c2', title: 'Casa Inteligente: 1 Único App no Celular', description: 'Centralização completa de iluminação, clima, segurança e som num único lugar.', iconKey: 'phone', colorHex: '#10B981', order: 1),
          ProposalPageCard(id: 'c3', title: 'Sem Energia Solar: Faturas Altas Todo Mês', description: 'Tarifas abusivas da concessionária e reajustes anuais contínuos sem retorno.', iconKey: 'coins', colorHex: '#EF4444', order: 2),
          ProposalPageCard(id: 'c4', title: 'Com Energia Solar: Economia de até 95%', description: 'Independência energética, blindagem tarifária e valorização imediata do imóvel.', iconKey: 'solar_power', colorHex: '#10B981', order: 3),
        ],
      ),

      // 10. Glassmorphism Ice Blue
      ProposalPage2TemplateInfo(
        id: 'tpl_10_glassmorphism',
        title: '10. Glassmorphism Ice Blue',
        category: 'High-Tech',
        description: 'Efeito vidro fosco translúcido com gradientes azulados e infográfico de rede Mesh.',
        layoutType: 'glassmorphism',
        icon: Icons.blur_on_rounded,
        defaultPrimaryColor: '#0EA5E9',
        illustrationKey: 'cyberDark',
        defaultCards: [
          ProposalPageCard(id: 'c1', title: 'Wi-Fi 6 Mesh Corporativo', description: 'Cobertura impecável em todos os cômodos, piscina e garagem sem quedas de sinal.', iconKey: 'wifi', colorHex: '#0EA5E9', order: 0),
          ProposalPageCard(id: 'c2', title: 'Switches PoE Silenciosos', description: 'Alimentação elétrica dos equipamentos direto pelos cabos de rede sem tomadas extras.', iconKey: 'bolt', colorHex: '#0EA5E9', order: 1),
          ProposalPageCard(id: 'c3', title: 'Sensores Ambientais 4 em 1', description: 'Temperatura, umidade, luminosidade lux e presença humana num dispositivo discreto.', iconKey: 'thermostat', colorHex: '#0EA5E9', order: 2),
          ProposalPageCard(id: 'c4', title: 'Garantia de 3 Anos com Troca Expressa', description: 'Substituição imediata de módulos sem espera de laudo de assistência técnica.', iconKey: 'award', colorHex: '#0EA5E9', order: 3),
        ],
      ),

      // 11. Colmeia Hexagonal IoT
      ProposalPage2TemplateInfo(
        id: 'tpl_11_hexagonal_iot',
        title: '11. Colmeia Hexagonal IoT',
        category: 'Inovação',
        description: 'Nós hexagonais conectados representando os diferentes subsistemas tecnológicos.',
        layoutType: 'hexagonal',
        icon: Icons.hexagon_outlined,
        defaultPrimaryColor: '#8B5CF6',
        illustrationKey: 'iotNetwork',
        defaultCards: [
          ProposalPageCard(id: 'c1', title: 'Subsistema 1: Iluminação Dimerizável', description: 'Fitas LED COB e lâmpadas dimerizáveis com temperatura de cor ajustável de 2700K a 6500K.', iconKey: 'light', colorHex: '#8B5CF6', order: 0),
          ProposalPageCard(id: 'c2', title: 'Subsistema 2: Climatização Central', description: 'Controle preciso de condicionadores de ar tipo split, inverter e dutados pelo celular.', iconKey: 'thermostat', colorHex: '#8B5CF6', order: 1),
          ProposalPageCard(id: 'c3', title: 'Subsistema 3: Áudio e Vídeo Multiroom', description: 'Música diferente em cada ambiente com streaming Spotify Connect e Apple AirPlay 2.', iconKey: 'music', colorHex: '#8B5CF6', order: 2),
          ProposalPageCard(id: 'c4', title: 'Subsistema 4: Fechaduras e Acesso', description: 'Biometria, teclado numérico luminoso e integração com campainha de vídeo IP.', iconKey: 'lock', colorHex: '#8B5CF6', order: 3),
        ],
      ),

      // 12. Hub Central & Ecossistema
      ProposalPage2TemplateInfo(
        id: 'tpl_12_circular_hub',
        title: '12. Hub Central & Ecossistema',
        category: 'Infográfico',
        description: 'Diagrama radial com hub central conectando iluminação, segurança, som e climatização.',
        layoutType: 'circularHub',
        icon: Icons.hub_rounded,
        defaultPrimaryColor: '#0284C7',
        illustrationKey: 'iotNetwork',
        defaultCards: [
          ProposalPageCard(id: 'c1', title: 'Hub Central Multiprotocolo', description: 'Suporte nativo aos padrões internacionais Zigbee 3.0, Z-Wave Plus, Matter e Thread.', iconKey: 'wifi', colorHex: '#0284C7', order: 0),
          ProposalPageCard(id: 'c2', title: 'Redundância com Bateria Backup', description: 'Até 4 horas de funcionamento ininterrupto mesmo em caso de apagão na rede da rua.', iconKey: 'bolt', colorHex: '#0284C7', order: 1),
          ProposalPageCard(id: 'c3', title: 'Conexão 4G LTE de Emergência', description: 'Envio imediato de alertas de intrusão mesmo se o cabo da internet for rompido.', iconKey: 'phone', colorHex: '#0284C7', order: 2),
          ProposalPageCard(id: 'c4', title: 'Histórico de Atividades e Logs', description: 'Registro detalhado de horários de abertura de portas e acionamento de cenários.', iconKey: 'chart', colorHex: '#0284C7', order: 3),
        ],
      ),

      // 13. Revista & Design Editorial
      ProposalPage2TemplateInfo(
        id: 'tpl_13_editorial_magazine',
        title: '13. Revista & Design Editorial',
        category: 'Editorial',
        description: 'Blocos amplos de texto editorial combinados com grandes imagens e tipografia imponente.',
        layoutType: 'editorial',
        icon: Icons.menu_book_rounded,
        defaultPrimaryColor: '#0F172A',
        illustrationKey: 'banner',
        defaultCards: [
          ProposalPageCard(id: 'c1', title: 'A Casa que Acompanha seu Ritmo', description: 'Da iluminação suave ao acordar ao encerramento automático da casa na hora de dormir.', iconKey: 'home', colorHex: '#0F172A', order: 0),
          ProposalPageCard(id: 'c2', title: 'Aroma, Temperatura & Som Integrados', description: 'Experiência sensorial completa criando a atmosfera perfeita para relaxamento e jantares.', iconKey: 'music', colorHex: '#0F172A', order: 1),
          ProposalPageCard(id: 'c3', title: 'Engenharia Invisível aos Olhos', description: 'Tecnologia que impressiona sem poluir os ambientes ou comprometer o projeto de interiores.', iconKey: 'blueprint', colorHex: '#0F172A', order: 2),
          ProposalPageCard(id: 'c4', title: 'Assessoria Especializada Contínua', description: 'Visitas periódicas de calibragem e acompanhamento técnico vitalício.', iconKey: 'handshake', colorHex: '#0F172A', order: 3),
        ],
      ),

      // 14. Os 2 Pilares Executivos
      ProposalPage2TemplateInfo(
        id: 'tpl_14_two_pillars',
        title: '14. Os 2 Pilares Executivos',
        category: 'Executivo',
        description: 'Duas colunas imponentes com checkmarks detalhados e rodapé com selo de garantia.',
        layoutType: 'twoPillars',
        icon: Icons.view_column_rounded,
        defaultPrimaryColor: '#2563EB',
        illustrationKey: 'luxuryGold',
        defaultCards: [
          ProposalPageCard(id: 'c1', title: 'Pilar 1: Engenharia de Alta Performance', description: 'Dimensionamento elétrico, cabeamento estruturado e módulos industriais com 0% falhas.', iconKey: 'bolt', colorHex: '#2563EB', order: 0),
          ProposalPageCard(id: 'c2', title: 'Pilar 2: Usabilidade & Facilidade de Uso', description: 'Qualquer pessoa da família (crianças a idosos) usa o sistema sem nenhuma dificuldade.', iconKey: 'phone', colorHex: '#2563EB', order: 1),
          ProposalPageCard(id: 'c3', title: 'Homologação e Conformidade Técnica', description: 'Equipamentos certificados pela Anatel e projeto alinhado às normas NBR 5410.', iconKey: 'award', colorHex: '#2563EB', order: 2),
          ProposalPageCard(id: 'c4', title: 'Entrega com Termo de Aceite Formal', description: 'Checklist rigoroso de testes ponto a ponto antes da entrega definitiva das chaves.', iconKey: 'handshake', colorHex: '#2563EB', order: 3),
        ],
      ),

      // 15. Matriz Completa 3x3
      ProposalPage2TemplateInfo(
        id: 'tpl_15_matrix_3x3',
        title: '15. Matriz Completa 3x3',
        category: 'Catálogo',
        description: 'Grade densa e organizada com 6 recursos essenciais para visão panorâmica e objetiva.',
        layoutType: 'matrix3x3',
        icon: Icons.apps_rounded,
        defaultPrimaryColor: '#0284C7',
        illustrationKey: 'blueprint',
        defaultCards: [
          ProposalPageCard(id: 'c1', title: 'Iluminação Cênica', description: 'Dimerização e circuitos inteligentes.', iconKey: 'light', colorHex: '#0284C7', order: 0),
          ProposalPageCard(id: 'c2', title: 'Climatização HVAC', description: 'Automação de ar condicionado split/duto.', iconKey: 'thermostat', colorHex: '#0284C7', order: 1),
          ProposalPageCard(id: 'c3', title: 'Áudio & Vídeo Hi-Fi', description: 'Zonas independentes de som estéreo.', iconKey: 'music', colorHex: '#0284C7', order: 2),
          ProposalPageCard(id: 'c4', title: 'Segurança & Câmeras', description: 'Monitoramento 24h com alerta no celular.', iconKey: 'camera', colorHex: '#0284C7', order: 3),
          ProposalPageCard(id: 'c5', title: 'Controle de Acesso', description: 'Fechaduras biométricas e interfonia IP.', iconKey: 'lock', colorHex: '#0284C7', order: 4),
          ProposalPageCard(id: 'c6', title: 'Cortinas & Persianas', description: 'Acionamento silencioso e sincronizado.', iconKey: 'home', colorHex: '#0284C7', order: 5),
        ],
      ),

      // 16. Hero Panorama Topo + 3 Cards
      ProposalPage2TemplateInfo(
        id: 'tpl_16_hero_top_cards',
        title: '16. Hero Panorama Topo + 3 Cards',
        category: 'Visual',
        description: 'Ilustração panorâmica ampla ocupando o rodapé e 3 cards robustos de destaque.',
        layoutType: 'heroTop',
        icon: Icons.panorama_rounded,
        defaultPrimaryColor: '#38BDF8',
        illustrationKey: 'banner',
        defaultCards: [
          ProposalPageCard(id: 'c1', title: 'Transformação Digital da sua Moradia', description: 'A automação valoriza o imóvel em até 20% e traz praticidade inigualável para o dia a dia.', iconKey: 'home', colorHex: '#38BDF8', order: 0),
          ProposalPageCard(id: 'c2', title: 'Tecnologia que Reduz Custos e Gastos', description: 'Desligamento inteligente de standby e ar condicionado que economizam até 30% de energia.', iconKey: 'eco', colorHex: '#38BDF8', order: 1),
          ProposalPageCard(id: 'c3', title: 'Conectividade e Suporte VIP Vitalício', description: 'Nossa equipe técnica fica de prontidão para ajustes remotos sem necessidade de visita física.', iconKey: 'handshake', colorHex: '#38BDF8', order: 2),
          ProposalPageCard(id: 'c4', title: 'Padrão Internacional de Engenharia', description: 'Equipamentos certificados de padrão industrial garantem durabilidade por décadas.', iconKey: 'award', colorHex: '#38BDF8', order: 3),
        ],
      ),

      // 17. Prancheta Técnica de Engenharia
      ProposalPage2TemplateInfo(
        id: 'tpl_17_engineering_checklist',
        title: '17. Prancheta Técnica de Engenharia',
        category: 'Engenharia',
        description: 'Visual blueprint/técnico com normas ABNT/Anatel, infraestrutura e cabeamento.',
        layoutType: 'blueprint',
        icon: Icons.architecture_rounded,
        defaultPrimaryColor: '#0284C7',
        illustrationKey: 'blueprint',
        defaultCards: [
          ProposalPageCard(id: 'c1', title: 'Conformidade com Normas ABNT NBR 5410', description: 'Projetos elétricos com disjuntores e DPS dedicados contra surtos elétricos e raios.', iconKey: 'bolt', colorHex: '#0284C7', order: 0),
          ProposalPageCard(id: 'c2', title: 'Tubulação Seca & Guia de Passagem', description: 'Diagrama unifilar detalhado fornecido para a equipe de obra seguir sem dúvidas.', iconKey: 'blueprint', colorHex: '#0284C7', order: 1),
          ProposalPageCard(id: 'c3', title: 'Quadro Central de Automação (QDA)', description: 'Montagem em barramentos metálicos com identificação a laser de cada circuito.', iconKey: 'shield', colorHex: '#0284C7', order: 2),
          ProposalPageCard(id: 'c4', title: 'Homologação e Garantia Técnica Integral', description: 'Testes de continuidade, isolamento e carga máxima com relatório final assinado.', iconKey: 'award', colorHex: '#0284C7', order: 3),
        ],
      ),

      // 18. Menu de Cenas Inteligentes
      ProposalPage2TemplateInfo(
        id: 'tpl_18_scenes_menu',
        title: '18. Menu de Cenas Inteligentes',
        category: 'Automação',
        description: 'Apresentação das cenas exclusivas (Cinema, Recepção, Viagem, Relax e Gourmet).',
        layoutType: 'scenesMenu',
        icon: Icons.movie_filter_rounded,
        defaultPrimaryColor: '#F59E0B',
        illustrationKey: 'isometric',
        defaultCards: [
          ProposalPageCard(id: 'c1', title: 'Cena "Cinema & Séries"', description: 'Luzes dimerizadas a 15%, persianas fechadas, projetor ligado e ar condicionado a 22ºC.', iconKey: 'music', colorHex: '#F59E0B', order: 0),
          ProposalPageCard(id: 'c2', title: 'Cena "Recepção de Amigos"', description: 'Iluminação cênica na sala e jardim com playlist animada no Spotify em todo o living.', iconKey: 'light', colorHex: '#F59E0B', order: 1),
          ProposalPageCard(id: 'c3', title: 'Cena "Boa Noite"', description: 'Um clique no interruptor ao lado da cama apaga todas as luzes da casa e tranca as portas.', iconKey: 'lock', colorHex: '#F59E0B', order: 2),
          ProposalPageCard(id: 'c4', title: 'Cena "Viagem Segura"', description: 'Fechamento do registro de gás, corte de tomadas em standby e ativação do alarme perimetral.', iconKey: 'shield', colorHex: '#F59E0B', order: 3),
        ],
      ),

      // 19. Sustentabilidade & Economia Verde (Eco / Solar)
      ProposalPage2TemplateInfo(
        id: 'tpl_19_green_efficiency',
        title: '19. Sustentabilidade & Economia Verde',
        category: 'Sustentabilidade',
        description: 'Foco verde esmeralda em preservação ambiental, eficiência energética e certificações.',
        layoutType: 'greenEco',
        icon: Icons.eco_rounded,
        defaultPrimaryColor: '#10B981',
        illustrationKey: 'greenEco',
        defaultCards: [
          ProposalPageCard(id: 'c1', title: 'Redução Direta da Pegada de Carbono', description: 'Menos toneladas de CO2 na atmosfera com energia solar e automação de consumo.', iconKey: 'eco', colorHex: '#10B981', order: 0),
          ProposalPageCard(id: 'c2', title: 'Aproveitamento Máximo da Luz Natural', description: 'Sensores crepusculares ajustam as lâmpadas conforme a entrada da claridade do sol.', iconKey: 'light', colorHex: '#10B981', order: 1),
          ProposalPageCard(id: 'c3', title: 'Monitoramento Gráfico em Tempo Real', description: 'Visualize no celular quantos kWh foram gerados e consumidos a cada minuto do dia.', iconKey: 'chart', colorHex: '#10B981', order: 2),
          ProposalPageCard(id: 'c4', title: 'Certificação Green Building / LEED', description: 'Sua residência elegível às mais prestigiadas certificações ecológicas mundiais.', iconKey: 'award', colorHex: '#10B981', order: 3),
        ],
      ),

      // 20. Sumário Executivo Compacto
      ProposalPage2TemplateInfo(
        id: 'tpl_20_compact_summary',
        title: '20. Sumário Executivo Compacto',
        category: 'Corporativo',
        description: 'Diagramação executiva com cards concisos, quadro de compromissos e selo de entrega.',
        layoutType: 'compactSummary',
        icon: Icons.article_rounded,
        defaultPrimaryColor: '#334155',
        illustrationKey: 'timeline',
        defaultCards: [
          ProposalPageCard(id: 'c1', title: 'Solução Turn-Key Integral', description: 'Fornecimento completo: equipamentos, cabeamento, projeto, programação e entrega.', iconKey: 'home', colorHex: '#334155', order: 0),
          ProposalPageCard(id: 'c2', title: 'Garantia de 3 Anos sem Custo Adicional', description: 'Cobertura completa contra defeitos de fabricação e suporte técnico prioritário.', iconKey: 'award', colorHex: '#334155', order: 1),
          ProposalPageCard(id: 'c3', title: 'Facilidade nas Condições de Pagamento', description: 'Parcelamento em até 120x com financiamento bancário aprovado em 15 minutos.', iconKey: 'coins', colorHex: '#334155', order: 2),
          ProposalPageCard(id: 'c4', title: 'Treinamento de Toda a Família', description: 'Apresentação prática e manual ilustrado com todos os passos de utilização.', iconKey: 'handshake', colorHex: '#334155', order: 3),
        ],
      ),
    ];
  }
}

/// Banco de Imagens Curado com 30 Fotos de Automação & 30 Fotos de Energia Solar
class CuratedProposalImage {
  final String id;
  final String title;
  final String category;
  final String url;
  final String? localAsset;

  const CuratedProposalImage({
    required this.id,
    required this.title,
    required this.category,
    required this.url,
    this.localAsset,
  });

  /// 30 Fotos Premium de Automação Residencial
  static List<CuratedProposalImage> getAutomationImages() {
    return const [
      CuratedProposalImage(
        id: 'auto_01',
        title: 'Mansão Contemporânea com Piscina',
        category: 'Fachadas',
        url: 'https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?auto=format&fit=crop&w=1200&q=80',
        localAsset: 'assets/images/capa/modelo_automacao_1.jpg',
      ),
      CuratedProposalImage(
        id: 'auto_02',
        title: 'Living Integrado & Iluminação Cênica',
        category: 'Interiores',
        url: 'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?auto=format&fit=crop&w=1200&q=80',
        localAsset: 'assets/images/capa/modelo_automacao_2.jpg',
      ),
      CuratedProposalImage(
        id: 'auto_03',
        title: 'Home Cinema & Som Surround',
        category: 'Home Theater',
        url: 'https://images.unsplash.com/photo-1593784991095-a205069470b6?auto=format&fit=crop&w=1200&q=80',
        localAsset: 'assets/images/capa/modelo_automacao_3.jpg',
      ),
      CuratedProposalImage(
        id: 'auto_04',
        title: 'Fachada Noturna com Automação de Luz',
        category: 'Fachadas',
        url: 'https://images.unsplash.com/photo-1512917774080-9991f1c4c750?auto=format&fit=crop&w=1200&q=80',
        localAsset: 'assets/images/capa/modelo_automacao_4.jpg',
      ),
      CuratedProposalImage(
        id: 'auto_05',
        title: 'Controle de Acesso & Fechadura Touch',
        category: 'Segurança',
        url: 'https://images.unsplash.com/photo-1558002038-1055907df827?auto=format&fit=crop&w=1200&q=80',
        localAsset: 'assets/images/capa/modelo_automacao_5.jpg',
      ),
      CuratedProposalImage(
        id: 'auto_06',
        title: 'Cozinha Gourmet Inteligente',
        category: 'Gourmet',
        url: 'https://images.unsplash.com/photo-1600565193348-f74bd3c7ccdf?auto=format&fit=crop&w=1200&q=80',
        localAsset: 'assets/images/capa/modelo_automacao_6.jpg',
      ),
      CuratedProposalImage(
        id: 'auto_07',
        title: 'Área da Piscina com Cenas de Relaxamento',
        category: 'Lazer',
        url: 'https://images.unsplash.com/photo-1580587771525-78b9dba3b914?auto=format&fit=crop&w=1200&q=80',
        localAsset: 'assets/images/capa/modelo_automacao_7.jpg',
      ),
      CuratedProposalImage(
        id: 'auto_08',
        title: 'Keypad de Luxo & Controle de Luzes',
        category: 'Dispositivos',
        url: 'https://images.unsplash.com/photo-1513694203232-719a280e022f?auto=format&fit=crop&w=1200&q=80',
        localAsset: 'assets/images/capa/modelo_automacao_8.jpg',
      ),
      CuratedProposalImage(
        id: 'auto_09',
        title: 'Suíte Master com Climatização & Cortinas',
        category: 'Interiores',
        url: 'https://images.unsplash.com/photo-1590490360182-c33d57733427?auto=format&fit=crop&w=1200&q=80',
        localAsset: 'assets/images/capa/modelo_automacao_9.jpg',
      ),
      CuratedProposalImage(
        id: 'auto_10',
        title: 'Penthouse Urbana com Automação Total',
        category: 'Fachadas',
        url: 'https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?auto=format&fit=crop&w=1200&q=80',
        localAsset: 'assets/images/capa/modelo_automacao_10.jpg',
      ),
      CuratedProposalImage(
        id: 'auto_11',
        title: 'Aplicativo Móvel com Painel de Controle',
        category: 'Dispositivos',
        url: 'https://images.unsplash.com/photo-1556742049-0a67c5574f73?auto=format&fit=crop&w=1200&q=80',
      ),
      CuratedProposalImage(
        id: 'auto_12',
        title: 'Jardim com Irrigação & Iluminação LED',
        category: 'Lazer',
        url: 'https://images.unsplash.com/photo-1584622650111-993a426fbf0a?auto=format&fit=crop&w=1200&q=80',
      ),
      CuratedProposalImage(
        id: 'auto_13',
        title: 'Varanda Integrada Noturna',
        category: 'Lazer',
        url: 'https://images.unsplash.com/photo-1513519245088-0e12902e5a38?auto=format&fit=crop&w=1200&q=80',
      ),
      CuratedProposalImage(
        id: 'auto_14',
        title: 'Sala de Estar Minimalista Escandinava',
        category: 'Interiores',
        url: 'https://images.unsplash.com/photo-1586023492125-27b2c045efd7?auto=format&fit=crop&w=1200&q=80',
      ),
      CuratedProposalImage(
        id: 'auto_15',
        title: 'Som Embutido no Teto de Gesso',
        category: 'Home Theater',
        url: 'https://images.unsplash.com/photo-1545454675-3531b543be5d?auto=format&fit=crop&w=1200&q=80',
      ),
      CuratedProposalImage(
        id: 'auto_16',
        title: 'Casa Inteligente em Madeira e Vidro',
        category: 'Fachadas',
        url: 'https://images.unsplash.com/photo-1518780664697-55e3ad937233?auto=format&fit=crop&w=1200&q=80',
      ),
      CuratedProposalImage(
        id: 'auto_17',
        title: 'Garagem com Carregador Veicular EV',
        category: 'Dispositivos',
        url: 'https://images.unsplash.com/photo-1563720223185-11003d516935?auto=format&fit=crop&w=1200&q=80',
      ),
      CuratedProposalImage(
        id: 'auto_18',
        title: 'Espaço Gourmet Climatizado',
        category: 'Gourmet',
        url: 'https://images.unsplash.com/photo-1556911220-e15b29be8c8f?auto=format&fit=crop&w=1200&q=80',
      ),
      CuratedProposalImage(
        id: 'auto_19',
        title: 'Lareira Automatizada na Sala',
        category: 'Interiores',
        url: 'https://images.unsplash.com/photo-1542314831-068cd1dbfeeb?auto=format&fit=crop&w=1200&q=80',
      ),
      CuratedProposalImage(
        id: 'auto_20',
        title: 'Quarto Inteligente com Cortina Rolô Motorizada',
        category: 'Interiores',
        url: 'https://images.unsplash.com/photo-1505693416388-ac5ce068fe85?auto=format&fit=crop&w=1200&q=80',
      ),
      CuratedProposalImage(
        id: 'auto_21',
        title: 'Rack de Automação & Cabeamento Estruturado',
        category: 'Engenharia',
        url: 'https://images.unsplash.com/photo-1558494949-ef010cbdcc31?auto=format&fit=crop&w=1200&q=80',
      ),
      CuratedProposalImage(
        id: 'auto_22',
        title: 'Hall de Entrada com Sensor de Presença',
        category: 'Segurança',
        url: 'https://images.unsplash.com/photo-1507089947368-19c1da9775ae?auto=format&fit=crop&w=1200&q=80',
      ),
      CuratedProposalImage(
        id: 'auto_23',
        title: 'Escada Escultural com Iluminação nos Degraus',
        category: 'Interiores',
        url: 'https://images.unsplash.com/photo-1600607687939-ce8a6c25118c?auto=format&fit=crop&w=1200&q=80',
      ),
      CuratedProposalImage(
        id: 'auto_24',
        title: 'Piscina Iluminada com LEDs Subaquáticos RGB',
        category: 'Lazer',
        url: 'https://images.unsplash.com/photo-1576013551627-0cc20b96c2a7?auto=format&fit=crop&w=1200&q=80',
      ),
      CuratedProposalImage(
        id: 'auto_25',
        title: 'Tablet de Parede com Interface de Automação',
        category: 'Dispositivos',
        url: 'https://images.unsplash.com/photo-1544244015-0df4b3ffc6b0?auto=format&fit=crop&w=1200&q=80',
      ),
      CuratedProposalImage(
        id: 'auto_26',
        title: 'Adega Climatizada com Sensor de Temperatura',
        category: 'Gourmet',
        url: 'https://images.unsplash.com/photo-1510812431401-41d2bd2722f3?auto=format&fit=crop&w=1200&q=80',
      ),
      CuratedProposalImage(
        id: 'auto_27',
        title: 'Câmera Dome Noturna de Alta Resolução',
        category: 'Segurança',
        url: 'https://images.unsplash.com/photo-1557597774-9d273605dfa9?auto=format&fit=crop&w=1200&q=80',
      ),
      CuratedProposalImage(
        id: 'auto_28',
        title: 'Home Office Inteligente e Conectado',
        category: 'Interiores',
        url: 'https://images.unsplash.com/photo-1524758631624-e2822e304c36?auto=format&fit=crop&w=1200&q=80',
      ),
      CuratedProposalImage(
        id: 'auto_29',
        title: 'Roteador Wi-Fi 6 Mesh Alta Performance',
        category: 'Engenharia',
        url: 'https://images.unsplash.com/photo-1544197150-b99a580bb7a8?auto=format&fit=crop&w=1200&q=80',
      ),
      CuratedProposalImage(
        id: 'auto_30',
        title: 'Mansão Futurista Noturna',
        category: 'Fachadas',
        url: 'https://images.unsplash.com/photo-1512915922686-57c11dde9b6b?auto=format&fit=crop&w=1200&q=80',
      ),
    ];
  }

  /// 30 Fotos Premium de Energia Solar Fotovoltaica
  static List<CuratedProposalImage> getSolarImages() {
    return const [
      CuratedProposalImage(
        id: 'solar_01',
        title: 'Telhado Residencial Alto Padrão com Painéis',
        category: 'Residencial',
        url: 'https://images.unsplash.com/photo-1508873696983-2df5293cb325?auto=format&fit=crop&w=1200&q=80',
        localAsset: 'assets/images/capa/modelo_solar_1.jpg',
      ),
      CuratedProposalImage(
        id: 'solar_02',
        title: 'Usina Solar em Solo ao Pôr do Sol',
        category: 'Usina de Solo',
        url: 'https://images.unsplash.com/photo-1509391365360-2e959784a276?auto=format&fit=crop&w=1200&q=80',
        localAsset: 'assets/images/capa/modelo_solar_2.jpg',
      ),
      CuratedProposalImage(
        id: 'solar_03',
        title: 'Galpão Industrial com Usina Fotovoltaica',
        category: 'Comercial',
        url: 'https://images.unsplash.com/photo-1497440001374-f26997328c1b?auto=format&fit=crop&w=1200&q=80',
        localAsset: 'assets/images/capa/modelo_solar_3.jpg',
      ),
      CuratedProposalImage(
        id: 'solar_04',
        title: 'Módulos Fotovoltaicos em Alta Definição',
        category: 'Equipamentos',
        url: 'https://images.unsplash.com/photo-1545208942-e1c9c916524b?auto=format&fit=crop&w=1200&q=80',
        localAsset: 'assets/images/capa/modelo_solar_4.jpg',
      ),
      CuratedProposalImage(
        id: 'solar_05',
        title: 'Inversor Solar Inteligente com Monitoramento',
        category: 'Equipamentos',
        url: 'https://images.unsplash.com/photo-1558441719-8b489c63f7ce?auto=format&fit=crop&w=1200&q=80',
        localAsset: 'assets/images/capa/modelo_solar_5.jpg',
      ),
      CuratedProposalImage(
        id: 'solar_06',
        title: 'Fazenda Solar no Campo',
        category: 'Usina de Solo',
        url: 'https://images.unsplash.com/photo-1521618755572-156ae0cdd74d?auto=format&fit=crop&w=1200&q=80',
        localAsset: 'assets/images/capa/modelo_solar_6.jpg',
      ),
      CuratedProposalImage(
        id: 'solar_07',
        title: 'Carport Solar (Garagem Fotovoltaica)',
        category: 'Comercial',
        url: 'https://images.unsplash.com/photo-1548611716-ad78255959f8?auto=format&fit=crop&w=1200&q=80',
        localAsset: 'assets/images/capa/modelo_solar_7.jpg',
      ),
      CuratedProposalImage(
        id: 'solar_08',
        title: 'Instalação Técnica de Módulos no Telhado',
        category: 'Instalação',
        url: 'https://images.unsplash.com/photo-1613665813446-82a78c468a1d?auto=format&fit=crop&w=1200&q=80',
        localAsset: 'assets/images/capa/modelo_solar_8.jpg',
      ),
      CuratedProposalImage(
        id: 'solar_09',
        title: 'Painéis Monocristalinos N-Type',
        category: 'Equipamentos',
        url: 'https://images.unsplash.com/photo-1545208942-e1c9c916524b?auto=format&fit=crop&w=1200&q=80',
        localAsset: 'assets/images/capa/modelo_solar_9.jpg',
      ),
      CuratedProposalImage(
        id: 'solar_10',
        title: 'Vista Aérea com Drone de Usina Solar',
        category: 'Usina de Solo',
        url: 'https://images.unsplash.com/photo-1508873696983-2df5293cb325?auto=format&fit=crop&w=1200&q=80',
        localAsset: 'assets/images/capa/modelo_solar_10.jpg',
      ),
      CuratedProposalImage(
        id: 'solar_11',
        title: 'Residência Sustentável com Telhado Cerâmico',
        category: 'Residencial',
        url: 'https://images.unsplash.com/photo-1513694203232-719a280e022f?auto=format&fit=crop&w=1200&q=80',
      ),
      CuratedProposalImage(
        id: 'solar_12',
        title: 'Bateria Solar de Armazenamento Lítio',
        category: 'Equipamentos',
        url: 'https://images.unsplash.com/photo-1558441719-8b489c63f7ce?auto=format&fit=crop&w=1200&q=80',
      ),
      CuratedProposalImage(
        id: 'solar_13',
        title: 'Supermercado com Cobertura Fotovoltaica',
        category: 'Comercial',
        url: 'https://images.unsplash.com/photo-1497440001374-f26997328c1b?auto=format&fit=crop&w=1200&q=80',
      ),
      CuratedProposalImage(
        id: 'solar_14',
        title: 'Usina Flutuante em Represa',
        category: 'Usina de Solo',
        url: 'https://images.unsplash.com/photo-1509391365360-2e959784a276?auto=format&fit=crop&w=1200&q=80',
      ),
      CuratedProposalImage(
        id: 'solar_15',
        title: 'Engenheiro com EPI Inspecionando Instalação',
        category: 'Instalação',
        url: 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?auto=format&fit=crop&w=1200&q=80',
      ),
      CuratedProposalImage(
        id: 'solar_16',
        title: 'Telhado Metálico Trapezoidal com Painéis',
        category: 'Comercial',
        url: 'https://images.unsplash.com/photo-1508873696983-2df5293cb325?auto=format&fit=crop&w=1200&q=80',
      ),
      CuratedProposalImage(
        id: 'solar_17',
        title: 'App Solar com Gráfico de Geração e Economia',
        category: 'Equipamentos',
        url: 'https://images.unsplash.com/photo-1551288049-bebda4e38f71?auto=format&fit=crop&w=1200&q=80',
      ),
      CuratedProposalImage(
        id: 'solar_18',
        title: 'Agro Solar no Campo com Plantio',
        category: 'Usina de Solo',
        url: 'https://images.unsplash.com/photo-1521618755572-156ae0cdd74d?auto=format&fit=crop&w=1200&q=80',
      ),
      CuratedProposalImage(
        id: 'solar_19',
        title: 'String Box & Proteções Elétricas CC/CA',
        category: 'Equipamentos',
        url: 'https://images.unsplash.com/photo-1558494949-ef010cbdcc31?auto=format&fit=crop&w=1200&q=80',
      ),
      CuratedProposalImage(
        id: 'solar_20',
        title: 'Casa de Praia Moderna com Painéis Solares',
        category: 'Residencial',
        url: 'https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?auto=format&fit=crop&w=1200&q=80',
      ),
      CuratedProposalImage(
        id: 'solar_21',
        title: 'Parque Solar com Rastreador (Tracker)',
        category: 'Usina de Solo',
        url: 'https://images.unsplash.com/photo-1466611653911-95081537e5b7?auto=format&fit=crop&w=1200&q=80',
      ),
      CuratedProposalImage(
        id: 'solar_22',
        title: 'Posto de Combustíveis com Carport Solar',
        category: 'Comercial',
        url: 'https://images.unsplash.com/photo-1548611716-ad78255959f8?auto=format&fit=crop&w=1200&q=80',
      ),
      CuratedProposalImage(
        id: 'solar_23',
        title: 'Linha de Módulos Fotovoltaicos em Céu Azul',
        category: 'Equipamentos',
        url: 'https://images.unsplash.com/photo-1509391365360-2e959784a276?auto=format&fit=crop&w=1200&q=80',
      ),
      CuratedProposalImage(
        id: 'solar_24',
        title: 'Indústria com Zero Emissão de Carbono',
        category: 'Comercial',
        url: 'https://images.unsplash.com/photo-1497440001374-f26997328c1b?auto=format&fit=crop&w=1200&q=80',
      ),
      CuratedProposalImage(
        id: 'solar_25',
        title: 'Condomínio Fechado Solar',
        category: 'Residencial',
        url: 'https://images.unsplash.com/photo-1512917774080-9991f1c4c750?auto=format&fit=crop&w=1200&q=80',
      ),
      CuratedProposalImage(
        id: 'solar_26',
        title: 'Quadro Geral de Baixa Tensão QGBT',
        category: 'Instalação',
        url: 'https://images.unsplash.com/photo-1558494949-ef010cbdcc31?auto=format&fit=crop&w=1200&q=80',
      ),
      CuratedProposalImage(
        id: 'solar_27',
        title: 'Módulos Bifaciais com Reflexo do Solo',
        category: 'Equipamentos',
        url: 'https://images.unsplash.com/photo-1545208942-e1c9c916524b?auto=format&fit=crop&w=1200&q=80',
      ),
      CuratedProposalImage(
        id: 'solar_28',
        title: 'Hotel Fazenda com Energia Limpa',
        category: 'Comercial',
        url: 'https://images.unsplash.com/photo-1580587771525-78b9dba3b914?auto=format&fit=crop&w=1200&q=80',
      ),
      CuratedProposalImage(
        id: 'solar_29',
        title: 'Pôr do Sol Dourado Refletindo nas Células Solares',
        category: 'Usina de Solo',
        url: 'https://images.unsplash.com/photo-1508873696983-2df5293cb325?auto=format&fit=crop&w=1200&q=80',
      ),
      CuratedProposalImage(
        id: 'solar_30',
        title: 'Sede Corporativa Sustentável LEED Platinum',
        category: 'Comercial',
        url: 'https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?auto=format&fit=crop&w=1200&q=80',
      ),
    ];
  }
}

/// 20 Presets Completos de Layout das Páginas Internas (Cabeçalho, Rodapé, Cores e Tipografia)
class InternalPagesLayoutPreset {
  final String id;
  final String title;
  final String subtitle;
  final int headerStyle;
  final int footerStyle;
  final String primaryColorHex;
  final String headerBgColorHex;
  final String headerTextColorHex;
  final String footerBgColorHex;
  final String footerTextColorHex;

  const InternalPagesLayoutPreset({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.headerStyle,
    required this.footerStyle,
    required this.primaryColorHex,
    required this.headerBgColorHex,
    required this.headerTextColorHex,
    required this.footerBgColorHex,
    required this.footerTextColorHex,
  });

  static List<InternalPagesLayoutPreset> getAllPresets() {
    return const [
      InternalPagesLayoutPreset(
        id: 'preset_01',
        title: 'Minimalista Corporativo',
        subtitle: 'Bordas sutis cinza e destaque sutil',
        headerStyle: 1,
        footerStyle: 1,
        primaryColorHex: '#0284C7',
        headerBgColorHex: '#FFFFFF',
        headerTextColorHex: '#0F172A',
        footerBgColorHex: '#0F172A',
        footerTextColorHex: '#FFFFFF',
      ),
      InternalPagesLayoutPreset(
        id: 'preset_02',
        title: 'Dark Cyber Blue',
        subtitle: 'Fundo Dark Slate e acentos neon',
        headerStyle: 4,
        footerStyle: 4,
        primaryColorHex: '#38BDF8',
        headerBgColorHex: '#0F172A',
        headerTextColorHex: '#FFFFFF',
        footerBgColorHex: '#0B1120',
        footerTextColorHex: '#38BDF8',
      ),
      InternalPagesLayoutPreset(
        id: 'preset_03',
        title: 'Emerald Clean Tech',
        subtitle: 'Elegância em verde esmeralda sustentável',
        headerStyle: 2,
        footerStyle: 2,
        primaryColorHex: '#10B981',
        headerBgColorHex: '#ECFDF5',
        headerTextColorHex: '#064E3B',
        footerBgColorHex: '#064E3B',
        footerTextColorHex: '#FFFFFF',
      ),
      InternalPagesLayoutPreset(
        id: 'preset_04',
        title: 'Luxury Gold & Black',
        subtitle: 'Sofisticação clássica ouro e grafite',
        headerStyle: 3,
        footerStyle: 3,
        primaryColorHex: '#D97706',
        headerBgColorHex: '#1C1917',
        headerTextColorHex: '#FDE68A',
        footerBgColorHex: '#1C1917',
        footerTextColorHex: '#F59E0B',
      ),
      InternalPagesLayoutPreset(
        id: 'preset_05',
        title: 'Azul Real Corporativo',
        subtitle: 'Confiança e solidez institucional',
        headerStyle: 5,
        footerStyle: 5,
        primaryColorHex: '#2563EB',
        headerBgColorHex: '#1E3A8A',
        headerTextColorHex: '#FFFFFF',
        footerBgColorHex: '#172554',
        footerTextColorHex: '#DBEAFE',
      ),
      InternalPagesLayoutPreset(
        id: 'preset_06',
        title: 'Industrial Slate',
        subtitle: 'Linhas técnicas e contraste neutro',
        headerStyle: 6,
        footerStyle: 6,
        primaryColorHex: '#475569',
        headerBgColorHex: '#F1F5F9',
        headerTextColorHex: '#0F172A',
        footerBgColorHex: '#334155',
        footerTextColorHex: '#F8FAFC',
      ),
      InternalPagesLayoutPreset(
        id: 'preset_07',
        title: 'Ciano Alta Conexão',
        subtitle: 'Vibrante, tecnológico e clean',
        headerStyle: 7,
        footerStyle: 7,
        primaryColorHex: '#06B6D4',
        headerBgColorHex: '#E0F2FE',
        headerTextColorHex: '#0369A1',
        footerBgColorHex: '#083344',
        footerTextColorHex: '#67E8F9',
      ),
      InternalPagesLayoutPreset(
        id: 'preset_08',
        title: 'Glassmorphism White',
        subtitle: 'Transparências com sombra fina',
        headerStyle: 8,
        footerStyle: 8,
        primaryColorHex: '#6366F1',
        headerBgColorHex: '#FAFAFA',
        headerTextColorHex: '#1E1B4B',
        footerBgColorHex: '#312E81',
        footerTextColorHex: '#E0E7FF',
      ),
      InternalPagesLayoutPreset(
        id: 'preset_09',
        title: 'Violet Tech Vision',
        subtitle: 'Identidade futurista em roxo/índigo',
        headerStyle: 9,
        footerStyle: 9,
        primaryColorHex: '#8B5CF6',
        headerBgColorHex: '#F5F3FF',
        headerTextColorHex: '#4C1D95',
        footerBgColorHex: '#2E1065',
        footerTextColorHex: '#DDD6FE',
      ),
      InternalPagesLayoutPreset(
        id: 'preset_10',
        title: 'Sunset Amber Solar',
        subtitle: 'Calor e energia vibrante',
        headerStyle: 10,
        footerStyle: 10,
        primaryColorHex: '#F59E0B',
        headerBgColorHex: '#FEF3C7',
        headerTextColorHex: '#78350F',
        footerBgColorHex: '#451A03',
        footerTextColorHex: '#FCD34D',
      ),
      InternalPagesLayoutPreset(
        id: 'preset_11',
        title: 'Nordic Clean Light',
        subtitle: 'Simplicidade nórdica com muito espaço',
        headerStyle: 1,
        footerStyle: 2,
        primaryColorHex: '#64748B',
        headerBgColorHex: '#FFFFFF',
        headerTextColorHex: '#334155',
        footerBgColorHex: '#F8FAFC',
        footerTextColorHex: '#475569',
      ),
      InternalPagesLayoutPreset(
        id: 'preset_12',
        title: 'Navy Blue & Orange',
        subtitle: 'Contraste esportivo e de alta energia',
        headerStyle: 3,
        footerStyle: 5,
        primaryColorHex: '#EA580C',
        headerBgColorHex: '#0F172A',
        headerTextColorHex: '#FB923C',
        footerBgColorHex: '#0C4A6E',
        footerTextColorHex: '#FFEDD5',
      ),
      InternalPagesLayoutPreset(
        id: 'preset_13',
        title: 'Cobalto High-End',
        subtitle: 'Azul cobalto profundo com branco',
        headerStyle: 4,
        footerStyle: 1,
        primaryColorHex: '#1D4ED8',
        headerBgColorHex: '#1E40AF',
        headerTextColorHex: '#FFFFFF',
        footerBgColorHex: '#172554',
        footerTextColorHex: '#FFFFFF',
      ),
      InternalPagesLayoutPreset(
        id: 'preset_14',
        title: 'Ecológico Floresta',
        subtitle: 'Verde musgo orgânico e suave',
        headerStyle: 2,
        footerStyle: 6,
        primaryColorHex: '#059669',
        headerBgColorHex: '#F0FDF4',
        headerTextColorHex: '#14532D',
        footerBgColorHex: '#14532D',
        footerTextColorHex: '#DCFCE7',
      ),
      InternalPagesLayoutPreset(
        id: 'preset_15',
        title: 'Titânio & Prata',
        subtitle: 'Estilo metálico sóbrio e refinado',
        headerStyle: 5,
        footerStyle: 4,
        primaryColorHex: '#334155',
        headerBgColorHex: '#E2E8F0',
        headerTextColorHex: '#0F172A',
        footerBgColorHex: '#1E293B',
        footerTextColorHex: '#CBD5E1',
      ),
      InternalPagesLayoutPreset(
        id: 'preset_16',
        title: 'Rubi Corporativo',
        subtitle: 'Destaques em vermelho carmim premium',
        headerStyle: 7,
        footerStyle: 3,
        primaryColorHex: '#E11D48',
        headerBgColorHex: '#FFF1F2',
        headerTextColorHex: '#881337',
        footerBgColorHex: '#4C0519',
        footerTextColorHex: '#FECDD3',
      ),
      InternalPagesLayoutPreset(
        id: 'preset_17',
        title: 'Modern Monochromatic',
        subtitle: 'Escala de cinza elegante e atemporal',
        headerStyle: 8,
        footerStyle: 7,
        primaryColorHex: '#18181B',
        headerBgColorHex: '#F4F4F5',
        headerTextColorHex: '#18181B',
        footerBgColorHex: '#18181B',
        footerTextColorHex: '#F4F4F5',
      ),
      InternalPagesLayoutPreset(
        id: 'preset_18',
        title: 'Teal Futurista',
        subtitle: 'Verde petróleo moderno com ciano',
        headerStyle: 9,
        footerStyle: 8,
        primaryColorHex: '#0D9488',
        headerBgColorHex: '#CCFBF1',
        headerTextColorHex: '#115E59',
        footerBgColorHex: '#134E4A',
        footerTextColorHex: '#5EEAD4',
      ),
      InternalPagesLayoutPreset(
        id: 'preset_19',
        title: 'Royal Indigo Gold',
        subtitle: 'Púrpura real com acentos dourados',
        headerStyle: 10,
        footerStyle: 9,
        primaryColorHex: '#4F46E5',
        headerBgColorHex: '#312E81',
        headerTextColorHex: '#FCD34D',
        footerBgColorHex: '#1E1B4B',
        footerTextColorHex: '#FCD34D',
      ),
      InternalPagesLayoutPreset(
        id: 'preset_20',
        title: 'Carvão & Limão Elétrico',
        subtitle: 'Super moderno com contraste esportivo',
        headerStyle: 4,
        footerStyle: 10,
        primaryColorHex: '#84CC16',
        headerBgColorHex: '#18181B',
        headerTextColorHex: '#A3E635',
        footerBgColorHex: '#09090B',
        footerTextColorHex: '#BEF264',
      ),
    ];
  }
}
