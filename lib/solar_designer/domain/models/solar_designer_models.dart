import 'dart:math' as math;
import 'dart:ui' as ui;

/// Ponto de coordenada métrica ou pixel no espaço 2D do telhado
class RoofPoint {
  final double x;
  final double y;

  const RoofPoint(this.x, this.y);

  RoofPoint translate(double dx, double dy) => RoofPoint(x + dx, y + dy);

  double distanceTo(RoofPoint other) {
    final dx = other.x - x;
    final dy = other.y - y;
    return math.sqrt(dx * dx + dy * dy);
  }

  ui.Offset toOffset() => ui.Offset(x, y);

  factory RoofPoint.fromOffset(ui.Offset offset) => RoofPoint(offset.dx, offset.dy);

  @override
  String toString() => 'RoofPoint(${x.toStringAsFixed(1)}, ${y.toStringAsFixed(1)})';
}

/// Orientação física dos módulos fotovoltaicos no telhado
enum ModuleOrientation {
  portrait, // Retrato (Vertical)
  landscape, // Paisagem (Horizontal)
}

extension ModuleOrientationExt on ModuleOrientation {
  String get label => this == ModuleOrientation.portrait ? 'Retrato (Vertical)' : 'Paisagem (Horizontal)';
}

/// Especificação técnica e dimensões físicas do módulo solar
class SolarModuleSpec {
  final String id;
  final String modelName;
  final int watts;
  final double widthMeters;
  final double heightMeters;
  final double weightKg;

  const SolarModuleSpec({
    required this.id,
    required this.modelName,
    required this.watts,
    required this.widthMeters,
    required this.heightMeters,
    this.weightKg = 28.5,
  });

  /// Área superficial ocupada por uma única placa em m²
  double get areaM2 => widthMeters * heightMeters;

  /// Retorna a largura considerando a orientação
  double getWidth(ModuleOrientation orientation) =>
      orientation == ModuleOrientation.portrait ? widthMeters : heightMeters;

  /// Retorna a altura considerando a orientação
  double getHeight(ModuleOrientation orientation) =>
      orientation == ModuleOrientation.portrait ? heightMeters : widthMeters;

  /// Lista de módulos comerciais padrão mais utilizados no mercado brasileiro
  static const List<SolarModuleSpec> presets = [
    SolarModuleSpec(
      id: 'mod_615w',
      modelName: 'Módulo TopCon 615W N-Type (2.28m × 1.13m)',
      watts: 615,
      widthMeters: 1.134,
      heightMeters: 2.278,
      weightKg: 31.2,
    ),
    SolarModuleSpec(
      id: 'mod_580w',
      modelName: 'Módulo TopCon 580W N-Type (2.28m × 1.13m)',
      watts: 580,
      widthMeters: 1.134,
      heightMeters: 2.278,
      weightKg: 30.5,
    ),
    SolarModuleSpec(
      id: 'mod_550w',
      modelName: 'Módulo Mono PERC 550W (2.28m × 1.13m)',
      watts: 550,
      widthMeters: 1.134,
      heightMeters: 2.279,
      weightKg: 28.6,
    ),
    SolarModuleSpec(
      id: 'mod_450w',
      modelName: 'Módulo Residencial 450W (2.09m × 1.04m)',
      watts: 450,
      widthMeters: 1.038,
      heightMeters: 2.094,
      weightKg: 24.5,
    ),
  ];
}

/// Placa fotovoltaica individual alocada no telhado
class PlacedModule {
  final String id;
  final String? rowId; // Identificador da fileira (para permitir exclusão em lote da linha)
  final RoofPoint center;
  final double widthMeters;
  final double heightMeters;
  final double rotationRadians;
  final int watts;
  bool isExcluded; // Se o operador clicou para remover (ex: obstrução de chaminé/sombra)

  PlacedModule({
    required this.id,
    this.rowId,
    required this.center,
    required this.widthMeters,
    required this.heightMeters,
    this.rotationRadians = 0.0,
    required this.watts,
    this.isExcluded = false,
  });

  /// Vértices do retângulo da placa em metros relativos
  List<RoofPoint> getCorners() {
    final hw = widthMeters / 2;
    final hh = heightMeters / 2;
    final cosA = math.cos(rotationRadians);
    final sinA = math.sin(rotationRadians);

    final localPoints = [
      [-hw, -hh],
      [hw, -hh],
      [hw, hh],
      [-hw, hh],
    ];

    return localPoints.map((p) {
      final rx = p[0] * cosA - p[1] * sinA;
      final ry = p[0] * sinA + p[1] * cosA;
      return RoofPoint(center.x + rx, center.y + ry);
    }).toList();
  }

  PlacedModule translate(double dxMeters, double dyMeters) {
    return PlacedModule(
      id: id,
      rowId: rowId,
      center: RoofPoint(center.x + dxMeters, center.y + dyMeters),
      widthMeters: widthMeters,
      heightMeters: heightMeters,
      rotationRadians: rotationRadians,
      watts: watts,
      isExcluded: isExcluded,
    );
  }

