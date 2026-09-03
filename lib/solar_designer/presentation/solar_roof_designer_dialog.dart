import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/services/drone_roof_vision_service.dart';
import '../data/services/module_layout_engine.dart';
import '../data/services/roof_geometry_service.dart';
import '../data/services/satellite_map_service.dart';
import '../domain/models/solar_designer_models.dart';
import 'widgets/satellite_roof_canvas.dart';

/// Diálogo Executivo Full-Screen de Estudo de Telhado Fotovoltaico via Satélite
class SolarRoofDesignerDialog extends StatefulWidget {
  final String? initialAddress;
  final SolarModuleSpec? initialModule;
  final ValueChanged<RoofStudyResult>? onStudyCompleted;

  const SolarRoofDesignerDialog({
    super.key,
    this.initialAddress,
    this.initialModule,
    this.onStudyCompleted,
  });

  /// Método estático para abrir o modal de estudo de telhado de qualquer tela
  static Future<RoofStudyResult?> show(
    BuildContext context, {
    String? initialAddress,
    SolarModuleSpec? initialModule,
  }) {
    return showDialog<RoofStudyResult>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) => SolarRoofDesignerDialog(
        initialAddress: initialAddress,
        initialModule: initialModule,
      ),
    );
  }

  @override
  State<SolarRoofDesignerDialog> createState() =>
      _SolarRoofDesignerDialogState();
}

/// Posições direcionais para adição de fileiras de módulos no plano 2D do telhado
enum RowDirection {
  above, // Acima no plano 2D (em direção ao topo / cumeeira)
  below, // Abaixo no plano 2D (em direção ao beiral)
  left,  // À Esquerda no plano 2D
  right, // À Direita no plano 2D
}

class _SolarRoofDesignerDialogState extends State<SolarRoofDesignerDialog> {
  final GlobalKey _canvasKey = GlobalKey();
  final TextEditingController _searchCtrl = TextEditingController();

  // Coordenadas geográficas atuais
  double _latitude = GeoCoordinate.defaultLocation.latitude;
  double _longitude = GeoCoordinate.defaultLocation.longitude;
  String _currentAddress = GeoCoordinate.defaultLocation.formattedAddress;
  double _zoom = 18.5; // Zoom alto para detalhe de telhado

  // Panning do canvas
  double _panOffsetX = 0.0;
  double _panOffsetY = 0.0;

  // Ferramenta ativa
  DesignerToolMode _toolMode = DesignerToolMode.pan;

  // Telhado desenhado
  List<RoofPoint> _roofVertices = [];
  bool _isRoofClosed = false;

  // Módulos solares alocados
  List<PlacedModule> _modules = [];
  SolarModuleSpec _selectedModule = SolarModuleSpec.presets.first;
  ModuleOrientation _orientation = ModuleOrientation.portrait;
  double _setbackMeters = 0.30; // 30cm de recuo da beirada
  double _rotationOffsetDegrees = 0.0; // Rotação adicional manual

  // Estados de carregamento e feedback
  bool _isSearching = false;
  String? _errorMessage;
  SatelliteSource _satelliteSource = SatelliteSource.googleHybrid;

  // Camada de Fundo (Satélite vs Foto de Drone)
  BackgroundLayerMode _backgroundMode = BackgroundLayerMode.satellite;
  Uint8List? _droneImageBytes;
  String? _droneImageFileName;
  DroneRoofAnalysisResult? _droneAnalysisResult;
  bool _isAnalyzingDrone = false;
  double? _customDroneMetersPerPixel;

  // Gerenciamento de Múltiplas Águas / Quedas de Telhado
  final List<RoofSection> _sections = [];
  int _activeSectionIndex = 0;
  bool _isSectionFinalized = false;
  static const List<Color> _sectionPalette = [
    Color(0xFFF59E0B), // Âmbar (Água 1)
    Color(0xFF38BDF8), // Ciano (Água 2)
    Color(0xFFA855F7), // Roxo (Água 3)
    Color(0xFF10B981), // Esmeralda (Água 4)
    Color(0xFFF43F5E), // Rosa (Água 5)
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialModule != null) {
      _selectedModule = widget.initialModule!;
    }

    // Inicializa a primeira água (Água 1)
    _sections.add(
      RoofSection(
        id: '1',
        name: 'Água 1',
        vertices: [],
        modules: [],
        moduleSpec: _selectedModule,
        orientation: _orientation,
        rotationDegrees: _rotationOffsetDegrees,
        setbackMeters: _setbackMeters,
        themeColor: _sectionPalette[0],
      ),
    );

