import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'solar_designer_models.dart';

/// Modelo de dados de um Estudo de Telhado Solar persistido no Cloud Firestore
class RoofStudyModel {
  final String id;
  final String companyId;
  final String name;

  // Vínculos Opcionais
  final String? clientId;
  final String? clientName;
  final String? proposalId;
  final String? proposalCode;

  // Localização geográfica e visualização do satélite
  final double latitude;
  final double longitude;
  final String formattedAddress;
  final double zoom;
  final double metersPerPixel;
  final double panOffsetX;
  final double panOffsetY;
  final String satelliteSource;

  // ── ESTUDO MAPS (Satélite Google Maps) ───────────────────────────────────
  final List<RoofSection> mapsSections;
  final double mapsPanOffsetX;
  final double mapsPanOffsetY;
  final double mapsZoom;

  // ── ESTUDO DRONE (Foto de Drone) ─────────────────────────────────────────
  final List<RoofSection> droneSections;
  final String? droneImageUrl;
  final String? droneImageFileName;
  final double? droneMetersPerPixel;
  final double dronePanOffsetX;
  final double dronePanOffsetY;
  final double droneZoom;

  // Modo ativo ao salvar ('satellite' | 'dronePhoto')
  final String lastActiveMode;

  // Geometria ativa ou consolidada (retrocompatibilidade)
  final List<RoofSection> sections;
  final int totalModulesCount;
  final double totalKwp;
  final double estimatedMonthlyKwh;

  // Status e Auditoria
  final String status; // 'draft' (rascunho), 'completed' (concluído)
  final String? thumbnailBase64;
  final String createdByUserId;
  final String createdByUserName;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RoofStudyModel({
    required this.id,
    this.companyId = '',
    required this.name,
    this.clientId,
    this.clientName,
    this.proposalId,
    this.proposalCode,
    required this.latitude,
    required this.longitude,
    required this.formattedAddress,
    this.zoom = 18.5,
    this.metersPerPixel = 0.05,
    this.panOffsetX = 0.0,
    this.panOffsetY = 0.0,
    this.satelliteSource = 'googleHybrid',
    this.mapsSections = const [],
    this.mapsPanOffsetX = 0.0,
    this.mapsPanOffsetY = 0.0,
    this.mapsZoom = 18.5,
    this.droneSections = const [],
    this.droneImageUrl,
    this.droneImageFileName,
    this.droneMetersPerPixel,
    this.dronePanOffsetX = 0.0,
    this.dronePanOffsetY = 0.0,
    this.droneZoom = 18.0,
    this.lastActiveMode = 'satellite',
    required this.sections,
    required this.totalModulesCount,
    required this.totalKwp,
    required this.estimatedMonthlyKwh,
    this.status = 'completed',
    this.thumbnailBase64,
    this.createdByUserId = '',
    this.createdByUserName = '',
    required this.createdAt,
    required this.updatedAt,
  });

  /// Alias de conveniência para quantidade total de módulos
  int get totalModules => totalModulesCount;

  /// Alias de conveniência para snapshot em Base64
  String? get snapshotImageBase64 => thumbnailBase64;

  /// Área consolidada de todas as seções/águas do telhado (m²)
  double get totalRoofAreaM2 =>
      sections.fold<double>(0.0, (acc, s) => acc + s.areaM2);

  /// Retorna se o estudo está atrelado a um cliente
  bool get hasClient => clientId != null && clientId!.trim().isNotEmpty;

  /// Retorna se o estudo está atrelado a uma proposta
  bool get hasProposal => proposalId != null && proposalId!.trim().isNotEmpty;

  /// Retorna se possui estudo feito no Google Maps
  bool get hasMapsStudy =>
      mapsSections.isNotEmpty || (sections.isNotEmpty && droneSections.isEmpty);

  /// Retorna se possui estudo feito no Drone
  bool get hasDroneStudy =>
      droneSections.isNotEmpty || (droneImageUrl != null && droneImageUrl!.isNotEmpty);

  /// Retorna se possui ambos os estudos registrados
  bool get hasBothStudies => hasMapsStudy && hasDroneStudy;

  /// Nome amigável para exibição do cliente
  String get displayClientName => hasClient ? clientName! : 'Sem cliente vinculado';

  /// Código amigável para exibição da proposta
  String get displayProposal =>
      hasProposal ? (proposalCode ?? 'Proposta vinculada') : 'Sem proposta vinculada';