  PlacedModule copyWith({
    String? id,
    String? rowId,
    RoofPoint? center,
    double? widthMeters,
    double? heightMeters,
    double? rotationRadians,
    int? watts,
    bool? isExcluded,
  }) {
    return PlacedModule(
      id: id ?? this.id,
      rowId: rowId ?? this.rowId,
      center: center ?? this.center,
      widthMeters: widthMeters ?? this.widthMeters,
      heightMeters: heightMeters ?? this.heightMeters,
      rotationRadians: rotationRadians ?? this.rotationRadians,
      watts: watts ?? this.watts,
      isExcluded: isExcluded ?? this.isExcluded,
    );
  }

  /// Verifica se um ponto (em metros) está contido dentro desta placa
  bool containsPoint(RoofPoint point) {
    final dx = point.x - center.x;
    final dy = point.y - center.y;
    final cosA = math.cos(-rotationRadians);
    final sinA = math.sin(-rotationRadians);
    final localX = dx * cosA - dy * sinA;
    final localY = dx * sinA + dy * cosA;

    return (localX.abs() <= widthMeters / 2.0) && (localY.abs() <= heightMeters / 2.0);
  }

  /// Rotaciona a placa em torno de um ponto pivô (ex: centróide do arranjo)
  PlacedModule rotateAround(RoofPoint pivot, double angleRadians) {
    final dx = center.x - pivot.x;
    final dy = center.y - pivot.y;
    final cosA = math.cos(angleRadians);
    final sinA = math.sin(angleRadians);
    final newCenterX = pivot.x + dx * cosA - dy * sinA;
    final newCenterY = pivot.y + dx * sinA + dy * cosA;

    return PlacedModule(
      id: id,
      rowId: rowId,
      center: RoofPoint(newCenterX, newCenterY),
      widthMeters: widthMeters,
      heightMeters: heightMeters,
      rotationRadians: (rotationRadians + angleRadians) % (2 * math.pi),
      watts: watts,
      isExcluded: isExcluded,
    );
  }
}

/// Modo da camada visual de fundo
enum BackgroundLayerMode {
  satellite,
  dronePhoto,
}

/// Aresta delimitadora do telhado com índice e ponto médio
class RoofEdge {
  final int index;
  final RoofPoint start;
  final RoofPoint end;
  final double lengthMeters;
  final RoofPoint midpoint;

  const RoofEdge({
    required this.index,
    required this.start,
    required this.end,
    required this.lengthMeters,
    required this.midpoint,
  });
}

/// Polígono delimitador da água do telhado
class RoofPolygon {
  final List<RoofPoint> vertices;

  const RoofPolygon({required this.vertices});

  bool get isClosed => vertices.length >= 3;

  /// Algoritmo de Ray Casting para verificar se um ponto métrico está dentro do polígono
  bool containsPoint(RoofPoint p) {
    if (vertices.length < 3) return false;
    bool inside = false;
    int j = vertices.length - 1;
    for (int i = 0; i < vertices.length; i++) {
      final vi = vertices[i];
      final vj = vertices[j];
      if (((vi.y > p.y) != (vj.y > p.y)) &&
          (p.x < (vj.x - vi.x) * (p.y - vi.y) / (vj.y - vi.y) + vi.x)) {
        inside = !inside;
      }
      j = i;
    }
    return inside;
  }

  /// Retorna as arestas numeradas do telhado com seus pontos médios
  List<RoofEdge> get edges {
    if (vertices.length < 2) return [];
    final list = <RoofEdge>[];
    for (int i = 0; i < vertices.length; i++) {
      final v1 = vertices[i];
      final v2 = vertices[(i + 1) % vertices.length];
      list.add(RoofEdge(
        index: i,
        start: v1,
        end: v2,
        lengthMeters: v1.distanceTo(v2),
        midpoint: RoofPoint((v1.x + v2.x) / 2.0, (v1.y + v2.y) / 2.0),
      ));
    }
    return list;
  }

  /// Escala o polígono por um fator proporcional a partir do seu centróide
  RoofPolygon scale(double factor) {
    if (factor <= 0 || vertices.isEmpty) return this;
    final c = centroid;
    final scaled = vertices.map((v) {
      final dx = v.x - c.x;
      final dy = v.y - c.y;
      return RoofPoint(c.x + dx * factor, c.y + dy * factor);
    }).toList();
    return RoofPolygon(vertices: scaled);
  }

  /// Escala o polígono para que uma aresta específica passe a ter exatamente targetLengthMeters
  RoofPolygon scaleEdge(int edgeIndex, double targetLengthMeters) {
    if (vertices.length < 2 || edgeIndex < 0 || edgeIndex >= vertices.length) return this;
    final v1 = vertices[edgeIndex];
    final v2 = vertices[(edgeIndex + 1) % vertices.length];
    final currentLength = v1.distanceTo(v2);
    if (currentLength <= 0.001 || targetLengthMeters <= 0.001) return this;
    final factor = targetLengthMeters / currentLength;
    return scale(factor);
  }

