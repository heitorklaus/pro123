import 'dart:async';
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
import '../domain/models/roof_study_model.dart';
import '../domain/services/brazil_solar_irradiation_service.dart';
import '../data/repositories/roof_study_repository.dart';
import 'widgets/satellite_roof_canvas.dart';
import 'widgets/roof_study_setup_dialog.dart';
import '../../clients/domain/models/client_model.dart';
import '../../proposals/domain/models/proposal_model.dart';
import '../../auth/domain/models/user_model.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Diálogo Executivo Full-Screen de Estudo de Telhado Fotovoltaico via Satélite
class SolarRoofDesignerDialog extends StatefulWidget {
  final String? initialAddress;
  final SolarModuleSpec? initialModule;
  final ValueChanged<RoofStudyResult>? onStudyCompleted;
  final RoofStudyModel? initialStudy;
  final String? initialStudyName;
  final ClientModel? initialClient;
  final ProposalModel? initialProposal;
  final UserModel? currentUser;

  const SolarRoofDesignerDialog({
    super.key,
    this.initialAddress,
    this.initialModule,
    this.onStudyCompleted,
    this.initialStudy,
    this.initialStudyName,
    this.initialClient,
    this.initialProposal,
    this.currentUser,
  });

  /// Método estático para abrir o modal de estudo de telhado de qualquer tela
  static Future<RoofStudyResult?> show(
    BuildContext context, {
    String? initialAddress,
    SolarModuleSpec? initialModule,
    RoofStudyModel? initialStudy,
    String? initialStudyName,
    ClientModel? initialClient,
    ProposalModel? initialProposal,
    UserModel? currentUser,
  }) {
    return showDialog<RoofStudyResult>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) => SolarRoofDesignerDialog(
        initialAddress: initialAddress,
        initialModule: initialModule,
        initialStudy: initialStudy,
        initialStudyName: initialStudyName,
        initialClient: initialClient,
        initialProposal: initialProposal,
        currentUser: currentUser,
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
  left, // À Esquerda no plano 2D
  right, // À Direita no plano 2D
}

class _SolarRoofDesignerDialogState extends State<SolarRoofDesignerDialog> {
  final GlobalKey _canvasKey = GlobalKey();
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _cepController = TextEditingController();
  final TextEditingController _hspController = TextEditingController();

  // Irradiação Solar CRESESB & Qualificação de Orientação
  double _dailyHsp = 5.0; // Horas de Sol Pleno (HSP diário médio em kWh/m²/dia)
  String _resolvedState = 'SP';
  String _resolvedRegion = 'Sudeste';
  bool _isRenderMode = false; // Alterna entre modo Qualificação (Heatmap + %) e modo Renderizar realista

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
  int _selectedModuleIndex =
      -1; // Índice da placa selecionada para ações individuais

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
  bool _isCurrentClusterFinalized = false;
  String? _activeClusterId;
  int _clusterCounter = 1;
  static const List<Color> _sectionPalette = [
    Color(0xFFF59E0B), // Âmbar (Água 1)
    Color(0xFF38BDF8), // Ciano (Água 2)
    Color(0xFFA855F7), // Roxo (Água 3)
    Color(0xFF10B981), // Esmeralda (Água 4)
    Color(0xFFF43F5E), // Rosa (Água 5)
  ];

  // ── Persistência e Vínculos do Estudo de Telhado (Firestore) ─────────────
  final RoofStudyRepository _roofStudyRepo = RoofStudyRepository();
  String? _studyId;
  String? _studyName;
  String? _clientId;
  String? _clientName;
  String? _proposalId;
  String? _proposalCode;
  DateTime? _createdAt;
  bool _isSavingStudy = false;

  // ── ESTUDO MAPS vs ESTUDO DRONE SEPARADOS ────────────────────────────────
  List<RoofSection> _mapsSections = [];
  int _mapsActiveSectionIndex = 0;
  double _mapsPanOffsetX = 0.0;
  double _mapsPanOffsetY = 0.0;
  double _mapsZoom = 18.5;

  List<RoofSection> _droneSections = [];
  int _droneActiveSectionIndex = 0;
  double _dronePanOffsetX = 0.0;
  double _dronePanOffsetY = 0.0;
  double _droneZoom = 18.0;
  String? _droneImageUrl;
  Future<String?>? _droneUploadFuture;
  bool _isLoadingDronePhoto = false;
  int? _snappedModuleIndex;
  Timer? _snapHighlightTimer;

  // Anotações de Orientação e Quedas do Telhado (Drone / Satélite)
  DroneNorthCompass? _droneNorthCompass;
  final List<DroneRoofArrow> _droneArrows = [];
  String? _selectedDroneArrowId;
  bool _showOrientationPanel = false;
  Offset _orientationPanelOffset = const Offset(24, 150);
  bool _snapAlignmentEnabled = true;
  Color _droneArrowsGlobalColor = const Color(0xFF2563EB);
  double _droneArrowsGlobalLength = 1.3;

  final ScrollController _orientationScrollController = ScrollController();
  final Map<String, GlobalKey> _arrowCardKeys = {};

  void _scrollToSelectedArrow(String arrowId) {
    if (!_showOrientationPanel) {
      setState(() {
        _showOrientationPanel = true;
        _toolMode = DesignerToolMode.select;
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final key = _arrowCardKeys[arrowId];
      if (key?.currentContext != null) {
        Scrollable.ensureVisible(
          key!.currentContext!,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOutCubic,
          alignment: 0.25,
        );
      } else {
        Future.delayed(const Duration(milliseconds: 60), () {
          if (!mounted) return;
          final retryKey = _arrowCardKeys[arrowId];
          if (retryKey?.currentContext != null) {
            Scrollable.ensureVisible(
              retryKey!.currentContext!,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOutCubic,
              alignment: 0.25,
            );
          }
        });
      }
    });
  }

  bool get _hasDronePhoto =>
      _droneImageBytes != null ||
      (_droneImageUrl != null && _droneImageUrl!.isNotEmpty);

  bool get _hasAnyClosedPolygon {
    if (_isRoofClosed && _roofVertices.length >= 3) return true;
    return _sections.any((s) => s.isClosed && s.vertices.length >= 3);
  }

  bool get _isAnyPolygonSelected {
    if (_isSectionFinalized) return false;
    if (_isRoofClosed && _roofVertices.length >= 3) return true;
    if (_activeSectionIndex >= 0 && _activeSectionIndex < _sections.length) {
      final sec = _sections[_activeSectionIndex];
      return sec.isClosed && sec.vertices.length >= 3;
    }
    return false;
  }

  void _showNoPolygonWarning() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Color(0xFFF59E0B), size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Para adicionar a orientação você deve definir a área do polígono antes...',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFF59E0B), width: 1.4),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Sincroniza as setas de orientação: atualiza rótulos e remove setas de seções deletadas.
  /// NÃO recria setas automaticamente se o usuário optou por remover ou desenhar sem seta.
  void _syncArrowsWithSections() {
    final closedSections = <RoofSection>[];
    for (int i = 0; i < _sections.length; i++) {
      final s = _sections[i];
      if (s.isClosed && s.vertices.length >= 3) {
        closedSections.add(s);
      } else if (i == _activeSectionIndex &&
          _isRoofClosed &&
          _roofVertices.length >= 3) {
        closedSections.add(s.copyWith(
          vertices: List.from(_roofVertices),
          isClosed: true,
        ));
      }
    }

    if (closedSections.isEmpty && _isRoofClosed && _roofVertices.length >= 3) {
      closedSections.add(RoofSection(
        id: '1',
        name: 'Água 1',
        vertices: List.from(_roofVertices),
        isClosed: true,
        modules: const [],
        moduleSpec: _selectedModule,
      ));
    }

    // Atualiza apenas os rótulos de setas que já existem
    for (int idx = 0; idx < closedSections.length; idx++) {
      final sec = closedSections[idx];
      final existingIdx =
          _droneArrows.indexWhere((a) => a.sectionId == sec.id);

      if (existingIdx != -1) {
        final existing = _droneArrows[existingIdx];
        _droneArrows[existingIdx] = existing.copyWith(
          label: sec.name.isNotEmpty ? sec.name : existing.label,
        );
      }
    }

    // Remove setas de seções que deixaram de existir
    _droneArrows.removeWhere((a) =>
        a.sectionId != null &&
        !closedSections.any((s) => s.id == a.sectionId));

    if (_selectedDroneArrowId != null &&
        !_droneArrows.any((a) => a.id == _selectedDroneArrowId)) {
      _selectedDroneArrowId = null;
    }
  }

  void _addDroneArrow() {
    if (!_hasAnyClosedPolygon) {
      _showNoPolygonWarning();
      return;
    }

    final closedSections = <RoofSection>[];
    for (int i = 0; i < _sections.length; i++) {
      final s = _sections[i];
      if (s.isClosed && s.vertices.length >= 3) {
        closedSections.add(s);
      } else if (i == _activeSectionIndex &&
          _isRoofClosed &&
          _roofVertices.length >= 3) {
        closedSections.add(s.copyWith(
          vertices: List.from(_roofVertices),
          isClosed: true,
        ));
      }
    }
    if (closedSections.isEmpty && _isRoofClosed && _roofVertices.length >= 3) {
      closedSections.add(RoofSection(
        id: '1',
        name: 'Água 1',
        vertices: List.from(_roofVertices),
        isClosed: true,
        modules: const [],
        moduleSpec: _selectedModule,
      ));
    }

    // Regra de Ouro: UMA SETA PARA CADA ORIENTAÇÃO
    // Encontra a seção que ainda não possui seta:
    RoofSection? targetSec;
    // 1. Prioriza a seção ativa atual se não possuir seta
    if (_activeSectionIndex < _sections.length) {
      final activeSec = _sections[_activeSectionIndex];
      if (!_droneArrows.any((a) => a.sectionId == activeSec.id)) {
        targetSec = activeSec;
      }
    }
    // 2. Senão, seleciona a primeira seção fechada sem seta
    if (targetSec == null) {
      for (final sec in closedSections) {
        if (!_droneArrows.any((a) => a.sectionId == sec.id)) {
          targetSec = sec;
          break;
        }
      }
    }

    if (targetSec == null) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  color: Color(0xFF38BDF8), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Cada orientação já possui sua seta. Desenhe uma nova água de telhado para adicionar outra orientação.',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF0F172A),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF38BDF8), width: 1.2),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    final polyVerts = targetSec.vertices.isNotEmpty
        ? targetSec.vertices
        : (_roofVertices.isNotEmpty ? _roofVertices : const <RoofPoint>[]);
    final poly = RoofPolygon(vertices: polyVerts);
    final centerM = poly.centroid;
    final newId = 'arrow_${targetSec.id}_${DateTime.now().millisecondsSinceEpoch}';
    final newAngle = (targetSec.rotationDegrees * math.pi / 180.0);

    final newArrow = DroneRoofArrow(
      id: newId,
      sectionId: targetSec.id,
      center: centerM,
      rotationRadians: newAngle,
      lengthMeters: _droneArrowsGlobalLength,
      label: targetSec.name.isNotEmpty ? targetSec.name : 'Água',
      color: targetSec.themeColor,
    );

    setState(() {
      _droneArrows.add(newArrow);
      _selectedDroneArrowId = newId;
      _showOrientationPanel = true;
    });

    _scrollToSelectedArrow(newId);
  }

  void _deleteDroneArrow(String id) {
    setState(() {
      _droneArrows.removeWhere((a) => a.id == id);
      _arrowCardKeys.remove(id);
      if (_selectedDroneArrowId == id) {
        _selectedDroneArrowId = null;
      }
    });
  }

  void _recenterDroneArrow(String id) {
    final idx = _droneArrows.indexWhere((a) => a.id == id);
    if (idx == -1) return;
    final arrow = _droneArrows[idx];

    RoofPoint newCenter = arrow.center;
    if (arrow.sectionId != null) {
      final sec = _sections.where((s) => s.id == arrow.sectionId).firstOrNull;
      if (sec != null && sec.vertices.length >= 3) {
        newCenter = sec.polygon.centroid;
      }
    } else if (_roofVertices.length >= 3) {
      newCenter = RoofPolygon(vertices: _roofVertices).centroid;
    }

    setState(() {
      _droneArrows[idx] = arrow.copyWith(center: newCenter);
    });
  }

  void _updateArrowRotation(int idx, double newAngle) {
    if (idx < 0 || idx >= _droneArrows.length) return;
    final arrow = _droneArrows[idx];
    final updated = arrow.copyWith(rotationRadians: newAngle);
    setState(() {
      _droneArrows[idx] = updated;
      _selectedDroneArrowId = arrow.id;
      if (arrow.sectionId != null) {
        final sIdx = _sections.indexWhere((s) => s.id == arrow.sectionId);
        if (sIdx != -1) {
          final deg =
              (((newAngle * 180.0 / math.pi) % 360) + 360) % 360;
          _sections[sIdx] = _sections[sIdx].copyWith(rotationDegrees: deg);
        }
      }
    });
  }

  void _addDroneNorthCompass() {
    final centerM = RoofPoint(
      RoofGeometryService.pixelsToMeters(-_panOffsetX, _metersPerPixel),
      RoofGeometryService.pixelsToMeters(-_panOffsetY, _metersPerPixel),
    );
    setState(() {
      _droneNorthCompass = DroneNorthCompass(
        center: centerM,
        rotationRadians: 0.0,
        showCardinals: true,
        sizeMeters: 3.2,
      );
      _showOrientationPanel = true;
    });
  }

  void _removeDroneNorthCompass() {
    setState(() {
      _droneNorthCompass = null;
    });
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialModule != null) {
      _selectedModule = widget.initialModule!;
    }

    final initialStudy = widget.initialStudy;
    if (initialStudy != null) {
      // Carrega dados completos do estudo salvo
      _studyId = initialStudy.id;
      _studyName = initialStudy.name;
      _clientId = initialStudy.clientId;
      _clientName = initialStudy.clientName;
      _proposalId = initialStudy.proposalId;
      _proposalCode = initialStudy.proposalCode;
      _latitude = initialStudy.latitude;
      _longitude = initialStudy.longitude;
      _currentAddress = initialStudy.formattedAddress;
      _searchCtrl.text = initialStudy.formattedAddress;
      _createdAt = initialStudy.createdAt;

      // Carrega estado independente do Maps
      _mapsSections = List.from(initialStudy.mapsSections);
      _mapsPanOffsetX = initialStudy.mapsPanOffsetX;
      _mapsPanOffsetY = initialStudy.mapsPanOffsetY;
      _mapsZoom = initialStudy.mapsZoom;

      // Carrega estado independente do Drone
      _droneSections = List.from(initialStudy.droneSections);
      _dronePanOffsetX = initialStudy.dronePanOffsetX;
      _dronePanOffsetY = initialStudy.dronePanOffsetY;
      _droneZoom = initialStudy.droneZoom;
      _droneImageUrl = initialStudy.droneImageUrl;
      _droneImageFileName = initialStudy.droneImageFileName;
      _customDroneMetersPerPixel = initialStudy.droneMetersPerPixel;

      // 1. Tenta carregar do cache local do dispositivo para exibição instantânea (0ms)
      if (initialStudy.id.isNotEmpty) {
        _loadCachedDroneImage(initialStudy.id);
      }
      // 2. Se tiver foto de drone gravada na nuvem e ainda não carregada, baixa em segundo plano
      if (_droneImageUrl != null && _droneImageUrl!.isNotEmpty) {
        _downloadDroneImage(_droneImageUrl!);
      }

      // Define qual modo abrir (Drone ou Satélite)
      final startInDrone = initialStudy.lastActiveMode == 'dronePhoto' ||
          (initialStudy.hasDroneStudy && !initialStudy.hasMapsStudy);

      if (startInDrone) {
        _backgroundMode = BackgroundLayerMode.dronePhoto;
        _sections.clear();
        if (_droneSections.isNotEmpty) {
          _sections.addAll(_droneSections);
        } else {
          _sections.add(
            RoofSection(
              id: '1',
              name: 'Telhado 1 (Drone)',
              vertices: [],
              modules: [],
              moduleSpec: _selectedModule,
              orientation: _orientation,
              rotationDegrees: 0.0,
              setbackMeters: _setbackMeters,
              themeColor: _sectionPalette[0],
            ),
          );
        }
        _panOffsetX = _dronePanOffsetX;
        _panOffsetY = _dronePanOffsetY;
        _zoom = _droneZoom;
      } else {
        _backgroundMode = BackgroundLayerMode.satellite;
        _sections.clear();
        if (_mapsSections.isNotEmpty) {
          _sections.addAll(_mapsSections);
        } else if (initialStudy.sections.isNotEmpty) {
          _sections.addAll(initialStudy.sections);
        } else {
          _sections.add(
            RoofSection(
              id: '1',
              name: 'Telhado 1',
              vertices: [],
              modules: [],
              moduleSpec: _selectedModule,
              orientation: _orientation,
              rotationDegrees: 0.0,
              setbackMeters: _setbackMeters,
              themeColor: _sectionPalette[0],
            ),
          );
        }
        _panOffsetX = _mapsPanOffsetX;
        _panOffsetY = _mapsPanOffsetY;
        _zoom = _mapsZoom;
      }

      if (_sections.isNotEmpty) {
        _activeSectionIndex = 0;
        final firstSec = _sections.first;
        _roofVertices = List.from(firstSec.vertices);
        _isRoofClosed = firstSec.isClosed;
        _modules = List.from(firstSec.modules);
        _selectedModule = SolarModuleSpec.presets.firstWhere(
          (s) =>
              s.id == firstSec.moduleSpec.id ||
              (s.watts == firstSec.moduleSpec.watts &&
                  (s.widthMeters - firstSec.moduleSpec.widthMeters).abs() <
                      0.05),
          orElse: () => firstSec.moduleSpec,
        );
        _orientation = firstSec.orientation;
        _rotationOffsetDegrees = firstSec.rotationDegrees;
        _setbackMeters = firstSec.setbackMeters;
        _toolMode = firstSec.isClosed
            ? DesignerToolMode.editModules
            : DesignerToolMode.drawRoof;
      }
    } else {
      // Novo estudo
      _studyName = widget.initialStudyName ??
          'Estudo Solar ${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}';
      if (widget.initialClient != null) {
        _clientId = widget.initialClient!.id;
        _clientName = widget.initialClient!.name;
        if (widget.initialClient!.fullAddress.trim().isNotEmpty &&
            (widget.initialAddress == null || widget.initialAddress!.isEmpty)) {
          _searchCtrl.text = widget.initialClient!.fullAddress.trim();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _performSearch(_searchCtrl.text);
          });
        }
      }
      if (widget.initialProposal != null) {
        _proposalId = widget.initialProposal!.id;
        _proposalCode = '#${widget.initialProposal!.proposalNumber}';
      }

