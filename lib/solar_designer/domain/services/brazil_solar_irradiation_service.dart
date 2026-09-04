import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Dados consolidados de irradiação solar e características da região (CRESESB / Atlas Brasileiro)
class SolarIrradiationData {
  final String uf;
  final String stateName;
  final String region;
  final double averageDailyHsp; // Horas de Sol Pleno (kWh/m²/dia média anual no plano ótimo)
  final double latitude; // Latitude média para ponderação angular
  final String source;

  const SolarIrradiationData({
    required this.uf,
    required this.stateName,
    required this.region,
    required this.averageDailyHsp,
    required this.latitude,
    this.source = 'CRESESB / Atlas Solar',
  });
}

/// Resultado analítico da qualificação solar de um telhado / conjunto de placas
class SolarOrientationEfficiency {
  final double angleFromNorthDegrees; // 0° = Norte exato, 180° = Sul exato
  final double efficiencyFactor; // Ex: 0.98 (98%)
  final int percentage; // Ex: 98
  final Color baseColor; // Cor sólida semântica (Verde, Azul, Âmbar, Vermelho)
  final Color overlayColor; // Cor translúcida para pintar a textura das placas
  final String classification; // 'Excelente (Norte)', 'Boa (Leste/Manhã)', etc.
  final String compassDirection; // 'Norte', 'Nordeste', 'Leste', 'Sul', etc.
  final String description;

  const SolarOrientationEfficiency({
    required this.angleFromNorthDegrees,
    required this.efficiencyFactor,
    required this.percentage,
    required this.baseColor,
    required this.overlayColor,
    required this.classification,
    required this.compassDirection,
    required this.description,
  });
}

