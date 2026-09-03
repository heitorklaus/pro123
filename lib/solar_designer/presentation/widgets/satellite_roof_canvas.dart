import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/services/roof_geometry_service.dart';
import '../../data/services/satellite_map_service.dart';
import '../../domain/models/solar_designer_models.dart';

/// Modos de interação do usuário no Canvas
enum DesignerToolMode {
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
  final ValueChanged<Offset>? onCanvasTap;
  final ValueChanged<Offset>? onCanvasDoubleTap;
  final Function(Offset delta)? onPanUpdate;
  final ValueChanged<Offset>? onZoomIn;
  final ValueChanged<Offset>? onZoomOut;
  final ValueChanged<int>? onEdgeTap;
  final Function(int vertexIndex, RoofPoint newPointMeters)? onVertexMoved;
  final Function(double dxMeters, double dyMeters)? onModuleGroupMoved;
  final Function(int index, double dxMeters, double dyMeters)? onModuleMoved;
  final Function(double deltaRadians)? onRotateModuleGroup;
  final Function(int index, double deltaRadians)? onRotateSingleModule;
  final Function(int index)? onRotateSingleModule90;
  final Function(int index)? onDeleteSingleModule;
  final VoidCallback? onRotate90;
  final VoidCallback? onOpenAngleDialog;
  final VoidCallback? onAddModule;
  final VoidCallback? onRemoveModule;
  final VoidCallback? onAddRow;
  final ValueChanged<String>? onDeleteRow;
  final ValueChanged<int>? onSectionSelected;
  final ValueChanged<int>? onDeleteSection;
  final VoidCallback? onFinishCurrentSection;
  final VoidCallback? onResumeEditing;
  final VoidCallback? onAddNewSection;
  final double groupRotationDegrees;
  final double metersPerPixel;

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
    this.onCanvasTap,
    this.onCanvasDoubleTap,
    this.onPanUpdate,
    this.onZoomIn,
    this.onZoomOut,
    this.onEdgeTap,
    this.onVertexMoved,
    this.onModuleGroupMoved,
    this.onModuleMoved,
    this.onRotateModuleGroup,
    this.onRotateSingleModule,
    this.onRotateSingleModule90,
    this.onDeleteSingleModule,
    this.onRotate90,
    this.onOpenAngleDialog,
    this.onAddModule,
    this.onRemoveModule,
    this.onAddRow,
    this.onDeleteRow,
    this.onSectionSelected,
    this.onDeleteSection,
    this.onFinishCurrentSection,
    this.onResumeEditing,
    this.onAddNewSection,
    this.groupRotationDegrees = 0.0,
    required this.metersPerPixel,
  });

  @override
  State<SatelliteRoofCanvas> createState() => _SatelliteRoofCanvasState();
}

class _SatelliteRoofCanvasState extends State<SatelliteRoofCanvas> {
  int _draggingVertexIndex = -1;
  int _draggingModuleIndex = -1;
  int _selectedModuleIndex = -1;
  bool _isDraggingModuleGroup = false;
  bool _isRotatingGroup = false;
  Offset? _rotationPivotScreen;
  double _lastDragAngle = 0.0;