  /// Calcula a área em m² utilizando a Shoelace Formula (Fórmula de Gauss)
  double get areaM2 {
    if (vertices.length < 3) return 0.0;
    double sum = 0.0;
    for (int i = 0; i < vertices.length; i++) {
      final current = vertices[i];
      final next = vertices[(i + 1) % vertices.length];
      sum += (current.x * next.y) - (next.x * current.y);
    }
    return (sum.abs()) / 2.0;
  }

  /// Calcula o perímetro total do telhado em metros
  double get perimeterMeters {
    if (vertices.length < 2) return 0.0;
    double sum = 0.0;
    for (int i = 0; i < vertices.length; i++) {
      final current = vertices[i];
      final next = vertices[(i + 1) % vertices.length];
      sum += current.distanceTo(next);
    }
    return sum;
  }

  /// Ponto central (Centróide) do polígono
  RoofPoint get centroid {
    if (vertices.isEmpty) return const RoofPoint(0, 0);
    double sx = 0;
    double sy = 0;
    for (final v in vertices) {
      sx += v.x;
      sy += v.y;
    }
    return RoofPoint(sx / vertices.length, sy / vertices.length);
  }

  /// Ângulo da borda mais longa (usado para alinhar o grid de placas com a cumeeira)
  double get dominantEdgeAngleRadians {
    if (vertices.length < 2) return 0.0;
    double maxLength = 0.0;
    double bestAngle = 0.0;

    for (int i = 0; i < vertices.length; i++) {
      final current = vertices[i];
      final next = vertices[(i + 1) % vertices.length];
      final len = current.distanceTo(next);
      if (len > maxLength) {
        maxLength = len;
        bestAngle = math.atan2(next.y - current.y, next.x - current.x);
      }
    }
    return bestAngle;
  }
}

/// Seção individual de telhado (Água / Queda / Conjunto) com seu próprio polígono e arranjo de placas
class RoofSection {
  final String id;
  final String name; // ex: "Água 1", "Água 2 (Superior)", "Garagem"
  final List<RoofPoint> vertices;
  final bool isClosed;
  final List<PlacedModule> modules;
  final SolarModuleSpec moduleSpec;
  final ModuleOrientation orientation;
  final double rotationDegrees;
  final double setbackMeters;
  final ui.Color themeColor;

  RoofSection({
    required this.id,
    required this.name,
    required this.vertices,
    this.isClosed = false,
    required this.modules,
    required this.moduleSpec,
    this.orientation = ModuleOrientation.portrait,
    this.rotationDegrees = 0.0,
    this.setbackMeters = 0.30,
    this.themeColor = const ui.Color(0xFFF59E0B),
  });

  RoofPolygon get polygon => RoofPolygon(vertices: vertices);
  double get areaM2 => polygon.areaM2;
  int get activeModuleCount => modules.where((m) => !m.isExcluded).length;
  double get totalKwp => (activeModuleCount * moduleSpec.watts) / 1000.0;
  double get estimatedMonthlyKwh => totalKwp * 130.0;

  RoofSection copyWith({
    String? id,
    String? name,
    List<RoofPoint>? vertices,
    bool? isClosed,
    List<PlacedModule>? modules,
    SolarModuleSpec? moduleSpec,
    ModuleOrientation? orientation,
    double? rotationDegrees,
    double? setbackMeters,
    ui.Color? themeColor,
  }) {
    return RoofSection(
      id: id ?? this.id,
      name: name ?? this.name,
      vertices: vertices ?? List.from(this.vertices),
      isClosed: isClosed ?? this.isClosed,
      modules: modules ?? List.from(this.modules),
      moduleSpec: moduleSpec ?? this.moduleSpec,
      orientation: orientation ?? this.orientation,
      rotationDegrees: rotationDegrees ?? this.rotationDegrees,
      setbackMeters: setbackMeters ?? this.setbackMeters,
      themeColor: themeColor ?? this.themeColor,
    );
  }
}

/// Resultado completo do estudo de telhado solar
class RoofStudyResult {
  final String? snapshotImageBase64;
  final int totalModules;
  final int totalWatts;
  final double totalKwp;
  final double roofAreaM2;
  final double moduleAreaM2;
  final double estimatedMonthlyKwh;
  final String address;
  final SolarModuleSpec selectedModule;
  final List<RoofSection>? sections;
  final DateTime createdAt;

  RoofStudyResult({
    this.snapshotImageBase64,
    required this.totalModules,
    required this.totalWatts,
    required this.totalKwp,
    required this.roofAreaM2,
    required this.moduleAreaM2,
    required this.estimatedMonthlyKwh,
    required this.address,
    required this.selectedModule,
    this.sections,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Percentual de aproveitamento do telhado
  double get utilizationPercentage =>
      roofAreaM2 > 0 ? ((moduleAreaM2 / roofAreaM2) * 100).clamp(0, 100) : 0.0;
}
