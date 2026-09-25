import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:mavis/auth/data/repositories/auth_repository.dart';
import 'package:mavis/products/domain/models/automation_study_model.dart';
import 'package:mavis/products/domain/models/product_model.dart';
import 'package:mavis/products/presentation/widgets/automation_proposal_customizer_dialog.dart';
import 'package:mavis/products/presentation/widgets/automation_preview_bridge.dart';
import 'package:mavis/products/presentation/widgets/glb_model_viewer_widget.dart';
import 'package:mavis/settings/data/services/automation_settings_service.dart';

/// Visualização interativa cinematográfica da Proposta Web de Automação Residencial
/// Reprodução fiel da imagem de referência de alto padrão:
/// - Fundo fotográfico de residência em alpha (sem grid de quadrados)
/// - Casa integrada ao cenário (sem container fechado)
/// - Anel interativo com "Arraste para explorar" e link "VISTA PANORÂMICA 3D"
/// - Coluna esquerda com título customizável "Residência Família Klaus", slogan e selos
/// - Coluna direita com lista vertical de cômodos empilhados e card do cômodo com thumbnail e checklist
class AutomationWebProposalView extends StatefulWidget {
  final ProductModel studyProduct;
  final AutomationProposalThemeConfig? initialThemeConfig;
  final VoidCallback? onBackToEditor;

  const AutomationWebProposalView({
    super.key,
    required this.studyProduct,
    this.initialThemeConfig,
    this.onBackToEditor,
  });

  @override
  State<AutomationWebProposalView> createState() => _AutomationWebProposalViewState();
}

class _AutomationWebProposalViewState extends State<AutomationWebProposalView> {
  late AutomationProposalThemeConfig _themeConfig;
  late List<AutomationEnvironment> _environments;
  int _selectedEnvIndex = 0;
  bool _showFloatingRoomDock = false;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _investmentSectionKey = GlobalKey();

  // Rotação da Maquete 3D / Simulação Interativa de Órbita
  double _houseRotationAngle = 0.0;
  bool _show3dInHero = true;

  // Parâmetros Reativos de Órbita & Zoom 3D da Maquete
  late double _glbOrbitTheta;
  late double _glbOrbitPhi;
  late double _glbScale;
  late bool _glbAutoRotate;

  final _currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _themeConfig = widget.initialThemeConfig ??
        AutomationProposalThemeConfig.fromMap(
          widget.studyProduct.specificAttributes['proposalTheme'] as Map<String, dynamic>?,
        );

    _glbOrbitTheta = _themeConfig.glbOrbitTheta;
    _glbOrbitPhi = _themeConfig.glbOrbitPhi;
    _glbScale = _themeConfig.glbScale;
    _glbAutoRotate = _themeConfig.glbAutoRotate;
    _loadCompanySettings();

    // Se o tema não tiver glbModelUrl válido mas houver um modelo ativo no bridge:
    if (!_themeConfig.hasValidGlb &&
        AutomationPreviewBridge.latestGlbDataUrl != null &&
        AutomationPreviewBridge.latestGlbDataUrl!.isNotEmpty &&
        !AutomationPreviewBridge.latestGlbDataUrl!.startsWith('indexeddb:')) {
      _themeConfig = _themeConfig.copyWith(
        glbModelUrl: AutomationPreviewBridge.latestGlbDataUrl,
        glbFileName: AutomationPreviewBridge.latestGlbFileName,
        hasGlbModel: true,
      );
    }

    final rawGlb = _themeConfig.glbModelUrl?.trim();
    final effectiveGlb = (rawGlb != null && rawGlb.isNotEmpty && !rawGlb.startsWith('indexeddb:'))
        ? rawGlb
        : (AutomationPreviewBridge.latestGlbDataUrl ?? '');
    if (effectiveGlb.isNotEmpty || _themeConfig.hasValidGlb) {
      _show3dInHero = true;
    }

