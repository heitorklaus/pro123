import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'automation_preview_bridge.dart';
import 'glb_model_viewer_widget.dart';

/// Modelo de Preset para os 10 Backgrounds de Residências em Alpha
class ProposalBackgroundPreset {
  final String id;
  final String title;
  final String subtitle;
  final String imageUrl;

  const ProposalBackgroundPreset({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
  });
}

/// 10 Modelos Oficiais de Background Noturno de Mansões em Alpha
const List<ProposalBackgroundPreset> kDefaultProposalBackgrounds = [
  ProposalBackgroundPreset(
    id: 'bg_villa_pool',
    title: 'Mansão Noturna com Piscina',
    subtitle: 'Iluminação cênica e reflexo na água',
    imageUrl: 'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?auto=format&fit=crop&w=1920&q=80',
  ),
  ProposalBackgroundPreset(
    id: 'bg_architectural_estate',
    title: 'Residência Contemporânea de Luxo',
    subtitle: 'Arquitetura moderna com vidros e concreto',
    imageUrl: 'https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?auto=format&fit=crop&w=1920&q=80',
  ),
  ProposalBackgroundPreset(
    id: 'bg_glass_patio',
    title: 'Mansão Glasshouse Integrada',
    subtitle: 'Pátio interno e vidros panorâmicos',
    imageUrl: 'https://images.unsplash.com/photo-1600607687939-ce8a6c25118c?auto=format&fit=crop&w=1920&q=80',
  ),
  ProposalBackgroundPreset(
    id: 'bg_minimalist_white',
    title: 'Villa Minimalista Noturna',
    subtitle: 'Linhas retas e iluminação indireta',
    imageUrl: 'https://images.unsplash.com/photo-1512917774080-9991f1c4c750?auto=format&fit=crop&w=1920&q=80',
  ),
  ProposalBackgroundPreset(
    id: 'bg_forest_mansion',
    title: 'Mansão Bosque Privativo',
    subtitle: 'Paisagismo exuberante e atmosfera acolhedora',
    imageUrl: 'https://images.unsplash.com/photo-1613490493576-7fde63acd811?auto=format&fit=crop&w=1920&q=80',
  ),
  ProposalBackgroundPreset(
    id: 'bg_concrete_wood',
    title: 'Casa Concreto, Madeira & Luz',
    subtitle: 'Design biofílico e iluminação inteligente',
    imageUrl: 'https://images.unsplash.com/photo-1580587771525-78b9dba3b914?auto=format&fit=crop&w=1920&q=80',
  ),
  ProposalBackgroundPreset(
    id: 'bg_blueprint_estate',
    title: 'Blueprint Arquitetônico Dark',
    subtitle: 'Linhas técnicas e plantas de engenharia',
    imageUrl: 'https://images.unsplash.com/photo-1600566753376-12c8ab7fb75b?auto=format&fit=crop&w=1920&q=80',
  ),
  ProposalBackgroundPreset(
    id: 'bg_poolside_dusk',
    title: 'Lounge Piscina & Crepúsculo',
    subtitle: 'Lazer e automação de áreas externas',
    imageUrl: 'https://images.unsplash.com/photo-1600573472591-ee6b68d14c68?auto=format&fit=crop&w=1920&q=80',
  ),
  ProposalBackgroundPreset(
    id: 'bg_warm_interior_glow',
    title: 'Smart Villa Iluminação Quente',
    subtitle: 'Destaque para automação dimerizável',
    imageUrl: 'https://images.unsplash.com/photo-1600585154526-990dced4db0d?auto=format&fit=crop&w=1920&q=80',
  ),
  ProposalBackgroundPreset(
    id: 'bg_grand_estate_twilight',
    title: 'Grand Estate Alto Padrão',
    subtitle: 'Fachada imponente e segurança perimetral',
    imageUrl: 'https://images.unsplash.com/photo-1570129477492-45c003edd2be?auto=format&fit=crop&w=1920&q=80',
  ),
];

/// Modelos de Casa 3D / Fachadas
class ProposalHouseModelPreset {
  final String id;
  final String title;
  final String imageUrl;
  final String? glbUrl;

  const ProposalHouseModelPreset({
    required this.id,
    required this.title,
    required this.imageUrl,
    this.glbUrl,
  });
}

const List<ProposalHouseModelPreset> kDefaultHousePresets = [
  ProposalHouseModelPreset(
    id: 'house_official_3d',
    title: 'Mansão Smart Villa 3D (Oficial)',
    imageUrl: 'assets/images/smart_home_hero.jpg',
  ),
  ProposalHouseModelPreset(
    id: 'house_modern_cube',
    title: 'Residência Cubos Contemporânea',
    imageUrl: 'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?auto=format&fit=crop&w=1200&q=80',
  ),
  ProposalHouseModelPreset(
    id: 'house_minimalist',
    title: 'Villa Minimalista Telhado Plano',
    imageUrl: 'https://images.unsplash.com/photo-1512917774080-9991f1c4c750?auto=format&fit=crop&w=1200&q=80',
  ),
  ProposalHouseModelPreset(
    id: 'house_glasshouse',
    title: 'Casa de Luxo Fachada em Vidro',
    imageUrl: 'https://images.unsplash.com/photo-1600607687939-ce8a6c25118c?auto=format&fit=crop&w=1200&q=80',
  ),
];

/// Configuração visual completa da Proposta Web de Automação
class AutomationProposalThemeConfig {
  final Color primaryColor;
  final String heroImageUrl;
  final String? glbModelUrl;
  final String? glbFileName;
  final bool hasGlbModel;
  final double glbScale;
  final double glbOrbitTheta;
  final double glbOrbitPhi;
  final bool glbAutoRotate;
  final String backgroundImageUrl;
  final double backgroundAlpha;
  final String titlePrefix;
  final String titleHighlight;
  final String tagline;
  final String description;
  final List<String> highlights;
  final String footerTagline;

