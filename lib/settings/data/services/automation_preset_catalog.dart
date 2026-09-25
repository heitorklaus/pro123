import '../../domain/models/automation_settings_model.dart';

/// Modelo de Item da Galeria de Presets de Capa PDF de Automação
class AutomationPresetItem {
  final String id;
  final String title;
  final String subtitle;
  final String imageUrl;
  final String primaryColorHex;
  final String coverTag;
  final String headline;
  final String subheadline;
  final String category; // 'Cyber Mansion' ou 'Cyber Divider'
  final bool isFullPhoto;
  final int customDividerStyle; // 0 a 9
  final List<AutomationCyberNode> defaultNodes;

  const AutomationPresetItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    this.primaryColorHex = '#38BDF8',
    this.coverTag = 'PROPOSTA / 2026',
    this.headline = 'A casa que entende você.',
    this.subheadline = 'Arquitetura, conforto e tecnologia integrados em uma experiência única.',
    this.category = 'Cyber Mansion',
    this.isFullPhoto = true,
    this.customDividerStyle = -1,
    this.defaultNodes = const [],
  });
}

/// Catálogo dos Presets de Capa de Proposta PDF do Ramo de Automação Residencial (Categorias Cyber Mansion & Cyber Divider)
class AutomationPresetCatalog {
  static final List<String> _mansionImages = List.generate(100, (i) => 'modelo_automacao_${i + 1}.jpg');
  static final List<String> _dividerImages = List.generate(100, (i) => 'modelo_automacao_${i + 1}.jpg');

  static List<AutomationPresetItem> _allPresets = [];

