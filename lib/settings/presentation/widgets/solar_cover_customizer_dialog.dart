import 'dart:convert';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';
import '../../../proposals/data/services/solar_proposal_pdf_service.dart';
import '../../../proposals/domain/models/proposal_item_model.dart';
import '../../../proposals/domain/models/proposal_model.dart';
import '../../data/services/solar_settings_service.dart';
import '../../domain/models/solar_settings_model.dart';
import 'solar_cover_divider_painter.dart';
import 'solar_vertical_split_painter.dart';

/// Modal amplo de estúdio visual para personalização interativa em tempo real da capa da proposta
class SolarCoverCustomizerDialog extends StatefulWidget {
  final SolarSettingsModel initialSettings;
  final ValueChanged<SolarSettingsModel> onSave;

  const SolarCoverCustomizerDialog({
    super.key,
    required this.initialSettings,
    required this.onSave,
  });

  static Future<SolarSettingsModel?> show(
    BuildContext context, {
    required SolarSettingsModel initialSettings,
    required ValueChanged<SolarSettingsModel> onSave,
  }) {
    return showDialog<SolarSettingsModel>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SolarCoverCustomizerDialog(
        initialSettings: initialSettings,
        onSave: onSave,
      ),
    );
  }

  @override
  State<SolarCoverCustomizerDialog> createState() => _SolarCoverCustomizerDialogState();
}