  const AutomationProposalThemeConfig({
    this.primaryColor = const Color(0xFF00E5FF), // Ciano neon da referência
    this.heroImageUrl = 'assets/images/smart_home_hero.jpg',
    this.glbModelUrl,
    this.glbFileName,
    this.hasGlbModel = false,
    this.glbScale = 1.2,
    this.glbOrbitTheta = 45.0,
    this.glbOrbitPhi = 65.0,
    this.glbAutoRotate = true,
    this.backgroundImageUrl = 'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?auto=format&fit=crop&w=1920&q=80',
    this.backgroundAlpha = 0.40,
    this.titlePrefix = 'Residência',
    this.titleHighlight = 'Família Klaus',
    this.tagline = 'Uma casa que entende você.',
    this.description = 'Explore cada ambiente e descubra como a tecnologia transforma conforto, segurança e experiências.',
    this.highlights = const [
      'Mais conforto',
      'Mais segurança',
      'Mais eficiência',
      'Mais momentos',
    ],
    this.footerTagline = 'TECNOLOGIA A SERVIÇO DA SUA MELHOR VIDA',
  });

  /// Getter de título completo montado
  String get fullTitle => '$titlePrefix $titleHighlight'.trim();

  /// Verifica se possui um modelo 3D válido associado
  bool get hasValidGlb =>
      (glbModelUrl != null && glbModelUrl!.trim().isNotEmpty && !glbModelUrl!.startsWith('indexeddb:')) ||
      hasGlbModel;

  AutomationProposalThemeConfig copyWith({
    Color? primaryColor,
    String? heroImageUrl,
    String? glbModelUrl,
    String? glbFileName,
    bool? hasGlbModel,
    double? glbScale,
    double? glbOrbitTheta,
    double? glbOrbitPhi,
    bool? glbAutoRotate,
    String? backgroundImageUrl,
    double? backgroundAlpha,
    String? titlePrefix,
    String? titleHighlight,
    String? tagline,
    String? description,
    List<String>? highlights,
    String? footerTagline,
  }) {
    return AutomationProposalThemeConfig(
      primaryColor: primaryColor ?? this.primaryColor,
      heroImageUrl: heroImageUrl ?? this.heroImageUrl,
      glbModelUrl: glbModelUrl ?? this.glbModelUrl,
      glbFileName: glbFileName ?? this.glbFileName,
      hasGlbModel: hasGlbModel ?? this.hasGlbModel,
      glbScale: glbScale ?? this.glbScale,
      glbOrbitTheta: glbOrbitTheta ?? this.glbOrbitTheta,
      glbOrbitPhi: glbOrbitPhi ?? this.glbOrbitPhi,
      glbAutoRotate: glbAutoRotate ?? this.glbAutoRotate,
      backgroundImageUrl: backgroundImageUrl ?? this.backgroundImageUrl,
      backgroundAlpha: backgroundAlpha ?? this.backgroundAlpha,
      titlePrefix: titlePrefix ?? this.titlePrefix,
      titleHighlight: titleHighlight ?? this.titleHighlight,
      tagline: tagline ?? this.tagline,
      description: description ?? this.description,
      highlights: highlights ?? this.highlights,
      footerTagline: footerTagline ?? this.footerTagline,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'primaryColor': primaryColor.toARGB32(),
      'heroImageUrl': heroImageUrl,
      if (glbModelUrl != null && glbModelUrl!.isNotEmpty && !glbModelUrl!.startsWith('indexeddb:'))
        'glbModelUrl': glbModelUrl,
      if (glbFileName != null && glbFileName!.isNotEmpty) 'glbFileName': glbFileName,
      'hasGlbModel': hasValidGlb,
      'glbScale': glbScale,
      'glbOrbitTheta': glbOrbitTheta,
      'glbOrbitPhi': glbOrbitPhi,
      'glbAutoRotate': glbAutoRotate,
      'backgroundImageUrl': backgroundImageUrl,
      'backgroundAlpha': backgroundAlpha,
      'titlePrefix': titlePrefix,
      'titleHighlight': titleHighlight,
      'tagline': tagline,
      'description': description,
      'highlights': highlights,
      'footerTagline': footerTagline,
    };
  }

  factory AutomationProposalThemeConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const AutomationProposalThemeConfig();
    final rawGlb = map['glbModelUrl']?.toString();
    final cleanGlb = (rawGlb != null && !rawGlb.startsWith('indexeddb:') && rawGlb.trim().isNotEmpty)
        ? rawGlb.trim()
        : null;
    final hasGlb = map['hasGlbModel'] == true ||
        (rawGlb != null && rawGlb.isNotEmpty);

