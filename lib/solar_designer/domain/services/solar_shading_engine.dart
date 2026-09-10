import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/solar_designer_models.dart';

/// Posição astronômica e vetores de incidência solar
class SolarSunPosition {
  final double hourOfDay; // Ex: 14.5 = 14h30
  final double elevationDegrees; // Altura angular do sol acima do horizonte (0° a 90°)
  final double azimuthDegrees; // Direção da bússola de onde o sol vem (0°=N, 90°=L, 180°=S, 270°=O)
  final bool isSunUp;

  const SolarSunPosition({
    required this.hourOfDay,
    required this.elevationDegrees,
    required this.azimuthDegrees,
    required this.isSunUp,
  });

  /// Vetor da direção para onde a sombra é PROJETADA (oposta ao azimute solar)
  /// Sombra aponta 180° oposto ao sol
  double get shadowDirectionRadians {
    final shadowAzimuth = (azimuthDegrees + 180.0) % 360.0;
    // Converte de Azimute de navegação (0°=Norte/cima, 90°=Leste/direita) para radianos do Canvas (+X=Leste, -Y=Norte)
    // Canvas: 0 rad = +X (Leste), -pi/2 = -Y (Norte)
    final canvasRad = (shadowAzimuth - 90.0) * (math.pi / 180.0);
    return canvasRad;
  }

  /// Retorna o ângulo na tela (em radianos) de onde o Sol incide, calibrado pela orientação do Norte
  /// northRotationRadians: 0 rad = Norte aponta para cima (-Y); pi/2 = Norte aponta para a direita (+X)
  double getEffectiveSunAngleRadians(double northRotationRadians) {
    final sunAzRad = azimuthDegrees * (math.pi / 180.0);
    return northRotationRadians + sunAzRad;
  }

  /// Retorna o vetor unitário na tela (Offset) para onde a sombra é projetada
  Offset getShadowProjectionVector(double northRotationRadians) {
    final effAngle = getEffectiveSunAngleRadians(northRotationRadians);
    // Sol vem de effAngle a partir de -Y; a sombra é projetada no sentido oposto
    return Offset(-math.sin(effAngle), math.cos(effAngle));
  }
}

/// Status de sombreamento de um módulo individual em um determinado horário
class ModuleShadingStatus {
  final String moduleId;
  final bool isShaded;
  final double shadedPercentage; // 0.0 = 100% ao sol, 1.0 = 100% sob sombra
  final String? castingSectionName; // Nome do telhado/torre que causou a sombra

  const ModuleShadingStatus({
    required this.moduleId,
    required this.isShaded,
    this.shadedPercentage = 0.0,
    this.castingSectionName,
  });
}

/// Diagnóstico de sombreamento acumulado ao longo de todo o dia (06:00 às 18:00)
class DailyShadingSimulationResult {
  final double overallEfficiencyPercentage; // Ex: 94.5% (Aproveitamento diário)
  final double totalLossPercentage; // Ex: 5.5% (Perda por sombra)
  final double effectiveSunHours; // Ex: 5.2 horas
  final Map<int, double> hourlyEfficiency; // Hora -> Eficiência (ex: 8 -> 85%, 12 -> 100%)
  final Map<String, double> moduleDailySunPercentage; // ID do Módulo -> % de sol no dia
  final int totalModulesCount;
  final int shadedAtCurrentHourCount;

  const DailyShadingSimulationResult({
    required this.overallEfficiencyPercentage,
    required this.totalLossPercentage,
    required this.effectiveSunHours,
    required this.hourlyEfficiency,
    required this.moduleDailySunPercentage,
    required this.totalModulesCount,
    required this.shadedAtCurrentHourCount,
  });
}