/// Serviço de Irradiação Solar do Brasil (CRESESB / CEPEL / Atlas Brasileiro de Energia Solar)
class BrazilSolarIrradiationService {
  // Tabela oficial consolidada dos 27 Estados brasileiros (CRESESB SunData / Atlas Solar INPE)
  static const Map<String, SolarIrradiationData> stateData = {
    'AC': SolarIrradiationData(uf: 'AC', stateName: 'Acre', region: 'Norte', averageDailyHsp: 4.80, latitude: -9.97),
    'AL': SolarIrradiationData(uf: 'AL', stateName: 'Alagoas', region: 'Nordeste', averageDailyHsp: 5.65, latitude: -9.66),
    'AP': SolarIrradiationData(uf: 'AP', stateName: 'Amapá', region: 'Norte', averageDailyHsp: 5.15, latitude: 0.03),
    'AM': SolarIrradiationData(uf: 'AM', stateName: 'Amazonas', region: 'Norte', averageDailyHsp: 4.70, latitude: -3.11),
    'BA': SolarIrradiationData(uf: 'BA', stateName: 'Bahia', region: 'Nordeste', averageDailyHsp: 5.75, latitude: -12.97),
    'CE': SolarIrradiationData(uf: 'CE', stateName: 'Ceará', region: 'Nordeste', averageDailyHsp: 5.85, latitude: -3.73),
    'DF': SolarIrradiationData(uf: 'DF', stateName: 'Distrito Federal', region: 'Centro-Oeste', averageDailyHsp: 5.45, latitude: -15.79),
    'ES': SolarIrradiationData(uf: 'ES', stateName: 'Espírito Santo', region: 'Sudeste', averageDailyHsp: 4.95, latitude: -20.31),
    'GO': SolarIrradiationData(uf: 'GO', stateName: 'Goiás', region: 'Centro-Oeste', averageDailyHsp: 5.40, latitude: -16.68),
    'MA': SolarIrradiationData(uf: 'MA', stateName: 'Maranhão', region: 'Nordeste', averageDailyHsp: 5.45, latitude: -2.53),
    'MT': SolarIrradiationData(uf: 'MT', stateName: 'Mato Grosso', region: 'Centro-Oeste', averageDailyHsp: 5.35, latitude: -15.60),
    'MS': SolarIrradiationData(uf: 'MS', stateName: 'Mato Grosso do Sul', region: 'Centro-Oeste', averageDailyHsp: 5.25, latitude: -20.46),
    'MG': SolarIrradiationData(uf: 'MG', stateName: 'Minas Gerais', region: 'Sudeste', averageDailyHsp: 5.35, latitude: -19.92),
    'PA': SolarIrradiationData(uf: 'PA', stateName: 'Pará', region: 'Norte', averageDailyHsp: 5.20, latitude: -1.45),
    'PB': SolarIrradiationData(uf: 'PB', stateName: 'Paraíba', region: 'Nordeste', averageDailyHsp: 5.75, latitude: -7.11),
    'PR': SolarIrradiationData(uf: 'PR', stateName: 'Paraná', region: 'Sul', averageDailyHsp: 4.55, latitude: -25.42),
    'PE': SolarIrradiationData(uf: 'PE', stateName: 'Pernambuco', region: 'Nordeste', averageDailyHsp: 5.80, latitude: -8.05),
    'PI': SolarIrradiationData(uf: 'PI', stateName: 'Piauí', region: 'Nordeste', averageDailyHsp: 5.80, latitude: -5.09),
    'RJ': SolarIrradiationData(uf: 'RJ', stateName: 'Rio de Janeiro', region: 'Sudeste', averageDailyHsp: 4.90, latitude: -22.90),
    'RN': SolarIrradiationData(uf: 'RN', stateName: 'Rio Grande do Norte', region: 'Nordeste', averageDailyHsp: 5.90, latitude: -5.79),
    'RS': SolarIrradiationData(uf: 'RS', stateName: 'Rio Grande do Sul', region: 'Sul', averageDailyHsp: 4.40, latitude: -30.03),
    'RO': SolarIrradiationData(uf: 'RO', stateName: 'Rondônia', region: 'Norte', averageDailyHsp: 4.85, latitude: -8.76),
    'RR': SolarIrradiationData(uf: 'RR', stateName: 'Roraima', region: 'Norte', averageDailyHsp: 5.10, latitude: 2.82),
    'SC': SolarIrradiationData(uf: 'SC', stateName: 'Santa Catarina', region: 'Sul', averageDailyHsp: 4.35, latitude: -27.59),
    'SP': SolarIrradiationData(uf: 'SP', stateName: 'São Paulo', region: 'Sudeste', averageDailyHsp: 4.80, latitude: -23.55),
    'SE': SolarIrradiationData(uf: 'SE', stateName: 'Sergipe', region: 'Nordeste', averageDailyHsp: 5.55, latitude: -10.94),
    'TO': SolarIrradiationData(uf: 'TO', stateName: 'Tocantins', region: 'Norte', averageDailyHsp: 5.50, latitude: -10.18),
  };

  /// Extrai a UF correspondente a partir de um CEP brasileiro (8 dígitos)
  static String extractUfFromCep(String cep) {
    final cleanCep = cep.replaceAll(RegExp(r'\D'), '');
    if (cleanCep.length < 5) return 'SP'; // Fallback padrão

    final prefix = int.tryParse(cleanCep.substring(0, math.min(5, cleanCep.length))) ?? 0;

    if (prefix >= 1000 && prefix <= 19999) return 'SP';
    if (prefix >= 20000 && prefix <= 28999) return 'RJ';
    if (prefix >= 29000 && prefix <= 29999) return 'ES';
    if (prefix >= 30000 && prefix <= 39999) return 'MG';
    if (prefix >= 40000 && prefix <= 48999) return 'BA';
    if (prefix >= 49000 && prefix <= 49999) return 'SE';
    if (prefix >= 50000 && prefix <= 56999) return 'PE';
    if (prefix >= 57000 && prefix <= 57999) return 'AL';
    if (prefix >= 58000 && prefix <= 58999) return 'PB';
    if (prefix >= 59000 && prefix <= 59999) return 'RN';
    if (prefix >= 60000 && prefix <= 63999) return 'CE';
    if (prefix >= 64000 && prefix <= 64999) return 'PI';
    if (prefix >= 65000 && prefix <= 65999) return 'MA';
    if (prefix >= 66000 && prefix <= 68899) return 'PA';
    if (prefix >= 68900 && prefix <= 68999) return 'AP';
    if (prefix >= 69000 && prefix <= 69299) return 'AM';
    if (prefix >= 69300 && prefix <= 69399) return 'RR';
    if (prefix >= 69400 && prefix <= 69899) return 'AM';
    if (prefix >= 69900 && prefix <= 69999) return 'AC';
    if (prefix >= 70000 && prefix <= 72799) return 'DF';
    if (prefix >= 72800 && prefix <= 72999) return 'GO';
    if (prefix >= 73000 && prefix <= 73699) return 'DF';
    if (prefix >= 73700 && prefix <= 76799) return 'GO';
    if (prefix >= 76800 && prefix <= 76999) return 'RO';
    if (prefix >= 77000 && prefix <= 77999) return 'TO';
    if (prefix >= 78000 && prefix <= 78899) return 'MT';
    if (prefix >= 79000 && prefix <= 79999) return 'MS';
    if (prefix >= 80000 && prefix <= 87999) return 'PR';
    if (prefix >= 88000 && prefix <= 89999) return 'SC';
    if (prefix >= 90000 && prefix <= 99999) return 'RS';

    return 'SP';
  }