    if (widget.initialAddress != null &&
        widget.initialAddress!.trim().isNotEmpty) {
      _searchCtrl.text = widget.initialAddress!.trim();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _performSearch(_searchCtrl.text);
      });
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Controles Métricos e Geometria ────────────────────────────────────────
  double get _metersPerPixel {
    if (_backgroundMode == BackgroundLayerMode.dronePhoto) {
      final base = _customDroneMetersPerPixel ?? 0.025; // 2.5cm por pixel
      return base / math.pow(2.0, _zoom - 18.0);
    }
    return RoofGeometryService.getMetersPerPixel(
      latitude: _latitude,
      zoomLevel: _zoom,
    );
  }

  RoofPolygon get _roofPolygon => RoofPolygon(vertices: _roofVertices);

  // ── Upload de Foto de Drone ──────────────────────────────────────────────
  Future<void> _pickDronePhoto() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      );

      if (files.isNotEmpty) {
        final file = files.first;
        final b = await file.readAsBytes();
        if (b.isNotEmpty && mounted) {
          setState(() {
            _droneImageBytes = b;
            _droneImageFileName = file.name;
            _backgroundMode = BackgroundLayerMode.dronePhoto;
            _customDroneMetersPerPixel = 0.025;
            _panOffsetX = 0.0;
            _panOffsetY = 0.0;
            _zoom = 18.0;
            _roofVertices.clear();
            _isRoofClosed = false;
            _modules.clear();
          });

          // Dispara a análise com IA Gemini Vision
          _analyzeDroneWithGemini();
        }
      }
    } catch (e) {
      debugPrint('[SolarRoofDesigner] Erro ao carregar foto do drone: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erro ao carregar foto: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── Análise Inteligente da Foto do Drone com IA Gemini ───────────────────
  Future<void> _analyzeDroneWithGemini() async {
    if (_droneImageBytes == null) return;

    setState(() => _isAnalyzingDrone = true);

    try {
      final result = await DroneRoofVisionService.analyzeDronePhoto(
        imageBytes: _droneImageBytes!,
        mimeType: _droneImageFileName?.toLowerCase().endsWith('.png') == true
            ? 'image/png'
            : 'image/jpeg',
      );

      if (mounted) {
        setState(() {
          _droneAnalysisResult = result;
          _isAnalyzingDrone = false;
        });

        // Se ainda não tiver telhado desenhado, cria um pré-dimensionamento inicial com base nas medidas da IA
        if (_roofVertices.isEmpty) {
          final halfW = result.estimatedWidthMeters / 2.0;
          final halfH = result.estimatedHeightMeters / 2.0;
          setState(() {
            _roofVertices.addAll([
              RoofPoint(-halfW, -halfH),
              RoofPoint(halfW, -halfH),
              RoofPoint(halfW, halfH),
              RoofPoint(-halfW, halfH),
            ]);
            _isRoofClosed = true;
          });
          _autoFillModules();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.auto_awesome_rounded, color: Colors.amber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'IA Gemini analisou o drone: ${result.roofType} (~${result.estimatedAreaM2.toStringAsFixed(1)} m²). Clique nas cotas para ajustar as medidas!',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1E293B),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('[SolarRoofDesigner] Erro na análise Gemini: $e');
      if (mounted) {
        setState(() => _isAnalyzingDrone = false);
      }
    }
  }

  // ── Diálogo de Edição Rápida de Medida de Aresta (Conforme Solicitado) ───
  void _editEdgeDimension(int edgeIndex) {
    if (_roofVertices.length < 2 ||
        edgeIndex < 0 ||
        edgeIndex >= _roofVertices.length) {
      return;
    }

    final p1 = _roofVertices[edgeIndex];
    final p2 = _roofVertices[(edgeIndex + 1) % _roofVertices.length];
    final currentLength = p1.distanceTo(p2);

    final ctrl = TextEditingController(text: currentLength.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF334155)),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.straighten_rounded,
                  color: Color(0xFFF59E0B), size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              'Ajustar Medida da Aresta',
              style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Informe a medida real conferida (cumeeira, beiral ou trena):',
              style: GoogleFonts.inter(
                  fontSize: 12.5, color: const Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Comprimento Real',
                labelStyle: GoogleFonts.inter(
                    color: const Color(0xFF94A3B8), fontSize: 13),
                suffixText: 'metros',
                suffixStyle: GoogleFonts.inter(
                    color: Colors.amber, fontWeight: FontWeight.bold),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF334155))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: Color(0xFFF59E0B), width: 1.5)),
              ),
              onSubmitted: (val) {
                final target = double.tryParse(val.replaceAll(',', '.'));
                if (target != null && target > 0) {
                  Navigator.pop(ctx);
                  _applyEdgeLength(edgeIndex, target);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar',
                style: GoogleFonts.inter(color: const Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            onPressed: () {
              final target = double.tryParse(ctrl.text.replaceAll(',', '.'));
              if (target != null && target > 0) {
                Navigator.pop(ctx);
                _applyEdgeLength(edgeIndex, target);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Aplicar Medida',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _applyEdgeLength(int edgeIndex, double targetLength) {
    if (_roofVertices.length < 2 || edgeIndex < 0 || edgeIndex >= _roofVertices.length) return;

    final p1 = _roofVertices[edgeIndex];
    final p2 = _roofVertices[(edgeIndex + 1) % _roofVertices.length];
    final currentLength = p1.distanceTo(p2);

    if (currentLength <= 0.001 || targetLength <= 0.001) return;

    // Fator de ajuste de escala métrica
    final scaleFactor = targetLength / currentLength;

    setState(() {
      // ADAPTA A ESCALA DA FOTO (metros por pixel)
      // A linha na tela NÃO se encurta nem se desloca, ela continua sobre o mesmo telhado!
      if (_backgroundMode == BackgroundLayerMode.dronePhoto) {
        final currentBase = _customDroneMetersPerPixel ?? 0.025;
        _customDroneMetersPerPixel = currentBase * scaleFactor;
      }

      // Atualiza os valores em metros de todos os vértices mantendo suas posições na tela
      for (int i = 0; i < _roofVertices.length; i++) {
        _roofVertices[i] = RoofPoint(
          _roofVertices[i].x * scaleFactor,
          _roofVertices[i].y * scaleFactor,
        );
      }
    });

    if (_isRoofClosed) {
      _autoFillModules();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Escala adaptada! O telhado agora mede exatamente ${targetLength.toStringAsFixed(2)} metros.',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleVertexMoved(int vertexIndex, RoofPoint newPoint) {
    if (vertexIndex >= 0 && vertexIndex < _roofVertices.length) {
      setState(() {
        _roofVertices[vertexIndex] = newPoint;
      });
      if (_isRoofClosed) {
        _autoFillModules();
      }
    }
  }

  // ── Adição e Movimentação Manual de Módulos (Conforme Solicitado) ────────
  void _addSingleModule() {
    final width = _orientation == ModuleOrientation.portrait
        ? _selectedModule.widthMeters
        : _selectedModule.heightMeters;
    final height = _orientation == ModuleOrientation.portrait
        ? _selectedModule.heightMeters
        : _selectedModule.widthMeters;
    final rot = _rotationOffsetDegrees * math.pi / 180.0;

    if (_modules.isEmpty) {
      // Se não há módulos, coloca no centro do telhado ou na mira central
      final center = _roofVertices.isNotEmpty ? _roofPolygon.centroid : const RoofPoint(0, 0);
      setState(() {
        _modules.add(PlacedModule(
          id: 'mod_manual_${DateTime.now().millisecondsSinceEpoch}',
          center: center,
          widthMeters: width,
          heightMeters: height,
          rotationRadians: rot,
          watts: _selectedModule.watts,
        ));
      });
      return;
    }

    // Se já existem módulos, calcula a posição da próxima placa à direita da última placa
    final last = _modules.last;
    const spacing = 0.02; // 2cm de folga entre placas
    final step = last.widthMeters + spacing;

    final dx = step * math.cos(last.rotationRadians);
    final dy = step * math.sin(last.rotationRadians);

    setState(() {
      _modules.add(PlacedModule(
        id: 'mod_manual_${DateTime.now().millisecondsSinceEpoch}_${_modules.length}',
        center: RoofPoint(last.center.x + dx, last.center.y + dy),
        widthMeters: width,
        heightMeters: height,
        rotationRadians: last.rotationRadians,
        watts: _selectedModule.watts,
      ));
    });
  }

  /// Adiciona uma nova placa com posição relativa à placa selecionada (targetIndex)
  /// Posições suportadas: 'left', 'right', 'front', 'back'
  void _addModuleRelative(int targetIndex, String position) {
    if (targetIndex < 0 || targetIndex >= _modules.length) return;

    final target = _modules[targetIndex];
    const spacing = 0.02; // 2cm de folga entre placas
    final rot = target.rotationRadians;
    final w = target.widthMeters;
    final h = target.heightMeters;

    // Vetores unitários no sistema de coordenadas da placa:
    // U (eixo longitudinal da linha / largura da placa): (cos(rot), sin(rot))
    // V (eixo transversal / frente-trás da placa): (-sin(rot), cos(rot))
    final uX = math.cos(rot);
    final uY = math.sin(rot);
    final vX = -math.sin(rot);
    final vY = math.cos(rot);

    // O usuário vê a tela sempre com X para a direita e Y para baixo.
    // Se a placa estiver virada de cabeça para baixo (rot entre 90° e 270°), o eixo U local aponta para a esquerda da tela!
    // Para que "Direita" seja SEMPRE à direita do observador na tela (ou à direita da esteira):
    // Verificamos a projeção de U no eixo X da tela (uX) e de V no eixo Y da tela (vY):
    final double signU = (uX >= 0) ? 1.0 : -1.0;
    final double signV = (vY >= 0) ? 1.0 : -1.0;

    double offsetU = 0.0;
    double offsetV = 0.0;

    switch (position) {
      case 'left':
        // Esquerda visual do usuário na tela: sempre no sentido -X
        offsetU = -signU * (w + spacing);
        break;
      case 'right':
        // Direita visual do usuário na tela: sempre no sentido +X
        offsetU = signU * (w + spacing);
        break;
      case 'front':
        // À frente visual do usuário na tela: sempre no sentido +Y
        offsetV = signV * (h + spacing);
        break;
      case 'back':
        // Atrás visual do usuário na tela: sempre no sentido -Y
        offsetV = -signV * (h + spacing);
        break;
    }

    final newCenterX = target.center.x + (offsetU * uX + offsetV * vX);
    final newCenterY = target.center.y + (offsetU * uY + offsetV * vY);

    setState(() {
      _modules.add(PlacedModule(
        id: 'mod_manual_${DateTime.now().millisecondsSinceEpoch}_${_modules.length}',
        rowId: target.rowId, // mantém vinculada à fileira caso a placa pertença a uma
        center: RoofPoint(newCenterX, newCenterY),
        widthMeters: w,
        heightMeters: h,
        rotationRadians: rot,
        watts: target.watts,
      ));
      _syncCurrentSection();
    });

    final String posLabel;
    switch (position) {
      case 'left':
        posLabel = 'à esquerda';
        break;
      case 'right':
        posLabel = 'à direita';
        break;
      case 'front':
        posLabel = 'à frente';
        break;
      case 'back':
      default:
        posLabel = 'atrás';
        break;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Placa adicionada $posLabel da placa selecionada!',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF10B981),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _removeSingleModule() {
    if (_modules.isNotEmpty) {
      setState(() {
        _modules.removeLast();
      });
    }
  }

  void _handleModuleMoved(int index, double dxMeters, double dyMeters) {
    if (index >= 0 && index < _modules.length) {
      setState(() {
        _modules[index] = _modules[index].translate(dxMeters, dyMeters);
      });
    }
  }

  void _handleModuleGroupMoved(double dxMeters, double dyMeters) {
    setState(() {
      _modules = _modules.map((m) => m.translate(dxMeters, dyMeters)).toList();
      _syncCurrentSection();
    });
  }

  /// Move o polígono do telhado junto com todas as placas solares
  void _handleDrawingMoved(double dxMeters, double dyMeters) {
    setState(() {
      _roofVertices = _roofVertices.map((v) => RoofPoint(v.x + dxMeters, v.y + dyMeters)).toList();
      _modules = _modules.map((m) => m.translate(dxMeters, dyMeters)).toList();
      _syncCurrentSection();
    });
  }

  /// Move apenas as placas de uma fileira/linha específica (rowId)
  void _handleRowMoved(String rowId, double dxMeters, double dyMeters) {
    setState(() {
      _modules = _modules.map((m) {
        if (m.rowId == rowId) {
          return m.translate(dxMeters, dyMeters);
        }
        return m;
      }).toList();
      _syncCurrentSection();
    });
  }

  // ── Rotação de Módulos (90° Paisagem e Ângulo Livre à Mão) ────────────────
  void _rotateModules90() {
    if (_modules.isEmpty) {
      setState(() {
        _orientation = _orientation == ModuleOrientation.portrait
            ? ModuleOrientation.landscape
            : ModuleOrientation.portrait;
      });
      return;
    }

    // Centróide do arranjo de módulos
    double sumX = 0, sumY = 0;
    for (final m in _modules) {
      sumX += m.center.x;
      sumY += m.center.y;
    }
    final pivot = RoofPoint(sumX / _modules.length, sumY / _modules.length);

    setState(() {
      _modules = _modules.map((m) => m.rotateAround(pivot, math.pi / 2)).toList();
      _rotationOffsetDegrees = (_rotationOffsetDegrees + 90.0) % 360.0;
      _orientation = _orientation == ModuleOrientation.portrait
          ? ModuleOrientation.landscape
          : ModuleOrientation.portrait;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Módulos rotacionados em 90° (${_orientation == ModuleOrientation.portrait ? "Retrato" : "Paisagem"})!',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF6366F1),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _rotateModulesByDelta(double deltaRadians) {
    if (_modules.isEmpty) return;

    double sumX = 0, sumY = 0;
    for (final m in _modules) {
      sumX += m.center.x;
      sumY += m.center.y;
    }
    final pivot = RoofPoint(sumX / _modules.length, sumY / _modules.length);

    setState(() {
      _modules = _modules.map((m) => m.rotateAround(pivot, deltaRadians)).toList();
      _rotationOffsetDegrees = (_rotationOffsetDegrees + deltaRadians * 180.0 / math.pi) % 360.0;
    });
  }

  // ── Rotação e Exclusão de Placa Individual (Conforme Solicitado) ──────────
  void _rotateSingleModule90(int index) {
    if (index < 0 || index >= _modules.length) return;
    setState(() {
      final m = _modules[index];
      _modules[index] = m.copyWith(
        rotationRadians: (m.rotationRadians + math.pi / 2) % (2 * math.pi),
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Placa #${index + 1} rotacionada em 90°!',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF38BDF8),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _rotateSingleModuleByDelta(int index, double deltaRadians) {
    if (index < 0 || index >= _modules.length) return;
    setState(() {
      final m = _modules[index];
      _modules[index] = m.copyWith(
        rotationRadians: (m.rotationRadians + deltaRadians) % (2 * math.pi),
      );
    });
  }

  void _deleteSingleModule(int index) {
    if (index < 0 || index >= _modules.length) return;
    setState(() {
      _modules.removeAt(index);
    });
  }

  // ── Adição de Nova Fileira / Linha no Plano 2D (Acima, Abaixo, Dir, Esq) ──
  Future<void> _showAddRowDialog() async {
    RowDirection selectedDirection = RowDirection.above;
    int moduleCount = _modules.isNotEmpty ? (_modules.length.clamp(1, 10)) : 4;
    ModuleOrientation rowOrientation = _orientation;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return Dialog(
              backgroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
              ),
              child: Container(
                width: 440,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Cabeçalho
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.table_rows_rounded, color: Color(0xFF38BDF8), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Adicionar Fileira de Placas',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Posição no plano do telhado (X / Y) e quantidade',
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  color: const Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          icon: const Icon(Icons.close_rounded, color: Colors.white60, size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Seção 1: Direção da Nova Fileira no Plano 2D
                    Text(
                      'POSIÇÃO DA NOVA LINHA (PLANO 2D):',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF94A3B8),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDirectionCard(
                            direction: RowDirection.above,
                            selected: selectedDirection == RowDirection.above,
                            icon: Icons.arrow_upward_rounded,
                            title: 'Acima',
                            subtitle: 'Rumo ao topo / cumeeira',
                            onTap: () => setDialogState(() => selectedDirection = RowDirection.above),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildDirectionCard(
                            direction: RowDirection.below,
                            selected: selectedDirection == RowDirection.below,
                            icon: Icons.arrow_downward_rounded,
                            title: 'Abaixo',
                            subtitle: 'Rumo ao beiral / fundo',
                            onTap: () => setDialogState(() => selectedDirection = RowDirection.below),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDirectionCard(
                            direction: RowDirection.left,
                            selected: selectedDirection == RowDirection.left,
                            icon: Icons.arrow_back_rounded,
                            title: 'À Esquerda',
                            subtitle: 'Lateral esquerda (X-)',
                            onTap: () => setDialogState(() => selectedDirection = RowDirection.left),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildDirectionCard(
                            direction: RowDirection.right,
                            selected: selectedDirection == RowDirection.right,
                            icon: Icons.arrow_forward_rounded,
                            title: 'À Direita',
                            subtitle: 'Lateral direita (X+)',
                            onTap: () => setDialogState(() => selectedDirection = RowDirection.right),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Seção 2: Quantidade de Módulos
                    Text(
                      'QUANTIDADE DE PLACAS NESTA LINHA:',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF94A3B8),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            onPressed: moduleCount > 1
                                ? () => setDialogState(() => moduleCount--)
                                : null,
                            icon: const Icon(Icons.remove_circle_outline_rounded, color: Color(0xFF38BDF8), size: 28),
                          ),
                          Column(
                            children: [
                              Text(
                                '$moduleCount placas',
                                style: GoogleFonts.outfit(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                '${(moduleCount * _selectedModule.watts / 1000.0).toStringAsFixed(2)} kWp',
                                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF10B981), fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          IconButton(
                            onPressed: moduleCount < 30
                                ? () => setDialogState(() => moduleCount++)
                                : null,
                            icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF38BDF8), size: 28),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Atalhos Rápidos
                    Wrap(
                      spacing: 8,
                      children: [2, 4, 6, 8, 10, 12].map((cnt) {
                        final isSel = moduleCount == cnt;
                        return InkWell(
                          onTap: () => setDialogState(() => moduleCount = cnt),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isSel ? const Color(0xFF38BDF8) : const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$cnt pl',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isSel ? const Color(0xFF0F172A) : Colors.white70,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // Botões de Ação
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF334155)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: Text('Cancelar', style: GoogleFonts.inter(color: Colors.white70)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: Text(
                              'INSERIR FILEIRA',
                              style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF38BDF8),
                              foregroundColor: const Color(0xFF0F172A),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result == true) {
      _addModuleRow(selectedDirection, moduleCount, rowOrientation);
    }
  }

  Widget _buildDirectionCard({
    required RowDirection direction,
    required bool selected,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF38BDF8).withValues(alpha: 0.15) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFF38BDF8) : const Color(0xFF334155),
            width: selected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? const Color(0xFF38BDF8) : const Color(0xFF94A3B8), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: selected ? Colors.white : Colors.white70,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      color: const Color(0xFF64748B),
                    ),
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
  }

  void _addModuleRow(RowDirection direction, int count, ModuleOrientation orientation) {
    if (count <= 0) return;

    // ── CORREÇÃO CRÍTICA: usar a rotação REAL das placas existentes, não _rotationOffsetDegrees
    // Isso garante que a nova fileira fique paralela ao conjunto já desenhado no telhado.
    final double rot = _modules.isNotEmpty
        ? _modules.first.rotationRadians
        : _rotationOffsetDegrees * math.pi / 180.0;

    final double modWidth = _selectedModule.getWidth(orientation);
    final double modHeight = _selectedModule.getHeight(orientation);
    const double colSpacing = 0.02; // 2cm entre placas na mesma fileira
    const double rowSpacing = 0.05; // 5cm entre fileiras adjacentes
    // A rotação do módulo na nova linha acompanha a rotação real das existentes
    final double modRot = rot;

    // ID único que identifica esta fileira inteira (para exclusão em lote)
    final String rowId = 'row_${DateTime.now().millisecondsSinceEpoch}';

    if (_modules.isEmpty) {
      final origin = _roofVertices.isNotEmpty
          ? RoofPolygon(vertices: _roofVertices).centroid
          : RoofPoint(0, 0);
      final totalW = count * modWidth + (count - 1) * colSpacing;
      final startU = -totalW / 2.0 + modWidth / 2.0;

      final newMods = <PlacedModule>[];
      for (int i = 0; i < count; i++) {
        final u = startU + i * (modWidth + colSpacing);
        final x = origin.x + u * math.cos(rot);
        final y = origin.y + u * math.sin(rot);
        newMods.add(PlacedModule(
          id: '${rowId}_$i',
          rowId: rowId,
          center: RoofPoint(x, y),
          widthMeters: modWidth,
          heightMeters: modHeight,
          rotationRadians: modRot,
          watts: _selectedModule.watts,
        ));
      }

      setState(() {
        _modules.addAll(newMods);
        _syncCurrentSection();
      });
      return;
    }

    // Calcula centroide dos módulos existentes como origem local (pivot)
    double sumX = 0, sumY = 0;
    for (final m in _modules) {
      sumX += m.center.x;
      sumY += m.center.y;
    }
    final pivot = RoofPoint(sumX / _modules.length, sumY / _modules.length);

    double minU = double.infinity, maxU = -double.infinity;
    double minV = double.infinity, maxV = -double.infinity;

    for (final m in _modules) {
      final dx = m.center.x - pivot.x;
      final dy = m.center.y - pivot.y;
      final u = dx * math.cos(rot) + dy * math.sin(rot);
      final v = -dx * math.sin(rot) + dy * math.cos(rot);

      minU = math.min(minU, u - m.widthMeters / 2.0);
      maxU = math.max(maxU, u + m.widthMeters / 2.0);
      minV = math.min(minV, v - m.heightMeters / 2.0);
      maxV = math.max(maxV, v + m.heightMeters / 2.0);
    }

    final newModules = <PlacedModule>[];

    if (direction == RowDirection.above) {
      final vNew = minV - rowSpacing - modHeight / 2.0;
      final centerU = (minU + maxU) / 2.0;
      final totalWidth = count * modWidth + (count - 1) * colSpacing;
      final startU = centerU - totalWidth / 2.0 + modWidth / 2.0;

      for (int i = 0; i < count; i++) {
        final u = startU + i * (modWidth + colSpacing);
        final x = pivot.x + u * math.cos(rot) - vNew * math.sin(rot);
        final y = pivot.y + u * math.sin(rot) + vNew * math.cos(rot);
        newModules.add(PlacedModule(
          id: '${rowId}_$i',
          rowId: rowId,
          center: RoofPoint(x, y),
          widthMeters: modWidth,
          heightMeters: modHeight,
          rotationRadians: modRot,
          watts: _selectedModule.watts,
        ));
      }
    } else if (direction == RowDirection.below) {
      final vNew = maxV + rowSpacing + modHeight / 2.0;
      final centerU = (minU + maxU) / 2.0;
      final totalWidth = count * modWidth + (count - 1) * colSpacing;
      final startU = centerU - totalWidth / 2.0 + modWidth / 2.0;

      for (int i = 0; i < count; i++) {
        final u = startU + i * (modWidth + colSpacing);
        final x = pivot.x + u * math.cos(rot) - vNew * math.sin(rot);
        final y = pivot.y + u * math.sin(rot) + vNew * math.cos(rot);
        newModules.add(PlacedModule(
          id: '${rowId}_$i',
          rowId: rowId,
          center: RoofPoint(x, y),
          widthMeters: modWidth,
          heightMeters: modHeight,
          rotationRadians: modRot,
          watts: _selectedModule.watts,
        ));
      }
    } else if (direction == RowDirection.right) {
      final uNew = maxU + colSpacing + modWidth / 2.0;
      final centerV = (minV + maxV) / 2.0;
      final totalHeight = count * modHeight + (count - 1) * rowSpacing;
      final startV = centerV - totalHeight / 2.0 + modHeight / 2.0;

      for (int i = 0; i < count; i++) {
        final v = startV + i * (modHeight + rowSpacing);
        final x = pivot.x + uNew * math.cos(rot) - v * math.sin(rot);
        final y = pivot.y + uNew * math.sin(rot) + v * math.cos(rot);
        newModules.add(PlacedModule(
          id: '${rowId}_$i',
          rowId: rowId,
          center: RoofPoint(x, y),
          widthMeters: modWidth,
          heightMeters: modHeight,
          rotationRadians: modRot,
          watts: _selectedModule.watts,
        ));
      }
    } else if (direction == RowDirection.left) {
      final uNew = minU - colSpacing - modWidth / 2.0;
      final centerV = (minV + maxV) / 2.0;
      final totalHeight = count * modHeight + (count - 1) * rowSpacing;
      final startV = centerV - totalHeight / 2.0 + modHeight / 2.0;

      for (int i = 0; i < count; i++) {
        final v = startV + i * (modHeight + rowSpacing);
        final x = pivot.x + uNew * math.cos(rot) - v * math.sin(rot);
        final y = pivot.y + uNew * math.sin(rot) + v * math.cos(rot);
        newModules.add(PlacedModule(
          id: '${rowId}_$i',
          rowId: rowId,
          center: RoofPoint(x, y),
          widthMeters: modWidth,
          heightMeters: modHeight,
          rotationRadians: modRot,
          watts: _selectedModule.watts,
        ));
      }
    }

    setState(() {
      _modules.addAll(newModules);
      _syncCurrentSection();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Fileira com $count placas adicionada com sucesso no plano do telhado!',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF10B981),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Remove todas as placas que pertencem à fileira identificada por [rowId]
  void _deleteRow(String rowId) {
    setState(() {
      _modules.removeWhere((m) => m.rowId == rowId);
      _syncCurrentSection();
    });
  }

  // ── Múltiplas Águas de Telhado (Finalizar, Nova Água, Alternar) ───────────
  void _syncCurrentSection() {
    if (_sections.isEmpty) {
      _sections.add(
        RoofSection(
          id: '1',
          name: 'Água 1',
          vertices: List.from(_roofVertices),
          isClosed: _isRoofClosed,
          modules: List.from(_modules),
          moduleSpec: _selectedModule,
          orientation: _orientation,
          rotationDegrees: _rotationOffsetDegrees,
          setbackMeters: _setbackMeters,
          themeColor: _sectionPalette[0],
        ),
      );
      return;
    }
    if (_activeSectionIndex >= 0 && _activeSectionIndex < _sections.length) {
      _sections[_activeSectionIndex] = _sections[_activeSectionIndex].copyWith(
        vertices: List.from(_roofVertices),
        isClosed: _isRoofClosed,
        modules: List.from(_modules),
        moduleSpec: _selectedModule,
        orientation: _orientation,
        rotationDegrees: _rotationOffsetDegrees,
        setbackMeters: _setbackMeters,
      );
    }
  }

  void _selectSection(int index) {
    if (index < 0 || index >= _sections.length || index == _activeSectionIndex) return;
    _syncCurrentSection();
    setState(() {
      _activeSectionIndex = index;
      _isSectionFinalized = false;
      final sec = _sections[index];
      _roofVertices = List.from(sec.vertices);
      _isRoofClosed = sec.isClosed;
      _modules = List.from(sec.modules);
      _selectedModule = sec.moduleSpec;
      _orientation = sec.orientation;
      _rotationOffsetDegrees = sec.rotationDegrees;
      _setbackMeters = sec.setbackMeters;
      _toolMode = sec.isClosed ? DesignerToolMode.editModules : DesignerToolMode.drawRoof;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Editando ${_sections[index].name} (${_sections[index].activeModuleCount} placas)',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        backgroundColor: _sections[index].themeColor,
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _finishCurrentSection() {
    _syncCurrentSection();
    setState(() {
      _isSectionFinalized = true;
    });
    final currentSec = _sections[_activeSectionIndex];

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${currentSec.name} concluída com sucesso (${currentSec.activeModuleCount} placas • ${currentSec.totalKwp.toStringAsFixed(2)} kWp)!',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF10B981),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _addNewSection() {
    _syncCurrentSection();

    final newIndex = _sections.length;
    final newColor = _sectionPalette[newIndex % _sectionPalette.length];
    final newSec = RoofSection(
      id: '${newIndex + 1}',
      name: 'Água ${newIndex + 1}',
      vertices: [],
      isClosed: false,
      modules: [],
      moduleSpec: _selectedModule,
      orientation: _orientation,
      rotationDegrees: 0.0,
      setbackMeters: _setbackMeters,
      themeColor: newColor,
    );

    setState(() {
      _sections.add(newSec);
      _activeSectionIndex = newIndex;
      _isSectionFinalized = false;
      _roofVertices = [];
      _isRoofClosed = false;
      _modules = [];
      _rotationOffsetDegrees = 0.0;
      _toolMode = DesignerToolMode.drawRoof;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Nova Água ${newIndex + 1} criada! Clique nos cantos para demarcar a nova queda do telhado.',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        backgroundColor: newColor,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Duplica e espelha a água atual invertida alinhada com a cumeeira (à frente ou atrás das placas).
  /// Conclui a água atual e seleciona a nova água espelhada já aberta para edição.
  void _duplicateCurrentSection(String direction) {
    if (_roofVertices.isEmpty && _modules.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Desenhe o telhado ou adicione placas antes de duplicar a água.',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFFEF4444),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // 1. Conclui a água atual
    _finishCurrentSection();

    // 2. Determina o vetor normal/orientação da cumeeira baseado na rotação dos módulos
    // Se não houver módulos, usa a rotação do grupo ou 0.0
    final double baseRotation = _modules.isNotEmpty
        ? _modules.first.rotationRadians
        : (_rotationOffsetDegrees * math.pi / 180.0);

    // Eixo V (frente/trás das placas): unitário
    final double vX = -math.sin(baseRotation);
    final double vY = math.cos(baseRotation);

    // 3. Projeta todos os pontos dos módulos e vértices no eixo V para achar o limite da cumeeira
    final List<RoofPoint> referencePoints = [];
    if (_modules.isNotEmpty) {
      for (final m in _modules) {
        referencePoints.addAll(m.getCorners());
      }
    }
    if (_roofVertices.isNotEmpty) {
      referencePoints.addAll(_roofVertices);
    }

    // Centro do conjunto atual
    double sumX = 0, sumY = 0;
    for (final p in referencePoints) {
      sumX += p.x;
      sumY += p.y;
    }
    final double centerRefX = sumX / referencePoints.length;
    final double centerRefY = sumY / referencePoints.length;

    // Projeções escalares no eixo V em relação ao centro: dot(P - C, V)
    double minV = double.infinity;
    double maxV = -double.infinity;

    for (final p in referencePoints) {
      final projV = (p.x - centerRefX) * vX + (p.y - centerRefY) * vY;
      if (projV < minV) minV = projV;
      if (projV > maxV) maxV = projV;
    }

    // Posição da linha de cumeeira no eixo V
    // 'front': cumeeira fica no maxV (ou minV dependendo da orientação visual)
    // 'back': cumeeira fica no minV (ou maxV)
    final double ridgeV = (direction == 'front') ? -minV : maxV;
    final double ridgeAnchorX = centerRefX + ridgeV * vX;
    final double ridgeAnchorY = centerRefY + ridgeV * vY;

    // Função para espelhar qualquer ponto em relação à linha da cumeeira perpendicular ao eixo V:
    // P' = P - 2 * dot(P - RidgeAnchor, V) * V
    RoofPoint mirrorPointAcrossRidge(RoofPoint p) {
      final double distV = (p.x - ridgeAnchorX) * vX + (p.y - ridgeAnchorY) * vY;
      final double mirroredX = p.x - 2.0 * distV * vX;
      final double mirroredY = p.y - 2.0 * distV * vY;
      return RoofPoint(mirroredX, mirroredY);
    }

    // 4. Espelha os vértices do polígono do telhado
    final List<RoofPoint> mirroredVertices = _roofVertices.map(mirrorPointAcrossRidge).toList();

    // 5. Espelha as placas solares e inverte sua rotação em 180°
    final List<PlacedModule> mirroredModules = _modules.map((m) {
      final mirroredCenter = mirrorPointAcrossRidge(m.center);

      return PlacedModule(
        id: 'mod_mirror_${DateTime.now().millisecondsSinceEpoch}_${m.id}',
        rowId: m.rowId != null ? 'row_mirror_${m.rowId}' : null,
        center: mirroredCenter,
        widthMeters: m.widthMeters,
        heightMeters: m.heightMeters,
        rotationRadians: (m.rotationRadians + math.pi) % (2 * math.pi),
        watts: m.watts,
        isExcluded: m.isExcluded,
      );
    }).toList();

    // 6. Cria a nova seção no sistema
    final newIndex = _sections.length;
    final newColor = _sectionPalette[newIndex % _sectionPalette.length];
    final mirroredRotation = (_rotationOffsetDegrees + 180.0) % 360.0;

    final newSec = RoofSection(
      id: '${newIndex + 1}',
      name: 'Água ${newIndex + 1}',
      vertices: mirroredVertices,
      isClosed: _isRoofClosed,
      modules: mirroredModules,
      moduleSpec: _selectedModule,
      orientation: _orientation,
      rotationDegrees: mirroredRotation,
      setbackMeters: _setbackMeters,
      themeColor: newColor,
    );

    setState(() {
      _sections.add(newSec);
      _activeSectionIndex = newIndex;
      _isSectionFinalized = false;
      _roofVertices = List.from(mirroredVertices);
      _isRoofClosed = _isRoofClosed;
      _modules = List.from(mirroredModules);
      _rotationOffsetDegrees = mirroredRotation;
      _toolMode = DesignerToolMode.editModules;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Água ${newIndex + 1} criada e encaixada na cumeeira oposta!',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        backgroundColor: newColor,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _deleteCurrentSection(int index) {
    if (_sections.length <= 1) {
      _clearRoof();
      return;
    }
    setState(() {
      _sections.removeAt(index);
      _activeSectionIndex = (_activeSectionIndex >= _sections.length) ? _sections.length - 1 : _activeSectionIndex;
      _isSectionFinalized = false;
      final sec = _sections[_activeSectionIndex];
      _roofVertices = List.from(sec.vertices);
      _isRoofClosed = sec.isClosed;
      _modules = List.from(sec.modules);
      _selectedModule = sec.moduleSpec;
      _orientation = sec.orientation;
      _rotationOffsetDegrees = sec.rotationDegrees;
      _setbackMeters = sec.setbackMeters;
    });
  }

  void _setAbsoluteRotationAngle(double targetDegrees) {
    if (_modules.isEmpty) {
      setState(() => _rotationOffsetDegrees = targetDegrees % 360.0);
      return;
    }

    final normalizedTarget = ((targetDegrees % 360) + 360) % 360;
    final currentNormalized = ((_rotationOffsetDegrees % 360) + 360) % 360;
    final diffDegrees = normalizedTarget - currentNormalized;
    final deltaRadians = diffDegrees * math.pi / 180.0;

    _rotateModulesByDelta(deltaRadians);
  }

  void _showSetAngleDialog() {
    final ctrl = TextEditingController(
      text: ((_rotationOffsetDegrees % 360 + 360) % 360).toStringAsFixed(1),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF334155)),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.screen_rotation_alt_rounded, color: Color(0xFF6366F1), size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              'Definir Ângulo de Rotação',
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Digite o ângulo exato em graus (0° a 360°) ou clique em um atalho:',
              style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Ângulo da Placa (°)',
                labelStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13),
                suffixText: 'graus',
                suffixStyle: GoogleFonts.inter(color: const Color(0xFF38BDF8), fontWeight: FontWeight.bold),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF334155))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5)),
              ),
              onSubmitted: (val) {
                final target = double.tryParse(val.replaceAll(',', '.'));
                if (target != null) {
                  Navigator.pop(ctx);
                  _setAbsoluteRotationAngle(target);
                }
              },
            ),
            const SizedBox(height: 14),
            Text(
              'Atalhos rápidos:',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [0.0, 15.0, 30.0, 45.0, 90.0, 180.0, 270.0].map((deg) {
                return ActionChip(
                  label: Text('${deg.toInt()}°', style: GoogleFonts.inter(fontSize: 11, color: Colors.white)),
                  backgroundColor: const Color(0xFF1E293B),
                  side: const BorderSide(color: Color(0xFF334155)),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _setAbsoluteRotationAngle(deg);
                  },
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: GoogleFonts.inter(color: const Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            onPressed: () {
              final target = double.tryParse(ctrl.text.replaceAll(',', '.'));
              if (target != null) {
                Navigator.pop(ctx);
                _setAbsoluteRotationAngle(target);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Aplicar Ângulo', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── Busca de Endereço / CEP ──────────────────────────────────────────────
  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    final coord = await SatelliteMapService.searchAddress(query);

    if (!mounted) return;

    if (coord != null) {
      setState(() {
        _latitude = coord.latitude;
        _longitude = coord.longitude;
        _currentAddress = coord.formattedAddress;
        _panOffsetX = 0.0;
        _panOffsetY = 0.0;
        _zoom = 18.0;
        _roofVertices.clear();
        _isRoofClosed = false;
        _modules.clear();
        _isSearching = false;
      });
    } else {
      setState(() {
        _isSearching = false;
        _errorMessage =
            'Endereço não localizado. Tente digitar o CEP ou a Cidade/Rua com número.';
      });
    }
  }

  // ── Ações do Canvas: Clique para Demarcar ou Excluir ─────────────────────
  void _handleCanvasTap(Offset localPos) {
    // Converte o clique na tela para coordenadas métricas relativas ao centro do canvas
    final RenderBox? box =
        _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final canvasCenter = Offset(box.size.width / 2.0 + _panOffsetX,
        box.size.height / 2.0 + _panOffsetY);
    final dxPixels = localPos.dx - canvasCenter.dx;
    final dyPixels = localPos.dy - canvasCenter.dy;

    final pointMeters = RoofPoint(
      RoofGeometryService.pixelsToMeters(dxPixels, _metersPerPixel),
      RoofGeometryService.pixelsToMeters(dyPixels, _metersPerPixel),
    );

    if (_toolMode == DesignerToolMode.drawRoof) {
      setState(() {
        if (!_isRoofClosed) {
          // Se clicou muito perto do primeiro vértice, fecha o polígono
          if (_roofVertices.length >= 3) {
            final first = _roofVertices.first;
            if (first.distanceTo(pointMeters) < 1.5) {
              _isRoofClosed = true;
              _autoFillModules();
              return;
            }
          }
          _roofVertices.add(pointMeters);
        }
      });
    } else if (_toolMode == DesignerToolMode.editModules) {
      // Alterna a exclusão da placa clicada (contornar chaminés, etc.)
      final hit = ModuleLayoutEngine.findModuleAtPoint(pointMeters, _modules);
      if (hit != null) {
        setState(() {
          hit.isExcluded = !hit.isExcluded;
        });
      }
    }
  }

  // ── Fechar Telhado com Duplo Clique ──────────────────────────────────────
  void _handleCanvasDoubleTap() {
    if (_toolMode == DesignerToolMode.drawRoof &&
        _roofVertices.length >= 3 &&
        !_isRoofClosed) {
      setState(() {
        _isRoofClosed = true;
        _autoFillModules();
      });
    }
  }

  // ── Preenchimento Automático dos Módulos ──────────────────────────────────
  void _autoFillModules() {
    if (_roofVertices.length < 3) return;

    final radOffset = _rotationOffsetDegrees * (math.pi / 180.0);
    final baseAngle = _roofPolygon.dominantEdgeAngleRadians + radOffset;

    final filled = ModuleLayoutEngine.autoFillModules(
      roof: _roofPolygon,
      moduleSpec: _selectedModule,
      orientation: _orientation,
      setbackMeters: _setbackMeters,
      customRotationRadians: baseAngle,
    );

    setState(() {
      _modules = filled;
    });
  }

  // ── Limpar Desenho do Telhado ─────────────────────────────────────────────
  void _clearRoof() {
    setState(() {
      _roofVertices.clear();
      _isRoofClosed = false;
      _modules.clear();
      _toolMode = DesignerToolMode.drawRoof;
    });
  }

  // ── Zoom In / Zoom Out com Ancoragem Focada (Focal Point Zoom) ───────────
  void _zoomIn([Offset? focalPoint]) {
    _applyZoom(0.5, focalPoint);
  }

  void _zoomOut([Offset? focalPoint]) {
    _applyZoom(-0.5, focalPoint);
  }

  void _applyZoom(double deltaZoom, [Offset? focalPoint]) {
    final double oldZoom = _zoom;
    final double newZoom = (oldZoom + deltaZoom).clamp(15.0, 20.0);
    if (newZoom == oldZoom) return;

    final RenderBox? box =
        _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    final size = box?.size ?? const Size(800, 600);
    final halfW = size.width / 2.0;
    final halfH = size.height / 2.0;

    // Se não informou ponto de foco (ex: clique no botão da barra), usa o centro da tela
    final fx = focalPoint?.dx ?? halfW;
    final fy = focalPoint?.dy ?? halfH;

    final double s = math.pow(2.0, newZoom - oldZoom).toDouble();

    final double newPanX = (fx - halfW) - s * (fx - halfW - _panOffsetX);
    final double newPanY = (fy - halfH) - s * (fy - halfH - _panOffsetY);

    setState(() {
      _zoom = newZoom;
      _panOffsetX = newPanX;
      _panOffsetY = newPanY;
    });
  }

  // ── Captura do Estudo e Exportação ───────────────────────────────────────
  Future<void> _exportStudy() async {
    String? base64Snapshot;
    try {
      final boundary = _canvasKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary != null) {
        final image = await boundary.toImage(pixelRatio: 1.5);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          base64Snapshot = base64Encode(byteData.buffer.asUint8List());
        }
      }
    } catch (e) {
      debugPrint('[SolarRoofDesigner] Erro ao capturar snapshot: $e');
    }

    _syncCurrentSection();

    // Coleta todos os módulos ativos de todas as seções mapeadas
    final allModules = <PlacedModule>[];
    for (final sec in _sections) {
      allModules.addAll(sec.modules.where((m) => !m.isExcluded));
    }
    if (allModules.isEmpty) {
      allModules.addAll(_modules.where((m) => !m.isExcluded));
    }

    final totalModules = allModules.length;
    final totalWatts = allModules.fold<int>(0, (sum, m) => sum + m.watts);
    final totalKwp = totalWatts > 0 ? (totalWatts / 1000.0) : ModuleLayoutEngine.calculateTotalKwp(_modules, _selectedModule);
    final estimatedKwh = ModuleLayoutEngine.estimateMonthlyGenerationKwh(totalKwp);
    final totalRoofArea = _sections.fold<double>(0.0, (sum, s) => sum + s.areaM2);

    final result = RoofStudyResult(
      snapshotImageBase64: base64Snapshot,
      totalModules: totalModules,
      totalWatts: totalWatts,
      totalKwp: totalKwp,
      roofAreaM2: totalRoofArea > 0 ? totalRoofArea : _roofPolygon.areaM2,
      moduleAreaM2: totalModules * _selectedModule.areaM2,
      estimatedMonthlyKwh: estimatedKwh,
      address: _currentAddress,
      selectedModule: _selectedModule,
      sections: List.from(_sections),
    );

    widget.onStudyCompleted?.call(result);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 960;

    _syncCurrentSection();

    // Consolidação de todas as águas (seções de telhado)
    int consolidatedModuleCount = 0;
    double consolidatedWatts = 0;
    double consolidatedRoofAreaM2 = 0;

    for (final sec in _sections) {
      consolidatedModuleCount += sec.activeModuleCount;
      consolidatedWatts += sec.activeModuleCount * sec.moduleSpec.watts;
      consolidatedRoofAreaM2 += sec.areaM2;
    }

    if (_sections.isEmpty) {
      consolidatedModuleCount = _modules.where((m) => !m.isExcluded).length;
      consolidatedWatts = consolidatedModuleCount * _selectedModule.watts.toDouble();
      consolidatedRoofAreaM2 = _roofPolygon.areaM2;
    }

    final consolidatedKwp = consolidatedWatts / 1000.0;
    final consolidatedMonthlyKwh = consolidatedKwp * 130.0;

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: Colors.transparent,
      child: Container(
        width: screenSize.width * 0.96,
        height: screenSize.height * 0.94,
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF334155)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 40,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── 1. CABEÇALHO DO STUDIO COM BUSCA ───────────────────────────
              _buildHeader(context),

              // ── 2. CORPO: CANVAS DE SATÉLITE + PAINEL DE KPIS ──────────────
              Expanded(
                child: isMobile
                    ? Column(
                        children: [
                          Expanded(child: _buildCanvasArea()),
                          _buildSidebar(
                              consolidatedModuleCount,
                              consolidatedKwp,
                              consolidatedRoofAreaM2,
                              consolidatedMonthlyKwh,
                              isMobile: true),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(child: _buildCanvasArea()),
                          Container(width: 1, color: const Color(0xFF1E293B)),
                          SizedBox(
                            width: 360,
                            child: _buildSidebar(
                                consolidatedModuleCount,
                                consolidatedKwp,
                                consolidatedRoofAreaM2,
                                consolidatedMonthlyKwh,
                                isMobile: false),
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

  /// Cabeçalho superior com barra de busca por endereço/CEP e botões de zoom
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(bottom: BorderSide(color: Color(0xFF334155))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFFF59E0B), Color(0xFFD97706)]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.solar_power_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Solar Roof Designer • Estudo de Telhado & Satélite 🛰️',
                  style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                Text(
                  _currentAddress,
                  style: GoogleFonts.inter(
                      fontSize: 11.5, color: const Color(0xFF94A3B8)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // Campo de busca por endereço ou CEP
          SizedBox(
            width: 380,
            child: TextField(
              controller: _searchCtrl,
              onSubmitted: _performSearch,
              style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Buscar endereço ou CEP (ex: 01310-100)...',
                hintStyle: GoogleFonts.inter(
                    fontSize: 12.5, color: const Color(0xFF64748B)),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: Color(0xFF94A3B8), size: 18),
                suffixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Color(0xFFF59E0B)),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.arrow_forward_rounded,
                            color: Color(0xFFF59E0B), size: 18),
                        onPressed: () => _performSearch(_searchCtrl.text),
                      ),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                errorText: _errorMessage,
                errorMaxLines: 1,
                errorStyle: GoogleFonts.inter(
                    fontSize: 10, color: const Color(0xFFEF4444)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Alternância Satélite vs Foto de Drone
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildModeChoiceButton(
                  isActive: _backgroundMode == BackgroundLayerMode.satellite,
                  label: 'Satélite',
                  icon: Icons.satellite_alt_rounded,
                  onTap: () => setState(
                      () => _backgroundMode = BackgroundLayerMode.satellite),
                ),
                _buildModeChoiceButton(
                  isActive: _backgroundMode == BackgroundLayerMode.dronePhoto,
                  label: _droneImageBytes != null ? 'Drone' : 'Drone 📸',
                  icon: Icons.camera_alt_rounded,
                  onTap: () {
                    if (_droneImageBytes == null) {
                      _pickDronePhoto();
                    } else {
                      setState(() =>
                          _backgroundMode = BackgroundLayerMode.dronePhoto);
                    }
                  },
                ),
              ],
            ),
          ),
          if (_droneImageBytes != null) ...[
            const SizedBox(width: 6),
            IconButton(
              onPressed: _pickDronePhoto,
              icon: const Icon(Icons.file_upload_outlined,
                  color: Color(0xFF38BDF8), size: 20),
              tooltip: 'Substituir Foto do Drone',
            ),
          ],
          if (_isAnalyzingDrone) ...[
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Color(0xFF38BDF8)),
                ),
                const SizedBox(width: 6),
                Text('IA analisando foto...',
                    style: GoogleFonts.inter(
                        fontSize: 11, color: const Color(0xFF38BDF8))),
              ],
            ),
          ],
          const SizedBox(width: 12),

          // Botões de Zoom In / Zoom Out
          IconButton(
            onPressed: _zoomIn,
            icon: const Icon(Icons.zoom_in_rounded, color: Colors.white70),
            tooltip: 'Aproximar Zoom',
          ),
          IconButton(
            onPressed: _zoomOut,
            icon: const Icon(Icons.zoom_out_rounded, color: Colors.white70),
            tooltip: 'Afastar Zoom',
          ),
          const SizedBox(width: 8),

          // Botão Fechar
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, color: Colors.white70),
            tooltip: 'Fechar',
          ),
        ],
      ),
    );
  }

  /// Botão de escolha entre Satélite e Drone
  Widget _buildModeChoiceButton({
    required bool isActive,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF6366F1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: isActive ? Colors.white : const Color(0xFF94A3B8)),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive ? Colors.white : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Área central contendo o canvas de satélite e a barra de ferramentas flutuante
  Widget _buildCanvasArea() {
    return Stack(
      children: [
        // Canvas com RepaintBoundary para captura de imagem
        RepaintBoundary(
          key: _canvasKey,
          child: SatelliteRoofCanvas(
            latitude: _latitude,
            longitude: _longitude,
            zoom: _zoom,
            panOffsetX: _panOffsetX,
            panOffsetY: _panOffsetY,
            roofVertices: _roofVertices,
            isRoofClosed: _isRoofClosed,
            modules: _modules,
            sections: _sections,
            activeSectionIndex: _activeSectionIndex,
            isEditingActiveSection: !_isSectionFinalized,
            toolMode: _toolMode,
            satelliteSource: _satelliteSource,
            backgroundMode: _backgroundMode,
            droneImageBytes: _droneImageBytes,
            metersPerPixel: _metersPerPixel,
            onCanvasTap: _handleCanvasTap,
            onCanvasDoubleTap: (_) => _handleCanvasDoubleTap(),
            onZoomIn: _zoomIn,
            onZoomOut: _zoomOut,
            onEdgeTap: _editEdgeDimension,
            onVertexMoved: _handleVertexMoved,
            onModuleGroupMoved: _handleModuleGroupMoved,
            onDrawingMoved: _handleDrawingMoved,
            onRowMoved: _handleRowMoved,
            onModuleMoved: _handleModuleMoved,
            onRotateModuleGroup: _rotateModulesByDelta,
            onRotateSingleModule: _rotateSingleModuleByDelta,
            onRotateSingleModule90: _rotateSingleModule90,
            onDeleteSingleModule: _deleteSingleModule,
            onRotate90: _rotateModules90,
            onOpenAngleDialog: _showSetAngleDialog,
            groupRotationDegrees: _rotationOffsetDegrees,
            onAddModule: _addSingleModule,
            onAddModuleRelative: _addModuleRelative,
            onRemoveModule: _removeSingleModule,
            onAddRow: _showAddRowDialog,
            onDeleteRow: _deleteRow,
            onSectionSelected: _selectSection,
            onDeleteSection: _deleteCurrentSection,
            onFinishCurrentSection: _finishCurrentSection,
            onResumeEditing: () => setState(() => _isSectionFinalized = false),
            onAddNewSection: _addNewSection,
            onDuplicateCurrentSection: _duplicateCurrentSection,
            onPanUpdate: (delta) {
              setState(() {
                _panOffsetX += delta.dx;
                _panOffsetY += delta.dy;
              });
            },
          ),
        ),

        // Barra de Ferramentas Flutuante Superior
        Positioned(
          top: 16,
          left: 20,
          child: _buildFloatingToolbar(),
        ),

        // Dica contextual na parte inferior do canvas
        Positioned(
          bottom: 16,
          left: 140,
          child: _buildContextualHint(),
        ),
      ],
    );
  }

  /// Barra flutuante com as ferramentas de desenho e controle de módulos
  Widget _buildFloatingToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF334155)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToolButton(
            mode: DesignerToolMode.pan,
            icon: Icons.pan_tool_rounded,
            label: 'Navegar',
          ),
          const SizedBox(width: 4),
          _buildToolButton(
            mode: DesignerToolMode.drawRoof,
            icon: Icons.polyline_rounded,
            label: _isRoofClosed ? 'Telhado OK' : 'Desenhar',
          ),
          const SizedBox(width: 4),
          _buildToolButton(
            mode: DesignerToolMode.editModules,
            icon: Icons.solar_power_rounded,
            label: 'Módulos ⚡',
          ),
          const SizedBox(width: 8),
          Container(width: 1, height: 24, color: const Color(0xFF334155)),
          const SizedBox(width: 8),

          // Botão Auto-Fill (Preencher Placas)
          ElevatedButton.icon(
            onPressed: _isRoofClosed ? _autoFillModules : null,
            icon: const Icon(Icons.flash_on_rounded, size: 16),
            label: Text('PREENCHER',
                style: GoogleFonts.outfit(
                    fontSize: 12, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(width: 6),

          // Botão + Placa Manual (coloca mais uma placa ao conjunto)
          OutlinedButton.icon(
            onPressed: _addSingleModule,
            icon: const Icon(Icons.add_rounded, size: 16, color: Color(0xFF10B981)),
            label: Text('+ Placa',
                style: GoogleFonts.outfit(
                    fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF10B981), width: 1.2),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(width: 6),

          // Botão + Nova Água (para telhados com múltiplas quedas)
          ElevatedButton.icon(
            onPressed: _addNewSection,
            icon: const Icon(Icons.add_home_work_rounded, size: 16),
            label: Text('+ NOVA ÁGUA',
                style: GoogleFonts.outfit(
                    fontSize: 12, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF38BDF8),
              foregroundColor: const Color(0xFF0F172A),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(width: 6),

          // Botão Limpar
          IconButton(
            onPressed: _roofVertices.isNotEmpty ? _clearRoof : null,
            icon: const Icon(Icons.delete_outline_rounded,
                color: Color(0xFFEF4444), size: 20),
            tooltip: 'Limpar Telhado',
          ),
          const SizedBox(width: 4),
          Container(width: 1, height: 24, color: const Color(0xFF334155)),
          const SizedBox(width: 6),

          // Seletor de Camada de Satélite (Google Maps / Esri)
          PopupMenuButton<SatelliteSource>(
            initialValue: _satelliteSource,
            tooltip: 'Alterar Satélite',
            onSelected: (source) => setState(() => _satelliteSource = source),
            color: const Color(0xFF0F172A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFF334155)),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.layers_rounded,
                      color: Color(0xFF38BDF8), size: 15),
                  const SizedBox(width: 6),
                  Text(
                    _satelliteSource.label,
                    style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  const Icon(Icons.arrow_drop_down_rounded,
                      color: Colors.white70, size: 16),
                ],
              ),
            ),
            itemBuilder: (ctx) => SatelliteSource.values.map((source) {
              return PopupMenuItem(
                value: source,
                child: Row(
                  children: [
                    Icon(
                      source == _satelliteSource
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 16,
                      color: source == _satelliteSource
                          ? const Color(0xFF10B981)
                          : Colors.white38,
                    ),
                    const SizedBox(width: 8),
                    Text(source.label,
                        style: GoogleFonts.inter(
                            fontSize: 12.5, color: Colors.white)),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildToolButton({
    required DesignerToolMode mode,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _toolMode == mode;
    return InkWell(
      onTap: () => setState(() => _toolMode = mode),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color: isSelected ? Colors.white : const Color(0xFF94A3B8)),
            const SizedBox(width: 6),
            Text(
              label,
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
  }

  /// Dica de instruções para o usuário baseada na ferramenta ativa
  Widget _buildContextualHint() {
    String hintText = '';
    if (_toolMode == DesignerToolMode.pan) {
      hintText =
          'Arraste com o botão esquerdo para navegar pelo telhado no centro da tela.';
    } else if (_toolMode == DesignerToolMode.drawRoof) {
      hintText = _isRoofClosed
          ? 'Telhado delimitado! Clique sobre as medidas (ex: 10.8m ✎) para alterar o tamanho real, ou arraste os cantos.'
          : 'Clique nos cantos para demarcar o telhado. Clique sobre qualquer medida para digitar o valor real.';
    } else if (_toolMode == DesignerToolMode.editModules) {
      hintText =
          'Arraste qualquer placa ou o conjunto todo [✥]. Use [+ Placa] para estender o arranjo livremente pela foto!';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.info_outline_rounded,
              color: Color(0xFFF59E0B), size: 15),
          const SizedBox(width: 8),
          Text(
            hintText,
            style: GoogleFonts.inter(fontSize: 11, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  /// Barra lateral com seleção de módulo, rotação e KPIs consolidados
  Widget _buildSidebar(
    int activeCount,
    double totalKwp,
    double areaM2,
    double monthlyKwh, {
    required bool isMobile,
  }) {
    return Container(
      color: const Color(0xFF1E293B),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'PARÂMETROS DA USINA',
                    style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF94A3B8)),
                  ),
                  const SizedBox(height: 12),

          // Card de Diagnóstico do Drone via IA Gemini
          if (_droneAnalysisResult != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome_rounded,
                          color: Color(0xFF38BDF8), size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Diagnóstico IA do Drone',
                        style: GoogleFonts.outfit(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF38BDF8)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_droneAnalysisResult!.roofType} • ~${_droneAnalysisResult!.estimatedAreaM2.toStringAsFixed(1)} m²',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  if (_droneAnalysisResult!.obstacles.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: _droneAnalysisResult!.obstacles.map((obs) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFEF4444).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: const Color(0xFFEF4444)
                                    .withValues(alpha: 0.3)),
                          ),
                          child: Text(obs,
                              style: GoogleFonts.inter(
                                  fontSize: 10.5,
                                  color: const Color(0xFFFCA5A5))),
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    _droneAnalysisResult!.technicalSummary,
                    style: GoogleFonts.inter(
                        fontSize: 11, color: const Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Seletor de Modelo de Módulo Solar
          Text('Modelo do Módulo:',
              style: GoogleFonts.inter(fontSize: 11.5, color: Colors.white70)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<SolarModuleSpec>(
                value: _selectedModule,
                isExpanded: true,
                dropdownColor: const Color(0xFF0F172A),
                icon: const Icon(Icons.keyboard_arrow_down_rounded,
                    color: Colors.white70),
                items: SolarModuleSpec.presets.map((spec) {
                  return DropdownMenuItem(
                    value: spec,
                    child: Text(
                      spec.modelName,
                      style:
                          GoogleFonts.inter(fontSize: 12, color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (newSpec) {
                  if (newSpec != null) {
                    setState(() => _selectedModule = newSpec);
                    if (_isRoofClosed) _autoFillModules();
                  }
                },
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Orientação: Retrato vs Paisagem
          Row(
            children: [
              Expanded(
                child: _buildOrientationChoice(
                  orientation: ModuleOrientation.portrait,
                  icon: Icons.crop_portrait_rounded,
                  label: 'Retrato',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildOrientationChoice(
                  orientation: ModuleOrientation.landscape,
                  icon: Icons.crop_landscape_rounded,
                  label: 'Paisagem',
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Ajuste fino de Rotação da Grade
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Giro da Grade:',
                  style: GoogleFonts.inter(fontSize: 11.5, color: Colors.white70)),
              InkWell(
                onTap: _showSetAngleDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${((_rotationOffsetDegrees % 360 + 360) % 360).toStringAsFixed(0)}°',
                        style: GoogleFonts.inter(
                            fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.amber),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.edit_rounded, size: 11, color: Colors.amber),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Slider(
            value: ((_rotationOffsetDegrees % 360 + 360) % 360).clamp(0.0, 360.0),
            min: 0,
            max: 360,
            divisions: 72,
            activeColor: const Color(0xFFF59E0B),
            inactiveColor: const Color(0xFF334155),
            onChanged: (val) {
              setState(() {
                _setAbsoluteRotationAngle(val);
              });
            },
          ),

          const SizedBox(height: 10),

          // Recuo de borda (Setback de segurança)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Recuo de Borda:',
                  style:
                      GoogleFonts.inter(fontSize: 11.5, color: Colors.white70)),
              Text('${(_setbackMeters * 100).toStringAsFixed(0)} cm',
                  style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber)),
            ],
          ),
          Slider(
            value: _setbackMeters,
            min: 0.15,
            max: 0.80,
            divisions: 13,
            activeColor: const Color(0xFFF59E0B),
            inactiveColor: const Color(0xFF334155),
            onChanged: (val) {
              setState(() => _setbackMeters = val);
              if (_isRoofClosed) _autoFillModules();
            },
          ),

          const Divider(color: Color(0xFF334155), height: 24),

          // ── 4 CARDS DE KPIS CONSOLIDADOS ─────────────────────────────────
          Text(
            'PRÉ-DIMENSIONAMENTO',
            style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                  child: _buildKpiCard(
                      'POTÊNCIA',
                      '${totalKwp.toStringAsFixed(2)} kWp',
                      Icons.bolt_rounded,
                      const Color(0xFF10B981))),
              const SizedBox(width: 10),
              Expanded(
                  child: _buildKpiCard('MÓDULOS', '$activeCount placas',
                      Icons.grid_view_rounded, const Color(0xFF6366F1))),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child: _buildKpiCard(
                      'ÁREA TELHADO',
                      '${areaM2.toStringAsFixed(1)} m²',
                      Icons.square_foot_rounded,
                      const Color(0xFFF59E0B))),
              const SizedBox(width: 10),
              Expanded(
                  child: _buildKpiCard(
                      'GERAÇÃO ESTIMADA',
                      '~${monthlyKwh.toStringAsFixed(0)} kWh/mês',
                      Icons.solar_power_rounded,
                      const Color(0xFF38BDF8))),
            ],
          ),

          // ── Resumo de Quedas Mapeadas (Múltiplas Águas) ───────────────────
          if (_sections.length > 1 || (_sections.isNotEmpty && _sections.first.activeModuleCount > 0)) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'QUEDAS DE TELHADO (${_sections.length})',
                        style: GoogleFonts.outfit(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF94A3B8)),
                      ),
                      InkWell(
                        onTap: _addNewSection,
                        child: Row(
                          children: [
                            const Icon(Icons.add_rounded, size: 12, color: Color(0xFF38BDF8)),
                            const SizedBox(width: 2),
                            Text(
                              'Nova Água',
                              style: GoogleFonts.inter(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF38BDF8)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ..._sections.asMap().entries.map((e) {
                    final idx = e.key;
                    final sec = e.value;
                    final isCur = idx == _activeSectionIndex;

                    return InkWell(
                      onTap: () => _selectSection(idx),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: isCur ? sec.themeColor.withValues(alpha: 0.15) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isCur ? sec.themeColor : Colors.transparent),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(color: sec.themeColor, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                sec.name,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: isCur ? FontWeight.bold : FontWeight.normal,
                                  color: isCur ? Colors.white : Colors.white70,
                                ),
                              ),
                            ),
                            Text(
                              '${sec.activeModuleCount} pl • ${sec.totalKwp.toStringAsFixed(2)} kWp',
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: isCur ? sec.themeColor : const Color(0xFF94A3B8),
                              ),
                            ),
                            if (isCur) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.edit_rounded, size: 11, color: Colors.amber),
                            ],
                            if (_sections.length > 1) ...[
                              const SizedBox(width: 6),
                              InkWell(
                                onTap: () => _deleteCurrentSection(idx),
                                child: const Icon(Icons.close_rounded, size: 13, color: Color(0xFFEF4444)),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── BOTÕES DE CONFIRMAÇÃO / EXPORTAÇÃO (FIXO NO RODAPÉ) ──────────
          ElevatedButton.icon(
            onPressed: activeCount > 0 ? _exportStudy : null,
            icon: const Icon(Icons.check_circle_rounded, size: 20),
            label: Text('SALVAR ESTUDO & APLICAR',
                style: GoogleFonts.outfit(
                    fontSize: 14, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrientationChoice({
    required ModuleOrientation orientation,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _orientation == orientation;
    return InkWell(
      onTap: () {
        if (_orientation != orientation) {
          _rotateModules90();
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6366F1) : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: isSelected
                  ? const Color(0xFF6366F1)
                  : const Color(0xFF334155)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 16,
                color: isSelected ? Colors.white : const Color(0xFF94A3B8)),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF94A3B8)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.outfit(
                fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