/// Motor de Cálculo de Posição Solar e Projeção Tridimensional de Sombreamento
class SolarShadingEngine {
  /// Calcula a posição aproximada do Sol para qualquer latitude brasileira e hora do dia
  /// (Latitude padrão: -23.5° [Sudeste / SP / PR / Centro-Sul], ajustável pelo estudo)
  static SolarSunPosition calculateSunPosition({
    required double hourOfDay,
    double latitude = -23.55,
    int dayOfYear = 80, // Equinócio médio de Outono/Primavera (ótima referência neutra)
  }) {
    if (hourOfDay < 5.8 || hourOfDay > 18.2) {
      return SolarSunPosition(
        hourOfDay: hourOfDay,
        elevationDegrees: 0.0,
        azimuthDegrees: 0.0,
        isSunUp: false,
      );
    }

    // Ângulo da hora: 12h = 0°, 1h = 15°, 6h = -90°, 18h = +90°
    final hourAngleDeg = (hourOfDay - 12.0) * 15.0;
    final hourAngleRad = hourAngleDeg * (math.pi / 180.0);
    final latRad = latitude * (math.pi / 180.0);

    // Declinação solar aproximada de Cooper
    final declinationDeg = 23.45 * math.sin((284 + dayOfYear) * 2 * math.pi / 365);
    final decRad = declinationDeg * (math.pi / 180.0);

    // Elevação Solar (Altitude)
    final sinElevation = math.sin(latRad) * math.sin(decRad) +
        math.cos(latRad) * math.cos(decRad) * math.cos(hourAngleRad);
    final elevationRad = math.asin(sinElevation.clamp(-1.0, 1.0));
    final elevationDeg = elevationRad * (180.0 / math.pi);

    if (elevationDeg <= 1.0) {
      return SolarSunPosition(
        hourOfDay: hourOfDay,
        elevationDegrees: math.max(0.0, elevationDeg),
        azimuthDegrees: hourOfDay < 12.0 ? 90.0 : 270.0,
        isSunUp: false,
      );
    }

    // Azimute Solar
    final cosAzimuth = (math.sin(decRad) - math.sin(latRad) * math.sin(elevationRad)) /
        (math.cos(latRad) * math.cos(elevationRad));
    final azRad = math.acos(cosAzimuth.clamp(-1.0, 1.0));
    double azimuthDeg = azRad * (180.0 / math.pi);

    // No hemisfério sul, o sol passa prioritariamente ao Norte (Azimute 0° / 360°) ao meio-dia
    if (hourAngleDeg > 0) {
      azimuthDeg = 360.0 - azimuthDeg;
    }

    return SolarSunPosition(
      hourOfDay: hourOfDay,
      elevationDegrees: elevationDeg,
      azimuthDegrees: azimuthDeg,
      isSunUp: true,
    );
  }

  /// Calcula o Envoltório Convexo (Convex Hull - Monotone Chain) de um conjunto de pontos
  /// Retorna o polígono externo contínuo e sem auto-interseções em ordem anti-horária
  static List<RoofPoint> computeConvexHull(List<RoofPoint> points) {
    if (points.length <= 3) return List.from(points);

    // Remove duplicatas muito próximas
    final unique = <RoofPoint>[];
    for (final p in points) {
      if (!unique.any((u) =>
          (u.x - p.x).abs() < 1e-4 && (u.y - p.y).abs() < 1e-4)) {
        unique.add(p);
      }
    }
    if (unique.length <= 3) return unique;

    // Ordena os pontos primeiro por X crescente, depois por Y crescente
    unique.sort((a, b) {
      final cmpX = a.x.compareTo(b.x);
      if (cmpX != 0) return cmpX;
      return a.y.compareTo(b.y);
    });

    double crossProduct(RoofPoint o, RoofPoint a, RoofPoint b) {
      return (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x);
    }

    // Casca inferior (lower hull)
    final lower = <RoofPoint>[];
    for (final p in unique) {
      while (lower.length >= 2 &&
          crossProduct(lower[lower.length - 2], lower.last, p) <= 0) {
        lower.removeLast();
      }
      lower.add(p);
    }

    // Casca superior (upper hull)
    final upper = <RoofPoint>[];
    for (final p in unique.reversed) {
      while (upper.length >= 2 &&
          crossProduct(upper[upper.length - 2], upper.last, p) <= 0) {
        upper.removeLast();
      }
      upper.add(p);
    }

    // Remove o último ponto de cada casca pois está duplicado no início da outra
    lower.removeLast();
    upper.removeLast();

    return [...lower, ...upper];
  }