  /// Retorna os dados solares do CRESESB a partir de um CEP ou UF
  static SolarIrradiationData getIrradiationData({String? cep, String? uf}) {
    String resolvedUf = uf?.toUpperCase() ?? '';
    if (resolvedUf.isEmpty && cep != null && cep.isNotEmpty) {
      resolvedUf = extractUfFromCep(cep);
    }
    if (!stateData.containsKey(resolvedUf)) {
      resolvedUf = 'SP'; // Padrão Brasil
    }
    return stateData[resolvedUf]!;
  }

  /// Calcula a geração mensal estimada em kWh
  /// Fórmula: Geração = HSP * Potência(kWp) * 30 * PerformanceRatio (0.75) * FatorAngular
  static double calculateMonthlyGenerationKwh({
    required double dailyHsp,
    required double totalKwp,
    double performanceRatio = 0.75,
    double efficiencyFactor = 1.0,
  }) {
    if (dailyHsp <= 0 || totalKwp <= 0) return 0.0;
    return dailyHsp * totalKwp * 30.0 * performanceRatio * efficiencyFactor;
  }

  /// Algoritmo de Qualificação de Orientação Solar
  /// Avalia a queda do telhado em relação ao Norte real e pondera de acordo com a Região/Latitude
  static SolarOrientationEfficiency evaluateOrientation({
    required double roofAzimuthDegrees, // Ângulo para onde a água do telhado cai (0° = Leste do canvas, etc.)
    required double northHeadingDegrees, // Rotação do Norte (0° = Topo do canvas, etc.)
    String? uf,
    String? cep,
  }) {
    final solarData = getIrradiationData(cep: cep, uf: uf);

    // Diferença angular absoluta em relação ao Norte Magnético/Geográfico
    // 0° = Orientado exatamente ao Norte
    // 90° = Leste
    // 180° = Sul
    // 270° = Oeste
    double diff = (roofAzimuthDegrees - northHeadingDegrees) % 360.0;
    if (diff < 0) diff += 360.0;

    // Ângulo de desvio em relação ao Norte (0° a 180°)
    final angleFromNorth = diff > 180.0 ? (360.0 - diff) : diff;

    // Direção da bússola
    final directionName = _resolveCompassPoint(diff);

    // Sensibilidade regional por Latitude:
    // No Norte/Nordeste (baixas latitudes), o sol viaja muito alto e o Sul perde menos (~68-75%).
    // No Sul/Sudeste (latitudes -20° a -30°), o sol de inverno é baixo ao norte e o Sul perde muito (~55-62%).
    final isTropical = solarData.region == 'Norte' || solarData.region == 'Nordeste';

    double factor;
    Color color;
    Color overlayColor;
    String classification;
    String desc;

    if (angleFromNorth <= 25.0) {
      // 🟢 NORTE EXATO (Ápice solar no Hemisfério Sul)
      factor = 1.0;
      color = const Color(0xFF10B981); // Emerald
      overlayColor = const Color(0xFF10B981).withValues(alpha: 0.36);
      classification = 'Excelente (Norte)';
      desc = 'Aproveitamento solar máximo no Brasil. Perfeita para alta produção.';
    } else if (angleFromNorth <= 55.0) {
      // 🟢 NORDESTE / NOROESTE
      factor = isTropical ? 0.98 : 0.95;
      color = const Color(0xFF059669); // Darker emerald
      overlayColor = const Color(0xFF10B981).withValues(alpha: 0.32);
      classification = diff < 180.0 ? 'Ótima (Nordeste)' : 'Ótima (Noroeste)';
      desc = 'Excelente aproveitamento anual com mínimas perdas angulares.';
    } else if (angleFromNorth <= 115.0) {
      // 🔵 LESTE OU OESTE (Sol da manhã ou da tarde)
      factor = isTropical ? 0.88 : 0.82;
      color = const Color(0xFF2563EB); // Royal Blue
      overlayColor = const Color(0xFF3B82F6).withValues(alpha: 0.32);
      final isEast = diff <= 180.0;
      classification = isEast ? 'Boa (Leste • Sol da Manhã)' : 'Boa (Oeste • Sol da Tarde)';
      desc = isEast
          ? 'Pico de geração matutino. Ideal para consumo residencial diurno.'
          : 'Pico de geração vespertino. Excelente para horário de ar-condicionado.';
    } else if (angleFromNorth <= 150.0) {
      // 🟡 SUDESTE OU SUDOESTE
      factor = isTropical ? 0.78 : 0.70;
      color = const Color(0xFFF59E0B); // Amber
      overlayColor = const Color(0xFFF59E0B).withValues(alpha: 0.34);
      classification = diff <= 180.0 ? 'Regular (Sudeste)' : 'Regular (Sudoeste)';
      desc = 'Aproveitamento moderado. Recomendado compensar com mais placas.';
    } else {
      // 🔴 SUL (Desfavorável no Hemisfério Sul)
      factor = isTropical ? 0.68 : 0.58;
      color = const Color(0xFFEF4444); // Red
      overlayColor = const Color(0xFFEF4444).withValues(alpha: 0.36);
      classification = 'Desfavorável (Sul)';
      desc = isTropical
          ? 'Perdas de inverno moderadas devido à baixa latitude da região.'
          : 'Baixo aproveitamento no inverno da Região Sul/Sudeste. Evite se possível.';
    }

    final pct = (factor * 100.0).round();

    return SolarOrientationEfficiency(
      angleFromNorthDegrees: angleFromNorth,
      efficiencyFactor: factor,
      percentage: pct,
      baseColor: color,
      overlayColor: overlayColor,
      classification: classification,
      compassDirection: directionName,
      description: desc,
    );
  }

