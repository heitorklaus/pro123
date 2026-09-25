import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';
import '../../../proposals/data/services/automation_proposal_pdf_service.dart';
import '../../../proposals/domain/models/proposal_item_model.dart';
import '../../../proposals/domain/models/proposal_model.dart';
import '../../data/services/automation_settings_service.dart';
import '../../domain/models/automation_settings_model.dart';
import 'solar_cover_divider_painter.dart';
import 'automation_vertical_split_painter.dart';
import 'automation_cyber_connector_painter.dart';
import 'cover_header_footer_widgets.dart';
import '../../domain/models/proposal_pages_models.dart';
import 'cover_pages_manager_tab.dart';
import 'cover_page2_interactive_canvas.dart';
import 'cover_custom_page_interactive_canvas.dart';

/// Modal amplo de estúdio visual para personalização interativa em tempo real da capa da proposta
class AutomationCoverCustomizerDialog extends StatefulWidget {
  final AutomationSettingsModel initialSettings;
  final ValueChanged<AutomationSettingsModel> onSave;
  final String? initialPageId;

  const AutomationCoverCustomizerDialog({
    super.key,
    required this.initialSettings,
    required this.onSave,
    this.initialPageId,
  });

  static Future<AutomationSettingsModel?> show(
    BuildContext context, {
    required AutomationSettingsModel initialSettings,
    required ValueChanged<AutomationSettingsModel> onSave,
    String? initialPageId,
  }) {
    return showDialog<AutomationSettingsModel>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AutomationCoverCustomizerDialog(
        initialSettings: initialSettings,
        onSave: onSave,
        initialPageId: initialPageId,
      ),
    );
  }

  @override
  State<AutomationCoverCustomizerDialog> createState() => _AutomationCoverCustomizerDialogState();
}

