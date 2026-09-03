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

  const DroneRoofAnalysisResult({
    required this.roofType,
    required this.estimatedAreaM2,
    required this.estimatedWidthMeters,
    required this.estimatedHeightMeters,
    required this.recommendedAzimuth,
    required this.obstacles,
    required this.technicalSummary,
  });

  factory DroneRoofAnalysisResult.fromJson(Map<String, dynamic> json) {
    final area = double.tryParse(json['estimatedAreaM2']?.toString() ?? '') ?? 50.0;
    final w = double.tryParse(json['estimatedWidthMeters']?.toString() ?? '') ?? 10.0;
    final h = double.tryParse(json['estimatedHeightMeters']?.toString() ?? '') ?? 5.0;

    final obsList = (json['obstacles'] as List<dynamic>?)
            ?.map((e) => e.toString().trim())
            .where((s) => s.isNotEmpty)
            .toList() ??
        [];

    return DroneRoofAnalysisResult(
      roofType: json['roofType']?.toString() ?? 'Cerâmico',
      estimatedAreaM2: area,
      estimatedWidthMeters: w,
      estimatedHeightMeters: h,
      recommendedAzimuth: json['recommendedAzimuth']?.toString() ?? 'Norte',
      obstacles: obsList,
      technicalSummary: json['technicalSummary']?.toString() ??
          'Telhado identificado e calibrado por inteligência artificial.',
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

Seu objetivo é extrair com inteligência espacial:
1. "roofType": Tipo de cobertura visível (Cerâmico, Metálico Trapezoidal, Fibrocimento, Laje de Concreto, etc.).
2. "estimatedWidthMeters": Estimativa da largura da água principal do telhado em metros (use referências arquitetônicas como tamanho padrão de telhas cerâmicas ~22cm, telhas metálicas, largura de portas ~80cm, calçadas ~1.5m, veículos ~4.5m).
3. "estimatedHeightMeters": Estimativa do comprimento de queda (da cumeeira ao beiral) em metros.
4. "estimatedAreaM2": Área útil estimada da principal água ou plano do telhado em m² (Largura x Altura).
5. "recommendedAzimuth": Orientação solar recomendada estimada (ex: Norte, Nordeste, Noroeste, etc.).
6. "obstacles": Lista de obstáculos visíveis no telhado (ex: "Caixa d'água", "Chaminé", "Respiro", "Claraboia", "Sombreamento de árvore").
7. "technicalSummary": Resumo técnico sucinto (1 a 2 frases) sobre as condições da cobertura para instalação de módulos solares fotovoltaicos.

Responda ESTRITAMENTE em formato JSON puro, sem blocos markdown adicionais, no formato:
{
  "roofType": "Cerâmico",
  "estimatedWidthMeters": 11.5,
  "estimatedHeightMeters": 6.0,
  "estimatedAreaM2": 69.0,
  "recommendedAzimuth": "Norte",
  "obstacles": ["Caixa d'água na extremidade oeste", "Respiro próximo à cumeeira"],
  "technicalSummary": "Telhado cerâmico com excelente área livre e orientação favorável."
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