  static String _resolveCompassPoint(double degrees) {
    if (degrees >= 337.5 || degrees < 22.5) return 'Norte';
    if (degrees >= 22.5 && degrees < 67.5) return 'Nordeste';
    if (degrees >= 67.5 && degrees < 112.5) return 'Leste';
    if (degrees >= 112.5 && degrees < 157.5) return 'Sudeste';
    if (degrees >= 157.5 && degrees < 202.5) return 'Sul';
    if (degrees >= 202.5 && degrees < 247.5) return 'Sudoeste';
    if (degrees >= 247.5 && degrees < 292.5) return 'Oeste';
    return 'Noroeste';
  }

  /// Avalia a orientação diretamente a partir do vetor da seta de queda e da agulha do Norte
  /// [roofArrowDir]: vetor para onde a ponta da seta de queda aponta na tela
  /// [northNeedleDir]: vetor para onde a ponta vermelha do Norte da bússola aponta na tela
  static SolarOrientationEfficiency evaluateOrientationFromVectors({
    required Offset roofArrowDir,
    required Offset northNeedleDir,
    String? uf,
    String? cep,
  }) {
    final solarData = getIrradiationData(cep: cep, uf: uf);

    final lenArrow = roofArrowDir.distance;
    final lenNorth = northNeedleDir.distance;
    if (lenArrow == 0 || lenNorth == 0) {
      return evaluateOrientation(
        roofAzimuthDegrees: 0,
        northHeadingDegrees: 0,
        uf: uf,
        cep: cep,
      );
    }

    final vA = roofArrowDir / lenArrow;
    final vN = northNeedleDir / lenNorth;

    // Produto escalar (dot): 1.0 = apontando exatamente para a mesma direção
    // -1.0 = apontando exatamente na direção oposta
    final dot = (vA.dx * vN.dx + vA.dy * vN.dy).clamp(-1.0, 1.0);

    // Ângulo de desvio em relação ao Norte (0° a 180°)
    final angleFromNorth = math.acos(dot) * 180.0 / math.pi;

    // Vetor Leste relativo ao Norte (90° horário de vN em coordenadas de tela com Y para baixo)
    final vEast = Offset(-vN.dy, vN.dx);
    final dotEast = vA.dx * vEast.dx + vA.dy * vEast.dy;
    final diff = dotEast >= 0 ? angleFromNorth : (360.0 - angleFromNorth);

    final directionName = _resolveCompassPoint(diff);
    final isTropical =
        solarData.region == 'Norte' || solarData.region == 'Nordeste';

    double factor;
    Color color;
    Color overlayColor;
    String classification;
    String desc;

    if (angleFromNorth <= 25.0) {
      factor = 1.0;
      color = const Color(0xFF10B981);
      overlayColor = const Color(0xFF10B981).withValues(alpha: 0.36);
      classification = 'Excelente (Norte)';
      desc =
          'Aproveitamento solar máximo no Brasil. Perfeita para alta produção.';
    } else if (angleFromNorth <= 55.0) {
      factor = isTropical ? 0.98 : 0.95;
      color = const Color(0xFF059669);
      overlayColor = const Color(0xFF10B981).withValues(alpha: 0.32);
      classification = diff < 180.0 ? 'Ótima (Nordeste)' : 'Ótima (Noroeste)';
      desc = 'Excelente aproveitamento anual com mínimas perdas angulares.';
    } else if (angleFromNorth <= 115.0) {
      factor = isTropical ? 0.88 : 0.82;
      color = const Color(0xFF2563EB);
      overlayColor = const Color(0xFF3B82F6).withValues(alpha: 0.32);
      final isEast = diff <= 180.0;
      classification =
          isEast ? 'Boa (Leste • Sol da Manhã)' : 'Boa (Oeste • Sol da Tarde)';
      desc = isEast
          ? 'Pico de geração matutino. Ideal para consumo residencial diurno.'
          : 'Pico de geração vespertino. Excelente para horário de ar-condicionado.';
    } else if (angleFromNorth <= 150.0) {
      factor = isTropical ? 0.78 : 0.70;
      color = const Color(0xFFF59E0B);
      overlayColor = const Color(0xFFF59E0B).withValues(alpha: 0.34);
      classification =
          diff <= 180.0 ? 'Regular (Sudeste)' : 'Regular (Sudoeste)';
      desc = 'Aproveitamento moderado. Recomendado compensar com mais placas.';
    } else {
      factor = isTropical ? 0.68 : 0.58;
      color = const Color(0xFFEF4444);
      overlayColor = const Color(0xFFEF4444).withValues(alpha: 0.36);
      classification = 'Desfavorável (Sul)';
      desc = isTropical
          ? 'Perdas de inverno moderadas devido à baixa latitude da região.'
          : 'Baixo aproveitamento no inverno da Região Sul/Sudeste. Evite se possível.';
    }

    final pct = (factor * 100.0).round();

    return SolarOrientationEfficiency(
      angleFromNorthDegrees: angleFromNorth,
      efficiencyFactor: factor,
      percentage: pct,
      baseColor: color,
      overlayColor: overlayColor,
      classification: classification,
      compassDirection: directionName,
      description: desc,
    );
  }
}