      // Inicializa o primeiro telhado do Maps (Telhado 1)
      _sections.add(
        RoofSection(
          id: '1',
          name: 'Telhado 1',
          vertices: [],
          modules: [],
          moduleSpec: _selectedModule,
          orientation: _orientation,
          rotationDegrees: _rotationOffsetDegrees,
          setbackMeters: _setbackMeters,
          themeColor: _sectionPalette[0],
        ),
      );
    }

    if (widget.initialAddress != null &&
        widget.initialAddress!.trim().isNotEmpty &&
        _searchCtrl.text.isEmpty) {
      _searchCtrl.text = widget.initialAddress!.trim();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _performSearch(_searchCtrl.text);
      });
    }

    // Autocompleta o CEP do cliente e busca a Irradiação Solar (CRESESB / Atlas Solar)
    String initialCep = '';
    if (widget.initialClient?.zipCode != null &&
        widget.initialClient!.zipCode!.trim().isNotEmpty) {
      initialCep = widget.initialClient!.zipCode!.trim();
    } else if (widget.initialClient?.fullAddress != null) {
      final cepMatch = RegExp(r'\b\d{5}-?\d{3}\b')
          .firstMatch(widget.initialClient!.fullAddress);
      if (cepMatch != null) initialCep = cepMatch.group(0)!;
    } else if (widget.initialAddress != null) {
      final cepMatch =
          RegExp(r'\b\d{5}-?\d{3}\b').firstMatch(widget.initialAddress!);
      if (cepMatch != null) initialCep = cepMatch.group(0)!;
    } else if (_searchCtrl.text.isNotEmpty) {
      final cepMatch = RegExp(r'\b\d{5}-?\d{3}\b').firstMatch(_searchCtrl.text);
      if (cepMatch != null) initialCep = cepMatch.group(0)!;
    }

    if (initialCep.isNotEmpty) {
      _cepController.text = initialCep;
      final solarData =
          BrazilSolarIrradiationService.getIrradiationData(cep: initialCep);
      _resolvedState = solarData.uf;
      _resolvedRegion = solarData.region;
      _dailyHsp = solarData.averageDailyHsp;
      _hspController.text = _dailyHsp.toStringAsFixed(2);
    } else {
      _dailyHsp = 5.0;
      _hspController.text = '5.00';
    }
  }

  /// Atualiza o CEP e recalcula a irradiação solar oficial do CRESESB
  void _updateCepAndHsp(String rawCep) {
    final cleanCep = rawCep.trim();
    final solarData =
        BrazilSolarIrradiationService.getIrradiationData(cep: cleanCep);
    setState(() {
      _resolvedState = solarData.uf;
      _resolvedRegion = solarData.region;
      _dailyHsp = solarData.averageDailyHsp;
      _hspController.text = _dailyHsp.toStringAsFixed(2);
    });
  }

  /// Calcula a qualificação de orientação solar para cada seção de telhado
  /// REGRA CRÍTICA: Se o conjunto/seção AINDA NÃO POSSUI SETA DE QUEDA, NÃO gera qualificação!
  /// As placas permanecem na textura fotorrealista natural, sem porcentagem e sem filtro colorido.
  Map<String, SolarOrientationEfficiency> _calculateSectionEfficiencies() {
    final Map<String, SolarOrientationEfficiency> result = {};

    // Vetor que aponta para a ponta vermelha do Norte na tela
    final Offset vNorth = _droneNorthCompass != null
        ? Offset(math.sin(_droneNorthCompass!.rotationRadians),
            -math.cos(_droneNorthCompass!.rotationRadians))
        : const Offset(0.0, -1.0); // Topo do canvas por padrão

    for (final sec in _sections) {
      final arrow = _droneArrows.cast<DroneRoofArrow?>().firstWhere(
            (a) => a?.sectionId == sec.id,
            orElse: () => null,
          );

      // Se ainda não foi adicionada a queda (seta) para esta água, não tem % nem filtro!
      if (arrow == null) continue;

      final vArrow = Offset(
        math.cos(arrow.rotationRadians),
        math.sin(arrow.rotationRadians),
      );

      result[sec.id] =
          BrazilSolarIrradiationService.evaluateOrientationFromVectors(
        roofArrowDir: vArrow,
        northNeedleDir: vNorth,
        cep: _cepController.text,
        uf: _resolvedState,
      );
    }

    final activeSecId =
        _sections.isNotEmpty && _activeSectionIndex < _sections.length
            ? _sections[_activeSectionIndex].id
            : 'active';
    if (!result.containsKey(activeSecId)) {
      final arrow = _droneArrows.cast<DroneRoofArrow?>().firstWhere(
            (a) => a?.sectionId == activeSecId,
            orElse: () => null,
          );

      // Apenas calcula se a água ativa tiver uma seta de queda desenhada!
      if (arrow != null) {
        final vArrow = Offset(
          math.cos(arrow.rotationRadians),
          math.sin(arrow.rotationRadians),
        );

        result[activeSecId] =
            BrazilSolarIrradiationService.evaluateOrientationFromVectors(
          roofArrowDir: vArrow,
          northNeedleDir: vNorth,
          cep: _cepController.text,
          uf: _resolvedState,
        );
      }
    }

    return result;
  }

  /// Calcula a geração mensal estimada em kWh consolidada
  /// Fórmula: HSP × Potência (kWp) × 30 dias × 0.75 (PR) × Fator de Orientação Angular
  double _calculateTotalEstimatedGenerationKwh() {
    final efficiencies = _calculateSectionEfficiencies();
    double totalGen = 0.0;
    int totalActiveModules = 0;

    if (_sections.isNotEmpty) {
      for (final sec in _sections) {
        final activeCount = sec.modules.where((m) => !m.isExcluded).length;
        if (activeCount == 0) continue;
        final kwp = (activeCount * sec.moduleSpec.watts) / 1000.0;
        final eff = efficiencies[sec.id]?.efficiencyFactor ?? 1.0;
        totalGen += BrazilSolarIrradiationService.calculateMonthlyGenerationKwh(
          dailyHsp: _dailyHsp,
          totalKwp: kwp,
          performanceRatio: 0.75,
          efficiencyFactor: eff,
        );
        totalActiveModules += activeCount;
      }
    }

    if (totalActiveModules == 0 && _modules.isNotEmpty) {
      final activeCount = _modules.where((m) => !m.isExcluded).length;
      final kwp = (activeCount * _selectedModule.watts) / 1000.0;
      final activeSecId =
          _sections.isNotEmpty && _activeSectionIndex < _sections.length
              ? _sections[_activeSectionIndex].id
              : 'active';
      final eff = efficiencies[activeSecId]?.efficiencyFactor ?? 1.0;
      totalGen = BrazilSolarIrradiationService.calculateMonthlyGenerationKwh(
        dailyHsp: _dailyHsp,
        totalKwp: kwp,
        performanceRatio: 0.75,
        efficiencyFactor: eff,
      );
    }

    return totalGen;
  }

  /// Baixa a foto do drone salva na nuvem (Firebase Storage ou URL externa)
  Future<void> _downloadDroneImage(String url) async {
    if (_droneImageBytes != null) return;
    setState(() => _isLoadingDronePhoto = true);
    try {
      Uint8List? downloadedBytes;

      // 1. Tenta baixar via Firebase Storage SDK (imune a bloqueios de CORS na Web)
      try {
        final ref = FirebaseStorage.instance.refFromURL(url);
        downloadedBytes = await ref
            .getData(50 * 1024 * 1024)
            .timeout(const Duration(seconds: 25));
      } catch (storageErr) {
        debugPrint(
            '[SolarRoofDesigner] Download via Storage SDK falhou ($storageErr), tentando via http.get...');
      }

      // 2. Se falhar ou não for Storage URL direta, tenta fallback via http.get
      if (downloadedBytes == null || downloadedBytes.isEmpty) {
        final response =
            await http.get(Uri.parse(url)).timeout(const Duration(seconds: 25));
        if (response.statusCode == 200) {
          downloadedBytes = response.bodyBytes;
        }
      }

      if (downloadedBytes != null && downloadedBytes.isNotEmpty && mounted) {
        setState(() {
          _droneImageBytes = downloadedBytes;
          _isLoadingDronePhoto = false;
        });
        if (_studyId != null && _studyId!.isNotEmpty) {
          _cacheDroneImage(_studyId!, downloadedBytes);
        }
      } else {
        if (mounted) setState(() => _isLoadingDronePhoto = false);
      }
    } catch (e) {
      debugPrint('[SolarRoofDesigner] Erro ao baixar foto do drone: $e');
      if (mounted) setState(() => _isLoadingDronePhoto = false);
    }
  }

  /// Salva foto do drone no cache local do dispositivo para carregamento offline/instantâneo
  Future<void> _cacheDroneImage(String studyId, Uint8List bytes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_drone_img_$studyId', base64Encode(bytes));
    } catch (e) {
      debugPrint('[SolarRoofDesigner] Erro ao salvar foto no cache local: $e');
    }
  }

  /// Carrega foto do drone do cache local do dispositivo
  Future<void> _loadCachedDroneImage(String studyId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final base64Str = prefs.getString('cached_drone_img_$studyId');
      if (base64Str != null &&
          base64Str.isNotEmpty &&
          mounted &&
          _droneImageBytes == null) {
        setState(() {
          _droneImageBytes = base64Decode(base64Str);
        });
      }
    } catch (e) {
      debugPrint(
          '[SolarRoofDesigner] Erro ao carregar foto do cache local: $e');
    }
  }

  /// Alterna fluidamente entre Satélite e Drone salvando e restaurando o estado de cada modo
  void _switchMode(BackgroundLayerMode targetMode) {
    if (_backgroundMode == targetMode) return;

    // 1. Salva o estado do modo atual com deep copy total
    _syncCurrentSection();
    if (_backgroundMode == BackgroundLayerMode.satellite) {
      _mapsSections = _sections.map((s) => s.copyWith()).toList();
      _mapsActiveSectionIndex = _activeSectionIndex;
      _mapsPanOffsetX = _panOffsetX;
      _mapsPanOffsetY = _panOffsetY;
      _mapsZoom = _zoom;
    } else if (_backgroundMode == BackgroundLayerMode.dronePhoto) {
      _droneSections = _sections.map((s) => s.copyWith()).toList();
      _droneActiveSectionIndex = _activeSectionIndex;
      _dronePanOffsetX = _panOffsetX;
      _dronePanOffsetY = _panOffsetY;
      _droneZoom = _zoom;
    }

    // 2. Altera o modo e limpa flags de bloqueio transitórias
    _backgroundMode = targetMode;
    _isAnalyzingDrone = false;
    _isLoadingDronePhoto = false;

    // 3. Restaura o estado do novo modo com deep copy
    if (targetMode == BackgroundLayerMode.satellite) {
      _sections.clear();
      if (_mapsSections.isNotEmpty) {
        _sections.addAll(_mapsSections.map((s) => s.copyWith()));
      } else {
        _sections.add(
          RoofSection(
            id: '1',
            name: 'Telhado 1',
            vertices: [],
            modules: [],
            moduleSpec: _selectedModule,
            orientation: _orientation,
            rotationDegrees: 0.0,
            setbackMeters: _setbackMeters,
            themeColor: _sectionPalette[0],
          ),
        );
      }
      _panOffsetX = _mapsPanOffsetX;
      _panOffsetY = _mapsPanOffsetY;
      _zoom = _mapsZoom;
      _activeSectionIndex =
          _mapsActiveSectionIndex.clamp(0, math.max(0, _sections.length - 1));
    } else {
      _sections.clear();
      if (_droneSections.isNotEmpty) {
        _sections.addAll(_droneSections.map((s) => s.copyWith()));
      } else {
        _sections.add(
          RoofSection(
            id: '1',
            name: 'Telhado 1 (Drone)',
            vertices: [],
            modules: [],
            moduleSpec: _selectedModule,
            orientation: _orientation,
            rotationDegrees: 0.0,
            setbackMeters: _setbackMeters,
            themeColor: _sectionPalette[0],
          ),
        );
      }
      _panOffsetX = _dronePanOffsetX;
      _panOffsetY = _dronePanOffsetY;
      _zoom = _droneZoom;
      _activeSectionIndex =
          _droneActiveSectionIndex.clamp(0, math.max(0, _sections.length - 1));
    }

    // 4. Sincroniza ponteiros da seção ativa
    _isSectionFinalized =
        false; // Garante que a seção esteja desbloqueada para edição imediata
    if (_sections.isNotEmpty && _activeSectionIndex < _sections.length) {
      final activeSec = _sections[_activeSectionIndex];
      _roofVertices = List.from(activeSec.vertices);
      _isRoofClosed = activeSec.isClosed;
      _modules = List.from(activeSec.modules);
      _selectedModule = SolarModuleSpec.presets.firstWhere(
        (s) =>
            s.id == activeSec.moduleSpec.id ||
            (s.watts == activeSec.moduleSpec.watts &&
                (s.widthMeters - activeSec.moduleSpec.widthMeters).abs() <
                    0.05),
        orElse: () => activeSec.moduleSpec,
      );
      _orientation = activeSec.orientation;
      _rotationOffsetDegrees = activeSec.rotationDegrees;
      _setbackMeters = activeSec.setbackMeters;
      _toolMode = activeSec.isClosed
          ? DesignerToolMode.editModules
          : DesignerToolMode.drawRoof;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _orientationScrollController.dispose();
    _snapHighlightTimer?.cancel();
    _searchCtrl.dispose();
    _cepController.dispose();
    _hspController.dispose();
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

  /// Realiza o upload da foto do drone para o Firebase Storage em segundo plano enquanto o usuário desenha
  Future<String?> _uploadDroneImageInBackground(Uint8List bytes) {
    final storageId =
        _studyId ?? 'study_${DateTime.now().millisecondsSinceEpoch}';
    final future = () async {
      try {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('roof_studies')
            .child('drone')
            .child('${storageId}_drone.jpg');
        final uploadTask = storageRef.putData(
          bytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        final snapshot = await uploadTask.timeout(const Duration(seconds: 45));
        final url = await snapshot.ref.getDownloadURL();
        if (mounted) {
          setState(() => _droneImageUrl = url);
        } else {
          _droneImageUrl = url;
        }
        return url;
      } catch (e) {
        debugPrint('[SolarRoofDesigner] Aviso no upload em background: $e');
        return null;
      }
    }();
    _droneUploadFuture = future;
    return future;
  }

  // ── Upload de Foto de Drone ──────────────────────────────────────────────
  Future<void> _pickDronePhoto() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      );

      if (files.isEmpty) return;

      final file = files.first;
      final b = await file.readAsBytes();
      if (b.isEmpty || !mounted) return;

      // Dispara o upload no Firebase Storage imediatamente em segundo plano
      _uploadDroneImageInBackground(b);

      // 1. Salva o estado do modo atual se estiver no satélite
      _syncCurrentSection();
      if (_backgroundMode == BackgroundLayerMode.satellite) {
        _mapsSections = List.from(_sections);
        _mapsPanOffsetX = _panOffsetX;
        _mapsPanOffsetY = _panOffsetY;
        _mapsZoom = _zoom;
      }

      // 2. Verifica se já existem módulos ou desenho nesta água/drone
      final bool hasExistingDrawing = _droneSections
              .any((s) => s.vertices.isNotEmpty || s.modules.isNotEmpty) ||
          (_backgroundMode == BackgroundLayerMode.dronePhoto &&
              (_roofVertices.isNotEmpty || _modules.isNotEmpty));

      String? userDecision = 'keep'; // padrão se for primeira imagem
      if (hasExistingDrawing) {
        userDecision = await showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF0F172A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFF38BDF8), width: 1.2),
            ),
            title: Row(
              children: [
                const Icon(Icons.help_outline_rounded,
                    color: Color(0xFF38BDF8), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Substituir Imagem do Drone',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                ),
              ],
            ),
            content: Text(
              'Já existem módulos e telhado demarcados neste estudo.\n\nDeseja limpar os módulos ou apenas trocar a imagem?',
              style: GoogleFonts.inter(
                color: const Color(0xFFCBD5E1),
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
            actionsAlignment: MainAxisAlignment.spaceBetween,
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null), // Cancelar
                child: Text(
                  'Cancelar',
                  style: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, 'clear'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: const BorderSide(color: Color(0xFFEF4444)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(
                      'Limpar Tudo',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, 'keep'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                    ),
                    child: Text(
                      'Apenas trocar imagem e manter os módulos',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }

      if (userDecision == null || !mounted) return; // Usuário cancelou

      if (userDecision == 'clear') {
        // Limpa tudo e inicializa do zero
        setState(() {
          _droneImageBytes = b;
          _droneImageUrl = null;
          _droneImageFileName = file.name;
          _backgroundMode = BackgroundLayerMode.dronePhoto;
          _customDroneMetersPerPixel = 0.025;
          _panOffsetX = 0.0;
          _panOffsetY = 0.0;
          _zoom = 18.0;

          _sections.clear();
          _sections.add(
            RoofSection(
              id: '1',
              name: 'Telhado 1 (Drone)',
              vertices: [],
              modules: [],
              moduleSpec: _selectedModule,
              orientation: _orientation,
              rotationDegrees: 0.0,
              setbackMeters: _setbackMeters,
              themeColor: _sectionPalette[0],
            ),
          );
          _droneSections = List.from(_sections);
          _activeSectionIndex = 0;
          _roofVertices.clear();
          _isRoofClosed = false;
          _modules.clear();
          _isAnalyzingDrone = true;
          _toolMode = DesignerToolMode.pan;
        });
      } else {
        // 'keep': Apenas troca imagem e mantém os módulos e o telhado intactos!
        setState(() {
          _droneImageBytes = b;
          _droneImageUrl = null;
          _droneImageFileName = file.name;
          _backgroundMode = BackgroundLayerMode.dronePhoto;
          _isAnalyzingDrone = true;
          _toolMode = DesignerToolMode.pan;
        });
      }

      if (_studyId != null && _studyId!.isNotEmpty) {
        _cacheDroneImage(_studyId!, b);
      }

      // Dispara a análise com IA Gemini Vision de forma silenciosa para métricas
      _analyzeDroneWithGemini();
    } catch (e) {
      debugPrint('[SolarRoofDesigner] Erro ao carregar foto do drone: $e');
      if (mounted) {
        setState(() => _isAnalyzingDrone = false);
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
      ).timeout(const Duration(seconds: 12));

      if (mounted) {
        // Libera desenhar sobre a imagem somente DEPOIS que a IA terminar de carregar
        setState(() {
          _droneAnalysisResult = result;
          _isAnalyzingDrone = false;
          if (_roofVertices.isEmpty && !_isRoofClosed) {
            _toolMode = DesignerToolMode.drawRoof;
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.auto_awesome_rounded, color: Colors.amber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'IA Gemini analisou o drone: ${result.roofType} (~${result.estimatedAreaM2.toStringAsFixed(1)} m²). Clique nos cantos do telhado para desenhar!',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600, fontSize: 12.5),
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
        // Libera o desenho mesmo com erro da IA para não prender o operador
        setState(() {
          _isAnalyzingDrone = false;
          if (_roofVertices.isEmpty && !_isRoofClosed) {
            _toolMode = DesignerToolMode.drawRoof;
          }
        });
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
    if (_roofVertices.length < 2 ||
        edgeIndex < 0 ||
        edgeIndex >= _roofVertices.length) {
      return;
    }

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
        _syncCurrentSection();
      });
      if (_isRoofClosed && _modules.isEmpty) {
        _autoFillModules();
      }
    }
  }

  // ── Adição e Movimentação Manual de Módulos (Conforme Solicitado) ────────
  void _addSingleModule() {
    if (!_isAnyPolygonSelected) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Faça um desenho de um telhado e selecione-o para adicionar módulos',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          backgroundColor: const Color(0xFF0F172A),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final width = _orientation == ModuleOrientation.portrait
        ? _selectedModule.widthMeters
        : _selectedModule.heightMeters;
    final height = _orientation == ModuleOrientation.portrait
        ? _selectedModule.heightMeters
        : _selectedModule.widthMeters;
    final rot = _rotationOffsetDegrees * math.pi / 180.0;

    // Quando o usuário adiciona placas avulsas pelo menu superior, a seleção fica em MÓDULOS
    _toolMode = DesignerToolMode.editModules;

    if (_modules.isEmpty) {
      // Se não há módulos, coloca no centro do telhado ou na mira central
      final center = _roofVertices.isNotEmpty
          ? _roofPolygon.centroid
          : const RoofPoint(0, 0);
      _clusterCounter = 1;
      _activeClusterId = 'conjunto_$_clusterCounter';
      _isCurrentClusterFinalized = false;

      setState(() {
        _modules.add(PlacedModule(
          id: 'mod_manual_${DateTime.now().millisecondsSinceEpoch}',
          rowId: _activeClusterId,
          center: center,
          widthMeters: width,
          heightMeters: height,
          rotationRadians: rot,
          watts: _selectedModule.watts,
        ));
        _selectedModuleIndex = 0;
        _adaptRoofToFitModules();
        _syncCurrentSection();
      });
      return;
    }

    // Se o conjunto anterior foi concluído ou nenhum conjunto está ativo, inicia um NOVO conjunto desacoplado do anterior!
    if (_isCurrentClusterFinalized || _activeClusterId == null) {
      _clusterCounter++;
      _activeClusterId = 'conjunto_$_clusterCounter';
      _isCurrentClusterFinalized = false;

      // Calcula posição desvinculada do conjunto anterior (abaixo das placas existentes)
      double maxY = -double.infinity;
      double avgX = 0;
      int count = 0;
      for (final m in _modules.where((m) => !m.isExcluded)) {
        if (m.center.y > maxY) maxY = m.center.y;
        avgX += m.center.x;
        count++;
      }
      final double startX = count > 0 ? (avgX / count) : 0.0;
      final double startY =
          maxY != -double.infinity ? (maxY + height + 0.8) : 0.0;

      setState(() {
        final newMod = PlacedModule(
          id: 'mod_manual_${DateTime.now().millisecondsSinceEpoch}_${_modules.length}',
          rowId: _activeClusterId,
          center: RoofPoint(startX, startY),
          widthMeters: width,
          heightMeters: height,
          rotationRadians: rot,
          watts: _selectedModule.watts,
        );
        _modules = List.from(_modules)..add(newMod);
        _selectedModuleIndex = _modules.length - 1;
        _adaptRoofToFitModules();
        _syncCurrentSection();
      });
      return;
    }

    // Se já existe um conjunto ativo, anexa a nova placa à direita da última placa DESSE conjunto ativo
    final clusterMods = _modules
        .where((m) => m.rowId == _activeClusterId && !m.isExcluded)
        .toList();
    final last = clusterMods.isNotEmpty ? clusterMods.last : _modules.last;

    const spacing = 0.02; // 2cm de folga entre placas
    final step = last.widthMeters + spacing;

    final dx = step * math.cos(last.rotationRadians);
    final dy = step * math.sin(last.rotationRadians);

    setState(() {
      final newMod = PlacedModule(
        id: 'mod_manual_${DateTime.now().millisecondsSinceEpoch}_${_modules.length}',
        rowId: _activeClusterId,
        center: RoofPoint(last.center.x + dx, last.center.y + dy),
        widthMeters: width,
        heightMeters: height,
        rotationRadians: last.rotationRadians,
        watts: _selectedModule.watts,
      );
      _modules = List.from(_modules)..add(newMod);
      _selectedModuleIndex = _modules.length - 1;
      _adaptRoofToFitModules();
      _syncCurrentSection();
    });
  }

  /// Finaliza o conjunto de placas em edição, permitindo adicionar novos conjuntos desacoplados no mesmo telhado
  void _concludeCurrentCluster() {
    setState(() {
      _isCurrentClusterFinalized = true;
      _activeClusterId = null;
      _selectedModuleIndex = -1;
      _syncCurrentSection();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Color(0xFF10B981), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Conjunto de placas concluído! Clique em "+ Placa" para iniciar outro conjunto ou clique no conjunto anterior para reativá-lo.',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xFF10B981), width: 1.2),
        ),
      ),
    );
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
    final newCenter = RoofPoint(newCenterX, newCenterY);

    // ── VALIDAÇÃO DE SOBREPOSIÇÃO ───────────────────────────────────────────
    // Se o ponto desejado já estiver ocupado por outra placa (ex: usuário clicou
    // numa placa central em vez da ponta), bloqueia e orienta a selecionar a extremidade.
    final double minDim = math.min(w, h);
    bool isOverlapping = false;
    for (final m in _modules) {
      if (m.isExcluded) continue;
      if (newCenter.distanceTo(m.center) < minDim * 0.75) {
        isOverlapping = true;
        break;
      }
    }

    if (isOverlapping) {
      _showOverlappingModuleAlert();
      return;
    }

    setState(() {
      final newMod = PlacedModule(
        id: 'mod_manual_${DateTime.now().millisecondsSinceEpoch}_${_modules.length}',
        rowId: target
            .rowId, // mantém vinculada à fileira caso a placa pertença a uma
        center: RoofPoint(newCenterX, newCenterY),
        widthMeters: w,
        heightMeters: h,
        rotationRadians: rot,
        watts: target.watts,
      );
      _modules = List.from(_modules)..add(newMod);
      _selectedModuleIndex = _modules.length -
          1; // Seleciona imediatamente a nova placa adicionada!
      _adaptRoofToFitModules();
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

  /// Alerta modal orientando o usuário a selecionar uma placa da extremidade quando houver sobreposição
  void _showOverlappingModuleAlert() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFF59E0B),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Espaço Já Ocupado',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Já existe uma placa solar posicionada nesse ponto.',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Para expandir a fileira nessa direção:',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF38BDF8),
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('1. ',
                          style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.bold)),
                      Expanded(
                        child: Text(
                          'Selecione a placa da ponta (extremidade) da fileira.',
                          style: GoogleFonts.inter(
                              color: Colors.white70, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('2. ',
                          style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.bold)),
                      Expanded(
                        child: Text(
                          'Clique novamente em "+ Placa" e escolha a direção para estender o arranjo livremente.',
                          style: GoogleFonts.inter(
                              color: Colors.white70, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: Text(
              'ENTENDIDO',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Ajusta dinamicamente os vértices do polígono do telhado para contornar
  /// de forma harmoniosa o arranjo de placas solares restantes, mantendo o recuo padrão (setback).
  void _adaptRoofToFitModules() {
    if (_modules.isEmpty) return;
    if (_roofVertices.isEmpty) return;

    final activeModules = _modules.where((m) => !m.isExcluded).toList();
    if (activeModules.isEmpty) return;

    // Rotação base do arranjo (da primeira placa ativa)
    final double rot = activeModules.first.rotationRadians;
    final double uX = math.cos(rot);
    final double uY = math.sin(rot);
    final double vX = -math.sin(rot);
    final double vY = math.cos(rot);

    // Centróide de referência de todas as placas
    double sumX = 0, sumY = 0;
    for (final m in activeModules) {
      sumX += m.center.x;
      sumY += m.center.y;
    }
    final pivot =
        RoofPoint(sumX / activeModules.length, sumY / activeModules.length);

    // Limites (min/max) de todas as placas nos eixos U e V relativos ao pivô
    double minU = double.infinity, maxU = -double.infinity;
    double minV = double.infinity, maxV = -double.infinity;

    for (final m in activeModules) {
      for (final c in m.getCorners()) {
        final relX = c.x - pivot.x;
        final relY = c.y - pivot.y;
        final projU = relX * uX + relY * uY;
        final projV = relX * vX + relY * vY;

        if (projU < minU) minU = projU;
        if (projU > maxU) maxU = projU;
        if (projV < minV) minV = projV;
        if (projV > maxV) maxV = projV;
      }
    }

    // Recuo padrão harmonioso (setback ~0.25m a 0.30m)
    final double margin = (_setbackMeters >= 0.15) ? _setbackMeters : 0.25;

    final double boundMinU = minU - margin;
    final double boundMaxU = maxU + margin;
    final double boundMinV = minV - margin;
    final double boundMaxV = maxV + margin;

    // Constrói os 4 cantos do polígono orientados na rotação exata das placas:
    _roofVertices = [
      RoofPoint(
        pivot.x + boundMinU * uX + boundMinV * vX,
        pivot.y + boundMinU * uY + boundMinV * vY,
      ),
      RoofPoint(
        pivot.x + boundMaxU * uX + boundMinV * vX,
        pivot.y + boundMaxU * uY + boundMinV * vY,
      ),
      RoofPoint(
        pivot.x + boundMaxU * uX + boundMaxV * vX,
        pivot.y + boundMaxU * uY + boundMaxV * vY,
      ),
      RoofPoint(
        pivot.x + boundMinU * uX + boundMaxV * vX,
        pivot.y + boundMinU * uY + boundMaxV * vY,
      ),
    ];
    _isRoofClosed = true;
  }

  void _removeSingleModule() {
    if (_modules.isNotEmpty) {
      setState(() {
        _modules.removeLast();
        _adaptRoofToFitModules();
        _syncCurrentSection();
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

  /// Auto-alinha (Snap Magnético) uma placa com a placa vizinha mais próxima.
  /// Nivela perfeitamente o topo/base (snap lateral) ou laterais (snap vertical),
  /// aplicando o espaçamento de presilha de 2cm e igualando o paralelismo angular.
  bool _applyMagneticSnapping(int index) {
    if (index < 0 || index >= _modules.length) return false;

    final dragged = _modules[index];
    if (dragged.isExcluded) return false;

    PlacedModule? bestNeighbor;
    RoofPoint? bestSnappedCenter;
    double bestDistance = double.infinity;
    String? bestNeighborRowId;
    double bestSnappedRotation = dragged.rotationRadians;

    final wDragged = dragged.widthMeters;
    final hDragged = dragged.heightMeters;
    const spacing = 0.02; // 2cm padrão entre módulos fotovoltaicos

    for (int i = 0; i < _modules.length; i++) {
      if (i == index) continue;
      final other = _modules[i];
      if (other.isExcluded) continue;

      // Vetores unitários no sistema de coordenadas da placa de referência (other)
      final rot = other.rotationRadians;
      final uX = math.cos(rot);
      final uY = math.sin(rot);
      final vX = -math.sin(rot);
      final vY = math.cos(rot);

      // Vetor delta do centro de other para o centro de dragged
      final dx = dragged.center.x - other.center.x;
      final dy = dragged.center.y - other.center.y;

      // Projeção nos eixos U (largura) e V (comprimento)
      final distU = dx * uX + dy * uY;
      final distV = dx * vX + dy * vY;

      final wTarget = other.widthMeters;
      final hTarget = other.heightMeters;

      // ── 1. SNAP LATERAL (Lado a Lado - Direita ou Esquerda) ─────────────
      final gapU = distU.abs() - (wTarget + wDragged) / 2.0;

      // Tolerância calibrada: ativa apenas quando estiver próximo (vão livre até 22cm)
      // Evita atrair módulos que o usuário queira deixar afastados
      if (gapU >= -0.20 && gapU <= 0.22 && distV.abs() <= hTarget * 0.35) {
        final snapSignU = distU >= 0 ? 1.0 : -1.0;
        final snappedDistU = snapSignU * ((wTarget + wDragged) / 2.0 + spacing);
        final snappedDistV =
            0.0; // Nivelamento vertical perfeito de topo e base!

        final candidateCenterX =
            other.center.x + (snappedDistU * uX + snappedDistV * vX);
        final candidateCenterY =
            other.center.y + (snappedDistU * uY + snappedDistV * vY);
        final candidateCenter = RoofPoint(candidateCenterX, candidateCenterY);

        // Verifica se essa posição de encaixe não colide com uma terceira placa existente
        bool collidesWithThird = false;
        for (int k = 0; k < _modules.length; k++) {
          if (k == index || k == i) continue;
          if (_modules[k].isExcluded) continue;
          if (candidateCenter.distanceTo(_modules[k].center) <
              math.min(wDragged, hDragged) * 0.70) {
            collidesWithThird = true;
            break;
          }
        }

        if (!collidesWithThird) {
          final distFromCurrent = candidateCenter.distanceTo(dragged.center);
          if (distFromCurrent < bestDistance && distFromCurrent <= 0.38) {
            bestDistance = distFromCurrent;
            bestNeighbor = other;
            bestSnappedCenter = candidateCenter;
            bestNeighborRowId = other.rowId;
            bestSnappedRotation = other.rotationRadians;
          }
        }
      }

      // ── 2. SNAP VERTICAL (Mesma Coluna - Acima ou Abaixo) ───────────────
      final gapV = distV.abs() - (hTarget + hDragged) / 2.0;

      // Tolerância calibrada: ativa apenas quando estiver próximo (vão livre até 22cm)
      if (gapV >= -0.20 && gapV <= 0.22 && distU.abs() <= wTarget * 0.35) {
        final snapSignV = distV >= 0 ? 1.0 : -1.0;
        final snappedDistV = snapSignV * ((hTarget + hDragged) / 2.0 + spacing);
        final snappedDistU = 0.0; // Alinhamento lateral perfeito na coluna!

        final candidateCenterX =
            other.center.x + (snappedDistU * uX + snappedDistV * vX);
        final candidateCenterY =
            other.center.y + (snappedDistU * uY + snappedDistV * vY);
        final candidateCenter = RoofPoint(candidateCenterX, candidateCenterY);

        // Verifica se essa posição de encaixe não colide com uma terceira placa existente
        bool collidesWithThird = false;
        for (int k = 0; k < _modules.length; k++) {
          if (k == index || k == i) continue;
          if (_modules[k].isExcluded) continue;
          if (candidateCenter.distanceTo(_modules[k].center) <
              math.min(wDragged, hDragged) * 0.70) {
            collidesWithThird = true;
            break;
          }
        }

        if (!collidesWithThird) {
          final distFromCurrent = candidateCenter.distanceTo(dragged.center);
          if (distFromCurrent < bestDistance && distFromCurrent <= 0.38) {
            bestDistance = distFromCurrent;
            bestNeighbor = other;
            bestSnappedCenter = candidateCenter;
            bestNeighborRowId = other.rowId;
            bestSnappedRotation = other.rotationRadians;
          }
        }
      }
    }

    if (bestNeighbor != null && bestSnappedCenter != null) {
      setState(() {
        _modules[index] = dragged.copyWith(
          center: bestSnappedCenter,
          rotationRadians: bestSnappedRotation,
          rowId: bestNeighborRowId ?? dragged.rowId,
        );
        _snappedModuleIndex = index;
      });

      _snapHighlightTimer?.cancel();
      _snapHighlightTimer = Timer(const Duration(milliseconds: 1600), () {
        if (mounted) {
          setState(() => _snappedModuleIndex = null);
        }
      });

      _syncCurrentSection();
      return true;
    }

    return false;
  }

  void _handleModuleDragEnd(int index) {
    final didSnap = _applyMagneticSnapping(index);
    if (didSnap && mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.auto_awesome_rounded,
                  color: Color(0xFF10B981), size: 18),
              const SizedBox(width: 8),
              Text(
                'Módulo colado e alinhado com precisão!',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold, fontSize: 12.5),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF0F172A),
          duration: const Duration(milliseconds: 1200),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    _syncCurrentSection();
  }

  void _handleModuleGroupMoved(double dxMeters, double dyMeters) {
    setState(() {
      if (_activeClusterId != null) {
        _modules = _modules.map((m) {
          if (m.rowId == _activeClusterId) {
            return m.translate(dxMeters, dyMeters);
          }
          return m;
        }).toList();
      } else {
        _modules = _modules.map((m) => m.translate(dxMeters, dyMeters)).toList();
      }
      _syncCurrentSection();
    });
  }

  /// Move o polígono do telhado junto com todas as placas solares
  void _handleDrawingMoved(double dxMeters, double dyMeters) {
    setState(() {
      _roofVertices = _roofVertices
          .map((v) => RoofPoint(v.x + dxMeters, v.y + dyMeters))
          .toList();
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

    final targetMods = _activeClusterId != null
        ? _modules
            .where((m) => m.rowId == _activeClusterId && !m.isExcluded)
            .toList()
        : _modules.where((m) => !m.isExcluded).toList();

    if (targetMods.isEmpty) return;

    // Centróide do arranjo do conjunto ativo
    double sumX = 0, sumY = 0;
    for (final m in targetMods) {
      sumX += m.center.x;
      sumY += m.center.y;
    }
    final pivot = RoofPoint(sumX / targetMods.length, sumY / targetMods.length);

    setState(() {
      _modules = _modules.map((m) {
        if (_activeClusterId == null || m.rowId == _activeClusterId) {
          return m.rotateAround(pivot, math.pi / 2);
        }
        return m;
      }).toList();
      _rotationOffsetDegrees = (_rotationOffsetDegrees + 90.0) % 360.0;
      _orientation = _orientation == ModuleOrientation.portrait
          ? ModuleOrientation.landscape
          : ModuleOrientation.portrait;
      _syncCurrentSection();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Conjunto rotacionado em 90° (${_orientation == ModuleOrientation.portrait ? "Retrato" : "Paisagem"})!',
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

    final targetMods = _activeClusterId != null
        ? _modules
            .where((m) => m.rowId == _activeClusterId && !m.isExcluded)
            .toList()
        : _modules.where((m) => !m.isExcluded).toList();

    if (targetMods.isEmpty) return;

    double sumX = 0, sumY = 0;
    for (final m in targetMods) {
      sumX += m.center.x;
      sumY += m.center.y;
    }
    final pivot = RoofPoint(sumX / targetMods.length, sumY / targetMods.length);

    setState(() {
      _modules = _modules.map((m) {
        if (_activeClusterId == null || m.rowId == _activeClusterId) {
          return m.rotateAround(pivot, deltaRadians);
        }
        return m;
      }).toList();
      _rotationOffsetDegrees =
          (_rotationOffsetDegrees + deltaRadians * 180.0 / math.pi) % 360.0;
      _syncCurrentSection();
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
      _selectedModuleIndex = -1;
      _adaptRoofToFitModules();
      _syncCurrentSection();
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
                            color:
                                const Color(0xFF38BDF8).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.table_rows_rounded,
                              color: Color(0xFF38BDF8), size: 22),
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
                          icon: const Icon(Icons.close_rounded,
                              color: Colors.white60, size: 20),
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
                            onTap: () => setDialogState(
                                () => selectedDirection = RowDirection.above),
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
                            onTap: () => setDialogState(
                                () => selectedDirection = RowDirection.below),
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
                            onTap: () => setDialogState(
                                () => selectedDirection = RowDirection.left),
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
                            onTap: () => setDialogState(
                                () => selectedDirection = RowDirection.right),
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
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
                            icon: const Icon(
                                Icons.remove_circle_outline_rounded,
                                color: Color(0xFF38BDF8),
                                size: 28),
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
                                style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: const Color(0xFF10B981),
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          IconButton(
                            onPressed: moduleCount < 30
                                ? () => setDialogState(() => moduleCount++)
                                : null,
                            icon: const Icon(Icons.add_circle_outline_rounded,
                                color: Color(0xFF38BDF8), size: 28),
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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isSel
                                  ? const Color(0xFF38BDF8)
                                  : const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$cnt pl',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isSel
                                    ? const Color(0xFF0F172A)
                                    : Colors.white70,
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
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            child: Text('Cancelar',
                                style:
                                    GoogleFonts.inter(color: Colors.white70)),
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
                              style: GoogleFonts.outfit(
                                  fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF38BDF8),
                              foregroundColor: const Color(0xFF0F172A),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
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
          color: selected
              ? const Color(0xFF38BDF8).withValues(alpha: 0.15)
              : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFF38BDF8) : const Color(0xFF334155),
            width: selected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: selected
                    ? const Color(0xFF38BDF8)
                    : const Color(0xFF94A3B8),
                size: 18),
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

  void _addModuleRow(
      RowDirection direction, int count, ModuleOrientation orientation) {
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
      _adaptRoofToFitModules();
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
      _adaptRoofToFitModules();
      _syncCurrentSection();
    });
  }

  // ── Múltiplas Águas de Telhado (Finalizar, Nova Água, Alternar) ───────────
  void _syncCurrentSection() {
    if (_sections.isEmpty) {
      _sections.add(
        RoofSection(
          id: '1',
          name: 'Telhado 1',
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
    if (index < 0 || index >= _sections.length || index == _activeSectionIndex) {
      return;
    }
    _syncCurrentSection();
    setState(() {
      _activeSectionIndex = index;
      _isSectionFinalized = false;
      _isCurrentClusterFinalized = false;
      final sec = _sections[index];
      _roofVertices = List.from(sec.vertices);
      _isRoofClosed = sec.isClosed;
      _modules = List.from(sec.modules);
      _activeClusterId = _modules.isNotEmpty ? _modules.last.rowId : null;
      _selectedModule = sec.moduleSpec;
      _orientation = sec.orientation;
      _rotationOffsetDegrees = sec.rotationDegrees;
      _setbackMeters = sec.setbackMeters;
      _toolMode = sec.isClosed
          ? DesignerToolMode.editModules
          : DesignerToolMode.drawRoof;
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
    _syncArrowsWithSections();
    setState(() {
      _isSectionFinalized = true;
      _toolMode = DesignerToolMode.pan;
      _selectedModuleIndex = -1;
      _selectedDroneArrowId = null;
    });
    final currentSec = _sections[_activeSectionIndex];

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${currentSec.name} concluído com sucesso (${currentSec.activeModuleCount} placas • ${currentSec.totalKwp.toStringAsFixed(2)} kWp)!',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF10B981),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _addNewSection() {
    // Se o telhado atual já está vazio sem nenhum desenho, vai direto para o modo DESENHAR
    if (_roofVertices.isEmpty && _modules.isEmpty) {
      setState(() {
        _toolMode = DesignerToolMode.drawRoof;
        _isRoofClosed = false;
        _isSectionFinalized = false;
        _isCurrentClusterFinalized = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Telhado pronto para desenho! Clique no mapa/foto para marcar os cantos.',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFF6366F1),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    _syncCurrentSection();

    final newIndex = _sections.length;
    final newColor = _sectionPalette[newIndex % _sectionPalette.length];
    final newSec = RoofSection(
      id: '${newIndex + 1}',
      name: 'Telhado ${newIndex + 1}',
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
          'Novo Telhado ${newIndex + 1} criado! Clique nos cantos para demarcar.',
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
            'Desenhe o telhado ou adicione placas antes de duplicar o telhado.',
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
      final double distV =
          (p.x - ridgeAnchorX) * vX + (p.y - ridgeAnchorY) * vY;
      final double mirroredX = p.x - 2.0 * distV * vX;
      final double mirroredY = p.y - 2.0 * distV * vY;
      return RoofPoint(mirroredX, mirroredY);
    }

    // 4. Espelha os vértices do polígono do telhado
    final List<RoofPoint> mirroredVertices =
        _roofVertices.map(mirrorPointAcrossRidge).toList();

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
      name: 'Telhado ${newIndex + 1}',
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
          'Telhado ${newIndex + 1} criado e encaixado na cumeeira oposta!',
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
      _activeSectionIndex = (_activeSectionIndex >= _sections.length)
          ? _sections.length - 1
          : _activeSectionIndex;
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
              child: const Icon(Icons.screen_rotation_alt_rounded,
                  color: Color(0xFF6366F1), size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              'Definir Ângulo de Rotação',
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
              'Digite o ângulo exato em graus (0° a 360°) ou clique em um atalho:',
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
                labelText: 'Ângulo da Placa (°)',
                labelStyle: GoogleFonts.inter(
                    color: const Color(0xFF94A3B8), fontSize: 13),
                suffixText: 'graus',
                suffixStyle: GoogleFonts.inter(
                    color: const Color(0xFF38BDF8),
                    fontWeight: FontWeight.bold),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF334155))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: Color(0xFF6366F1), width: 1.5)),
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
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [0.0, 15.0, 30.0, 45.0, 90.0, 180.0, 270.0].map((deg) {
                return ActionChip(
                  label: Text('${deg.toInt()}°',
                      style:
                          GoogleFonts.inter(fontSize: 11, color: Colors.white)),
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
            child: Text('Cancelar',
                style: GoogleFonts.inter(color: const Color(0xFF94A3B8))),
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Aplicar Ângulo',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
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
    // Bloqueia qualquer ação de desenho se a IA ainda estiver analisando a foto do drone ou baixando
    if ((_isAnalyzingDrone || _isLoadingDronePhoto) &&
        _backgroundMode == BackgroundLayerMode.dronePhoto) {
      return;
    }

    // Bloqueia se estiver no modo drone mas nenhuma foto foi carregada ainda
    if (_backgroundMode == BackgroundLayerMode.dronePhoto &&
        _droneImageBytes == null) {
      return;
    }

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
      // Se a água atual já está delimitada com o polígono fechado:
      // Conclui a água atual e vai para Navegar, aguardando que o operador crie uma nova água quando desejar
      if (_isRoofClosed && _roofVertices.length >= 3) {
        _finishCurrentSection();
        return;
      }

      setState(() {
        _isSectionFinalized = false;

        // Se clicou muito perto do primeiro vértice, fecha o polígono
        if (_roofVertices.length >= 3) {
          final first = _roofVertices.first;
          final firstScreenPos = Offset(
            canvasCenter.dx +
                RoofGeometryService.metersToPixels(first.x, _metersPerPixel),
            canvasCenter.dy +
                RoofGeometryService.metersToPixels(first.y, _metersPerPixel),
          );
          final distPixels = (localPos - firstScreenPos).distance;

          if (distPixels <= 24.0) {
            _isRoofClosed = true;
            _toolMode = DesignerToolMode.editModules;
            _syncArrowsWithSections();
            _autoFillModules();
            return;
          }
        }
        _roofVertices.add(pointMeters);
      });
      return;
    } else if (_toolMode == DesignerToolMode.editModules) {
      // Alterna a exclusão da placa clicada (contornar chaminés, etc.)
      final hit = ModuleLayoutEngine.findModuleAtPoint(pointMeters, _modules);
      if (hit != null) {
        setState(() {
          hit.isExcluded = !hit.isExcluded;
        });
        return;
      } else if (_roofVertices.isEmpty) {
        // Se a seção atual está vazia e clicou na tela, inicia o desenho instantaneamente (se permitido)!
        if (_backgroundMode == BackgroundLayerMode.dronePhoto && !_hasDronePhoto) {
          return;
        }
        setState(() {
          _toolMode = DesignerToolMode.drawRoof;
          _isSectionFinalized = false;
          _isRoofClosed = false;
          _roofVertices = [pointMeters];
          _selectedDroneArrowId = null;
          _selectedModuleIndex = -1;
        });
        return;
      }
      // Clicou fora das placas / espaço vazio: deseleciona tudo (setas, placas)!
      setState(() {
        _selectedDroneArrowId = null;
        _selectedModuleIndex = -1;
      });
    } else {
      // Qualquer outro modo: ao clicar no vazio, deseleciona tudo!
      setState(() {
        _selectedDroneArrowId = null;
        _selectedModuleIndex = -1;
      });
    }
  }

  // ── Fechar Telhado com Duplo Clique ──────────────────────────────────────
  void _handleCanvasDoubleTap() {
    if (_toolMode == DesignerToolMode.drawRoof &&
        _roofVertices.length >= 3 &&
        !_isRoofClosed) {
      setState(() {
        _isRoofClosed = true;
        _toolMode = DesignerToolMode.editModules;
        _syncArrowsWithSections();
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
      _toolMode = DesignerToolMode.editModules;
    });
  }

  // ── Limpar Desenho do Telhado ─────────────────────────────────────────────
  void _clearRoof() {
    setState(() {
      _roofVertices.clear();
      _isRoofClosed = false;
      _modules.clear();
      _selectedModuleIndex = -1;
      _toolMode = DesignerToolMode.drawRoof;
      if (_activeSectionIndex >= 0 && _activeSectionIndex < _sections.length) {
        _sections[_activeSectionIndex] =
            _sections[_activeSectionIndex].copyWith(
          vertices: [],
          isClosed: false,
          modules: [],
        );
      }
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

  // ── Persistência do Estudo no Firestore ─────────────────────────────────
  Future<RoofStudyModel?> _saveRoofStudy({bool showFeedback = true}) async {
    if (_isSavingStudy) return null;
    setState(() => _isSavingStudy = true);

    try {
      _syncCurrentSection();

      // Sincroniza o estado atual na respectiva lista independente
      if (_backgroundMode == BackgroundLayerMode.satellite) {
        _mapsSections = List.from(_sections);
        _mapsPanOffsetX = _panOffsetX;
        _mapsPanOffsetY = _panOffsetY;
        _mapsZoom = _zoom;
      } else if (_backgroundMode == BackgroundLayerMode.dronePhoto) {
        _droneSections = List.from(_sections);
        _dronePanOffsetX = _panOffsetX;
        _dronePanOffsetY = _panOffsetY;
        _droneZoom = _zoom;
      }

      // Se houver foto de drone em memória que ainda não subiu para a nuvem, verifica se já concluiu em background (sem travar o salvamento)
      String? finalDroneImageUrl = _droneImageUrl;
      if (_droneImageBytes != null &&
          (finalDroneImageUrl == null || finalDroneImageUrl.isEmpty)) {
        if (_droneUploadFuture != null) {
          try {
            // Dá tolerância de no máximo 800ms se o upload em background já estiver prestes a concluir
            finalDroneImageUrl =
                await _droneUploadFuture!.timeout(const Duration(milliseconds: 800));
            _droneImageUrl = finalDroneImageUrl;
          } catch (_) {
            // Se ainda não concluiu, NÃO TRAVA o salvamento: prossegue imediatamente para o Firestore!
          }
        } else {
          // Se por algum motivo não havia disparado o upload em background, dispara agora de forma assíncrona
          _uploadDroneImageInBackground(_droneImageBytes!);
        }
      }

      // Captura thumbnail compacta otimizada para o Firestore (< 60KB)
      String? base64Snapshot;
      try {
        final boundary = _canvasKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
        if (boundary != null && boundary.size.width > 0) {
          // Reduz a escala para gerar uma imagem miniatura compacta (~220px)
          final scaleRatio = (220.0 / boundary.size.width).clamp(0.08, 0.25);
          final image = await boundary.toImage(pixelRatio: scaleRatio);
          final byteData =
              await image.toByteData(format: ui.ImageByteFormat.png);
          if (byteData != null) {
            final bytes = byteData.buffer.asUint8List();
            if (bytes.length < 350000) {
              base64Snapshot = base64Encode(bytes);
            }
          }
        }
      } catch (e) {
        debugPrint(
            '[SolarRoofDesigner] Erro ao capturar thumbnail para salvar: $e');
      }

      int totalModules = 0;
      double totalWatts = 0;

      for (final sec in _sections) {
        totalModules += sec.activeModuleCount;
        totalWatts += sec.activeModuleCount * sec.moduleSpec.watts;
      }
      if (_sections.isEmpty) {
        totalModules = _modules.where((m) => !m.isExcluded).length;
        totalWatts = totalModules * _selectedModule.watts.toDouble();
      }

      final totalKwp = totalWatts / 1000.0;
      final estimatedMonthlyKwh = totalKwp * 130.0;

      final now = DateTime.now();
      final study = RoofStudyModel(
        id: _studyId ?? '',
        name: _studyName?.trim().isNotEmpty == true
            ? _studyName!.trim()
            : 'Estudo Solar ${_currentAddress.split(',').first}',
        clientId: _clientId,
        clientName: _clientName,
        proposalId: _proposalId,
        proposalCode: _proposalCode,
        latitude: _latitude,
        longitude: _longitude,
        formattedAddress: _currentAddress,
        zoom: _zoom,
        panOffsetX: _panOffsetX,
        panOffsetY: _panOffsetY,
        mapsSections: List.from(_mapsSections),
        mapsPanOffsetX: _mapsPanOffsetX,
        mapsPanOffsetY: _mapsPanOffsetY,
        mapsZoom: _mapsZoom,
        droneSections: List.from(_droneSections),
        droneImageUrl: finalDroneImageUrl,
        droneImageFileName: _droneImageFileName,
        droneMetersPerPixel: _customDroneMetersPerPixel,
        dronePanOffsetX: _dronePanOffsetX,
        dronePanOffsetY: _dronePanOffsetY,
        droneZoom: _droneZoom,
        lastActiveMode: _backgroundMode == BackgroundLayerMode.dronePhoto
            ? 'dronePhoto'
            : 'satellite',
        sections: List.from(_sections),
        totalModulesCount: totalModules,
        totalKwp: totalKwp,
        estimatedMonthlyKwh: estimatedMonthlyKwh,
        thumbnailBase64: base64Snapshot,
        companyId: widget.currentUser?.effectiveCompanyId ??
            widget.currentUser?.companyId ??
            '',
        createdByUserId: widget.currentUser?.uid ?? '',
        createdByUserName: widget.currentUser?.name ?? '',
        createdAt: _createdAt ?? now,
        updatedAt: now,
      );

      final savedId = await _roofStudyRepo.saveStudy(study);
      _studyId = savedId;
      _createdAt ??= now;

      // CRÍTICO: Garante persistência imediata no cache local com o ID gerado na PRIMEIRA VEZ!
      if (_droneImageBytes != null && savedId.isNotEmpty) {
        _cacheDroneImage(savedId, _droneImageBytes!);
      }

      // Se o upload para nuvem ainda estiver em segundo plano, atualiza o Firestore assim que concluir
      if ((finalDroneImageUrl == null || finalDroneImageUrl.isEmpty) &&
          _droneUploadFuture != null) {
        _droneUploadFuture!.then((uploadedUrl) {
          if (uploadedUrl != null &&
              uploadedUrl.isNotEmpty &&
              savedId.isNotEmpty) {
            _roofStudyRepo.updateDroneImageUrl(savedId, uploadedUrl);
          }
        });
      }

      if (mounted) {
        if (showFeedback) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Estudo "${study.name}" salvo com sucesso no banco de dados!',
                      style: GoogleFonts.inter(
                          color: Colors.white, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
      return study.copyWith(id: savedId);
    } catch (e) {
      debugPrint('[SolarRoofDesigner] Erro ao salvar estudo: $e');
      if (mounted && showFeedback) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar estudo: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
      return null;
    } finally {
      if (mounted) {
        setState(() => _isSavingStudy = false);
      }
    }
  }

  /// Abre diálogo para renomear o estudo ou alterar vínculos de cliente/proposta
  Future<void> _editStudyLinks() async {
    final result = await RoofStudySetupDialog.show(
      context,
      currentUser: widget.currentUser,
      isEditingLinksOnly: true,
      existingStudy: RoofStudyModel(
        id: _studyId ?? '',
        name: _studyName ?? '',
        clientId: _clientId,
        clientName: _clientName,
        proposalId: _proposalId,
        proposalCode: _proposalCode,
        latitude: _latitude,
        longitude: _longitude,
        formattedAddress: _currentAddress,
        zoom: _zoom,
        panOffsetX: _panOffsetX,
        panOffsetY: _panOffsetY,
        sections: _sections,
        totalModulesCount: 0,
        totalKwp: 0,
        estimatedMonthlyKwh: 0,
        createdAt: _createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    if (result != null) {
      setState(() {
        _studyName = result.studyName;
        _clientId = result.selectedClient?.id;
        _clientName = result.selectedClient?.name;
        _proposalId = result.selectedProposal?.id;
        _proposalCode = result.selectedProposal != null
            ? '#${result.selectedProposal!.proposalNumber}'
            : null;
      });
      // Salva automaticamente as novas informações de vínculo
      await _saveRoofStudy(showFeedback: true);
    }
  }

  // ── Captura do Estudo e Exportação ───────────────────────────────────────
  Future<void> _exportStudy() async {
    // Salva automaticamente no Firestore
    final saved = await _saveRoofStudy(showFeedback: false);

    String? base64Snapshot = saved?.snapshotImageBase64;
    if (base64Snapshot == null) {
      try {
        final boundary = _canvasKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
        if (boundary != null && boundary.size.width > 0) {
          final scaleRatio = (260.0 / boundary.size.width).clamp(0.08, 0.3);
          final image = await boundary.toImage(pixelRatio: scaleRatio);
          final byteData =
              await image.toByteData(format: ui.ImageByteFormat.png);
          if (byteData != null) {
            base64Snapshot = base64Encode(byteData.buffer.asUint8List());
          }
        }
      } catch (e) {
        debugPrint('[SolarRoofDesigner] Erro ao capturar snapshot: $e');
      }
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
    final totalKwp = totalWatts > 0
        ? (totalWatts / 1000.0)
        : ModuleLayoutEngine.calculateTotalKwp(_modules, _selectedModule);
    final estimatedKwh =
        ModuleLayoutEngine.estimateMonthlyGenerationKwh(totalKwp);
    final totalRoofArea =
        _sections.fold<double>(0.0, (sum, s) => sum + s.areaM2);

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
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop(result);
    }
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
      consolidatedWatts =
          consolidatedModuleCount * _selectedModule.watts.toDouble();
      consolidatedRoofAreaM2 = _roofPolygon.areaM2;
    }

    final consolidatedKwp = consolidatedWatts / 1000.0;
    final consolidatedMonthlyKwh = consolidatedKwp * 130.0;

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: Colors.transparent,
      child: ScaffoldMessenger(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
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
                                Container(
                                    width: 1, color: const Color(0xFF1E293B)),
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
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _studyName ?? 'Estudo de Telhado & Satélite 🛰️',
                        style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Chip Cliente
                    InkWell(
                      onTap: _editStudyLinks,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _clientName != null
                              ? const Color(0xFF065F46).withValues(alpha: 0.7)
                              : const Color(0xFF334155),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _clientName != null
                                ? const Color(0xFF10B981)
                                : const Color(0xFF475569),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _clientName != null
                                  ? Icons.person_rounded
                                  : Icons.person_outline_rounded,
                              size: 13,
                              color: _clientName != null
                                  ? const Color(0xFF34D399)
                                  : const Color(0xFF94A3B8),
                            ),
                            const SizedBox(width: 4),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 140),
                              child: Text(
                                _clientName ?? 'Sem Cliente',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _clientName != null
                                      ? const Color(0xFF34D399)
                                      : const Color(0xFF94A3B8),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Chip Proposta
                    InkWell(
                      onTap: _editStudyLinks,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _proposalCode != null
                              ? const Color(0xFF3730A3).withValues(alpha: 0.7)
                              : const Color(0xFF334155),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _proposalCode != null
                                ? const Color(0xFF6366F1)
                                : const Color(0xFF475569),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _proposalCode != null
                                  ? Icons.description_rounded
                                  : Icons.description_outlined,
                              size: 13,
                              color: _proposalCode != null
                                  ? const Color(0xFF818CF8)
                                  : const Color(0xFF94A3B8),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _proposalCode ?? 'Sem Proposta',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _proposalCode != null
                                    ? const Color(0xFF818CF8)
                                    : const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: _editStudyLinks,
                      icon: const Icon(Icons.edit_outlined,
                          size: 15, color: Color(0xFF94A3B8)),
                      tooltip: 'Alterar Nome ou Vínculos',
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 24, minHeight: 24),
                    ),
                  ],
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
            width: 300,
            child: TextField(
              controller: _searchCtrl,
              onSubmitted: _performSearch,
              style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Buscar endereço ou CEP (ex: 01310-100)...',
                hintStyle: GoogleFonts.inter(
                    fontSize: 12, color: const Color(0xFF64748B)),
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
                  onTap: () => _switchMode(BackgroundLayerMode.satellite),
                ),
                _buildModeChoiceButton(
                  isActive: _backgroundMode == BackgroundLayerMode.dronePhoto,
                  label: 'Drone',
                  icon: Icons.camera_alt_rounded,
                  onTap: () => _switchMode(BackgroundLayerMode.dronePhoto),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: _pickDronePhoto,
            icon: Icon(
              _droneImageBytes != null
                  ? Icons.photo_library_rounded
                  : Icons.add_photo_alternate_rounded,
              color: const Color(0xFF38BDF8),
              size: 20,
            ),
            tooltip: _droneImageBytes != null
                ? 'Substituir Imagem do Drone'
                : 'Carregar Foto do Drone',
          ),
          if (_isLoadingDronePhoto) ...[
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
                Text(
                  'Baixando drone...',
                  style: GoogleFonts.inter(
                      fontSize: 11, color: const Color(0xFF38BDF8)),
                ),
              ],
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
          const SizedBox(width: 10),

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

          // Botão Salvar Estudo no Banco
          ElevatedButton.icon(
            onPressed: _isSavingStudy
                ? null
                : () => _saveRoofStudy(showFeedback: true),
            icon: _isSavingStudy
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save_rounded, size: 16),
            label: Text(
              _isSavingStudy ? 'SALVANDO...' : 'SALVAR 💾',
              style:
                  GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
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
            selectedModuleIndex: _selectedModuleIndex,
            onSelectModule: (idx) {
              setState(() {
                _selectedModuleIndex = idx;
                if (idx >= 0 && idx < _modules.length) {
                  final mod = _modules[idx];
                  _activeClusterId = mod.rowId ?? 'conjunto_1';
                  _isCurrentClusterFinalized = false;
                }
              });
            },
            activeClusterId: _activeClusterId,
            isClusterFinalized: _isCurrentClusterFinalized,
            sections: _sections,
            activeSectionIndex: _activeSectionIndex,
            isEditingActiveSection: !_isSectionFinalized,
            toolMode: _toolMode,
            satelliteSource: _satelliteSource,
            backgroundMode: _backgroundMode,
            droneImageBytes: _droneImageBytes,
            isAnalyzingDrone: (_isAnalyzingDrone || _isLoadingDronePhoto),
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
            onModuleDragEnd: _handleModuleDragEnd,
            snappedModuleIndex: _snappedModuleIndex,
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
            onResumeEditing: () => setState(() {
              _isSectionFinalized = false;
              _toolMode = DesignerToolMode.editModules;
            }),
            onAddNewSection: _addNewSection,
            onDuplicateCurrentSection: _duplicateCurrentSection,
            onConcludeCluster: _concludeCurrentCluster,
            droneNorthCompass: _droneNorthCompass,
            droneArrows: _droneArrows,
            selectedDroneArrowId: _selectedDroneArrowId,
            snapAlignmentEnabled: _snapAlignmentEnabled,
            onUpdateDroneCompass: (compass) =>
                setState(() => _droneNorthCompass = compass),
            onUpdateDroneArrow: (arrow) {
              setState(() {
                final idx =
                    _droneArrows.indexWhere((a) => a.id == arrow.id);
                if (idx != -1) {
                  _droneArrows[idx] = arrow;
                }
                if (arrow.sectionId != null) {
                  final sIdx =
                      _sections.indexWhere((s) => s.id == arrow.sectionId);
                  if (sIdx != -1) {
                    final deg =
                        (((arrow.rotationRadians * 180.0 / math.pi) % 360) +
                                360) %
                            360;
                    _sections[sIdx] =
                        _sections[sIdx].copyWith(rotationDegrees: deg);
                  }
                }
              });
            },
            onSelectDroneArrow: (id) {
              setState(() => _selectedDroneArrowId = id);
              if (id != null) {
                _scrollToSelectedArrow(id);
              }
            },
            onDeleteDroneArrow: _deleteDroneArrow,
            onPanUpdate: (delta) {
              setState(() {
                _panOffsetX += delta.dx;
                _panOffsetY += delta.dy;
              });
            },
            isRenderMode: _isRenderMode,
            sectionEfficiencies: _calculateSectionEfficiencies(),
            activeSectionEfficiency: _calculateSectionEfficiencies()[_sections.isNotEmpty && _activeSectionIndex < _sections.length ? _sections[_activeSectionIndex].id : 'active'],
          ),
        ),

        // Barra de Ferramentas Flutuante Superior
        Positioned(
          top: 16,
          left: 20,
          child: _buildFloatingToolbar(),
        ),

        // Painel Flutuante Arrastável de Orientação & Quedas
        if (_showOrientationPanel)
          Positioned(
            left: _orientationPanelOffset.dx,
            top: _orientationPanelOffset.dy,
            child: _buildOrientationFloatingPanel(),
          ),

        // Dica contextual na parte inferior do canvas
        Positioned(
          bottom: 16,
          left: 140,
          child: _buildContextualHint(),
        ),

        // Overlay bloqueador com CircularProgressIndicator enquanto a IA analisa a foto do drone ou baixa foto
        if ((_isAnalyzingDrone || _isLoadingDronePhoto) &&
            _backgroundMode == BackgroundLayerMode.dronePhoto)
          Positioned.fill(
            child: AbsorbPointer(
              absorbing: true,
              child: Container(
                color: Colors.black.withValues(alpha: 0.65),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 36, vertical: 30),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.98),
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: const Color(0xFF38BDF8), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xFF38BDF8).withValues(alpha: 0.35),
                          blurRadius: 32,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 52,
                          height: 52,
                          child: CircularProgressIndicator(
                            strokeWidth: 4,
                            color: Color(0xFF38BDF8),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Carregando...',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isLoadingDronePhoto
                              ? 'Baixando foto do drone...'
                              : 'Aguarde a IA analisar a imagem para liberar o desenho',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
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
            mode: DesignerToolMode.select,
            icon: Icons.near_me_rounded,
            label: 'Selecionar',
          ),
          const SizedBox(width: 4),
          _buildToolButton(
            mode: DesignerToolMode.pan,
            icon: Icons.pan_tool_rounded,
            label: 'Navegar',
          ),
          const SizedBox(width: 4),
          _buildToolButton(
            mode: DesignerToolMode.drawRoof,
            icon: Icons.polyline_rounded,
            label: 'Desenhar',
            isEnabled: _backgroundMode == BackgroundLayerMode.dronePhoto
                ? (_hasDronePhoto && (!_isRoofClosed || _roofVertices.length < 3))
                : (!_isRoofClosed || _roofVertices.length < 3),
            disabledTooltip: (_backgroundMode == BackgroundLayerMode.dronePhoto && !_hasDronePhoto)
                ? 'IMPORTE A FOTO DO DRONE PARA DESENHAR'
                : 'CRIE UM NOVO TELHADO PARA DESENHAR',
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

          // Botão Auto-Fill (Preencher Placas) - Oculto no modo Drone
          if (_backgroundMode != BackgroundLayerMode.dronePhoto) ...[
            ElevatedButton.icon(
              onPressed: _isRoofClosed ? _autoFillModules : null,
              icon: const Icon(Icons.flash_on_rounded, size: 16),
              label: Text('PREENCHER',
                  style: GoogleFonts.outfit(
                      fontSize: 12, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(width: 6),
          ],

          // Botão + Placa Manual (coloca mais uma placa ao conjunto)
          Tooltip(
            message: !_isAnyPolygonSelected
                ? 'Faça um desenho de um telhado e selecione-o para adicionar módulos'
                : 'Adicionar placa ao telhado selecionado',
            child: MouseRegion(
              cursor: _isAnyPolygonSelected
                  ? SystemMouseCursors.click
                  : SystemMouseCursors.forbidden,
              child: Opacity(
                opacity: !_isAnyPolygonSelected ? 0.45 : 1.0,
                child: OutlinedButton.icon(
                  onPressed: _isAnyPolygonSelected ? _addSingleModule : null,
                  icon: Icon(
                    Icons.add_rounded,
                    size: 16,
                    color: _isAnyPolygonSelected
                        ? const Color(0xFF10B981)
                        : const Color(0xFF94A3B8),
                  ),
                  label: Text(
                    '+ Placa',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _isAnyPolygonSelected
                          ? Colors.white
                          : const Color(0xFF94A3B8),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: _isAnyPolygonSelected
                          ? const Color(0xFF10B981)
                          : const Color(0xFF475569),
                      width: 1.2,
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
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

          // Seletor de Camada de Satélite (Google Maps / Esri) - Oculto no modo Drone
          if (_backgroundMode != BackgroundLayerMode.dronePhoto) ...[
            const SizedBox(width: 4),
            Container(width: 1, height: 24, color: const Color(0xFF334155)),
            const SizedBox(width: 6),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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

          // Botão Orientação & Quedas (Abre janela flutuante arrastável)
          const SizedBox(width: 4),
          Container(width: 1, height: 24, color: const Color(0xFF334155)),
          const SizedBox(width: 6),
          Tooltip(
            message: !_hasAnyClosedPolygon
                ? 'Para definir orientacao, desenhe a queda do telhado primeiro'
                : 'Configurar orientações solares e quedas de telhado',
            child: Opacity(
              opacity: !_hasAnyClosedPolygon ? 0.45 : 1.0,
              child: ElevatedButton.icon(
                onPressed: !_hasAnyClosedPolygon
                    ? () => _showNoPolygonWarning()
                    : () {
                        if (!_showOrientationPanel) {
                          _syncArrowsWithSections();
                          setState(() {
                            _showOrientationPanel = true;
                            _toolMode = DesignerToolMode.select; // Ativa a ferramenta SELECIONAR!
                          });
                        } else {
                          setState(() {
                            _showOrientationPanel = false;
                          });
                        }
                      },
                icon: Icon(
                  Icons.explore_rounded,
                  size: 16,
                  color: _showOrientationPanel
                      ? Colors.white
                      : const Color(0xFF38BDF8),
                ),
                label: Text(
                  'Orientação & Quedas',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _showOrientationPanel
                      ? const Color(0xFF0284C7)
                      : const Color(0xFF1E293B),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: _showOrientationPanel
                          ? const Color(0xFF38BDF8)
                          : const Color(0xFF334155),
                      width: 1.2,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Botão RENDERIZAR / QUALIFICAÇÃO SOLAR
          const SizedBox(width: 6),
          Tooltip(
            message: _isRenderMode
                ? 'Modo Renderizar: Exibindo placas fotovoltaicas fotorrealistas limpas (Sem filtros coloridos). Clique para voltar ao modo Análise Solar'
                : 'Modo Qualificação: Exibindo mapa de calor solar e porcentagens de eficiência. Clique para Renderizar fotorrealista',
            child: ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _isRenderMode = !_isRenderMode;
                });
              },
              icon: Icon(
                _isRenderMode
                    ? Icons.camera_alt_rounded
                    : Icons.auto_awesome_rounded,
                size: 16,
                color: _isRenderMode
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFF10B981),
              ),
              label: Text(
                _isRenderMode ? 'Renderizado' : 'Renderizar',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isRenderMode
                    ? const Color(0xFF78350F)
                    : const Color(0xFF1E293B),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: _isRenderMode
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFF334155),
                    width: 1.2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Painel Flutuante Arrastável para Configuração de Norte e Setas de Queda
  Widget _buildOrientationFloatingPanel() {
    return Container(
      width: 360,
      constraints: const BoxConstraints(maxHeight: 560),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF38BDF8).withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
            blurRadius: 16,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Cabeçalho Arrastável
            GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  _orientationPanelOffset += details.delta;
                });
              },
              child: MouseRegion(
                cursor: SystemMouseCursors.move,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E293B),
                    border: Border(
                      bottom:
                          BorderSide(color: Color(0xFF334155), width: 1.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.explore_rounded,
                          color: Color(0xFF38BDF8), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Orientação & Quedas',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      const Tooltip(
                        message: 'Arraste para mover este painel',
                        child: Icon(Icons.drag_indicator_rounded,
                            color: Colors.white38, size: 16),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () =>
                            setState(() => _showOrientationPanel = false),
                        borderRadius: BorderRadius.circular(6),
                        child: const Padding(
                          padding: EdgeInsets.all(2),
                          child: Icon(Icons.close_rounded,
                              color: Colors.white70, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 2. Conteúdo Rolável
            Flexible(
              child: SingleChildScrollView(
                controller: _orientationScrollController,
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // CARD: NORTE DA IMAGEM
                    _buildNorthCompassSection(),
                    const SizedBox(height: 12),

                    // CARD: SETAS DE QUEDAS DO TELHADO
                    _buildRoofArrowsSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Seção do Norte da Imagem dentro do painel flutuante
  Widget _buildNorthCompassSection() {
    final compass = _droneNorthCompass;
    final hasCompass = compass != null;

    final degrees = hasCompass
        ? (((compass.rotationRadians * 180.0 / math.pi) % 360) + 360) % 360
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasCompass
              ? const Color(0xFFEF4444).withValues(alpha: 0.5)
              : const Color(0xFF334155),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.navigation_rounded,
                  color: Color(0xFFEF4444), size: 17),
              const SizedBox(width: 8),
              Text(
                'Indicação do Norte',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              if (hasCompass) ...[
                Tooltip(
                  message: 'Recentralizar Norte na tela',
                  child: IconButton(
                    icon: const Icon(Icons.center_focus_strong_rounded,
                        size: 16, color: Color(0xFF38BDF8)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      final centerM = RoofPoint(
                        RoofGeometryService.pixelsToMeters(
                            -_panOffsetX, _metersPerPixel),
                        RoofGeometryService.pixelsToMeters(
                            -_panOffsetY, _metersPerPixel),
                      );
                      setState(() {
                        _droneNorthCompass =
                            _droneNorthCompass!.copyWith(center: centerM);
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Remover Norte',
                  child: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        size: 16, color: Color(0xFFEF4444)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: _removeDroneNorthCompass,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),

          if (!hasCompass) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _addDroneNorthCompass,
                icon: const Icon(Icons.add_rounded,
                    size: 16, color: Color(0xFF38BDF8)),
                label: Text(
                  '+ Adicionar Indicação do Norte',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF38BDF8), width: 1.2),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ] else ...[
            // Rotação do Norte
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Rotação do Norte:',
                  style: GoogleFonts.inter(
                      fontSize: 11.5, color: const Color(0xFF94A3B8)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Text(
                    '${degrees.toStringAsFixed(0)}°',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFEF4444),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // Slider fino de 0° a 360°
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: const Color(0xFFEF4444),
                inactiveTrackColor: const Color(0xFF334155),
                thumbColor: Colors.white,
                overlayColor: const Color(0xFFEF4444).withValues(alpha: 0.2),
                trackHeight: 3,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 6.5),
              ),
              child: Slider(
                value: degrees,
                min: 0,
                max: 360,
                divisions: 72,
                onChanged: (val) {
                  setState(() {
                    _droneNorthCompass = _droneNorthCompass!.copyWith(
                      rotationRadians: val * math.pi / 180.0,
                    );
                  });
                },
              ),
            ),

            // Botões rápidos de quadrantes (N, L, S, O)
            Row(
              children: [
                _buildQuickAngleBtn('N (0°)', 0, degrees, (v) {
                  setState(() => _droneNorthCompass =
                      _droneNorthCompass!.copyWith(rotationRadians: 0.0));
                }),
                const SizedBox(width: 4),
                _buildQuickAngleBtn('L (90°)', 90, degrees, (v) {
                  setState(() => _droneNorthCompass = _droneNorthCompass!
                      .copyWith(rotationRadians: math.pi / 2));
                }),
                const SizedBox(width: 4),
                _buildQuickAngleBtn('S (180°)', 180, degrees, (v) {
                  setState(() => _droneNorthCompass =
                      _droneNorthCompass!.copyWith(rotationRadians: math.pi));
                }),
                const SizedBox(width: 4),
                _buildQuickAngleBtn('O (270°)', 270, degrees, (v) {
                  setState(() => _droneNorthCompass = _droneNorthCompass!
                      .copyWith(rotationRadians: 3 * math.pi / 2));
                }),
              ],
            ),
            const SizedBox(height: 8),

            // Switch de Pontos Cardeais
            InkWell(
              onTap: () {
                setState(() {
                  _droneNorthCompass = _droneNorthCompass!.copyWith(
                    showCardinals: !_droneNorthCompass!.showCardinals,
                  );
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      _droneNorthCompass!.showCardinals
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                      size: 18,
                      color: _droneNorthCompass!.showCardinals
                          ? const Color(0xFF10B981)
                          : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Exibir Pontos Cardeais (N, S, L, O)',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Seção das Setas de Quedas do Telhado dentro do painel flutuante
  Widget _buildRoofArrowsSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.arrow_forward_rounded,
                  color: Color(0xFF38BDF8), size: 17),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    Text(
                      'Quedas do Telhado',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (_droneArrows.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF38BDF8).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: const Color(0xFF38BDF8)
                                  .withValues(alpha: 0.6)),
                        ),
                        child: Text(
                          '${_droneArrows.length}',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF38BDF8),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _addDroneArrow,
                icon: const Icon(Icons.add_rounded, size: 14),
                label: Text(
                  '+ Nova Queda',
                  style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Auto-Alinhamento Magnético (Snap)
          InkWell(
            onTap: () =>
                setState(() => _snapAlignmentEnabled = !_snapAlignmentEnabled),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: _snapAlignmentEnabled
                    ? const Color(0xFF10B981).withValues(alpha: 0.12)
                    : const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _snapAlignmentEnabled
                      ? const Color(0xFF10B981).withValues(alpha: 0.5)
                      : const Color(0xFF334155),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _snapAlignmentEnabled
                        ? Icons.auto_awesome_rounded
                        : Icons.auto_awesome_outlined,
                    size: 15,
                    color: _snapAlignmentEnabled
                        ? const Color(0xFF10B981)
                        : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Auto-Alinhamento Magnético',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _snapAlignmentEnabled
                                ? Colors.white
                                : const Color(0xFF94A3B8),
                          ),
                        ),
                        Text(
                          'Alinha eixos e ângulos de quedas opostas',
                          style: GoogleFonts.inter(
                            fontSize: 9.5,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _snapAlignmentEnabled,
                    activeThumbColor: const Color(0xFF10B981),
                    onChanged: (val) =>
                        setState(() => _snapAlignmentEnabled = val),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Controles Globais de Cor e Escala (Apenas UM controle muda todas as setas)
          if (_droneArrows.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Seletor Global de Cor
                  Row(
                    children: [
                      Text(
                        'Cor das Quedas:',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                      const Spacer(),
                      ...[
                        const Color(0xFF2563EB), // Azul Royal 3D (da referência)
                        const Color(0xFF38BDF8), // Ciano
                        const Color(0xFF6366F1), // Índigo
                        const Color(0xFF10B981), // Esmeralda
                        const Color(0xFFF59E0B), // Âmbar
                        const Color(0xFFF43F5E), // Rosa
                        const Color(0xFFA855F7), // Roxo
                        Colors.white,            // Branco
                      ].map((c) {
                        final isCurColor =
                            _droneArrowsGlobalColor.toARGB32() == c.toARGB32();
                        return InkWell(
                          onTap: () {
                            setState(() {
                              _droneArrowsGlobalColor = c;
                              for (int i = 0; i < _droneArrows.length; i++) {
                                _droneArrows[i] =
                                    _droneArrows[i].copyWith(color: c);
                              }
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            margin: const EdgeInsets.only(left: 6),
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color:
                                    isCurColor ? Colors.white : Colors.black45,
                                width: isCurColor ? 2.2 : 1.0,
                              ),
                              boxShadow: isCurColor
                                  ? [
                                      BoxShadow(
                                        color: c.withValues(alpha: 0.6),
                                        blurRadius: 6,
                                      )
                                    ]
                                  : null,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // 2. Slider Global de Escala / Tamanho
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Escala das Quedas:',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Text(
                          '${_droneArrowsGlobalLength.toStringAsFixed(1)}m',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF38BDF8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: const Color(0xFF38BDF8),
                      inactiveTrackColor: const Color(0xFF334155),
                      thumbColor: Colors.white,
                      overlayColor:
                          const Color(0xFF38BDF8).withValues(alpha: 0.2),
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6.0),
                    ),
                    child: Slider(
                      value: _droneArrowsGlobalLength.clamp(0.5, 5.0),
                      min: 0.5,
                      max: 5.0,
                      divisions: 45,
                      onChanged: (val) {
                        setState(() {
                          _droneArrowsGlobalLength = val;
                          for (int i = 0; i < _droneArrows.length; i++) {
                            _droneArrows[i] =
                                _droneArrows[i].copyWith(lengthMeters: val);
                          }
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          if (_droneArrows.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Nenhuma seta de queda adicionada. Clique em "+ Nova Queda" para indicar a orientação das águas do telhado.',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  color: const Color(0xFF64748B),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ] else ...[
            // Lista das Setas (Cards Ultra Enxutos e Interativos)
            ...List.generate(_droneArrows.length, (idx) {
              final arrow = _droneArrows[idx];
              final isSelected = arrow.id == _selectedDroneArrowId;
              final key =
                  _arrowCardKeys.putIfAbsent(arrow.id, () => GlobalKey());
              final degrees =
                  (((arrow.rotationRadians * 180.0 / math.pi) % 360) + 360) %
                      360;

              return Container(
                key: key,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF0F172A)
                      : const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF38BDF8)
                        : arrow.color.withValues(alpha: 0.5),
                    width: isSelected ? 2.0 : 1.0,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF38BDF8).withValues(alpha: 0.28),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      if (_selectedDroneArrowId != arrow.id) {
                        setState(() => _selectedDroneArrowId = arrow.id);
                        _scrollToSelectedArrow(arrow.id);
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Topo do card da seta
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: arrow.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Row(
                                  children: [
                                    Text(
                                      arrow.label.isNotEmpty
                                          ? arrow.label
                                          : 'Queda ${idx + 1}',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    if (isSelected) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF38BDF8)
                                              .withValues(alpha: 0.2),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                            color: const Color(0xFF38BDF8),
                                            width: 1.0,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 5,
                                              height: 5,
                                              decoration: const BoxDecoration(
                                                color: Color(0xFF38BDF8),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 3),
                                            Text(
                                              'EM EDIÇÃO',
                                              style: GoogleFonts.inter(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w800,
                                                color: const Color(0xFF38BDF8),
                                                letterSpacing: 0.4,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              // Botão Inverter 180° (Giro de oposição perfeita)
                              Tooltip(
                                message: 'Inverter 180° (Sentido oposto)',
                                child: InkWell(
                                  onTap: () {
                                    final newAngle =
                                        ((arrow.rotationRadians + math.pi) %
                                            (2 * math.pi));
                                    _updateArrowRotation(idx, newAngle);
                                  },
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF334155),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.sync_alt_rounded,
                                            size: 12, color: Colors.white),
                                        const SizedBox(width: 3),
                                        Text(
                                          '180°',
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
                              const SizedBox(width: 6),

                              // Botão Recentralizar Seta no Polígono
                              Tooltip(
                                message: 'Recentralizar no meio do telhado',
                                child: IconButton(
                                  icon: const Icon(
                                      Icons.filter_center_focus_rounded,
                                      size: 14,
                                      color: Color(0xFF38BDF8)),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () =>
                                      _recenterDroneArrow(arrow.id),
                                ),
                              ),
                              const SizedBox(width: 6),

                              // Botão Excluir
                              Tooltip(
                                message: 'Excluir seta',
                                child: IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded,
                                      size: 14, color: Color(0xFFEF4444)),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => _deleteDroneArrow(arrow.id),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Slider de Rotação da Seta
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Rotação da Queda:',
                                style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: const Color(0xFF94A3B8)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                      color: const Color(0xFF334155)),
                                ),
                                child: Text(
                                  '${degrees.toStringAsFixed(0)}° (${_getDirectionCardinalLabel(degrees)})',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: arrow.color,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),

                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: arrow.color,
                              inactiveTrackColor: const Color(0xFF334155),
                              thumbColor: Colors.white,
                              overlayColor: arrow.color.withValues(alpha: 0.2),
                              trackHeight: 3,
                              thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 6.0),
                            ),
                            child: Slider(
                              value: degrees,
                              min: 0,
                              max: 360,
                              divisions: 72,
                              onChanged: (val) {
                                _updateArrowRotation(
                                    idx, val * math.pi / 180.0);
                              },
                            ),
                          ),
                          const SizedBox(height: 4),

                          // Botões rápidos de giro da seta
                          Row(
                            children: [
                              _buildQuickAngleBtn('-90°', -90, degrees, (_) {
                                final newAngle = (((arrow.rotationRadians -
                                                math.pi / 2) %
                                            (2 * math.pi)) +
                                        (2 * math.pi)) %
                                    (2 * math.pi);
                                _updateArrowRotation(idx, newAngle);
                              }),
                              const SizedBox(width: 6),
                              _buildQuickAngleBtn('+90°', 90, degrees, (_) {
                                final newAngle = ((arrow.rotationRadians +
                                        math.pi / 2) %
                                    (2 * math.pi));
                                _updateArrowRotation(idx, newAngle);
                              }),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  /// Helper para botão de ângulo rápido
  Widget _buildQuickAngleBtn(
      String label, double targetDeg, double currentDeg, ValueChanged<double> onTap) {
    final isSelected = (currentDeg - targetDeg).abs() < 1.0;
    return InkWell(
      onTap: () => onTap(targetDeg),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF0284C7)
              : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF38BDF8)
                : const Color(0xFF334155),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : const Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }

  /// Retorna o nome cardeal aproximado com base no ângulo (0° = Leste, 90° = Sul, 180° = Oeste, 270° = Norte)
  String _getDirectionCardinalLabel(double degrees) {
    final d = ((degrees % 360) + 360) % 360;
    if (d >= 337.5 || d < 22.5) return 'Leste';
    if (d >= 22.5 && d < 67.5) return 'Sudeste';
    if (d >= 67.5 && d < 112.5) return 'Sul';
    if (d >= 112.5 && d < 157.5) return 'Sudoeste';
    if (d >= 157.5 && d < 202.5) return 'Oeste';
    if (d >= 202.5 && d < 247.5) return 'Noroeste';
    if (d >= 247.5 && d < 292.5) return 'Norte';
    return 'Nordeste';
  }

  Widget _buildToolButton({
    required DesignerToolMode mode,
    required IconData icon,
    required String label,
    bool isEnabled = true,
    String? disabledTooltip,
  }) {
    final isSelected = _toolMode == mode;

    if (!isEnabled) {
      final disabledChild = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: const Color(0xFF475569)),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF475569),
              ),
            ),
          ],
        ),
      );

      if (disabledTooltip != null) {
        return Tooltip(
          message: disabledTooltip,
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF38BDF8), width: 1.2),
          ),
          textStyle: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
          ),
          child: disabledChild,
        );
      }
      return disabledChild;
    }

    return InkWell(
      onTap: () => setState(() {
        _toolMode = mode;
        if (mode == DesignerToolMode.editModules) {
          _isSectionFinalized = false;
        }
      }),
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
                            color:
                                const Color(0xFF38BDF8).withValues(alpha: 0.3)),
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
                              children:
                                  _droneAnalysisResult!.obstacles.map((obs) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444)
                                        .withValues(alpha: 0.15),
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
                      style: GoogleFonts.inter(
                          fontSize: 11.5, color: Colors.white70)),
                  const SizedBox(height: 6),
                  Builder(
                    builder: (context) {
                      final availableSpecs = <SolarModuleSpec>[
                        ...SolarModuleSpec.presets
                      ];
                      if (!availableSpecs
                          .any((s) => s.id == _selectedModule.id)) {
                        availableSpecs.insert(0, _selectedModule);
                      }
                      final dropdownValue = availableSpecs.firstWhere(
                        (s) => s.id == _selectedModule.id,
                        orElse: () => availableSpecs.first,
                      );

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<SolarModuleSpec>(
                            value: dropdownValue,
                            isExpanded: true,
                            dropdownColor: const Color(0xFF0F172A),
                            icon: const Icon(Icons.keyboard_arrow_down_rounded,
                                color: Colors.white70),
                            items: availableSpecs.map((spec) {
                              return DropdownMenuItem(
                                value: spec,
                                child: Text(
                                  spec.modelName,
                                  style: GoogleFonts.inter(
                                      fontSize: 12, color: Colors.white),
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
                      );
                    },
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
                          style: GoogleFonts.inter(
                              fontSize: 11.5, color: Colors.white70)),
                      InkWell(
                        onTap: _showSetAngleDialog,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: Colors.amber.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              Text(
                                '${((_rotationOffsetDegrees % 360 + 360) % 360).toStringAsFixed(0)}°',
                                style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.edit_rounded,
                                  size: 11, color: Colors.amber),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: ((_rotationOffsetDegrees % 360 + 360) % 360)
                        .clamp(0.0, 360.0),
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
                          style: GoogleFonts.inter(
                              fontSize: 11.5, color: Colors.white70)),
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

                  // ── IRRADIAÇÃO SOLAR & GERAÇÃO (CRESESB / INPE) ──────────────────────────
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF334155)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.wb_sunny_rounded,
                                color: Color(0xFFF59E0B),
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'IRRADIAÇÃO SOLAR',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  Text(
                                    'CRESESB / Atlas Solar INPE',
                                    style: GoogleFonts.inter(
                                      fontSize: 10.5,
                                      color: const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: const Color(0xFF10B981)
                                        .withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                '$_resolvedState • $_resolvedRegion',
                                style: GoogleFonts.inter(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF10B981),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Linha com CEP e Irradiação HSP
                        Row(
                          children: [
                            // Campo de CEP
                            Expanded(
                              flex: 5,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'CEP DA INSTALAÇÃO',
                                    style: GoogleFonts.inter(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF94A3B8),
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Container(
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E293B),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: const Color(0xFF334155)),
                                    ),
                                    child: TextField(
                                      controller: _cepController,
                                      onChanged: (val) {
                                        final clean =
                                            val.replaceAll(RegExp(r'\D'), '');
                                        if (clean.length >= 5) {
                                          _updateCepAndHsp(val);
                                        }
                                      },
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'Ex: 01310-100',
                                        hintStyle: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: const Color(0xFF64748B),
                                        ),
                                        prefixIcon: const Icon(
                                          Icons.place_rounded,
                                          size: 15,
                                          color: Color(0xFF38BDF8),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 8),
                                        border: InputBorder.none,
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),

                            // Campo de Irradiação (HSP)
                            Expanded(
                              flex: 5,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'HSP (kWh/m²/dia)',
                                    style: GoogleFonts.inter(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF94A3B8),
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Container(
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E293B),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: const Color(0xFF334155)),
                                    ),
                                    child: TextField(
                                      controller: _hspController,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      onChanged: (val) {
                                        final parsed = double.tryParse(
                                            val.replaceAll(',', '.'));
                                        if (parsed != null && parsed > 0) {
                                          setState(() => _dailyHsp = parsed);
                                        }
                                      },
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFFF59E0B),
                                      ),
                                      decoration: InputDecoration(
                                        hintText: '5.00',
                                        hintStyle: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: const Color(0xFF64748B),
                                        ),
                                        prefixIcon: const Icon(
                                          Icons.solar_power_rounded,
                                          size: 15,
                                          color: Color(0xFFF59E0B),
                                        ),
                                        suffixText: 'h/dia',
                                        suffixStyle: GoogleFonts.inter(
                                          fontSize: 10,
                                          color: const Color(0xFF94A3B8),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 8),
                                        border: InputBorder.none,
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Card de Resultado de Geração Mensal Estimada
                        Builder(
                          builder: (ctx) {
                            final estimatedKwh =
                                _calculateTotalEstimatedGenerationKwh();
                            final effs = _calculateSectionEfficiencies();
                            final bool hasDrop = effs.isNotEmpty;

                            double sumEff = 0.0;
                            int countEff = 0;
                            for (final e in effs.values) {
                              sumEff += e.efficiencyFactor;
                              countEff++;
                            }
                            final avgEffPct = countEff > 0
                                ? ((sumEff / countEff) * 100).round()
                                : 100;

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF1E3A8A)
                                        .withValues(alpha: 0.35),
                                    const Color(0xFF0F172A),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: const Color(0xFF38BDF8)
                                        .withValues(alpha: 0.4)),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.energy_savings_leaf_rounded,
                                            size: 16,
                                            color: Color(0xFF10B981),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'GERAÇÃO ESTIMADA',
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: const Color(0xFF38BDF8),
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: !hasDrop
                                              ? const Color(0xFF64748B)
                                                  .withValues(alpha: 0.20)
                                              : (avgEffPct >= 90
                                                      ? const Color(0xFF10B981)
                                                      : (avgEffPct >= 80
                                                          ? const Color(
                                                              0xFF38BDF8)
                                                          : const Color(
                                                              0xFFF59E0B)))
                                                  .withValues(alpha: 0.20),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          !hasDrop
                                              ? 'Aguardando queda'
                                              : '$avgEffPct% eficiênc.',
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: !hasDrop
                                                ? const Color(0xFF94A3B8)
                                                : (avgEffPct >= 90
                                                    ? const Color(0xFF10B981)
                                                    : (avgEffPct >= 80
                                                        ? const Color(
                                                            0xFF38BDF8)
                                                        : const Color(
                                                            0xFFF59E0B))),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Text(
                                        estimatedKwh.toStringAsFixed(0),
                                        style: GoogleFonts.outfit(
                                          fontSize: 26,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'kWh / mês',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF94A3B8),
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        'PR: 75% • 30d',
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          color: const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    hasDrop
                                        ? '$_dailyHsp HSP × ${totalKwp.toStringAsFixed(2)} kWp × 30d × 0.75 × ${(avgEffPct / 100).toStringAsFixed(2)} (Fator Angular)'
                                        : '$_dailyHsp HSP × ${totalKwp.toStringAsFixed(2)} kWp × 30d × 0.75 (Adicione a queda para qualificar)',
                                    style: GoogleFonts.inter(
                                      fontSize: 9.5,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                  if (!hasDrop) ...[
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.info_outline_rounded,
                                          size: 13,
                                          color: Color(0xFF38BDF8),
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            'Adicione a seta de queda em "Orientação & Quedas" para calcular a orientação em relação ao Norte.',
                                            style: GoogleFonts.inter(
                                              fontSize: 9.5,
                                              color: const Color(0xFF38BDF8),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),

                        // Alerta se o usuário ainda não adicionou o Norte no Drone
                        if (_backgroundMode == BackgroundLayerMode.dronePhoto &&
                            _droneNorthCompass == null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: const Color(0xFFF59E0B)
                                      .withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline_rounded,
                                    size: 15, color: Color(0xFFF59E0B)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Adicione o Norte em "Orientação & Quedas" para qualificar com exatidão máxima.',
                                    style: GoogleFonts.inter(
                                        fontSize: 10.5, color: Colors.white70),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

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
                          child: _buildKpiCard(
                              'MÓDULOS',
                              '$activeCount placas',
                              Icons.grid_view_rounded,
                              const Color(0xFF6366F1))),
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
                              '~${_calculateTotalEstimatedGenerationKwh().toStringAsFixed(0)} kWh/mês',
                              Icons.solar_power_rounded,
                              const Color(0xFF38BDF8))),
                    ],
                  ),

                  // ── Resumo de Quedas Mapeadas (Múltiplas Águas) ───────────────────
                  if (_sections.length > 1 ||
                      (_sections.isNotEmpty &&
                          _sections.first.activeModuleCount > 0)) ...[
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
                                'TELHADOS (${_sections.length})',
                                style: GoogleFonts.outfit(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF94A3B8)),
                              ),
                              InkWell(
                                onTap: _addNewSection,
                                child: Row(
                                  children: [
                                    const Icon(Icons.add_rounded,
                                        size: 12, color: Color(0xFF38BDF8)),
                                    const SizedBox(width: 2),
                                    Text(
                                      'Novo Telhado',
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
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 5),
                                decoration: BoxDecoration(
                                  color: isCur
                                      ? sec.themeColor.withValues(alpha: 0.15)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: isCur
                                          ? sec.themeColor
                                          : Colors.transparent),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                          color: sec.themeColor,
                                          shape: BoxShape.circle),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        sec.name,
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: isCur
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: isCur
                                              ? Colors.white
                                              : Colors.white70,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${sec.activeModuleCount} pl • ${sec.totalKwp.toStringAsFixed(2)} kWp',
                                      style: GoogleFonts.inter(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: isCur
                                            ? sec.themeColor
                                            : const Color(0xFF94A3B8),
                                      ),
                                    ),
                                    if (isCur) ...[
                                      const SizedBox(width: 4),
                                      const Icon(Icons.edit_rounded,
                                          size: 11, color: Colors.amber),
                                    ],
                                    if (_sections.length > 1) ...[
                                      const SizedBox(width: 6),
                                      InkWell(
                                        onTap: () => _deleteCurrentSection(idx),
                                        child: const Icon(Icons.close_rounded,
                                            size: 13, color: Color(0xFFEF4444)),
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
            onPressed:
                (activeCount > 0 && !_isSavingStudy) ? _exportStudy : null,
            icon: _isSavingStudy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check_circle_rounded, size: 20),
            label: Text(
              _isSavingStudy
                  ? 'SALVANDO & APLICANDO...'
                  : 'SALVAR ESTUDO & APLICAR',
              style: GoogleFonts.outfit(
                  fontSize: 14, fontWeight: FontWeight.bold),
            ),
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