    return AutomationProposalThemeConfig(
      primaryColor: map['primaryColor'] != null
          ? Color((map['primaryColor'] as num).toInt())
          : const Color(0xFF00E5FF),
      heroImageUrl: map['heroImageUrl']?.toString() ?? 'assets/images/smart_home_hero.jpg',
      glbModelUrl: cleanGlb,
      glbFileName: map['glbFileName']?.toString(),
      hasGlbModel: hasGlb,
      glbScale: (map['glbScale'] as num?)?.toDouble() ?? 1.2,
      glbOrbitTheta: (map['glbOrbitTheta'] as num?)?.toDouble() ?? 45.0,
      glbOrbitPhi: (map['glbOrbitPhi'] as num?)?.toDouble() ?? 65.0,
      glbAutoRotate: map['glbAutoRotate'] as bool? ?? true,
      backgroundImageUrl: map['backgroundImageUrl']?.toString() ??
          'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?auto=format&fit=crop&w=1920&q=80',
      backgroundAlpha: (map['backgroundAlpha'] as num?)?.toDouble() ?? 0.40,
      titlePrefix: map['titlePrefix']?.toString() ?? 'Residência',
      titleHighlight: map['titleHighlight']?.toString() ??
          (map['headline']?.toString().replaceFirst('Residência', '').trim().isNotEmpty == true
              ? map['headline']!.toString().replaceFirst('Residência', '').trim()
              : 'Família Klaus'),
      tagline: map['tagline']?.toString() ?? 'Uma casa que entende você.',
      description: map['description']?.toString() ??
          'Explore cada ambiente e descubra como a tecnologia transforma conforto, segurança e experiências.',
      highlights: map['highlights'] is List
          ? List<String>.from(map['highlights'])
          : const [
              'Mais conforto',
              'Mais segurança',
              'Mais eficiência',
              'Mais momentos',
            ],
      footerTagline: map['footerTagline']?.toString() ?? 'TECNOLOGIA A SERVIÇO DA SUA MELHOR VIDA',
    );
  }
}

/// Diálogo Premium para Customização da Proposta Web de Automação
class AutomationProposalCustomizerDialog extends StatefulWidget {
  final AutomationProposalThemeConfig initialConfig;
  final String clientName;
  final ValueChanged<AutomationProposalThemeConfig> onSave;
  final ValueChanged<AutomationProposalThemeConfig>? onLiveChange;

  const AutomationProposalCustomizerDialog({
    super.key,
    required this.initialConfig,
    required this.clientName,
    required this.onSave,
    this.onLiveChange,
  });

  @override
  State<AutomationProposalCustomizerDialog> createState() =>
      _AutomationProposalCustomizerDialogState();
}