    _environments = widget.studyProduct.automationEnvironments;
    if (_environments.isEmpty) {
      _environments = [
        AutomationEnvironment(
          id: 'env_sala',
          name: 'Sala de Estar',
          description: 'Conforto, automação de iluminação dimerizada e entretenimento multimídia imersivo.',
          items: [
            AutomationItem(
              id: 'it1',
              name: 'Módulo Dimmer 6 Circuitos Zigbee 3.0',
              category: AutomationItemCategory.lighting,
              quantity: 6,
              unitPrice: 380.0,
            ),
            AutomationItem(
              id: 'it2',
              name: 'Motor Tubular Silencioso para Cortina',
              category: AutomationItemCategory.curtains,
              quantity: 2,
              unitPrice: 950.0,
            ),
            AutomationItem(
              id: 'it3',
              name: 'Interface de Climatização Integrada Wi-Fi',
              category: AutomationItemCategory.climate,
              quantity: 1,
              unitPrice: 1200.0,
            ),
            AutomationItem(
              id: 'it4',
              name: 'Receiver 7.2 4K Dolby Atmos & Caixas de Teto',
              category: AutomationItemCategory.audioVideo,
              quantity: 1,
              unitPrice: 6800.0,
            ),
          ],
        ),
        AutomationEnvironment(
          id: 'env_suite',
          name: 'Suíte Master',
          description: 'Bem-estar, climatização precisa e controle de persianas com privacidade total.',
          items: [
            AutomationItem(
              id: 'it5',
              name: 'Keypad Inteligente 4 Teclas Gravadas',
              category: AutomationItemCategory.lighting,
              quantity: 2,
              unitPrice: 650.0,
            ),
          ],
        ),
        AutomationEnvironment(
          id: 'env_gourmet',
          name: 'Área Gourmet',
          description: 'Conexões especiais, som ambiente e iluminação funcional para alta gastronomia.',
          items: [
            AutomationItem(
              id: 'it6',
              name: 'Amplificador Multiroom Streaming Hi-Fi',
              category: AutomationItemCategory.audioVideo,
              quantity: 1,
              unitPrice: 4200.0,
            ),
          ],
        ),
        AutomationEnvironment(
          id: 'env_piscina',
          name: 'Piscina & Lazer',
          description: 'Lazer, tranquilidade e cenários luminosos de destaque para a área externa.',
          items: [
            AutomationItem(
              id: 'it7',
              name: 'Controlador RGBW Subaquático e Cascata',
              category: AutomationItemCategory.sensors,
              quantity: 1,
              unitPrice: 2800.0,
            ),
          ],
        ),
      ];
    }
  }

  Future<void> _loadCompanySettings() async {
    try {
      final user = await AuthRepository().getCurrentUser();
      final companyId = user?.companyId ?? '';
      final settings = await AutomationSettingsService().fetchSettings(companyId);
      if (mounted) {
        setState(() {
          _themeConfig = _themeConfig.copyWith(
            backgroundImageUrl: settings.coverImageUrl,
            titlePrefix: settings.coverTitle,
            titleHighlight: settings.coverSubtitle,
            tagline: settings.coverSubheadline,
          );
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!mounted || _environments.isEmpty) return;

    final firstKey = _getRoomKey(_environments.first.id);
    final lastKey = _getRoomKey(_environments.last.id);

    final firstCtx = firstKey.currentContext;
    final lastCtx = lastKey.currentContext;

    bool isVisible = false;

    if (firstCtx != null && lastCtx != null) {
      final firstRenderBox = firstCtx.findRenderObject() as RenderBox?;
      final lastRenderBox = lastCtx.findRenderObject() as RenderBox?;

      if (firstRenderBox != null && firstRenderBox.hasSize &&
          lastRenderBox != null && lastRenderBox.hasSize) {
        final screenHeight = MediaQuery.of(context).size.height;
        final firstTop = firstRenderBox.localToGlobal(Offset.zero).dy;
        final lastBottom = lastRenderBox.localToGlobal(Offset.zero).dy + lastRenderBox.size.height;

        // O menu flutuante permanece visível enquanto o usuário navega pela lista de cômodos,
        // ocultando-se apenas quando sobe ao topo (Hero/Header) ou desce ao final (Investimento/Footer).
        isVisible = firstTop < (screenHeight * 0.85) && lastBottom > 120;
      }
    } else {
      // Fallback baseado no scroll offset caso os elementos ainda estejam sendo montados
      final offset = _scrollController.offset;
      final maxExtent = _scrollController.position.hasContentDimensions
          ? _scrollController.position.maxScrollExtent
          : 3000.0;
      isVisible = offset > 450 && offset < (maxExtent - 550);
    }

    if (isVisible != _showFloatingRoomDock) {
      setState(() {
        _showFloatingRoomDock = isVisible;
      });
    }

    // Atualiza o cômodo ativo destacado no dock à medida que a página é rolada
    if (isVisible) {
      int closestIndex = _selectedEnvIndex;
      double minDistance = double.infinity;
      final screenCenter = MediaQuery.of(context).size.height * 0.35;

      for (int i = 0; i < _environments.length; i++) {
        final envKey = _getRoomKey(_environments[i].id);
        final ctx = envKey.currentContext;
        if (ctx != null) {
          final box = ctx.findRenderObject() as RenderBox?;
          if (box != null && box.hasSize) {
            final top = box.localToGlobal(Offset.zero).dy;
            final dist = (top - screenCenter).abs();
            if (dist < minDistance) {
              minDistance = dist;
              closestIndex = i;
            }
          }
        }
      }

      if (closestIndex != _selectedEnvIndex) {
        setState(() {
          _selectedEnvIndex = closestIndex;
        });
      }
    }
  }

  void _scrollToSection(GlobalKey key, {double alignment = 0.05}) {
    final context = key.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
        alignment: alignment,
      );
    }
  }

  final Map<String, GlobalKey> _roomKeys = {};

  GlobalKey _getRoomKey(String envId) {
    return _roomKeys.putIfAbsent(envId, () => GlobalKey());
  }

  void _selectEnvironment(int idx, {bool scrollToPanel = true}) {
    if (idx < 0 || idx >= _environments.length) return;
    setState(() => _selectedEnvIndex = idx);
    if (scrollToPanel && idx < _environments.length) {
      final envId = _environments[idx].id;
      final targetKey = _getRoomKey(envId);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSection(targetKey, alignment: 0.02);
      });
    }
  }

  void _openCustomizer() {
    showDialog(
      context: context,
      builder: (ctx) => AutomationProposalCustomizerDialog(
        initialConfig: _themeConfig,
        clientName: widget.studyProduct.name,
        onLiveChange: (liveConfig) {
          setState(() {
            _themeConfig = liveConfig;
            _glbOrbitTheta = liveConfig.glbOrbitTheta;
            _glbOrbitPhi = liveConfig.glbOrbitPhi;
            _glbScale = liveConfig.glbScale;
            _glbAutoRotate = liveConfig.glbAutoRotate;
            final rawGlb = liveConfig.glbModelUrl?.trim();
            final effectiveGlb = (rawGlb != null && rawGlb.isNotEmpty && !rawGlb.startsWith('indexeddb:'))
                ? rawGlb
                : (AutomationPreviewBridge.latestGlbDataUrl ?? '');
            if (effectiveGlb.isNotEmpty || liveConfig.hasValidGlb) {
              _show3dInHero = true;
            }
          });
        },
        onSave: (newConfig) {
          setState(() {
            _themeConfig = newConfig;
            _glbOrbitTheta = newConfig.glbOrbitTheta;
            _glbOrbitPhi = newConfig.glbOrbitPhi;
            _glbScale = newConfig.glbScale;
            _glbAutoRotate = newConfig.glbAutoRotate;
            final rawGlb = newConfig.glbModelUrl?.trim();
            final effectiveGlb = (rawGlb != null && rawGlb.isNotEmpty && !rawGlb.startsWith('indexeddb:'))
                ? rawGlb
                : (AutomationPreviewBridge.latestGlbDataUrl ?? '');
            if (effectiveGlb.isNotEmpty || newConfig.hasValidGlb) {
              _show3dInHero = true;
            }
          });
        },
      ),
    );
  }

  void _save3DViewPosition() {
    final liveOrbit = GlbModelViewerWidget.getCurrentCameraOrbit();
    if (liveOrbit != null) {
      _glbOrbitTheta = liveOrbit['theta'] ?? _glbOrbitTheta;
      _glbOrbitPhi = liveOrbit['phi'] ?? _glbOrbitPhi;
    }

    final updatedConfig = _themeConfig.copyWith(
      glbOrbitTheta: _glbOrbitTheta,
      glbOrbitPhi: _glbOrbitPhi,
      glbScale: _glbScale,
      glbAutoRotate: _glbAutoRotate,
    );

    setState(() {
      _themeConfig = updatedConfig;
    });

    widget.studyProduct.specificAttributes['proposalTheme'] = updatedConfig.toMap();
    AutomationPreviewBridge.savePreviewData(widget.studyProduct);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Posição 3D Salva na Proposta!',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                  ),
                  Text(
                    'Ângulo: ${_glbOrbitTheta.round()}° • Inclinação: ${_glbOrbitPhi.round()}° • Zoom: ${(_glbScale * 100).round()}% • Auto-rotação: ${_glbAutoRotate ? "Ativada" : "Desativada"}',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.9)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _open3DPanoramicModal() {
    final primaryColor = _themeConfig.primaryColor;
    final rawGlb = _themeConfig.glbModelUrl?.trim();
    final effectiveGlb = (rawGlb != null && rawGlb.isNotEmpty && !rawGlb.startsWith('indexeddb:'))
        ? rawGlb
        : (AutomationPreviewBridge.latestGlbDataUrl ?? '');
    final hasGlb = effectiveGlb.isNotEmpty || _themeConfig.hasValidGlb;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Container(
              width: 1040,
              height: 720,
              decoration: BoxDecoration(
                color: const Color(0xFF070B14),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: primaryColor.withValues(alpha: 0.5), width: 1.5),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.95), blurRadius: 40),
                  BoxShadow(color: primaryColor.withValues(alpha: 0.25), blurRadius: 30),
                ],
              ),
              child: Column(
                children: [
                  // Top Bar do Modal 3D
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.view_in_ar_rounded, color: primaryColor, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'VISTA PANORÂMICA 3D • ENGINE THREE.JS / WEBGL',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.8,
                              ),
                            ),
                            Text(
                              _themeConfig.glbFileName != null
                                  ? 'Modelo 3D Ativo: ${_themeConfig.glbFileName!} • Órbita 360°, rotação e zoom livres'
                                  : (hasGlb
                                      ? 'Modelo 3D GLB Ativo • Órbita 360°, rotação e zoom livres'
                                      : 'Exibindo render da residência • Envie seu arquivo .GLB para interagir em tempo real'),
                              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _openCustomizer();
                          },
                          icon: const Icon(Icons.upload_file_rounded, size: 16),
                          label: Text(
                            hasGlb ? 'Trocar GLB / Foto' : 'Enviar Arquivo .GLB',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E293B),
                            foregroundColor: primaryColor,
                            side: BorderSide(color: primaryColor.withValues(alpha: 0.3)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: _save3DViewPosition,
                          icon: const Icon(Icons.save_rounded, size: 16),
                          label: Text(
                            'Salvar Posição 3D',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(Icons.close_rounded, color: Colors.white),
                        ),
                      ],
                    ),
                  ),

                  // Área Interativa de Visualização 3D Real (WebGL)
                  Expanded(
                    child: Container(
                      color: const Color(0xFF070B14),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Background sutil
                          Positioned.fill(
                            child: Opacity(
                              opacity: 0.15,
                              child: _buildBackgroundImage(),
                            ),
                          ),

                          // Renderizador 3D Real com Three.js / <model-viewer>
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: GlbModelViewerWidget(
                                glbUrl: effectiveGlb,
                                fallbackImageUrl: _themeConfig.heroImageUrl,
                                autoRotate: _glbAutoRotate,
                                accentColor: primaryColor,
                                glbScale: _glbScale,
                                glbOrbitTheta: _glbOrbitTheta,
                                glbOrbitPhi: _glbOrbitPhi,
                                onCameraChange: (theta, phi) {
                                  setModalState(() {
                                    _glbOrbitTheta = theta;
                                    _glbOrbitPhi = phi;
                                  });
                                  setState(() {});
                                },
                              ),
                            ),
                          ),

                          // Overlay com Instruções e Indicador de Órbita
                          Positioned(
                            bottom: 20,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: primaryColor.withValues(alpha: 0.4)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.threed_rotation_rounded, color: primaryColor, size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      hasGlb
                                          ? 'Arraste com o botão esquerdo para orbitar • Roda do mouse para aproximar/afastar'
                                          : 'Clique em "Enviar Arquivo .GLB" para ver a maquete 3D volumétrica interativa',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
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
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showApprovalDialog() {
    final primaryColor = _themeConfig.primaryColor;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: primaryColor.withValues(alpha: 0.5), width: 1.5),
        ),
        child: Container(
          width: 480,
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: primaryColor.withValues(alpha: 0.4)),
                ),
                child: Icon(Icons.verified_rounded, color: primaryColor, size: 40),
              ),
              const SizedBox(height: 18),
              Text(
                'Aprovar Estudo de Automação',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Ao aprovar, este projeto será encaminhado para a engenharia para vistoria técnica e emissão do contrato oficial.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8), height: 1.5),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Investimento Total:', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8))),
                    Text(
                      _currencyFormat.format(widget.studyProduct.salePrice),
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF94A3B8),
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text('Fechar', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: Color(0xFF10B981),
                            content: Text('🎉 Proposta aprovada com sucesso no sistema!'),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text('Confirmar Aprovação', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = _themeConfig.primaryColor;
    final activeEnv = _environments.isNotEmpty && _selectedEnvIndex < _environments.length
        ? _environments[_selectedEnvIndex]
        : null;

    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── FUNDO FOTOGRÁFICO DE RESIDÊNCIA EM ALPHA (SEM GRID DE QUADRADOS) ──
          Positioned.fill(
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildBackgroundImage(),
                // Gradiente de vinheta e atmosfera escura
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF070B14).withValues(alpha: 0.88),
                        const Color(0xFF070B14).withValues(alpha: 0.65),
                        const Color(0xFF070B14).withValues(alpha: 0.95),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── CONTEÚDO PRINCIPAL ROLÁVEL ──
          SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Header Fiel à Referência
                _buildTopHeader(primaryColor),

                // 2. Seção Hero Imersiva (Coluna Esquerda, Casa Central e Coluna Direita)
                _buildHeroStageSection(primaryColor, activeEnv),

                const SizedBox(height: 32),

                // 3. TODOS OS AMBIENTES / CÔMODOS EMPILHADOS UM ABAIXO DO OUTRO NA PÁGINA
                if (_environments.isNotEmpty) ...[
                  ..._environments.asMap().entries.map((entry) {
                    final env = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 32),
                      child: _buildExpandedActiveRoomPanel(primaryColor, env),
                    );
                  }),
                ],

                const SizedBox(height: 60),

                // 4. Resumo do Investimento Global & CTA
                _buildInvestmentSummarySection(primaryColor),

                const SizedBox(height: 80),

                // Rodapé
                _buildFooter(primaryColor),
              ],
            ),
          ),

          // Menu Flutuante Dock de Cômodos no Rodapé (surge dinamicamente ao visualizar o conteúdo)
          Positioned(
            bottom: 24,
            left: 20,
            right: MediaQuery.of(context).size.width > 1080 ? 340 : 20,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: _buildFloatingRoomDock(primaryColor),
            ),
          ),

          // Barra Flutuante de Ferramentas no Canto Inferior Direito
          Positioned(
            bottom: MediaQuery.of(context).size.width > 1080 ? 24 : 96,
            right: 28,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'floating_customizer',
                  onPressed: _openCustomizer,
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: primaryColor,
                  elevation: 8,
                  icon: const Icon(Icons.palette_rounded, size: 19),
                  label: Text(
                    'Personalizar Foto / Background / 3D',
                    style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold),
                  ),
                ),
                if (widget.onBackToEditor != null) ...[
                  const SizedBox(width: 12),
                  FloatingActionButton.extended(
                    heroTag: 'floating_back',
                    onPressed: widget.onBackToEditor,
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.black,
                    elevation: 8,
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    label: Text(
                      'Voltar ao Editor',
                      style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // WIDGET DO FUNDO (BACKGROUND)
  // ---------------------------------------------------------------------------
  Widget _buildBackgroundImage() {
    final url = _themeConfig.backgroundImageUrl;
    final alpha = _themeConfig.backgroundAlpha;

    Widget imageWidget;
    if (url.startsWith('data:')) {
      final comma = url.indexOf(',');
      final bytes = base64Decode(comma != -1 ? url.substring(comma + 1) : url);
      imageWidget = Image.memory(bytes, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _fallbackBg());
    } else if (url.startsWith('assets/')) {
      imageWidget = Image.asset(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _fallbackBg());
    } else {
      imageWidget = Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _fallbackBg());
    }

    return Opacity(
      opacity: alpha,
      child: imageWidget,
    );
  }

  Widget _fallbackBg() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF070B14)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. TOP HEADER (IDENTICO À IMAGEM 2)
  // ---------------------------------------------------------------------------
  Widget _buildTopHeader(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
      child: Row(
        children: [
          // Logo [T] TAOS CRM
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: primaryColor, width: 1.5),
                  boxShadow: [
                    BoxShadow(color: primaryColor.withValues(alpha: 0.35), blurRadius: 10),
                  ],
                ),
                child: Center(
                  child: Text(
                    'T',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: primaryColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'TAOS CRM',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),

          const Spacer(),

          // Botão Personalizar Proposta
          OutlinedButton.icon(
            onPressed: _openCustomizer,
            icon: Icon(Icons.tune_rounded, size: 16, color: primaryColor),
            label: Text('Personalizar Proposta', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: primaryColor.withValues(alpha: 0.6)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(width: 14),

          // Botão Aprovar Proposta
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor, const Color(0xFF0284C7)],
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(color: primaryColor.withValues(alpha: 0.4), blurRadius: 14, offset: const Offset(0, 2)),
              ],
            ),
            child: ElevatedButton(
              onPressed: _showApprovalDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Aprovar proposta',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }



  // ---------------------------------------------------------------------------
  // 2. HERO STAGE: 3 COLUNAS INTEGRADAS (ESQUERDA, CASA CENTRAL E DIREITA)
  // ---------------------------------------------------------------------------
  Widget _buildHeroStageSection(Color primaryColor, AutomationEnvironment? activeEnv) {
    return Container(
      padding: const EdgeInsets.fromLTRB(48, 20, 48, 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 1050;
          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Coluna Esquerda: Eyebrow, Título com Destaque Neon, Subtítulo e 4 Selos
                SizedBox(
                  width: 330,
                  child: _buildLeftHeroColumn(primaryColor),
                ),

                const SizedBox(width: 16),

                // Centro: A Casa 3D Integrada sem Box + Anel "Arraste para explorar" + Link Vista Panorâmica
                Expanded(
                  child: _buildCenterIntegratedHouseStage(primaryColor, activeEnv),
                ),

                const SizedBox(width: 16),

                // Coluna Direita: Frase de Destaque, Lista Vertical de Cômodos e Card do Cômodo
                SizedBox(
                  width: 350,
                  child: _buildRightHeroColumn(primaryColor, activeEnv),
                ),
              ],
            );
          } else {
            return Column(
              children: [
                _buildLeftHeroColumn(primaryColor),
                const SizedBox(height: 24),
                _buildCenterIntegratedHouseStage(primaryColor, activeEnv),
                const SizedBox(height: 24),
                _buildRightHeroColumn(primaryColor, activeEnv),
              ],
            );
          }
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // COLUNA ESQUERDA: TIPOGRAFIA & SELOS
  // ---------------------------------------------------------------------------
  Widget _buildLeftHeroColumn(Color primaryColor) {
    final prefix = _themeConfig.titlePrefix.isNotEmpty ? _themeConfig.titlePrefix : 'Residência';
    final highlight = _themeConfig.titleHighlight.isNotEmpty ? _themeConfig.titleHighlight : 'Família Klaus';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Eyebrow Decorativo com Linha
        Row(
          children: [
            Container(width: 24, height: 2, color: const Color(0xFFF59E0B)),
            const SizedBox(width: 8),
            Text(
              'PROPOSTA DE AUTOMAÇÃO RESIDENCIAL',
              style: GoogleFonts.inter(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                color: primaryColor,
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // TÍTULO CUSTOMIZÁVEL COM GRADIENTE CIANO NEON
        Text(
          prefix,
          style: GoogleFonts.outfit(
            fontSize: 38,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            height: 1.05,
          ),
        ),
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [primaryColor, const Color(0xFF38BDF8), Colors.white],
          ).createShader(bounds),
          child: Text(
            highlight,
            style: GoogleFonts.outfit(
              fontSize: 38,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.1,
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Slogan
        Text(
          _themeConfig.tagline,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),

        const SizedBox(height: 8),

        // Descrição
        Text(
          _themeConfig.description,
          style: GoogleFonts.inter(
            fontSize: 12.5,
            color: const Color(0xFF94A3B8),
            height: 1.5,
          ),
        ),

        const SizedBox(height: 28),

        // 4 Selos Verticais com Ícones Traçados
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildBenefitItem(Icons.home_outlined, _themeConfig.highlights.isNotEmpty ? _themeConfig.highlights[0] : 'Mais conforto', primaryColor),
            _buildBenefitItem(Icons.shield_outlined, _themeConfig.highlights.length > 1 ? _themeConfig.highlights[1] : 'Mais segurança', primaryColor),
            _buildBenefitItem(Icons.eco_outlined, _themeConfig.highlights.length > 2 ? _themeConfig.highlights[2] : 'Mais eficiência', primaryColor),
            _buildBenefitItem(Icons.favorite_outline_rounded, _themeConfig.highlights.length > 3 ? _themeConfig.highlights[3] : 'Mais momentos', primaryColor),
          ],
        ),

        const SizedBox(height: 36),

        // Rodapé da Coluna
        Text(
          _themeConfig.footerTagline,
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.8,
            color: const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildBenefitItem(IconData icon, String label, Color primaryColor) {
    return Column(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
          ),
          child: Icon(icon, color: primaryColor, size: 20),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 65,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: const Color(0xFFCBD5E1),
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // CENTRO: CASA 3D INTEGRADA COM ANEL E PIN LUMINOSO
  // ---------------------------------------------------------------------------
  Widget _buildCenterIntegratedHouseStage(Color primaryColor, AutomationEnvironment? activeEnv) {
    final rawGlb = _themeConfig.glbModelUrl?.trim();
    final effectiveGlb = (rawGlb != null && rawGlb.isNotEmpty && !rawGlb.startsWith('indexeddb:'))
        ? rawGlb
        : (AutomationPreviewBridge.latestGlbDataUrl ?? '');
    final hasGlb = effectiveGlb.isNotEmpty || _themeConfig.hasValidGlb;

    return Stack(
      alignment: Alignment.center,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Seletor de Modo (quando houver GLB disponível)
            if (hasGlb) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 10),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildStageModePill(
                      icon: Icons.image_outlined,
                      label: 'Render Fachada',
                      isActive: !_show3dInHero,
                      primaryColor: primaryColor,
                      onTap: () => setState(() => _show3dInHero = false),
                    ),
                    const SizedBox(width: 4),
                    _buildStageModePill(
                      icon: Icons.view_in_ar_rounded,
                      label: 'Maquete 3D Interativa',
                      isActive: _show3dInHero,
                      primaryColor: primaryColor,
                      onTap: () => setState(() => _show3dInHero = true),
                    ),
                  ],
                ),
              ),
            ],

            // Imagem 3D da Casa Integrada ou Model-Viewer WebGL
            if (hasGlb && _show3dInHero) ...[
              SizedBox(
                height: 450,
                width: double.infinity,
                child: GlbModelViewerWidget(
                  glbUrl: effectiveGlb,
                  fallbackImageUrl: _themeConfig.heroImageUrl,
                  autoRotate: _glbAutoRotate,
                  accentColor: primaryColor,
                  glbScale: _glbScale,
                  glbOrbitTheta: _glbOrbitTheta,
                  glbOrbitPhi: _glbOrbitPhi,
                  onCameraChange: (theta, phi) {
                    setState(() {
                      _glbOrbitTheta = theta;
                      _glbOrbitPhi = phi;
                    });
                  },
                ),
              ),
            ] else
              GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    _houseRotationAngle += details.delta.dx * 0.005;
                  });
                },
                child: Transform(
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateY(_houseRotationAngle),
                  alignment: Alignment.center,
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 460),
                    child: _buildHouseImageWidget(fit: BoxFit.contain),
                  ),
                ),
              ),

            const SizedBox(height: 8),

            // Anel Gráfico com Setas e Texto "Arraste para explorar" + Link VISTA PANORÂMICA 3D
            InkWell(
              onTap: _open3DPanoramicModal,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: primaryColor.withValues(alpha: 0.35)),
                  boxShadow: [
                    BoxShadow(color: primaryColor.withValues(alpha: 0.15), blurRadius: 10),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.threed_rotation_rounded, color: primaryColor, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'VISTA PANORÂMICA 3D',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      hasGlb ? '• Órbita & Zoom WebGL' : '• Arraste para explorar',
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.fullscreen_rounded, size: 16, color: Color(0xFF94A3B8)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStageModePill({
    required IconData icon,
    required String label,
    required bool isActive,
    required Color primaryColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? primaryColor.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? primaryColor : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isActive ? primaryColor : const Color(0xFF94A3B8)),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive ? Colors.white : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHouseImageWidget({BoxFit fit = BoxFit.cover, double? height}) {
    final url = _themeConfig.heroImageUrl;
    if (url.startsWith('data:')) {
      final comma = url.indexOf(',');
      final bytes = base64Decode(comma != -1 ? url.substring(comma + 1) : url);
      return Image.memory(bytes, fit: fit, height: height, errorBuilder: (_, __, ___) => _fallbackHouse());
    } else if (url.startsWith('assets/')) {
      return Image.asset(url, fit: fit, height: height, errorBuilder: (_, __, ___) => _fallbackHouse());
    } else {
      return Image.network(url, fit: fit, height: height, errorBuilder: (_, __, ___) => _fallbackHouse());
    }
  }

  Widget _fallbackHouse() {
    return Center(
      child: Icon(Icons.home_work_rounded, size: 80, color: _themeConfig.primaryColor),
    );
  }

  // ---------------------------------------------------------------------------
  // COLUNA DIREITA: LISTA VERTICAL DE CÔMODOS & CARD DO AMBIENTE
  // ---------------------------------------------------------------------------
  Widget _buildRightHeroColumn(Color primaryColor, AutomationEnvironment? activeEnv) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Frase Superior da Coluna
        Text(
          'CASAS MAIS INTELIGENTES\nPESSOAS MAIS LIVRES',
          textAlign: TextAlign.right,
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
            color: const Color(0xFF64748B),
            height: 1.3,
          ),
        ),

        const SizedBox(height: 14),

        // Lista Vertical de Cômodos Empilhados com Ícone e Seta >
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _environments.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, idx) {
            final env = _environments[idx];
            final isSelected = idx == _selectedEnvIndex;

            return InkWell(
              onTap: () => _selectEnvironment(idx, scrollToPanel: true),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF0F172A).withValues(alpha: 0.95)
                      : const Color(0xFF0F172A).withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? primaryColor : Colors.white.withValues(alpha: 0.12),
                    width: isSelected ? 1.8 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: primaryColor.withValues(alpha: 0.25),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ]
                        : null,
                ),
                child: Row(
                  children: [
                    Icon(
                      env.icon,
                      color: isSelected ? primaryColor : const Color(0xFF94A3B8),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        env.name,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: isSelected ? primaryColor : const Color(0xFF64748B),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }



  String _getRoomInteriorPhoto(String roomName) {
    final lower = roomName.toLowerCase();
    if (lower.contains('quarto') || lower.contains('suite') || lower.contains('suíte')) {
      return 'https://images.unsplash.com/photo-1595526114035-0d45ed16cfbf?auto=format&fit=crop&w=400&q=80';
    }
    if (lower.contains('cozinha') || lower.contains('gourmet') || lower.contains('jantar')) {
      return 'https://images.unsplash.com/photo-1600585152220-90363fe7e115?auto=format&fit=crop&w=400&q=80';
    }
    if (lower.contains('piscina') || lower.contains('jardim') || lower.contains('lazer') || lower.contains('varanda')) {
      return 'https://images.unsplash.com/photo-1576013551627-0cc20b96c2a7?auto=format&fit=crop&w=400&q=80';
    }
    if (lower.contains('cinema') || lower.contains('theater')) {
      return 'https://images.unsplash.com/photo-1593784991095-a205069470b6?auto=format&fit=crop&w=400&q=80';
    }
    // Padrão: Living room
    return 'https://images.unsplash.com/photo-1600210492486-724fe5c67fb0?auto=format&fit=crop&w=400&q=80';
  }

  IconData _getRoomIcon(String roomName) {
    final lower = roomName.toLowerCase();
    if (lower.contains('banheiro') || lower.contains('lavabo') || lower.contains('bwc')) {
      return Icons.bathtub_rounded;
    }
    if (lower.contains('suíte') || lower.contains('suite') || lower.contains('quarto') || lower.contains('dormitório')) {
      return Icons.bed_rounded;
    }
    if (lower.contains('gourmet') || lower.contains('churrasqu')) {
      return Icons.outdoor_grill_rounded;
    }
    if (lower.contains('cozinha') || lower.contains('jantar') || lower.contains('copa')) {
      return Icons.kitchen_rounded;
    }
    if (lower.contains('piscina')) {
      return Icons.pool_rounded;
    }
    if (lower.contains('lazer') || lower.contains('varanda') || lower.contains('deck') || lower.contains('sacada')) {
      return Icons.deck_rounded;
    }
    if (lower.contains('cinema') || lower.contains('theater') || lower.contains('som') || lower.contains('áudio') || lower.contains('tv')) {
      return Icons.tv_rounded;
    }
    if (lower.contains('escritório') || lower.contains('office')) {
      return Icons.desk_rounded;
    }
    if (lower.contains('garagem') || lower.contains('abrigo')) {
      return Icons.directions_car_rounded;
    }
    return Icons.weekend_rounded;
  }

  // ---------------------------------------------------------------------------
  // NOVO: PAINEL EXPANDIDO RETANGULAR DO AMBIENTE SELECIONADO
  // Unifica o card de destaque do cômodo com o detalhamento completo de equipamentos
  // ocupando o espaço horizontal nobre da tela
  // ---------------------------------------------------------------------------
  Widget _buildExpandedActiveRoomPanel(Color primaryColor, AutomationEnvironment env) {
    final roomPhotoUrl = (env.imageUrl != null && env.imageUrl!.trim().isNotEmpty)
        ? env.imageUrl!.trim()
        : _getRoomInteriorPhoto(env.name);
    final totalStudyValue = widget.studyProduct.salePrice > 0 ? widget.studyProduct.salePrice : 1.0;
    final envPercentage = (env.subtotal / totalStudyValue * 100).clamp(0.0, 100.0);

    return Container(
      key: _getRoomKey(env.id),
      margin: const EdgeInsets.symmetric(horizontal: 48),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: primaryColor.withValues(alpha: 0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.7),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.12),
            blurRadius: 36,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── BARRA SUPERIOR DO PAINEL DO CÔMODO ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B).withValues(alpha: 0.65),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
            ),
            child: Row(
              children: [
                // Ícone do Ambiente em Container Destaque
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                  ),
                  child: Icon(env.icon, color: primaryColor, size: 26),
                ),
                const SizedBox(width: 16),

                // Título e Descrição do Cômodo
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            env.name,
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: primaryColor.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              '${env.totalItemsCount} ${env.totalItemsCount == 1 ? 'dispositivo' : 'dispositivos'}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        env.miniexplanation,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 24),

                // Subtotal do Cômodo
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'SUBTOTAL DO AMBIENTE',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    Text(
                      _currencyFormat.format(env.subtotal),
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: primaryColor,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── CORPO: DUAS COLUNAS (RESUMO & FOTO DO CÔMODO + EQUIPAMENTOS INSTALADOS) ──
          Padding(
            padding: const EdgeInsets.all(28),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 880;

                final leftSummary = Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B132B).withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Foto do Cômodo com Overlay Elegante
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Stack(
                          children: [
                            Container(
                              height: 190,
                              width: double.infinity,
                              color: Colors.black45,
                              child: Image.network(
                                roomPhotoUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Center(
                                  child: Icon(Icons.meeting_room_rounded, color: Colors.white24, size: 48),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 12,
                              left: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.75),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: primaryColor.withValues(alpha: 0.4)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.photo_camera_rounded, size: 12, color: primaryColor),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Cenário Integrado',
                                      style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),
                      const Divider(color: Color(0xFF1E293B), height: 1),
                      const SizedBox(height: 14),

                      // Card de representatividade no investimento
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B).withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.pie_chart_outline_rounded, size: 20, color: primaryColor),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Representatividade no Projeto',
                                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                                  ),
                                  Text(
                                    '${envPercentage.toStringAsFixed(1)}% do valor total da proposta',
                                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );

                final rightEquipmentList = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.inventory_2_outlined, color: primaryColor, size: 20),
                            const SizedBox(width: 10),
                            Text(
                              'EQUIPAMENTOS ADOTADOS (${env.items.length})',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Hardware & Módulos Oficiais',
                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    if (env.items.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B).withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.devices_other_rounded, size: 40, color: primaryColor.withValues(alpha: 0.6)),
                              const SizedBox(height: 12),
                              Text(
                                'Nenhum equipamento específico listado para este ambiente.',
                                style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: env.items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = env.items[index];
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B).withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: item.category.color.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(item.category.icon, color: item.category.color, size: 20),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: item.category.color.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              item.categoryTitle,
                                              style: GoogleFonts.inter(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: item.category.color,
                                              ),
                                            ),
                                          ),
                                          if (item.manufacturer != null && item.manufacturer!.isNotEmpty) ...[
                                            const SizedBox(width: 8),
                                            Text(
                                              'Marca: ${item.manufacturer}',
                                              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F172A),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                                  ),
                                  child: Text(
                                    '${item.quantity} ${item.unit}',
                                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      _currencyFormat.format(item.calculatedTotal),
                                      style: GoogleFonts.outfit(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: primaryColor,
                                      ),
                                    ),
                                    Text(
                                      '${_currencyFormat.format(item.unitPrice)} un.',
                                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                );

                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 360, child: leftSummary),
                      const SizedBox(width: 24),
                      Expanded(child: rightEquipmentList),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      leftSummary,
                      const SizedBox(height: 20),
                      rightEquipmentList,
                    ],
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // MENU FLUTUANTE DE NAVEGAÇÃO DE CÔMODOS (DOCK NO RODAPÉ)
  // Aparece dinamicamente apenas quando o usuário está visualizando as especificações
  // do cômodo, permitindo alternar rapidamente sem precisar rolar para o topo
  // ---------------------------------------------------------------------------
  Widget _buildFloatingRoomDock(Color primaryColor) {
    final screenWidth = MediaQuery.of(context).size.width;
    final maxDockWidth = (screenWidth - 380).clamp(240.0, 780.0);

    return AnimatedSlide(
      offset: _showFloatingRoomDock ? Offset.zero : const Offset(0, 1.4),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _showFloatingRoomDock ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 260),
        child: IgnorePointer(
          ignoring: !_showFloatingRoomDock,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: primaryColor.withValues(alpha: 0.45),
                width: 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.7),
                  blurRadius: 28,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.22),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: primaryColor.withValues(alpha: 0.35)),
                  ),
                  child: Icon(Icons.apps_rounded, color: primaryColor, size: 16),
                ),
                const SizedBox(width: 8),
                Text(
                  'CÔMODOS',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(width: 10),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxDockWidth),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(_environments.length, (idx) {
                        final env = _environments[idx];
                        final isSelected = idx == _selectedEnvIndex;
                        final roomIcon = _getRoomIcon(env.name);

                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: InkWell(
                            onTap: () => _selectEnvironment(idx, scrollToPanel: true),
                            borderRadius: BorderRadius.circular(10),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: 66,
                              height: 60,
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? primaryColor.withValues(alpha: 0.2)
                                    : const Color(0xFF1E293B).withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected ? primaryColor : Colors.white.withValues(alpha: 0.1),
                                  width: isSelected ? 2 : 1,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: primaryColor.withValues(alpha: 0.4),
                                          blurRadius: 10,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    roomIcon,
                                    size: 18,
                                    color: isSelected ? primaryColor : const Color(0xFF94A3B8),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    env.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(
                                      fontSize: 9.5,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 5. RESUMO DO INVESTIMENTO
  // ---------------------------------------------------------------------------
  Widget _buildInvestmentSummarySection(Color primaryColor) {
    final totalPrice = widget.studyProduct.salePrice;
    final totalDispositivos = _environments.fold(0, (acc, env) => acc + env.totalItemsCount);

    return Container(
      key: _investmentSectionKey,
      margin: const EdgeInsets.symmetric(horizontal: 48),
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: primaryColor.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(color: primaryColor.withValues(alpha: 0.12), blurRadius: 32, spreadRadius: 2),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: primaryColor.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: Icon(Icons.account_balance_wallet_rounded, color: primaryColor, size: 28),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Resumo do Investimento & Engenharia', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                  Text('Solução completa incluindo equipamentos, programação, integração e suporte.', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8))),
                ],
              ),
            ],
          ),

          const SizedBox(height: 32),

          Row(
            children: [
              Expanded(child: _buildSummaryKpiCard('Ambientes Planejados', '${_environments.length} cômodos', Icons.room_preferences_rounded, primaryColor)),
              const SizedBox(width: 16),
              Expanded(child: _buildSummaryKpiCard('Total de Dispositivos', '$totalDispositivos unidades', Icons.devices_other_rounded, primaryColor)),
              const SizedBox(width: 16),
              Expanded(child: _buildSummaryKpiCard('Investimento Global', _currencyFormat.format(totalPrice), Icons.verified_rounded, primaryColor, isHighlight: true)),
            ],
          ),

          const SizedBox(height: 32),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pronto para transformar sua residência?', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      Text('Condições exclusivas de parcelamento e garantia estendida de integração.', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8))),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _showApprovalDialog,
                  icon: const Icon(Icons.check_circle_rounded, size: 20),
                  label: Text('APROVAR PROPOSTA AGORA', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                    elevation: 8,
                    shadowColor: primaryColor.withValues(alpha: 0.6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryKpiCard(String title, String value, IconData icon, Color primaryColor, {bool isHighlight = false}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isHighlight ? primaryColor.withValues(alpha: 0.12) : const Color(0xFF0F172A).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isHighlight ? primaryColor : Colors.white.withValues(alpha: 0.08), width: isHighlight ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: primaryColor, size: 22),
          const SizedBox(height: 12),
          Text(title, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8))),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: isHighlight ? primaryColor : Colors.white)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // RODAPÉ
  // ---------------------------------------------------------------------------
  Widget _buildFooter(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 48),
      decoration: BoxDecoration(
        color: const Color(0xFF070B14),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '© ${DateTime.now().year} TAOS CRM • Proposta Web Interativa gerada com Inteligência Artificial',
            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
          ),
          Text(
            'Tecnologia de Automação & Engenharia Residencial',
            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}
