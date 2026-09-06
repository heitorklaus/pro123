import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../products/data/services/gemini_solar_vision_service.dart';

/// Resultado estruturado da análise de foto aérea / drone via IA Google Gemini
class DroneRoofAnalysisResult {
  final String roofType; // Cerâmico, Metálico, Fibrocimento, Laje, etc.
  final double estimatedAreaM2;
  final double estimatedWidthMeters;
  final double estimatedHeightMeters;
  final String recommendedAzimuth;
  final List<String> obstacles;
  final String technicalSummary;

  // ── Atributos Volumétricos e Estéticos 3D (Visão Gemini) ───────────────────
  final double estimatedWallHeightMeters; // Pé-direito da parede (ex: 3.5m, 6.0m)
  final double estimatedPeakHeightMeters; // Altura máxima do bloco mais alto (ex: 6.2m)
  final bool hasPlatibanda; // Se possui moldura de platibanda embutida
  final String wallColorHex; // Cor da parede identificada (ex: '#FFFFFF', '#E2E8F0')
  final bool hasPoolOrGarden; // Se tem piscina ou jardim no entorno

  const DroneRoofAnalysisResult({
    required this.roofType,
    required this.estimatedAreaM2,
    required this.estimatedWidthMeters,
    required this.estimatedHeightMeters,
    required this.recommendedAzimuth,
    required this.obstacles,
    required this.technicalSummary,
    this.estimatedWallHeightMeters = 3.50,
    double? estimatedPeakHeightMeters,
    this.hasPlatibanda = true,
    this.wallColorHex = '#FFFFFF',
    this.hasPoolOrGarden = true,
  }) : estimatedPeakHeightMeters = estimatedPeakHeightMeters ?? estimatedWallHeightMeters;

  factory DroneRoofAnalysisResult.fromJson(Map<String, dynamic> json) {
    final area = double.tryParse(json['estimatedAreaM2']?.toString() ?? '') ?? 50.0;
    final w = double.tryParse(json['estimatedWidthMeters']?.toString() ?? '') ?? 10.0;
    final h = double.tryParse(json['estimatedHeightMeters']?.toString() ?? '') ?? 5.0;
    final wallH = double.tryParse(json['estimatedWallHeightMeters']?.toString() ?? '') ?? 3.50;
    final peakH = double.tryParse(json['estimatedPeakHeightMeters']?.toString() ?? '') ?? wallH;

    final obsList = (json['obstacles'] as List<dynamic>?)
            ?.map((e) => e.toString().trim())
            .where((s) => s.isNotEmpty)
            .toList() ??
        [];

    return DroneRoofAnalysisResult(
      roofType: json['roofType']?.toString() ?? 'Fibrocimento',
      estimatedAreaM2: area,
      estimatedWidthMeters: w,
      estimatedHeightMeters: h,
      recommendedAzimuth: json['recommendedAzimuth']?.toString() ?? 'Norte',
      obstacles: obsList,
      technicalSummary: json['technicalSummary']?.toString() ??
          'Telhado e volumetria identificados e calibrados por IA.',
      estimatedWallHeightMeters: wallH,
      estimatedPeakHeightMeters: peakH,
      hasPlatibanda: json['hasPlatibanda'] as bool? ?? true,
      wallColorHex: json['wallColorHex']?.toString() ?? '#FFFFFF',
      hasPoolOrGarden: json['hasPoolOrGarden'] as bool? ?? true,
    );
  }
}

/// Serviço inteligente de Visão Computacional com IA Gemini para fotos de Drone
class DroneRoofVisionService {
  static const List<String> _preferredModels = [
    'gemini-2.5-flash',
    'gemini-1.5-flash',
    'gemini-flash-latest',
  ];