  /// Calcula o polígono da sombra 2D projetado por uma seção de telhado sobre um plano inferior
  /// deltaHeightMeters: Desnível de altura entre o topo do telhado emissor e a base do receptor
  /// northRotationRadians: Orientação do Norte no canvas (0 rad = Norte para cima [-Y]; pi/2 = Norte para a direita [+X])
  static List<RoofPoint> projectShadowPolygon({
    required List<RoofPoint> casterVertices,
    required double deltaHeightMeters,
    required SolarSunPosition sun,
    double northRotationRadians = 0.0,
  }) {
    if (casterVertices.length < 3 ||
        deltaHeightMeters <= 0.05 ||
        !sun.isSunUp ||
        sun.elevationDegrees <= 2.0) {
      return [];
    }

    // Comprimento da sombra: L = H / tan(elevação)
    final elevationRad = sun.elevationDegrees * (math.pi / 180.0);
    // Limita a projeção para evitar sombras infinitas no nascer/pôr do sol
    final maxShadow = math.max(60.0, deltaHeightMeters * 4.0);
    final shadowLength =
        math.min(maxShadow, deltaHeightMeters / math.tan(elevationRad));

    // Vetor de deslocamento da sombra calibrado pela rotação do Norte
    final shadowVec = sun.getShadowProjectionVector(northRotationRadians);
    final dxMeters = shadowLength * shadowVec.dx;
    final dyMeters = shadowLength * shadowVec.dy;

    // Vértices do topo projetados no chão
    final projectedPoints = casterVertices
        .map((p) => RoofPoint(p.x + dxMeters, p.y + dyMeters))
        .toList();

    // Constrói a silhueta sólida e sem auto-interseção da sombra via Convex Hull
    // (Garante preenchimento contínuo sem fendas, cortes ou formato de garfo)
    return computeConvexHull([...casterVertices, ...projectedPoints]);
  }

  /// Avalia a incidência de sombra em tempo real para todos os módulos de todas as seções
  static Map<String, ModuleShadingStatus> evaluateModulesShading({
    required List<RoofSection> allSections,
    required SolarSunPosition sun,
    double northRotationRadians = 0.0,
  }) {
    final result = <String, ModuleShadingStatus>{};

    if (!sun.isSunUp || sun.elevationDegrees <= 2.0) {
      // Fora das horas de sol: todos sem radiação
      for (final sec in allSections) {
        for (final mod in sec.modules) {
          result[mod.id] = ModuleShadingStatus(
            moduleId: mod.id,
            isShaded: true,
            shadedPercentage: 1.0,
          );
        }
      }
      return result;
    }

    // Inicializa todos como 100% ao sol
    for (final sec in allSections) {
      for (final mod in sec.modules) {
        result[mod.id] = ModuleShadingStatus(
          moduleId: mod.id,
          isShaded: false,
          shadedPercentage: 0.0,
        );
      }
    }

    // Para cada par de seções (Caster mais alto -> Receiver mais baixo):
    for (int i = 0; i < allSections.length; i++) {
      final caster = allSections[i];
      if (caster.vertices.length < 3) continue;
      final casterH = caster.peakHeightMeters;

      for (int j = 0; j < allSections.length; j++) {
        if (i == j) continue;
        final receiver = allSections[j];
        final receiverH = receiver.baseHeightMeters;

        final deltaH = casterH - receiverH;
        if (deltaH <= 0.20) continue; // Caster não é alto o suficiente para sombrear o receptor

        // Calcula a mancha de sombra projetada pelo caster no nível do receptor (calibrada pelo Norte)
        final shadowPoly = projectShadowPolygon(
          casterVertices: caster.vertices,
          deltaHeightMeters: deltaH,
          sun: sun,
          northRotationRadians: northRotationRadians,
        );

        if (shadowPoly.length < 3) continue;
        final shadowRoofPoly = RoofPolygon(vertices: shadowPoly);

        // Testa cada módulo do receptor contra a mancha de sombra
        for (final mod in receiver.modules) {
          if (mod.isExcluded) continue;

          // Testa o centróide e os 4 cantos da placa para precisão milimétrica
          final corners = mod.getCorners();
          int pointsUnderShadow = 0;

          if (shadowRoofPoly.containsPoint(mod.center)) {
            pointsUnderShadow += 2;
          }
          for (final corner in corners) {
            if (shadowRoofPoly.containsPoint(corner)) {
              pointsUnderShadow++;
            }
          }

          if (pointsUnderShadow > 0) {
            final shadedRatio = (pointsUnderShadow / 6.0).clamp(0.0, 1.0);
            result[mod.id] = ModuleShadingStatus(
              moduleId: mod.id,
              isShaded: true,
              shadedPercentage: shadedRatio,
              castingSectionName: caster.name,
            );
          }
        }
      }
    }

    return result;
  }

