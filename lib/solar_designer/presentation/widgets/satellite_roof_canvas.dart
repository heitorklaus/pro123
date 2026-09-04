import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_fonts/google_fonts.dart';
import '../../data/services/roof_geometry_service.dart';
import '../../data/services/satellite_map_service.dart';
import '../../domain/models/solar_designer_models.dart';
import '../../domain/services/brazil_solar_irradiation_service.dart';
import 'solar_panel_texture_data.dart';

/// Modos de interação do usuário no Canvas
enum DesignerToolMode {
  select, // Selecionar Setas, Módulos, Conjuntos e Objetos
  pan, // Navegar / Mover Satélite ou Imagem
  drawRoof, // Desenhar ou Ajustar Vértices do Telhado
  editModules, // Módulos, Adicionar, Mover Arranjo e Obstáculos
}

/// Canvas Interativo de Telhado, Imagem de Satélite e Foto de Drone
class SatelliteRoofCanvas extends StatefulWidget {
  final double latitude;
  final double longitude;
  final double zoom;
  final double panOffsetX;
  final double panOffsetY;
  final List<RoofPoint> roofVertices;
  final bool isRoofClosed;
  final List<PlacedModule> modules;
  final List<RoofSection> sections;
  final int activeSectionIndex;
  final bool isEditingActiveSection;
  final DesignerToolMode toolMode;
  final SatelliteSource satelliteSource;
  final BackgroundLayerMode backgroundMode;
  final Uint8List? droneImageBytes;
  final bool isAnalyzingDrone;
  final ValueChanged<Offset>? onCanvasTap;
  final ValueChanged<Offset>? onCanvasDoubleTap;
  final Function(Offset delta)? onPanUpdate;
  final ValueChanged<Offset>? onZoomIn;
  final ValueChanged<Offset>? onZoomOut;
  final ValueChanged<int>? onEdgeTap;
  final Function(int vertexIndex, RoofPoint newPointMeters)? onVertexMoved;
  final Function(double dxMeters, double dyMeters)? onModuleGroupMoved;
  final Function(double dxMeters, double dyMeters)?
      onDrawingMoved; // move polígono + módulos juntos
  final Function(String rowId, double dxMeters, double dyMeters)? onRowMoved;
  final Function(int index, double dxMeters, double dyMeters)? onModuleMoved;
  final ValueChanged<int>? onModuleDragEnd;
  final int? snappedModuleIndex;
  final Function(double deltaRadians)? onRotateModuleGroup;
  final Function(int index, double deltaRadians)? onRotateSingleModule;
  final Function(int index)? onRotateSingleModule90;
  final Function(int index)? onDeleteSingleModule;
  final VoidCallback? onRotate90;
  final VoidCallback? onOpenAngleDialog;
  final VoidCallback? onAddModule;
  final Function(int targetIndex, String position)? onAddModuleRelative;
  final VoidCallback? onRemoveModule;
  final VoidCallback? onAddRow;
  final ValueChanged<String>? onDeleteRow;
  final ValueChanged<int>? onSectionSelected;
  final ValueChanged<int>? onDeleteSection;
  final VoidCallback? onFinishCurrentSection;
  final VoidCallback? onResumeEditing;
  final VoidCallback? onAddNewSection;
  final Function(String direction)? onDuplicateCurrentSection;
  final VoidCallback? onConcludeCluster;
  final String? activeClusterId;
  final bool isClusterFinalized;
  final double groupRotationDegrees;
  final double metersPerPixel;
  final int selectedModuleIndex;
  final ValueChanged<int>? onSelectModule;
  final DroneNorthCompass? droneNorthCompass;
  final List<DroneRoofArrow> droneArrows;
  final String? selectedDroneArrowId;
  final bool snapAlignmentEnabled;
  final ValueChanged<DroneNorthCompass>? onUpdateDroneCompass;
  final ValueChanged<DroneRoofArrow>? onUpdateDroneArrow;
  final ValueChanged<String?>? onSelectDroneArrow;
  final ValueChanged<String>? onDeleteDroneArrow;
  final bool isRenderMode;
  final Map<String, SolarOrientationEfficiency> sectionEfficiencies;
  final SolarOrientationEfficiency? activeSectionEfficiency;

  const SatelliteRoofCanvas({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.zoom,
    required this.panOffsetX,
    required this.panOffsetY,
    required this.roofVertices,
    required this.isRoofClosed,
    required this.modules,
    this.sections = const [],
    this.activeSectionIndex = 0,
    this.isEditingActiveSection = true,
    required this.toolMode,
    this.satelliteSource = SatelliteSource.googleHybrid,
    this.backgroundMode = BackgroundLayerMode.satellite,
    this.droneImageBytes,
    this.isAnalyzingDrone = false,
    this.onCanvasTap,
    this.onCanvasDoubleTap,
    this.onPanUpdate,
    this.onZoomIn,
    this.onZoomOut,
    this.onEdgeTap,
    this.onVertexMoved,
    this.onModuleGroupMoved,
    this.onDrawingMoved,
    this.onRowMoved,
    this.onModuleMoved,
    this.onModuleDragEnd,
    this.snappedModuleIndex,
    this.onRotateModuleGroup,
    this.onRotateSingleModule,
    this.onRotateSingleModule90,
    this.onDeleteSingleModule,
    this.onRotate90,
    this.onOpenAngleDialog,
    this.onAddModule,
    this.onAddModuleRelative,
    this.onRemoveModule,
    this.onAddRow,
    this.onDeleteRow,
    this.onSectionSelected,
    this.onDeleteSection,
    this.onFinishCurrentSection,
    this.onResumeEditing,
    this.onAddNewSection,
    this.onDuplicateCurrentSection,
    this.onConcludeCluster,
    this.activeClusterId,
    this.isClusterFinalized = false,
    this.groupRotationDegrees = 0.0,
    required this.metersPerPixel,
    this.selectedModuleIndex = -1,
    this.onSelectModule,
    this.droneNorthCompass,
    this.droneArrows = const [],
    this.selectedDroneArrowId,
    this.snapAlignmentEnabled = true,
    this.onUpdateDroneCompass,
    this.onUpdateDroneArrow,
    this.onSelectDroneArrow,
    this.onDeleteDroneArrow,
    this.isRenderMode = false,
    this.sectionEfficiencies = const {},
    this.activeSectionEfficiency,
  });

  @override
  State<SatelliteRoofCanvas> createState() => _SatelliteRoofCanvasState();
}

class _SatelliteRoofCanvasState extends State<SatelliteRoofCanvas> {
  int _draggingVertexIndex = -1;
  int _hoveredVertexIndex = -1;
  int _draggingModuleIndex = -1;
  int _selectedModuleIndex = -1;
  String? _selectedRowId;
  bool _isDraggingRow = false;
  bool _isDraggingModuleGroup = false;
  String _moveMode =
      'modules'; // 'modules' (apenas placas) ou 'both' (polígono + placas)
  bool _isMoveEnabled = false; // Ativação obrigatória via diálogo
  bool _showMoveTip = false; // Balão de dica flutuante temporizado
  String _moveTipText = ''; // Texto contextual da opção selecionada
  Timer? _tipTimer;
  bool _isRotatingGroup = false;
  Offset? _rotationPivotScreen;
  double _lastDragAngle = 0.0;
  bool _isPanning = false;
  bool _isHoveringModule = false;
  Offset? _panStartScreenPos;
  double _panTotalDistance = 0.0;
  DateTime _lastProcessedTap = DateTime.fromMillisecondsSinceEpoch(0);

  // Estados de Manipulação de Orientação e Quedas do Drone
  String? _selectedDroneArrowId;
  String? _draggingDroneArrowId;
  String? _rotatingDroneArrowId;
  bool _isDraggingNorthCompass = false;
  bool _isRotatingNorthCompass = false;
  Offset? _snapGuideStart;
  Offset? _snapGuideEnd;

  // Hover e arraste de alta precisão 1:1
  bool _isHoveringDroneCompass = false;
  bool _isHoveringDroneArrow = false;
  bool _isHoveringDroneRotationHandle = false;
  RoofPoint? _dragStartCompassCenter;
  Offset? _dragStartCompassScreenPos;
  RoofPoint? _dragStartArrowCenter;
  Offset? _dragStartArrowScreenPos;

  // Textura fotorrealista do módulo solar fotovoltaico
  ui.Image? _solarPanelImage;

  @override
  void initState() {
    super.initState();
    _selectedModuleIndex = widget.selectedModuleIndex;
    _selectedDroneArrowId = widget.selectedDroneArrowId;
    _loadSolarPanelTexture();
  }

  Future<void> _loadSolarPanelTexture() async {
    try {
      final codec =
          await ui.instantiateImageCodec(SolarPanelTextureData.bytes);
      final frame = await codec.getNextFrame();
      if (mounted) {
        setState(() {
          _solarPanelImage = frame.image;
        });
        return;
      }
    } catch (_) {}

    try {
      final byteData =
          await rootBundle.load('assets/images/solar_panel_module.webp');
      final bytes = byteData.buffer.asUint8List();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (mounted) {
        setState(() {
          _solarPanelImage = frame.image;
        });
      }
    } catch (_) {}
  }

  @override
  void didUpdateWidget(covariant SatelliteRoofCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Se alternou entre Satélite e Drone, limpa estados de arraste e seleções residuais
    if (widget.backgroundMode != oldWidget.backgroundMode) {
      setState(() {
        _selectedModuleIndex = -1;
        _selectedRowId = null;
        _draggingVertexIndex = -1;
        _hoveredVertexIndex = -1;
        _draggingModuleIndex = -1;
        _isDraggingRow = false;
        _isDraggingModuleGroup = false;
        _isRotatingGroup = false;
        _isPanning = false;
        _panStartScreenPos = null;
        _panTotalDistance = 0.0;
        _draggingDroneArrowId = null;
        _rotatingDroneArrowId = null;
        _isDraggingNorthCompass = false;
        _isRotatingNorthCompass = false;
        _snapGuideStart = null;
        _snapGuideEnd = null;
        _dragStartCompassCenter = null;
        _dragStartCompassScreenPos = null;
        _dragStartArrowCenter = null;
        _dragStartArrowScreenPos = null;
      });
    }

    // Sincroniza a seleção vinda do pai (ex: nova placa adicionada)
    if (widget.selectedModuleIndex != oldWidget.selectedModuleIndex) {
      setState(() {
        _selectedModuleIndex = widget.selectedModuleIndex;
        if (_selectedModuleIndex != -1) {
          _selectedRowId = null;
        }
      });
    }

    if (widget.selectedDroneArrowId != oldWidget.selectedDroneArrowId) {
      setState(() {
        _selectedDroneArrowId = widget.selectedDroneArrowId;
      });
    }
  }

  @override
  void dispose() {
    _tipTimer?.cancel();
    super.dispose();
  }

  double _normalizeAngle(double a) {
    return ((a % (2 * math.pi)) + (2 * math.pi)) % (2 * math.pi);
  }

  double _angleDiff(double a, double b) {
    final diff = (_normalizeAngle(a) - _normalizeAngle(b)).abs();
    return diff > math.pi ? (2 * math.pi - diff) : diff;
  }

  DroneRoofArrow? _findHitDroneArrowRotationHandle(
      Offset localPos, Offset centerOffset) {
    // A alça de rotação só é visível e manipulável para a seta que estiver selecionada!
    final activeId = _selectedDroneArrowId ?? widget.selectedDroneArrowId;
    if (activeId == null) return null;

    final selectedArrow =
        widget.droneArrows.where((a) => a.id == activeId).firstOrNull;
    if (selectedArrow == null) return null;

    final centerPx = Offset(
      centerOffset.dx +
          RoofGeometryService.metersToPixels(
              selectedArrow.center.x, widget.metersPerPixel),
      centerOffset.dy +
          RoofGeometryService.metersToPixels(
              selectedArrow.center.y, widget.metersPerPixel),
    );
    final lenPx = RoofGeometryService.metersToPixels(
            selectedArrow.lengthMeters, widget.metersPerPixel)
        .clamp(26.0, 75.0);
    final dir = Offset(math.cos(selectedArrow.rotationRadians),
        math.sin(selectedArrow.rotationRadians));
    final tipPos = centerPx + dir * (lenPx * 0.50);
    final rotHandlePos = tipPos + dir * 14.0;

    if ((localPos - rotHandlePos).distance <= 20.0) {
      return selectedArrow;
    }
    return null;
  }

  DroneRoofArrow? _findHitDroneArrowBody(Offset localPos, Offset centerOffset) {
    for (final arrow in widget.droneArrows.reversed) {
      final centerPx = Offset(
        centerOffset.dx +
            RoofGeometryService.metersToPixels(
                arrow.center.x, widget.metersPerPixel),
        centerOffset.dy +
            RoofGeometryService.metersToPixels(
                arrow.center.y, widget.metersPerPixel),
      );
      final lenPx = RoofGeometryService.metersToPixels(
              arrow.lengthMeters, widget.metersPerPixel)
          .clamp(26.0, 75.0);
      final widthPx = lenPx * 0.88;
      final dir = Offset(
          math.cos(arrow.rotationRadians), math.sin(arrow.rotationRadians));
      final tipPos = centerPx + dir * (lenPx * 0.50);

      if ((localPos - centerPx).distance <= (widthPx * 0.70) ||
          (localPos - tipPos).distance <= 22.0) {
        return arrow;
      }
    }
    return null;
  }

  bool _isHitDroneCompassRotationHandle(Offset localPos, Offset centerOffset) {
    if (widget.droneNorthCompass == null) return false;
    final compass = widget.droneNorthCompass!;
    final centerPx = Offset(
      centerOffset.dx +
          RoofGeometryService.metersToPixels(
              compass.center.x, widget.metersPerPixel),
      centerOffset.dy +
          RoofGeometryService.metersToPixels(
              compass.center.y, widget.metersPerPixel),
    );
    final radius = RoofGeometryService.metersToPixels(
            compass.sizeMeters / 2, widget.metersPerPixel)
        .clamp(26.0, 65.0);
    final dir = Offset(
        math.sin(compass.rotationRadians), -math.cos(compass.rotationRadians));
    final rotHandle = centerPx + dir * (radius + 16.0);
    return (localPos - rotHandle).distance <= 20.0;
  }

  bool _isHitDroneCompassBody(Offset localPos, Offset centerOffset) {
    if (widget.droneNorthCompass == null) return false;
    final compass = widget.droneNorthCompass!;
    final centerPx = Offset(
      centerOffset.dx +
          RoofGeometryService.metersToPixels(
              compass.center.x, widget.metersPerPixel),
      centerOffset.dy +
          RoofGeometryService.metersToPixels(
              compass.center.y, widget.metersPerPixel),
    );
    final radius = RoofGeometryService.metersToPixels(
            compass.sizeMeters / 2, widget.metersPerPixel)
        .clamp(26.0, 65.0);
    return (localPos - centerPx).distance <= radius;
  }

  RoofPolygon? _findPolygonForArrow(DroneRoofArrow arrow) {
    // 1. Se a seta tiver sectionId, tenta encontrar a seção correspondente
    if (arrow.sectionId != null) {
      if (widget.activeSectionIndex >= 0 &&
          widget.activeSectionIndex < widget.sections.length &&
          widget.sections[widget.activeSectionIndex].id == arrow.sectionId) {
        if (widget.roofVertices.length >= 3) {
          return RoofPolygon(vertices: widget.roofVertices);
        }
      }
      for (final sec in widget.sections) {
        if (sec.id == arrow.sectionId && sec.vertices.length >= 3) {
          return RoofPolygon(vertices: sec.vertices);
        }
      }
    }

    // 2. Se o centro da seta está dentro da seção ativa
    if (widget.roofVertices.length >= 3 && widget.isRoofClosed) {
      final activePoly = RoofPolygon(vertices: widget.roofVertices);
      if (activePoly.containsPoint(arrow.center)) {
        return activePoly;
      }
    }

    // 3. Se está dentro de alguma outra seção
    for (final sec in widget.sections) {
      if (sec.vertices.length >= 3) {
        final secPoly = RoofPolygon(vertices: sec.vertices);
        if (secPoly.containsPoint(arrow.center)) {
          return secPoly;
        }
      }
    }

    // 4. Fallback: Se houver qualquer polígono fechado disponível
    if (widget.roofVertices.length >= 3 && widget.isRoofClosed) {
      return RoofPolygon(vertices: widget.roofVertices);
    }
    for (final sec in widget.sections) {
      if (sec.vertices.length >= 3) {
        return RoofPolygon(vertices: sec.vertices);
      }
    }

    return null;
  }

