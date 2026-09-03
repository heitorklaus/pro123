import 'dart:math' as math;
import '../../domain/models/solar_designer_models.dart';

/// Serviço de cálculos geométricos, projeção métrica e colisões espaciais 2D para telhados
class RoofGeometryService {
  /// Calcula a escala real de metros por pixel em uma dada latitude e nível de zoom na projeção Web Mercator
  static double getMetersPerPixel({
    required double latitude,
    required double zoomLevel,
  }) {
    final latRad = latitude * (math.pi / 180.0);
    // 156543.03392 m/px no equador no zoom 0
    return (156543.03392 * math.cos(latRad)) / math.pow(2, zoomLevel);
  }

  /// Converte distância em pixels da tela para metros reais
  static double pixelsToMeters(double pixels, double metersPerPixel) {
    return pixels * metersPerPixel;
  }

  /// Converte distância em metros reais para pixels na tela
  static double metersToPixels(double meters, double metersPerPixel) {
    if (metersPerPixel <= 0) return 0.0;
    return meters / metersPerPixel;
  }

  /// Algoritmo Ray-Casting (Tiro de Raio) para verificar se um ponto está estritamente dentro de um polígono
  static bool isPointInsidePolygon(RoofPoint point, List<RoofPoint> polygon) {
    if (polygon.length < 3) return false;

    bool inside = false;
    int j = polygon.length - 1;

    for (int i = 0; i < polygon.length; i++) {
      final pi = polygon[i];
      final pj = polygon[j];

      final intersect = ((pi.y > point.y) != (pj.y > point.y)) &&
          (point.x < (pj.x - pi.x) * (point.y - pi.y) / (pj.y - pi.y) + pi.x);

      if (intersect) {
        inside = !inside;
      }
      j = i;
    }

    return inside;
  }

  /// Verifica se todos os 4 cantos de uma placa solar (e seu centro) estão dentro do telhado
  static bool isModuleFullyInsideRoof({
    required PlacedModule module,
    required RoofPolygon roof,
    double setbackMeters = 0.25, // Recuo de segurança das bordas do telhado
  }) {
    if (!roof.isClosed) return false;

    // 1. O centro da placa deve estar dentro
    if (!isPointInsidePolygon(module.center, roof.vertices)) {
      return false;
    }

    // 2. Todos os cantos da placa devem estar dentro do polígono
    final corners = module.getCorners();
    for (final corner in corners) {
      if (!isPointInsidePolygon(corner, roof.vertices)) {
        return false;
      }
    }

    // 3. Verifica distância mínima às arestas do telhado (Setback de segurança)
    if (setbackMeters > 0) {
      for (final corner in corners) {
        final dist = distanceToPolygonEdges(corner, roof.vertices);
        if (dist < setbackMeters) {
          return false;
        }
      }
    }

    return true;
  }

  /// Calcula a menor distância de um ponto a qualquer uma das arestas de um polígono
  static double distanceToPolygonEdges(RoofPoint point, List<RoofPoint> polygon) {
    if (polygon.length < 2) return double.infinity;
    double minDistance = double.infinity;

    for (int i = 0; i < polygon.length; i++) {
      final p1 = polygon[i];
      final p2 = polygon[(i + 1) % polygon.length];

      final d = distanceToSegment(point, p1, p2);
      if (d < minDistance) {
        minDistance = d;
      }
    }
    return minDistance;
  }

  /// Distância perpendicular de um ponto a um segmento de reta [p1, p2]
  static double distanceToSegment(RoofPoint p, RoofPoint p1, RoofPoint p2) {
    final l2 = (p2.x - p1.x) * (p2.x - p1.x) + (p2.y - p1.y) * (p2.y - p1.y);
    if (l2 == 0) return p.distanceTo(p1);

    // Projeção do ponto no segmento
    final t = math.max(0.0, math.min(1.0, ((p.x - p1.x) * (p2.x - p1.x) + (p.y - p1.y) * (p2.y - p1.y)) / l2));
    final projection = RoofPoint(p1.x + t * (p2.x - p1.x), p1.y + t * (p2.y - p1.y));
    return p.distanceTo(projection);
  }

  /// Calcula o Azimute (Orientação solar em graus: 0° Norte, 90° Leste, 180° Sul, 270° Oeste)
  static double calculateAzimuthDegrees(RoofPoint p1, RoofPoint p2) {
    final rad = math.atan2(p2.x - p1.x, -(p2.y - p1.y));
    double deg = rad * (180.0 / math.pi);
    if (deg < 0) deg += 360.0;
    return deg;
  }

  /// Retorna o nome amigável da orientação solar (ex: Norte, Nordeste, etc.)
  static String getAzimuthLabel(double degrees) {
    final normalized = (degrees % 360 + 360) % 360;
    if (normalized >= 337.5 || normalized < 22.5) return 'Norte (0°) • Ideal ☀️';
    if (normalized >= 22.5 && normalized < 67.5) return 'Nordeste (45°) • Excelente';
    if (normalized >= 67.5 && normalized < 112.5) return 'Leste (90°) • Manhã';
    if (normalized >= 112.5 && normalized < 157.5) return 'Sudeste (135°) • Bom';
    if (normalized >= 157.5 && normalized < 202.5) return 'Sul (180°) • Menor Geração';
    if (normalized >= 202.5 && normalized < 247.5) return 'Sudoeste (225°) • Bom';
    if (normalized >= 247.5 && normalized < 292.5) return 'Oeste (270°) • Tarde';
    return 'Noroeste (315°) • Excelente';
  }
}
