import 'dart:math' as math;
import '../../domain/models/solar_designer_models.dart';
import 'roof_geometry_service.dart';

/// Motor de alocação, empacotamento 2D e dimensionamento de placas solares sobre o telhado
class ModuleLayoutEngine {
  /// Gera automaticamente a malha otimizada de módulos fotovoltaicos preenchendo o telhado
  static List<PlacedModule> autoFillModules({
    required RoofPolygon roof,
    required SolarModuleSpec moduleSpec,
    required ModuleOrientation orientation,
    double spacingMeters = 0.02, // 2cm de folga entre módulos (presilhas de fixação)
    double rowSpacingMeters = 0.05, // 5cm entre fileiras
    double setbackMeters = 0.30, // 30cm de recuo de segurança da beirada/cumeeira
    double? customRotationRadians, // Rotação personalizada ou alinhamento com a cumeeira
  }) {
    if (!roof.isClosed || roof.vertices.length < 3) return [];

    final width = moduleSpec.getWidth(orientation);
    final height = moduleSpec.getHeight(orientation);

    // Determina o ângulo de alinhamento das placas (ou alinha com a borda mais longa do telhado)
    final rotation = customRotationRadians ?? roof.dominantEdgeAngleRadians;

    // Encontra o centro e a caixa delimitadora (Bounding Box) do telhado
    final centroid = roof.centroid;
    double minX = double.infinity, maxX = -double.infinity;
    double minY = double.infinity, maxY = -double.infinity;

    for (final v in roof.vertices) {
      if (v.x < minX) minX = v.x;
      if (v.x > maxX) maxX = v.x;
      if (v.y < minY) minY = v.y;
      if (v.y > maxY) maxY = v.y;
    }

    final spanX = maxX - minX;
    final spanY = maxY - minY;
    final maxRadius = math.max(spanX, spanY) * 1.4;

    final stepX = width + spacingMeters;
    final stepY = height + rowSpacingMeters;

    final cosA = math.cos(rotation);
    final sinA = math.sin(rotation);

    final List<PlacedModule> modules = [];
    int moduleCounter = 1;

    final stepsX = (maxRadius / stepX).ceil();
    final stepsY = (maxRadius / stepY).ceil();

    // Varre em grade a partir do centroide
    for (int iy = -stepsY; iy <= stepsY; iy++) {
      for (int ix = -stepsX; ix <= stepsX; ix++) {
        final localX = ix * stepX;
        final localY = iy * stepY;

        // Aplica a rotação da grade
        final rotX = localX * cosA - localY * sinA;
        final rotY = localX * sinA + localY * cosA;

        final worldCenter = RoofPoint(centroid.x + rotX, centroid.y + rotY);

        final candidate = PlacedModule(
          id: 'mod_$moduleCounter',
          center: worldCenter,
          widthMeters: width,
          heightMeters: height,
          rotationRadians: rotation,
          watts: moduleSpec.watts,
          isExcluded: false,
        );

        // Testa se cabe dentro do polígono respeitando o recuo de borda
        if (RoofGeometryService.isModuleFullyInsideRoof(
          module: candidate,
          roof: roof,
          setbackMeters: setbackMeters,
        )) {
          modules.add(candidate);
          moduleCounter++;
        }
      }
    }

    return modules;
  }

  /// Calcula a potência de pico total dos módulos ativos em kWp
  static double calculateTotalKwp(List<PlacedModule> modules, SolarModuleSpec spec) {
    final activeCount = modules.where((m) => !m.isExcluded).length;
    return (activeCount * spec.watts) / 1000.0;
  }

  /// Estima a geração de energia mensal média em kWh (média Brasil: ~125 a 135 kWh/mês por kWp)
  static double estimateMonthlyGenerationKwh(double kwp) {
    return kwp * 128.0;
  }

  /// Encontra se o clique do usuário acertou alguma placa existente para alternar exclusão
  static PlacedModule? findModuleAtPoint(RoofPoint clickPoint, List<PlacedModule> modules) {
    for (final mod in modules.reversed) {
      final corners = mod.getCorners();
      if (RoofGeometryService.isPointInsidePolygon(clickPoint, corners)) {
        return mod;
      }
    }
    return null;
  }
}