  /// Executa a simulação completa do dia inteiro (das 06:00 às 18:00 em intervalos de 30min)
  /// gerando o gráfico de curvas, a taxa de perda por sombreamento e o aproveitamento real do sistema
  static DailyShadingSimulationResult simulateFullDay({
    required List<RoofSection> sections,
    double currentHour = 12.0,
    double latitude = -23.55,
    double northRotationRadians = 0.0,
    int dayOfYear = 172, // Padrão: Inverno (cenário mais conservador)
  }) {
    int totalModules = 0;
    for (final s in sections) {
      totalModules += s.activeModuleCount;
    }

    if (totalModules == 0) {
      return const DailyShadingSimulationResult(
        overallEfficiencyPercentage: 100.0,
        totalLossPercentage: 0.0,
        effectiveSunHours: 5.2,
        hourlyEfficiency: {},
        moduleDailySunPercentage: {},
        totalModulesCount: 0,
        shadedAtCurrentHourCount: 0,
      );
    }

    final hourlyEff = <int, double>{};
    final moduleSunSum = <String, double>{};
    final moduleSampleCount = <String, int>{};

    for (final s in sections) {
      for (final m in s.modules) {
        if (!m.isExcluded) {
          moduleSunSum[m.id] = 0.0;
          moduleSampleCount[m.id] = 0;
        }
      }
    }

    double totalIdealIrradiation = 0.0;
    double totalActualIrradiation = 0.0;

    // Amostra a cada 30 minutos das 06:00 às 18:00 (25 amostras diárias)
    for (double h = 6.0; h <= 18.0; h += 0.5) {
      final sun = calculateSunPosition(hourOfDay: h, latitude: latitude, dayOfYear: dayOfYear);
      if (!sun.isSunUp) continue;

      // Peso senoidal da irradiação no céu (sol a pino às 12h tem peso 1.0, às 7h tem ~0.25)
      final sunWeight = math.sin(sun.elevationDegrees * (math.pi / 180.0)).clamp(0.0, 1.0);

      final shading = evaluateModulesShading(
        allSections: sections,
        sun: sun,
        northRotationRadians: northRotationRadians,
      );

      double hourSunRatioSum = 0.0;
      int activeCount = 0;

      for (final s in sections) {
        for (final m in s.modules) {
          if (m.isExcluded) continue;
          activeCount++;
          final status = shading[m.id];
          final sunFraction = 1.0 - (status?.shadedPercentage ?? 0.0);
          hourSunRatioSum += sunFraction;

          moduleSunSum[m.id] = (moduleSunSum[m.id] ?? 0.0) + (sunFraction * sunWeight);
          moduleSampleCount[m.id] = (moduleSampleCount[m.id] ?? 0) + 1;
        }
      }

      final currentAvgSun = activeCount > 0 ? (hourSunRatioSum / activeCount) : 1.0;

      // Grava nas horas cheias para o gráfico
      if ((h % 1.0).abs() < 0.01) {
        hourlyEff[h.toInt()] = currentAvgSun * 100.0;
      }

      totalIdealIrradiation += sunWeight;
      totalActualIrradiation += (sunWeight * currentAvgSun);
    }

    // Calcula a eficiência global ponderada pela intensidade do sol
    final overallEfficiency = totalIdealIrradiation > 0
        ? ((totalActualIrradiation / totalIdealIrradiation) * 100.0).clamp(0.0, 100.0)
        : 100.0;
    final loss = (100.0 - overallEfficiency).clamp(0.0, 100.0);

    // Aproveitamento individual de cada placa
    final moduleDailyPercentage = <String, double>{};
    for (final entry in moduleSunSum.entries) {
      final modId = entry.key;
      final val = entry.value;
      final maxVal = totalIdealIrradiation;
      moduleDailyPercentage[modId] = maxVal > 0 ? ((val / maxVal) * 100.0).clamp(0.0, 100.0) : 100.0;
    }

    // Avalia o momento atual selecionado no slider
    final currentSun = calculateSunPosition(hourOfDay: currentHour, latitude: latitude, dayOfYear: dayOfYear);
    final currentShading = evaluateModulesShading(
      allSections: sections,
      sun: currentSun,
      northRotationRadians: northRotationRadians,
    );
    int currentShaded = 0;
    for (final s in sections) {
      for (final m in s.modules) {
        if (!m.isExcluded && (currentShading[m.id]?.isShaded ?? false)) {
          currentShaded++;
        }
      }
    }

    return DailyShadingSimulationResult(
      overallEfficiencyPercentage: overallEfficiency,
      totalLossPercentage: loss,
      effectiveSunHours: (5.2 * (overallEfficiency / 100.0)),
      hourlyEfficiency: hourlyEff,
      moduleDailySunPercentage: moduleDailyPercentage,
      totalModulesCount: totalModules,
      shadedAtCurrentHourCount: currentShaded,
    );
  }
}