  RoofStudyModel copyWith({
    String? id,
    String? companyId,
    String? name,
    String? clientId,
    String? clientName,
    String? proposalId,
    String? proposalCode,
    double? latitude,
    double? longitude,
    String? formattedAddress,
    double? zoom,
    double? metersPerPixel,
    double? panOffsetX,
    double? panOffsetY,
    String? satelliteSource,
    List<RoofSection>? mapsSections,
    double? mapsPanOffsetX,
    double? mapsPanOffsetY,
    double? mapsZoom,
    List<RoofSection>? droneSections,
    String? droneImageUrl,
    String? droneImageFileName,
    double? droneMetersPerPixel,
    double? dronePanOffsetX,
    double? dronePanOffsetY,
    double? droneZoom,
    String? lastActiveMode,
    List<RoofSection>? sections,
    int? totalModulesCount,
    double? totalKwp,
    double? estimatedMonthlyKwh,
    String? status,
    String? thumbnailBase64,
    String? createdByUserId,
    String? createdByUserName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RoofStudyModel(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      name: name ?? this.name,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      proposalId: proposalId ?? this.proposalId,
      proposalCode: proposalCode ?? this.proposalCode,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      formattedAddress: formattedAddress ?? this.formattedAddress,
      zoom: zoom ?? this.zoom,
      metersPerPixel: metersPerPixel ?? this.metersPerPixel,
      panOffsetX: panOffsetX ?? this.panOffsetX,
      panOffsetY: panOffsetY ?? this.panOffsetY,
      satelliteSource: satelliteSource ?? this.satelliteSource,
      mapsSections: mapsSections ?? this.mapsSections,
      mapsPanOffsetX: mapsPanOffsetX ?? this.mapsPanOffsetX,
      mapsPanOffsetY: mapsPanOffsetY ?? this.mapsPanOffsetY,
      mapsZoom: mapsZoom ?? this.mapsZoom,
      droneSections: droneSections ?? this.droneSections,
      droneImageUrl: droneImageUrl ?? this.droneImageUrl,
      droneImageFileName: droneImageFileName ?? this.droneImageFileName,
      droneMetersPerPixel: droneMetersPerPixel ?? this.droneMetersPerPixel,
      dronePanOffsetX: dronePanOffsetX ?? this.dronePanOffsetX,
      dronePanOffsetY: dronePanOffsetY ?? this.dronePanOffsetY,
      droneZoom: droneZoom ?? this.droneZoom,
      lastActiveMode: lastActiveMode ?? this.lastActiveMode,
      sections: sections ?? this.sections,
      totalModulesCount: totalModulesCount ?? this.totalModulesCount,
      totalKwp: totalKwp ?? this.totalKwp,
      estimatedMonthlyKwh: estimatedMonthlyKwh ?? this.estimatedMonthlyKwh,
      status: status ?? this.status,
      thumbnailBase64: thumbnailBase64 ?? this.thumbnailBase64,
      createdByUserId: createdByUserId ?? this.createdByUserId,
      createdByUserName: createdByUserName ?? this.createdByUserName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'companyId': companyId,
      'name': name,
      'clientId': clientId,
      'clientName': clientName,
      'proposalId': proposalId,
      'proposalCode': proposalCode,
      'latitude': latitude,
      'longitude': longitude,
      'formattedAddress': formattedAddress,
      'zoom': zoom,
      'metersPerPixel': metersPerPixel,
      'panOffsetX': panOffsetX,
      'panOffsetY': panOffsetY,
      'satelliteSource': satelliteSource,
      'mapsSections': mapsSections.map((sec) => _sectionToMap(sec)).toList(),
      'mapsPanOffsetX': mapsPanOffsetX,
      'mapsPanOffsetY': mapsPanOffsetY,
      'mapsZoom': mapsZoom,
      'droneSections': droneSections.map((sec) => _sectionToMap(sec)).toList(),
      'droneImageUrl': droneImageUrl,
      'droneImageFileName': droneImageFileName,
      'droneMetersPerPixel': droneMetersPerPixel,
      'dronePanOffsetX': dronePanOffsetX,
      'dronePanOffsetY': dronePanOffsetY,
      'droneZoom': droneZoom,
      'lastActiveMode': lastActiveMode,
      'sections': sections.map((sec) => _sectionToMap(sec)).toList(),
      'totalModulesCount': totalModulesCount,
      'totalKwp': totalKwp,
      'estimatedMonthlyKwh': estimatedMonthlyKwh,
      'status': status,
      'thumbnailBase64': (thumbnailBase64 != null && thumbnailBase64!.length < 450000)
          ? thumbnailBase64
          : null,
      'createdByUserId': createdByUserId,
      'createdByUserName': createdByUserName,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory RoofStudyModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    final rawSections = map['sections'] as List<dynamic>? ?? [];
    final parsedLegacySections = rawSections
        .map((item) => _sectionFromMap(item as Map<String, dynamic>))
        .toList();

    final rawMapsSections = map['mapsSections'] as List<dynamic>?;
    final parsedMapsSections = rawMapsSections != null
        ? rawMapsSections
            .map((item) => _sectionFromMap(item as Map<String, dynamic>))
            .toList()
        : parsedLegacySections;

    final rawDroneSections = map['droneSections'] as List<dynamic>? ?? [];
    final parsedDroneSections = rawDroneSections
        .map((item) => _sectionFromMap(item as Map<String, dynamic>))
        .toList();

    final lastActiveMode = map['lastActiveMode'] as String? ??
        (parsedDroneSections.isNotEmpty && parsedMapsSections.isEmpty
            ? 'dronePhoto'
            : 'satellite');

    final activeSections = lastActiveMode == 'dronePhoto' && parsedDroneSections.isNotEmpty
        ? parsedDroneSections
        : (parsedMapsSections.isNotEmpty ? parsedMapsSections : parsedLegacySections);

    return RoofStudyModel(
      id: id,
      companyId: map['companyId'] as String? ?? '',
      name: map['name'] as String? ?? 'Estudo de Telhado',
      clientId: map['clientId'] as String?,
      clientName: map['clientName'] as String?,
      proposalId: map['proposalId'] as String?,
      proposalCode: map['proposalCode'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble() ?? -15.7942,
      longitude: (map['longitude'] as num?)?.toDouble() ?? -47.8822,
      formattedAddress: map['formattedAddress'] as String? ?? '',
      zoom: (map['zoom'] as num?)?.toDouble() ?? 18.5,
      metersPerPixel: (map['metersPerPixel'] as num?)?.toDouble() ?? 0.05,
      panOffsetX: (map['panOffsetX'] as num?)?.toDouble() ?? 0.0,
      panOffsetY: (map['panOffsetY'] as num?)?.toDouble() ?? 0.0,
      satelliteSource: map['satelliteSource'] as String? ?? 'googleHybrid',
      mapsSections: parsedMapsSections,
      mapsPanOffsetX: (map['mapsPanOffsetX'] as num?)?.toDouble() ?? (map['panOffsetX'] as num?)?.toDouble() ?? 0.0,
      mapsPanOffsetY: (map['mapsPanOffsetY'] as num?)?.toDouble() ?? (map['panOffsetY'] as num?)?.toDouble() ?? 0.0,
      mapsZoom: (map['mapsZoom'] as num?)?.toDouble() ?? (map['zoom'] as num?)?.toDouble() ?? 18.5,
      droneSections: parsedDroneSections,
      droneImageUrl: map['droneImageUrl'] as String?,
      droneImageFileName: map['droneImageFileName'] as String?,
      droneMetersPerPixel: (map['droneMetersPerPixel'] as num?)?.toDouble(),
      dronePanOffsetX: (map['dronePanOffsetX'] as num?)?.toDouble() ?? 0.0,
      dronePanOffsetY: (map['dronePanOffsetY'] as num?)?.toDouble() ?? 0.0,
      droneZoom: (map['droneZoom'] as num?)?.toDouble() ?? 18.0,
      lastActiveMode: lastActiveMode,
      sections: activeSections,
      totalModulesCount: (map['totalModulesCount'] as num?)?.toInt() ?? 0,
      totalKwp: (map['totalKwp'] as num?)?.toDouble() ?? 0.0,
      estimatedMonthlyKwh: (map['estimatedMonthlyKwh'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] as String? ?? 'completed',
      thumbnailBase64: map['thumbnailBase64'] as String?,
      createdByUserId: map['createdByUserId'] as String? ?? '',
      createdByUserName: map['createdByUserName'] as String? ?? '',
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }

  // ── SERIALIZADORES AUXILIARES ───────────────────────────────────────────────

  static Map<String, dynamic> _sectionToMap(RoofSection sec) {
    return {
      'id': sec.id,
      'name': sec.name,
      'isClosed': sec.isClosed,
      'orientation': sec.orientation == ModuleOrientation.portrait ? 'portrait' : 'landscape',
      'rotationDegrees': sec.rotationDegrees,
      'setbackMeters': sec.setbackMeters,
      'themeColor': sec.themeColor.toARGB32(),
      'moduleSpec': {
        'id': sec.moduleSpec.id,
        'modelName': sec.moduleSpec.modelName,
        'watts': sec.moduleSpec.watts,
        'widthMeters': sec.moduleSpec.widthMeters,
        'heightMeters': sec.moduleSpec.heightMeters,
        'weightKg': sec.moduleSpec.weightKg,
      },
      'vertices': sec.vertices.map((v) => {'x': v.x, 'y': v.y}).toList(),
      'modules': sec.modules
          .map((m) => {
                'id': m.id,
                'rowId': m.rowId,
                'centerX': m.center.x,
                'centerY': m.center.y,
                'widthMeters': m.widthMeters,
                'heightMeters': m.heightMeters,
                'rotationRadians': m.rotationRadians,
                'isExcluded': m.isExcluded,
                'watts': m.watts,
              })
          .toList(),
    };
  }

  static RoofSection _sectionFromMap(Map<String, dynamic> map) {
    final rawVertices = map['vertices'] as List<dynamic>? ?? [];
    final vertices = rawVertices
        .map((v) => RoofPoint(
              (v['x'] as num).toDouble(),
              (v['y'] as num).toDouble(),
            ))
        .toList();

    final rawModules = map['modules'] as List<dynamic>? ?? [];
    final modules = rawModules
        .map((m) => PlacedModule(
              id: m['id'] as String? ?? 'mod_${m['centerX']}_${m['centerY']}',
              rowId: m['rowId'] as String?,
              center: RoofPoint(
                (m['centerX'] as num?)?.toDouble() ?? 0.0,
                (m['centerY'] as num?)?.toDouble() ?? 0.0,
              ),
              widthMeters: (m['widthMeters'] as num?)?.toDouble() ??
                  (m['width'] as num?)?.toDouble() ??
                  1.134,
              heightMeters: (m['heightMeters'] as num?)?.toDouble() ??
                  (m['height'] as num?)?.toDouble() ??
                  2.278,
              rotationRadians: (m['rotationRadians'] as num?)?.toDouble() ??
                  ((m['rotationDegrees'] as num?)?.toDouble() != null
                      ? (m['rotationDegrees'] as num).toDouble() * 3.141592653589793 / 180.0
                      : 0.0),
              isExcluded: m['isExcluded'] as bool? ?? false,
              watts: (m['watts'] as num?)?.toInt() ?? 615,
            ))
        .toList();

    final modMap = map['moduleSpec'] as Map<String, dynamic>?;
    final moduleSpec = modMap != null
        ? SolarModuleSpec(
            id: modMap['id'] as String? ?? 'mod_615w',
            modelName: modMap['modelName'] as String? ?? 'Módulo Padrão',
            watts: (modMap['watts'] as num?)?.toInt() ?? 615,
            widthMeters: (modMap['widthMeters'] as num?)?.toDouble() ?? 1.134,
            heightMeters: (modMap['heightMeters'] as num?)?.toDouble() ?? 2.278,
            weightKg: (modMap['weightKg'] as num?)?.toDouble() ?? 28.5,
          )
        : SolarModuleSpec.presets.first;

    final orientationStr = map['orientation'] as String? ?? 'portrait';
    final orientation = orientationStr == 'landscape'
        ? ModuleOrientation.landscape
        : ModuleOrientation.portrait;

    final colorVal = map['themeColor'] as num?;
    final themeColor = colorVal != null
        ? ui.Color(colorVal.toInt())
        : const ui.Color(0xFFF59E0B);

    return RoofSection(
      id: map['id'] as String? ?? '1',
      name: map['name'] as String? ?? 'Telhado 1',
      vertices: vertices,
      modules: modules,
      moduleSpec: moduleSpec,
      orientation: orientation,
      rotationDegrees: (map['rotationDegrees'] as num?)?.toDouble() ?? 0.0,
      setbackMeters: (map['setbackMeters'] as num?)?.toDouble() ?? 0.30,
      themeColor: themeColor,
      isClosed: map['isClosed'] as bool? ?? vertices.length >= 3,
    );
  }
}