  RoofPoint _clampPointInsidePolygon(
      RoofPolygon poly, RoofPoint currentPt, RoofPoint targetPt) {
    if (poly.containsPoint(targetPt)) {
      return targetPt;
    }

    RoofPoint pInside =
        poly.containsPoint(currentPt) ? currentPt : poly.centroid;
    RoofPoint pOutside = targetPt;

    for (int step = 0; step < 6; step++) {
      final mid = RoofPoint(
        (pInside.x + pOutside.x) / 2.0,
        (pInside.y + pOutside.y) / 2.0,
      );
      if (poly.containsPoint(mid)) {
        pInside = mid;
      } else {
        pOutside = mid;
      }
    }
    return pInside;
  }

  DroneRoofArrow _applyArrowDragSnap(
      DroneRoofArrow arrow, RoofPoint newCenter) {
    // Garante que o ponto está confinado dentro do polígono daquela orientação
    RoofPoint constrained = newCenter;
    final poly = _findPolygonForArrow(arrow);
    if (poly != null && poly.vertices.length >= 3) {
      constrained = _clampPointInsidePolygon(poly, arrow.center, constrained);
    }

    if (!widget.snapAlignmentEnabled || widget.droneArrows.length <= 1) {
      _snapGuideStart = null;
      _snapGuideEnd = null;
      return arrow.copyWith(center: constrained);
    }
    // Snap elástico suave (~9 pixels): guia o alinhamento sem prender o movimento lateral
    final snapDistMeters =
        RoofGeometryService.pixelsToMeters(9.0, widget.metersPerPixel);
    RoofPoint snapped = constrained;
    Offset? gStart;
    Offset? gEnd;

    for (final other in widget.droneArrows) {
      if (other.id == arrow.id) continue;
      // Snap vertical (mesmo eixo X)
      if ((constrained.x - other.center.x).abs() < snapDistMeters) {
        final candidate = RoofPoint(other.center.x, snapped.y);
        if (poly == null || poly.containsPoint(candidate)) {
          snapped = candidate;
          gStart = other.center.toOffset();
          gEnd = snapped.toOffset();
        }
      }
      // Snap horizontal (mesmo eixo Y)
      if ((constrained.y - other.center.y).abs() < snapDistMeters) {
        final candidate = RoofPoint(snapped.x, other.center.y);
        if (poly == null || poly.containsPoint(candidate)) {
          snapped = candidate;
          gStart = other.center.toOffset();
          gEnd = snapped.toOffset();
        }
      }
    }
    _snapGuideStart = gStart;
    _snapGuideEnd = gEnd;
    return arrow.copyWith(center: snapped);
  }

  double _applyArrowRotationSnap(double rawAngle, String arrowId) {
    if (!widget.snapAlignmentEnabled) return rawAngle;
    final norm = _normalizeAngle(rawAngle);
    const double snapTol = 0.14; // ~8 graus

    // Snap relativo a outras setas existentes (oposta 180°, perpendicular 90°, paralela 0°)
    for (final other in widget.droneArrows) {
      if (other.id == arrowId) continue;
      final oRot = _normalizeAngle(other.rotationRadians);

      // Oposta (180°) - telhados de 2 ou 4 quedas (Leste vs Oeste)
      final opp = _normalizeAngle(oRot + math.pi);
      if (_angleDiff(norm, opp) < snapTol) return opp;

      // Perpendicular +90°
      final perp1 = _normalizeAngle(oRot + math.pi / 2);
      if (_angleDiff(norm, perp1) < snapTol) return perp1;

      // Perpendicular -90°
      final perp2 = _normalizeAngle(oRot - math.pi / 2);
      if (_angleDiff(norm, perp2) < snapTol) return perp2;

      // Paralela
      if (_angleDiff(norm, oRot) < snapTol) return oRot;
    }

    // Snap em cardeais e semi-cardeais fixos (0°, 45°, 90°, 135°, 180°, 225°, 270°, 315°)
    const fixedAngles = [
      0.0,
      math.pi / 4,
      math.pi / 2,
      3 * math.pi / 4,
      math.pi,
      5 * math.pi / 4,
      3 * math.pi / 2,
      7 * math.pi / 4,
    ];
    for (final fa in fixedAngles) {
      if (_angleDiff(norm, fa) < 0.087) {
        return fa;
      }
    }

    return norm;
  }

  double _applyNorthCompassRotationSnap(double rawAngle) {
    final norm = _normalizeAngle(rawAngle);
    const cardAngles = [
      0.0,
      math.pi / 4,
      math.pi / 2,
      3 * math.pi / 4,
      math.pi,
      5 * math.pi / 4,
      3 * math.pi / 2,
      7 * math.pi / 4,
    ];
    for (final ca in cardAngles) {
      if (_angleDiff(norm, ca) < 0.087) {
        return ca;
      }
    }
    return norm;
  }

  /// Retorna o cursor contextual correspondente à ferramenta ativa
  MouseCursor _getCanvasCursor() {
    if (widget.isAnalyzingDrone &&
        widget.backgroundMode == BackgroundLayerMode.dronePhoto) {
      return SystemMouseCursors.wait;
    }

    // 1. Se estiver arrastando um vértice (bolinha do telhado)
    if (_draggingVertexIndex != -1) {
      return SystemMouseCursors.grabbing;
    }

    // 2. Se o mouse estiver sobre qualquer bolinha de vértice, vira o ponteiro do mouse!
    if (_hoveredVertexIndex != -1) {
      return SystemMouseCursors.click;
    }

    // 3. Se estiver arrastando Norte ou Seta do drone
    if (_isDraggingNorthCompass || _draggingDroneArrowId != null) {
      return SystemMouseCursors.grabbing;
    }
    if (_isRotatingNorthCompass || _rotatingDroneArrowId != null) {
      return SystemMouseCursors.grabbing;
    }

    // 4. Se o mouse estiver sobre o Norte ou uma Seta de Queda: VIRA A MÃOZINHA!
    if (_isHoveringDroneCompass || _isHoveringDroneArrow) {
      return SystemMouseCursors.click;
    }
    if (_isHoveringDroneRotationHandle) {
      return SystemMouseCursors.grab;
    }

    // 5. Se estiver arrastando módulo, linha ou conjunto
    if (_isPanning ||
        _draggingModuleIndex != -1 ||
        _isDraggingRow ||
        _isDraggingModuleGroup ||
        _isRotatingGroup) {
      return SystemMouseCursors.grabbing;
    }

    // 6. Se o mouse estiver sobre qualquer placa solar, vira a mãozinha
    if (_isHoveringModule) {
      return SystemMouseCursors.click;
    }

    if (widget.toolMode == DesignerToolMode.select) {
      return SystemMouseCursors.basic;
    }

    if (widget.toolMode == DesignerToolMode.pan ||
        widget.toolMode == DesignerToolMode.editModules) {
      return SystemMouseCursors.grab;
    }

    // 7. Fora da placa solar e do vértice no modo desenhar, vira a cruz cirúrgica (+)
    return SystemMouseCursors.precise;
  }

  /// Retorna se a posição da tela está sobre qualquer placa (ativa ou de outras seções)
  bool _isPointOverAnyModule(Offset localPos, Offset centerOffset) {
    if (widget.modules.isEmpty && widget.sections.isEmpty) return false;

    // 1. Placas da seção ativa
    for (int i = widget.modules.length - 1; i >= 0; i--) {
      final m = widget.modules[i];
      if (m.isExcluded) continue;
      final corners = m.getCorners();
      final screenPts = corners
          .map((p) => Offset(
                centerOffset.dx +
                    RoofGeometryService.metersToPixels(
                        p.x, widget.metersPerPixel),
                centerOffset.dy +
                    RoofGeometryService.metersToPixels(
                        p.y, widget.metersPerPixel),
              ))
          .toList();

      final path = Path()..addPolygon(screenPts, true);
      if (path.contains(localPos)) {
        return true;
      }
    }

    // 2. Placas das outras seções
    for (final sec in widget.sections) {
      for (final m in sec.modules) {
        if (m.isExcluded) continue;
        final corners = m.getCorners();
        final screenPts = corners
            .map((p) => Offset(
                  centerOffset.dx +
                      RoofGeometryService.metersToPixels(
                          p.x, widget.metersPerPixel),
                  centerOffset.dy +
                      RoofGeometryService.metersToPixels(
                          p.y, widget.metersPerPixel),
                ))
            .toList();

        final path = Path()..addPolygon(screenPts, true);
        if (path.contains(localPos)) {
          return true;
        }
      }
    }

    return false;
  }

  void _handleCanvasHover(Offset localPos, Offset centerOffset) {
    // 1. Anotações do Drone: Testa se está sobre o Norte ou Setas de Queda
    bool isOverCompass = false;
    bool isOverArrow = false;
    bool isOverRotHandle = false;

    if (widget.droneNorthCompass != null) {
      if (_isHitDroneCompassRotationHandle(localPos, centerOffset)) {
        isOverRotHandle = true;
      } else if (_isHitDroneCompassBody(localPos, centerOffset)) {
        isOverCompass = true;
      }
    }

    if (!isOverCompass && !isOverRotHandle && widget.droneArrows.isNotEmpty) {
      if (_findHitDroneArrowRotationHandle(localPos, centerOffset) != null) {
        isOverRotHandle = true;
      } else if (_findHitDroneArrowBody(localPos, centerOffset) != null) {
        isOverArrow = true;
      }
    }

    // 2. Testa se o mouse está sobre alguma bolinha de vértice do telhado (bolinhas das arestas)
    int foundHoveredVertex = -1;
    if (widget.roofVertices.isNotEmpty) {
      for (int i = 0; i < widget.roofVertices.length; i++) {
        final p = widget.roofVertices[i];
        final pxX = RoofGeometryService.metersToPixels(p.x, widget.metersPerPixel);
        final pxY = RoofGeometryService.metersToPixels(p.y, widget.metersPerPixel);
        final screenPos = Offset(centerOffset.dx + pxX, centerOffset.dy + pxY);

        if ((localPos - screenPos).distance <= 24.0) {
          foundHoveredVertex = i;
          break;
        }
      }
    }

    // 3. Verifica se o mouse está sobre uma placa solar (ativo no modo select)
    bool isOverModule = false;
    if (foundHoveredVertex == -1 &&
        !isOverCompass &&
        !isOverArrow &&
        !isOverRotHandle &&
        widget.toolMode != DesignerToolMode.pan) {
      isOverModule = _isPointOverAnyModule(localPos, centerOffset);
    }

    if (foundHoveredVertex != _hoveredVertexIndex ||
        isOverModule != _isHoveringModule ||
        isOverCompass != _isHoveringDroneCompass ||
        isOverArrow != _isHoveringDroneArrow ||
        isOverRotHandle != _isHoveringDroneRotationHandle) {
      setState(() {
        _hoveredVertexIndex = foundHoveredVertex;
        _isHoveringModule = isOverModule;
        _isHoveringDroneCompass = isOverCompass;
        _isHoveringDroneArrow = isOverArrow;
        _isHoveringDroneRotationHandle = isOverRotHandle;
      });
    }
  }