class _SolarCoverCustomizerDialogState extends State<SolarCoverCustomizerDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late SolarSettingsModel _current;
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

  // Dimensões base A4
  static const double a4Width = 595.28;
  static const double a4Height = 841.89;

  @override
  void initState() {
    super.initState();
    _current = widget.initialSettings;
    if (_current.proposalStyle != 'verticalSplit') {
      if (_current.verticalSplitRightBlockTop >= 0.70 ||
          (_current.verticalSplitRightBlockTop == 0.20 && _current.verticalSplitHeadlineTop == 0.06)) {
        _current = _current.copyWith(
          verticalSplitRightBlockTop: 0.04,
          verticalSplitRightBlockRight: 0.48,
          verticalSplitHeadlineTop: 0.50,
          verticalSplitHeadlineLeft: 0.06,
          verticalSplitLeftFooterBottom: 0.26,
          verticalSplitLeftFooterLeft: 0.06,
          coverLogoPositionX: 0.78,
          coverLogoPositionY: 0.78,
          coverLogoWidth: 95.0,
        );
      }
    }
    _tabController = TabController(length: 3, vsync: this);

    _headlineCtrl = TextEditingController(text: _current.verticalSplitHeadline);
    _subheadlineCtrl = TextEditingController(text: _current.verticalSplitSubheadline);
    _rightTitleCtrl = TextEditingController(text: _current.verticalSplitRightTitle);
    _rightSubtitleCtrl = TextEditingController(text: _current.verticalSplitRightSubtitle);
    _rightTaglineCtrl = TextEditingController(text: _current.verticalSplitRightTagline);
    _leftFooterCtrl = TextEditingController(text: _current.verticalSplitLeftFooter);
    _rightFooterCtrl = TextEditingController(text: _current.verticalSplitRightFooter);

    _coverTitleCtrl = TextEditingController(text: _current.coverTitle);
    _coverSubtitleCtrl = TextEditingController(text: _current.coverSubtitle);

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
        // Logo:
        coverShowLogo: true,
        coverLogoPositionX: _current.proposalStyle != 'verticalSplit' ? 0.78 : 0.65,
        coverLogoPositionY: _current.proposalStyle != 'verticalSplit' ? 0.78 : 0.05,
        coverLogoWidth: 95.0,
      );
      _coverTitleCtrl.text = 'PROPOSTA COMERCIAL';
      _coverSubtitleCtrl.text = 'ENERGIA SOLAR FOTOVOLTAICA';
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
      debugPrint('[SolarCoverCustomizerDialog] Erro ao selecionar foto: $e');
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

  void _previewPdf() {
    final sampleProposal = ProposalModel(
      id: 'preview_id',
      proposalNumber: 'PROP-2026/001',
      title: 'Proposta Comercial Usina Solar',
      clientName: 'Cliente Exemplo Proposta',
      clientEmail: 'cliente@exemplo.com.br',
      clientPhone: '(11) 98765-4321',
      subtotal: 24500.0,
      totalAmount: 24500.0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      status: ProposalStatus.negotiating,
      items: [
        ProposalItemModel(
          name: 'Usina Solar Fotovoltaica 8.68 kWp',
          quantity: 1,
          unitPrice: 24500.0,
          totalPrice: 24500.0,
          isSolarPlant: true,
          solarKilowatts: 8.68,
          solarRoofType: 'Cerâmico',
          solarComponents: [
            '14x Módulo Solar Monocristalino 620W N-Type Bifacial',
            '1x Inversor Solar Grid-Tie 6kW String Wi-Fi',
            '1x Estrutura Fixação Telhado Cerâmico Alumínio Anodizado',
            '1x String Box CC 2 Entradas / 2 Saídas com DPS',
          ],
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
                  Text(
                    'Prévia Instantânea do PDF com o seu Layout Personalizado',
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
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
                  build: (format) => SolarProposalPdfService.generateSolarProposalPdf(
                    sampleProposal,
                    solarSettings: _current,
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
    setState(() => _isSaving = true);
    try {
      await SolarSettingsService.saveSettings(_current);
      widget.onSave(_current);
      if (mounted) {
        Navigator.pop(context, _current);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configurações e posições da capa salvas com sucesso!'),
            backgroundColor: Color(0xFF059669),
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
                    flex: 6,
                    child: _buildInteractiveCanvasArea(),
                  ),

                  // DIVISOR
                  Container(width: 1, color: const Color(0xFF1E293B)),

                  // LADO DIREITO: INSPECTOR EM TEMPO REAL
                  Expanded(
                    flex: 5,
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
                'Estúdio Visual da Capa • Personalização Livre em Tempo Real',
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
          const SizedBox(width: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _current.proposalStyle == 'verticalSplit'
                  ? const Color(0xFFEAB308).withValues(alpha: 0.18)
                  : const Color(0xFF0284C7).withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _current.proposalStyle == 'verticalSplit'
                    ? const Color(0xFFEAB308)
                    : const Color(0xFF0284C7),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _current.proposalStyle == 'verticalSplit' ? Icons.view_sidebar_rounded : Icons.style_rounded,
                  size: 14,
                  color: _current.proposalStyle == 'verticalSplit' ? const Color(0xFFEAB308) : const Color(0xFF38BDF8),
                ),
                const SizedBox(width: 6),
                Text(
                  _current.proposalStyle == 'verticalSplit' ? 'ESTILO VERTICAL SPLIT' : 'ESTILO MODERN',
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: _current.proposalStyle == 'verticalSplit' ? const Color(0xFFEAB308) : const Color(0xFF38BDF8),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),

          // Botão Resetar
          OutlinedButton.icon(
            onPressed: _resetPositions,
            icon: const Icon(Icons.restart_alt_rounded, size: 16),
            label: const Text('RESETAR'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFCBD5E1),
              side: const BorderSide(color: Color(0xFF475569)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // CANVAS A4 INTERATIVO COM DRAG & DROP LIVRE
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildInteractiveCanvasArea() {
    return Container(
      color: const Color(0xFF0B1120),
      child: Center(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: LayoutBuilder(
            builder: (ctx, constraints) {
              // Altura disponível e escala do canvas
              final maxH = 680.0;
              final scale = maxH / a4Height;
              final canvasW = a4Width * scale;
              final canvasH = maxH;

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
                        SolarVerticalSplitCoverView(
                          settings: _current,
                          width: canvasW,
                          height: canvasH,
                          clientName: 'João da Silva Santos',
                          proposalNumber: 'PROP-2026/001',
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
                            label: '📌 Proposta Solar',
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
                        // 1. Imagem de Fundo
                        if (_current.isCustomCoverMode &&
                            _current.customCoverImageBase64 != null &&
                            _current.customCoverImageBase64!.isNotEmpty)
                          Image.memory(
                            base64Decode(_current.customCoverImageBase64!),
                            fit: BoxFit.cover,
                            width: canvasW,
                            height: canvasH,
                          )
                        else if (_current.isCustomCoverMode)
                          Image.network(
                            SolarSettingsService.getWebBackgroundUrl(_current.webBackgroundTemplate),
                            fit: BoxFit.cover,
                            width: canvasW,
                            height: canvasH,
                            errorBuilder: (_, __, ___) => Container(color: const Color(0xFF0F172A)),
                          )
                        else
                          Image.network(
                            SolarSettingsService.getBigCoverUrl(_current.selectedCoverTemplate),
                            fit: BoxFit.cover,
                            width: canvasW,
                            height: canvasH,
                            errorBuilder: (_, __, ___) => Container(color: const Color(0xFF0F172A)),
                          ),

                        // 2. Separador Vetorial / Decalque da Foto (SOMENTE se for foto limpa/personalizada)
                        if (_current.isCustomCoverMode)
                          CustomPaint(
                            size: Size(canvasW, canvasH),
                            painter: SolarCoverDividerPainter(
                              dividerType: _current.customDividerStyle,
                              primaryColor: Color(_hexToInt(_current.customDividerColor)),
                              splitYRatio: 0.70,
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
                                    SizedBox(height: 6 * scale),
                                    Container(
                                      width: 44 * scale,
                                      height: 3.5 * scale,
                                      decoration: BoxDecoration(
                                        color: Color(_current.verticalSplitAccentColorValue),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
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

                        // Dados do Cliente & Geração (canto inferior direito fixo)
                        Positioned(
                          bottom: 12 * scale,
                          right: 20 * scale,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Cliente: João da Silva Santos',
                                style: GoogleFonts.inter(
                                  fontSize: 7.5 * scale,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF475569),
                                ),
                              ),
                              Text(
                                'Geração: 990 kWh/mês (8.61 kWp)',
                                style: GoogleFonts.inter(
                                  fontSize: 7.5 * scale,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                        ),
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
                                child: Image.memory(
                                  base64Decode(_current.companyLogoBase64!),
                                  width: (_current.coverLogoWidth * scale).clamp(40.0, 250.0),
                                  fit: BoxFit.contain,
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
                              final newLeft = ((iconItem.x * canvasW) + dx) / canvasW;
                              final newTop = ((iconItem.y * canvasH) + dy) / canvasH;
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
                    ],
                  ),
                ),
              );
            },
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
                          color: Color(_current.verticalSplitAccentColorValue),
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
                SizedBox(height: 8 * scale),
                Container(
                  width: 40 * scale,
                  height: 3.5 * scale,
                  decoration: BoxDecoration(
                    color: Color(_current.verticalSplitAccentColorValue),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(height: 8 * scale),
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
        label: '📌 Proposta Solar',
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
              width: clampedW,
              height: 24,
              margin: const EdgeInsets.only(bottom: 2),
              child: Row(
                children: [
                  Container(
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
                        Text(
                          label,
                          style: GoogleFonts.inter(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
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
          Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (_) {
              _selectAndFocusElement(elementKey);
            },
            onPointerMove: (event) {
              onDrag(event.delta.dx, event.delta.dy);
            },
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
                              child: Listener(
                                behavior: HitTestBehavior.opaque,
                                onPointerDown: (_) {
                                  _selectAndFocusElement(elementKey);
                                },
                                onPointerMove: (event) {
                                  onResizeWidth(event.delta.dx);
                                },
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
  // PAINEL LATERAL DE CONTROLES E TEXTOS EM TEMPO REAL
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
              Tab(icon: Icon(Icons.image_outlined, size: 18), text: 'Logo & Papel de Parede'),
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
                _buildLogoAndWallpaperTab(),
              ],
            ),
          ),
        ],
      ),
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
                    hint: 'SOLAR',
                  ),
                ),
              ],
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
    final dividers = SolarSettingsService.getAvailableDividers();

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

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.1,
            ),
            itemCount: dividers.length,
            itemBuilder: (context, idx) {
              final div = dividers[idx];
              final divId = div['id'] as int;
              final isSelected = _current.customDividerStyle == divId;

              return InkWell(
                onTap: () => setState(() {
                  _current = _current.copyWith(
                    customDividerStyle: divId,
                    isCustomCoverMode: true,
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
                          child: CustomPaint(
                            painter: SolarCoverDividerPainter(
                              dividerType: divId,
                              primaryColor: Color(_hexToInt(_current.customDividerColor)),
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
                                    '#${divId + 1}',
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

  Widget _buildLogoAndWallpaperTab() {
    final backgrounds = SolarSettingsModel.availableWebBackgrounds;

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

          _panelSectionTitle('Foto Solar de Fundo (34 Modelos HD)', 'Troque a foto do lado esquerdo com 1 clique'),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.4,
            ),
            itemCount: backgrounds.length,
            itemBuilder: (ctx, idx) {
              final bg = backgrounds[idx];
              final isSel = _current.webBackgroundTemplate == bg;

              return InkWell(
                onTap: () => setState(() => _current = _current.copyWith(webBackgroundTemplate: bg)),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSel ? const Color(0xFFEAB308) : const Color(0xFF334155),
                      width: isSel ? 2.5 : 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(isSel ? 5.5 : 7),
                    child: Image.network(
                      SolarSettingsService.getWebBackgroundUrl(bg),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFF0F172A),
                        child: Center(child: Text('#${idx + 1}', style: const TextStyle(color: Colors.white70, fontSize: 10))),
                      ),
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