  /// Calcula a caixa delimitadora (bounding box) de todas as placas da seção ativa
  Rect? _getModulesBoundingBox(Offset centerOffset) {
    if (widget.modules.isEmpty) return null;
    double minX = double.infinity, maxX = -double.infinity;
    double minY = double.infinity, maxY = -double.infinity;

    for (final m in widget.modules) {
      for (final p in m.getCorners()) {
        final px = centerOffset.dx + RoofGeometryService.metersToPixels(p.x, widget.metersPerPixel);
        final py = centerOffset.dy + RoofGeometryService.metersToPixels(p.y, widget.metersPerPixel);
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
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (details) {
                final localPos = details.localPosition;

                // Se a seção ativa estiver concluída (em modo repouso), não inicia edição por pan
                if (!widget.isEditingActiveSection) {
                  return;
                }

                // 1. Se estiver desenhando telhado, testa se pegou um vértice da água ativa
                if (widget.toolMode == DesignerToolMode.drawRoof && widget.roofVertices.isNotEmpty) {
                  for (int i = 0; i < widget.roofVertices.length; i++) {
                    final p = widget.roofVertices[i];
                    final pxX = RoofGeometryService.metersToPixels(p.x, widget.metersPerPixel);
                    final pxY = RoofGeometryService.metersToPixels(p.y, widget.metersPerPixel);
                    final screenPos = Offset(centerOffset.dx + pxX, centerOffset.dy + pxY);

                    if ((localPos - screenPos).distance <= 22.0) {
                      setState(() => _draggingVertexIndex = i);
                      return;
                    }
                  }
                }

                // 2. Se houver módulos na água ativa e clicar sobre eles
                if (widget.modules.isNotEmpty) {
                  // 2.1 Testa se clicou na alça de rotação de grupo (topo do bbox)
                  if (modulesBbox != null) {
                    final rotHandlePos = Offset(modulesBbox.center.dx, modulesBbox.top - 24);
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

                  final dxM = RoofGeometryService.pixelsToMeters(localPos.dx - centerOffset.dx, widget.metersPerPixel);
                  final dyM = RoofGeometryService.pixelsToMeters(localPos.dy - centerOffset.dy, widget.metersPerPixel);
                  final clickPointMeters = RoofPoint(dxM, dyM);

                  // Testa se clicou em um módulo individual
                  for (int i = widget.modules.length - 1; i >= 0; i--) {
                    if (widget.modules[i].containsPoint(clickPointMeters)) {
                      setState(() {
                        _draggingModuleIndex = i;
                        _selectedModuleIndex = i;
                      });
                      return;
                    }
                  }

                  // Testa se clicou perto da área do conjunto de módulos para arrastar o conjunto todo
                  if (widget.toolMode == DesignerToolMode.editModules && modulesBbox != null) {
                    if (modulesBbox.inflate(16.0).contains(localPos)) {
                      setState(() => _isDraggingModuleGroup = true);
                      return;
                    }
                  }
                }

                _draggingVertexIndex = -1;
                _draggingModuleIndex = -1;
                _isDraggingModuleGroup = false;
                _isRotatingGroup = false;
              },
              onPanUpdate: (details) {
                if (_isRotatingGroup && _rotationPivotScreen != null) {
                  // Rotaciona conjunto à mão livre
                  final currentAngle = math.atan2(
                    details.localPosition.dy - _rotationPivotScreen!.dy,
                    details.localPosition.dx - _rotationPivotScreen!.dx,
                  );
                  final deltaAngle = currentAngle - _lastDragAngle;
                  _lastDragAngle = currentAngle;
                  widget.onRotateModuleGroup?.call(deltaAngle);
                } else if (_draggingVertexIndex != -1 && _draggingVertexIndex < widget.roofVertices.length) {
                  // Move vértice do telhado da água ativa
                  final dxPixels = details.localPosition.dx - centerOffset.dx;
                  final dyPixels = details.localPosition.dy - centerOffset.dy;
                  final newPoint = RoofPoint(
                    RoofGeometryService.pixelsToMeters(dxPixels, widget.metersPerPixel),
                    RoofGeometryService.pixelsToMeters(dyPixels, widget.metersPerPixel),
                  );
                  widget.onVertexMoved?.call(_draggingVertexIndex, newPoint);
                } else if (_draggingModuleIndex != -1 && _draggingModuleIndex < widget.modules.length) {
                  // Move placa individual livremente
                  final dxM = RoofGeometryService.pixelsToMeters(details.delta.dx, widget.metersPerPixel);
                  final dyM = RoofGeometryService.pixelsToMeters(details.delta.dy, widget.metersPerPixel);
                  widget.onModuleMoved?.call(_draggingModuleIndex, dxM, dyM);
                } else if (_isDraggingModuleGroup) {
                  // Move conjunto todo de módulos
                  final dxM = RoofGeometryService.pixelsToMeters(details.delta.dx, widget.metersPerPixel);
                  final dyM = RoofGeometryService.pixelsToMeters(details.delta.dy, widget.metersPerPixel);
                  widget.onModuleGroupMoved?.call(dxM, dyM);
                } else if (widget.toolMode == DesignerToolMode.pan) {
                  widget.onPanUpdate?.call(details.delta);
                }
              },
              onPanEnd: (_) {
                setState(() {
                  _draggingVertexIndex = -1;
                  _draggingModuleIndex = -1;
                  _isDraggingModuleGroup = false;
                  _isRotatingGroup = false;
                  _rotationPivotScreen = null;
                });
              },
              onTapUp: (details) {
                final localPos = details.localPosition;
                final dxM = RoofGeometryService.pixelsToMeters(localPos.dx - centerOffset.dx, widget.metersPerPixel);
                final dyM = RoofGeometryService.pixelsToMeters(localPos.dy - centerOffset.dy, widget.metersPerPixel);
                final clickMeters = RoofPoint(dxM, dyM);

                // 1. Se a seção ativa estiver concluída e o usuário clicou nela: retoma edição!
                if (!widget.isEditingActiveSection) {
                  final activePolygon = RoofPolygon(vertices: widget.roofVertices);
                  bool hit = activePolygon.containsPoint(clickMeters) || widget.modules.any((m) => m.containsPoint(clickMeters));

                  if (!hit && widget.roofVertices.isNotEmpty) {
                    final aPoints = widget.modules.isNotEmpty
                        ? widget.modules.where((m) => !m.isExcluded).expand((m) => m.getCorners()).map((p) => Offset(
                            centerOffset.dx + RoofGeometryService.metersToPixels(p.x, widget.metersPerPixel),
                            centerOffset.dy + RoofGeometryService.metersToPixels(p.y, widget.metersPerPixel),
                          ))
                        : widget.roofVertices.map((p) => Offset(
                            centerOffset.dx + RoofGeometryService.metersToPixels(p.x, widget.metersPerPixel),
                            centerOffset.dy + RoofGeometryService.metersToPixels(p.y, widget.metersPerPixel),
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
                    final badgePos = Offset(placeRight ? aBbox.right + 26 : aBbox.left - 26, aBbox.center.dy);
                    if ((localPos - badgePos).distance <= 35.0) {
                      hit = true;
                    }
                  }

                  if (hit) {
                    widget.onResumeEditing?.call();
                    return;
                  }
                }

                // 2. Testa se clicou em uma cota métrica de aresta da água ativa (somente se em edição)
                if (widget.isEditingActiveSection && widget.roofVertices.length >= 2) {
                  final edgeCount = widget.isRoofClosed
                      ? widget.roofVertices.length
                      : (widget.roofVertices.length - 1);

                  for (int i = 0; i < edgeCount; i++) {
                    final p1 = widget.roofVertices[i];
                    final p2 = widget.roofVertices[(i + 1) % widget.roofVertices.length];

                    final sp1 = Offset(
                      centerOffset.dx + RoofGeometryService.metersToPixels(p1.x, widget.metersPerPixel),
                      centerOffset.dy + RoofGeometryService.metersToPixels(p1.y, widget.metersPerPixel),
                    );
                    final sp2 = Offset(
                      centerOffset.dx + RoofGeometryService.metersToPixels(p2.x, widget.metersPerPixel),
                      centerOffset.dy + RoofGeometryService.metersToPixels(p2.y, widget.metersPerPixel),
                    );

                    final mid = Offset((sp1.dx + sp2.dx) / 2.0, (sp1.dy + sp2.dy) / 2.0);

                    if ((localPos - mid).distance <= 30.0) {
                      widget.onEdgeTap?.call(i);
                      return;
                    }
                  }
                }

                // 3. Se clicou em uma placa da água ativa para selecioná-la
                if (widget.isEditingActiveSection && widget.modules.isNotEmpty) {
                  int clickedIdx = -1;
                  for (int i = widget.modules.length - 1; i >= 0; i--) {
                    if (widget.modules[i].containsPoint(clickMeters)) {
                      clickedIdx = i;
                      break;
                    }
                  }

                  if (clickedIdx != -1) {
                    setState(() => _selectedModuleIndex = clickedIdx);
                    return;
                  } else {
                    if (_selectedModuleIndex != -1) {
                      setState(() => _selectedModuleIndex = -1);
                    }
                  }
                }

                // 4. Testa se clicou em OUTRA seção para torná-la ativa para edição!
                if (widget.sections.isNotEmpty) {
                  for (int s = 0; s < widget.sections.length; s++) {
                    if (s == widget.activeSectionIndex) continue;
                    final sec = widget.sections[s];
                    bool hit = sec.polygon.containsPoint(clickMeters) || sec.modules.any((m) => m.containsPoint(clickMeters));

                    if (!hit && sec.vertices.isNotEmpty) {
                      final sPoints = sec.modules.isNotEmpty
                          ? sec.modules.where((m) => !m.isExcluded).expand((m) => m.getCorners()).map((p) => Offset(
                              centerOffset.dx + RoofGeometryService.metersToPixels(p.x, widget.metersPerPixel),
                              centerOffset.dy + RoofGeometryService.metersToPixels(p.y, widget.metersPerPixel),
                            ))
                          : sec.vertices.map((p) => Offset(
                              centerOffset.dx + RoofGeometryService.metersToPixels(p.x, widget.metersPerPixel),
                              centerOffset.dy + RoofGeometryService.metersToPixels(p.y, widget.metersPerPixel),
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
                      final badgePos = Offset(placeRight ? sBbox.right + 26 : sBbox.left - 26, sBbox.center.dy);
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

                // 5. Dispara tap geral do canvas
                widget.onCanvasTap?.call(localPos);
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
                        draggingModuleIndex: _draggingModuleIndex,
                        selectedModuleIndex: _selectedModuleIndex,
                        isDraggingGroup: _isDraggingModuleGroup,
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

                    // 4. Seletor de Águas / Quedas no Topo (Pills navegáveis)
                    if (widget.sections.length > 1 || (widget.sections.isNotEmpty && widget.sections.first.vertices.isNotEmpty)) ...[
                      Positioned(
                        top: 68,
                        left: 20,
                        child: _buildSectionPillsSelector(),
                      ),
                    ],

                    // 5. Barra e Controles Colados ao Conjunto de Placas (SOMENTE QUANDO EM EDIÇÃO)
                    if (widget.isEditingActiveSection && modulesBbox != null && widget.modules.isNotEmpty) ...[
                      // 5.1 Barra Superior Colada ao Conjunto (com Concluir Água)
                      Positioned(
                        left: (modulesBbox.left).clamp(16.0, canvasSize.width - 440),
                        top: (modulesBbox.top - 46).clamp(16.0, canvasSize.height - 54),
                        child: _buildGluedModuleToolbar(modulesBbox),
                      ),

                      // 5.2 Alça de Rotação à Mão Livre do Conjunto Todo
                      Positioned(
                        left: modulesBbox.center.dx - 15,
                        top: (modulesBbox.top - 82).clamp(10.0, canvasSize.height - 90),
                        child: _buildRotationHandleWidget(modulesBbox),
                      ),

                      // 5.3 Botão Rápido '+' Colado na Borda Direita do Conjunto
                      Positioned(
                        left: (modulesBbox.right + 10).clamp(8.0, canvasSize.width - 44),
                        top: (modulesBbox.top + (modulesBbox.height - 34) / 2.0).clamp(8.0, canvasSize.height - 44),
                        child: _buildAddModuleCircleButton(),
                      ),
                    ],

                    // 6. Mini Barra Flutuante da Placa Selecionada Individualmente
                    if (widget.isEditingActiveSection && _selectedModuleIndex >= 0 && _selectedModuleIndex < widget.modules.length) ...[
                      _buildSelectedModuleFloatingBar(canvasSize, centerOffset),
                    ],

                    // 7. Rosa dos Ventos Flutuante (Norte Geográfico)
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
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: isActive ? sec.themeColor.withValues(alpha: 0.25) : Colors.transparent,
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
                        color: isActive ? sec.themeColor : const Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${sec.name} (${sec.activeModuleCount} pl)',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                          color: isActive ? Colors.white : const Color(0xFF94A3B8),
                        ),
                      ),
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
                            child: const Icon(Icons.close_rounded, size: 11, color: Color(0xFFEF4444)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),

          // Botão + Nova Água no topo
          InkWell(
            onTap: widget.onAddNewSection,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.add_rounded, size: 14, color: Color(0xFF10B981)),
                  const SizedBox(width: 2),
                  Text(
                    '+ Nova Água',
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
      centerOffset.dx + RoofGeometryService.metersToPixels(mod.center.x, widget.metersPerPixel),
      centerOffset.dy + RoofGeometryService.metersToPixels(mod.center.y, widget.metersPerPixel),
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
                onTap: () => widget.onRotateSingleModule90?.call(_selectedModuleIndex),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.rotate_90_degrees_cw_rounded, size: 12, color: Color(0xFFA5B4FC)),
                      const SizedBox(width: 3),
                      Text('90°', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
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
                  widget.onRotateSingleModule?.call(_selectedModuleIndex, deltaAngle);
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.sync_rounded, size: 12, color: Color(0xFF10B981)),
                        const SizedBox(width: 2),
                        Text(
                          '${((mod.rotationRadians * 180 / math.pi) % 360).round()}°',
                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
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
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.6)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.table_rows_rounded, size: 12, color: Color(0xFFFCA5A5)),
                        const SizedBox(width: 2),
                        const Icon(Icons.close_rounded, size: 12, color: Color(0xFFEF4444)),
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
                  child: const Icon(Icons.delete_outline_rounded, size: 14, color: Color(0xFFEF4444)),
                ),
              ),
            ),
            const SizedBox(width: 4),

            // Botão Fechar Seleção
            InkWell(
              onTap: () => setState(() => _selectedModuleIndex = -1),
              borderRadius: BorderRadius.circular(10),
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(Icons.close_rounded, size: 14, color: Color(0xFF94A3B8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Barra de ferramentas colada diretamente ao conjunto de módulos
  Widget _buildGluedModuleToolbar(Rect bbox) {
    final activeModules = widget.modules.where((m) => !m.isExcluded).length;
    final normalizedAngle = ((widget.groupRotationDegrees % 360 + 360) % 360).toStringAsFixed(0);
    final currentSecName = widget.sections.isNotEmpty && widget.activeSectionIndex < widget.sections.length
        ? widget.sections[widget.activeSectionIndex].name
        : 'Água Atual';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFF59E0B), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Tag do Nome da Água Ativa
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.roofing_rounded, size: 12, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      currentSecName,
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),

              // Botão + Linha (Adiciona nova fileira de placas no plano 2D)
              Tooltip(
                message: 'Adicionar nova fileira de placas ao conjunto (Acima, Abaixo, Direita ou Esquerda)',
                child: InkWell(
                  onTap: widget.onAddRow,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.6)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.table_rows_rounded, size: 13, color: Color(0xFF38BDF8)),
                        const SizedBox(width: 4),
                        Text(
                          '+ Linha',
                          style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),

          // Botão Rotação 90° Rápida do Conjunto Todo
          Tooltip(
            message: 'Girar conjunto em 90° (Alternar Retrato e Paisagem)',
            child: InkWell(
              onTap: widget.onRotate90,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.rotate_90_degrees_cw_rounded, size: 13, color: Color(0xFFA5B4FC)),
                    const SizedBox(width: 4),
                    Text(
                      '↻ 90°',
                      style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Chip para Definir Ângulo Específico (ex: 12° ✎)
          Tooltip(
            message: 'Definir ângulo exato do conjunto em graus (°)',
            child: InkWell(
              onTap: widget.onOpenAngleDialog,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.screen_rotation_alt_rounded, size: 12, color: Color(0xFF38BDF8)),
                    const SizedBox(width: 3),
                    Text(
                      '$normalizedAngle° ✎',
                      style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF38BDF8)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Botão Adicionar Placa (+)
          InkWell(
            onTap: widget.onAddModule,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.add_rounded, size: 14, color: Colors.white),
                  const SizedBox(width: 2),
                  Text(
                    '+ Placa',
                    style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),

          // Botão Remover Placa (-)
          if (widget.modules.isNotEmpty) ...[
            const SizedBox(width: 4),
            InkWell(
              onTap: widget.onRemoveModule,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.remove_rounded, size: 13, color: Color(0xFFEF4444)),
              ),
            ),
          ],

          const SizedBox(width: 6),
          Text(
            '$activeModules pl',
            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF94A3B8)),
          ),

          const SizedBox(width: 8),

          // ── Botão CONCLUIR / FINALIZAR CONJUNTO (ÚNICO NO CONJUNTO) ────────
          Tooltip(
            message: 'Finalizar edição desta água e salvar arranjo',
            child: InkWell(
              onTap: widget.onFinishCurrentSection,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF10B981), width: 1.2),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF10B981)),
                    const SizedBox(width: 5),
                    Text(
                      'Concluir Água',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),

    // Ícone exclusivo de Arraste ancorado no canto superior direito do badge
    Positioned(
      top: -8,
      right: -6,
      child: Tooltip(
        message: 'Arrastar todo o conjunto de placas pela foto',
        child: GestureDetector(
          onPanUpdate: (details) {
            final dxM = RoofGeometryService.pixelsToMeters(details.delta.dx, widget.metersPerPixel);
            final dyM = RoofGeometryService.pixelsToMeters(details.delta.dy, widget.metersPerPixel);
            widget.onModuleGroupMoved?.call(dxM, dyM);
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.move,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(Icons.open_with_rounded, size: 13, color: Color(0xFF0F172A)),
              ),
            ),
          ),
        ),
      ),
    ),
  ],
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
                color: _isRotatingGroup ? const Color(0xFF10B981) : const Color(0xFF6366F1),
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

  /// Botão circular '+' colado na lateral direita do conjunto
  Widget _buildAddModuleCircleButton() {
    return Tooltip(
      message: 'Adicionar mais uma placa ao conjunto',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onAddModule,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF10B981),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Center(
              child: Icon(Icons.add_rounded, color: Colors.white, size: 20),
            ),
          ),
        ),
      ),
    );
  }

  /// Constrói o fundo de acordo com o modo ativo: Satélite ou Foto de Drone
  Widget _buildBackgroundLayer(Size canvasSize) {
    if (widget.backgroundMode == BackgroundLayerMode.dronePhoto && widget.droneImageBytes != null) {
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

    return _buildSatelliteTileLayer(canvasSize);
  }

  /// Constrói o fundo de satélite carregando os tiles de alta resolução da região
  Widget _buildSatelliteTileLayer(Size canvasSize) {
    final int z = widget.zoom.round().clamp(1, 20);
    final centerTile = SatelliteMapService.latLngToTileCoords(widget.latitude, widget.longitude, z);

    final halfW = canvasSize.width / 2.0;
    final halfH = canvasSize.height / 2.0;
    const tileSize = 256.0;

    final startX = (centerTile.x - (halfW + widget.panOffsetX + tileSize) / tileSize).floor();
    final endX = (centerTile.x + (halfW - widget.panOffsetX + tileSize) / tileSize).ceil();
    final startY = (centerTile.y - (halfH + widget.panOffsetY + tileSize) / tileSize).floor();
    final endY = (centerTile.y + (halfH - widget.panOffsetY + tileSize) / tileSize).ceil();

    final List<Widget> tileWidgets = [];

    for (int tx = startX; tx <= endX; tx++) {
      for (int ty = startY; ty <= endY; ty++) {
        final tileUrl = SatelliteMapService.getTileUrl(tx, ty, z, source: widget.satelliteSource);

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
                  child: Icon(Icons.satellite_alt_outlined, color: Colors.white24, size: 24),
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
          const Icon(Icons.navigation_rounded, color: Color(0xFFEF4444), size: 16),
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
    final fiveMetersInPixels = RoofGeometryService.metersToPixels(5.0, widget.metersPerPixel);
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
            style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white70),
          ),
        ],
      ),
    );
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
  final int draggingModuleIndex;
  final int selectedModuleIndex;
  final bool isDraggingGroup;

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
    this.draggingModuleIndex = -1,
    this.selectedModuleIndex = -1,
    this.isDraggingGroup = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerOffset = Offset(size.width / 2.0 + panOffsetX, size.height / 2.0 + panOffsetY);

    // ── 1. RENDERIZAÇÃO DAS SEÇÕES INATIVAS ─────────────────────────────────
    for (int s = 0; s < sections.length; s++) {
      if (s == activeSectionIndex) continue;
      final sec = sections[s];

      if (sec.vertices.isNotEmpty) {
        final path = Path();
        final screenVerts = sec.vertices.map((p) {
          final pxX = RoofGeometryService.metersToPixels(p.x, metersPerPixel);
          final pxY = RoofGeometryService.metersToPixels(p.y, metersPerPixel);
          return Offset(centerOffset.dx + pxX, centerOffset.dy + pxY);
        }).toList();

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

        // Módulos da seção inativa
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

          final pPaint = Paint()
            ..color = const Color(0xFF1E3A8A).withValues(alpha: 0.90)
            ..style = PaintingStyle.fill;
          canvas.drawPath(mPath, pPaint);

          final fPaint = Paint()
            ..color = Colors.white38
            ..strokeWidth = 1.0
            ..style = PaintingStyle.stroke;
          canvas.drawPath(mPath, fPaint);
        }

        // Tag identificadora lateral e vertical: [ Água X • N pl ✎ ]
        double sMinX = double.infinity, sMaxX = -double.infinity;
        double sMinY = double.infinity, sMaxY = -double.infinity;
        final sPoints = sec.modules.isNotEmpty
            ? sec.modules.where((m) => !m.isExcluded).expand((m) => m.getCorners()).map((p) => Offset(
                centerOffset.dx + RoofGeometryService.metersToPixels(p.x, metersPerPixel),
                centerOffset.dy + RoofGeometryService.metersToPixels(p.y, metersPerPixel),
              ))
            : screenVerts;

        for (final pt in sPoints) {
          if (pt.dx < sMinX) sMinX = pt.dx;
          if (pt.dx > sMaxX) sMaxX = pt.dx;
          if (pt.dy < sMinY) sMinY = pt.dy;
          if (pt.dy > sMaxY) sMaxY = pt.dy;
        }
        final sBbox = Rect.fromLTRB(sMinX, sMinY, sMaxX, sMaxY);
        final bool placeRight = (sBbox.right + 45 < size.width);
        final badgePos = Offset(placeRight ? sBbox.right + 26 : sBbox.left - 26, sBbox.center.dy);
        final targetPoint = Offset(placeRight ? sBbox.right : sBbox.left, sBbox.center.dy);

        _drawVerticalSectionBadge(
          canvas,
          badgePos,
          '${sec.name} • ${sec.activeModuleCount} pl ✎',
          sec.themeColor,
          targetPoint: targetPoint,
        );
      }
    }

    // ── 2. SE A SEÇÃO ATIVA ESTIVER CONCLUÍDA (MODO REPOUSO / IMAGEM 2) ─────
    if (!isEditingActiveSection) {
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

        final activeThemeColor = sections.isNotEmpty && activeSectionIndex < sections.length
            ? sections[activeSectionIndex].themeColor
            : const Color(0xFFF59E0B);

        if (isClosed) {
          path.close();
          final fillPaint = Paint()
            ..color = activeThemeColor.withValues(alpha: 0.12)
            ..style = PaintingStyle.fill;
          canvas.drawPath(path, fillPaint);
        }

        final borderPaint = Paint()
          ..color = activeThemeColor
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke;
        canvas.drawPath(path, borderPaint);

        // Módulos solares limpos
        int activeModCount = 0;

        for (final mod in modules) {
          if (mod.isExcluded) continue;
          activeModCount++;

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

          final pPaint = Paint()
            ..color = const Color(0xFF1E3A8A)
            ..style = PaintingStyle.fill;
          canvas.drawPath(mPath, pPaint);

          final fPaint = Paint()
            ..color = const Color(0xFFE2E8F0)
            ..strokeWidth = 1.2
            ..style = PaintingStyle.stroke;
          canvas.drawPath(mPath, fPaint);
        }

        // Tag identificadora lateral e na vertical (fora das placas para não cobrir)
        final String curName = sections.isNotEmpty && activeSectionIndex < sections.length
            ? sections[activeSectionIndex].name
            : 'Água 1';

        double aMinX = double.infinity, aMaxX = -double.infinity;
        double aMinY = double.infinity, aMaxY = -double.infinity;
        final aPoints = modules.isNotEmpty
            ? modules.where((m) => !m.isExcluded).expand((m) => m.getCorners()).map((p) => Offset(
                centerOffset.dx + RoofGeometryService.metersToPixels(p.x, metersPerPixel),
                centerOffset.dy + RoofGeometryService.metersToPixels(p.y, metersPerPixel),
              ))
            : screenVertices;

        for (final pt in aPoints) {
          if (pt.dx < aMinX) aMinX = pt.dx;
          if (pt.dx > aMaxX) aMaxX = pt.dx;
          if (pt.dy < aMinY) aMinY = pt.dy;
          if (pt.dy > aMaxY) aMaxY = pt.dy;
        }
        final aBbox = Rect.fromLTRB(aMinX, aMinY, aMaxX, aMaxY);
        final bool placeRight = (aBbox.right + 45 < size.width);
        final badgePos = Offset(placeRight ? aBbox.right + 26 : aBbox.left - 26, aBbox.center.dy);
        final targetPoint = Offset(placeRight ? aBbox.right : aBbox.left, aBbox.center.dy);

        _drawVerticalSectionBadge(
          canvas,
          badgePos,
          '$curName • $activeModCount pl ✎',
          activeThemeColor,
          targetPoint: targetPoint,
        );
      }
      return;
    }

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

      // Cotas métricas nas arestas da água ativa com botão de edição
      final edgeCount = isClosed ? vertices.length : vertices.length - 1;
      for (int i = 0; i < edgeCount; i++) {
        final p1 = vertices[i];
        final p2 = vertices[(i + 1) % vertices.length];
        final sp1 = screenVertices[i];
        final sp2 = screenVertices[(i + 1) % vertices.length];

        final distMeters = p1.distanceTo(p2);
        final mid = Offset((sp1.dx + sp2.dx) / 2, (sp1.dy + sp2.dy) / 2);

        _drawMetricLabel(canvas, mid, '${distMeters.toStringAsFixed(1)}m');
      }

      // Vértices do telhado ativo (bolinhas interativas de arraste)
      for (int i = 0; i < screenVertices.length; i++) {
        final v = screenVertices[i];
        final isDragging = i == draggingIndex;

        final vertexPaint = Paint()
          ..color = isDragging ? const Color(0xFF10B981) : Colors.white
          ..style = PaintingStyle.fill;

        final vertexBorder = Paint()
          ..color = isDragging ? Colors.white : const Color(0xFFF59E0B)
          ..strokeWidth = isDragging ? 3.0 : 2.0
          ..style = PaintingStyle.stroke;

        canvas.drawCircle(v, isDragging ? 8.0 : 6.0, vertexPaint);
        canvas.drawCircle(v, isDragging ? 8.0 : 6.0, vertexBorder);
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
        final panelPaint = Paint()
          ..color = isBeingDragged ? const Color(0xFF2563EB) : const Color(0xFF1E3A8A)
          ..style = PaintingStyle.fill;
        canvas.drawPath(modPath, panelPaint);

        Color borderColor = const Color(0xFFE2E8F0);
        double borderWidth = 1.2;

        if (isSelected) {
          borderColor = const Color(0xFF38BDF8);
          borderWidth = 2.5;
        } else if (isBeingDragged) {
          borderColor = const Color(0xFF10B981);
          borderWidth = 2.5;
        }

        final framePaint = Paint()
          ..color = borderColor
          ..strokeWidth = borderWidth
          ..style = PaintingStyle.stroke;
        canvas.drawPath(modPath, framePaint);

        if (screenCorners.length >= 4) {
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

  /// Desenha uma tag identificadora estilizada lateral e na vertical para não cobrir as placas
  void _drawVerticalSectionBadge(
    Canvas canvas,
    Offset position,
    String text,
    Color color, {
    Offset? targetPoint,
  }) {
    final span = TextSpan(
      text: text,
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
    final tp = TextPainter(text: span, textDirection: TextDirection.ltr);
    tp.layout();

    final textWidth = tp.width;
    final textHeight = tp.height;

    // Linha conectora suave com ponto de ancoragem no telhado
    if (targetPoint != null) {
      final linePaint = Paint()
        ..color = color.withValues(alpha: 0.65)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;
      canvas.drawLine(targetPoint, position, linePaint);

      final dotPaint = Paint()..color = color;
      canvas.drawCircle(targetPoint, 3.0, dotPaint);
    }

    canvas.save();
    canvas.translate(position.dx, position.dy);
    canvas.rotate(math.pi / 2); // Rotaciona 90° na vertical

    final bgRect = Rect.fromCenter(
      center: Offset.zero,
      width: textWidth + 18,
      height: textHeight + 10,
    );

    final rrect = RRect.fromRectAndRadius(bgRect, const Radius.circular(12));
    final bgPaint = Paint()..color = const Color(0xFF0F172A).withValues(alpha: 0.95);
    final borderPaint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;

    canvas.drawRRect(rrect, bgPaint);
    canvas.drawRRect(rrect, borderPaint);

    tp.paint(canvas, Offset(-textWidth / 2, -textHeight / 2));
    canvas.restore();
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

    tp.paint(canvas, Offset(position.dx - tp.width / 2, position.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _RoofOverlayPainter oldDelegate) => true;
}