  /// Calcula a caixa delimitadora (bounding box) do conjunto ativo de placas (ou de todas se não houver divisão)
  Rect? _getModulesBoundingBox(Offset centerOffset) {
    if (widget.modules.isEmpty) return null;

    // Se o conjunto foi concluído e nenhum conjunto está ativo, não exibe controles de grupo
    if (widget.isClusterFinalized && widget.activeClusterId == null) {
      return null;
    }

    // Se houver um conjunto ativo especificado, foca EXCLUSIVAMENTE nele!
    Iterable<PlacedModule> targetModules = widget.modules;
    if (widget.activeClusterId != null) {
      final clusterModules = widget.modules
          .where((m) => m.rowId == widget.activeClusterId && !m.isExcluded)
          .toList();
      if (clusterModules.isNotEmpty) {
        targetModules = clusterModules;
      } else {
        return null;
      }
    }

    double minX = double.infinity, maxX = -double.infinity;
    double minY = double.infinity, maxY = -double.infinity;

    for (final m in targetModules) {
      for (final p in m.getCorners()) {
        final px = centerOffset.dx +
            RoofGeometryService.metersToPixels(p.x, widget.metersPerPixel);
        final py = centerOffset.dy +
            RoofGeometryService.metersToPixels(p.y, widget.metersPerPixel);
        if (px < minX) minX = px;
        if (px > maxX) maxX = px;
        if (py < minY) minY = py;
        if (py > maxY) maxY = py;
      }
    }

    if (minX == double.infinity) return null;
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
        final centerOffset = Offset(
          canvasSize.width / 2.0 + widget.panOffsetX,
          canvasSize.height / 2.0 + widget.panOffsetY,
        );
        final modulesBbox = _getModulesBoundingBox(centerOffset);

        return ClipRect(
          child: Listener(
            onPointerSignal: (pointerSignal) {
              if (pointerSignal is PointerScrollEvent) {
                if (pointerSignal.scrollDelta.dy < 0) {
                  widget.onZoomIn?.call(pointerSignal.localPosition);
                } else if (pointerSignal.scrollDelta.dy > 0) {
                  widget.onZoomOut?.call(pointerSignal.localPosition);
                }
              }
            },
            child: MouseRegion(
              cursor: _getCanvasCursor(),
              onHover: (event) =>
                  _handleCanvasHover(event.localPosition, centerOffset),
              onExit: (_) {
                if (_isHoveringModule || _hoveredVertexIndex != -1) {
                  setState(() {
                    _isHoveringModule = false;
                    _hoveredVertexIndex = -1;
                  });
                }
              },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (details) {
                  _panStartScreenPos = details.localPosition;
                  _panTotalDistance = 0.0;

                  if (widget.isAnalyzingDrone &&
                      widget.backgroundMode == BackgroundLayerMode.dronePhoto) {
                    return;
                  }

                  final localPos = details.localPosition;

                  // ── ANOTAÇÕES DE DRONE (Norte e Setas de Queda) ──
                  if (widget.droneArrows.isNotEmpty ||
                      widget.droneNorthCompass != null) {
                    // 1. Alça de rotação de alguma seta de queda
                    final hitRotArrow = _findHitDroneArrowRotationHandle(
                        localPos, centerOffset);
                    if (hitRotArrow != null) {
                      setState(() {
                        _selectedDroneArrowId = hitRotArrow.id;
                        _rotatingDroneArrowId = hitRotArrow.id;
                        _isPanning = false;
                      });
                      widget.onSelectDroneArrow?.call(hitRotArrow.id);
                      return;
                    }

                    // 2. Alça de rotação do Norte
                    if (_isHitDroneCompassRotationHandle(
                        localPos, centerOffset)) {
                      setState(() {
                        _isRotatingNorthCompass = true;
                        _isPanning = false;
                      });
                      return;
                    }

                    // 3. Corpo / Centro de alguma seta de queda
                    final hitBodyArrow =
                        _findHitDroneArrowBody(localPos, centerOffset);
                    if (hitBodyArrow != null) {
                      setState(() {
                        _selectedDroneArrowId = hitBodyArrow.id;
                        _draggingDroneArrowId = hitBodyArrow.id;
                        _dragStartArrowCenter = hitBodyArrow.center;
                        _dragStartArrowScreenPos = localPos;
                        _isPanning = false;
                      });
                      widget.onSelectDroneArrow?.call(hitBodyArrow.id);
                      return;
                    }

                    // 4. Corpo do Norte
                    if (_isHitDroneCompassBody(localPos, centerOffset)) {
                      setState(() {
                        _isDraggingNorthCompass = true;
                        _dragStartCompassCenter =
                            widget.droneNorthCompass!.center;
                        _dragStartCompassScreenPos = localPos;
                        _isPanning = false;
                      });
                      return;
                    }
                  }

                  // ── PRIORIDADE ABSOLUTA 1: TESTA SE CLICOU NA BOLINHA DE UM VÉRTICE DO TELHADO ──
                  // Funciona em qualquer modo (drone ou satélite, desenhar ou módulos ou navegar)
                  if (widget.roofVertices.isNotEmpty) {
                    for (int i = 0; i < widget.roofVertices.length; i++) {
                      final p = widget.roofVertices[i];
                      final pxX = RoofGeometryService.metersToPixels(
                          p.x, widget.metersPerPixel);
                      final pxY = RoofGeometryService.metersToPixels(
                          p.y, widget.metersPerPixel);
                      final screenPos =
                          Offset(centerOffset.dx + pxX, centerOffset.dy + pxY);

                      if ((localPos - screenPos).distance <= 26.0) {
                        // Se a seção ativa estiver em repouso/concluída, reativa para edição imediata!
                        if (!widget.isEditingActiveSection) {
                          widget.onResumeEditing?.call();
                        }
                        setState(() {
                          _draggingVertexIndex = i;
                          _isPanning = false;
                          _selectedModuleIndex = -1;
                          _selectedRowId = null;
                        });
                        return;
                      }
                    }
                  }

                  if (widget.toolMode == DesignerToolMode.pan ||
                      widget.toolMode == DesignerToolMode.editModules) {
                    setState(() => _isPanning = true);
                  }

                  // Se a seção ativa estiver concluída (em modo repouso), não inicia edição por pan (exceto se em modo desenhar)
                  if (!widget.isEditingActiveSection &&
                      widget.toolMode != DesignerToolMode.drawRoof) {
                    return;
                  }

                  // 2. Se houver módulos na água ativa e clicar sobre eles (apenas se não estiver no modo de desenhar telhado)
                  if (widget.toolMode != DesignerToolMode.drawRoof &&
                      widget.modules.isNotEmpty) {
                    // 2.1 Testa se clicou na alça de rotação de grupo (topo do bbox)
                    if (modulesBbox != null) {
                      final rotHandlePos =
                          Offset(modulesBbox.center.dx, modulesBbox.top - 24);
                      if ((localPos - rotHandlePos).distance <= 24.0) {
                        setState(() {
                          _isRotatingGroup = true;
                          _rotationPivotScreen = modulesBbox.center;
                          _lastDragAngle = math.atan2(
                            localPos.dy - modulesBbox.center.dy,
                            localPos.dx - modulesBbox.center.dx,
                          );
                        });
                        return;
                      }
                    }

                    final dxM = RoofGeometryService.pixelsToMeters(
                        localPos.dx - centerOffset.dx, widget.metersPerPixel);
                    final dyM = RoofGeometryService.pixelsToMeters(
                        localPos.dy - centerOffset.dy, widget.metersPerPixel);
                    final clickPointMeters = RoofPoint(dxM, dyM);

                    // Testa se clicou em um módulo individual
                    for (int i = widget.modules.length - 1; i >= 0; i--) {
                      if (widget.modules[i].containsPoint(clickPointMeters)) {
                        setState(() {
                          _draggingModuleIndex = i;
                          _selectedModuleIndex = i;
                          _isPanning = false;
                        });
                        widget.onSelectModule?.call(i);
                        return;
                      }
                    }

                    // Se houver uma linha inteira selecionada e o usuário arrastar sobre uma de suas placas
                    if (_selectedRowId != null) {
                      final rowMods = widget.modules
                          .where((m) => m.rowId == _selectedRowId);
                      if (rowMods
                          .any((m) => m.containsPoint(clickPointMeters))) {
                        setState(() => _isDraggingRow = true);
                        return;
                      }
                    }

                    // Se houver um módulo selecionado e clicar nele para arrastá-lo
                    if (_selectedModuleIndex != -1 &&
                        _selectedModuleIndex < widget.modules.length) {
                      if (widget.modules[_selectedModuleIndex]
                          .containsPoint(clickPointMeters)) {
                        setState(() {
                          _draggingModuleIndex = _selectedModuleIndex;
                          _isPanning = false;
                        });
                        return;
                      }
                    }

                    // Testa se clicou perto da área do conjunto de módulos para arrastar o conjunto todo (somente se ativo)
                    if (widget.toolMode == DesignerToolMode.editModules &&
                        modulesBbox != null &&
                        _isMoveEnabled) {
                      if (modulesBbox.inflate(16.0).contains(localPos)) {
                        setState(() => _isDraggingModuleGroup = true);
                        return;
                      }
                    }

                    // Se estiver no modo select e clicou em placa de outra água/seção, alterna a seção!
                    if (widget.toolMode == DesignerToolMode.select) {
                      for (int s = 0; s < widget.sections.length; s++) {
                        if (s == widget.activeSectionIndex) continue;
                        final sec = widget.sections[s];
                        for (final m in sec.modules) {
                          if (!m.isExcluded &&
                              m.containsPoint(clickPointMeters)) {
                            widget.onSectionSelected?.call(s);
                            return;
                          }
                        }
                      }
                    }
                  }

                  _draggingVertexIndex = -1;
                  _draggingModuleIndex = -1;
                  _isDraggingRow = false;
                  _isDraggingModuleGroup = false;
                  _isRotatingGroup = false;
                },
                onPanUpdate: (details) {
                  _panTotalDistance += details.delta.distance;

                  // 1. Rotação interativa de seta de queda
                  if (_rotatingDroneArrowId != null) {
                    final arrow = widget.droneArrows.firstWhere(
                      (a) => a.id == _rotatingDroneArrowId,
                      orElse: () => widget.droneArrows.first,
                    );
                    final centerScreen = Offset(
                      centerOffset.dx +
                          RoofGeometryService.metersToPixels(
                              arrow.center.x, widget.metersPerPixel),
                      centerOffset.dy +
                          RoofGeometryService.metersToPixels(
                              arrow.center.y, widget.metersPerPixel),
                    );
                    final rawAngle = math.atan2(
                      details.localPosition.dy - centerScreen.dy,
                      details.localPosition.dx - centerScreen.dx,
                    );
                    final snappedAngle =
                        _applyArrowRotationSnap(rawAngle, arrow.id);
                    widget.onUpdateDroneArrow?.call(
                        arrow.copyWith(rotationRadians: snappedAngle));
                    return;
                  }

                  // 2. Arraste / Translação de seta de queda com Snap magnético (1:1 instantâneo)
                  if (_draggingDroneArrowId != null) {
                    final arrow = widget.droneArrows.firstWhere(
                      (a) => a.id == _draggingDroneArrowId,
                      orElse: () => widget.droneArrows.first,
                    );
                    RoofPoint newCenter;
                    if (_dragStartArrowCenter != null &&
                        _dragStartArrowScreenPos != null) {
                      final totalScreenDx = details.localPosition.dx -
                          _dragStartArrowScreenPos!.dx;
                      final totalScreenDy = details.localPosition.dy -
                          _dragStartArrowScreenPos!.dy;
                      final dxM = RoofGeometryService.pixelsToMeters(
                          totalScreenDx, widget.metersPerPixel);
                      final dyM = RoofGeometryService.pixelsToMeters(
                          totalScreenDy, widget.metersPerPixel);
                      newCenter = RoofPoint(
                        _dragStartArrowCenter!.x + dxM,
                        _dragStartArrowCenter!.y + dyM,
                      );
                    } else {
                      final dxM = RoofGeometryService.pixelsToMeters(
                          details.delta.dx, widget.metersPerPixel);
                      final dyM = RoofGeometryService.pixelsToMeters(
                          details.delta.dy, widget.metersPerPixel);
                      newCenter = arrow.center.translate(dxM, dyM);
                    }
                    final snappedArrow =
                        _applyArrowDragSnap(arrow, newCenter);
                    widget.onUpdateDroneArrow?.call(snappedArrow);
                    return;
                  }

                  // 3. Rotação do Norte do Drone
                  if (_isRotatingNorthCompass &&
                      widget.droneNorthCompass != null) {
                    final compass = widget.droneNorthCompass!;
                    final centerScreen = Offset(
                      centerOffset.dx +
                          RoofGeometryService.metersToPixels(
                              compass.center.x, widget.metersPerPixel),
                      centerOffset.dy +
                          RoofGeometryService.metersToPixels(
                              compass.center.y, widget.metersPerPixel),
                    );
                    final rawAngle = math.atan2(
                          details.localPosition.dy - centerScreen.dy,
                          details.localPosition.dx - centerScreen.dx,
                        ) +
                        math.pi / 2;
                    final snappedAngle =
                        _applyNorthCompassRotationSnap(rawAngle);
                    widget.onUpdateDroneCompass?.call(
                        compass.copyWith(rotationRadians: snappedAngle));
                    return;
                  }

                  // 4. Arraste do Norte do Drone (1:1 instantâneo sem atraso)
                  if (_isDraggingNorthCompass &&
                      widget.droneNorthCompass != null) {
                    final compass = widget.droneNorthCompass!;
                    RoofPoint newCenter;
                    if (_dragStartCompassCenter != null &&
                        _dragStartCompassScreenPos != null) {
                      final totalScreenDx = details.localPosition.dx -
                          _dragStartCompassScreenPos!.dx;
                      final totalScreenDy = details.localPosition.dy -
                          _dragStartCompassScreenPos!.dy;
                      final dxM = RoofGeometryService.pixelsToMeters(
                          totalScreenDx, widget.metersPerPixel);
                      final dyM = RoofGeometryService.pixelsToMeters(
                          totalScreenDy, widget.metersPerPixel);
                      newCenter = RoofPoint(
                        _dragStartCompassCenter!.x + dxM,
                        _dragStartCompassCenter!.y + dyM,
                      );
                    } else {
                      final dxM = RoofGeometryService.pixelsToMeters(
                          details.delta.dx, widget.metersPerPixel);
                      final dyM = RoofGeometryService.pixelsToMeters(
                          details.delta.dy, widget.metersPerPixel);
                      newCenter = compass.center.translate(dxM, dyM);
                    }
                    widget.onUpdateDroneCompass
                        ?.call(compass.copyWith(center: newCenter));
                    return;
                  }

                  if (_isRotatingGroup && _rotationPivotScreen != null) {
                    // Rotaciona conjunto à mão livre
                    final currentAngle = math.atan2(
                      details.localPosition.dy - _rotationPivotScreen!.dy,
                      details.localPosition.dx - _rotationPivotScreen!.dx,
                    );
                    final deltaAngle = currentAngle - _lastDragAngle;
                    _lastDragAngle = currentAngle;
                    widget.onRotateModuleGroup?.call(deltaAngle);
                  } else if (_isDraggingRow && _selectedRowId != null) {
                    // Move todas as placas da fileira selecionada
                    final dxM = RoofGeometryService.pixelsToMeters(
                        details.delta.dx, widget.metersPerPixel);
                    final dyM = RoofGeometryService.pixelsToMeters(
                        details.delta.dy, widget.metersPerPixel);
                    widget.onRowMoved?.call(_selectedRowId!, dxM, dyM);
                  } else if (_draggingVertexIndex != -1 &&
                      _draggingVertexIndex < widget.roofVertices.length) {
                    // Move vértice do telhado da água ativa
                    final dxPixels = details.localPosition.dx - centerOffset.dx;
                    final dyPixels = details.localPosition.dy - centerOffset.dy;
                    final newPoint = RoofPoint(
                      RoofGeometryService.pixelsToMeters(
                          dxPixels, widget.metersPerPixel),
                      RoofGeometryService.pixelsToMeters(
                          dyPixels, widget.metersPerPixel),
                    );
                    widget.onVertexMoved?.call(_draggingVertexIndex, newPoint);
                  } else if (_draggingModuleIndex != -1 &&
                      _draggingModuleIndex < widget.modules.length) {
                    // Move placa individual livremente
                    final dxM = RoofGeometryService.pixelsToMeters(
                        details.delta.dx, widget.metersPerPixel);
                    final dyM = RoofGeometryService.pixelsToMeters(
                        details.delta.dy, widget.metersPerPixel);
                    widget.onModuleMoved?.call(_draggingModuleIndex, dxM, dyM);
                  } else if (_isDraggingModuleGroup) {
                    // Move conjunto todo de módulos (ou com o polígono se modo 'both')
                    final dxM = RoofGeometryService.pixelsToMeters(
                        details.delta.dx, widget.metersPerPixel);
                    final dyM = RoofGeometryService.pixelsToMeters(
                        details.delta.dy, widget.metersPerPixel);
                    if (_moveMode == 'both') {
                      widget.onDrawingMoved?.call(dxM, dyM);
                    } else {
                      widget.onModuleGroupMoved?.call(dxM, dyM);
                    }
                  } else if (widget.toolMode == DesignerToolMode.pan ||
                      (widget.toolMode == DesignerToolMode.editModules && !_isMoveEnabled)) {
                    widget.onPanUpdate?.call(details.delta);
                  }
                },
                onPanEnd: (_) {
                  final int releasedModuleIndex = _draggingModuleIndex;
                  final bool wasDrag = _panTotalDistance > 3.0;

                  setState(() {
                    _draggingVertexIndex = -1;
                    _draggingModuleIndex = -1;
                    _isDraggingRow = false;
                    _isDraggingModuleGroup = false;
                    _isRotatingGroup = false;
                    _rotationPivotScreen = null;
                    _isPanning = false;
                    _draggingDroneArrowId = null;
                    _rotatingDroneArrowId = null;
                    _isDraggingNorthCompass = false;
                    _isRotatingNorthCompass = false;
                    _snapGuideStart = null;
                    _snapGuideEnd = null;
                    _dragStartCompassCenter = null;
                    _dragStartCompassScreenPos = null;
                    _dragStartArrowCenter = null;
                    _dragStartArrowScreenPos = null;
                  });

                  if (releasedModuleIndex != -1) {
                    if (wasDrag) {
                      // O usuário arrastou e soltou a placa: executa o encaixe magnético (Snap) SEMPRE!
                      widget.onModuleDragEnd?.call(releasedModuleIndex);
                    } else {
                      // Clique simples sobre a placa: seleciona a placa imediatamente!
                      setState(() {
                        _selectedRowId = null;
                        _selectedModuleIndex = releasedModuleIndex;
                      });
                      widget.onSelectModule?.call(releasedModuleIndex);
                    }
                  } else if (_panTotalDistance <= 24.0 && _panStartScreenPos != null) {
                    _handleCanvasTapDispatch(_panStartScreenPos!, centerOffset,
                        canvasSize, modulesBbox);
                  }
                },
                onTapUp: (details) {
                  _handleCanvasTapDispatch(details.localPosition, centerOffset,
                      canvasSize, modulesBbox);
                },
                onDoubleTap: () {
                  widget.onCanvasDoubleTap?.call(Offset.zero);
                },
                child: SizedBox(
                  width: canvasSize.width,
                  height: canvasSize.height,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // 1. Camada de Fundo (Google Satélite ou Foto do Drone)
                      _buildBackgroundLayer(canvasSize),

                      // 2. Camada Vetorial (Telhados, Placas de TODAS as Águas, Medições e Destaques)
                      CustomPaint(
                        size: canvasSize,
                        painter: _RoofOverlayPainter(
                          vertices: widget.roofVertices,
                          isClosed: widget.isRoofClosed,
                          modules: widget.modules,
                          sections: widget.sections,
                          activeSectionIndex: widget.activeSectionIndex,
                          isEditingActiveSection: widget.isEditingActiveSection,
                          metersPerPixel: widget.metersPerPixel,
                          toolMode: widget.toolMode,
                          panOffsetX: widget.panOffsetX,
                          panOffsetY: widget.panOffsetY,
                          draggingIndex: _draggingVertexIndex,
                          hoveredVertexIndex: _hoveredVertexIndex,
                          draggingModuleIndex: _draggingModuleIndex,
                          selectedModuleIndex: _selectedModuleIndex,
                          selectedRowId: _selectedRowId,
                          activeClusterId: widget.activeClusterId,
                          isDraggingGroup: _isDraggingModuleGroup,
                          snappedModuleIndex: widget.snappedModuleIndex,
                          droneNorthCompass: widget.droneNorthCompass,
                          droneArrows: widget.droneArrows,
                          selectedDroneArrowId: _selectedDroneArrowId ??
                              widget.selectedDroneArrowId,
                          snapGuideStart: _snapGuideStart,
                          snapGuideEnd: _snapGuideEnd,
                          panelTextureImage: _solarPanelImage,
                          isRenderMode: widget.isRenderMode,
                          sectionEfficiencies: widget.sectionEfficiencies,
                          activeSectionEfficiency: widget.activeSectionEfficiency,
                        ),
                      ),

                      // 3. Mira / Alvo Central de Referência Geográfica
                      Center(
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.amber, width: 2),
                          ),
                          child: Center(
                            child: Container(
                              width: 3,
                              height: 3,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.amber,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // 4. Seletor de Águas / Quedas no Topo (Pills navegáveis sempre visíveis desde o início)
                      if (widget.sections.isNotEmpty) ...[
                        Positioned(
                          top: 68,
                          left: 20,
                          child: _buildSectionPillsSelector(),
                        ),
                      ],

                      // 5. Toolbar Horizontal fixa abaixo do menu de pills (ramificada do seletor)
                      if (widget.isEditingActiveSection &&
                          widget.modules.isNotEmpty) ...[
                        // 5.1 Barra de ação compacta logo abaixo dos pills
                        Positioned(
                          top: 108,
                          left: 20,
                          child: _buildHorizontalModuleToolbar(),
                        ),

                        // 5.2 Alça de Rotação à Mão Livre do Conjunto Todo
                        if (modulesBbox != null)
                          Positioned(
                            left: modulesBbox.center.dx - 15,
                            top: (modulesBbox.top - 50)
                                .clamp(10.0, canvasSize.height - 90),
                            child: _buildRotationHandleWidget(modulesBbox),
                          ),

                        // 5.3 Alça de Mover / Ativar ancorada no CANTO SUPERIOR ESQUERDO ou à esquerda do polígono/bbox
                        if (modulesBbox != null)
                          Positioned(
                            left: (modulesBbox.left - ((widget.roofVertices.isEmpty || !_isMoveEnabled) ? 85 : 140)) >= 12.0
                                ? (modulesBbox.left - ((widget.roofVertices.isEmpty || !_isMoveEnabled) ? 85 : 140)) // À esquerda do telhado se houver folga na tela
                                : modulesBbox.left.clamp(8.0, canvasSize.width - ((widget.roofVertices.isEmpty || !_isMoveEnabled) ? 90 : 145)), // No canto superior esquerdo
                            top: (modulesBbox.left - ((widget.roofVertices.isEmpty || !_isMoveEnabled) ? 85 : 140)) >= 12.0
                                ? (modulesBbox.top - 6).clamp(8.0, canvasSize.height - 35)
                                : (modulesBbox.top - 36).clamp(8.0, canvasSize.height - 35),
                            child: _buildDrawingDragHandle(),
                          ),

                        // 5.4 Balão de dica temporizado (4s ou fechamento no X) - apenas quando há polígono desenhado
                        if (_showMoveTip && modulesBbox != null && widget.roofVertices.isNotEmpty)
                          Positioned(
                            left: modulesBbox.left.clamp(8.0, canvasSize.width - 320),
                            top: (modulesBbox.top > 65
                                    ? modulesBbox.top - 50
                                    : modulesBbox.top + 32)
                                .clamp(8.0, canvasSize.height - 60),
                            child: _buildMoveTipBalloon(),
                          ),
                      ],

                      // 6. Mini Barra Flutuante da Placa Selecionada Individualmente
                      if (widget.isEditingActiveSection &&
                          _selectedModuleIndex >= 0 &&
                          _selectedModuleIndex < widget.modules.length) ...[
                        _buildSelectedModuleFloatingBar(
                            canvasSize, centerOffset),
                      ],

                      // 6.1 Barra Flutuante da Linha/Fileira Selecionada
                      if (widget.isEditingActiveSection &&
                          _selectedRowId != null) ...[
                        _buildSelectedRowFloatingBar(canvasSize, centerOffset),
                      ],

                      // 7. Rosa dos Ventos Flutuante (Norte Geográfico - apenas em satélite)
                      if (widget.backgroundMode != BackgroundLayerMode.dronePhoto)
                        Positioned(
                          top: 16,
                          right: 16,
                          child: _buildCompassWidget(),
                        ),


                      // 8. Barra de Escala Métrica
                      Positioned(
                        bottom: 16,
                        left: 16,
                        child: _buildScaleWidget(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Pílulas seletoras de águas no topo esquerdo do canvas
  Widget _buildSectionPillsSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 8),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...widget.sections.asMap().entries.map((entry) {
            final idx = entry.key;
            final sec = entry.value;
            final isActive = idx == widget.activeSectionIndex;

            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: InkWell(
                onTap: () => widget.onSectionSelected?.call(idx),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: isActive
                        ? sec.themeColor.withValues(alpha: 0.25)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isActive ? sec.themeColor : Colors.transparent,
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.roofing_rounded,
                        size: 13,
                        color:
                            isActive ? sec.themeColor : const Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${sec.name} (${sec.activeModuleCount} pl)',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight:
                              isActive ? FontWeight.bold : FontWeight.normal,
                          color:
                              isActive ? Colors.white : const Color(0xFF94A3B8),
                        ),
                      ),
                      // Se estiver concluída (não está editando), mostra o ícone de lápis para editar
                      if (!widget.isEditingActiveSection || !isActive) ...[
                        const SizedBox(width: 4),
                        Tooltip(
                          message: 'Editar este telhado',
                          child: InkWell(
                            onTap: () {
                              if (!isActive) {
                                widget.onSectionSelected?.call(idx);
                              }
                              widget.onResumeEditing?.call();
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: const Padding(
                              padding: EdgeInsets.all(2),
                              child: Icon(Icons.edit_rounded,
                                  size: 12, color: Color(0xFF38BDF8)),
                            ),
                          ),
                        ),
                      ],
                      if (widget.sections.length > 1) ...[
                        const SizedBox(width: 5),
                        InkWell(
                          onTap: () => widget.onDeleteSection?.call(idx),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.white12,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close_rounded,
                                size: 11, color: Color(0xFFEF4444)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),

          // Botão + Novo Telhado no topo
          InkWell(
            onTap: widget.onAddNewSection,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.add_rounded,
                      size: 14, color: Color(0xFF10B981)),
                  const SizedBox(width: 2),
                  Text(
                    '+ Novo Telhado',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Constrói o mini balão de controle flutuante sobre a placa selecionada individualmente
  Widget _buildSelectedModuleFloatingBar(Size canvasSize, Offset centerOffset) {
    final mod = widget.modules[_selectedModuleIndex];
    final screenCenter = Offset(
      centerOffset.dx +
          RoofGeometryService.metersToPixels(
              mod.center.x, widget.metersPerPixel),
      centerOffset.dy +
          RoofGeometryService.metersToPixels(
              mod.center.y, widget.metersPerPixel),
    );

    return Positioned(
      left: (screenCenter.dx - 75).clamp(12.0, canvasSize.width - 160),
      top: (screenCenter.dy - 56).clamp(12.0, canvasSize.height - 50),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF38BDF8), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Botão Girar Esta Placa em 90°
            Tooltip(
              message: 'Girar apenas esta placa em 90°',
              child: InkWell(
                onTap: () =>
                    widget.onRotateSingleModule90?.call(_selectedModuleIndex),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.rotate_90_degrees_cw_rounded,
                          size: 12, color: Color(0xFFA5B4FC)),
                      const SizedBox(width: 3),
                      Text('90°',
                          style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),

            // Alça de Giro Livre à Mão desta placa
            Tooltip(
              message: 'Girar esta placa livremente (arraste)',
              child: GestureDetector(
                onPanStart: (details) {
                  _lastDragAngle = math.atan2(
                    details.globalPosition.dy - screenCenter.dy,
                    details.globalPosition.dx - screenCenter.dx,
                  );
                },
                onPanUpdate: (details) {
                  final currentAngle = math.atan2(
                    details.globalPosition.dy - screenCenter.dy,
                    details.globalPosition.dx - screenCenter.dx,
                  );
                  final deltaAngle = currentAngle - _lastDragAngle;
                  _lastDragAngle = currentAngle;
                  widget.onRotateSingleModule
                      ?.call(_selectedModuleIndex, deltaAngle);
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.sync_rounded,
                            size: 12, color: Color(0xFF10B981)),
                        const SizedBox(width: 2),
                        Text(
                          '${((mod.rotationRadians * 180 / math.pi) % 360).round()}°',
                          style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),

            // Botão Adicionar Placa Relativa a esta placa selecionada
            Tooltip(
              message: 'Adicionar nova placa ao lado, à frente ou atrás desta',
              child: InkWell(
                onTap: () => _showAddRelativeModuleDialog(_selectedModuleIndex),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: const Color(0xFF10B981).withValues(alpha: 0.6)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_rounded,
                          size: 13, color: Color(0xFF10B981)),
                      const SizedBox(width: 2),
                      Text('+ Placa',
                          style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),

            // Botão Excluir Linha Inteira (se pertencer a uma fileira criada)
            if (mod.rowId != null) ...[
              Tooltip(
                message: 'Excluir fileira inteira (X)',
                child: InkWell(
                  onTap: () {
                    final rId = mod.rowId!;
                    setState(() => _selectedModuleIndex = -1);
                    widget.onDeleteRow?.call(rId);
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color:
                              const Color(0xFFEF4444).withValues(alpha: 0.6)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.table_rows_rounded,
                            size: 12, color: Color(0xFFFCA5A5)),
                        const SizedBox(width: 2),
                        const Icon(Icons.close_rounded,
                            size: 12, color: Color(0xFFEF4444)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],

            // Botão Excluir Placa Individual (Apenas ícone de lixeira, sem texto!)
            Tooltip(
              message: 'Excluir placa',
              child: InkWell(
                onTap: () {
                  final idx = _selectedModuleIndex;
                  setState(() => _selectedModuleIndex = -1);
                  widget.onDeleteSingleModule?.call(idx);
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.delete_outline_rounded,
                      size: 14, color: Color(0xFFEF4444)),
                ),
              ),
            ),
            const SizedBox(width: 4),

            // Botão Fechar Seleção
            InkWell(
              onTap: () {
                setState(() => _selectedModuleIndex = -1);
                widget.onSelectModule?.call(-1);
              },
              borderRadius: BorderRadius.circular(10),
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(Icons.close_rounded,
                    size: 14, color: Color(0xFF94A3B8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Exibe diálogo modal compacto perguntando a posição desejada para a nova placa
  void _showAddRelativeModuleDialog(int targetIndex) {
    if (targetIndex < 0 || targetIndex >= widget.modules.length) return;

    showDialog(
      context: context,
      builder: (ctx) {
        Widget positionOption({
          required String label,
          required IconData icon,
          required String positionKey,
          required Color color,
        }) {
          return InkWell(
            onTap: () {
              Navigator.of(ctx).pop();
              widget.onAddModuleRelative?.call(targetIndex, positionKey);
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: color.withValues(alpha: 0.45), width: 1.2),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
          ),
          title: Row(
            children: [
              const Icon(Icons.add_box_rounded,
                  color: Color(0xFF10B981), size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Deseja adicionar em que posição?',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              positionOption(
                label: 'Esquerda da placa',
                icon: Icons.arrow_back_rounded,
                positionKey: 'left',
                color: const Color(0xFF38BDF8),
              ),
              const SizedBox(height: 8),
              positionOption(
                label: 'Direita da placa',
                icon: Icons.arrow_forward_rounded,
                positionKey: 'right',
                color: const Color(0xFF38BDF8),
              ),
              const SizedBox(height: 8),
              positionOption(
                label: 'À frente da placa',
                icon: Icons.arrow_downward_rounded,
                positionKey: 'front',
                color: const Color(0xFF10B981),
              ),
              const SizedBox(height: 8),
              positionOption(
                label: 'Atrás da placa',
                icon: Icons.arrow_upward_rounded,
                positionKey: 'back',
                color: const Color(0xFFF59E0B),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'Cancelar',
                style: GoogleFonts.inter(
                    color: const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Pergunta para qual lado da cumeeira espelhar: À Frente ou Atrás das placas
  void _showDuplicateSectionDirectionDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        Widget dirButton({
          required String label,
          required String subtitle,
          required IconData icon,
          required String directionKey,
          required Color color,
        }) {
          return InkWell(
            onTap: () {
              Navigator.of(ctx).pop();
              widget.onDuplicateCurrentSection?.call(directionKey);
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: color.withValues(alpha: 0.5), width: 1.3),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 20, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: GoogleFonts.inter(
                              fontSize: 11, color: const Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: color, size: 18),
                ],
              ),
            ),
          );
        }

        return AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
          ),
          title: Row(
            children: [
              const Icon(Icons.flip_rounded,
                  color: Color(0xFFA5B4FC), size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Duplicar e Espelhar Telhado',
                  style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Para qual lado da cumeeira você deseja espelhar o telhado oposto?',
                style: GoogleFonts.inter(color: Colors.white70, fontSize: 12.5),
              ),
              const SizedBox(height: 14),
              dirButton(
                label: 'À Frente das Placas',
                subtitle: 'Espelha na cumeeira voltada para a frente',
                icon: Icons.arrow_downward_rounded,
                directionKey: 'front',
                color: const Color(0xFF10B981),
              ),
              const SizedBox(height: 10),
              dirButton(
                label: 'Atrás das Placas',
                subtitle: 'Espelha na cumeeira voltada para trás',
                icon: Icons.arrow_upward_rounded,
                directionKey: 'back',
                color: const Color(0xFF38BDF8),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'Cancelar',
                style: GoogleFonts.inter(
                    color: const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Pergunta se deseja mover somente as placas ou o polígono com as placas
  void _showMoveSelectionDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        Widget moveOption({
          required String title,
          required String subtitle,
          required IconData icon,
          required String mode,
          required Color color,
        }) {
          final isCurrent = _moveMode == mode;
          return InkWell(
            onTap: () {
              Navigator.of(ctx).pop();
              setState(() {
                _moveMode = mode;
                _isMoveEnabled = true;
                _moveTipText = mode == 'both'
                    ? 'o polígono com as placas'
                    : 'somente as placas';
                _showMoveTip = true;
              });
              _tipTimer?.cancel();
              _tipTimer = Timer(const Duration(seconds: 4), () {
                if (mounted) {
                  setState(() => _showMoveTip = false);
                }
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isCurrent
                    ? color.withValues(alpha: 0.22)
                    : color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isCurrent ? color : color.withValues(alpha: 0.4),
                  width: isCurrent ? 1.8 : 1.2,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 20, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              title,
                              style: GoogleFonts.inter(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                            if (isCurrent) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('ATIVO',
                                    style: GoogleFonts.inter(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white)),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: GoogleFonts.inter(
                              fontSize: 11, color: const Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.check_circle_rounded,
                      color: isCurrent ? color : Colors.white24, size: 20),
                ],
              ),
            ),
          );
        }

        return AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
          ),
          title: Row(
            children: [
              const Icon(Icons.open_with_rounded,
                  color: Color(0xFFF59E0B), size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Como deseja mover?',
                  style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Deseja mover somente as placas ou o polígono com as placas?',
                style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 14),
              moveOption(
                title: 'Mover somente as placas',
                subtitle:
                    'O polígono do telhado fica fixo e apenas as placas se movem',
                icon: Icons.solar_power_rounded,
                mode: 'modules',
                color: const Color(0xFF38BDF8),
              ),
              const SizedBox(height: 10),
              moveOption(
                title: 'Mover polígono com as placas',
                subtitle:
                    'O desenho do telhado e todas as placas se movem juntos',
                icon: Icons.roofing_rounded,
                mode: 'both',
                color: const Color(0xFFF59E0B),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'Fechar',
                style: GoogleFonts.inter(
                    color: const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Barra de controle flutuante quando a fileira inteira (_selectedRowId) está selecionada
  Widget _buildSelectedRowFloatingBar(Size canvasSize, Offset centerOffset) {
    final rowMods =
        widget.modules.where((m) => m.rowId == _selectedRowId).toList();
    if (rowMods.isEmpty) return const SizedBox.shrink();

    // Centro da fileira
    double sumX = 0, sumY = 0;
    for (final m in rowMods) {
      sumX += m.center.x;
      sumY += m.center.y;
    }
    final avgX = sumX / rowMods.length;
    final avgY = sumY / rowMods.length;
    final screenCenter = Offset(
      centerOffset.dx +
          RoofGeometryService.metersToPixels(avgX, widget.metersPerPixel),
      centerOffset.dy +
          RoofGeometryService.metersToPixels(avgY, widget.metersPerPixel),
    );

    return Positioned(
      left: (screenCenter.dx - 100).clamp(12.0, canvasSize.width - 210),
      top: (screenCenter.dy - 56).clamp(12.0, canvasSize.height - 50),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF38BDF8), width: 1.6),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Badge com número de placas na linha
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF38BDF8).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.table_rows_rounded,
                      size: 12, color: Color(0xFF38BDF8)),
                  const SizedBox(width: 4),
                  Text(
                    'Linha (${rowMods.length} pl)',
                    style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF38BDF8)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),

            // Botão Mover Linha (ao arrastar este ícone, move a fileira)
            Tooltip(
              message: 'Arrastar fileira inteira pelo mapa',
              child: GestureDetector(
                onPanUpdate: (details) {
                  final dxM = RoofGeometryService.pixelsToMeters(
                      details.delta.dx, widget.metersPerPixel);
                  final dyM = RoofGeometryService.pixelsToMeters(
                      details.delta.dy, widget.metersPerPixel);
                  widget.onRowMoved?.call(_selectedRowId!, dxM, dyM);
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.move,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color:
                              const Color(0xFFF59E0B).withValues(alpha: 0.6)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.open_with_rounded,
                            size: 13, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 3),
                        Text(
                          'Mover',
                          style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFF59E0B)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),

            // Botão Excluir Linha
            Tooltip(
              message: 'Excluir todas as placas desta linha',
              child: InkWell(
                onTap: () {
                  final rId = _selectedRowId!;
                  setState(() => _selectedRowId = null);
                  widget.onDeleteRow?.call(rId);
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.5)),
                  ),
                  child: const Icon(Icons.delete_outline_rounded,
                      size: 14, color: Color(0xFFEF4444)),
                ),
              ),
            ),
            const SizedBox(width: 4),

            // Fechar Seleção da Linha
            InkWell(
              onTap: () => setState(() => _selectedRowId = null),
              borderRadius: BorderRadius.circular(10),
              child: const Padding(
                padding: EdgeInsets.all(3),
                child: Icon(Icons.close_rounded,
                    size: 14, color: Color(0xFF94A3B8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Toolbar horizontal compacta ramificada logo abaixo do seletor de águas
  Widget _buildHorizontalModuleToolbar() {
    final activeModules = widget.modules.where((m) => !m.isExcluded).length;
    final normalizedAngle =
        ((widget.groupRotationDegrees % 360 + 360) % 360).toStringAsFixed(0);

    const double h = 32.0;

    Widget btn({
      required Widget child,
      VoidCallback? onTap,
      Color borderColor = const Color(0xFF334155),
      Color bgColor = const Color(0xFF1E293B),
      String tooltip = '',
      EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 8),
    }) {
      return Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: h,
            padding: padding,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor, width: 1.1),
            ),
            child: Center(child: child),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF334155), width: 1.1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Conector visual ramificado (pequeno ícone ou curva)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Icon(Icons.subdirectory_arrow_right_rounded,
                size: 14, color: Color(0xFFF59E0B)),
          ),

          // + Linha
          btn(
            tooltip: 'Adicionar fileira de placas',
            onTap: widget.onAddRow,
            bgColor: const Color(0xFF38BDF8).withValues(alpha: 0.15),
            borderColor: const Color(0xFF38BDF8).withValues(alpha: 0.6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.table_rows_rounded,
                    size: 12, color: Color(0xFF38BDF8)),
                const SizedBox(width: 4),
                Text('+ Linha',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ],
            ),
          ),
          const SizedBox(width: 5),

          // Mover (Ativar Movimento se inativo, ou Mover direto se for modo avulso sem polígono)
          btn(
            tooltip: widget.roofVertices.isEmpty
                ? 'Mover conjunto de placas'
                : (!_isMoveEnabled
                    ? 'Clique para ativar o movimento'
                    : (_moveMode == 'both'
                        ? 'Mover Polígono + Placas (Clique para alterar)'
                        : 'Mover Somente as Placas (Clique para alterar)')),
            onTap: widget.roofVertices.isEmpty ? null : _showMoveSelectionDialog,
            bgColor: widget.roofVertices.isEmpty
                ? const Color(0xFF38BDF8).withValues(alpha: 0.2)
                : (!_isMoveEnabled
                    ? const Color(0xFF64748B).withValues(alpha: 0.2)
                    : (_moveMode == 'both'
                        ? const Color(0xFFF59E0B).withValues(alpha: 0.25)
                        : const Color(0xFF38BDF8).withValues(alpha: 0.2))),
            borderColor: widget.roofVertices.isEmpty
                ? const Color(0xFF38BDF8).withValues(alpha: 0.6)
                : (!_isMoveEnabled
                    ? const Color(0xFF94A3B8).withValues(alpha: 0.5)
                    : (_moveMode == 'both'
                        ? const Color(0xFFF59E0B).withValues(alpha: 0.8)
                        : const Color(0xFF38BDF8).withValues(alpha: 0.6))),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.roofVertices.isEmpty
                      ? Icons.open_with_rounded
                      : (!_isMoveEnabled
                          ? Icons.touch_app_rounded
                          : Icons.open_with_rounded),
                  size: 12,
                  color: widget.roofVertices.isEmpty
                      ? const Color(0xFF38BDF8)
                      : (!_isMoveEnabled
                          ? const Color(0xFFF59E0B)
                          : (_moveMode == 'both'
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF38BDF8))),
                ),
                const SizedBox(width: 3),
                Text(
                  widget.roofVertices.isEmpty
                      ? 'Mover'
                      : (!_isMoveEnabled
                          ? 'Ativar Mover'
                          : (_moveMode == 'both' ? 'Mover (+Telhado)' : 'Mover')),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                if (widget.roofVertices.isNotEmpty && _isMoveEnabled) ...[
                  const SizedBox(width: 3),
                  const Icon(Icons.edit_rounded,
                      size: 10, color: Colors.white70),
                ],
              ],
            ),
          ),
          const SizedBox(width: 5),

          // Girar 90°
          btn(
            tooltip: 'Girar 90° (Retrato ↔ Paisagem)',
            onTap: widget.onRotate90,
            bgColor: const Color(0xFF6366F1).withValues(alpha: 0.15),
            borderColor: const Color(0xFF6366F1).withValues(alpha: 0.5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.rotate_90_degrees_cw_rounded,
                    size: 12, color: Color(0xFFA5B4FC)),
                const SizedBox(width: 4),
                Text('90°',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ],
            ),
          ),
          const SizedBox(width: 5),

          // Ângulo livre
          btn(
            tooltip: 'Definir ângulo exato',
            onTap: widget.onOpenAngleDialog,
            bgColor: const Color(0xFF1E293B),
            borderColor: const Color(0xFF38BDF8).withValues(alpha: 0.4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.screen_rotation_alt_rounded,
                    size: 11, color: Color(0xFF38BDF8)),
                const SizedBox(width: 3),
                Text('$normalizedAngle° ✎',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF38BDF8))),
              ],
            ),
          ),
          const SizedBox(width: 5),

          // Concluir conjunto
          if (widget.onConcludeCluster != null) ...[
            btn(
              tooltip: (widget.isClusterFinalized || widget.activeClusterId == null)
                  ? 'Conjunto já concluído (clique em uma placa para reativar)'
                  : 'Concluir este conjunto de placas',
              onTap: (widget.isClusterFinalized || widget.activeClusterId == null)
                  ? null
                  : widget.onConcludeCluster,
              bgColor: (widget.isClusterFinalized || widget.activeClusterId == null)
                  ? const Color(0xFF64748B).withValues(alpha: 0.15)
                  : const Color(0xFF10B981).withValues(alpha: 0.18),
              borderColor: (widget.isClusterFinalized || widget.activeClusterId == null)
                  ? const Color(0xFF64748B).withValues(alpha: 0.4)
                  : const Color(0xFF10B981).withValues(alpha: 0.7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 13,
                    color: (widget.isClusterFinalized || widget.activeClusterId == null)
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF10B981),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Concluir conjunto',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: (widget.isClusterFinalized || widget.activeClusterId == null)
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 5),
          ],

          // Duplicar Telhado (Espelhar oposto)
          Tooltip(
            message: 'Duplicar telhado',
            child: InkWell(
              onTap: _showDuplicateSectionDirectionDialog,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                height: h,
                padding: const EdgeInsets.symmetric(horizontal: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.6),
                      width: 1.1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.flip_rounded,
                        size: 13, color: Color(0xFFA5B4FC)),
                    const SizedBox(width: 3),
                    const Icon(Icons.content_copy_rounded,
                        size: 11, color: Color(0xFFA5B4FC)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Contador de placas
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$activeModules pl',
              style: GoogleFonts.inter(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF94A3B8)),
            ),
          ),
          const SizedBox(width: 6),

          // Concluir Telhado
          Tooltip(
            message: 'Finalizar edição deste telhado',
            child: InkWell(
              onTap: widget.onFinishCurrentSection,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                height: h,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: const Color(0xFF10B981), width: 1.3),
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          size: 13, color: Color(0xFF10B981)),
                      const SizedBox(width: 4),
                      Text('Concluir Telhado',
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF10B981))),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Alça de mover ou ativar o movimento no polígono / conjunto de placas.
  /// Se inativo: ícone de ATIVAR (não move no arraste, força o clique para abrir o diálogo).
  /// Se ativo: ícone de MOVER (com arraste habilitado) + ícone ✎ para trocar de opção.
  /// Se sem polígono: diretamente MOVER com ícone de mover e arraste imediato.
  Widget _buildDrawingDragHandle() {
    final bool hasNoPolygon = widget.roofVertices.isEmpty;
    if (hasNoPolygon) {
      const activeColor = Color(0xFF38BDF8);
      return Container(
        height: 28,
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: activeColor, width: 1.8),
          boxShadow: [
            BoxShadow(
              color: activeColor.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Tooltip(
          message: 'Arrastar para mover conjunto de placas',
          child: GestureDetector(
            onPanUpdate: (details) {
              final dxM = RoofGeometryService.pixelsToMeters(
                  details.delta.dx, widget.metersPerPixel);
              final dyM = RoofGeometryService.pixelsToMeters(
                  details.delta.dy, widget.metersPerPixel);
              widget.onModuleGroupMoved?.call(dxM, dyM);
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.move,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                color: Colors.transparent,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.open_with_rounded,
                        size: 14, color: activeColor),
                    const SizedBox(width: 4),
                    Text(
                      'MOVER',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (!_isMoveEnabled) {
      return Tooltip(
        message: 'Clique para ativar o movimento',
        child: InkWell(
          onTap: _showMoveSelectionDialog,
          borderRadius: BorderRadius.circular(16),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Container(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF59E0B), width: 1.8),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.touch_app_rounded,
                      size: 14, color: Color(0xFFF59E0B)),
                  const SizedBox(width: 4),
                  Text(
                    'ATIVAR',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: const Color(0xFFF59E0B),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final isBoth = _moveMode == 'both';
    final activeColor =
        isBoth ? const Color(0xFFF59E0B) : const Color(0xFF38BDF8);

    return Container(
      height: 28,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: activeColor, width: 1.8),
        boxShadow: [
          BoxShadow(
            color: activeColor.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Área de Arraste (Mover)
          Tooltip(
            message: isBoth
                ? 'Arrastar para mover polígono + placas'
                : 'Arrastar para mover somente placas',
            child: GestureDetector(
              onPanUpdate: (details) {
                final dxM = RoofGeometryService.pixelsToMeters(
                    details.delta.dx, widget.metersPerPixel);
                final dyM = RoofGeometryService.pixelsToMeters(
                    details.delta.dy, widget.metersPerPixel);
                if (_moveMode == 'both') {
                  widget.onDrawingMoved?.call(dxM, dyM);
                } else {
                  widget.onModuleGroupMoved?.call(dxM, dyM);
                }
              },
              child: MouseRegion(
                cursor: SystemMouseCursors.move,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7),
                  color: Colors.transparent,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.open_with_rounded,
                          size: 14, color: activeColor),
                      const SizedBox(width: 4),
                      Text(
                        isBoth ? 'MOVER (+TELHADO)' : 'MOVER',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Divisor vertical
          Container(
            width: 1,
            height: 14,
            color: Colors.white24,
          ),

          // Ícone de Edição (Lápis) para reabrir diálogo e trocar de opção
          Tooltip(
            message: 'Alterar modo de mover (placas ou conjunto)',
            child: InkWell(
              onTap: _showMoveSelectionDialog,
              borderRadius:
                  const BorderRadius.horizontal(right: Radius.circular(16)),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  child: Icon(Icons.edit_rounded, size: 13, color: activeColor),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Balão de dica (tip) temporizado em 4s informando o que pode ser movido
  Widget _buildMoveTipBalloon() {
    final isBoth = _moveMode == 'both';
    final accentColor =
        isBoth ? const Color(0xFFF59E0B) : const Color(0xFF38BDF8);

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accentColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: accentColor.withValues(alpha: 0.25),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isBoth ? Icons.roofing_rounded : Icons.solar_power_rounded,
                size: 14,
                color: accentColor,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Agora você pode mover $_moveTipText',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            InkWell(
              onTap: () {
                setState(() {
                  _showMoveTip = false;
                  _tipTimer?.cancel();
                });
              },
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(
                  Icons.close_rounded,
                  size: 15,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Alça circular de rotação livre localizada no topo do conjunto de placas

  Widget _buildRotationHandleWidget(Rect bbox) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: 'Girar conjunto à mão livre (clique e arraste em círculo)',
          child: MouseRegion(
            cursor: SystemMouseCursors.grab,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isRotatingGroup
                    ? const Color(0xFF10B981)
                    : const Color(0xFF6366F1),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(Icons.sync_rounded, color: Colors.white, size: 17),
              ),
            ),
          ),
        ),
        Container(
          width: 2,
          height: 8,
          color: const Color(0xFF6366F1).withValues(alpha: 0.6),
        ),
      ],
    );
  }

  /// Constrói o fundo de acordo com o modo ativo: Satélite ou Foto de Drone
  Widget _buildBackgroundLayer(Size canvasSize) {
    if (widget.backgroundMode == BackgroundLayerMode.dronePhoto) {
      if (widget.droneImageBytes != null) {
        final double scale = math.pow(2.0, widget.zoom - 18.0).toDouble();

        return Container(
          color: const Color(0xFF0F172A),
          child: Center(
            child: Transform.translate(
              offset: Offset(widget.panOffsetX, widget.panOffsetY),
              child: Transform.scale(
                scale: scale,
                child: Image.memory(
                  widget.droneImageBytes!,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        );
      }

      return Container(
        color: const Color(0xFF0F172A),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_a_photo_outlined,
                  color: Color(0xFF38BDF8), size: 48),
              const SizedBox(height: 12),
              Text(
                'Nenhuma foto de drone carregada neste estudo',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Clique no botão da câmera no topo para carregar a foto do drone',
                style: GoogleFonts.inter(
                  color: const Color(0xFF94A3B8),
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _buildSatelliteTileLayer(canvasSize);
  }

  /// Constrói o fundo de satélite carregando os tiles de alta resolução da região
  Widget _buildSatelliteTileLayer(Size canvasSize) {
    final int z = widget.zoom.round().clamp(1, 20);
    final centerTile = SatelliteMapService.latLngToTileCoords(
        widget.latitude, widget.longitude, z);

    final halfW = canvasSize.width / 2.0;
    final halfH = canvasSize.height / 2.0;
    const tileSize = 256.0;

    final startX =
        (centerTile.x - (halfW + widget.panOffsetX + tileSize) / tileSize)
            .floor();
    final endX =
        (centerTile.x + (halfW - widget.panOffsetX + tileSize) / tileSize)
            .ceil();
    final startY =
        (centerTile.y - (halfH + widget.panOffsetY + tileSize) / tileSize)
            .floor();
    final endY =
        (centerTile.y + (halfH - widget.panOffsetY + tileSize) / tileSize)
            .ceil();

    final List<Widget> tileWidgets = [];

    for (int tx = startX; tx <= endX; tx++) {
      for (int ty = startY; ty <= endY; ty++) {
        final tileUrl = SatelliteMapService.getTileUrl(tx, ty, z,
            source: widget.satelliteSource);

        final left = halfW + widget.panOffsetX + (tx - centerTile.x) * tileSize;
        final top = halfH + widget.panOffsetY + (ty - centerTile.y) * tileSize;

        tileWidgets.add(
          Positioned(
            key: ValueKey('tile_${widget.satelliteSource.name}_${tx}_${ty}_$z'),
            left: left,
            top: top,
            width: tileSize,
            height: tileSize,
            child: Image.network(
              tileUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: const Color(0xFF1E293B),
                child: const Center(
                  child: Icon(Icons.satellite_alt_outlined,
                      color: Colors.white24, size: 24),
                ),
              ),
            ),
          ),
        );
      }
    }

    return SizedBox(
      width: canvasSize.width,
      height: canvasSize.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: const Color(0xFF0F172A)),
          ...tileWidgets,
        ],
      ),
    );
  }

  /// Rosa dos ventos estilizada indicando o Norte magnético
  Widget _buildCompassWidget() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.navigation_rounded,
              color: Color(0xFFEF4444), size: 16),
          const SizedBox(width: 6),
          Text(
            'NORTE (0°)',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  /// Régua métrica que mostra quantos pixels equivalem a 5 metros reais
  Widget _buildScaleWidget() {
    final fiveMetersInPixels =
        RoofGeometryService.metersToPixels(5.0, widget.metersPerPixel);
    final clampedWidth = fiveMetersInPixels.clamp(30.0, 200.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: clampedWidth,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.amber,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '5 metros',
            style: GoogleFonts.inter(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: Colors.white70),
          ),
        ],
      ),
    );
  }

  void _handleCanvasTapDispatch(Offset localPos, Offset centerOffset,
      Size canvasSize, Rect? modulesBbox) {
    final now = DateTime.now();
    if (now.difference(_lastProcessedTap).inMilliseconds < 120) {
      return;
    }
    _lastProcessedTap = now;

    // Bloqueia qualquer clique no canvas se a IA ainda estiver analisando a foto do drone
    if (widget.isAnalyzingDrone &&
        widget.backgroundMode == BackgroundLayerMode.dronePhoto) {
      return;
    }

    // 0. SE ESTIVER NO MODO DESENHAR TELHADO (drawRoof) E O TELHADO AINDA NÃO ESTIVER FECHADO:
    // O clique é para colocar novo vértice ou fechar o polígono!
    if (widget.toolMode == DesignerToolMode.drawRoof && !widget.isRoofClosed) {
      widget.onCanvasTap?.call(localPos);
      return;
    }

    final dxM = RoofGeometryService.pixelsToMeters(
        localPos.dx - centerOffset.dx, widget.metersPerPixel);
    final dyM = RoofGeometryService.pixelsToMeters(
        localPos.dy - centerOffset.dy, widget.metersPerPixel);
    final clickMeters = RoofPoint(dxM, dyM);

    // 0.1 ANOTAÇÕES DE DRONE: Se clicou sobre qualquer seta de queda do telhado
    if (widget.droneArrows.isNotEmpty) {
      final hitRot = _findHitDroneArrowRotationHandle(localPos, centerOffset);
      if (hitRot != null) {
        setState(() {
          _selectedDroneArrowId = hitRot.id;
        });
        widget.onSelectDroneArrow?.call(hitRot.id);
        return;
      }
      final hitArrow = _findHitDroneArrowBody(localPos, centerOffset);
      if (hitArrow != null) {
        setState(() {
          _selectedDroneArrowId = hitArrow.id;
        });
        widget.onSelectDroneArrow?.call(hitArrow.id);
        return;
      }
    }

    // 1. Se a seção ativa estiver concluída e o usuário clicou nela: retoma edição!
    if (!widget.isEditingActiveSection) {
      final effectiveVertices = widget.roofVertices.isNotEmpty
          ? widget.roofVertices
          : (widget.activeSectionIndex >= 0 &&
                  widget.activeSectionIndex < widget.sections.length
              ? widget.sections[widget.activeSectionIndex].vertices
              : <RoofPoint>[]);
      final activePolygon = RoofPolygon(vertices: effectiveVertices);
      bool hit = (effectiveVertices.length >= 3 &&
              activePolygon.containsPoint(clickMeters)) ||
          widget.modules.any((m) => m.containsPoint(clickMeters));

      if (!hit && effectiveVertices.isNotEmpty) {
        final aPoints = widget.modules.isNotEmpty
            ? widget.modules
                .where((m) => !m.isExcluded)
                .expand((m) => m.getCorners())
                .map((p) => Offset(
                      centerOffset.dx +
                          RoofGeometryService.metersToPixels(
                              p.x, widget.metersPerPixel),
                      centerOffset.dy +
                          RoofGeometryService.metersToPixels(
                              p.y, widget.metersPerPixel),
                    ))
            : effectiveVertices.map((p) => Offset(
                  centerOffset.dx +
                      RoofGeometryService.metersToPixels(
                          p.x, widget.metersPerPixel),
                  centerOffset.dy +
                      RoofGeometryService.metersToPixels(
                          p.y, widget.metersPerPixel),
                ));
        double aMinX = double.infinity, aMaxX = -double.infinity;
        double aMinY = double.infinity, aMaxY = -double.infinity;
        for (final pt in aPoints) {
          if (pt.dx < aMinX) aMinX = pt.dx;
          if (pt.dx > aMaxX) aMaxX = pt.dx;
          if (pt.dy < aMinY) aMinY = pt.dy;
          if (pt.dy > aMaxY) aMaxY = pt.dy;
        }
        final aBbox = Rect.fromLTRB(aMinX, aMinY, aMaxX, aMaxY);
        final bool placeRight = (aBbox.right + 45 < canvasSize.width);
        final badgePos = Offset(
            placeRight ? aBbox.right + 26 : aBbox.left - 26, aBbox.center.dy);
        if ((localPos - badgePos).distance <= 35.0) {
          hit = true;
        }
      }

      if (hit) {
        widget.onResumeEditing?.call();
        return;
      }
    }

    // 2. Se clicou em uma placa da água ativa para selecioná-la
    if (widget.isEditingActiveSection && widget.modules.isNotEmpty) {
      int clickedIdx = -1;
      for (int i = widget.modules.length - 1; i >= 0; i--) {
        if (widget.modules[i].containsPoint(clickMeters)) {
          clickedIdx = i;
          break;
        }
      }

      if (clickedIdx != -1) {
        setState(() {
          _selectedRowId = null;
          _selectedModuleIndex = clickedIdx;
        });
        widget.onSelectModule?.call(clickedIdx);
        return;
      }
    }

    // 3. Testa se clicou em uma cota métrica de aresta
    if (widget.isEditingActiveSection && widget.roofVertices.length >= 2) {
      final edgeCount = widget.isRoofClosed
          ? widget.roofVertices.length
          : (widget.roofVertices.length - 1);

      final screenVertices = widget.roofVertices.map((p) {
        final pxX =
            RoofGeometryService.metersToPixels(p.x, widget.metersPerPixel);
        final pxY =
            RoofGeometryService.metersToPixels(p.y, widget.metersPerPixel);
        return Offset(centerOffset.dx + pxX, centerOffset.dy + pxY);
      }).toList();

      double pSumX = 0, pSumY = 0;
      for (final sv in screenVertices) {
        pSumX += sv.dx;
        pSumY += sv.dy;
      }
      final polyCenter =
          Offset(pSumX / screenVertices.length, pSumY / screenVertices.length);

      for (int i = 0; i < edgeCount; i++) {
        final sp1 = screenVertices[i];
        final sp2 = screenVertices[(i + 1) % screenVertices.length];

        final mid = Offset((sp1.dx + sp2.dx) / 2.0, (sp1.dy + sp2.dy) / 2.0);
        final edgeVec = sp2 - sp1;
        final edgeLen = edgeVec.distance;
        Offset badgeHitPos = mid;

        if (edgeLen > 0) {
          Offset norm = Offset(-edgeVec.dy, edgeVec.dx) / edgeLen;
          final dotWithOutward = (mid.dx + norm.dx * 10 - polyCenter.dx) *
                  (mid.dx - polyCenter.dx) +
              (mid.dy + norm.dy * 10 - polyCenter.dy) *
                  (mid.dy - polyCenter.dy);
          final dotCenter =
              (mid.dx - polyCenter.dx) * (mid.dx - polyCenter.dx) +
                  (mid.dy - polyCenter.dy) * (mid.dy - polyCenter.dy);

          if (dotWithOutward < dotCenter) {
            norm = -norm;
          }
          badgeHitPos = mid + norm * 38.0;
        }

        if ((localPos - badgeHitPos).distance <= 22.0) {
          widget.onEdgeTap?.call(i);
          return;
        }
      }
    }

    // 4. Testa se clicou em outra seção
    if (widget.sections.isNotEmpty) {
      for (int s = 0; s < widget.sections.length; s++) {
        if (s == widget.activeSectionIndex) continue;
        final sec = widget.sections[s];
        bool hit = sec.polygon.containsPoint(clickMeters) ||
            sec.modules.any((m) => m.containsPoint(clickMeters));

        if (!hit && sec.vertices.isNotEmpty) {
          final sPoints = sec.modules.isNotEmpty
              ? sec.modules
                  .where((m) => !m.isExcluded)
                  .expand((m) => m.getCorners())
                  .map((p) => Offset(
                        centerOffset.dx +
                            RoofGeometryService.metersToPixels(
                                p.x, widget.metersPerPixel),
                        centerOffset.dy +
                            RoofGeometryService.metersToPixels(
                                p.y, widget.metersPerPixel),
                      ))
              : sec.vertices.map((p) => Offset(
                    centerOffset.dx +
                        RoofGeometryService.metersToPixels(
                            p.x, widget.metersPerPixel),
                    centerOffset.dy +
                        RoofGeometryService.metersToPixels(
                            p.y, widget.metersPerPixel),
                  ));
          double sMinX = double.infinity, sMaxX = -double.infinity;
          double sMinY = double.infinity, sMaxY = -double.infinity;
          for (final pt in sPoints) {
            if (pt.dx < sMinX) sMinX = pt.dx;
            if (pt.dx > sMaxX) sMaxX = pt.dx;
            if (pt.dy < sMinY) sMinY = pt.dy;
            if (pt.dy > sMaxY) sMaxY = pt.dy;
          }
          final sBbox = Rect.fromLTRB(sMinX, sMinY, sMaxX, sMaxY);
          final bool placeRight = (sBbox.right + 45 < canvasSize.width);
          final badgePos = Offset(
              placeRight ? sBbox.right + 26 : sBbox.left - 26, sBbox.center.dy);
          if ((localPos - badgePos).distance <= 35.0) {
            hit = true;
          }
        }

        if (hit) {
          widget.onSectionSelected?.call(s);
          return;
        }
      }
    }

    // 5. Se o telhado da água ativa já está fechado/delimitado:
    // Se o usuário clicar FORA do polígono e fora das placas, conclui a água ativa e vai automaticamente para NAVEGAR!
    if (widget.isRoofClosed && widget.isEditingActiveSection) {
      final activePolygon = RoofPolygon(vertices: widget.roofVertices);
      final bool isInsidePolygon = activePolygon.containsPoint(clickMeters);
      final bool isInsideModules = widget.modules
          .any((m) => !m.isExcluded && m.containsPoint(clickMeters));

      if (!isInsidePolygon && !isInsideModules) {
        setState(() {
          _selectedDroneArrowId = null;
          _selectedModuleIndex = -1;
          _selectedRowId = null;
        });
        widget.onSelectDroneArrow?.call(null);
        widget.onSelectModule?.call(-1);
        widget.onFinishCurrentSection?.call();
        return;
      }
    }

    // 6. Clique em espaço vazio do canvas / fora do desenho: deseleciona tudo (setas, placas, conjuntos)!
    setState(() {
      _selectedDroneArrowId = null;
      _selectedModuleIndex = -1;
      _selectedRowId = null;
    });
    widget.onSelectDroneArrow?.call(null);
    widget.onSelectModule?.call(-1);
    widget.onCanvasTap?.call(localPos);
  }
}

/// Painter que renderiza os polígonos de todas as águas, placas solares de todos os conjuntos e destaques da água ativa
class _RoofOverlayPainter extends CustomPainter {
  final List<RoofPoint> vertices;
  final bool isClosed;
  final List<PlacedModule> modules;
  final List<RoofSection> sections;
  final int activeSectionIndex;
  final bool isEditingActiveSection;
  final double metersPerPixel;
  final DesignerToolMode toolMode;
  final double panOffsetX;
  final double panOffsetY;
  final int draggingIndex;
  final int hoveredVertexIndex;
  final int draggingModuleIndex;
  final int selectedModuleIndex;
  final int? snappedModuleIndex;
  final bool isDraggingGroup;
  final DroneNorthCompass? droneNorthCompass;
  final List<DroneRoofArrow> droneArrows;
  final String? selectedDroneArrowId;
  final Offset? snapGuideStart;
  final Offset? snapGuideEnd;
  final ui.Image? panelTextureImage;
  final bool isRenderMode;
  final Map<String, SolarOrientationEfficiency> sectionEfficiencies;
  final SolarOrientationEfficiency? activeSectionEfficiency;

  _RoofOverlayPainter({
    required this.vertices,
    required this.isClosed,
    required this.modules,
    required this.sections,
    required this.activeSectionIndex,
    this.isEditingActiveSection = true,
    required this.metersPerPixel,
    required this.toolMode,
    required this.panOffsetX,
    required this.panOffsetY,
    this.draggingIndex = -1,
    this.hoveredVertexIndex = -1,
    this.draggingModuleIndex = -1,
    this.selectedModuleIndex = -1,
    this.snappedModuleIndex,
    this.selectedRowId,
    this.activeClusterId,
    this.isDraggingGroup = false,
    this.droneNorthCompass,
    this.droneArrows = const [],
    this.selectedDroneArrowId,
    this.snapGuideStart,
    this.snapGuideEnd,
    this.panelTextureImage,
    this.isRenderMode = false,
    this.sectionEfficiencies = const {},
    this.activeSectionEfficiency,
  });

  final String? selectedRowId;
  final String? activeClusterId;

  @override
  void paint(Canvas canvas, Size size) {
    final centerOffset =
        Offset(size.width / 2.0 + panOffsetX, size.height / 2.0 + panOffsetY);

    // ── 1. RENDERIZAÇÃO DAS SEÇÕES INATIVAS ─────────────────────────────────
    for (int s = 0; s < sections.length; s++) {
      if (s == activeSectionIndex) continue;
      final sec = sections[s];

      // Polígono da seção inativa (se existir)
      if (sec.vertices.isNotEmpty && isEditingActiveSection) {
        final screenVerts = sec.vertices.map((p) {
          final pxX = RoofGeometryService.metersToPixels(p.x, metersPerPixel);
          final pxY = RoofGeometryService.metersToPixels(p.y, metersPerPixel);
          return Offset(centerOffset.dx + pxX, centerOffset.dy + pxY);
        }).toList();

        final path = Path();
        path.moveTo(screenVerts.first.dx, screenVerts.first.dy);
        for (int i = 1; i < screenVerts.length; i++) {
          path.lineTo(screenVerts[i].dx, screenVerts[i].dy);
        }

        if (sec.isClosed) {
          path.close();
          final fillPaint = Paint()
            ..color = sec.themeColor.withValues(alpha: 0.12)
            ..style = PaintingStyle.fill;
          canvas.drawPath(path, fillPaint);
        }

        final borderPaint = Paint()
          ..color = sec.themeColor.withValues(alpha: 0.50)
          ..strokeWidth = 1.8
          ..style = PaintingStyle.stroke;
        canvas.drawPath(path, borderPaint);
      }

      // Módulos da seção inativa (SEMPRE RENDERIZA, mesmo que a água tenha sido criada sem polígono de arestas!)
      for (final mod in sec.modules) {
        if (mod.isExcluded) continue;
        final corners = mod.getCorners();
        final sCorners = corners.map((p) {
          final pxX = RoofGeometryService.metersToPixels(p.x, metersPerPixel);
          final pxY = RoofGeometryService.metersToPixels(p.y, metersPerPixel);
          return Offset(centerOffset.dx + pxX, centerOffset.dy + pxY);
        }).toList();

        final mPath = Path();
        mPath.moveTo(sCorners.first.dx, sCorners.first.dy);
        for (int i = 1; i < sCorners.length; i++) {
          mPath.lineTo(sCorners[i].dx, sCorners[i].dy);
        }
        mPath.close();

        final secEff = sectionEfficiencies[sec.id];
        _drawModuleFace(
          canvas: canvas,
          mod: mod,
          centerOffset: centerOffset,
          modPath: mPath,
          fallbackFillPaint: Paint()
            ..color = const Color(0xFF1E3A8A).withValues(alpha: 0.90)
            ..style = PaintingStyle.fill,
          opacity: 0.85,
          efficiency: secEff,
        );

        final fPaint = Paint()
          ..color = Colors.white38
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke;
        canvas.drawPath(mPath, fPaint);

        if (panelTextureImage == null && sCorners.length >= 4) {
          final mid1 = Offset(
            (sCorners[0].dx + sCorners[1].dx) / 2,
            (sCorners[0].dy + sCorners[1].dy) / 2,
          );
          final mid2 = Offset(
            (sCorners[2].dx + sCorners[3].dx) / 2,
            (sCorners[2].dy + sCorners[3].dy) / 2,
          );
          final busbarPaint = Paint()
            ..color = Colors.white24
            ..strokeWidth = 0.8;
          canvas.drawLine(mid1, mid2, busbarPaint);
        }
      }
    }

    // ── 2. QUANDO NENHUMA ÁGUA ESTÁ EM EDIÇÃO (MODO REPOUSO / APRESENTAÇÃO) ─
    if (!isEditingActiveSection &&
        (isClosed || vertices.isEmpty) &&
        toolMode != DesignerToolMode.drawRoof &&
        modules.isNotEmpty) {
      // Renderiza exclusivamente as placas solares limpas da seção ativa (sem polígonos)
      for (final mod in modules) {
        if (mod.isExcluded) continue;

        final corners = mod.getCorners();
        final sCorners = corners.map((p) {
          final pxX = RoofGeometryService.metersToPixels(p.x, metersPerPixel);
          final pxY = RoofGeometryService.metersToPixels(p.y, metersPerPixel);
          return Offset(centerOffset.dx + pxX, centerOffset.dy + pxY);
        }).toList();

        final mPath = Path();
        mPath.moveTo(sCorners.first.dx, sCorners.first.dy);
        for (int i = 1; i < sCorners.length; i++) {
          mPath.lineTo(sCorners[i].dx, sCorners[i].dy);
        }
        mPath.close();

        final activeSecId = activeSectionIndex < sections.length
            ? sections[activeSectionIndex].id
            : 'active';
        final eff = sectionEfficiencies[activeSecId] ?? activeSectionEfficiency;
        _drawModuleFace(
          canvas: canvas,
          mod: mod,
          centerOffset: centerOffset,
          modPath: mPath,
          fallbackFillPaint: Paint()
            ..color = const Color(0xFF1E3A8A)
            ..style = PaintingStyle.fill,
          efficiency: eff,
        );

        final fPaint = Paint()
          ..color = const Color(0xFFE2E8F0)
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke;
        canvas.drawPath(mPath, fPaint);

        if (panelTextureImage == null && sCorners.length >= 4) {
          final mid1 = Offset(
            (sCorners[0].dx + sCorners[1].dx) / 2,
            (sCorners[0].dy + sCorners[1].dy) / 2,
          );
          final mid2 = Offset(
            (sCorners[2].dx + sCorners[3].dx) / 2,
            (sCorners[2].dy + sCorners[3].dy) / 2,
          );
          final busbarPaint = Paint()
            ..color = Colors.white24
            ..strokeWidth = 0.8;
          canvas.drawLine(mid1, mid2, busbarPaint);
        }
      }
      // Não damos return antecipado aqui: prossegue para desenhar as setas de indicação de quedas (droneArrows) e o norte (compass)!
    } else if (isEditingActiveSection) {
      // ── 3. RENDERIZAÇÃO DA SEÇÃO ATIVA EM EDIÇÃO COMPLETA ───────────────────
      if (vertices.isNotEmpty) {
      final path = Path();
      final screenVertices = vertices.map((p) {
        final pxX = RoofGeometryService.metersToPixels(p.x, metersPerPixel);
        final pxY = RoofGeometryService.metersToPixels(p.y, metersPerPixel);
        return Offset(centerOffset.dx + pxX, centerOffset.dy + pxY);
      }).toList();

      path.moveTo(screenVertices.first.dx, screenVertices.first.dy);
      for (int i = 1; i < screenVertices.length; i++) {
        path.lineTo(screenVertices[i].dx, screenVertices[i].dy);
      }

      if (isClosed) {
        path.close();

        final fillPaint = Paint()
          ..color = const Color(0xFFF59E0B).withValues(alpha: 0.20)
          ..style = PaintingStyle.fill;
        canvas.drawPath(path, fillPaint);
      }

      // Linhas de borda da água ativa
      final borderPaint = Paint()
        ..color = const Color(0xFFF59E0B)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;
      canvas.drawPath(path, borderPaint);

      // Cotas métricas posicionadas do lado de FORA do polígono e afastadas das placas solares
      final edgeCount = isClosed ? vertices.length : vertices.length - 1;

      // Calcula o centro do polígono para garantir que o vetor aponte sempre para FORA
      double polySumX = 0, polySumY = 0;
      for (final sv in screenVertices) {
        polySumX += sv.dx;
        polySumY += sv.dy;
      }
      final polyCenter = Offset(
          polySumX / screenVertices.length, polySumY / screenVertices.length);

      for (int i = 0; i < edgeCount; i++) {
        final p1 = vertices[i];
        final p2 = vertices[(i + 1) % vertices.length];
        final sp1 = screenVertices[i];
        final sp2 = screenVertices[(i + 1) % vertices.length];

        final distMeters = p1.distanceTo(p2);
        final mid = Offset((sp1.dx + sp2.dx) / 2, (sp1.dy + sp2.dy) / 2);

        // Vetor da aresta
        final edgeVec = sp2 - sp1;
        final edgeLen = edgeVec.distance;
        Offset badgePos = mid;

        if (edgeLen > 0) {
          // Candidato de normal perpendicular
          Offset norm = Offset(-edgeVec.dy, edgeVec.dx) / edgeLen;

          // Garante que a normal aponte para FORA do polígono (longe do centróide)
          final dotWithOutward = (mid.dx + norm.dx * 10 - polyCenter.dx) *
                  (mid.dx - polyCenter.dx) +
              (mid.dy + norm.dy * 10 - polyCenter.dy) *
                  (mid.dy - polyCenter.dy);
          final dotCenter =
              (mid.dx - polyCenter.dx) * (mid.dx - polyCenter.dx) +
                  (mid.dy - polyCenter.dy) * (mid.dy - polyCenter.dy);

          if (dotWithOutward < dotCenter) {
            norm = -norm; // inverte para apontar para fora
          }

          // Afasta generosamente 38px para fora do polígono, garantindo limpeza visual total
          badgePos = mid + norm * 38.0;
        }

        _drawMetricLabel(canvas, badgePos, '${distMeters.toStringAsFixed(1)}m');
      }

      // Vértices do telhado ativo (bolinhas interativas de arraste)
      for (int i = 0; i < screenVertices.length; i++) {
        final v = screenVertices[i];
        final isDragging = i == draggingIndex;
        final isHovered = i == hoveredVertexIndex;

        final radius = isDragging ? 9.5 : (isHovered ? 8.5 : 6.0);

        final vertexPaint = Paint()
          ..color = isDragging
              ? const Color(0xFF10B981)
              : (isHovered ? const Color(0xFF38BDF8) : Colors.white)
          ..style = PaintingStyle.fill;

        final vertexBorder = Paint()
          ..color = isDragging
              ? Colors.white
              : (isHovered ? Colors.white : const Color(0xFFF59E0B))
          ..strokeWidth = (isDragging || isHovered) ? 3.0 : 2.0
          ..style = PaintingStyle.stroke;

        canvas.drawCircle(v, radius, vertexPaint);
        canvas.drawCircle(v, radius, vertexBorder);
      }
    }

    // ── 4. RENDERIZAÇÃO DAS PLACAS SOLARES DA ÁGUA ATIVA EM EDIÇÃO ──────────
    for (int modIdx = 0; modIdx < modules.length; modIdx++) {
      final mod = modules[modIdx];
      final isBeingDragged = modIdx == draggingModuleIndex;
      final isSelected = modIdx == selectedModuleIndex;

      final corners = mod.getCorners();
      final screenCorners = corners.map((p) {
        final pxX = RoofGeometryService.metersToPixels(p.x, metersPerPixel);
        final pxY = RoofGeometryService.metersToPixels(p.y, metersPerPixel);
        return Offset(centerOffset.dx + pxX, centerOffset.dy + pxY);
      }).toList();

      final modPath = Path();
      modPath.moveTo(screenCorners.first.dx, screenCorners.first.dy);
      for (int i = 1; i < screenCorners.length; i++) {
        modPath.lineTo(screenCorners[i].dx, screenCorners[i].dy);
      }
      modPath.close();

      if (mod.isExcluded) {
        final excludedPaint = Paint()
          ..color = const Color(0xFFEF4444).withValues(alpha: 0.35)
          ..style = PaintingStyle.fill;
        canvas.drawPath(modPath, excludedPaint);

        final excludedBorder = Paint()
          ..color = const Color(0xFFEF4444)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;
        canvas.drawPath(modPath, excludedBorder);
      } else {
        final activeSecId = activeSectionIndex < sections.length
            ? sections[activeSectionIndex].id
            : 'active';
        final eff = sectionEfficiencies[activeSecId] ?? activeSectionEfficiency;
        _drawModuleFace(
          canvas: canvas,
          mod: mod,
          centerOffset: centerOffset,
          modPath: modPath,
          fallbackFillPaint: Paint()
            ..color = isBeingDragged
                ? const Color(0xFF2563EB)
                : const Color(0xFF1E3A8A)
            ..style = PaintingStyle.fill,
          isDragging: isBeingDragged,
          efficiency: eff,
        );

        final bool isClusterActive =
            activeClusterId == null || mod.rowId == activeClusterId;

        Color borderColor = isClusterActive
            ? const Color(0xFFE2E8F0)
            : const Color(0xFF64748B);
        double borderWidth = isClusterActive ? 1.2 : 0.9;

        final bool isRowSelected =
            selectedRowId != null && mod.rowId == selectedRowId;
        final bool isSnapped =
            snappedModuleIndex != null && modIdx == snappedModuleIndex;

        if (isSnapped) {
          borderColor = const Color(0xFF10B981);
          borderWidth = 3.2;
        } else if (isSelected) {
          borderColor = const Color(0xFF38BDF8);
          borderWidth = 2.5;
        } else if (isRowSelected) {
          borderColor = const Color(0xFF38BDF8);
          borderWidth = 2.0;
        } else if (isBeingDragged) {
          borderColor = const Color(0xFF10B981);
          borderWidth = 2.5;
        } else if (isClusterActive && activeClusterId != null) {
          borderColor = const Color(0xFF93C5FD);
          borderWidth = 1.4;
        }

        final framePaint = Paint()
          ..color = borderColor
          ..strokeWidth = borderWidth
          ..style = PaintingStyle.stroke;
        canvas.drawPath(modPath, framePaint);

        if (panelTextureImage == null && screenCorners.length >= 4) {
          final mid1 = Offset(
            (screenCorners[0].dx + screenCorners[1].dx) / 2,
            (screenCorners[0].dy + screenCorners[1].dy) / 2,
          );
          final mid2 = Offset(
            (screenCorners[2].dx + screenCorners[3].dx) / 2,
            (screenCorners[2].dy + screenCorners[3].dy) / 2,
          );
          final busbarPaint = Paint()
            ..color = Colors.white24
            ..strokeWidth = 0.8;
          canvas.drawLine(mid1, mid2, busbarPaint);
        }
      }
    }
  }

    // ── 5. LINHA GUIA DE SNAP / AUTO-ALINHAMENTO MAGNÉTICO ──────────────────
    if (snapGuideStart != null && snapGuideEnd != null) {
      _drawSnapGuide(canvas, centerOffset, snapGuideStart!, snapGuideEnd!);
    }

    // ── 6. SETAS DE INDICAÇÃO DE QUEDAS (DRONE) ─────────────────────────────
    for (final arrow in droneArrows) {
      _drawRoofArrow(
        canvas: canvas,
        centerOffset: centerOffset,
        arrow: arrow,
        isSelected: arrow.id == selectedDroneArrowId,
      );
    }

    // ── 7. NORTE MÓVEL ROTACIONÁVEL DO DRONE ─────────────────────────────────
    if (droneNorthCompass != null) {
      _drawDroneNorthCompass(
        canvas: canvas,
        centerOffset: centerOffset,
        compass: droneNorthCompass!,
      );
    }
  }

  /// Desenha a face fotorrealista da placa solar com a imagem do usuário ou fallback suave
  void _drawModuleFace({
    required Canvas canvas,
    required PlacedModule mod,
    required Offset centerOffset,
    required Path modPath,
    required Paint fallbackFillPaint,
    bool isDragging = false,
    double opacity = 1.0,
    SolarOrientationEfficiency? efficiency,
  }) {
    final centerScreen = Offset(
      centerOffset.dx +
          RoofGeometryService.metersToPixels(mod.center.x, metersPerPixel),
      centerOffset.dy +
          RoofGeometryService.metersToPixels(mod.center.y, metersPerPixel),
    );
    final wPx =
        RoofGeometryService.metersToPixels(mod.widthMeters, metersPerPixel);
    final hPx =
        RoofGeometryService.metersToPixels(mod.heightMeters, metersPerPixel);

    if (panelTextureImage != null) {
      canvas.save();
      canvas.translate(centerScreen.dx, centerScreen.dy);
      canvas.rotate(mod.rotationRadians);

      // A foto original está em orientação paisagem (horizontal).
      // Se o módulo for vertical (retrato, heightMeters > widthMeters), rotacionamos 90°
      final bool isPortrait = mod.heightMeters > mod.widthMeters;
      if (isPortrait) {
        canvas.rotate(math.pi / 2);
      }

      final dstWidth = isPortrait ? hPx : wPx;
      final dstHeight = isPortrait ? wPx : hPx;
      final dstRect = Rect.fromCenter(
        center: Offset.zero,
        width: dstWidth,
        height: dstHeight,
      );

      final srcRect = Rect.fromLTWH(
        0,
        0,
        panelTextureImage!.width.toDouble(),
        panelTextureImage!.height.toDouble(),
      );

      final imgPaint = Paint()
        ..filterQuality = FilterQuality.medium
        ..isAntiAlias = true;

      if (isDragging) {
        imgPaint.color = const Color(0xFF60A5FA).withValues(alpha: 0.9);
      } else if (opacity < 1.0) {
        imgPaint.color = Color.fromRGBO(255, 255, 255, opacity);
      }

      canvas.drawImageRect(panelTextureImage!, srcRect, dstRect, imgPaint);
      canvas.restore();
    } else {
      canvas.drawPath(modPath, fallbackFillPaint);
    }

    // Se NÃO for modo renderizar e houver qualificação solar calculada:
    if (!isRenderMode && efficiency != null && !isDragging) {
      // 1. Aplica o filtro translúcido colorido da qualificação sobre a placa
      final filterPaint = Paint()
        ..color = efficiency.overlayColor
        ..style = PaintingStyle.fill;
      canvas.drawPath(modPath, filterPaint);

      // 2. Desenha a porcentagem de eficiência centralizada no módulo
      final minDim = math.min(wPx, hPx);
      if (minDim >= 8.0) {
        final fontSize = (minDim * 0.38).clamp(8.0, 16.0);
        final textSpan = TextSpan(
          text: '${efficiency.percentage}%',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            shadows: [
              const Shadow(
                color: Colors.black87,
                blurRadius: 3.0,
                offset: Offset(0, 1),
              ),
            ],
          ),
        );
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        )..layout();

        textPainter.paint(
          canvas,
          centerScreen - Offset(textPainter.width / 2, textPainter.height / 2),
        );
      }
    }
  }

  /// Desenha a linha pontilhada de auto-alinhamento magnético
  void _drawSnapGuide(Canvas canvas, Offset centerOffset, Offset p1Meters,
      Offset p2Meters) {
    final p1 = Offset(
      centerOffset.dx +
          RoofGeometryService.metersToPixels(p1Meters.dx, metersPerPixel),
      centerOffset.dy +
          RoofGeometryService.metersToPixels(p1Meters.dy, metersPerPixel),
    );
    final p2 = Offset(
      centerOffset.dx +
          RoofGeometryService.metersToPixels(p2Meters.dx, metersPerPixel),
      centerOffset.dy +
          RoofGeometryService.metersToPixels(p2Meters.dy, metersPerPixel),
    );

    final guidePaint = Paint()
      ..color = const Color(0xFF10B981)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;

    final diff = p2 - p1;
    final dist = diff.distance;
    if (dist > 0) {
      const dashLen = 7.0;
      const spaceLen = 5.0;
      final dir = diff / dist;
      double current = 0.0;
      while (current < dist) {
        final start = p1 + dir * current;
        final end = p1 + dir * math.min(current + dashLen, dist);
        canvas.drawLine(start, end, guidePaint);
        current += dashLen + spaceLen;
      }
    }

    final dotPaint = Paint()
      ..color = const Color(0xFF10B981)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(p1, 4.0, dotPaint);
    canvas.drawCircle(p2, 4.0, dotPaint);
  }

  /// Constrói o caminho arredondado do ponteiro delta 3D moderno (estilo cursor / navegação)
  Path _buildDeltaPointerPath({
    required Offset center,
    required Offset dir,
    required Offset norm,
    required double length,
    required double width,
    double cornerRadius = 4.0,
  }) {
    final pTip = center + dir * (length * 0.50);
    final pRight = center - dir * (length * 0.42) + norm * (width * 0.50);
    final pNotch = center - dir * (length * 0.12);
    final pLeft = center - dir * (length * 0.42) - norm * (width * 0.50);

    final pts = [pTip, pRight, pNotch, pLeft];
    final path = Path();

    for (int i = 0; i < 4; i++) {
      final prev = pts[(i - 1 + 4) % 4];
      final curr = pts[i];
      final next = pts[(i + 1) % 4];

      final inVec = (curr - prev);
      final outVec = (next - curr);
      final inLen = inVec.distance;
      final outLen = outVec.distance;

      final r = cornerRadius.clamp(1.0, math.min(inLen, outLen) * 0.35);

      final inDir = inVec / inLen;
      final outDir = outVec / outLen;

      final pStart = curr - inDir * r;
      final pEnd = curr + outDir * r;

      if (i == 0) {
        path.moveTo(pStart.dx, pStart.dy);
      } else {
        path.lineTo(pStart.dx, pStart.dy);
      }
      path.quadraticBezierTo(curr.dx, curr.dy, pEnd.dx, pEnd.dy);
    }

    path.close();
    return path;
  }

  /// Desenha a seta de indicação de queda de telhado moderna em vetor 3D com degradê
  void _drawRoofArrow({
    required Canvas canvas,
    required Offset centerOffset,
    required DroneRoofArrow arrow,
    required bool isSelected,
  }) {
    final centerPx = Offset(
      centerOffset.dx +
          RoofGeometryService.metersToPixels(arrow.center.x, metersPerPixel),
      centerOffset.dy +
          RoofGeometryService.metersToPixels(arrow.center.y, metersPerPixel),
    );
    final lenPx = RoofGeometryService.metersToPixels(
            arrow.lengthMeters, metersPerPixel)
        .clamp(26.0, 75.0);
    final widthPx = lenPx * 0.88;

    final dir = Offset(
        math.cos(arrow.rotationRadians), math.sin(arrow.rotationRadians));
    final norm = Offset(-dir.dy, dir.dx);

    // Cores em degradê com base na cor da seta (suporta qualquer cor escolhida no painel)
    final hsl = HSLColor.fromColor(arrow.color);
    final baseHsl = hsl.lightness < 0.25 ? hsl.withLightness(0.50) : hsl;

    final lightColor = baseHsl
        .withLightness((baseHsl.lightness * 1.30).clamp(0.0, 0.95))
        .toColor();
    final midColor = baseHsl.toColor();
    final darkColor = baseHsl
        .withLightness((baseHsl.lightness * 0.70).clamp(0.0, 1.0))
        .toColor();
    final bevelColor = baseHsl
        .withLightness((baseHsl.lightness * 0.42).clamp(0.0, 1.0))
        .toColor();

    final cornerRad = (lenPx * 0.09).clamp(2.5, 6.0);

    // 1. Caminho da face superior
    final topPath = _buildDeltaPointerPath(
      center: centerPx,
      dir: dir,
      norm: norm,
      length: lenPx,
      width: widthPx,
      cornerRadius: cornerRad,
    );

    // 2. Extrusão 3D para baixo/direita dando o relevo da imagem
    const depthOffset = Offset(1.5, 3.8);
    final bevelPath = _buildDeltaPointerPath(
      center: centerPx + depthOffset,
      dir: dir,
      norm: norm,
      length: lenPx,
      width: widthPx,
      cornerRadius: cornerRad,
    );

    // 3. Glow de seleção em volta de toda a seta
    if (isSelected) {
      final glowPaint = Paint()
        ..color = const Color(0xFF38BDF8).withValues(alpha: 0.50)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0)
        ..style = PaintingStyle.fill;
      canvas.drawPath(bevelPath, glowPaint);
      canvas.drawPath(topPath, glowPaint);
    }

    // 4. Sombra suave ambiente
    canvas.drawShadow(
        bevelPath, Colors.black.withValues(alpha: 0.60), 4.5, true);

    // 5. Camada 3D de relevo lateral/inferior
    final bevelPaint = Paint()
      ..color = bevelColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(bevelPath, bevelPaint);

    // 6. Face superior com degradê suave e moderno
    final tipPos = centerPx + dir * (lenPx * 0.50);
    final notchPos = centerPx - dir * (lenPx * 0.12);

    final gradientPaint = Paint()
      ..shader = ui.Gradient.linear(
        tipPos,
        notchPos,
        [lightColor, midColor, darkColor],
        [0.0, 0.48, 1.0],
      )
      ..style = PaintingStyle.fill;
    canvas.drawPath(topPath, gradientPaint);

    // 7. Borda de brilho especular fino na face superior
    final specularPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.38)
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke;
    canvas.drawPath(topPath, specularPaint);

    // 8. Contorno externo sutil para contraste nítido em qualquer telhado
    final borderPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawPath(bevelPath, borderPaint);

    // 9. Alça de rotação interativa (na ponta da seta) quando selecionada
    if (isSelected) {
      final rotHandlePos = tipPos + dir * 14.0;
      final dashedLinePaint = Paint()
        ..color = const Color(0xFF38BDF8)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;
      canvas.drawLine(tipPos, rotHandlePos, dashedLinePaint);

      final handlePaint = Paint()
        ..color = const Color(0xFF0F172A)
        ..style = PaintingStyle.fill;
      final handleBorder = Paint()
        ..color = const Color(0xFF38BDF8)
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(rotHandlePos, 6.5, handlePaint);
      canvas.drawCircle(rotHandlePos, 6.5, handleBorder);

      final iconPaint = Paint()
        ..color = const Color(0xFF38BDF8)
        ..strokeWidth = 1.4
        ..style = PaintingStyle.stroke;
      canvas.drawArc(
        Rect.fromCircle(center: rotHandlePos, radius: 3.2),
        -math.pi / 2,
        math.pi * 1.5,
        false,
        iconPaint,
      );

      // Nó de arraste no centro
      final centerDragPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(centerPx, 2.5, centerDragPaint);
      canvas.drawCircle(
          centerPx,
          2.5,
          Paint()
            ..color = Colors.black87
            ..strokeWidth = 1.2
            ..style = PaintingStyle.stroke);
    }
  }

  /// Desenha a rosa dos ventos / bússola do norte para fotos de drone
  void _drawDroneNorthCompass({
    required Canvas canvas,
    required Offset centerOffset,
    required DroneNorthCompass compass,
  }) {
    final centerPx = Offset(
      centerOffset.dx +
          RoofGeometryService.metersToPixels(
              compass.center.x, metersPerPixel),
      centerOffset.dy +
          RoofGeometryService.metersToPixels(
              compass.center.y, metersPerPixel),
    );
    final radius = RoofGeometryService.metersToPixels(
            compass.sizeMeters / 2, metersPerPixel)
        .clamp(28.0, 70.0);

    // Disco de base escuro translúcido
    final diskPaint = Paint()
      ..color = const Color(0xFF0F172A).withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;
    final diskBorder = Paint()
      ..color = const Color(0xFF38BDF8)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(centerPx, radius, diskPaint);
    canvas.drawCircle(centerPx, radius, diskBorder);

    // Anel interno sutil
    canvas.drawCircle(
      centerPx,
      radius * 0.75,
      Paint()
        ..color = Colors.white12
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke,
    );

    // Agulha do Norte
    final dir = Offset(math.sin(compass.rotationRadians),
        -math.cos(compass.rotationRadians));
    final norm = Offset(-dir.dy, dir.dx);

    final needleLength = radius * 0.78;
    final needleWidth = radius * 0.24;

    final northTip = centerPx + dir * needleLength;
    final southTip = centerPx - dir * needleLength;
    final rightWing = centerPx + norm * needleWidth;
    final leftWing = centerPx - norm * needleWidth;

    // Triângulo Norte (Vermelho)
    final northPath = Path()
      ..moveTo(centerPx.dx, centerPx.dy)
      ..lineTo(rightWing.dx, rightWing.dy)
      ..lineTo(northTip.dx, northTip.dy)
      ..lineTo(leftWing.dx, leftWing.dy)
      ..close();
    canvas.drawPath(northPath, Paint()..color = const Color(0xFFEF4444));
    canvas.drawPath(
        northPath,
        Paint()
          ..color = Colors.white
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke);

    // Triângulo Sul (Branco/Cinza)
    final southPath = Path()
      ..moveTo(centerPx.dx, centerPx.dy)
      ..lineTo(rightWing.dx, rightWing.dy)
      ..lineTo(southTip.dx, southTip.dy)
      ..lineTo(leftWing.dx, leftWing.dy)
      ..close();
    canvas.drawPath(southPath, Paint()..color = const Color(0xFFCBD5E1));
    canvas.drawPath(
        southPath,
        Paint()
          ..color = Colors.black38
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke);

    // Pino central
    canvas.drawCircle(
        centerPx, 4.0, Paint()..color = const Color(0xFF0F172A));
    canvas.drawCircle(
        centerPx,
        4.0,
        Paint()
          ..color = Colors.white
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke);

    // Alça de rotação do Norte (fora do disco)
    final rotHandlePos = centerPx + dir * (radius + 16.0);
    final handlePaint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.fill;
    final handleBorder = Paint()
      ..color = const Color(0xFFEF4444)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
        northTip,
        rotHandlePos,
        Paint()
          ..color = const Color(0xFFEF4444)
          ..strokeWidth = 1.5);
    canvas.drawCircle(rotHandlePos, 8.0, handlePaint);
    canvas.drawCircle(rotHandlePos, 8.0, handleBorder);
    canvas.drawCircle(
        rotHandlePos, 3.0, Paint()..color = const Color(0xFFEF4444));

    // Cardeais (N, S, L, O)
    if (compass.showCardinals) {
      void drawCardinalText(String text, Offset pos, Color color) {
        final tp = TextPainter(
          text: TextSpan(
            text: text,
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        tp.layout();
        tp.paint(
            canvas, Offset(pos.dx - tp.width / 2, pos.dy - tp.height / 2));
      }

      final labelDist = radius * 0.86;
      drawCardinalText(
          'N', centerPx + dir * labelDist, const Color(0xFFEF4444));
      drawCardinalText('S', centerPx - dir * labelDist, Colors.white70);
      drawCardinalText('L', centerPx + norm * labelDist, Colors.white70);
      drawCardinalText('O', centerPx - norm * labelDist, Colors.white70);
    }
  }

  /// Desenha uma caixinha com a cota métrica clicável sobre a linha
  void _drawMetricLabel(Canvas canvas, Offset position, String text) {
    final span = TextSpan(
      text: '$text ✎',
      style: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF0F172A),
      ),
    );
    final tp = TextPainter(text: span, textDirection: TextDirection.ltr);
    tp.layout();

    final bgRect = Rect.fromCenter(
      center: position,
      width: tp.width + 12,
      height: tp.height + 6,
    );

    final rrect = RRect.fromRectAndRadius(bgRect, const Radius.circular(6));
    final bgPaint = Paint()..color = const Color(0xFFFEF3C7);
    final borderPaint = Paint()
      ..color = const Color(0xFFD97706)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    canvas.drawRRect(rrect, bgPaint);
    canvas.drawRRect(rrect, borderPaint);

    tp.paint(canvas,
        Offset(position.dx - tp.width / 2, position.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _RoofOverlayPainter oldDelegate) => true;
}