class _AutomationProposalCustomizerDialogState
    extends State<AutomationProposalCustomizerDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  late Color _selectedColor;
  late String _heroImageUrl;
  late String? _glbModelUrl;
  late String? _glbFileName;
  late String _selectedBackgroundUrl;
  late double _backgroundAlpha;
  late double _glbScale;
  late double _glbOrbitTheta;
  late double _glbOrbitPhi;
  late bool _glbAutoRotate;

  late TextEditingController _titlePrefixCtrl;
  late TextEditingController _titleHighlightCtrl;
  late TextEditingController _taglineCtrl;
  late TextEditingController _descriptionCtrl;
  late TextEditingController _footerTaglineCtrl;
  late TextEditingController _customHouseUrlCtrl;
  late TextEditingController _customGlbUrlCtrl;
  late TextEditingController _customBgUrlCtrl;

  late List<String> _highlights;
  bool _isUploadingHouseImage = false;
  bool _isUploadingGlb = false;
  bool _isUploadingBg = false;

  static const List<Color> _presetColors = [
    Color(0xFF00E5FF), // Ciano Neon (Referência)
    Color(0xFF10B981), // Esmeralda Smart
    Color(0xFFF59E0B), // Âmbar Solar
    Color(0xFF6366F1), // Índigo Tech
    Color(0xFF8B5CF6), // Violeta Cyber
    Color(0xFFEC4899), // Rosa Neon
  ];

  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    final cfg = widget.initialConfig;
    _selectedColor = cfg.primaryColor;
    _heroImageUrl = cfg.heroImageUrl;
    _glbModelUrl = cfg.glbModelUrl;
    _glbFileName = cfg.glbFileName;
    _selectedBackgroundUrl = cfg.backgroundImageUrl;
    _backgroundAlpha = cfg.backgroundAlpha;
    _glbScale = cfg.glbScale;
    _glbOrbitTheta = cfg.glbOrbitTheta;
    _glbOrbitPhi = cfg.glbOrbitPhi;
    _glbAutoRotate = cfg.glbAutoRotate;

    final defaultHighlight = widget.clientName.isNotEmpty
        ? (widget.clientName.startsWith('Família') ? widget.clientName : 'Família ${widget.clientName}')
        : cfg.titleHighlight;

    _titlePrefixCtrl = TextEditingController(text: cfg.titlePrefix.isNotEmpty ? cfg.titlePrefix : 'Residência');
    _titleHighlightCtrl = TextEditingController(text: cfg.titleHighlight.isNotEmpty ? cfg.titleHighlight : defaultHighlight);
    _taglineCtrl = TextEditingController(text: cfg.tagline);
    _descriptionCtrl = TextEditingController(text: cfg.description);
    _footerTaglineCtrl = TextEditingController(text: cfg.footerTagline);

    _customHouseUrlCtrl = TextEditingController(text: _heroImageUrl.startsWith('http') ? _heroImageUrl : '');
    _customGlbUrlCtrl = TextEditingController(text: _glbModelUrl?.startsWith('http') == true ? _glbModelUrl : '');
    _customBgUrlCtrl = TextEditingController(text: _selectedBackgroundUrl.startsWith('http') ? _selectedBackgroundUrl : '');

    _highlights = List<String>.from(cfg.highlights);

    // Escuta alterações nos campos de texto para preview em tempo real
    _titlePrefixCtrl.addListener(_notifyLiveChange);
    _titleHighlightCtrl.addListener(_notifyLiveChange);
    _taglineCtrl.addListener(_notifyLiveChange);
    _descriptionCtrl.addListener(_notifyLiveChange);
    _footerTaglineCtrl.addListener(_notifyLiveChange);
    _customHouseUrlCtrl.addListener(_notifyLiveChange);
    _customGlbUrlCtrl.addListener(_notifyLiveChange);
    _customBgUrlCtrl.addListener(_notifyLiveChange);
  }

  AutomationProposalThemeConfig _buildCurrentConfig() {
    final liveOrbit = GlbModelViewerWidget.getCurrentCameraOrbit();
    if (liveOrbit != null) {
      _glbOrbitTheta = liveOrbit['theta'] ?? _glbOrbitTheta;
      _glbOrbitPhi = liveOrbit['phi'] ?? _glbOrbitPhi;
    }

    final finalHeroImage = (_customHouseUrlCtrl.text.trim().startsWith('http') || _customHouseUrlCtrl.text.trim().startsWith('data:'))
        ? _customHouseUrlCtrl.text.trim()
        : _heroImageUrl;

    final customGlbText = _customGlbUrlCtrl.text.trim();
    final finalGlbUrl = (customGlbText.startsWith('http://') ||
            customGlbText.startsWith('https://') ||
            customGlbText.startsWith('blob:') ||
            customGlbText.startsWith('data:'))
        ? customGlbText
        : (_glbModelUrl ?? AutomationPreviewBridge.latestGlbDataUrl);

    final finalBgUrl = (_customBgUrlCtrl.text.trim().startsWith('http') || _customBgUrlCtrl.text.trim().startsWith('data:'))
        ? _customBgUrlCtrl.text.trim()
        : _selectedBackgroundUrl;

    final hasGlb = (finalGlbUrl != null && finalGlbUrl.isNotEmpty && !finalGlbUrl.startsWith('indexeddb:')) ||
        widget.initialConfig.hasValidGlb;

    return widget.initialConfig.copyWith(
      primaryColor: _selectedColor,
      heroImageUrl: finalHeroImage,
      glbModelUrl: finalGlbUrl,
      glbFileName: _glbFileName,
      hasGlbModel: hasGlb,
      glbScale: _glbScale,
      glbOrbitTheta: _glbOrbitTheta,
      glbOrbitPhi: _glbOrbitPhi,
      glbAutoRotate: _glbAutoRotate,
      backgroundImageUrl: finalBgUrl,
      backgroundAlpha: _backgroundAlpha,
      titlePrefix: _titlePrefixCtrl.text.trim().isNotEmpty ? _titlePrefixCtrl.text.trim() : 'Residência',
      titleHighlight: _titleHighlightCtrl.text.trim().isNotEmpty ? _titleHighlightCtrl.text.trim() : 'Família Klaus',
      tagline: _taglineCtrl.text.trim(),
      description: _descriptionCtrl.text.trim(),
      footerTagline: _footerTaglineCtrl.text.trim(),
      highlights: _highlights,
    );
  }

  void _notifyLiveChange() {
    widget.onLiveChange?.call(_buildCurrentConfig());
  }

  void _cancel() {
    if (!_isSaved) {
      widget.onLiveChange?.call(widget.initialConfig);
    }
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titlePrefixCtrl.dispose();
    _titleHighlightCtrl.dispose();
    _taglineCtrl.dispose();
    _descriptionCtrl.dispose();
    _footerTaglineCtrl.dispose();
    _customHouseUrlCtrl.dispose();
    _customGlbUrlCtrl.dispose();
    _customBgUrlCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // UPLOAD DA FOTO DA CASA (JPG/PNG/WEBP)
  // ---------------------------------------------------------------------------
  Future<void> _pickHouseImage() async {
    setState(() => _isUploadingHouseImage = true);
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      );

      if (files.isNotEmpty) {
        final file = files.first;
        final bytes = await file.readAsBytes();
        final base64String = base64Encode(bytes);
        final ext = file.extension?.toLowerCase() ?? 'jpeg';
        final mime = ext == 'png' ? 'image/png' : (ext == 'webp' ? 'image/webp' : 'image/jpeg');
        final dataUrl = 'data:$mime;base64,$base64String';

        setState(() {
          _heroImageUrl = dataUrl;
          _customHouseUrlCtrl.text = 'Arquivo local: ${file.name}';
          _selectedBackgroundUrl = dataUrl;
          _customBgUrlCtrl.text = 'Foto da Casa: ${file.name}';
        });
        _notifyLiveChange();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✓ Imagem da residência (${file.name}) carregada com sucesso!'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao selecionar imagem: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingHouseImage = false);
    }
  }

  // ---------------------------------------------------------------------------
  // UPLOAD DO ARQUIVO 3D (.GLB)
  // ---------------------------------------------------------------------------
  Future<void> _pickGlbModel() async {
    setState(() => _isUploadingGlb = true);
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['glb', 'gltf', 'dae', 'obj'],
      );

      if (files.isNotEmpty) {
        final file = files.first;
        final bytes = await file.readAsBytes();
        final base64String = base64Encode(bytes);
        final dataUrl = 'data:model/gltf-binary;base64,$base64String';

        setState(() {
          _glbModelUrl = dataUrl;
          _glbFileName = file.name;
          _customGlbUrlCtrl.text = file.name;
        });
        _notifyLiveChange();

        // Registra no bridge de preview global
        AutomationPreviewBridge.latestGlbDataUrl = dataUrl;
        AutomationPreviewBridge.latestGlbFileName = file.name;
        AutomationPreviewBridge.save3DModelBytes(file.name, bytes);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✓ Modelo 3D (${file.name}) carregado para a Vista Panorâmica!'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao selecionar arquivo 3D: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingGlb = false);
    }
  }

  // ---------------------------------------------------------------------------
  // DOWNLOAD DO ARQUIVO 3D (.GLB)
  // ---------------------------------------------------------------------------
  void _downloadGlbFile() {
    final customGlbText = _customGlbUrlCtrl.text.trim();
    final activeGlbUrl = (customGlbText.startsWith('http://') ||
            customGlbText.startsWith('https://') ||
            customGlbText.startsWith('blob:') ||
            customGlbText.startsWith('data:'))
        ? customGlbText
        : (_glbModelUrl ?? AutomationPreviewBridge.latestGlbDataUrl);

    if (activeGlbUrl == null || activeGlbUrl.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nenhum modelo 3D GLB disponível para download.'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
      return;
    }

    final name = _glbFileName ?? 'Casa_3D_Residencial.glb';
    AutomationPreviewBridge.downloadGlbFile(activeGlbUrl, name);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Download do modelo 3D ($name) iniciado com sucesso!'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // UPLOAD DO BACKGROUND PERSONALIZADO
  // ---------------------------------------------------------------------------
  Future<void> _pickBackgroundImage() async {
    setState(() => _isUploadingBg = true);
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      );

      if (files.isNotEmpty) {
        final file = files.first;
        final bytes = await file.readAsBytes();
        final base64String = base64Encode(bytes);
        final ext = file.extension?.toLowerCase() ?? 'jpeg';
        final mime = ext == 'png' ? 'image/png' : (ext == 'webp' ? 'image/webp' : 'image/jpeg');
        final dataUrl = 'data:$mime;base64,$base64String';

        setState(() {
          _selectedBackgroundUrl = dataUrl;
          _customBgUrlCtrl.text = 'Background personalizado: ${file.name}';
        });
        _notifyLiveChange();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✓ Background personalizado (${file.name}) carregado com sucesso!'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao selecionar imagem de fundo: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingBg = false);
    }
  }



  void _save() {
    _isSaved = true;
    final updated = _buildCurrentConfig();

    if (updated.glbModelUrl != null && updated.glbModelUrl!.isNotEmpty) {
      AutomationPreviewBridge.latestGlbDataUrl = updated.glbModelUrl;
      AutomationPreviewBridge.latestGlbFileName = updated.glbFileName;
    }

    widget.onSave(updated);
    widget.onLiveChange?.call(updated);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && !_isSaved) {
          widget.onLiveChange?.call(widget.initialConfig);
        }
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          width: 860,
          constraints: const BoxConstraints(maxHeight: 780),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _selectedColor.withValues(alpha: 0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.8),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
              BoxShadow(
                color: _selectedColor.withValues(alpha: 0.15),
                blurRadius: 32,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            children: [
              // HEADER DO MODAL COM TABS
              Container(
                padding: const EdgeInsets.fromLTRB(28, 20, 20, 0),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _selectedColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _selectedColor.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Icon(Icons.palette_rounded, color: _selectedColor, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Personalizar Proposta Web Interativa',
                                style: GoogleFonts.outfit(
                                  fontSize: 19,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'Escolha entre 10 modelos de background em alpha, faça upload da casa ou modelo 3D GLB e personalize títulos',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: _cancel,
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                          splashRadius: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TabBar(
                      controller: _tabController,
                      indicatorColor: _selectedColor,
                      indicatorWeight: 3,
                      labelColor: _selectedColor,
                      unselectedLabelColor: const Color(0xFF94A3B8),
                      labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                      tabs: const [
                        Tab(icon: Icon(Icons.home_work_rounded, size: 18), text: 'Fundo em Alpha & Casa 3D (Uploads)'),
                        Tab(icon: Icon(Icons.text_fields_rounded, size: 18), text: 'Título, Textos de Impacto & Cores'),
                      ],
                    ),
                  ],
                ),
              ),

              // CORPO COM AS DUAS ABAS
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // ABA 1: BACKGROUND & CASA 3D COM UPLOADS E PRESETS
                    _buildTabBackgroundAndHouse(),

                    // ABA 2: TÍTULO, TEXTOS, SLOGAN & CORES
                    _buildTabTypographyAndColors(),
                  ],
                ),
              ),

              // RODAPÉ DE AÇÕES
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Preview atualiza em tempo real com as alterações salvas.',
                      style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                    ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: _cancel,
                          child: Text(
                            'Cancelar',
                            style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _save,
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: Text(
                            'Salvar & Aplicar',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _selectedColor,
                            foregroundColor: Colors.black,
                            elevation: 4,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }



  // ---------------------------------------------------------------------------
  // ABA 1: FUNDO EM ALPHA & CASA 3D (COM 10 MODELOS E BOTÕES DE UPLOAD)
  // ---------------------------------------------------------------------------
  Widget _buildTabBackgroundAndHouse() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── SEÇÃO 1: FOTO / MODELO 3D DA CASA DO CLIENTE ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '1. CASA DO CLIENTE (DESTAQUE CENTRAL INTEGRADO)',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: _selectedColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Faça upload da imagem da casa, envie o arquivo 3D (.GLB) para vista panorâmica ou selecione um modelo.',
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Painel de Uploads da Casa (Imagem & GLB)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Botão Upload Foto da Casa
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isUploadingHouseImage ? null : _pickHouseImage,
                        icon: _isUploadingHouseImage
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.cloud_upload_rounded, size: 20),
                        label: Text(
                          'UPLOAD DA FOTO DA CASA',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: _selectedColor,
                          side: BorderSide(color: _selectedColor.withValues(alpha: 0.5)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Botão Upload Arquivo 3D GLB
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isUploadingGlb ? null : _pickGlbModel,
                        icon: _isUploadingGlb
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.view_in_ar_rounded, size: 20),
                        label: Text(
                          _glbFileName != null ? '3D: ${_glbFileName!}' : 'UPLOAD ARQUIVO 3D (GLB / COLLADA)',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: const Color(0xFF10B981),
                          side: BorderSide(color: const Color(0xFF10B981).withValues(alpha: 0.5)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Campos de URL alternativos
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _customHouseUrlCtrl,
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Ou cole a URL da imagem da casa...',
                          hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                          isDense: true,
                          prefixIcon: const Icon(Icons.link_rounded, size: 16, color: Color(0xFF94A3B8)),
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: TextField(
                        controller: _customGlbUrlCtrl,
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Ou cole a URL do modelo .glb 3D...',
                          hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                          isDense: true,
                          prefixIcon: const Icon(Icons.hub_rounded, size: 16, color: Color(0xFF94A3B8)),
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
                Builder(
                  builder: (context) {
                    final customGlbText = _customGlbUrlCtrl.text.trim();
                    final activeGlbUrl = (customGlbText.startsWith('http://') ||
                            customGlbText.startsWith('https://') ||
                            customGlbText.startsWith('blob:') ||
                            customGlbText.startsWith('data:'))
                        ? customGlbText
                        : (_glbModelUrl ?? AutomationPreviewBridge.latestGlbDataUrl);
                    final hasActiveGlb = activeGlbUrl != null &&
                        activeGlbUrl.trim().isNotEmpty &&
                        !activeGlbUrl.startsWith('indexeddb:');

                    if (!hasActiveGlb) return const SizedBox.shrink();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Container do Visualizador 3D
                        Container(
                          height: 270,
                          width: double.infinity,
                          margin: const EdgeInsets.only(top: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF10B981), width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF10B981).withValues(alpha: 0.25),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              GlbModelViewerWidget(
                                glbUrl: activeGlbUrl,
                                fallbackImageUrl: _heroImageUrl,
                                autoRotate: _glbAutoRotate,
                                accentColor: _selectedColor,
                                glbScale: _glbScale,
                                glbOrbitTheta: _glbOrbitTheta,
                                glbOrbitPhi: _glbOrbitPhi,
                                enableCameraControls: false,
                                onCameraChange: (theta, phi) {
                                  _glbOrbitTheta = theta;
                                  _glbOrbitPhi = phi;
                                  _notifyLiveChange();
                                },
                              ),
                              Positioned(
                                top: 12,
                                left: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.95),
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 6),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.threed_rotation_rounded, color: Colors.white, size: 16),
                                      const SizedBox(width: 8),
                                      Text(
                                        'PREVIEW 3D ATIVO (${_glbOrbitTheta.toInt()}° / ${_glbOrbitPhi.toInt()}° / ${(_glbScale * 100).toInt()}%)',
                                        style: GoogleFonts.inter(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // Controles rápidos de Zoom [-] [+] no topo direito do container
                              Positioned(
                                top: 12,
                                right: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F172A).withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        onPressed: _glbScale > 0.4
                                            ? () {
                                                setState(() {
                                                  _glbScale = (_glbScale - 0.15).clamp(0.4, 3.5);
                                                });
                                                _notifyLiveChange();
                                              }
                                            : null,
                                        icon: const Icon(Icons.remove_rounded, color: Colors.white, size: 16),
                                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                        padding: EdgeInsets.zero,
                                        tooltip: 'Diminuir Tamanho',
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 6),
                                        child: Text(
                                          'Zoom: ${(_glbScale * 100).toInt()}%',
                                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: _selectedColor),
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: _glbScale < 3.5
                                            ? () {
                                                setState(() {
                                                  _glbScale = (_glbScale + 0.15).clamp(0.4, 3.5);
                                                });
                                                _notifyLiveChange();
                                              }
                                            : null,
                                        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 16),
                                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                        padding: EdgeInsets.zero,
                                        tooltip: 'Aumentar Tamanho',
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 12,
                                right: 12,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: _downloadGlbFile,
                                      icon: const Icon(Icons.download_rounded, size: 18),
                                      label: Text(
                                        'BAIXAR .GLB (3D)',
                                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF1E293B),
                                        foregroundColor: const Color(0xFF10B981),
                                        side: const BorderSide(color: Color(0xFF10B981), width: 1.5),
                                        elevation: 6,
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Painel de Controle de Escala, Zoom e Rotação da Maquete 3D
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _selectedColor.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.tune_rounded, color: _selectedColor, size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        'AJUSTE DE TAMANHO, ÂNGULO E ROTAÇÃO INICIAL 3D',
                                        style: GoogleFonts.outfit(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.8,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        'Giro Automático:',
                                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                                      ),
                                      const SizedBox(width: 6),
                                      Switch.adaptive(
                                        value: _glbAutoRotate,
                                        activeTrackColor: _selectedColor,
                                        activeThumbColor: Colors.white,
                                        onChanged: (val) {
                                          setState(() => _glbAutoRotate = val);
                                          _notifyLiveChange();
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // 1. Controle de Tamanho / Zoom (Escala)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Tamanho / Zoom Inicial:', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white)),
                                  Text('${(_glbScale * 100).toInt()}% (${_glbScale.toStringAsFixed(1)}x)', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold, color: _selectedColor)),
                                ],
                              ),
                              Row(
                                children: [
                                  Text('Pequeno (40%)', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8))),
                                  Expanded(
                                    child: SliderTheme(
                                      data: SliderThemeData(
                                        activeTrackColor: _selectedColor,
                                        inactiveTrackColor: const Color(0xFF334155),
                                        thumbColor: _selectedColor,
                                        trackHeight: 5,
                                      ),
                                      child: Slider(
                                        value: _glbScale.clamp(0.4, 3.5),
                                        min: 0.4,
                                        max: 3.5,
                                        divisions: 31,
                                        onChanged: (val) {
                                          setState(() => _glbScale = val);
                                          _notifyLiveChange();
                                        },
                                      ),
                                    ),
                                  ),
                                  Text('Gigante (350%)', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8))),
                                ],
                              ),

                              // 2. Controle de Rotação Horizontal (Theta)
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Rotação Horizontal (Ângulo de Fachada):', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white)),
                                  Text('${_glbOrbitTheta.toInt()}°', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold, color: _selectedColor)),
                                ],
                              ),
                              Row(
                                children: [
                                  Text('0° Frontal', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8))),
                                  Expanded(
                                    child: SliderTheme(
                                      data: SliderThemeData(
                                        activeTrackColor: _selectedColor,
                                        inactiveTrackColor: const Color(0xFF334155),
                                        thumbColor: _selectedColor,
                                        trackHeight: 5,
                                      ),
                                      child: Slider(
                                        value: _glbOrbitTheta.clamp(0.0, 360.0),
                                        min: 0.0,
                                        max: 360.0,
                                        divisions: 72,
                                        onChanged: (val) {
                                          setState(() => _glbOrbitTheta = val);
                                          _notifyLiveChange();
                                        },
                                      ),
                                    ),
                                  ),
                                  Text('360° Completo', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8))),
                                ],
                              ),

                              // 3. Controle de Inclinação Vertical (Phi)
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Inclinação Vertical (Visão de Cima/Lado):', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white)),
                                  Text('${_glbOrbitPhi.toInt()}°', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold, color: _selectedColor)),
                                ],
                              ),
                              Row(
                                children: [
                                  Text('20° Superior', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8))),
                                  Expanded(
                                    child: SliderTheme(
                                      data: SliderThemeData(
                                        activeTrackColor: _selectedColor,
                                        inactiveTrackColor: const Color(0xFF334155),
                                        thumbColor: _selectedColor,
                                        trackHeight: 5,
                                      ),
                                      child: Slider(
                                        value: _glbOrbitPhi.clamp(20.0, 90.0),
                                        min: 20.0,
                                        max: 90.0,
                                        divisions: 70,
                                        onChanged: (val) {
                                          setState(() => _glbOrbitPhi = val);
                                          _notifyLiveChange();
                                        },
                                      ),
                                    ),
                                  ),
                                  Text('90° Terrestre', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8))),
                                ],
                              ),

                              const SizedBox(height: 10),
                              // Chips de Ângulos Pré-Configurados
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _buildPresetChip(
                                    label: '📐 Fachada Frontal (0°)',
                                    isSelected: (_glbOrbitTheta - 0).abs() < 10,
                                    onTap: () {
                                      setState(() {
                                        _glbOrbitTheta = 0;
                                        _glbOrbitPhi = 65;
                                      });
                                      _notifyLiveChange();
                                    },
                                  ),
                                  _buildPresetChip(
                                    label: '📐 Isométrica 3D (45°)',
                                    isSelected: (_glbOrbitTheta - 45).abs() < 10,
                                    onTap: () {
                                      setState(() {
                                        _glbOrbitTheta = 45;
                                        _glbOrbitPhi = 65;
                                      });
                                      _notifyLiveChange();
                                    },
                                  ),
                                  _buildPresetChip(
                                    label: '📐 Lateral Dir. (90°)',
                                    isSelected: (_glbOrbitTheta - 90).abs() < 10,
                                    onTap: () {
                                      setState(() {
                                        _glbOrbitTheta = 90;
                                        _glbOrbitPhi = 65;
                                      });
                                      _notifyLiveChange();
                                    },
                                  ),
                                  _buildPresetChip(
                                    label: '📐 Visão Traseira (180°)',
                                    isSelected: (_glbOrbitTheta - 180).abs() < 10,
                                    onTap: () {
                                      setState(() {
                                        _glbOrbitTheta = 180;
                                        _glbOrbitPhi = 65;
                                      });
                                      _notifyLiveChange();
                                    },
                                  ),
                                  _buildPresetChip(
                                    label: '📐 Vista Aérea (30° Incl.)',
                                    isSelected: (_glbOrbitPhi - 30).abs() < 10,
                                    onTap: () {
                                      setState(() {
                                        _glbOrbitPhi = 30;
                                      });
                                      _notifyLiveChange();
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // ── SEÇÃO 2: 10 MODELOS DE BACKGROUND DE RESIDÊNCIA EM ALPHA ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '2. MODELOS DE BACKGROUND EM ALPHA (10 OPÇÕES DE RESIDÊNCIAS)',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: _selectedColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Selecione uma das 10 mansões noturnas com iluminação cênica para o fundo em transparência.',
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _isUploadingBg ? null : _pickBackgroundImage,
                icon: const Icon(Icons.add_photo_alternate_rounded, size: 16),
                label: Text('ENVIAR BACKGROUND', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Grid dos 10 Modelos de Background
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: kDefaultProposalBackgrounds.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              mainAxisExtent: 135,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemBuilder: (context, index) {
              final preset = kDefaultProposalBackgrounds[index];
              final isSelected = _selectedBackgroundUrl == preset.imageUrl;

              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedBackgroundUrl = preset.imageUrl;
                    _customBgUrlCtrl.text = preset.imageUrl;
                  });
                  _notifyLiveChange();
                },
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? _selectedColor : Colors.white.withValues(alpha: 0.1),
                      width: isSelected ? 2.5 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(color: _selectedColor.withValues(alpha: 0.35), blurRadius: 12, spreadRadius: 1),
                          ]
                        : null,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        preset.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1E293B)),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.85)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                      if (isSelected)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(color: _selectedColor, shape: BoxShape.circle),
                            child: const Icon(Icons.check_rounded, color: Colors.black, size: 12),
                          ),
                        ),
                      Positioned(
                        bottom: 8,
                        left: 8,
                        right: 8,
                        child: Text(
                          preset.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 18),

          // Preview em tempo real da Imagem Selecionada / Carregada com o Fade Aplicado
          Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: const Color(0xFF0F172A),
              border: Border.all(
                color: _selectedColor.withValues(alpha: 0.5),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: _selectedColor.withValues(alpha: 0.2),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(color: const Color(0xFF020617)),
                Opacity(
                  opacity: _backgroundAlpha,
                  child: _selectedBackgroundUrl.startsWith('data:')
                      ? Image.memory(
                          base64Decode(_selectedBackgroundUrl.split(',').last),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.broken_image_rounded, color: Colors.white38, size: 36),
                          ),
                        )
                      : Image.network(
                          _selectedBackgroundUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.broken_image_rounded, color: Colors.white38, size: 36),
                          ),
                        ),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.8),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _selectedColor.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.remove_red_eye_rounded, color: _selectedColor, size: 13),
                        const SizedBox(width: 6),
                        Text(
                          'PREVIEW DO FADE EM TEMPO REAL: ${(_backgroundAlpha * 100).toInt()}%',
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 10,
                  left: 12,
                  right: 12,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _getPresetTitle(_selectedBackgroundUrl),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _selectedColor.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Alpha ${(_backgroundAlpha * 100).toInt()}%',
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: _selectedColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Controle de Opacidade do Fundo em Alpha
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.opacity_rounded, color: Color(0xFF94A3B8), size: 20),
                const SizedBox(width: 12),
                Text('Intensidade do Fundo em Alpha:', style: GoogleFonts.inter(fontSize: 13, color: Colors.white)),
                Expanded(
                  child: Slider(
                    value: _backgroundAlpha,
                    min: 0.15,
                    max: 0.80,
                    activeColor: _selectedColor,
                    inactiveColor: const Color(0xFF0F172A),
                    onChanged: (val) {
                      setState(() => _backgroundAlpha = val);
                      _notifyLiveChange();
                    },
                  ),
                ),
                Text(
                  '${(_backgroundAlpha * 100).toInt()}%',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: _selectedColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ABA 2: TÍTULO, TEXTOS DE IMPACTO & CORES
  // ---------------------------------------------------------------------------
  Widget _buildTabTypographyAndColors() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. TÍTULO EDITÁVEL E CUSTOMIZÁVEL
          Text(
            '1. TÍTULO PRINCIPAL DO PROJETO',
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: _selectedColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'O título é dividido em Prefixo (branco) e Nome de Destaque (com gradiente ciano).',
            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _titlePrefixCtrl,
                  style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Prefixo do Título',
                    labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    hintText: 'Ex: Residência',
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 5,
                child: TextField(
                  controller: _titleHighlightCtrl,
                  style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: _selectedColor),
                  decoration: InputDecoration(
                    labelText: 'Nome de Destaque / Família (Com Gradiente Neon)',
                    labelStyle: TextStyle(color: _selectedColor, fontSize: 12),
                    hintText: 'Ex: Família Klaus',
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 2. COR DE DESTAQUE NEON
          Text(
            '2. COR PRINCIPAL DE DESTAQUE (NEON TECH)',
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: _selectedColor,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: _presetColors.map((color) {
              final isSelected = _selectedColor.toARGB32() == color.toARGB32();
              return InkWell(
                onTap: () {
                  setState(() => _selectedColor = color);
                  _notifyLiveChange();
                },
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? color.withValues(alpha: 0.2) : const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? color : Colors.white.withValues(alpha: 0.1),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _getColorName(color),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 24),

          // 3. SLOGAN E DESCRIÇÃO DE IMPACTO
          Text(
            '3. SLOGAN E DESCRIÇÃO DE IMPACTO',
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: _selectedColor,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _taglineCtrl,
            style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Frase de Efeito (Subtítulo)',
              labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              hintText: 'Uma casa que entende você.',
              filled: true,
              fillColor: const Color(0xFF1E293B),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionCtrl,
            maxLines: 2,
            style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Descrição Comercial',
              labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              hintText: 'Explore cada ambiente e descubra como a tecnologia transforma...',
              filled: true,
              fillColor: const Color(0xFF1E293B),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),

          const SizedBox(height: 24),

          // 4. SELOS DE BENEFÍCIOS (4 DESTAQUES)
          Text(
            '4. SELOS DE BENEFÍCIOS',
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: _selectedColor,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _highlights.map((badge) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _selectedColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded, color: _selectedColor, size: 14),
                    const SizedBox(width: 8),
                    Text(badge, style: GoogleFonts.inter(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500)),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  String _getPresetTitle(String url) {
    final found = kDefaultProposalBackgrounds.where((b) => b.imageUrl == url);
    if (found.isNotEmpty) return found.first.title;
    if (url.startsWith('data:')) return 'Foto da Casa / Upload Personalizado';
    return 'Background Selecionado';
  }

  String _getColorName(Color color) {
    if (color == const Color(0xFF00E5FF)) return 'Ciano Neon (Oficial)';
    if (color == const Color(0xFF10B981)) return 'Esmeralda Smart';
    if (color == const Color(0xFFF59E0B)) return 'Âmbar Solar';
    if (color == const Color(0xFF6366F1)) return 'Índigo Tech';
    if (color == const Color(0xFF8B5CF6)) return 'Violeta Cyber';
    if (color == const Color(0xFFEC4899)) return 'Rosa Neon';
    return 'Personalizada';
  }

  Widget _buildPresetChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? _selectedColor.withValues(alpha: 0.2) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? _selectedColor : const Color(0xFF334155),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }
}