class _AutomationCoverCustomizerDialogState extends State<AutomationCoverCustomizerDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late AutomationSettingsModel _current;
  bool _isSaving = false;

  // Controllers de Textos (Vertical Split)
  late final TextEditingController _headlineCtrl;
  late final TextEditingController _subheadlineCtrl;
  late final TextEditingController _rightTitleCtrl;
  late final TextEditingController _rightSubtitleCtrl;
  late final TextEditingController _rightTaglineCtrl;
  late final TextEditingController _leftFooterCtrl;
  late final TextEditingController _rightFooterCtrl;

  // Controllers de Textos (Estilo Modern)
  late final TextEditingController _coverTitleCtrl;
  late final TextEditingController _coverSubtitleCtrl;

  // Controllers de Cabeçalho & Rodapé
  late final TextEditingController _headerText1Ctrl;
  late final TextEditingController _headerText2Ctrl;
  late final TextEditingController _headerText3Ctrl;
  late final TextEditingController _footerText1Ctrl;
  late final TextEditingController _footerText2Ctrl;
  late final TextEditingController _footerText3Ctrl;
  late final TextEditingController _footerText4Ctrl;

  // FocusNodes para foco automático ao clicar/arrastar no Canvas
  final FocusNode _headlineFocusNode = FocusNode();
  final FocusNode _subheadlineFocusNode = FocusNode();
  final FocusNode _rightTitleFocusNode = FocusNode();
  final FocusNode _rightSubtitleFocusNode = FocusNode();
  final FocusNode _rightTaglineFocusNode = FocusNode();
  final FocusNode _leftFooterFocusNode = FocusNode();
  final FocusNode _rightFooterFocusNode = FocusNode();
  final FocusNode _coverTitleFocusNode = FocusNode();
  final FocusNode _coverSubtitleFocusNode = FocusNode();
  final Map<String, FocusNode> _customTextFocusNodes = {};
  final Map<int, FocusNode> _badgeFocusNodes = {};
  final ScrollController _inspectorScrollController = ScrollController();

  // Elemento atualmente selecionado/arrastado no canvas
  String? _selectedElementKey;
  String? _hoveredElementKey;

  // Página atualmente inspecionada no estúdio
  String _activeCustomizerPageId = 'page_1'; // 'page_1', 'page_2', 'page_3', 'page_4', 'page_5', ou 'custom_...'
  String? _selectedPage2CardId;

  // Galeria de Capas / Fotos
  int _selectedCoverGalleryTab = 0; // 0: 100 Capas A4, 1: 34 Fotos HD
  String _coverSearchQuery = '';

  // Cache de imagens Base64 para alta performance durante o arraste
  Uint8List? _cachedLogoBytes;
  String? _cachedLogoBase64;
  Uint8List? _cachedCoverBytes;
  String? _cachedCoverBase64;

  Uint8List? _getLogoBytes(String? base64Str) {
    if (base64Str == null || base64Str.isEmpty) return null;
    final clean = base64Str.contains(',') ? base64Str.split(',').last : base64Str;
    if (_cachedLogoBase64 == clean && _cachedLogoBytes != null) {
      return _cachedLogoBytes;
    }
    try {
      _cachedLogoBase64 = clean;
      _cachedLogoBytes = base64Decode(clean);
      return _cachedLogoBytes;
    } catch (_) {
      return null;
    }
  }

  Uint8List? _getCoverBytes(String? base64Str) {
    if (base64Str == null || base64Str.isEmpty) return null;
    final clean = base64Str.contains(',') ? base64Str.split(',').last : base64Str;
    if (_cachedCoverBase64 == clean && _cachedCoverBytes != null) {
      return _cachedCoverBytes;
    }
    try {
      _cachedCoverBase64 = clean;
      _cachedCoverBytes = base64Decode(clean);
      return _cachedCoverBytes;
    } catch (_) {
      return null;
    }
  }

  // Dimensões base A4
  static const double a4Width = 595.28;
  static const double a4Height = 841.89;

  @override
  void initState() {
    super.initState();
    _current = widget.initialSettings;
    if (widget.initialPageId != null && widget.initialPageId!.isNotEmpty) {
      _activeCustomizerPageId = widget.initialPageId!;
    }
    _tabController = TabController(
      length: 6,
      vsync: this,
      initialIndex: (widget.initialPageId == 'page_4' ||
              widget.initialPageId == 'page_2' ||
              widget.initialPageId == 'page_3' ||
              widget.initialPageId == 'page_5')
          ? 5
          : 0,
    );
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });

    _headlineCtrl = TextEditingController(text: _current.verticalSplitHeadline);
    _subheadlineCtrl = TextEditingController(text: _current.verticalSplitSubheadline);
    _rightTitleCtrl = TextEditingController(text: _current.verticalSplitRightTitle);
    _rightSubtitleCtrl = TextEditingController(text: _current.verticalSplitRightSubtitle);
    _rightTaglineCtrl = TextEditingController(text: _current.verticalSplitRightTagline);
    _leftFooterCtrl = TextEditingController(text: _current.verticalSplitLeftFooter);
    _rightFooterCtrl = TextEditingController(text: _current.verticalSplitRightFooter);

    _coverTitleCtrl = TextEditingController(text: _current.coverTitle);
    _coverSubtitleCtrl = TextEditingController(text: _current.coverSubtitle);

    _headerText1Ctrl = TextEditingController(text: _current.coverHeaderText1);
    _headerText2Ctrl = TextEditingController(text: _current.coverHeaderText2);
    _headerText3Ctrl = TextEditingController(text: _current.coverHeaderText3);
    _footerText1Ctrl = TextEditingController(text: _current.coverFooterText1);
    _footerText2Ctrl = TextEditingController(text: _current.coverFooterText2);
    _footerText3Ctrl = TextEditingController(text: _current.coverFooterText3);
    _footerText4Ctrl = TextEditingController(text: _current.coverFooterText4);

    _headlineCtrl.addListener(() {
      setState(() {
        _current = _current.copyWith(verticalSplitHeadline: _headlineCtrl.text);
      });
    });
    _subheadlineCtrl.addListener(() {
      setState(() {
        _current = _current.copyWith(verticalSplitSubheadline: _subheadlineCtrl.text);
      });
    });
    _rightTitleCtrl.addListener(() {
      setState(() {
        _current = _current.copyWith(verticalSplitRightTitle: _rightTitleCtrl.text);
      });
    });
    _rightSubtitleCtrl.addListener(() {
      setState(() {
        _current = _current.copyWith(verticalSplitRightSubtitle: _rightSubtitleCtrl.text);
      });
    });
    _rightTaglineCtrl.addListener(() {
      setState(() {
        _current = _current.copyWith(verticalSplitRightTagline: _rightTaglineCtrl.text);
      });
    });
    _leftFooterCtrl.addListener(() {
      setState(() {
        _current = _current.copyWith(verticalSplitLeftFooter: _leftFooterCtrl.text);
      });
    });
    _rightFooterCtrl.addListener(() {
      setState(() {
        _current = _current.copyWith(verticalSplitRightFooter: _rightFooterCtrl.text);
      });
    });

    _coverTitleCtrl.addListener(() {
      setState(() {
        _current = _current.copyWith(coverTitle: _coverTitleCtrl.text);
      });
    });
    _coverSubtitleCtrl.addListener(() {
      setState(() {
        _current = _current.copyWith(coverSubtitle: _coverSubtitleCtrl.text);
      });
    });

    _headerText1Ctrl.addListener(() {
      setState(() {
        _current = _current.copyWith(coverHeaderText1: _headerText1Ctrl.text);
      });
    });
    _headerText2Ctrl.addListener(() {
      setState(() {
        _current = _current.copyWith(coverHeaderText2: _headerText2Ctrl.text);
      });
    });
    _headerText3Ctrl.addListener(() {
      setState(() {
        _current = _current.copyWith(coverHeaderText3: _headerText3Ctrl.text);
      });
    });
    _footerText1Ctrl.addListener(() {
      setState(() {
        _current = _current.copyWith(coverFooterText1: _footerText1Ctrl.text);
      });
    });
    _footerText2Ctrl.addListener(() {
      setState(() {
        _current = _current.copyWith(coverFooterText2: _footerText2Ctrl.text);
      });
    });
    _footerText3Ctrl.addListener(() {
      setState(() {
        _current = _current.copyWith(coverFooterText3: _footerText3Ctrl.text);
      });
    });
    _footerText4Ctrl.addListener(() {
      setState(() {
        _current = _current.copyWith(coverFooterText4: _footerText4Ctrl.text);
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _headlineCtrl.dispose();
    _subheadlineCtrl.dispose();
    _rightTitleCtrl.dispose();
    _rightSubtitleCtrl.dispose();
    _rightTaglineCtrl.dispose();
    _leftFooterCtrl.dispose();
    _rightFooterCtrl.dispose();
    _coverTitleCtrl.dispose();
    _coverSubtitleCtrl.dispose();
    _headerText1Ctrl.dispose();
    _headerText2Ctrl.dispose();
    _headerText3Ctrl.dispose();
    _footerText1Ctrl.dispose();
    _footerText2Ctrl.dispose();
    _footerText3Ctrl.dispose();
    _footerText4Ctrl.dispose();

    _headlineFocusNode.dispose();
    _subheadlineFocusNode.dispose();
    _rightTitleFocusNode.dispose();
    _rightSubtitleFocusNode.dispose();
    _rightTaglineFocusNode.dispose();
    _leftFooterFocusNode.dispose();
    _rightFooterFocusNode.dispose();
    _coverTitleFocusNode.dispose();
    _coverSubtitleFocusNode.dispose();
    for (final fn in _customTextFocusNodes.values) {
      fn.dispose();
    }
    for (final fn in _badgeFocusNodes.values) {
      fn.dispose();
    }
    _inspectorScrollController.dispose();
    super.dispose();
  }

  int _hexToInt(String hexStr, {int fallback = 0xFF0284C7}) {
    final clean = hexStr.replaceAll('#', '').trim();
    if (clean.length == 6) return int.tryParse('FF$clean', radix: 16) ?? fallback;
    if (clean.length == 8) return int.tryParse(clean, radix: 16) ?? fallback;
    return fallback;
  }

  void _selectAndFocusElement(String elementKey) {
    setState(() => _selectedElementKey = elementKey);

    if (elementKey == 'logo') {
      if (_tabController.index != 4) {
        _tabController.animateTo(4);
      }
    } else if (elementKey == 'header' || elementKey == 'footer') {
      if (_tabController.index != 3) {
        _tabController.animateTo(3);
      }
    } else if (elementKey.startsWith('node_')) {
      if (_tabController.index != 2) {
        _tabController.animateTo(2);
      }
    } else if (elementKey == 'coverBadge') {
      if (_tabController.index != 0) {
        _tabController.animateTo(0);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _coverTitleFocusNode.requestFocus();
      });
    } else if (elementKey == 'clientInfo') {
      if (_tabController.index != 0) {
        _tabController.animateTo(0);
      }
    } else {
      if (_tabController.index != 0) {
        _tabController.animateTo(0);
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (elementKey == 'headline') {
          _headlineFocusNode.requestFocus();
        } else if (elementKey == 'leftFooter') {
          if (_current.verticalSplitDividerType == 2) {
            _leftFooterFocusNode.requestFocus();
          } else if (_badgeFocusNodes.isNotEmpty) {
            _badgeFocusNodes[0]?.requestFocus();
          }
        } else if (elementKey == 'rightBlock') {
          _rightSubtitleFocusNode.requestFocus();
        } else if (elementKey == 'rightFooter') {
          _rightFooterFocusNode.requestFocus();
        } else if (elementKey.startsWith('customText_')) {
          final id = elementKey.replaceFirst('customText_', '');
          _customTextFocusNodes[id]?.requestFocus();
        }
      });
    }
  }

  IconData _getNodeIcon(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'light':
      case 'lampada':
      case 'iluminacao':
      case 'lightbulb':
        return Icons.lightbulb_outline_rounded;
      case 'music':
      case 'audio':
      case 'som':
        return Icons.music_note_rounded;
      case 'temp':
      case 'clima':
      case 'climatizacao':
      case 'hvac':
      case 'thermostat':
        return Icons.thermostat_rounded;
      case 'camera':
      case 'monitoramento':
      case 'video':
        return Icons.videocam_outlined;
      case 'lock':
      case 'fechadura':
      case 'acesso':
      case 'biometria':
        return Icons.lock_outline_rounded;
      case 'wifi':
      case 'rede':
        return Icons.wifi_rounded;
      case 'tv':
      case 'cinema':
      case 'theater':
        return Icons.tv_rounded;
      case 'curtain':
      case 'cortina':
      case 'persiana':
        return Icons.curtains_rounded;
      case 'shield':
      case 'seguranca':
        return Icons.security_rounded;
      case 'power':
      case 'energia':
        return Icons.power_settings_new_rounded;
      default:
        return Icons.bolt_rounded;
    }
  }

  void _updateNode(
    String id, {
    String? label,
    String? iconName,
    double? posX,
    double? posY,
    double? targetX,
    double? targetY,
    String? colorHex,
    bool? showConnectorLine,
  }) {
    setState(() {
      _current = _current.copyWith(
        nodes: _current.nodes.map((n) {
          if (n.id == id) {
            return n.copyWith(
              label: label,
              iconName: iconName,
              posX: posX,
              posY: posY,
              targetX: targetX,
              targetY: targetY,
              colorHex: colorHex,
              showConnectorLine: showConnectorLine,
            );
          }
          return n;
        }).toList(),
      );
    });
  }

  void _addCyberNode() {
    final newId = 'node_${DateTime.now().millisecondsSinceEpoch}';
    final newNode = AutomationCyberNode(
      id: newId,
      label: 'Novo Ponto',
      iconName: 'light',
      posX: 0.50,
      posY: 0.35,
      targetX: 0.46,
      targetY: 0.40,
      colorHex: _current.customDividerColor.isNotEmpty ? _current.customDividerColor : '#38BDF8',
      showConnectorLine: true,
    );
    setState(() {
      _current = _current.copyWith(nodes: [..._current.nodes, newNode]);
      _selectedElementKey = 'node_$newId';
    });
    if (_tabController.index != 2) {
      _tabController.animateTo(2);
    }
  }

  void _removeCyberNode(String id) {
    setState(() {
      _current = _current.copyWith(
        nodes: _current.nodes.where((n) => n.id != id).toList(),
      );
      if (_selectedElementKey == 'node_$id' || _selectedElementKey == 'node_target_$id') {
        _selectedElementKey = null;
      }
    });
  }

  void _resetDefaultNodes() {
    setState(() {
      _current = _current.copyWith(
        nodes: AutomationCyberNode.defaultNodes(),
      );
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('5 Nós Inteligentes padrão restaurados com sucesso!'),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }


  void _resetPositions() {
    setState(() {
      _current = _current.copyWith(
        // Vertical Split & Modern compartilhados:
        verticalSplitHeadlineTop: _current.proposalStyle != 'verticalSplit' ? 0.50 : 0.06,
        verticalSplitHeadlineLeft: 0.06,
        verticalSplitRightBlockTop: _current.proposalStyle != 'verticalSplit'
            ? 0.04
            : _current.verticalSplitDividerType == 1
                ? 0.22
                : _current.verticalSplitDividerType == 2
                    ? 0.16
                    : 0.20,
        verticalSplitRightBlockRight: _current.proposalStyle != 'verticalSplit' ? 0.48 : 0.08,
        verticalSplitLeftFooterBottom: _current.proposalStyle != 'verticalSplit' ? 0.26 : 0.04,
        verticalSplitLeftFooterLeft: 0.06,
        verticalSplitRightFooterBottom: 0.04,
        verticalSplitRightFooterRight: _current.proposalStyle != 'verticalSplit' ? 0.50 : 0.08,
        verticalSplitShowHeadline: true,
        verticalSplitShowLeftFooter: true,
        verticalSplitShowRightBlock: true,
        verticalSplitShowRightFooter: true,
        // Modern:
        coverBadgePositionX: 0.08,
        coverBadgePositionY: 0.06,
        coverShowBadge: true,
        coverBadgeColor: '#FFFFFF',
        coverBadgeOpacity: 0.92,
        coverTitleColor: '#0284C7',
        coverSubtitleColor: '#0F172A',
        coverTitleFontSize: 26.0,
        coverSubtitleFontSize: 11.0,
        customDividerStyle: 0,
        customDividerColor: '#0284C7',
        customDividerBottomColor: '#FFFFFF',
        // Dados do Cliente:
        coverClientInfoPositionX: 0.58,
        coverClientInfoPositionY: 0.88,
        coverClientInfoWidth: 240.0,
        coverClientInfoFontSize: 8.5,
        coverClientInfoColor: '#0F172A',
        coverClientInfoSecondaryColor: '#38BDF8',
        coverShowClientInfo: true,
        // Logo:
        coverShowLogo: true,
        coverLogoPositionX: _current.proposalStyle != 'verticalSplit' ? 0.78 : 0.65,
        coverLogoPositionY: _current.proposalStyle != 'verticalSplit' ? 0.78 : 0.05,
        coverLogoWidth: 95.0,
        // Cabeçalho & Rodapé:
        coverShowHeader: true,
        coverHeaderStyle: 9,
        coverHeaderText1: 'PROPOSTA EXECUTIVA',
        coverHeaderText2: 'AUTOMAÇÃO RESIDENCIAL HIGH-END',
        coverHeaderText3: 'CONFORTO, SEGURANÇA E TECNOLOGIA INTEGRADA',
        coverHeaderBgColor: '#0F172A',
        coverHeaderTextColor: '#FFFFFF',
        coverHeaderIconColor: '#38BDF8',
        coverShowFooter: true,
        coverFooterStyle: 1,
        coverFooterText1: 'A CASA QUE ENTENDE VOCÊ • EXPERIÊNCIA ÚNICA',
        coverFooterText2: '(11) 00000-0000 • contato@suaempresa.com.br',
        coverFooterText3: 'www.suaempresa.com.br',
        coverFooterText4: 'Proposta técnica e comercial válida por 15 dias corridos.',
        coverFooterBgColor: '#0F172A',
        coverFooterTextColor: '#CBD5E1',
        coverFooterIconColor: '#38BDF8',
      );
      _coverTitleCtrl.text = 'PROPOSTA COMERCIAL';
      _coverSubtitleCtrl.text = 'AUTOMAÇÃO RESIDENCIAL HIGH-END';
      _headerText1Ctrl.text = 'PROPOSTA EXECUTIVA';
      _headerText2Ctrl.text = 'AUTOMAÇÃO RESIDENCIAL HIGH-END';
      _headerText3Ctrl.text = 'CONFORTO, SEGURANÇA E TECNOLOGIA INTEGRADA';
      _footerText1Ctrl.text = 'A CASA QUE ENTENDE VOCÊ • EXPERIÊNCIA ÚNICA';
      _footerText2Ctrl.text = '(11) 00000-0000 • contato@suaempresa.com.br';
      _footerText3Ctrl.text = 'www.suaempresa.com.br';
      _footerText4Ctrl.text = 'Proposta técnica e comercial válida por 15 dias corridos.';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Posições e elementos da capa restaurados para o padrão com sucesso!'),
        backgroundColor: Color(0xFF0F172A),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _pickCustomCoverPhoto() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      );

      if (files.isNotEmpty) {
        final bytes = await files.first.readAsBytes();
        final b64 = base64Encode(bytes);
        setState(() {
          _current = _current.copyWith(
            customCoverImageBase64: b64,
            isCustomCoverMode: true,
          );
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Foto da capa carregada com sucesso!'),
              backgroundColor: Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[AutomationCoverCustomizerDialog] Erro ao selecionar foto: $e');
    }
  }

  Widget _buildFontFamilySelector({
    required String label,
    required String selectedFont,
    required ValueChanged<String> onSelect,
  }) {
    const availableFonts = [
      'Montserrat',
      'Roboto',
      'Inter',
      'Outfit',
      'Oswald',
      'Poppins',
      'Playfair Display',
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.font_download_outlined, color: Color(0xFF38BDF8), size: 16),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFFCBD5E1)),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF475569)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: availableFonts.contains(selectedFont) ? selectedFont : 'Montserrat',
                isDense: true,
                dropdownColor: const Color(0xFF1E293B),
                icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                items: availableFonts.map((font) {
                  return DropdownMenuItem<String>(
                    value: font,
                    child: Text(
                      font,
                      style: getCoverTextStyle(fontFamily: font, fontSize: 12.5, color: Colors.white),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) onSelect(val);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorChipsRow({
    required String selectedHex,
    required ValueChanged<String> onSelect,
  }) {
    const colors = [
      {'hex': '#FFFFFF', 'name': 'Branco', 'border': true},
      {'hex': '#0F172A', 'name': 'Preto Grafite'},
      {'hex': '#0284C7', 'name': 'Azul Ciano'},
      {'hex': '#2563EB', 'name': 'Azul Royal'},
      {'hex': '#F59E0B', 'name': 'Âmbar Solar'},
      {'hex': '#F97316', 'name': 'Laranja Energia'},
      {'hex': '#10B981', 'name': 'Verde Esmeralda'},
      {'hex': '#8B5CF6', 'name': 'Roxo Tech'},
      {'hex': '#EF4444', 'name': 'Vermelho Rubi'},
      {'hex': '#475569', 'name': 'Cinza Ardósia'},
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: colors.map((c) {
        final hex = c['hex'] as String;
        final isSelected = selectedHex.toUpperCase() == hex.toUpperCase();
        final colorVal = Color(_hexToInt(hex));
        final needsBorder = c['border'] == true;

        return InkWell(
          onTap: () => onSelect(hex),
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: colorVal,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF38BDF8)
                    : needsBorder
                        ? const Color(0xFFCBD5E1)
                        : Colors.transparent,
                width: isSelected ? 2.5 : 1,
              ),
              boxShadow: isSelected
                  ? [BoxShadow(color: colorVal.withValues(alpha: 0.5), blurRadius: 6, offset: const Offset(0, 2))]
                  : null,
            ),
            child: isSelected
                ? Icon(
                    Icons.check,
                    size: 13,
                    color: hex == '#FFFFFF' ? Colors.black : Colors.white,
                  )
                : null,
          ),
        );
      }).toList(),
    );
  }

  void _addCustomText() {
    final newId = 'txt_${DateTime.now().millisecondsSinceEpoch}';
    final newItem = CustomCoverTextItem(
      id: newId,
      text: 'Novo Texto',
      x: 0.35,
      y: 0.48,
      fontSize: 14.0,
      colorValue: 0xFF0F172A,
      isBold: true,
    );
    setState(() {
      _current = _current.copyWith(
        customTextItems: [..._current.customTextItems, newItem],
      );
    });
    _selectAndFocusElement('customText_$newId');
  }

  void _showIconPickerModal() {
    final availableIcons = [
      {'key': 'solar_power', 'name': 'Painel Solar', 'icon': Icons.solar_power_rounded},
      {'key': 'bolt', 'name': 'Raio / Energia', 'icon': Icons.bolt_rounded},
      {'key': 'eco', 'name': 'Sustentabilidade', 'icon': Icons.eco_outlined},
      {'key': 'shield', 'name': 'Garantia / Proteção', 'icon': Icons.shield_outlined},
      {'key': 'verified', 'name': 'Qualidade / Check', 'icon': Icons.verified_rounded},
      {'key': 'star', 'name': 'Destaque / Estrela', 'icon': Icons.star_rounded},
      {'key': 'home', 'name': 'Residencial', 'icon': Icons.home_outlined},
      {'key': 'phone', 'name': 'Telefone / WhatsApp', 'icon': Icons.phone_rounded},
      {'key': 'location', 'name': 'Localização', 'icon': Icons.location_on_rounded},
      {'key': 'mail', 'name': 'E-mail', 'icon': Icons.mail_outline_rounded},
      {'key': 'lightbulb', 'name': 'Lâmpada / Ideia', 'icon': Icons.lightbulb_outline_rounded},
      {'key': 'handshake', 'name': 'Parceria', 'icon': Icons.handshake_outlined},
      {'key': 'award', 'name': 'Prêmio / Troféu', 'icon': Icons.emoji_events_outlined},
      {'key': 'engineering', 'name': 'Engenharia', 'icon': Icons.engineering_rounded},
      {'key': 'coins', 'name': 'Economia Financeira', 'icon': Icons.monetization_on_outlined},
      {'key': 'chart', 'name': 'Gráfico de Valorização', 'icon': Icons.bar_chart_rounded},
    ];

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFF334155))),
        child: Container(
          width: 560,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Selecione o Ícone para Adicionar na Capa',
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(color: Color(0xFF334155)),
              const SizedBox(height: 12),
              SizedBox(
                height: 320,
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.1,
                  ),
                  itemCount: availableIcons.length,
                  itemBuilder: (c, idx) {
                    final item = availableIcons[idx];
                    return InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        _addCustomIcon(item['key'] as String);
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(item['icon'] as IconData, color: const Color(0xFFEAB308), size: 28),
                            const SizedBox(height: 6),
                            Text(
                              item['name'] as String,
                              style: GoogleFonts.inter(fontSize: 10.5, color: Colors.white70, fontWeight: FontWeight.w600),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBadgeIconPickerModal(int badgeIndex) {
    final availableIcons = [
      {'key': 'solar_power', 'name': 'Painel Solar', 'icon': Icons.solar_power_rounded},
      {'key': 'bolt', 'name': 'Raio / Energia', 'icon': Icons.bolt_rounded},
      {'key': 'eco', 'name': 'Sustentabilidade', 'icon': Icons.eco_outlined},
      {'key': 'shield', 'name': 'Garantia / Proteção', 'icon': Icons.shield_outlined},
      {'key': 'verified', 'name': 'Qualidade / Check', 'icon': Icons.verified_rounded},
      {'key': 'star', 'name': 'Destaque / Estrela', 'icon': Icons.star_rounded},
      {'key': 'home', 'name': 'Residencial', 'icon': Icons.home_outlined},
      {'key': 'phone', 'name': 'Telefone / WhatsApp', 'icon': Icons.phone_rounded},
      {'key': 'location', 'name': 'Localização', 'icon': Icons.location_on_rounded},
      {'key': 'mail', 'name': 'E-mail', 'icon': Icons.mail_outline_rounded},
      {'key': 'lightbulb', 'name': 'Lâmpada / Ideia', 'icon': Icons.lightbulb_outline_rounded},
      {'key': 'handshake', 'name': 'Parceria', 'icon': Icons.handshake_outlined},
      {'key': 'award', 'name': 'Prêmio / Troféu', 'icon': Icons.emoji_events_outlined},
      {'key': 'engineering', 'name': 'Engenharia', 'icon': Icons.engineering_rounded},
      {'key': 'coins', 'name': 'Economia Financeira', 'icon': Icons.monetization_on_outlined},
      {'key': 'chart', 'name': 'Gráfico de Valorização', 'icon': Icons.bar_chart_rounded},
    ];

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFF334155))),
        child: Container(
          width: 560,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Selecione o Ícone para o Badge',
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(color: Color(0xFF334155)),
              const SizedBox(height: 12),
              SizedBox(
                height: 320,
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.1,
                  ),
                  itemCount: availableIcons.length,
                  itemBuilder: (c, idx) {
                    final item = availableIcons[idx];
                    return InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() {
                          final list = List<CoverFooterBadge>.from(_current.verticalSplitFooterBadges);
                          if (badgeIndex >= 0 && badgeIndex < list.length) {
                            list[badgeIndex] = list[badgeIndex].copyWith(iconKey: item['key'] as String);
                            _current = _current.copyWith(verticalSplitFooterBadges: list);
                          }
                        });
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(item['icon'] as IconData, color: const Color(0xFFEAB308), size: 28),
                            const SizedBox(height: 6),
                            Text(
                              item['name'] as String,
                              style: GoogleFonts.inter(fontSize: 10.5, color: Colors.white70, fontWeight: FontWeight.w600),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addBadge() {
    setState(() {
      final list = List<CoverFooterBadge>.from(_current.verticalSplitFooterBadges);
      list.add(const CoverFooterBadge(iconKey: 'eco', label: 'NOVO BADGE'));
      _current = _current.copyWith(verticalSplitFooterBadges: list);
    });
  }

  void _removeBadge(int index) {
    setState(() {
      final list = List<CoverFooterBadge>.from(_current.verticalSplitFooterBadges);
      if (index >= 0 && index < list.length) {
        list.removeAt(index);
        _current = _current.copyWith(verticalSplitFooterBadges: list);
      }
    });
  }

  void _addCustomIcon(String iconKey) {
    final newId = 'ico_${DateTime.now().millisecondsSinceEpoch}';
    final newItem = CustomCoverIconItem(
      id: newId,
      iconKey: iconKey,
      x: 0.45,
      y: 0.48,
      size: 28.0,
      colorValue: 0xFFEAB308,
    );
    setState(() {
      _current = _current.copyWith(
        customIconItems: [..._current.customIconItems, newItem],
      );
      _selectedElementKey = 'customIcon_$newId';
    });
  }

  void _removeCustomText(String id) {
    setState(() {
      _current = _current.copyWith(
        customTextItems: _current.customTextItems.where((t) => t.id != id).toList(),
      );
      if (_selectedElementKey == 'customText_$id') {
        _selectedElementKey = null;
      }
    });
  }

  void _removeCustomIcon(String id) {
    setState(() {
      _current = _current.copyWith(
        customIconItems: _current.customIconItems.where((i) => i.id != id).toList(),
      );
      if (_selectedElementKey == 'customIcon_$id') {
        _selectedElementKey = null;
      }
    });
  }

  Future<void> _pickCompanyLogo() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
      );
      if (files.isNotEmpty) {
        final bytes = await files.first.readAsBytes();
        final base64Str = base64Encode(bytes);
        setState(() {
          _current = _current.copyWith(
            companyLogoBase64: base64Str,
            coverShowLogo: true,
          );
        });
      }
    } catch (_) {}
  }

  void _syncAllControllersToCurrent() {
    _current = _current.copyWith(
      verticalSplitHeadline: _headlineCtrl.text,
      verticalSplitSubheadline: _subheadlineCtrl.text,
      verticalSplitRightTitle: _rightTitleCtrl.text,
      verticalSplitRightSubtitle: _rightSubtitleCtrl.text,
      verticalSplitRightTagline: _rightTaglineCtrl.text,
      verticalSplitLeftFooter: _leftFooterCtrl.text,
      verticalSplitRightFooter: _rightFooterCtrl.text,
      coverTitle: _coverTitleCtrl.text,
      coverSubtitle: _coverSubtitleCtrl.text,
      coverHeaderText1: _headerText1Ctrl.text,
      coverHeaderText2: _headerText2Ctrl.text,
      coverHeaderText3: _headerText3Ctrl.text,
      coverFooterText1: _footerText1Ctrl.text,
      coverFooterText2: _footerText2Ctrl.text,
      coverFooterText3: _footerText3Ctrl.text,
      coverFooterText4: _footerText4Ctrl.text,
    );
  }

  void _previewPdf() {
    _syncAllControllersToCurrent();

    final sampleProposal = ProposalModel(
      id: 'preview_id',
      proposalNumber: 'PROP-2026/001',
      title: 'Proposta Comercial de Automação Residencial',
      clientName: _current.clientName.isNotEmpty ? _current.clientName : 'Cliente Exemplo Proposta',
      clientEmail: 'cliente@exemplo.com.br',
      clientPhone: '(11) 98765-4321',
      subtotal: 24500.0,
      totalAmount: 24500.0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      status: ProposalStatus.negotiating,
      items: [
        ProposalItemModel(
          name: 'Sistema de Automação Residencial High-End',
          quantity: 1,
          unitPrice: 24500.0,
          totalPrice: 24500.0,
        ),
      ],
    );

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 900,
          height: 750,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Prévia Instantânea do PDF (Automação Residencial)',
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: PdfPreview(
                  build: (format) => AutomationProposalPdfService.generateProposalPdf(
                    settings: _current,
                    proposal: sampleProposal,
                  ),
                  allowPrinting: true,
                  allowSharing: true,
                  canChangePageFormat: false,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _saveAndApply() async {
    _syncAllControllersToCurrent();
    setState(() => _isSaving = true);
    try {
      await AutomationSettingsService.saveSettings(_current);
      widget.onSave(_current);
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text('Configurações e alterações salvas com sucesso!'),
              ],
            ),
            backgroundColor: Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar configurações: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      backgroundColor: Colors.transparent,
      child: Container(
        width: 1320,
        height: 880,
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── CABEÇALHO DO ESTÚDIO ─────────────────────────────────────────
            _buildHeader(),

            // ── CORPO PRINCIPAL (CANVAS INTERATIVO + PAINEL DE CONTROLES) ────
            Expanded(
              child: Row(
                children: [
                  // LADO ESQUERDO: CANVAS A4 INTERATIVO (DRAG & DROP)
                  Expanded(
                    flex: 5,
                    child: _buildInteractiveCanvasArea(),
                  ),

                  // DIVISOR
                  Container(width: 1, color: const Color(0xFF1E293B)),

                  // LADO DIREITO: INSPECTOR EM TEMPO REAL
                  Expanded(
                    flex: 6,
                    child: _buildInspectorPanel(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(bottom: BorderSide(color: Color(0xFF334155))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFEAB308), Color(0xFFCA8A04)]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.palette_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Estúdio Visual da Capa • Personalização Livre em Tempo Real (Automação Residencial)',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                'Arraste qualquer texto ou elemento na folha A4 e veja o resultado idêntico ao PDF gerado',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
          const Spacer(),

          // Botão Resetar (Apenas Ícone)
          Tooltip(
            message: 'Resetar posições',
            child: OutlinedButton(
              onPressed: _resetPositions,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFCBD5E1),
                side: const BorderSide(color: Color(0xFF475569)),
                padding: const EdgeInsets.all(10),
                minimumSize: const Size(38, 38),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Icon(Icons.restart_alt_rounded, size: 18),
            ),
          ),
          const SizedBox(width: 8),

          // Botão Prévia PDF
          ElevatedButton.icon(
            onPressed: _previewPdf,
            icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
            label: const Text('PRÉVIA PDF'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 8),

          // Botão Salvar
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveAndApply,
            icon: _isSaving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.check_circle_rounded, size: 16),
            label: Text(_isSaving ? 'SALVANDO...' : 'SALVAR & APLICAR'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 10),

          // Fechar
          IconButton(
            tooltip: 'Fechar',
            icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
            onPressed: () => Navigator.pop(context, _current),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // CANVAS A4 INTERATIVO COM DRAG & DROP LIVRE
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildInteractiveCanvasArea() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (_selectedElementKey != null) {
          setState(() => _selectedElementKey = null);
        }
      },
      child: Container(
        color: const Color(0xFF0B1120),
      child: Center(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: LayoutBuilder(
            builder: (ctx, constraints) {
              // Altura disponível e escala do canvas (levemente reduzido para acomodar aba Páginas com folga)
              final maxH = 610.0;
              final scale = maxH / a4Height;
              final canvasW = a4Width * scale;
              final canvasH = maxH;

              // ── SELECIONADA PÁGINA 2 OU ABA PÁGINAS COM PÁGINA 2 ATIVA ──
              if (_activeCustomizerPageId == 'page_2') {
                return Container(
                  width: canvasW,
                  height: canvasH,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.6),
                        blurRadius: 25,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CoverPage2InteractiveCanvas(
                      width: canvasW,
                      height: canvasH,
                      scale: scale,
                      isSolar: false,
                      primaryColor: Color(_hexToInt(_current.verticalSplitAccentColor, fallback: 0xFF38BDF8)),
                      cards: _current.page2Cards,
                      selectedCardId: _selectedPage2CardId,
                      onSelectCard: (cId) {
                        setState(() {
                          _selectedPage2CardId = cId;
                          if (_tabController.index != 5) {
                            _tabController.animateTo(5);
                          }
                        });
                      },
                      showHeader: _current.coverShowHeader,
                      headerStyle: _current.coverHeaderStyle,
                      headerText1: _current.coverHeaderText1,
                      headerText2: _current.coverHeaderText2,
                      headerText3: _current.coverHeaderText3,
                      headerBgColor: _current.coverHeaderBgColor,
                      headerTextColor: _current.coverHeaderTextColor,
                      headerIconColor: _current.coverHeaderIconColor,
                      showFooter: _current.coverShowFooter,
                      footerStyle: _current.coverFooterStyle,
                      footerText1: _current.coverFooterText1,
                      footerText2: _current.coverFooterText2,
                      footerText3: _current.coverFooterText3,
                      footerText4: _current.coverFooterText4,
                      footerBgColor: _current.coverFooterBgColor,
                      footerTextColor: _current.coverFooterTextColor,
                      footerIconColor: _current.coverFooterIconColor,
                      showIllustration: _current.page2ShowIllustration,
                      illustrationType: _current.page2IllustrationType,
                    ),
                  ),
                );
              }

              // ── SELECIONADA PÁGINA CUSTOMIZADA CRIADA PELO USUÁRIO ──
              if (_activeCustomizerPageId.startsWith('custom_')) {
                final customPage = _current.customPages.firstWhere(
                  (cp) => cp.id == _activeCustomizerPageId,
                  orElse: () => ProposalCustomPage(id: _activeCustomizerPageId, title: 'Nova Página Personalizada'),
                );
                return Container(
                  width: canvasW,
                  height: canvasH,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.6),
                        blurRadius: 25,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CoverCustomPageInteractiveCanvas(
                      width: canvasW,
                      height: canvasH,
                      scale: scale,
                      page: customPage,
                      primaryColor: Color(_hexToInt(_current.verticalSplitAccentColor, fallback: 0xFF38BDF8)),
                      showHeader: _current.coverShowHeader,
                      headerStyle: _current.coverHeaderStyle,
                      headerText1: _current.coverHeaderText1,
                      headerText2: _current.coverHeaderText2,
                      headerText3: _current.coverHeaderText3,
                      headerBgColor: _current.coverHeaderBgColor,
                      headerTextColor: _current.coverHeaderTextColor,
                      headerIconColor: _current.coverHeaderIconColor,
                      showFooter: _current.coverShowFooter,
                      footerStyle: _current.coverFooterStyle,
                      footerText1: _current.coverFooterText1,
                      footerText2: _current.coverFooterText2,
                      footerText3: _current.coverFooterText3,
                      footerText4: _current.coverFooterText4,
                      footerBgColor: _current.coverFooterBgColor,
                      footerTextColor: _current.coverFooterTextColor,
                      footerIconColor: _current.coverFooterIconColor,
                    ),
                  ),
                );
              }

              // ── SELECIONADA PÁGINA 3 ESPECÍFICA (PORTFÓLIO & CLIENTES) ──
              if (_activeCustomizerPageId == 'page_3') {
                return _buildPage3CanvasPreview(canvasW, canvasH, scale);
              }

              // ── SELECIONADA PÁGINA 4 ESPECÍFICA (AMBIENTES & CARDS DA PROPOSTA WEB) ──
              if (_activeCustomizerPageId == 'page_4') {
                return _buildPage4CanvasPreview(canvasW, canvasH, scale);
              }

              // ── SELECIONADAS PÁGINAS INTERNAS (PÁG 3, 5) OU ABA CABEÇALHO/RODAPÉ (INDEX == 3) ──
              if (_tabController.index == 3 || _activeCustomizerPageId.startsWith('page_3') || _activeCustomizerPageId.startsWith('page_4') || _activeCustomizerPageId.startsWith('page_5')) {
                final pNum = _activeCustomizerPageId.replaceAll('page_', '');
                return Container(
                  width: canvasW,
                  height: canvasH,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.6),
                        blurRadius: 25,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CoverInternalPageDemo(
                      width: canvasW,
                      height: canvasH,
                      scale: scale,
                      showHeader: _current.coverShowHeader,
                      headerStyleId: _current.coverHeaderStyle,
                      headerText1: _current.coverHeaderText1,
                      headerText2: _current.coverHeaderText2,
                      headerText3: _activeCustomizerPageId != 'page_1' ? 'Página $pNum de 5' : _current.coverHeaderText3,
                      headerBgColor: _current.coverHeaderBgColor,
                      headerTextColor: _current.coverHeaderTextColor,
                      headerIconColor: _current.coverHeaderIconColor,
                      showFooter: _current.coverShowFooter,
                      footerStyleId: _current.coverFooterStyle,
                      footerText1: _current.coverFooterText1,
                      footerText2: _current.coverFooterText2,
                      footerText3: _current.coverFooterText3,
                      footerText4: _activeCustomizerPageId != 'page_1' ? 'Página $pNum de 5' : _current.coverFooterText4,
                      footerBgColor: _current.coverFooterBgColor,
                      footerTextColor: _current.coverFooterTextColor,
                      footerIconColor: _current.coverFooterIconColor,
                      accentColor: Color(_hexToInt(_current.verticalSplitAccentColor, fallback: 0xFF38BDF8)),
                    ),
                  ),
                );
              }

              return Container(
                width: canvasW,
                height: canvasH,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: 25,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    clipBehavior: Clip.none,
                    fit: StackFit.expand,
                    children: [
                      // ── 1. RENDERIZAÇÃO DA CAPA BASE (VERTICAL SPLIT OU MODERN) ──
                      if (_current.proposalStyle == 'verticalSplit') ...[
                        // Capa Vertical Split Renderizada em tempo real
                        AutomationVerticalSplitCoverView(
                          settings: _current,
                          width: canvasW,
                          height: canvasH,
                          clientName: 'João da Silva Santos',
                          proposalNumber: 'PROP-2026/001',
                        ),

                        // Linhas Cibernéticas Neon dos Nós de Automação (Vertical Split)
                        if (_current.nodes.isNotEmpty)
                          CustomPaint(
                            size: Size(canvasW, canvasH),
                            painter: AutomationCyberConnectorPainter(
                              nodes: _current.nodes,
                              primaryColor: Color(_hexToInt(_current.customDividerColor.isNotEmpty ? _current.customDividerColor : '#38BDF8')),
                              selectedNodeId: _selectedElementKey?.startsWith('node_') == true
                                  ? _selectedElementKey!.replaceFirst('node_target_', '').replaceFirst('node_', '')
                                  : null,
                            ),
                          ),

                        // Desselecionar ao clicar na foto da capa
                        Positioned.fill(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              if (_selectedElementKey != null) {
                                setState(() => _selectedElementKey = null);
                              }
                            },
                          ),
                        ),

                        // Bloco 1: Headline Esquerda
                        if (_current.verticalSplitShowHeadline)
                          _buildDraggableHandle(
                            elementKey: 'headline',
                            label: '📌 Título da Foto',
                            left: _current.verticalSplitHeadlineLeft * canvasW,
                            top: _current.verticalSplitHeadlineTop * canvasH,
                            width: canvasW * 0.44,
                            height: 110 * scale,
                            onDelete: () => setState(() => _current = _current.copyWith(verticalSplitShowHeadline: false)),
                            onDrag: (dx, dy) {
                              setState(() {
                                final newLeft = ((_current.verticalSplitHeadlineLeft * canvasW) + dx) / canvasW;
                                final newTop = ((_current.verticalSplitHeadlineTop * canvasH) + dy) / canvasH;
                                _current = _current.copyWith(
                                  verticalSplitHeadlineLeft: newLeft.clamp(-1.50, 2.50),
                                  verticalSplitHeadlineTop: newTop.clamp(-1.50, 2.50),
                                );
                              });
                            },
                          ),

                        // Bloco 2: Rodapé Esquerdo
                        if (_current.verticalSplitShowLeftFooter)
                          Builder(
                            builder: (context) {
                              final footerW = _current.verticalSplitLeftFooterWidth.clamp(0.20, 0.95) * canvasW;
                              final double footerH;
                              if (_current.verticalSplitDividerType == 2) {
                                footerH = 32.0 * scale;
                              } else if (_current.verticalSplitBadgesLayout == 'vertical') {
                                footerH = (math.max(1, _current.verticalSplitFooterBadges.length) * 24.0 + 12.0) * scale;
                              } else if (_current.verticalSplitBadgesLayout == 'wrap') {
                                footerH = 54.0 * scale;
                              } else {
                                footerH = 38.0 * scale;
                              }

                              return _buildDraggableHandle(
                                elementKey: 'leftFooter',
                                label: '📌 Rodapé Foto / Badges',
                                left: _current.verticalSplitLeftFooterLeft * canvasW,
                                top: canvasH - (_current.verticalSplitLeftFooterBottom * canvasH) - footerH,
                                width: footerW,
                                height: footerH,
                                onDelete: () => setState(() => _current = _current.copyWith(verticalSplitShowLeftFooter: false)),
                                onResizeWidth: (dw) {
                                  setState(() {
                                    final newW = ((_current.verticalSplitLeftFooterWidth * canvasW) + dw) / canvasW;
                                    _current = _current.copyWith(
                                      verticalSplitLeftFooterWidth: newW.clamp(0.20, 0.95),
                                    );
                                  });
                                },
                                onDrag: (dx, dy) {
                                  setState(() {
                                    final newLeft = ((_current.verticalSplitLeftFooterLeft * canvasW) + dx) / canvasW;
                                    final currentBottomPx = _current.verticalSplitLeftFooterBottom * canvasH;
                                    final newBottom = (currentBottomPx - dy) / canvasH;
                                    _current = _current.copyWith(
                                      verticalSplitLeftFooterLeft: newLeft.clamp(-1.50, 2.50),
                                      verticalSplitLeftFooterBottom: newBottom.clamp(-1.50, 2.50),
                                    );
                                  });
                                },
                              );
                            },
                          ),

                        // Bloco 3: Proposta Solar (Direita)
                        if (_current.verticalSplitShowRightBlock)
                          _buildDraggableHandle(
                            elementKey: 'rightBlock',
                            label: '📌 Proposta de Automação',
                            left: canvasW - (_current.verticalSplitRightBlockRight * canvasW) - (canvasW * 0.42),
                            top: _current.verticalSplitRightBlockTop * canvasH,
                            width: canvasW * 0.42,
                            height: 160 * scale,
                            onDelete: () => setState(() => _current = _current.copyWith(verticalSplitShowRightBlock: false)),
                            onDrag: (dx, dy) {
                              setState(() {
                                final currentRightPx = _current.verticalSplitRightBlockRight * canvasW;
                                final newRight = (currentRightPx - dx) / canvasW;
                                final newTop = ((_current.verticalSplitRightBlockTop * canvasH) + dy) / canvasH;
                                _current = _current.copyWith(
                                  verticalSplitRightBlockRight: newRight.clamp(-1.50, 2.50),
                                  verticalSplitRightBlockTop: newTop.clamp(-1.50, 2.50),
                                );
                              });
                            },
                          ),

                        // Bloco 4: Rodapé Direito
                        if (_current.verticalSplitShowRightFooter)
                          _buildDraggableHandle(
                            elementKey: 'rightFooter',
                            label: '📌 Rodapé Institucional',
                            left: canvasW - (_current.verticalSplitRightFooterRight * canvasW) - (canvasW * 0.40),
                            top: canvasH - (_current.verticalSplitRightFooterBottom * canvasH) - (45 * scale),
                            width: canvasW * 0.40,
                            height: 45 * scale,
                            onDelete: () => setState(() => _current = _current.copyWith(verticalSplitShowRightFooter: false)),
                            onDrag: (dx, dy) {
                              setState(() {
                                final currentRightPx = _current.verticalSplitRightFooterRight * canvasW;
                                final newRight = (currentRightPx - dx) / canvasW;
                                final currentBottomPx = _current.verticalSplitRightFooterBottom * canvasH;
                                final newBottom = (currentBottomPx - dy) / canvasH;
                                _current = _current.copyWith(
                                  verticalSplitRightFooterRight: newRight.clamp(-1.50, 2.50),
                                  verticalSplitRightFooterBottom: newBottom.clamp(-1.50, 2.50),
                                );
                              });
                            },
                          ),
                      ] else ...[
                        // ── Capa Modern Renderizada em tempo real ──
                        // 1. Imagem de Fundo (mantém a foto escolhida na galeria ou upload)
                        if (_current.customCoverImageBase64 != null &&
                            _current.customCoverImageBase64!.isNotEmpty)
                          Builder(
                            builder: (context) {
                              final bytes = _getCoverBytes(_current.customCoverImageBase64);
                              if (bytes == null) return Container(color: const Color(0xFF0F172A));
                              return Image.memory(
                                bytes,
                                fit: BoxFit.cover,
                                width: canvasW,
                                height: canvasH,
                              );
                            },
                          )
                        else
                          Image.network(
                            AutomationSettingsService.getBigCoverUrl(_current.selectedCoverTemplate),
                            fit: BoxFit.cover,
                            width: canvasW,
                            height: canvasH,
                            errorBuilder: (_, __, ___) => Container(color: const Color(0xFF0F172A)),
                          ),

                        // 2. Separador Vetorial / Decalque da Foto (SOMENTE se houver divisor selecionado)
                        if (_current.customDividerStyle >= 0)
                          CustomPaint(
                            size: Size(canvasW, canvasH),
                            painter: SolarCoverDividerPainter(
                              dividerType: _current.customDividerStyle,
                              primaryColor: Color(_hexToInt(_current.customDividerColor)),
                              bottomAreaColor: Color(_hexToInt(_current.customDividerBottomColor)),
                              splitYRatio: 0.70,
                            ),
                          ),

                        // 2.1. Linhas Cibernéticas Neon dos Nós de Automação (Modern)
                        if (_current.nodes.isNotEmpty)
                          CustomPaint(
                            size: Size(canvasW, canvasH),
                            painter: AutomationCyberConnectorPainter(
                              nodes: _current.nodes,
                              primaryColor: Color(_hexToInt(_current.customDividerColor.isNotEmpty ? _current.customDividerColor : '#38BDF8')),
                              selectedNodeId: _selectedElementKey?.startsWith('node_') == true
                                  ? _selectedElementKey!.replaceFirst('node_target_', '').replaceFirst('node_', '')
                                  : null,
                            ),
                          ),

                        // Desselecionar ao clicar na foto da capa
                        Positioned.fill(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              if (_selectedElementKey != null) {
                                setState(() => _selectedElementKey = null);
                              }
                            },
                          ),
                        ),

                        // ── ELEMENTOS CUSTOMIZÁVEIS E ARRASTÁVEIS DO ESTILO MODERN ──
                        // 3. Frase de Impacto / Headline na Área da Foto (como no Split)
                        if (_current.verticalSplitShowHeadline && _current.verticalSplitHeadline.trim().isNotEmpty) ...[
                          Positioned(
                            top: _current.verticalSplitHeadlineTop * canvasH,
                            left: _current.verticalSplitHeadlineLeft * canvasW,
                            child: IgnorePointer(
                              child: SizedBox(
                                width: canvasW * 0.70,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _current.verticalSplitHeadline.trim(),
                                      style: getCoverTextStyle(
                                        fontFamily: _current.coverHeadlineFont,
                                        fontSize: 20.0 * scale,
                                        fontWeight: FontWeight.w900,
                                        color: Color(_current.coverHeadlineColorValue),
                                        height: 1.15,
                                        letterSpacing: 0.8,
                                        shadows: const [
                                          Shadow(color: Colors.black87, blurRadius: 8, offset: Offset(0, 2)),
                                        ],
                                      ),
                                    ),
                                    if (_current.verticalSplitShowHeadlineDivider) ...[
                                      SizedBox(height: 6 * scale),
                                      Container(
                                        width: (_current.verticalSplitHeadlineDividerWidth * 0.9 * scale).clamp(10.0, 300.0),
                                        height: (_current.verticalSplitHeadlineDividerHeight * 0.9 * scale).clamp(1.0, 20.0),
                                        decoration: BoxDecoration(
                                          color: Color(_current.verticalSplitHeadlineDividerColorValue),
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),
                                    ],
                                    if (_current.verticalSplitSubheadline.trim().isNotEmpty) ...[
                                      SizedBox(height: 8 * scale),
                                      Text(
                                        _current.verticalSplitSubheadline.trim(),
                                        style: getCoverTextStyle(
                                          fontFamily: _current.coverHeadlineFont,
                                          fontSize: 10.0 * scale,
                                          fontWeight: FontWeight.w700,
                                          color: Color(_current.coverHeadlineColorValue).withValues(alpha: 0.95),
                                          height: 1.35,
                                          letterSpacing: 0.6,
                                          shadows: const [
                                            Shadow(color: Colors.black87, blurRadius: 6, offset: Offset(0, 1)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                          _buildDraggableHandle(
                            elementKey: 'headline',
                            label: '📌 Título da Foto',
                            left: _current.verticalSplitHeadlineLeft * canvasW,
                            top: _current.verticalSplitHeadlineTop * canvasH,
                            width: canvasW * 0.70,
                            height: 110 * scale,
                            onDelete: () => setState(() => _current = _current.copyWith(verticalSplitShowHeadline: false)),
                            onDrag: (dx, dy) {
                              setState(() {
                                final newLeft = ((_current.verticalSplitHeadlineLeft * canvasW) + dx) / canvasW;
                                final newTop = ((_current.verticalSplitHeadlineTop * canvasH) + dy) / canvasH;
                                _current = _current.copyWith(
                                  verticalSplitHeadlineLeft: newLeft.clamp(-1.50, 2.50),
                                  verticalSplitHeadlineTop: newTop.clamp(-1.50, 2.50),
                                );
                              });
                            },
                          ),
                        ],

                        // 4. Badges Informativos sobre a foto
                        ..._buildModernBadges(canvasW, canvasH, scale),

                        // 5. Bloco Institucional Limpo na Área Branca Inferior (Igual ao Split)
                        ..._buildModernRightBlock(canvasW, canvasH, scale),

                        // 6. Rodapé Informativo na Área Branca Preservada da Capa Modern
                        ..._buildModernRightFooter(canvasW, canvasH, scale),

                        // 7. Dados do Cliente, CPF/CNPJ e Solução (Arrastável, Redimensionável e Cores Editáveis)
                        ..._buildModernClientInfo(canvasW, canvasH, scale),
                      ],

                      // ── 2. LOGOMARCA (COMUM AOS DOIS ESTILOS) ──
                      if (_current.coverShowLogo &&
                          _current.companyLogoBase64 != null &&
                          _current.companyLogoBase64!.isNotEmpty) ...[
                        if (_current.proposalStyle != 'verticalSplit')
                          Positioned(
                            left: (_current.coverLogoPositionX * canvasW)
                                .clamp(0.0, canvasW - (_current.coverLogoWidth * scale)),
                            top: (_current.coverLogoPositionY * canvasH)
                                .clamp(0.0, canvasH * 0.85),
                            child: IgnorePointer(
                              child: Container(
                                width: (_current.coverLogoWidth * scale).clamp(40.0, 250.0),
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.22),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFF38BDF8).withValues(alpha: 0.8),
                                    width: 1.5,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
                                  ],
                                ),
                                child: Builder(
                                  builder: (context) {
                                    final bytes = _getLogoBytes(_current.companyLogoBase64);
                                    if (bytes == null) return const SizedBox();
                                    return Image.memory(
                                      bytes,
                                      width: (_current.coverLogoWidth * scale).clamp(40.0, 250.0),
                                      fit: BoxFit.contain,
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        _buildDraggableHandle(
                          elementKey: 'logo',
                          label: '📌 Logomarca',
                          left: _current.coverLogoPositionX * canvasW,
                          top: _current.coverLogoPositionY * canvasH,
                          width: (_current.coverLogoWidth * scale).clamp(40.0, 250.0),
                          height: 50 * scale,
                          onDelete: () => setState(() => _current = _current.copyWith(coverShowLogo: false)),
                          onDrag: (dx, dy) {
                            setState(() {
                              final newLeft = ((_current.coverLogoPositionX * canvasW) + dx) / canvasW;
                              final newTop = ((_current.coverLogoPositionY * canvasH) + dy) / canvasH;
                              _current = _current.copyWith(
                                coverLogoPositionX: newLeft.clamp(-1.50, 2.50),
                                coverLogoPositionY: newTop.clamp(-1.50, 2.50),
                              );
                            });
                          },
                        ),
                      ],

                      // ── 3. TEXTOS PERSONALIZADOS EXTRAS (COMUM AOS DOIS ESTILOS) ──
                      if (_current.proposalStyle != 'verticalSplit')
                        for (final textItem in _current.customTextItems)
                          Positioned(
                            left: textItem.x * canvasW,
                            top: textItem.y * canvasH,
                            child: IgnorePointer(
                              child: Text(
                                textItem.text,
                                style: GoogleFonts.outfit(
                                  fontSize: textItem.fontSize * scale,
                                  fontWeight: textItem.isBold ? FontWeight.w800 : FontWeight.w500,
                                  color: Color(textItem.colorValue),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                      for (final textItem in _current.customTextItems)
                        _buildDraggableHandle(
                          elementKey: 'customText_${textItem.id}',
                          label: '✏️ ${textItem.text.split('\n').first.trim().isEmpty ? 'Texto' : textItem.text.split('\n').first.trim()}',
                          left: textItem.x * canvasW,
                          top: textItem.y * canvasH,
                          width: 140 * scale,
                          height: (textItem.fontSize * 1.6 + 12) * scale,
                          onDelete: () => _removeCustomText(textItem.id),
                          onDrag: (dx, dy) {
                            setState(() {
                              final newLeft = ((textItem.x * canvasW) + dx) / canvasW;
                              final newTop = ((textItem.y * canvasH) + dy) / canvasH;
                              _current = _current.copyWith(
                                customTextItems: _current.customTextItems.map((t) {
                                  if (t.id == textItem.id) {
                                    return t.copyWith(
                                      x: newLeft.clamp(-1.50, 2.50),
                                      y: newTop.clamp(-1.50, 2.50),
                                    );
                                  }
                                  return t;
                                }).toList(),
                              );
                            });
                          },
                        ),

                      // ── 4. ÍCONES PERSONALIZADOS EXTRAS (COMUM AOS DOIS ESTILOS) ──
                      if (_current.proposalStyle != 'verticalSplit')
                        for (final iconItem in _current.customIconItems)
                          Positioned(
                            left: iconItem.x * canvasW,
                            top: iconItem.y * canvasH,
                            child: IgnorePointer(
                              child: Icon(
                                getCoverBadgeIcon(iconItem.iconKey),
                                size: iconItem.size * scale,
                                color: Color(iconItem.colorValue),
                              ),
                            ),
                          ),
                      for (final iconItem in _current.customIconItems)
                        _buildDraggableHandle(
                          elementKey: 'customIcon_${iconItem.id}',
                          label: '⚡ Ícone',
                          left: iconItem.x * canvasW,
                          top: iconItem.y * canvasH,
                          width: (iconItem.size + 14) * scale,
                          height: (iconItem.size + 14) * scale,
                          onDelete: () => _removeCustomIcon(iconItem.id),
                          onDrag: (dx, dy) {
                            setState(() {
                              final newLeft = ((iconItem.x * canvasW) + (dx * 2.5)) / canvasW;
                              final newTop = ((iconItem.y * canvasH) + (dy * 2.5)) / canvasH;
                              _current = _current.copyWith(
                                customIconItems: _current.customIconItems.map((i) {
                                  if (i.id == iconItem.id) {
                                    return i.copyWith(
                                      x: newLeft.clamp(-1.50, 2.50),
                                      y: newTop.clamp(-1.50, 2.50),
                                    );
                                  }
                                  return i;
                                }).toList(),
                              );
                            });
                          },
                        ),

                      // ── 5. NÓS CIBERNÉTICOS / PONTOS INTELIGENTES (ARRASRO DO ÍCONE E DO ALVO) ──
                      ..._buildCyberNodesCanvasElements(canvasW, canvasH, scale),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
  }

  List<Widget> _buildModernBadges(double canvasW, double canvasH, double scale) {
    if (!_current.verticalSplitShowLeftFooter || _current.verticalSplitFooterBadges.isEmpty) {
      return const [];
    }

    final footerW = _current.verticalSplitLeftFooterWidth.clamp(0.20, 0.95) * canvasW;
    final footerH = 34.0 * scale;
    final footerTop = canvasH - (_current.verticalSplitLeftFooterBottom * canvasH) - footerH;

    return [
      Positioned(
        left: _current.verticalSplitLeftFooterLeft * canvasW,
        top: footerTop,
        child: IgnorePointer(
          child: SizedBox(
            width: footerW,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < _current.verticalSplitFooterBadges.length; i++) ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          getCoverBadgeIcon(_current.verticalSplitFooterBadges[i].iconKey),
                          color: Color(_current.coverBadgesIconColorValue),
                          size: 14.0 * scale,
                        ),
                        SizedBox(width: 4 * scale),
                        Text(
                          _current.verticalSplitFooterBadges[i].label,
                          style: getCoverTextStyle(
                            fontFamily: _current.coverHeadlineFont,
                            fontSize: 8.5 * scale,
                            fontWeight: FontWeight.w800,
                            color: Color(_current.coverBadgesTextColorValue),
                            letterSpacing: 0.6,
                            shadows: const [
                              Shadow(color: Colors.black87, blurRadius: 6, offset: Offset(0, 1)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (i < _current.verticalSplitFooterBadges.length - 1)
                      Container(
                        width: 1.5,
                        height: 12 * scale,
                        color: Colors.white38,
                        margin: EdgeInsets.symmetric(horizontal: 6 * scale),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      _buildDraggableHandle(
        elementKey: 'leftFooter',
        label: '📌 Rodapé Foto / Badges',
        left: _current.verticalSplitLeftFooterLeft * canvasW,
        top: footerTop,
        width: footerW,
        height: footerH,
        onDelete: () => setState(() => _current = _current.copyWith(verticalSplitShowLeftFooter: false)),
        onResizeWidth: (dw) {
          setState(() {
            final newW = ((_current.verticalSplitLeftFooterWidth * canvasW) + dw) / canvasW;
            _current = _current.copyWith(
              verticalSplitLeftFooterWidth: newW.clamp(0.20, 0.95),
            );
          });
        },
        onDrag: (dx, dy) {
          setState(() {
            final newLeft = ((_current.verticalSplitLeftFooterLeft * canvasW) + dx) / canvasW;
            final currentBottomPx = _current.verticalSplitLeftFooterBottom * canvasH;
            final newBottom = (currentBottomPx - dy) / canvasH;
            _current = _current.copyWith(
              verticalSplitLeftFooterLeft: newLeft.clamp(-1.50, 2.50),
              verticalSplitLeftFooterBottom: newBottom.clamp(-1.50, 2.50),
            );
          });
        },
      ),
    ];
  }

  List<Widget> _buildModernRightBlock(double canvasW, double canvasH, double scale) {
    if (!_current.verticalSplitShowRightBlock) return const [];

    final blockLeft = canvasW - (_current.verticalSplitRightBlockRight * canvasW) - (canvasW * 0.42);
    final blockTop = _current.verticalSplitRightBlockTop * canvasH;

    return [
      Positioned(
        left: blockLeft,
        top: blockTop,
        child: IgnorePointer(
          child: SizedBox(
            width: canvasW * 0.42,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _current.verticalSplitRightTitle,
                  style: getCoverTextStyle(
                    fontFamily: _current.coverRightBlockFont,
                    fontSize: 13.0 * scale,
                    fontWeight: FontWeight.w700,
                    color: Color(_current.coverRightTitleColorValue),
                    letterSpacing: 4.0,
                  ),
                ),
                SizedBox(height: 2 * scale),
                Text(
                  _current.verticalSplitRightSubtitle,
                  style: getCoverTextStyle(
                    fontFamily: _current.coverRightBlockFont,
                    fontSize: 32.0 * scale,
                    fontWeight: FontWeight.w900,
                    color: Color(_current.coverRightSubtitleColorValue),
                    letterSpacing: 1.5,
                    height: 1.0,
                  ),
                ),
                if (_current.verticalSplitShowRightDivider) ...[
                  SizedBox(height: 8 * scale),
                  Container(
                    width: (_current.verticalSplitRightDividerWidth * 0.75 * scale).clamp(10.0, 300.0),
                    height: (_current.verticalSplitRightDividerHeight * 0.8 * scale).clamp(1.0, 20.0),
                    decoration: BoxDecoration(
                      color: Color(_current.verticalSplitRightDividerColorValue),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  SizedBox(height: 8 * scale),
                ] else ...[
                  SizedBox(height: 10 * scale),
                ],
                Text(
                  _current.verticalSplitRightTagline,
                  style: getCoverTextStyle(
                    fontFamily: _current.coverRightBlockFont,
                    fontSize: 9.0 * scale,
                    fontWeight: FontWeight.w700,
                    color: Color(_current.coverRightTaglineColorValue),
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      _buildDraggableHandle(
        elementKey: 'rightBlock',
        label: '📌 Proposta de Automação',
        left: blockLeft,
        top: blockTop,
        width: canvasW * 0.42,
        height: 140 * scale,
        onDelete: () => setState(() => _current = _current.copyWith(verticalSplitShowRightBlock: false)),
        onDrag: (dx, dy) {
          setState(() {
            final currentRightPx = _current.verticalSplitRightBlockRight * canvasW;
            final newRight = (currentRightPx - dx) / canvasW;
            final newTop = ((_current.verticalSplitRightBlockTop * canvasH) + dy) / canvasH;
            _current = _current.copyWith(
              verticalSplitRightBlockRight: newRight.clamp(-1.50, 2.50),
              verticalSplitRightBlockTop: newTop.clamp(-1.50, 2.50),
            );
          });
        },
      ),
    ];
  }

  List<Widget> _buildModernRightFooter(double canvasW, double canvasH, double scale) {
    if (!_current.verticalSplitShowRightFooter) return const [];

    final footerLeft = canvasW - (_current.verticalSplitRightFooterRight * canvasW) - (canvasW * 0.45);
    final footerTop = canvasH - (_current.verticalSplitRightFooterBottom * canvasH) - (35 * scale);

    return [
      Positioned(
        left: footerLeft,
        top: footerTop,
        child: IgnorePointer(
          child: SizedBox(
            width: canvasW * 0.45,
            child: Text(
              _current.verticalSplitRightFooter,
              style: getCoverTextStyle(
                fontFamily: _current.coverFooterFont,
                fontSize: 8.0 * scale,
                fontWeight: FontWeight.w700,
                color: Color(_current.coverFooterColorValue),
              ),
            ),
          ),
        ),
      ),
      _buildDraggableHandle(
        elementKey: 'rightFooter',
        label: '📌 Rodapé Institucional',
        left: footerLeft,
        top: footerTop,
        width: canvasW * 0.45,
        height: 35 * scale,
        onDelete: () => setState(() => _current = _current.copyWith(verticalSplitShowRightFooter: false)),
        onDrag: (dx, dy) {
          setState(() {
            final currentRightPx = _current.verticalSplitRightFooterRight * canvasW;
            final newRight = (currentRightPx - dx) / canvasW;
            final currentBottomPx = _current.verticalSplitRightFooterBottom * canvasH;
            final newBottom = (currentBottomPx - dy) / canvasH;
            _current = _current.copyWith(
              verticalSplitRightFooterRight: newRight.clamp(-1.50, 2.50),
              verticalSplitRightFooterBottom: newBottom.clamp(-1.50, 2.50),
            );
          });
        },
      ),
    ];
  }

  List<Widget> _buildModernClientInfo(double canvasW, double canvasH, double scale) {
    if (!_current.coverShowClientInfo) return const [];

    final clientLeft = (_current.coverClientInfoPositionX * canvasW).clamp(0.0, canvasW - 50.0);
    final clientTop = (_current.coverClientInfoPositionY * canvasH).clamp(0.0, canvasH - 30.0);
    final clientW = (_current.coverClientInfoWidth * scale).clamp(100.0, canvasW);
    final clientH = 50.0 * scale;

    return [
      Positioned(
        left: clientLeft,
        top: clientTop,
        child: IgnorePointer(
          child: SizedBox(
            width: clientW,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Cliente: ${_current.clientName.isNotEmpty ? _current.clientName : "João da Silva Santos"}',
                  style: getCoverTextStyle(
                    fontFamily: _current.coverHeadlineFont,
                    fontSize: _current.coverClientInfoFontSize * scale,
                    fontWeight: FontWeight.bold,
                    color: Color(_current.coverClientInfoColorValue),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2 * scale),
                Text(
                  'CPF/CNPJ: 123.456.789-00',
                  style: getCoverTextStyle(
                    fontFamily: _current.coverHeadlineFont,
                    fontSize: (_current.coverClientInfoFontSize * 0.9) * scale,
                    fontWeight: FontWeight.w600,
                    color: Color(_current.coverClientInfoSecondaryColorValue),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2 * scale),
                Text(
                  'Automação: Iluminação, Áudio & Climatização',
                  style: getCoverTextStyle(
                    fontFamily: _current.coverHeadlineFont,
                    fontSize: (_current.coverClientInfoFontSize * 0.9) * scale,
                    fontWeight: FontWeight.w600,
                    color: Color(_current.coverClientInfoSecondaryColorValue),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
      _buildDraggableHandle(
        elementKey: 'clientInfo',
        label: '📌 Dados do Cliente / CPF',
        left: clientLeft,
        top: clientTop,
        width: clientW,
        height: clientH,
        onDelete: () => setState(() => _current = _current.copyWith(coverShowClientInfo: false)),
        onResizeWidth: (dw) {
          setState(() {
            final currentPx = _current.coverClientInfoWidth * scale;
            final newWidth = (currentPx + dw) / scale;
            _current = _current.copyWith(
              coverClientInfoWidth: newWidth.clamp(100.0, 500.0),
            );
          });
        },
        onDrag: (dx, dy) {
          setState(() {
            final newX = ((_current.coverClientInfoPositionX * canvasW) + dx) / canvasW;
            final newY = ((_current.coverClientInfoPositionY * canvasH) + dy) / canvasH;
            _current = _current.copyWith(
              coverClientInfoPositionX: newX.clamp(-0.5, 1.5),
              coverClientInfoPositionY: newY.clamp(-0.5, 1.5),
            );
          });
        },
      ),
    ];
  }

  List<Widget> _buildCyberNodesCanvasElements(double canvasW, double canvasH, double scale) {
    if (_current.nodes.isEmpty) return const [];

    final widgets = <Widget>[];

    for (final node in _current.nodes) {
      final isNodeSelected = _selectedElementKey == 'node_${node.id}';
      final isTargetSelected = _selectedElementKey == 'node_target_${node.id}';
      final isAnySelected = isNodeSelected || isTargetSelected;
      final nodeColor = Color(_hexToInt(node.colorHex, fallback: 0xFF38BDF8));
      final badgeRadius = (20.0 * scale).clamp(16.0, 26.0);

      final posX = (node.posX * canvasW).clamp(10.0, canvasW - 10.0);
      final posY = (node.posY * canvasH).clamp(10.0, canvasH - 10.0);
      final targetX = (node.targetX * canvasW).clamp(5.0, canvasW - 5.0);
      final targetY = (node.targetY * canvasH).clamp(5.0, canvasH - 5.0);

      // 1. VISUAL: Badge Redondo com Borda Neon e Fundo Escuro
      widgets.add(
        Positioned(
          left: posX - badgeRadius,
          top: posY - badgeRadius,
          child: IgnorePointer(
            child: Container(
              width: badgeRadius * 2,
              height: badgeRadius * 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0F172A).withValues(alpha: 0.92),
                border: Border.all(
                  color: isAnySelected ? Colors.white : nodeColor,
                  width: isAnySelected ? 2.5 : 2.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: nodeColor.withValues(alpha: isAnySelected ? 0.85 : 0.50),
                    blurRadius: isAnySelected ? 16 : 8,
                    spreadRadius: isAnySelected ? 2.5 : 0.5,
                  ),
                  const BoxShadow(
                    color: Colors.black87,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  _getNodeIcon(node.iconName),
                  size: badgeRadius * 0.95,
                  color: isAnySelected ? Colors.white : nodeColor,
                ),
              ),
            ),
          ),
        ),
      );

      // 2. VISUAL: Mini Etiqueta de Identificação do Nó
      final labelFontSize = (_current.coverNodesLabelFontSize * scale).clamp(6.0, 24.0);
      final labelBoxWidth = math.max(110.0 * scale, node.label.length * (labelFontSize * 0.95));
      widgets.add(
        Positioned(
          left: posX - (labelBoxWidth / 2),
          top: posY + badgeRadius + (3 * scale),
          child: IgnorePointer(
            child: SizedBox(
              width: labelBoxWidth,
              child: Center(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 6 * scale, vertical: 2.5 * scale),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: nodeColor.withValues(alpha: 0.5),
                      width: 0.8,
                    ),
                    boxShadow: const [
                      BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 1)),
                    ],
                  ),
                  child: Text(
                    node.label.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: labelFontSize,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      // 3. INTERATIVO: Handle para Arrastar o Badge do Nó
      widgets.add(
        _buildDraggableHandle(
          elementKey: 'node_${node.id}',
          label: '⚡ ${node.label}',
          left: posX - badgeRadius,
          top: posY - badgeRadius,
          width: badgeRadius * 2,
          height: (badgeRadius * 2) + (18 * scale),
          onDelete: () => _removeCyberNode(node.id),
          onDrag: (dx, dy) {
            setState(() {
              final newX = ((node.posX * canvasW) + (dx * 2.5)) / canvasW;
              final newY = ((node.posY * canvasH) + (dy * 2.5)) / canvasH;
              _updateNode(
                node.id,
                posX: newX.clamp(0.02, 0.98),
                posY: newY.clamp(0.02, 0.98),
              );
            });
          },
        ),
      );

      // 4. INTERATIVO: Handle para Arrastar o Alvo na Arquitetura
      if (node.showConnectorLine) {
        final targetHandleRadius = 14.0 * scale;
        widgets.add(
          _buildDraggableHandle(
            elementKey: 'node_target_${node.id}',
            label: '🎯 Alvo: ${node.label}',
            left: targetX - targetHandleRadius,
            top: targetY - targetHandleRadius,
            width: targetHandleRadius * 2,
            height: targetHandleRadius * 2,
            onDelete: null,
            onDrag: (dx, dy) {
              setState(() {
                final newTargetX = ((node.targetX * canvasW) + (dx * 2.5)) / canvasW;
                final newTargetY = ((node.targetY * canvasH) + (dy * 2.5)) / canvasH;
                _updateNode(
                  node.id,
                  targetX: newTargetX.clamp(0.02, 0.98),
                  targetY: newTargetY.clamp(0.02, 0.98),
                );
              });
            },
          ),
        );
      }
    }

    return widgets;
  }

  Widget _buildDraggableHandle({
    required String elementKey,
    required String label,
    required double left,
    required double top,
    required double width,
    required double height,
    required void Function(double dx, double dy) onDrag,
    void Function(double dw)? onResizeWidth,
    VoidCallback? onDelete,
  }) {
    final isSelected = _selectedElementKey == elementKey;
    final isHovered = _hoveredElementKey == elementKey && !isSelected;

    final clampedW = width.clamp(32.0, 700.0);
    final clampedH = height.clamp(20.0, 700.0);
    final effectiveTop = isSelected ? math.max(0.0, top - 26) : top;

    return Positioned(
      left: left,
      top: effectiveTop,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isSelected)
            Container(
              width: math.max(clampedW, onDelete != null ? 180.0 : 130.0),
              height: 24,
              margin: const EdgeInsets.only(bottom: 2),
              child: Row(
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.open_with_rounded, size: 10, color: Colors.white),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              label,
                              style: GoogleFonts.inter(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (onDelete != null)
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onDelete,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDC2626),
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: const [
                              BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 1)),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.close_rounded, size: 11, color: Colors.white),
                              const SizedBox(width: 2),
                              Text(
                                'OCULTAR',
                                style: GoogleFonts.inter(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _selectAndFocusElement(elementKey),
            onPanStart: (_) => _selectAndFocusElement(elementKey),
            onPanUpdate: (details) => onDrag(details.delta.dx, details.delta.dy),
            child: MouseRegion(
              cursor: SystemMouseCursors.move,
              onEnter: (_) => setState(() => _hoveredElementKey = elementKey),
              onExit: (_) {
                if (_hoveredElementKey == elementKey) {
                  setState(() => _hoveredElementKey = null);
                }
              },
              child: Container(
                width: clampedW,
                height: clampedH,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF38BDF8)
                        : isHovered
                            ? const Color(0xFF38BDF8).withValues(alpha: 0.60)
                            : Colors.transparent,
                    width: isSelected ? 2 : 1.5,
                  ),
                  color: isSelected
                      ? const Color(0xFF38BDF8).withValues(alpha: 0.12)
                      : isHovered
                          ? const Color(0xFF38BDF8).withValues(alpha: 0.06)
                          : Colors.transparent,
                ),
                child: isSelected && onResizeWidth != null
                    ? Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            right: -8,
                            top: 0,
                            bottom: 0,
                            child: Center(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => _selectAndFocusElement(elementKey),
                                onPanStart: (_) => _selectAndFocusElement(elementKey),
                                onPanUpdate: (details) => onResizeWidth(details.delta.dx),
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.resizeLeftRight,
                                  child: Container(
                                    width: 14,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0284C7),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Colors.white, width: 1.5),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.35),
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.drag_indicator_rounded,
                                      size: 10,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // PREVIEW DA PÁGINA 3 (PORTFÓLIO & CLIENTES) NO CANVAS A4
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildPage3CanvasPreview(double canvasW, double canvasH, double scale) {
    final pageBgColor = Color(_hexToInt(_current.page3BgColor, fallback: 0xFF0B132B));
    final cardBgColor = Color(_hexToInt(_current.page3CardBgColor, fallback: 0xFF111C38));
    final borderColor = Color(_hexToInt(_current.page3BorderColor, fallback: 0xFF38BDF8));
    final titleColor = Color(_hexToInt(_current.page3TitleColor, fallback: 0xFFFFFFFF));
    final subtitleColor = Color(_hexToInt(_current.page3SubtitleColor, fallback: 0xFF94A3B8));
    final accentColor = Color(_hexToInt(_current.page3AccentColor, fallback: 0xFF38BDF8));

    final portfolioItems = _current.page3PortfolioItems.isNotEmpty
        ? _current.page3PortfolioItems
        : AutomationPortfolioItem.defaultItems();

    return Container(
      width: canvasW,
      height: canvasH,
      decoration: BoxDecoration(
        color: pageBgColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── MIOLO DA PÁGINA 3 COM OS CARDS DE PORTFÓLIO & CLIENTES ──
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 24 * scale,
                  vertical: (_current.coverShowHeader ? 52 * scale : 24 * scale),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Superior da Seção de Portfólio
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 4 * scale),
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6 * scale),
                                  border: Border.all(color: accentColor.withValues(alpha: 0.4), width: 1),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.photo_library_rounded, color: accentColor, size: 12 * scale),
                                    SizedBox(width: 6 * scale),
                                    Text(
                                      'PORTFÓLIO & CASES REAIS',
                                      style: GoogleFonts.inter(
                                        fontSize: 9 * scale,
                                        fontWeight: FontWeight.bold,
                                        color: accentColor,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 6 * scale),
                              Text(
                                _current.page3Title.isNotEmpty ? _current.page3Title : 'PORTFÓLIO & CLIENTES',
                                style: GoogleFonts.outfit(
                                  fontSize: 16 * scale,
                                  fontWeight: FontWeight.bold,
                                  color: titleColor,
                                ),
                              ),
                              if (_current.page3Subtitle.isNotEmpty) ...[
                                SizedBox(height: 2 * scale),
                                Text(
                                  _current.page3Subtitle,
                                  style: GoogleFonts.inter(
                                    fontSize: 8.5 * scale,
                                    color: subtitleColor,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Text(
                          'Cases Entregues • Padrão High-End',
                          style: GoogleFonts.inter(
                            fontSize: 9 * scale,
                            color: subtitleColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12 * scale),

                    // ── CARDS DOS CASES DE PORTFÓLIO ──
                    Expanded(
                      child: Column(
                        children: portfolioItems.take(3).map((caseItem) {
                          return Expanded(
                            child: Container(
                              margin: EdgeInsets.only(bottom: 10 * scale),
                              decoration: BoxDecoration(
                                color: cardBgColor,
                                borderRadius: BorderRadius.circular(12 * scale),
                                border: Border.all(color: borderColor.withValues(alpha: 0.6), width: 1.2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.25),
                                    blurRadius: 8 * scale,
                                    offset: Offset(0, 3 * scale),
                                  ),
                                ],
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Foto do Case (Lado Esquerdo)
                                  Container(
                                    width: 140 * scale,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0F172A),
                                      borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular(11 * scale),
                                        bottomLeft: Radius.circular(11 * scale),
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular(11 * scale),
                                        bottomLeft: Radius.circular(11 * scale),
                                      ),
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          if (caseItem.imageBase64 != null && caseItem.imageBase64!.isNotEmpty)
                                            Builder(builder: (ctx) {
                                              try {
                                                return Image.memory(
                                                  base64Decode(caseItem.imageBase64!.contains(',')
                                                      ? caseItem.imageBase64!.split(',').last
                                                      : caseItem.imageBase64!),
                                                  fit: BoxFit.cover,
                                                );
                                              } catch (_) {
                                                return const Icon(Icons.broken_image_rounded, color: Colors.white24);
                                              }
                                            })
                                          else
                                            Container(
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    const Color(0xFF1E293B),
                                                    accentColor.withValues(alpha: 0.2),
                                                  ],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                ),
                                              ),
                                              child: Center(
                                                child: Icon(
                                                  Icons.home_work_rounded,
                                                  size: 38 * scale,
                                                  color: accentColor.withValues(alpha: 0.5),
                                                ),
                                              ),
                                            ),
                                          // Badge Concluído sobre a foto
                                          Positioned(
                                            top: 6 * scale,
                                            left: 6 * scale,
                                            child: Container(
                                              padding: EdgeInsets.symmetric(horizontal: 6 * scale, vertical: 2 * scale),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(alpha: 0.8),
                                                borderRadius: BorderRadius.circular(4 * scale),
                                                border: Border.all(color: const Color(0xFF10B981), width: 0.8),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.check_circle_rounded, size: 8 * scale, color: const Color(0xFF10B981)),
                                                  SizedBox(width: 3 * scale),
                                                  Text(
                                                    'Case Entregue',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 7.5 * scale,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // Dados e Especificação Técnica (Lado Direito)
                                  Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.all(10 * scale),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      caseItem.title,
                                                      style: GoogleFonts.outfit(
                                                        fontSize: 11.5 * scale,
                                                        fontWeight: FontWeight.bold,
                                                        color: titleColor,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  if (caseItem.clientOrLocation.isNotEmpty) ...[
                                                    SizedBox(width: 4 * scale),
                                                    Container(
                                                      padding: EdgeInsets.symmetric(horizontal: 6 * scale, vertical: 2 * scale),
                                                      decoration: BoxDecoration(
                                                        color: accentColor.withValues(alpha: 0.15),
                                                        borderRadius: BorderRadius.circular(4 * scale),
                                                      ),
                                                      child: Text(
                                                        caseItem.clientOrLocation,
                                                        style: GoogleFonts.inter(
                                                          fontSize: 7.5 * scale,
                                                          fontWeight: FontWeight.bold,
                                                          color: accentColor,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              SizedBox(height: 4 * scale),
                                              // Tags Chips
                                              if (caseItem.tags.isNotEmpty)
                                                Wrap(
                                                  spacing: 4 * scale,
                                                  runSpacing: 2 * scale,
                                                  children: caseItem.tags.split('•').map((t) => t.trim()).where((t) => t.isNotEmpty).take(4).map((tag) {
                                                    return Container(
                                                      padding: EdgeInsets.symmetric(horizontal: 5 * scale, vertical: 1.5 * scale),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white.withValues(alpha: 0.06),
                                                        borderRadius: BorderRadius.circular(3 * scale),
                                                        border: Border.all(color: Colors.white12, width: 0.5),
                                                      ),
                                                      child: Text(
                                                        tag,
                                                        style: GoogleFonts.inter(
                                                          fontSize: 7 * scale,
                                                          fontWeight: FontWeight.w600,
                                                          color: subtitleColor,
                                                        ),
                                                      ),
                                                    );
                                                  }).toList(),
                                                ),
                                            ],
                                          ),
                                          // Especificação Técnica Detalhada
                                          Text(
                                            caseItem.description,
                                            style: GoogleFonts.inter(
                                              fontSize: 8.5 * scale,
                                              color: subtitleColor,
                                              height: 1.25,
                                            ),
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── CABEÇALHO NO TOPO (PÁGINA INTERNA) ──
            if (_current.coverShowHeader)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: CoverHeaderWidget(
                  styleId: _current.coverHeaderStyle,
                  text1: _current.coverHeaderText1.isNotEmpty ? _current.coverHeaderText1 : 'PORTFÓLIO E CLIENTES',
                  text2: _current.coverHeaderText2.isNotEmpty ? _current.coverHeaderText2 : _current.companyName,
                  text3: 'Página 3 de 5',
                  accentColor: accentColor,
                  scale: scale,
                  customBgColorHex: _current.coverHeaderBgColor,
                  customTextColorHex: _current.coverHeaderTextColor,
                  customIconColorHex: _current.coverHeaderIconColor,
                ),
              ),

            // ── RODAPÉ NA BASE (PÁGINA INTERNA) ──
            if (_current.coverShowFooter)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: CoverFooterWidget(
                  styleId: _current.coverFooterStyle,
                  text1: _current.coverFooterText1.isNotEmpty ? _current.coverFooterText1 : 'A CASA QUE ENTENDE VOCÊ • EXPERIÊNCIA ÚNICA',
                  text2: _current.coverFooterText2.isNotEmpty ? _current.coverFooterText2 : _current.companyPhone,
                  text3: _current.coverFooterText3.isNotEmpty ? _current.coverFooterText3 : _current.companyWebsite,
                  text4: 'Página 3 de 5',
                  accentColor: accentColor,
                  scale: scale,
                  customBgColorHex: _current.coverFooterBgColor,
                  customTextColorHex: _current.coverFooterTextColor,
                  customIconColorHex: _current.coverFooterIconColor,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // PREVIEW DA PÁGINA 4 (AMBIENTES & CARDS DA PROPOSTA WEB) NO CANVAS A4
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildPage4CanvasPreview(double canvasW, double canvasH, double scale) {
    final pageBgColor = Color(_hexToInt(_current.page4BgColor, fallback: 0xFF0B132B));
    final cardBgColor = Color(_hexToInt(_current.page4CardBgColor, fallback: 0xFF111C38));
    final borderColor = Color(_hexToInt(_current.page4BorderColor, fallback: 0xFF00E5FF));
    final titleColor = Color(_hexToInt(_current.page4TitleColor, fallback: 0xFFFFFFFF));
    final subtitleColor = Color(_hexToInt(_current.page4SubtitleColor, fallback: 0xFF94A3B8));
    final accentColor = Color(_hexToInt(_current.page4AccentColor, fallback: 0xFF00E5FF));

    return Container(
      width: canvasW,
      height: canvasH,
      decoration: BoxDecoration(
        color: pageBgColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── MIOLO DA PÁGINA 4 COM OS CARDS DE AMBIENTES (IMAGEM 1) ──
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 24 * scale,
                  vertical: (_current.coverShowHeader ? 52 * scale : 24 * scale),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Superior da Seção Técnica
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 4 * scale),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6 * scale),
                                border: Border.all(color: accentColor.withValues(alpha: 0.4), width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.layers_rounded, color: accentColor, size: 12 * scale),
                                  SizedBox(width: 6 * scale),
                                  Text(
                                    'CATÁLOGO & EQUIPAMENTOS',
                                    style: GoogleFonts.inter(
                                      fontSize: 9 * scale,
                                      fontWeight: FontWeight.bold,
                                      color: accentColor,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 6 * scale),
                            Text(
                              'Detalhamento Técnico por Ambiente',
                              style: GoogleFonts.outfit(
                                fontSize: 16 * scale,
                                fontWeight: FontWeight.bold,
                                color: titleColor,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Hardware Homologado • Padrão ABNT/IEEE',
                          style: GoogleFonts.inter(
                            fontSize: 9 * scale,
                            color: subtitleColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 14 * scale),

                    // ── CARD VISUAL DO AMBIENTE (LIVING INTEGRADO) ──
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: cardBgColor,
                          borderRadius: BorderRadius.circular(14 * scale),
                          border: Border.all(color: borderColor.withValues(alpha: 0.8), width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 10 * scale,
                              offset: Offset(0, 4 * scale),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // 1. Cabeçalho do Card
                            Container(
                              padding: EdgeInsets.all(12 * scale),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(13 * scale),
                                  topRight: Radius.circular(13 * scale),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 34 * scale,
                                    height: 34 * scale,
                                    decoration: BoxDecoration(
                                      color: accentColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8 * scale),
                                      border: Border.all(color: accentColor.withValues(alpha: 0.35)),
                                    ),
                                    child: Icon(Icons.meeting_room_rounded, color: accentColor, size: 18 * scale),
                                  ),
                                  SizedBox(width: 10 * scale),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              'LIVING INTEGRADO & HOME THEATER',
                                              style: GoogleFonts.outfit(
                                                fontSize: 13 * scale,
                                                fontWeight: FontWeight.bold,
                                                color: titleColor,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                            SizedBox(width: 8 * scale),
                                            Container(
                                              padding: EdgeInsets.symmetric(horizontal: 7 * scale, vertical: 2 * scale),
                                              decoration: BoxDecoration(
                                                color: accentColor.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(10 * scale),
                                                border: Border.all(color: accentColor.withValues(alpha: 0.4)),
                                              ),
                                              child: Text(
                                                '8 dispositivos',
                                                style: GoogleFonts.inter(
                                                  fontSize: 8.5 * scale,
                                                  fontWeight: FontWeight.bold,
                                                  color: accentColor,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 2 * scale),
                                        Text(
                                          'Controle de iluminação dimerizável, climatização, cortinas e áudio multiroom',
                                          style: GoogleFonts.inter(
                                            fontSize: 9.5 * scale,
                                            color: subtitleColor,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 12 * scale),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'SUBTOTAL DO AMBIENTE',
                                        style: GoogleFonts.inter(
                                          fontSize: 7.5 * scale,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.8,
                                          color: subtitleColor,
                                        ),
                                      ),
                                      Text(
                                        'R\$ 14.850,00',
                                        style: GoogleFonts.outfit(
                                          fontSize: 16 * scale,
                                          fontWeight: FontWeight.w900,
                                          color: accentColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            Divider(height: 1, color: borderColor.withValues(alpha: 0.2)),

                            // 2. Corpo do Card: Duas Colunas (Foto/Resumo + Lista de Equipamentos)
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.all(12 * scale),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // Coluna Esquerda: Foto Ilustrativa & Representatividade
                                    SizedBox(
                                      width: 175 * scale,
                                      child: Column(
                                        children: [
                                          // Foto com Overlay
                                          Expanded(
                                            child: Container(
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(10 * scale),
                                                color: const Color(0xFF0F172A),
                                                border: Border.all(color: Colors.white12),
                                              ),
                                              child: Stack(
                                                fit: StackFit.expand,
                                                children: [
                                                  Center(
                                                    child: Icon(
                                                      Icons.living_rounded,
                                                      size: 42 * scale,
                                                      color: accentColor.withValues(alpha: 0.35),
                                                    ),
                                                  ),
                                                  Positioned(
                                                    top: 8 * scale,
                                                    left: 8 * scale,
                                                    child: Container(
                                                      padding: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 3 * scale),
                                                      decoration: BoxDecoration(
                                                        color: Colors.black.withValues(alpha: 0.75),
                                                        borderRadius: BorderRadius.circular(12 * scale),
                                                        border: Border.all(color: accentColor.withValues(alpha: 0.5)),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Icon(Icons.photo_camera_rounded, size: 9 * scale, color: accentColor),
                                                          SizedBox(width: 4 * scale),
                                                          Text(
                                                            'Cenário Integrado',
                                                            style: GoogleFonts.inter(
                                                              fontSize: 8 * scale,
                                                              fontWeight: FontWeight.bold,
                                                              color: Colors.white,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          SizedBox(height: 8 * scale),
                                          // Card de Representatividade
                                          Container(
                                            padding: EdgeInsets.all(8 * scale),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(alpha: 0.3),
                                              borderRadius: BorderRadius.circular(8 * scale),
                                              border: Border.all(color: Colors.white10),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(Icons.pie_chart_outline_rounded, size: 16 * scale, color: accentColor),
                                                SizedBox(width: 8 * scale),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        'Representatividade no Projeto',
                                                        style: GoogleFonts.inter(fontSize: 8 * scale, color: subtitleColor),
                                                      ),
                                                      Text(
                                                        '38.5% do valor total',
                                                        style: GoogleFonts.inter(
                                                          fontSize: 9.5 * scale,
                                                          fontWeight: FontWeight.bold,
                                                          color: titleColor,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(width: 12 * scale),

                                    // Coluna Direita: Equipamentos Adotados
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(Icons.inventory_2_outlined, color: accentColor, size: 14 * scale),
                                                  SizedBox(width: 6 * scale),
                                                  Text(
                                                    'EQUIPAMENTOS ADOTADOS (8)',
                                                    style: GoogleFonts.outfit(
                                                      fontSize: 11 * scale,
                                                      fontWeight: FontWeight.bold,
                                                      color: titleColor,
                                                      letterSpacing: 0.4,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Text(
                                                'Hardware & Módulos Oficiais',
                                                style: GoogleFonts.inter(fontSize: 8.5 * scale, color: subtitleColor),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 8 * scale),

                                          // 4 Equipamentos Simulados da Proposta
                                          Expanded(
                                            child: Column(
                                              children: [
                                                _buildPreviewItemRow(
                                                  name: 'Módulo Dimmer 4 Canais Zigbee 3.0 Pro',
                                                  category: 'Iluminação',
                                                  brand: 'Aqara Pro',
                                                  qty: 2,
                                                  unitPrice: 1700.0,
                                                  scale: scale,
                                                  titleColor: titleColor,
                                                  subtitleColor: subtitleColor,
                                                  accentColor: accentColor,
                                                ),
                                                SizedBox(height: 6 * scale),
                                                _buildPreviewItemRow(
                                                  name: 'Keypad Inteligente Touch Glass 6 Teclas',
                                                  category: 'Interruptor',
                                                  brand: 'Sonoff Smart',
                                                  qty: 3,
                                                  unitPrice: 1450.0,
                                                  scale: scale,
                                                  titleColor: titleColor,
                                                  subtitleColor: subtitleColor,
                                                  accentColor: accentColor,
                                                ),
                                                SizedBox(height: 6 * scale),
                                                _buildPreviewItemRow(
                                                  name: 'Controlador IR/RF Climatização & Cortinas',
                                                  category: 'Climatização',
                                                  brand: 'Broadlink RM4',
                                                  qty: 1,
                                                  unitPrice: 1200.0,
                                                  scale: scale,
                                                  titleColor: titleColor,
                                                  subtitleColor: subtitleColor,
                                                  accentColor: accentColor,
                                                ),
                                                SizedBox(height: 6 * scale),
                                                _buildPreviewItemRow(
                                                  name: 'Amplificador Áudio Multiroom Wi-Fi/BT 200W',
                                                  category: 'Áudio & Vídeo',
                                                  brand: 'Arylic Hi-Fi',
                                                  qty: 2,
                                                  unitPrice: 2950.0,
                                                  scale: scale,
                                                  titleColor: titleColor,
                                                  subtitleColor: subtitleColor,
                                                  accentColor: accentColor,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── CABEÇALHO NO TOPO (PÁGINA INTERNA) ──
            if (_current.coverShowHeader)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: CoverHeaderWidget(
                  styleId: _current.coverHeaderStyle,
                  text1: _current.coverHeaderText1.isNotEmpty ? _current.coverHeaderText1 : 'AUTOMAÇÃO RESIDENCIAL',
                  text2: _current.coverHeaderText2.isNotEmpty ? _current.coverHeaderText2 : _current.companyName,
                  text3: 'Página 4 de 5',
                  accentColor: accentColor,
                  scale: scale,
                  customBgColorHex: _current.coverHeaderBgColor,
                  customTextColorHex: _current.coverHeaderTextColor,
                  customIconColorHex: _current.coverHeaderIconColor,
                ),
              ),

            // ── RODAPÉ NA BASE (PÁGINA INTERNA) ──
            if (_current.coverShowFooter)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: CoverFooterWidget(
                  styleId: _current.coverFooterStyle,
                  text1: _current.coverFooterText1.isNotEmpty ? _current.coverFooterText1 : 'A CASA QUE ENTENDE VOCÊ • EXPERIÊNCIA ÚNICA',
                  text2: _current.coverFooterText2.isNotEmpty ? _current.coverFooterText2 : _current.companyPhone,
                  text3: _current.coverFooterText3.isNotEmpty ? _current.coverFooterText3 : _current.companyWebsite,
                  text4: 'Página 4 de 5',
                  accentColor: accentColor,
                  scale: scale,
                  customBgColorHex: _current.coverFooterBgColor,
                  customTextColorHex: _current.coverFooterTextColor,
                  customIconColorHex: _current.coverFooterIconColor,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewItemRow({
    required String name,
    required String category,
    required String brand,
    required int qty,
    required double unitPrice,
    required double scale,
    required Color titleColor,
    required Color subtitleColor,
    required Color accentColor,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 7 * scale),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(8 * scale),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(5 * scale),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6 * scale),
            ),
            child: Icon(Icons.devices_rounded, color: accentColor, size: 12 * scale),
          ),
          SizedBox(width: 8 * scale),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: GoogleFonts.inter(
                    fontSize: 9.5 * scale,
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 1 * scale),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 5 * scale, vertical: 1 * scale),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4 * scale),
                      ),
                      child: Text(
                        category,
                        style: GoogleFonts.inter(
                          fontSize: 7.5 * scale,
                          fontWeight: FontWeight.bold,
                          color: accentColor,
                        ),
                      ),
                    ),
                    SizedBox(width: 6 * scale),
                    Text(
                      'Marca: $brand',
                      style: GoogleFonts.inter(fontSize: 8 * scale, color: subtitleColor),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: 8 * scale),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Qtd: $qty',
                style: GoogleFonts.inter(fontSize: 8 * scale, color: subtitleColor),
              ),
              Text(
                'R\$ ${(qty * unitPrice).toStringAsFixed(2).replaceAll('.', ',')}',
                style: GoogleFonts.inter(
                  fontSize: 9.5 * scale,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildInspectorPanel() {
    return Container(
      color: const Color(0xFF1E293B),
      child: Column(
        children: [
          // Abas
          TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFFEAB308),
            indicatorWeight: 3,
            labelColor: const Color(0xFFF8FAFC),
            unselectedLabelColor: const Color(0xFF94A3B8),
            labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
            tabs: const [
              Tab(icon: Icon(Icons.edit_note_rounded, size: 18), text: 'Textos & Conteúdo'),
              Tab(icon: Icon(Icons.tune_rounded, size: 18), text: 'Estilo & Divisor'),
              Tab(icon: Icon(Icons.hub_rounded, size: 18), text: 'Nós Inteligentes'),
              Tab(icon: Icon(Icons.view_headline_rounded, size: 18), text: 'Cabeçalho & Rodapé'),
              Tab(icon: Icon(Icons.image_outlined, size: 18), text: 'Logo & Papel de Parede'),
              Tab(icon: Icon(Icons.auto_stories_rounded, size: 18), text: 'Páginas'),
            ],
          ),
          const Divider(height: 1, color: Color(0xFF334155)),

          // Conteúdo das Abas
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTextsTab(),
                _buildStyleTab(),
                _buildCyberNodesTab(),
                _buildHeaderFooterTab(),
                _buildLogoAndWallpaperTab(),
                _buildPagesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPagesTab() {
    return CoverPagesManagerTab(
      isSolar: false,
      activePageId: _activeCustomizerPageId,
      onSelectPage: (pId) {
        setState(() {
          _activeCustomizerPageId = pId;
        });
      },
      hiddenPageIds: _current.hiddenPageIds,
      onUpdateHiddenPages: (hiddenList) {
        setState(() {
          _current = _current.copyWith(hiddenPagesJson: jsonEncode(hiddenList));
        });
      },
      customPages: _current.customPages,
      onUpdateCustomPages: (cPages) {
        setState(() {
          _current = _current.copyWith(
            customPagesJson: jsonEncode(cPages.map((c) => c.toMap()).toList()),
          );
        });
      },
      page2Cards: _current.page2Cards,
      onUpdatePage2Cards: (cards) {
        setState(() {
          _current = _current.copyWith(
            page2CardsJson: jsonEncode(cards.map((c) => c.toMap()).toList()),
          );
        });
      },
      selectedPage2TemplateId: _current.page2TemplateId,
      onSelectPage2Template: (tpl) {
        setState(() {
          _current = _current.copyWith(
            page2TemplateId: tpl.id,
            page2IllustrationType: tpl.illustrationKey,
            page2CardsJson: jsonEncode(tpl.defaultCards.map((c) => c.toMap()).toList()),
            primaryColorHex: tpl.defaultPrimaryColor,
            verticalSplitAccentColor: tpl.defaultPrimaryColor,
          );
          _activeCustomizerPageId = 'page_2';
        });
      },
      selectedInternalPresetId: _current.internalPagesLayoutPreset,
      onSelectInternalPreset: (preset) {
        setState(() {
          _current = _current.copyWith(
            internalPagesLayoutPreset: preset.id,
            coverHeaderStyle: preset.headerStyle,
            coverFooterStyle: preset.footerStyle,
            primaryColorHex: preset.primaryColorHex,
            coverHeaderBgColor: preset.headerBgColorHex,
            coverHeaderTextColor: preset.headerTextColorHex,
            coverFooterBgColor: preset.footerBgColorHex,
            coverFooterTextColor: preset.footerTextColorHex,
          );
        });
      },
      page2ShowIllustration: _current.page2ShowIllustration,
      onTogglePage2Illustration: (val) {
        setState(() {
          _current = _current.copyWith(page2ShowIllustration: val);
        });
      },
      page2IllustrationType: _current.page2IllustrationType,
      onSelectPage2IllustrationType: (type) {
        setState(() {
          _current = _current.copyWith(page2IllustrationType: type);
        });
      },
      onSelectImageFromBank: (img) {
        setState(() {
          if (img.localAsset != null && img.localAsset!.isNotEmpty) {
            _current = _current.copyWith(selectedCoverTemplate: img.localAsset!);
          } else {
            _current = _current.copyWith(coverImageUrl: img.url);
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Imagem "${img.title}" selecionada!'),
            backgroundColor: const Color(0xFF0284C7),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      primaryColor: Color(_hexToInt(_current.verticalSplitAccentColor, fallback: 0xFF0284C7)),
      page3Title: _current.page3Title,
      onUpdatePage3Title: (t) => setState(() => _current = _current.copyWith(page3Title: t)),
      page3Subtitle: _current.page3Subtitle,
      onUpdatePage3Subtitle: (s) => setState(() => _current = _current.copyWith(page3Subtitle: s)),
      page3PortfolioItems: _current.page3PortfolioItems,
      onUpdatePage3PortfolioItems: (items) => setState(() => _current = _current.copyWith(
            page3PortfolioJson: jsonEncode(items.map((i) => i.toMap()).toList()),
          )),
      page3BgColor: _current.page3BgColor,
      onUpdatePage3BgColor: (c) => setState(() => _current = _current.copyWith(page3BgColor: c)),
      page3CardBgColor: _current.page3CardBgColor,
      onUpdatePage3CardBgColor: (c) => setState(() => _current = _current.copyWith(page3CardBgColor: c)),
      page3BorderColor: _current.page3BorderColor,
      onUpdatePage3BorderColor: (c) => setState(() => _current = _current.copyWith(page3BorderColor: c)),
      page3TitleColor: _current.page3TitleColor,
      onUpdatePage3TitleColor: (c) => setState(() => _current = _current.copyWith(page3TitleColor: c)),
      page3SubtitleColor: _current.page3SubtitleColor,
      onUpdatePage3SubtitleColor: (c) => setState(() => _current = _current.copyWith(page3SubtitleColor: c)),
      page3AccentColor: _current.page3AccentColor,
      onUpdatePage3AccentColor: (c) => setState(() => _current = _current.copyWith(page3AccentColor: c)),
      onResetPage3Items: () => setState(() => _current = _current.copyWith(
            page3Title: 'PORTFÓLIO & CLIENTES',
            page3Subtitle: 'Projetos executados com excelência e tecnologia de ponta',
            page3PortfolioJson: '',
            page3BgColor: '#0B132B',
            page3CardBgColor: '#111C38',
            page3BorderColor: '#38BDF8',
            page3TitleColor: '#FFFFFF',
            page3SubtitleColor: '#94A3B8',
            page3AccentColor: '#38BDF8',
          )),
      page4BgColor: _current.page4BgColor,
      onUpdatePage4BgColor: (c) => setState(() => _current = _current.copyWith(page4BgColor: c)),
      page4CardBgColor: _current.page4CardBgColor,
      onUpdatePage4CardBgColor: (c) => setState(() => _current = _current.copyWith(page4CardBgColor: c)),
      page4BorderColor: _current.page4BorderColor,
      onUpdatePage4BorderColor: (c) => setState(() => _current = _current.copyWith(page4BorderColor: c)),
      page4TitleColor: _current.page4TitleColor,
      onUpdatePage4TitleColor: (c) => setState(() => _current = _current.copyWith(page4TitleColor: c)),
      page4SubtitleColor: _current.page4SubtitleColor,
      onUpdatePage4SubtitleColor: (c) => setState(() => _current = _current.copyWith(page4SubtitleColor: c)),
      page4AccentColor: _current.page4AccentColor,
      onUpdatePage4AccentColor: (c) => setState(() => _current = _current.copyWith(page4AccentColor: c)),
      onResetPage4Colors: () => setState(() => _current = _current.copyWith(
            page4BgColor: '#0B132B',
            page4CardBgColor: '#111C38',
            page4BorderColor: '#00E5FF',
            page4TitleColor: '#FFFFFF',
            page4SubtitleColor: '#94A3B8',
            page4AccentColor: '#00E5FF',
          )),
    );
  }

  Widget _buildHeaderFooterTab() {
    return CoverHeaderFooterTabContent(
      showHeader: _current.coverShowHeader,
      onToggleHeader: (val) {
        setState(() {
          _current = _current.copyWith(coverShowHeader: val);
        });
      },
      headerStyle: _current.coverHeaderStyle,
      onSelectHeaderStyle: (styleId) {
        setState(() {
          _current = _current.copyWith(coverHeaderStyle: styleId);
        });
      },
      headerText1Ctrl: _headerText1Ctrl,
      headerText2Ctrl: _headerText2Ctrl,
      headerText3Ctrl: _headerText3Ctrl,
      showFooter: _current.coverShowFooter,
      onToggleFooter: (val) {
        setState(() {
          _current = _current.copyWith(coverShowFooter: val);
        });
      },
      footerStyle: _current.coverFooterStyle,
      onSelectFooterStyle: (styleId) {
        setState(() {
          _current = _current.copyWith(coverFooterStyle: styleId);
        });
      },
      footerText1Ctrl: _footerText1Ctrl,
      footerText2Ctrl: _footerText2Ctrl,
      footerText3Ctrl: _footerText3Ctrl,
      footerText4Ctrl: _footerText4Ctrl,
      accentColor: const Color(0xFF38BDF8),
      selectedInternalPresetId: _current.internalPagesLayoutPreset,
      onSelectInternalPreset: (preset) {
        setState(() {
          _current = _current.copyWith(
            internalPagesLayoutPreset: preset.id,
            coverHeaderStyle: preset.headerStyle,
            coverFooterStyle: preset.footerStyle,
            primaryColorHex: preset.primaryColorHex,
            coverHeaderBgColor: preset.headerBgColorHex,
            coverHeaderTextColor: preset.headerTextColorHex,
            coverFooterBgColor: preset.footerBgColorHex,
            coverFooterTextColor: preset.footerTextColorHex,
          );
        });
      },
      headerBgColor: _current.coverHeaderBgColor,
      onHeaderBgColorChanged: (c) => setState(() => _current = _current.copyWith(coverHeaderBgColor: c)),
      headerTextColor: _current.coverHeaderTextColor,
      onHeaderTextColorChanged: (c) => setState(() => _current = _current.copyWith(coverHeaderTextColor: c)),
      headerIconColor: _current.coverHeaderIconColor,
      onHeaderIconColorChanged: (c) => setState(() => _current = _current.copyWith(coverHeaderIconColor: c)),
      footerBgColor: _current.coverFooterBgColor,
      onFooterBgColorChanged: (c) => setState(() => _current = _current.copyWith(coverFooterBgColor: c)),
      footerTextColor: _current.coverFooterTextColor,
      onFooterTextColorChanged: (c) => setState(() => _current = _current.copyWith(coverFooterTextColor: c)),
      footerIconColor: _current.coverFooterIconColor,
      onFooterIconColorChanged: (c) => setState(() => _current = _current.copyWith(coverFooterIconColor: c)),
    );
  }

  Widget _buildTextsTab() {
    return SingleChildScrollView(
      controller: _inspectorScrollController,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── BOTÕES DE ADICIONAR ELEMENTOS (NO TOPO DA ABA) ───────────────
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _addCustomText,
                  icon: const Icon(Icons.title_rounded, size: 16),
                  label: const Text('+ ADICIONAR TEXTO'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showIconPickerModal,
                  icon: const Icon(Icons.add_reaction_outlined, size: 16),
                  label: const Text('+ ADICIONAR ÍCONE'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // ── SEÇÃO: ELEMENTOS ADICIONAIS CRIADOS PELO USUÁRIO ───────────────
          if (_current.customTextItems.isNotEmpty || _current.customIconItems.isNotEmpty) ...[
            _panelSectionTitle('Elementos Adicionais Criados', 'Textos e ícones extras adicionados na capa'),
            const SizedBox(height: 12),

            // Lista de Textos Extras
            for (final textItem in _current.customTextItems) ...[
              Builder(
                builder: (ctx) {
                  final fn = _customTextFocusNodes.putIfAbsent(textItem.id, () => FocusNode());
                  final isSel = _selectedElementKey == 'customText_${textItem.id}';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSel ? const Color(0xFF38BDF8) : const Color(0xFF334155),
                        width: isSel ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.title_rounded, color: Color(0xFF6366F1), size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Texto Adicional',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isSel ? const Color(0xFF38BDF8) : Colors.white,
                                ),
                              ),
                            ),
                            if (isSel) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0284C7),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('SELECIONADO', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.white)),
                              ),
                              const SizedBox(width: 6),
                            ],
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 18),
                              tooltip: 'Excluir Texto',
                              onPressed: () => _removeCustomText(textItem.id),
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          key: ValueKey('custom_txt_${textItem.id}'),
                          initialValue: textItem.text,
                          focusNode: fn,
                          onTap: () => setState(() => _selectedElementKey = 'customText_${textItem.id}'),
                          onChanged: (val) {
                            setState(() {
                              _current = _current.copyWith(
                                customTextItems: _current.customTextItems.map((t) {
                                  if (t.id == textItem.id) return t.copyWith(text: val);
                                  return t;
                                }).toList(),
                              );
                            });
                          },
                          style: GoogleFonts.inter(fontSize: 12.5, color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Digite o texto...',
                            hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                            filled: true,
                            fillColor: const Color(0xFF1E293B),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text('Tamanho: ${textItem.fontSize.toInt()}px', style: GoogleFonts.inter(fontSize: 11, color: Colors.white70)),
                            Expanded(
                              child: Slider(
                                value: textItem.fontSize.clamp(8.0, 48.0),
                                min: 8.0,
                                max: 48.0,
                                activeColor: const Color(0xFF6366F1),
                                onChanged: (v) {
                                  setState(() {
                                    _current = _current.copyWith(
                                      customTextItems: _current.customTextItems.map((t) {
                                        if (t.id == textItem.id) return t.copyWith(fontSize: v);
                                        return t;
                                      }).toList(),
                                    );
                                  });
                                },
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _current = _current.copyWith(
                                    customTextItems: _current.customTextItems.map((t) {
                                      if (t.id == textItem.id) return t.copyWith(isBold: !t.isBold);
                                      return t;
                                    }).toList(),
                                  );
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: textItem.isBold ? const Color(0xFF6366F1) : const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('B', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text('Cor: ', style: GoogleFonts.inter(fontSize: 11, color: Colors.white70)),
                            for (final colorHex in ['#FFFFFF', '#0F172A', '#EAB308', '#F97316', '#0284C7', '#10B981', '#EF4444']) ...[
                              InkWell(
                                onTap: () {
                                  final intVal = int.parse(colorHex.replaceAll('#', 'FF'), radix: 16);
                                  setState(() {
                                    _current = _current.copyWith(
                                      customTextItems: _current.customTextItems.map((t) {
                                        if (t.id == textItem.id) return t.copyWith(colorValue: intVal);
                                        return t;
                                      }).toList(),
                                    );
                                  });
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(right: 6),
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    color: Color(int.parse(colorHex.replaceAll('#', 'FF'), radix: 16)),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: textItem.colorValue == int.parse(colorHex.replaceAll('#', 'FF'), radix: 16)
                                          ? Colors.white
                                          : Colors.white24,
                                      width: textItem.colorValue == int.parse(colorHex.replaceAll('#', 'FF'), radix: 16) ? 2 : 1,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],

            // Lista de Ícones Extras
            for (final iconItem in _current.customIconItems) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _selectedElementKey == 'customIcon_${iconItem.id}'
                        ? const Color(0xFF38BDF8)
                        : const Color(0xFF334155),
                    width: _selectedElementKey == 'customIcon_${iconItem.id}' ? 2 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(getCoverBadgeIcon(iconItem.iconKey), color: Color(iconItem.colorValue), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Ícone: ${iconItem.iconKey.toUpperCase()}',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 18),
                          tooltip: 'Excluir Ícone',
                          onPressed: () => _removeCustomIcon(iconItem.id),
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text('Tamanho: ${iconItem.size.toInt()}px', style: GoogleFonts.inter(fontSize: 11, color: Colors.white70)),
                        Expanded(
                          child: Slider(
                            value: iconItem.size.clamp(14.0, 72.0),
                            min: 14.0,
                            max: 72.0,
                            activeColor: const Color(0xFFF59E0B),
                            onChanged: (v) {
                              setState(() {
                                _current = _current.copyWith(
                                  customIconItems: _current.customIconItems.map((i) {
                                    if (i.id == iconItem.id) return i.copyWith(size: v);
                                    return i;
                                  }).toList(),
                                );
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                        Row(
                          children: [
                            Text('Cor: ', style: GoogleFonts.inter(fontSize: 11, color: Colors.white70)),
                            for (final colorHex in ['#EAB308', '#F97316', '#FFFFFF', '#0F172A', '#0284C7', '#10B981', '#EF4444']) ...[
                              InkWell(
                                onTap: () {
                                  final intVal = int.parse(colorHex.replaceAll('#', 'FF'), radix: 16);
                                  setState(() {
                                    _current = _current.copyWith(
                                      customIconItems: _current.customIconItems.map((i) {
                                        if (i.id == iconItem.id) return i.copyWith(colorValue: intVal);
                                        return i;
                                      }).toList(),
                                    );
                                  });
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(right: 6),
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    color: Color(int.parse(colorHex.replaceAll('#', 'FF'), radix: 16)),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: iconItem.colorValue == int.parse(colorHex.replaceAll('#', 'FF'), radix: 16)
                                          ? Colors.white
                                          : Colors.white24,
                                      width: iconItem.colorValue == int.parse(colorHex.replaceAll('#', 'FF'), radix: 16) ? 2 : 1,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ],

          const SizedBox(height: 18),

          // ── 1. FRASE DE IMPACTO / HEADLINE (FOTO) ─────────────────────────
          _panelSectionTitle(
            'Frase de Impacto da Foto',
            'Título e subtítulo destacados na área da imagem',
            onDelete: _current.verticalSplitShowHeadline
                ? () => setState(() => _current = _current.copyWith(verticalSplitShowHeadline: false))
                : null,
            deleteTooltip: 'Ocultar Frase de Impacto',
          ),
          const SizedBox(height: 12),
          if (!_current.verticalSplitShowHeadline)
            _buildHiddenElementBanner(
              'Frase de Impacto da Foto',
              () => setState(() => _current = _current.copyWith(verticalSplitShowHeadline: true)),
            )
          else ...[
            _buildFontFamilySelector(
              label: 'Fonte do Título e Subtítulo:',
              selectedFont: _current.coverHeadlineFont,
              onSelect: (f) => setState(() => _current = _current.copyWith(coverHeadlineFont: f)),
            ),
            const SizedBox(height: 6),
            Text(
              'Cor do Texto da Frase:',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFCBD5E1)),
            ),
            const SizedBox(height: 6),
            _buildColorChipsRow(
              selectedHex: _current.coverHeadlineColor,
              onSelect: (c) => setState(() => _current = _current.copyWith(coverHeadlineColor: c)),
            ),
            const SizedBox(height: 12),
            _darkTextField(
              controller: _headlineCtrl,
              focusNode: _headlineFocusNode,
              isHighlighted: _selectedElementKey == 'headline',
              label: 'Título Principal da Imagem',
              hint: 'ENERGIA QUE MOVE O SEU AMANHÃ',
            ),
            const SizedBox(height: 10),
            _darkTextField(
              controller: _subheadlineCtrl,
              focusNode: _subheadlineFocusNode,
              isHighlighted: _selectedElementKey == 'headline',
              label: 'Subtítulo da Imagem',
              hint: 'MAIS ECONOMIA. MAIS LIBERDADE. UM FUTURO SUSTENTÁVEL.',
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _current.verticalSplitShowHeadlineDivider
                      ? Color(_current.verticalSplitHeadlineDividerColorValue).withValues(alpha: 0.35)
                      : const Color(0xFF334155),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Linha de Destaque da Frase',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Transform.scale(
                        scale: 0.8,
                        child: Switch(
                          value: _current.verticalSplitShowHeadlineDivider,
                          activeThumbColor: const Color(0xFF38BDF8),
                          onChanged: (val) {
                            setState(() {
                              _current = _current.copyWith(verticalSplitShowHeadlineDivider: val);
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  if (_current.verticalSplitShowHeadlineDivider) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Largura da Linha:',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFCBD5E1)),
                        ),
                        Text(
                          '${_current.verticalSplitHeadlineDividerWidth.round()} px',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF38BDF8)),
                        ),
                      ],
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: const Color(0xFF0284C7),
                        inactiveTrackColor: const Color(0xFF334155),
                        thumbColor: const Color(0xFF38BDF8),
                        overlayColor: const Color(0xFF38BDF8).withValues(alpha: 0.2),
                        trackHeight: 3,
                      ),
                      child: Slider(
                        value: _current.verticalSplitHeadlineDividerWidth.clamp(10.0, 200.0),
                        min: 10.0,
                        max: 200.0,
                        divisions: 38,
                        onChanged: (val) {
                          setState(() {
                            _current = _current.copyWith(verticalSplitHeadlineDividerWidth: val);
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Espessura da Linha:',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFCBD5E1)),
                        ),
                        Text(
                          '${_current.verticalSplitHeadlineDividerHeight.toStringAsFixed(1)} px',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF38BDF8)),
                        ),
                      ],
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: const Color(0xFF0284C7),
                        inactiveTrackColor: const Color(0xFF334155),
                        thumbColor: const Color(0xFF38BDF8),
                        overlayColor: const Color(0xFF38BDF8).withValues(alpha: 0.2),
                        trackHeight: 3,
                      ),
                      child: Slider(
                        value: _current.verticalSplitHeadlineDividerHeight.clamp(1.0, 10.0),
                        min: 1.0,
                        max: 10.0,
                        divisions: 18,
                        onChanged: (val) {
                          setState(() {
                            _current = _current.copyWith(verticalSplitHeadlineDividerHeight: val);
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Cor da Linha:',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFCBD5E1)),
                    ),
                    const SizedBox(height: 6),
                    _buildColorChipsRow(
                      selectedHex: _current.verticalSplitHeadlineDividerColor.isNotEmpty
                          ? _current.verticalSplitHeadlineDividerColor
                          : _current.verticalSplitAccentColor,
                      onSelect: (c) => setState(() => _current = _current.copyWith(verticalSplitHeadlineDividerColor: c)),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          const Divider(color: Color(0xFF334155)),
          const SizedBox(height: 16),

          // ── 2. SEÇÃO: BADGES INFORMATIVOS ───────────────────────────────
          _panelSectionTitle(
            'Badges Informativos',
            'Configure os selos em destaque na capa',
            onDelete: _current.verticalSplitShowLeftFooter
                ? () => setState(() => _current = _current.copyWith(verticalSplitShowLeftFooter: false))
                : null,
            deleteTooltip: 'Ocultar Badges Informativos',
          ),
          const SizedBox(height: 12),
          if (!_current.verticalSplitShowLeftFooter)
            _buildHiddenElementBanner(
              'Badges Informativos',
              () => setState(() => _current = _current.copyWith(verticalSplitShowLeftFooter: true)),
            )
          else ...[
            Text(
              'Cor do Texto dos Badges:',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFCBD5E1)),
            ),
            const SizedBox(height: 6),
            _buildColorChipsRow(
              selectedHex: _current.coverBadgesTextColor,
              onSelect: (c) => setState(() => _current = _current.copyWith(coverBadgesTextColor: c)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'Cor dos Ícones dos Badges:',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFCBD5E1)),
                ),
                const Spacer(),
                if (_current.coverBadgesIconColor.isNotEmpty &&
                    _current.coverBadgesIconColor.toUpperCase() != _current.coverBadgesTextColor.toUpperCase())
                  InkWell(
                    onTap: () => setState(() => _current = _current.copyWith(coverBadgesIconColor: '')),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFF38BDF8), width: 0.8),
                      ),
                      child: Text(
                        '🔗 Mesma da fonte',
                        style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF38BDF8), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            _buildColorChipsRow(
              selectedHex: _current.coverBadgesIconColor.isNotEmpty ? _current.coverBadgesIconColor : _current.coverBadgesTextColor,
              onSelect: (c) => setState(() => _current = _current.copyWith(coverBadgesIconColor: c)),
            ),
            const SizedBox(height: 12),
            if (_current.verticalSplitFooterBadges.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Disposição dos Badges:',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFCBD5E1),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _layoutChoiceButton(
                            label: 'Horizontal',
                            icon: Icons.view_headline_rounded,
                            isSelected: _current.verticalSplitBadgesLayout == 'horizontal',
                            onTap: () => setState(() => _current = _current.copyWith(verticalSplitBadgesLayout: 'horizontal')),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _layoutChoiceButton(
                            label: 'Vertical',
                            icon: Icons.view_agenda_rounded,
                            isSelected: _current.verticalSplitBadgesLayout == 'vertical',
                            onTap: () => setState(() => _current = _current.copyWith(verticalSplitBadgesLayout: 'vertical')),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _layoutChoiceButton(
                            label: 'Quebrar',
                            icon: Icons.wrap_text_rounded,
                            isSelected: _current.verticalSplitBadgesLayout == 'wrap',
                            onTap: () => setState(() => _current = _current.copyWith(verticalSplitBadgesLayout: 'wrap')),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Largura da Caixa:',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFCBD5E1),
                          ),
                        ),
                        Text(
                          '${(_current.verticalSplitLeftFooterWidth * 100).toInt()}% da Capa',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF38BDF8),
                          ),
                        ),
                      ],
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: const Color(0xFF0284C7),
                        inactiveTrackColor: const Color(0xFF334155),
                        thumbColor: const Color(0xFF38BDF8),
                        overlayColor: const Color(0xFF38BDF8).withValues(alpha: 0.2),
                        trackHeight: 4,
                      ),
                      child: Slider(
                        value: _current.verticalSplitLeftFooterWidth.clamp(0.20, 0.95),
                        min: 0.20,
                        max: 0.95,
                        divisions: 75,
                        onChanged: (val) {
                          setState(() {
                            _current = _current.copyWith(verticalSplitLeftFooterWidth: val);
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              for (int i = 0; i < _current.verticalSplitFooterBadges.length; i++) ...[
                Builder(
                  builder: (ctx) {
                    final badge = _current.verticalSplitFooterBadges[i];
                    final fn = _badgeFocusNodes.putIfAbsent(i, () => FocusNode());
                    final isSel = _selectedElementKey == 'leftFooter';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSel ? const Color(0xFF38BDF8) : const Color(0xFF334155),
                          width: isSel ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Botão Seletor de Ícone
                          Tooltip(
                            message: 'Clique para trocar o ícone',
                            child: InkWell(
                              onTap: () => _showBadgeIconPickerModal(i),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF475569)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      getCoverBadgeIcon(badge.iconKey),
                                      color: Color(_current.verticalSplitAccentColorValue),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 14),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Campo de Texto do Badge
                          Expanded(
                            child: TextFormField(
                              key: ValueKey('badge_txt_${i}_${badge.iconKey}'),
                              initialValue: badge.label,
                              focusNode: fn,
                              onTap: () => setState(() => _selectedElementKey == 'leftFooter'),
                              onChanged: (val) {
                                setState(() {
                                  final list = List<CoverFooterBadge>.from(_current.verticalSplitFooterBadges);
                                  list[i] = list[i].copyWith(label: val.toUpperCase());
                                  _current = _current.copyWith(verticalSplitFooterBadges: list);
                                });
                              },
                              style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'Texto do badge (ex: ECONOMIA)',
                                hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                                filled: true,
                                fillColor: const Color(0xFF1E293B),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Excluir Badge
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 18),
                            tooltip: 'Remover Badge',
                            onPressed: () => _removeBadge(i),
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],

              // Botão Adicionar Badge
              OutlinedButton.icon(
                onPressed: _addBadge,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('+ ADICIONAR BADGE'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF38BDF8),
                  side: const BorderSide(color: Color(0xFF0284C7)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
              ),
            ],
          ],
          const SizedBox(height: 24),
          const Divider(color: Color(0xFF334155)),
          const SizedBox(height: 16),

          // ── 3. SEÇÃO: TEXTOS INSTITUCIONAIS (TÍTULO E TAGLINE) ───────────
          _panelSectionTitle(
            'Textos Institucionais da Capa',
            'Identidade e mensagem corporativa',
            onDelete: _current.verticalSplitShowRightBlock
                ? () => setState(() => _current = _current.copyWith(verticalSplitShowRightBlock: false))
                : null,
            deleteTooltip: 'Ocultar Proposta Solar e Tagline',
          ),
          const SizedBox(height: 12),
          if (!_current.verticalSplitShowRightBlock)
            _buildHiddenElementBanner(
              'Bloco Proposta Solar e Tagline',
              () => setState(() => _current = _current.copyWith(verticalSplitShowRightBlock: true)),
            )
          else ...[
            _buildFontFamilySelector(
              label: 'Fonte de Proposta Solar:',
              selectedFont: _current.coverRightBlockFont,
              onSelect: (f) => setState(() => _current = _current.copyWith(coverRightBlockFont: f)),
            ),
            const SizedBox(height: 6),
            Text(
              'Cor do Título ("PROPOSTA"):',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFCBD5E1)),
            ),
            const SizedBox(height: 6),
            _buildColorChipsRow(
              selectedHex: _current.coverRightTitleColor,
              onSelect: (c) => setState(() => _current = _current.copyWith(coverRightTitleColor: c)),
            ),
            const SizedBox(height: 8),
            Text(
              'Cor do Subtítulo ("SOLAR"):',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFCBD5E1)),
            ),
            const SizedBox(height: 6),
            _buildColorChipsRow(
              selectedHex: _current.coverRightSubtitleColor,
              onSelect: (c) => setState(() => _current = _current.copyWith(coverRightSubtitleColor: c)),
            ),
            const SizedBox(height: 8),
            Text(
              'Cor da Tagline / Slogan:',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFCBD5E1)),
            ),
            const SizedBox(height: 6),
            _buildColorChipsRow(
              selectedHex: _current.coverRightTaglineColor,
              onSelect: (c) => setState(() => _current = _current.copyWith(coverRightTaglineColor: c)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _darkTextField(
                    controller: _rightTitleCtrl,
                    focusNode: _rightTitleFocusNode,
                    isHighlighted: _selectedElementKey == 'rightBlock',
                    label: 'Título',
                    hint: 'PROPOSTA',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _darkTextField(
                    controller: _rightSubtitleCtrl,
                    focusNode: _rightSubtitleFocusNode,
                    isHighlighted: _selectedElementKey == 'rightBlock',
                    label: 'Subtítulo / Destaque',
                    hint: 'AUTOMAÇÃO',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.horizontal_rule_rounded,
                            color: _current.verticalSplitShowRightDivider
                                ? Color(_current.verticalSplitRightDividerColorValue)
                                : const Color(0xFF64748B),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Linha de Destaque sob o Título',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      Switch(
                        value: _current.verticalSplitShowRightDivider,
                        activeThumbColor: const Color(0xFF38BDF8),
                        onChanged: (val) {
                          setState(() {
                            _current = _current.copyWith(verticalSplitShowRightDivider: val);
                          });
                        },
                      ),
                    ],
                  ),
                  if (_current.verticalSplitShowRightDivider) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Largura da Linha:',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFCBD5E1)),
                        ),
                        Text(
                          '${_current.verticalSplitRightDividerWidth.round()} px',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF38BDF8)),
                        ),
                      ],
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: const Color(0xFF0284C7),
                        inactiveTrackColor: const Color(0xFF334155),
                        thumbColor: const Color(0xFF38BDF8),
                        overlayColor: const Color(0xFF38BDF8).withValues(alpha: 0.2),
                        trackHeight: 3,
                      ),
                      child: Slider(
                        value: _current.verticalSplitRightDividerWidth.clamp(15.0, 160.0),
                        min: 15.0,
                        max: 160.0,
                        divisions: 29,
                        onChanged: (val) {
                          setState(() {
                            _current = _current.copyWith(verticalSplitRightDividerWidth: val);
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Espessura da Linha:',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFCBD5E1)),
                        ),
                        Text(
                          '${_current.verticalSplitRightDividerHeight.toStringAsFixed(1)} px',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF38BDF8)),
                        ),
                      ],
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: const Color(0xFF0284C7),
                        inactiveTrackColor: const Color(0xFF334155),
                        thumbColor: const Color(0xFF38BDF8),
                        overlayColor: const Color(0xFF38BDF8).withValues(alpha: 0.2),
                        trackHeight: 3,
                      ),
                      child: Slider(
                        value: _current.verticalSplitRightDividerHeight.clamp(1.0, 10.0),
                        min: 1.0,
                        max: 10.0,
                        divisions: 18,
                        onChanged: (val) {
                          setState(() {
                            _current = _current.copyWith(verticalSplitRightDividerHeight: val);
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Cor da Linha:',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFCBD5E1)),
                    ),
                    const SizedBox(height: 6),
                    _buildColorChipsRow(
                      selectedHex: _current.verticalSplitRightDividerColor.isNotEmpty
                          ? _current.verticalSplitRightDividerColor
                          : _current.verticalSplitAccentColor,
                      onSelect: (c) => setState(() => _current = _current.copyWith(verticalSplitRightDividerColor: c)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            _darkTextField(
              controller: _rightTaglineCtrl,
              focusNode: _rightTaglineFocusNode,
              isHighlighted: _selectedElementKey == 'rightBlock',
              label: 'Tagline / Slogan',
              hint: 'SOLUÇÕES EM ENERGIA\nPARA UM FUTURO MELHOR',
              maxLines: 2,
            ),
          ],
          const SizedBox(height: 24),
          const Divider(color: Color(0xFF334155)),
          const SizedBox(height: 16),

          // ── 4. SEÇÃO: RODAPÉ INSTITUCIONAL ───────────────────────────────
          _panelSectionTitle(
            'Rodapé Institucional',
            'Mensagem no rodapé da folha',
            onDelete: _current.verticalSplitShowRightFooter
                ? () => setState(() => _current = _current.copyWith(verticalSplitShowRightFooter: false))
                : null,
            deleteTooltip: 'Ocultar Rodapé Institucional',
          ),
          const SizedBox(height: 12),
          if (!_current.verticalSplitShowRightFooter)
            _buildHiddenElementBanner(
              'Rodapé Institucional',
              () => setState(() => _current = _current.copyWith(verticalSplitShowRightFooter: true)),
            )
          else ...[
            _buildFontFamilySelector(
              label: 'Fonte do Rodapé:',
              selectedFont: _current.coverFooterFont,
              onSelect: (f) => setState(() => _current = _current.copyWith(coverFooterFont: f)),
            ),
            const SizedBox(height: 6),
            Text(
              'Cor do Texto do Rodapé:',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFCBD5E1)),
            ),
            const SizedBox(height: 6),
            _buildColorChipsRow(
              selectedHex: _current.coverFooterColor,
              onSelect: (c) => setState(() => _current = _current.copyWith(coverFooterColor: c)),
            ),
            const SizedBox(height: 12),
            _darkTextField(
              controller: _rightFooterCtrl,
              focusNode: _rightFooterFocusNode,
              isHighlighted: _selectedElementKey == 'rightFooter',
              label: 'Rodapé Institucional',
              hint: 'ENERGIA HOJE.\nMAIS POSSIBILIDADES\nAMANHÃ.',
              maxLines: 2,
            ),
          ],
          const SizedBox(height: 24),
          const Divider(color: Color(0xFF334155)),
          const SizedBox(height: 16),

          // ── 5. SEÇÃO: DADOS DO CLIENTE & CPF/CNPJ ───────────────────────────────
          _panelSectionTitle(
            'Dados do Cliente & CPF/CNPJ',
            'Posição, cores e dimensões dos dados do cliente e solução na capa',
            onDelete: _current.coverShowClientInfo
                ? () => setState(() => _current = _current.copyWith(coverShowClientInfo: false))
                : null,
            deleteTooltip: 'Ocultar Dados do Cliente',
          ),
          const SizedBox(height: 12),
          if (!_current.coverShowClientInfo)
            _buildHiddenElementBanner(
              'Dados do Cliente & CPF/CNPJ',
              () => setState(() => _current = _current.copyWith(coverShowClientInfo: true)),
            )
          else ...[
            Text(
              'Cor Principal (Nome do Cliente):',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFCBD5E1)),
            ),
            const SizedBox(height: 6),
            _buildColorChipsRow(
              selectedHex: _current.coverClientInfoColor,
              onSelect: (c) => setState(() => _current = _current.copyWith(coverClientInfoColor: c)),
            ),
            const SizedBox(height: 12),
            Text(
              'Cor Secundária (CPF/CNPJ e Solução):',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFCBD5E1)),
            ),
            const SizedBox(height: 6),
            _buildColorChipsRow(
              selectedHex: _current.coverClientInfoSecondaryColor,
              onSelect: (c) => setState(() => _current = _current.copyWith(coverClientInfoSecondaryColor: c)),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tamanho da Fonte:',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFCBD5E1)),
                ),
                Text(
                  '${_current.coverClientInfoFontSize.toStringAsFixed(1)} pt',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF38BDF8)),
                ),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: const Color(0xFF0284C7),
                inactiveTrackColor: const Color(0xFF334155),
                thumbColor: const Color(0xFF38BDF8),
                overlayColor: const Color(0xFF38BDF8).withValues(alpha: 0.2),
                trackHeight: 4,
              ),
              child: Slider(
                value: _current.coverClientInfoFontSize.clamp(6.0, 16.0),
                min: 6.0,
                max: 16.0,
                divisions: 20,
                onChanged: (val) {
                  setState(() {
                    _current = _current.copyWith(coverClientInfoFontSize: val);
                  });
                },
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Largura da Caixa:',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFCBD5E1)),
                ),
                Text(
                  '${_current.coverClientInfoWidth.toInt()} pt',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF38BDF8)),
                ),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: const Color(0xFF0284C7),
                inactiveTrackColor: const Color(0xFF334155),
                thumbColor: const Color(0xFF38BDF8),
                overlayColor: const Color(0xFF38BDF8).withValues(alpha: 0.2),
                trackHeight: 4,
              ),
              child: Slider(
                value: _current.coverClientInfoWidth.clamp(120.0, 500.0),
                min: 120.0,
                max: 500.0,
                divisions: 38,
                onChanged: (val) {
                  setState(() {
                    _current = _current.copyWith(coverClientInfoWidth: val);
                  });
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStyleTab() {
    if (_current.proposalStyle == 'modern') {
      return _buildModernStyleTab();
    }
    return _buildVerticalSplitStyleTab();
  }

  Widget _buildVerticalSplitStyleTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _panelSectionTitle('Tipo de Corte do Divisor', 'Selecione a geometria do divisor vetorial da capa'),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildDividerTypeCard(0, '📐 Corte Diagonal', 'Clássico e arrojado'),
              const SizedBox(width: 10),
              _buildDividerTypeCard(1, '⚡ Raio de Energia', 'Dinâmico em zig-zag'),
              const SizedBox(width: 10),
              _buildDividerTypeCard(2, '☀️ Sol Radiante', 'Arco com auréola solar'),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(color: Color(0xFF334155)),
          const SizedBox(height: 16),

          _panelSectionTitle('Cor de Destaque / Acento', 'Cor da barra de título e linha do divisor'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildColorOption('#EAB308', 'Amarelo Dourado'),
              _buildColorOption('#F59E0B', 'Âmbar Solar'),
              _buildColorOption('#F97316', 'Laranja Intenso'),
              _buildColorOption('#10B981', 'Verde Esmeralda'),
              _buildColorOption('#0284C7', 'Azul Royal'),
              _buildColorOption('#8B5CF6', 'Roxo Moderno'),
              _buildColorOption('#EF4444', 'Vermelho Energia'),
              _buildColorOption('#0F172A', 'Preto Premium'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModernStyleTab() {
    final dividers = AutomationSettingsService.getAvailableDividers();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. SELETOR DOS 10 MODELOS DE SEPARADOR MATEMÁTICO ──
          _panelSectionTitle(
            'Estilo do Separador / Decalque da Foto (10 Opções)',
            'Cortes geométricos calculados com linhas fluidas e fitas decorativas',
          ),
          const SizedBox(height: 14),

          LayoutBuilder(
            builder: (ctx, constraints) {
              final availableW = constraints.maxWidth;
              final isTwoCols = availableW >= 360;
              final cardW = isTwoCols ? (availableW - 10) / 2 : availableW;

              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: dividers.map((div) {
                  final divId = div['id'] as int;
                  final isSelected = _current.customDividerStyle == divId;

                  return SizedBox(
                    width: cardW,
                    child: InkWell(
                      onTap: () => setState(() {
                        _current = _current.copyWith(
                          customDividerStyle: divId,
                          isCustomCoverMode: divId >= 0,
                        );
                      }),
                      borderRadius: BorderRadius.circular(10),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF0F172A).withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? const Color(0xFFEAB308) : const Color(0xFF334155),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Mini Preview Vetorial do Separador
                            Container(
                              width: 50,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFFEAB308) : const Color(0xFF334155),
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(5),
                                child: divId < 0
                                    ? Center(
                                        child: Icon(
                                          Icons.fullscreen_rounded,
                                          size: 22,
                                          color: isSelected ? const Color(0xFFEAB308) : const Color(0xFF94A3B8),
                                        ),
                                      )
                                    : CustomPaint(
                                        painter: SolarCoverDividerPainter(
                                          dividerType: divId,
                                          primaryColor: Color(_hexToInt(_current.customDividerColor)),
                                          bottomAreaColor: Color(_hexToInt(_current.customDividerBottomColor)),
                                          splitYRatio: 0.58,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: isSelected ? const Color(0xFFEAB308).withValues(alpha: 0.2) : const Color(0xFF1E293B),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          divId < 0 ? 'OFF' : '#${divId + 1}',
                                          style: GoogleFonts.outfit(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: isSelected ? const Color(0xFFEAB308) : const Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Expanded(
                                        child: Text(
                                          div['name'] as String,
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: isSelected ? const Color(0xFFEAB308) : Colors.white,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    div['desc'] as String,
                                    style: GoogleFonts.inter(fontSize: 9.5, color: const Color(0xFF94A3B8)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),

          const SizedBox(height: 24),
          const Divider(color: Color(0xFF334155)),
          const SizedBox(height: 16),

          // ── 2. COR DO SEPARADOR / FITA GEOMÉTRICA ──
          _panelSectionTitle(
            'Cor do Separador / Fita Geométrica',
            'Tonalidade das linhas decorativas e degradê do decalque',
          ),
          const SizedBox(height: 12),
          _buildColorChipsRow(
            selectedHex: _current.customDividerColor,
            onSelect: (c) => setState(() => _current = _current.copyWith(customDividerColor: c)),
          ),

          const SizedBox(height: 20),

          // ── 2.1. COR DA ÁREA INFERIOR (ÁREA BRANCA DA CAPA) ──
          _panelSectionTitle(
            'Cor da Área Inferior (Base da Capa)',
            'Tonalidade de fundo da área de rodapé e dados do cliente abaixo do separador',
          ),
          const SizedBox(height: 12),
          _buildColorChipsRow(
            selectedHex: _current.customDividerBottomColor,
            onSelect: (c) => setState(() => _current = _current.copyWith(customDividerBottomColor: c)),
          ),

          const SizedBox(height: 24),
          const Divider(color: Color(0xFF334155)),
          const SizedBox(height: 16),

          // ── 3. FOTO PERSONALIZADA DA EMPRESA ──
          _panelSectionTitle(
            'Foto de Fundo da Capa',
            'Envie uma foto em alta resolução do seu escritório ou usina instalada',
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.cloud_upload_rounded, color: Color(0xFF10B981), size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Foto Personalizada',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                      ),
                      Text(
                        _current.customCoverImageBase64 != null && _current.customCoverImageBase64!.isNotEmpty
                            ? '✅ Foto customizada carregada e ativa'
                            : 'Usando imagem padrão do sistema',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: _current.customCoverImageBase64 != null ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _pickCustomCoverPhoto,
                  icon: const Icon(Icons.folder_open_rounded, size: 16),
                  label: Text(_current.customCoverImageBase64 != null ? 'TROCAR FOTO' : 'ESCOLHER FOTO'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCyberNodesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── BOTÕES DE AÇÃO SUPERIOR (NOVA CONEXÃO & RESTAURAR) ─────────────
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _addCyberNode,
                  icon: const Icon(Icons.add_location_alt_rounded, size: 16),
                  label: const Text('+ NOVO PONTO INTELIGENTE'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: _resetDefaultNodes,
                icon: const Icon(Icons.restore_rounded, size: 16),
                label: const Text('PADRÃO'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF94A3B8),
                  side: const BorderSide(color: Color(0xFF475569)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // ── CONTROLE DO TAMANHO DA FONTE DOS RÓTULOS DOS NÓS ──
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.format_size_rounded, color: Color(0xFF38BDF8), size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Tamanho da Fonte dos Rótulos',
                          style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        ' pt',
                        style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF38BDF8)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: const Color(0xFF38BDF8),
                    inactiveTrackColor: const Color(0xFF334155),
                    thumbColor: const Color(0xFF38BDF8),
                    overlayColor: const Color(0xFF38BDF8).withValues(alpha: 0.2),
                    trackHeight: 3,
                  ),
                  child: Slider(
                    value: _current.coverNodesLabelFontSize.clamp(6.0, 18.0),
                    min: 6.0,
                    max: 18.0,
                    divisions: 24,
                    onChanged: (val) {
                      setState(() {
                        _current = _current.copyWith(coverNodesLabelFontSize: val);
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _panelSectionTitle('Pontos Tecnológicos na Fachada', 'Posicione os ícones inteligentes sobre a arquitetura da residência'),
          const SizedBox(height: 12),

          // Dica de uso
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0284C7).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                const Icon(Icons.touch_app_rounded, color: Color(0xFF38BDF8), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Arraste livremente o ícone e o anel alvo na folha A4 para apontar exatamente para o telhado, esquadria, porta ou cômodo da casa.',
                    style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFFE0F2FE), height: 1.3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Lista de Nós Cibernéticos
          if (_current.nodes.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    const Icon(Icons.hub_outlined, color: Color(0xFF64748B), size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'Nenhum ponto inteligente na capa',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _resetDefaultNodes,
                      icon: const Icon(Icons.restore_rounded),
                      label: const Text('Restaurar 5 Pontos Padrão'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            for (int idx = 0; idx < _current.nodes.length; idx++) ...[
              Builder(
                builder: (ctx) {
                  final node = _current.nodes[idx];
                  final isSel = _selectedElementKey == 'node_${node.id}' || _selectedElementKey == 'node_target_${node.id}';
                  final nodeColor = Color(_hexToInt(node.colorHex, fallback: 0xFF38BDF8));

                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSel ? const Color(0xFF38BDF8) : const Color(0xFF334155),
                        width: isSel ? 2 : 1,
                      ),
                      boxShadow: isSel
                          ? [
                              BoxShadow(
                                color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Cabeçalho do Card
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF1E293B),
                                border: Border.all(color: nodeColor, width: 1.8),
                              ),
                              child: Center(
                                child: Icon(_getNodeIcon(node.iconName), size: 16, color: nodeColor),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    node.label.isNotEmpty ? node.label : 'Ponto #${idx + 1}',
                                    style: GoogleFonts.inter(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: isSel ? const Color(0xFF38BDF8) : Colors.white,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Ícone: (${(node.posX * 100).toInt()}%, ${(node.posY * 100).toInt()}%) • Alvo: (${(node.targetX * 100).toInt()}%, ${(node.targetY * 100).toInt()}%)',
                                    style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                            if (isSel)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0284C7),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'SELECIONADO',
                                  style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                            const SizedBox(width: 6),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 18),
                              tooltip: 'Excluir Ponto',
                              onPressed: () => _removeCyberNode(node.id),
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Campo Nome / Rótulo
                        Text(
                          'RÓTULO DO PONTO:',
                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white70),
                        ),
                        const SizedBox(height: 4),
                        TextFormField(
                          key: ValueKey('node_lbl_${node.id}'),
                          initialValue: node.label,
                          onTap: () => setState(() => _selectedElementKey = 'node_${node.id}'),
                          onChanged: (val) => _updateNode(node.id, label: val),
                          style: GoogleFonts.inter(fontSize: 12.5, color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Ex: ILUMINAÇÃO CÊNICA, ÁUDIO HIGH END...',
                            hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                            filled: true,
                            fillColor: const Color(0xFF1E293B),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Seletor de Ícone
                        Text(
                          'ÍCONE TECNOLÓGICO:',
                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white70),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            {'key': 'light', 'icon': Icons.lightbulb_outline_rounded, 'tip': 'Iluminação'},
                            {'key': 'music', 'icon': Icons.music_note_rounded, 'tip': 'Áudio / Som'},
                            {'key': 'temp', 'icon': Icons.thermostat_rounded, 'tip': 'Climatização'},
                            {'key': 'camera', 'icon': Icons.videocam_outlined, 'tip': 'Câmera / AI'},
                            {'key': 'lock', 'icon': Icons.lock_outline_rounded, 'tip': 'Acesso / Biometria'},
                            {'key': 'wifi', 'icon': Icons.wifi_rounded, 'tip': 'Wi-Fi / Rede'},
                            {'key': 'tv', 'icon': Icons.tv_rounded, 'tip': 'Home Cinema'},
                            {'key': 'curtain', 'icon': Icons.curtains_rounded, 'tip': 'Cortinas'},
                            {'key': 'shield', 'icon': Icons.security_rounded, 'tip': 'Segurança'},
                            {'key': 'power', 'icon': Icons.power_settings_new_rounded, 'tip': 'Energia'},
                          ].map((opt) {
                            final iconKey = opt['key'] as String;
                            final iconData = opt['icon'] as IconData;
                            final tip = opt['tip'] as String;
                            final isIconSel = node.iconName.toLowerCase() == iconKey;

                            return Tooltip(
                              message: tip,
                              child: InkWell(
                                onTap: () => _updateNode(node.id, iconName: iconKey),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: isIconSel ? const Color(0xFF0284C7) : const Color(0xFF1E293B),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isIconSel ? Colors.white : const Color(0xFF334155),
                                      width: isIconSel ? 1.8 : 1,
                                    ),
                                  ),
                                  child: Icon(
                                    iconData,
                                    size: 16,
                                    color: isIconSel ? Colors.white : const Color(0xFFCBD5E1),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 10),

                        // Seletor de Cor Neon
                        Row(
                          children: [
                            Text(
                              'COR NEON:',
                              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white70),
                            ),
                            const SizedBox(width: 8),
                            Wrap(
                              spacing: 6,
                              children: ['#38BDF8', '#00E5FF', '#2563EB', '#10B981', '#EAB308', '#A855F7', '#EF4444', '#FFFFFF'].map((hex) {
                                final isColorSel = node.colorHex.toUpperCase() == hex.toUpperCase();
                                return InkWell(
                                  onTap: () => _updateNode(node.id, colorHex: hex),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: Color(_hexToInt(hex)),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isColorSel ? Colors.white : Colors.transparent,
                                        width: isColorSel ? 2 : 1,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Switch Linha Conectora
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Linha Conectora na Fachada',
                              style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFFCBD5E1)),
                            ),
                            Switch(
                              value: node.showConnectorLine,
                              activeThumbColor: const Color(0xFF38BDF8),
                              onChanged: (val) => _updateNode(node.id, showConnectorLine: val),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
        ],
      ),
    );
  }

  Widget _buildLogoAndWallpaperTab() {
    final defaultCovers = AutomationSettingsService.getDefaultCoverList();
    final defaultBgs = AutomationSettingsModel.availableWebBackgrounds;

    final isCoversMode = _selectedCoverGalleryTab == 0;
    final currentList = isCoversMode ? defaultCovers : defaultBgs;

    final filteredList = _coverSearchQuery.trim().isEmpty
        ? currentList
        : currentList.where((name) {
            final query = _coverSearchQuery.toLowerCase().trim();
            final nameLower = name.toLowerCase();
            final numOnly = name.replaceAll(RegExp(r'\D'), '');
            return nameLower.contains(query) || numOnly == query;
          }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _panelSectionTitle('Logomarca da Empresa na Capa', 'Exiba sua marca no topo da capa'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Row(
              children: [
                Switch.adaptive(
                  value: _current.coverShowLogo,
                  activeTrackColor: const Color(0xFFEAB308),
                  onChanged: (val) => setState(() => _current = _current.copyWith(coverShowLogo: val)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Exibir logomarca da empresa na folha de capa',
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _pickCompanyLogo,
                  icon: const Icon(Icons.cloud_upload_rounded, size: 16),
                  label: const Text('TROCAR LOGO'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Divider(color: Color(0xFF334155)),
          const SizedBox(height: 16),

          // ── FOTO DE FUNDO PERSONALIZADA (UPLOAD DO USUÁRIO) ─────────────────
          _panelSectionTitle(
            'Foto de Fundo Personalizada (Upload)',
            'Envie uma foto do seu escritório, projeto ou residência para ser o background da capa',
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (_current.customCoverImageBase64 != null && _current.customCoverImageBase64!.isNotEmpty)
                    ? const Color(0xFF10B981)
                    : const Color(0xFF334155),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (_current.customCoverImageBase64 != null && _current.customCoverImageBase64!.isNotEmpty)
                        ? const Color(0xFF10B981).withValues(alpha: 0.2)
                        : const Color(0xFF0284C7).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    (_current.customCoverImageBase64 != null && _current.customCoverImageBase64!.isNotEmpty)
                        ? Icons.check_circle_rounded
                        : Icons.add_photo_alternate_rounded,
                    color: (_current.customCoverImageBase64 != null && _current.customCoverImageBase64!.isNotEmpty)
                        ? const Color(0xFF10B981)
                        : const Color(0xFF38BDF8),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Foto Personalizada como Background',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        (_current.customCoverImageBase64 != null && _current.customCoverImageBase64!.isNotEmpty)
                            ? '✅ Foto do usuário aplicada como plano de fundo da capa'
                            : 'Envie uma foto da sua máquina (.jpg, .png, .webp) para ser a capa',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: (_current.customCoverImageBase64 != null && _current.customCoverImageBase64!.isNotEmpty)
                              ? const Color(0xFF34D399)
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_current.customCoverImageBase64 != null && _current.customCoverImageBase64!.isNotEmpty) ...[
                  IconButton(
                    tooltip: 'Remover foto personalizada e voltar ao catálogo',
                    icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
                    onPressed: () {
                      setState(() {
                        _current = _current.copyWith(
                          customCoverImageBase64: null,
                          isCustomCoverMode: false,
                        );
                      });
                    },
                  ),
                  const SizedBox(width: 6),
                ],
                ElevatedButton.icon(
                  onPressed: _pickCustomCoverPhoto,
                  icon: const Icon(Icons.cloud_upload_rounded, size: 16),
                  label: Text((_current.customCoverImageBase64 != null && _current.customCoverImageBase64!.isNotEmpty)
                      ? 'TROCAR FOTO'
                      : 'ENVIAR FOTO'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (_current.customCoverImageBase64 != null && _current.customCoverImageBase64!.isNotEmpty)
                        ? const Color(0xFF059669)
                        : const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Divider(color: Color(0xFF334155)),
          const SizedBox(height: 16),

          _panelSectionTitle(
            'Galeria de Capas em Formato A4',
            'Selecione o modelo da capa para atualizar a folha do lado esquerdo com 1 clique',
          ),
          const SizedBox(height: 14),

          // Seletor de Categoria (100 Capas A4 vs 34 Wallpapers HD vs Enviar Minha Foto)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _selectedCoverGalleryTab = 0),
                    borderRadius: BorderRadius.circular(8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _selectedCoverGalleryTab == 0 ? const Color(0xFFEAB308) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.description_outlined,
                            size: 15,
                            color: _selectedCoverGalleryTab == 0 ? Colors.black : Colors.white70,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '100 Capas Oficiais A4',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: _selectedCoverGalleryTab == 0 ? Colors.black : Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _selectedCoverGalleryTab = 1),
                    borderRadius: BorderRadius.circular(8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _selectedCoverGalleryTab == 1 ? const Color(0xFFEAB308) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.wallpaper_rounded,
                            size: 15,
                            color: _selectedCoverGalleryTab == 1 ? Colors.black : Colors.white70,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '34 Fotos de Fundo HD',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: _selectedCoverGalleryTab == 1 ? Colors.black : Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: InkWell(
                    onTap: _pickCustomCoverPhoto,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: (_current.customCoverImageBase64 != null && _current.customCoverImageBase64!.isNotEmpty)
                            ? const Color(0xFF059669)
                            : const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: (_current.customCoverImageBase64 != null && _current.customCoverImageBase64!.isNotEmpty)
                              ? const Color(0xFF10B981)
                              : const Color(0xFF334155),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_rounded,
                            size: 15,
                            color: (_current.customCoverImageBase64 != null && _current.customCoverImageBase64!.isNotEmpty)
                                ? Colors.white
                                : const Color(0xFF38BDF8),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            (_current.customCoverImageBase64 != null && _current.customCoverImageBase64!.isNotEmpty)
                                ? 'Sua Foto Ativa'
                                : 'Enviar Minha Foto',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: (_current.customCoverImageBase64 != null && _current.customCoverImageBase64!.isNotEmpty)
                                  ? Colors.white
                                  : const Color(0xFF38BDF8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Campo de Busca Rápida
          TextField(
            onChanged: (val) => setState(() => _coverSearchQuery = val),
            style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Buscar número da capa (ex: 1, 15, 88)...',
              hintStyle: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 12),
              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 18),
              suffixIcon: _coverSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, color: Colors.white54, size: 16),
                      onPressed: () => setState(() => _coverSearchQuery = ''),
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFF0F172A),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF334155))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF334155))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFEAB308))),
            ),
          ),
          const SizedBox(height: 14),

          // Aviso se houver foto personalizada ativa
          if (_current.customCoverImageBase64 != null && _current.customCoverImageBase64!.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF059669).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Color(0xFF10B981), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Você está usando uma foto personalizada. Clique em qualquer capa abaixo para voltar ao catálogo.',
                      style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFFD1FAE5)),
                    ),
                  ),
                ],
              ),
            ),

          // Grid de Capas com proporção vertical A4 (childAspectRatio: 0.71)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.71, // Proporção Exata A4 Vertical
            ),
            itemCount: filteredList.length,
            itemBuilder: (ctx, idx) {
              final item = filteredList[idx];
              final isCustomActive = _current.customCoverImageBase64 != null && _current.customCoverImageBase64!.isNotEmpty;
              final isSel = !isCustomActive &&
                  (_current.selectedCoverTemplate == item || _current.webBackgroundTemplate == item);

              final rawUrl = isCoversMode
                  ? AutomationSettingsService.getSmallCoverUrl(item)
                  : AutomationSettingsService.getWebBackgroundUrl(item);
              final thumbUrl = 'https://wsrv.nl/?url=${Uri.encodeComponent(rawUrl)}&w=300&output=webp';

              final numMatch = RegExp(r'\d+').firstMatch(item);
              final displayNum = numMatch != null ? numMatch.group(0) : '${idx + 1}';

              return InkWell(
                onTap: () {
                  setState(() {
                    _current = _current.copyWith(
                      selectedCoverTemplate: item,
                      webBackgroundTemplate: item,
                      customCoverImageBase64: null,
                    );
                  });
                },
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSel ? const Color(0xFFEAB308) : const Color(0xFF334155),
                      width: isSel ? 2.5 : 1,
                    ),
                    boxShadow: isSel
                        ? [
                            BoxShadow(
                              color: const Color(0xFFEAB308).withValues(alpha: 0.40),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(isSel ? 7.5 : 9),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Imagem da Capa (A4) com loading e fallback robusto
                        Image.network(
                          thumbUrl,
                          fit: BoxFit.cover,
                          loadingBuilder: (ctx, child, progress) {
                            if (progress == null) return child;
                            return Container(
                              color: const Color(0xFF1E293B),
                              child: const Center(
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFEAB308)),
                                ),
                              ),
                            );
                          },
                          errorBuilder: (_, __, ___) => Image.network(
                            rawUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: const Color(0xFF0F172A),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.image_outlined, color: Colors.white24, size: 22),
                                    const SizedBox(height: 4),
                                    Text('#$displayNum', style: const TextStyle(color: Colors.white70, fontSize: 10)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Gradiente escuro no rodapé
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: 40,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.85)],
                              ),
                            ),
                          ),
                        ),

                        // Badge no topo: Número da Capa
                        Positioned(
                          top: 6,
                          left: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.white24, width: 0.5),
                            ),
                            child: Text(
                              '#$displayNum',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),

                        // Ícone de Selecionado no topo direito
                        if (isSel)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.black87,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_circle_rounded,
                                color: Color(0xFFEAB308),
                                size: 18,
                              ),
                            ),
                          ),

                        // Legenda no rodapé
                        Positioned(
                          left: 4,
                          right: 4,
                          bottom: 5,
                          child: Text(
                            isCoversMode ? 'Capa #$displayNum' : 'Foto #$displayNum',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDividerTypeCard(int type, String title, String subtitle) {
    final isSelected = _current.verticalSplitDividerType == type;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _current = _current.copyWith(verticalSplitDividerType: type)),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF0F172A).withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFFEAB308) : const Color(0xFF334155),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? const Color(0xFFEAB308) : Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF94A3B8)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColorOption(String hex, String name) {
    final isSelected = _current.verticalSplitAccentColor.toLowerCase() == hex.toLowerCase();
    final color = Color(int.parse(hex.replaceAll('#', 'FF'), radix: 16));

    return InkWell(
      onTap: () => setState(() => _current = _current.copyWith(verticalSplitAccentColor: hex)),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : const Color(0xFF334155),
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
              name,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _panelSectionTitle(String title, String subtitle, {VoidCallback? onDelete, String? deleteTooltip}) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 2),
              Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
            ],
          ),
        ),
        if (onDelete != null)
          IconButton(
            icon: const Icon(Icons.visibility_off_outlined, color: Color(0xFF94A3B8), size: 18),
            tooltip: deleteTooltip ?? 'Ocultar Elemento',
            onPressed: onDelete,
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(4),
          ),
      ],
    );
  }

  Widget _layoutChoiceButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF475569),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : const Color(0xFF94A3B8),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHiddenElementBanner(String title, VoidCallback onRestore) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF475569)),
      ),
      child: Row(
        children: [
          const Icon(Icons.visibility_off_rounded, color: Color(0xFF94A3B8), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$title (Ocultado)',
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8), fontStyle: FontStyle.italic),
            ),
          ),
          TextButton.icon(
            onPressed: onRestore,
            icon: const Icon(Icons.restore_rounded, size: 14, color: Color(0xFF38BDF8)),
            label: const Text('EXIBIR', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11.5, fontWeight: FontWeight.bold)),
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
          ),
        ],
      ),
    );
  }

  Widget _darkTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    FocusNode? focusNode,
    bool isHighlighted = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isHighlighted ? const Color(0xFF38BDF8) : Colors.transparent,
          width: 1.5,
        ),
      ),
      padding: isHighlighted ? const EdgeInsets.all(4) : EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: isHighlighted ? const Color(0xFF38BDF8) : const Color(0xFFCBD5E1),
                ),
              ),
              if (isHighlighted) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('SELECIONADO NO CANVAS', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            focusNode: focusNode,
            maxLines: maxLines,
            style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
              filled: true,
              fillColor: const Color(0xFF0F172A),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: isHighlighted ? const Color(0xFF38BDF8) : const Color(0xFF334155)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFEAB308), width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