  /// Analisa a foto aérea de drone diretamente na API do Google Gemini
  static Future<DroneRoofAnalysisResult> analyzeDronePhoto({
    required Uint8List imageBytes,
    String mimeType = 'image/jpeg',
    String? customApiKey,
  }) async {
    final apiKey = (customApiKey != null && customApiKey.trim().isNotEmpty)
        ? customApiKey.trim()
        : await GeminiSolarVisionService.getSavedApiKey();

    if (apiKey.isEmpty) {
      throw Exception('Chave API do Google Gemini não encontrada.');
    }

    final base64Data = base64Encode(imageBytes);

    const prompt = '''
Você é um Engenheiro Fotovoltaico Sênior e Especialista em Fotogrametria com Drones.
Analise visualmente esta fotografia aérea/drone de um telhado residencial ou comercial.

Seu objetivo é extrair com inteligência espacial e volumétrica 3D:
1. "roofType": Tipo de cobertura visível (Cerâmico, Metálico Trapezoidal, Fibrocimento, Laje de Concreto, etc.).
2. "estimatedWidthMeters": Estimativa da largura da água principal do telhado em metros.
3. "estimatedHeightMeters": Estimativa do comprimento de queda em metros.
4. "estimatedAreaM2": Área útil estimada da principal água em m².
5. "recommendedAzimuth": Orientação solar recomendada estimada (ex: Norte, Nordeste, Noroeste, etc.).
6. "obstacles": Lista de obstáculos visíveis no telhado (ex: "3x Coletores Solares Térmicos antigos", "Caixa d'água", "Chaminé").
7. "estimatedWallHeightMeters": Estimativa do pé-direito da parede/beiral inferior em metros (ex: 3.20 a 3.80 para térrea, 6.00 para sobrado).
8. "estimatedPeakHeightMeters": Estimativa da altura máxima da cumeeira ou torre central mais alta da edificação em metros.
9. "hasPlatibanda": true se a casa tiver paredes de platibanda (moldura reta ocultando as telhas) ou false se for telha aparente com beiral.
10. "wallColorHex": Cor predominante das paredes visíveis (ex: "#FFFFFF" branco, "#E2E8F0" cinza claro, "#FDE68A" bege).
11. "hasPoolOrGarden": true se houver jardim, gramado ou piscina visível ao redor da casa.
12. "technicalSummary": Resumo técnico sucinto (1 a 2 frases) sobre as condições da cobertura.

Responda ESTRITAMENTE em formato JSON puro, sem blocos markdown adicionais, no formato:
{
  "roofType": "Fibrocimento com Platibanda",
  "estimatedWidthMeters": 9.5,
  "estimatedHeightMeters": 6.5,
  "estimatedAreaM2": 62.0,
  "recommendedAzimuth": "Norte",
  "obstacles": ["3x Coletores solares térmicos instalados"],
  "estimatedWallHeightMeters": 3.5,
  "estimatedPeakHeightMeters": 5.8,
  "hasPlatibanda": true,
  "wallColorHex": "#FFFFFF",
  "hasPoolOrGarden": true,
  "technicalSummary": "Casa térrea com platibanda branca e torre central elevada com desnível de ~2.3m projetando sombra matinal."
}
''';

    Map<String, String> getHeaders() {
      if (apiKey.startsWith('AQ.')) {
        return {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        };
      }
      return {
        'Content-Type': 'application/json',
        'x-goog-api-key': apiKey,
      };
    }

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt},
            {
              'inline_data': {
                'mime_type': mimeType,
                'data': base64Data,
              }
            }
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.1,
        'response_mime_type': 'application/json',
      }
    });

    String? lastError;

    for (final model in _preferredModels) {
      try {
        final uri = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent',
        );

        final response = await http
            .post(uri, headers: getHeaders(), body: body)
            .timeout(const Duration(seconds: 30));

        if (response.statusCode == 200) {
          final resJson = jsonDecode(response.body) as Map<String, dynamic>;
          final candidates = resJson['candidates'] as List<dynamic>?;
          if (candidates != null && candidates.isNotEmpty) {
            final content = candidates.first['content'] as Map<String, dynamic>?;
            final parts = content?['parts'] as List<dynamic>?;
            if (parts != null && parts.isNotEmpty) {
              final rawText = parts.first['text'] as String? ?? '';
              final cleaned = rawText
                  .replaceAll(RegExp(r'^```json\s*', multiLine: true), '')
                  .replaceAll(RegExp(r'^```\s*$', multiLine: true), '')
                  .trim();

              final parsedMap = jsonDecode(cleaned) as Map<String, dynamic>;
              return DroneRoofAnalysisResult.fromJson(parsedMap);
            }
          }
        } else {
          lastError = 'HTTP ${response.statusCode}: ${response.body}';
        }
      } catch (e) {
        lastError = e.toString();
        debugPrint('[DroneRoofVisionService] Falha com modelo $model: $e');
      }
    }

    throw Exception(
      'Não foi possível analisar a foto de drone com a IA Gemini. Detalhes: $lastError',
    );
  }
}