  static List<AutomationPresetItem> getAllPresets() {
    _allPresets = [];

    final List<AutomationPresetItem> list = [];

    // -------------------------------------------------------------
    // 🏛️ CATEGORIA 1: CYBER MANSION (100 Capas Noturnas com Nós Cibernéticos)
    // -------------------------------------------------------------
    list.add(
      const AutomationPresetItem(
        id: 'auto_cover_01',
        title: 'ARBO Mansion High-Tech',
        subtitle: 'Modelo Referência Cyber Mansion Noturno',
        imageUrl: 'modelo_automacao_1.jpg',
        primaryColorHex: '#38BDF8',
        coverTag: 'PROPOSTA / 2026',
        headline: 'A casa que entende você.',
        subheadline: 'Arquitetura, conforto e tecnologia integrados em uma experiência única.',
        category: 'Cyber Mansion',
        isFullPhoto: true,
        customDividerStyle: -1,
        defaultNodes: [
          AutomationCyberNode(id: 'n1', label: 'Iluminação Cênica', iconName: 'light', posX: 0.54, posY: 0.31, targetX: 0.50, targetY: 0.35, colorHex: '#38BDF8'),
          AutomationCyberNode(id: 'n2', label: 'Áudio Multiroom', iconName: 'music', posX: 0.40, posY: 0.52, targetX: 0.38, targetY: 0.58, colorHex: '#38BDF8'),
          AutomationCyberNode(id: 'n3', label: 'Climatização HVAC', iconName: 'temp', posX: 0.93, posY: 0.29, targetX: 0.88, targetY: 0.32, colorHex: '#38BDF8'),
          AutomationCyberNode(id: 'n4', label: 'Monitoramento AI', iconName: 'camera', posX: 0.94, posY: 0.46, targetX: 0.90, targetY: 0.48, colorHex: '#38BDF8'),
          AutomationCyberNode(id: 'n5', label: 'Controle de Acesso', iconName: 'lock', posX: 0.78, posY: 0.58, targetX: 0.76, targetY: 0.62, colorHex: '#38BDF8'),
        ],
      ),
    );

    final mansionTitles = [
      'Villa Noturna com Piscina', 'Mansão Contemporânea Glasshouse', 'Pátio com Vidros Panorâmicos',
      'Living Noturno com Iluminação Cênica', 'Espaço Gourmet & Som Surround', 'Fachada Iluminada High-End',
      'Home Cinema Imersivo Dolby Atmos', 'Suíte Master com Climatização IA', 'Jardim de Inverno com Cenas Ilum',
      'Piscina Aquecida Noturna', 'Hall de Entrada Imponente', 'Escada Suspensa com Led Oculto',
    ];

    final colors = ['#38BDF8', '#2563EB', '#10B981', '#F59E0B', '#EF4444', '#8B5CF6'];

    for (int i = 2; i <= 100; i++) {
      final img = _mansionImages[(i - 1) % _mansionImages.length];
      final title = mansionTitles[(i - 1) % mansionTitles.length];
      final color = colors[(i - 1) % colors.length];

      list.add(
        AutomationPresetItem(
          id: 'auto_cover_${i < 10 ? '0$i' : i}',
          title: 'Capa Automação #$i — $title',
          subtitle: 'Layout Cyber Noturno A4 High-End',
          imageUrl: img,
          primaryColorHex: color,
          coverTag: 'PROPOSTA / 2026',
          headline: 'Tecnologia que Transforma Ambientes.',
          subheadline: 'Projeto de automação sob medida com iluminação, áudio e climatização integrados.',
          category: 'Cyber Mansion',
          isFullPhoto: true,
          customDividerStyle: -1,
          defaultNodes: [
            AutomationCyberNode(id: 'n1_$i', label: 'Iluminação Cênica', iconName: 'light', posX: 0.50, posY: 0.32, targetX: 0.48, targetY: 0.35, colorHex: color),
            AutomationCyberNode(id: 'n2_$i', label: 'Áudio Multiroom', iconName: 'music', posX: 0.38, posY: 0.50, targetX: 0.36, targetY: 0.55, colorHex: color),
            AutomationCyberNode(id: 'n3_$i', label: 'Climatização HVAC', iconName: 'temp', posX: 0.88, posY: 0.30, targetX: 0.85, targetY: 0.33, colorHex: color),
            AutomationCyberNode(id: 'n4_$i', label: 'Controle de Acesso', iconName: 'lock', posX: 0.75, posY: 0.60, targetX: 0.72, targetY: 0.64, colorHex: color),
          ],
        ),
      );
    }

    // -------------------------------------------------------------
    // 🎨 CATEGORIA 2: CYBER DIVIDER (100 Capas com Separadores & Decalques Matemáticos)
    // -------------------------------------------------------------
    final dividerTitles = [
      'Onda Suave S-Curve High-Tech', 'Onda Dupla Harmônica', 'Corte Diagonal Cyber Sharp',
      'Chevron Facetado Geométrico', 'Arco Aerodinâmico Côncavo', 'Declive Arquitetônico Solar',
      'Trapezoidal High-End Luxo', 'Split Vertical Sólido Tech', 'Curva Senoidal Tripla',
      'Bloco Minimalista Clean',
    ];

    for (int i = 101; i <= 200; i++) {
      final idx = i - 101;
      final img = _dividerImages[idx % _dividerImages.length];
      final style = idx % 10;
      final title = dividerTitles[style];
      final color = colors[idx % colors.length];

      list.add(
        AutomationPresetItem(
          id: 'auto_divider_${i - 100 < 10 ? '0${i - 100}' : i - 100}',
          title: 'Capa Separador #${i - 100} — $title',
          subtitle: 'Design Geométrico A4 em Decalque',
          imageUrl: img,
          primaryColorHex: color,
          coverTag: 'PROPOSTA DE AUTOMAÇÃO',
          headline: 'CONFORTO & INTELIGÊNCIA',
          subheadline: 'Engenharia de precisão e design minimalista em automação.',
          category: 'Cyber Divider',
          isFullPhoto: false,
          customDividerStyle: style,
          defaultNodes: const [],
        ),
      );
    }

    _allPresets = list;
    return _allPresets;
  }

  static List<AutomationPresetItem> getPresetsByCategory(String category) {
    return getAllPresets().where((p) => p.category == category).toList();
  }

  static AutomationPresetItem getPresetById(String id) {
    final all = getAllPresets();
    return all.firstWhere(
      (p) => p.id == id,
      orElse: () => all.first,
    );
  }
}
