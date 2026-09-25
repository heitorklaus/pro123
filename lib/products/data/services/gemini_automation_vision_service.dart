import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/automation_study_model.dart';

/// Item extraído pela Inteligência Artificial
class ParsedAutomationItem {
  final String name;
  final String category;
  final int quantity;
  final String unit;
  final double unitPrice;
  final double totalPrice;
  final String? sku;
  final String? manufacturer;
  final String? notes;

  const ParsedAutomationItem({
    required this.name,
    required this.category,
    this.quantity = 1,
    this.unit = 'UN',
    this.unitPrice = 0.0,
    this.totalPrice = 0.0,
    this.sku,
    this.manufacturer,
    this.notes,
  });

  AutomationItem toAutomationItem() {
    return AutomationItem(
      id: UniqueKey().toString(),
      name: name,
      category: AutomationItemCategory.fromString(category),
      quantity: quantity,
      unit: unit,
      unitPrice: unitPrice,
      totalPrice: totalPrice > 0 ? totalPrice : (quantity * unitPrice),
      sku: sku,
      manufacturer: manufacturer,
      notes: notes,
    );
  }
}

/// Ambiente extraído pela Inteligência Artificial
class ParsedAutomationEnvironment {
  final String name;
  final List<ParsedAutomationItem> items;
  final String? notes;
  final String? description;

  const ParsedAutomationEnvironment({
    required this.name,
    this.items = const [],
    this.notes,
    this.description,
  });

  AutomationEnvironment toAutomationEnvironment() {
    return AutomationEnvironment(
      id: UniqueKey().toString(),
      name: name,
      items: items.map((i) => i.toAutomationItem()).toList(),
      notes: notes,
      description: description,
    );
  }
}

/// Estudo completo extraído pela Inteligência Artificial
class ParsedAutomationStudy {
  final String studyName;
  final String? clientName;
  final String? distributorOrIntegrator;
  final String? notes;
  final List<ParsedAutomationEnvironment> environments;
  final double totalAmount;
  final double laborAmount;

  const ParsedAutomationStudy({
    required this.studyName,
    this.clientName,
    this.distributorOrIntegrator,
    this.notes,
    this.environments = const [],
    this.totalAmount = 0.0,
    this.laborAmount = 0.0,
  });
}

/// Serviço de Inteligência Artificial Google Gemini para leitura de Memoriais, Orçamentos e Projetos de Automação
class GeminiAutomationVisionService {
  static const _apiKeyStorageKey = 'mavis_gemini_api_key';
  static String get defaultApiKey =>
      utf8.decode(base64.decode('QVEuQWI4Uk42SVFkZ3pDTndjUDdFYk9kV2R1QVFZR2lBSlNadEZJU201MVd1dXBUZ1pEbnc='));

  static Future<String> getSavedApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_apiKeyStorageKey);
    if (saved != null && saved.trim().isNotEmpty) {
      return saved.trim();
    }
    return defaultApiKey;
  }

  /// Analisa um arquivo PDF ou Imagem diretamente na API multimodal do Google Gemini Flash
  static Future<ParsedAutomationStudy> analyzeAutomationProject({
    required Uint8List fileBytes,
    required String fileExtension,
    String? customApiKey,
  }) async {
    final apiKey = (customApiKey != null && customApiKey.trim().isNotEmpty)
        ? customApiKey.trim()
        : await getSavedApiKey();

    if (apiKey.isEmpty) {
      throw Exception('Chave da API do Google Gemini não configurada.');
    }

    String mimeType = 'application/pdf';
    final ext = fileExtension.toLowerCase().replaceAll('.', '');
    if (ext == 'png') {
      mimeType = 'image/png';
    } else if (ext == 'jpg' || ext == 'jpeg') {
      mimeType = 'image/jpeg';
    } else if (ext == 'webp') {
      mimeType = 'image/webp';
    } else if (ext == 'pdf') {
      mimeType = 'application/pdf';
    }

    final base64File = base64Encode(fileBytes);

    const promptText = '''
Você é um Engenheiro e Especialista Sênior em Automação Residencial e Predial (Smart Home & Audio/Video).
Analise visualmente o documento enviado (PDF, Imagem ou Cotação de Distribuidor) de ponta a ponta.

Sua missão é extrair e estruturar o projeto por AMBIENTES (Cômodos / Zonas) e seus respectivos EQUIPAMENTOS E SOLUÇÕES.

Regras de Extração:
1. NOME DO ESTUDO / PROJETO: Identifique o nome do cliente, condomínio, obra ou título do projeto (ex: "Projeto Automação Residência Alphaville", "Apartamento Jardins - Smart Home", etc.).
2. LISTA DE AMBIENTES: Identifique cada cômodo mencionado explicitamente no documento (ex: "Sala de Estar & Jantar", "Home Theater / TV", "Suíte Master", "Varanda Gourmet", "Cozinha", "Hall de Entrada", "Jardim / Piscina", "Área de Serviço"). Se o orçamento for geral por itens e não separar por ambiente, crie um ambiente padrão "Ambiente Geral / Central" ou agrupe logicamente.
3. EQUIPAMENTOS DE CADA AMBIENTE: Para cada ambiente, extraia todos os equipamentos e soluções previstos:
   - Nome completo e modelo do equipamento
   - Categoria: "Iluminação", "Persianas", "Áudio & Vídeo", "Climatização", "Rede", "Segurança", "Sensores", ou "Outros"
   - Quantidade e unidade (UN, PC, M, etc.)
   - Preço Unitário e Preço Total (se constar no documento, caso não conste preencha 0.0)
   - Fabricante / Marca (ex: Control4, Savant, Sonoff, Tuya, Intelbras, Somfy, Yamaha, Denon, JBL, etc.)
4. VALORES CONSOLIDADOS: Valor total dos equipamentos e valor de serviços/instalação/programação (se informado).

Retorne ESTRITAMENTE um objeto JSON válido (sem tags markdown, sem ```json e sem texto antes ou depois) no seguinte formato:
{
  "studyName": "Nome do Estudo ou Projeto",
  "clientName": "Nome do Cliente (se houver)",
  "distributorOrIntegrator": "Empresa emissora ou fornecedor",
  "notes": "Observações gerais sobre o escopo técnico",
  "totalAmount": 28500.00,
  "laborAmount": 4500.00,
  "environments": [
    {
      "name": "Sala de Estar",
      "notes": "Automação de 4 circuitos de iluminação e 2 persianas",
      "items": [
        {
          "name": "Módulo Dimmer 4 Canais Zigbee",
          "category": "Iluminação",
          "quantity": 1,
          "unit": "UN",
          "unitPrice": 450.00,
          "totalPrice": 450.00,
          "manufacturer": "Tuya / NovaDigital",
          "sku": "DIM-4CH-ZGB"
        },
        {
          "name": "Motor Tubular de Persiana 20Nm",
          "category": "Persianas",
          "quantity": 2,
          "unit": "UN",
          "unitPrice": 850.00,
          "totalPrice": 1700.00,
          "manufacturer": "Somfy"
        }
      ]
    }
  ]
}
''';

    final models = [
      'gemini-3.6-flash',
      'gemini-3.5-flash',
      'gemini-flash-latest',
      'gemini-1.5-flash',
    ];

    String? lastError;

    for (final model in models) {
      try {
        final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
        );

        final body = jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': promptText},
                {
                  'inline_data': {
                    'mime_type': mimeType,
                    'data': base64File,
                  }
                }
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.1,
            'maxOutputTokens': 8192,
            'responseMimeType': 'application/json',
          }
        });

        final headers = {
          'Content-Type': 'application/json',
          'x-goog-api-key': apiKey,
        };

        final response = await http.post(url, headers: headers, body: body);

        if (response.statusCode == 200) {
          final resJson = jsonDecode(response.body);
          final candidates = resJson['candidates'] as List?;
          if (candidates == null || candidates.isEmpty) {
            throw Exception('O Gemini não retornou nenhuma resposta.');
          }

          final textResponse =
              candidates.first['content']['parts'][0]['text'] as String;

          return _parseAutomationJsonResponse(textResponse);
        } else {
          lastError = 'Status ${response.statusCode}: ${response.body}';
          debugPrint('[GeminiAutomationVision] Falha com modelo $model: $lastError');
        }
      } catch (e) {
        lastError = e.toString();
        debugPrint('[GeminiAutomationVision] Exceção com modelo $model: $e');
      }
    }

    throw Exception('Falha ao analisar projeto de automação com IA: $lastError');
  }

  static ParsedAutomationStudy _parseAutomationJsonResponse(String rawText) {
    var cleanJson = rawText.trim();
    if (cleanJson.startsWith('```json')) {
      cleanJson = cleanJson.substring(7);
    } else if (cleanJson.startsWith('```')) {
      cleanJson = cleanJson.substring(3);
    }
    if (cleanJson.endsWith('```')) {
      cleanJson = cleanJson.substring(0, cleanJson.length - 3);
    }
    cleanJson = cleanJson.trim();

    final map = jsonDecode(cleanJson) as Map<String, dynamic>;

    final studyName = map['studyName']?.toString().trim() ?? 'Estudo de Automação';
    final clientName = map['clientName']?.toString().trim();
    final distributor = map['distributorOrIntegrator']?.toString().trim();
    final notes = map['notes']?.toString().trim();
    final totalAmount = (map['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final laborAmount = (map['laborAmount'] as num?)?.toDouble() ?? 0.0;

    final parsedEnvs = <ParsedAutomationEnvironment>[];
    final envsRaw = map['environments'];
    if (envsRaw is List) {
      for (final envMap in envsRaw) {
        if (envMap is Map) {
          final envName = envMap['name']?.toString().trim() ?? 'Ambiente';
          final envNotes = envMap['notes']?.toString().trim();
          final parsedItems = <ParsedAutomationItem>[];

          final itemsRaw = envMap['items'];
          if (itemsRaw is List) {
            for (final itemMap in itemsRaw) {
              if (itemMap is Map) {
                final itemName = itemMap['name']?.toString().trim() ?? 'Equipamento';
                final cat = itemMap['category']?.toString().trim() ?? 'Outros';
                final qty = (itemMap['quantity'] as num?)?.toInt() ?? 1;
                final unit = itemMap['unit']?.toString().trim() ?? 'UN';
                final unitPrice = (itemMap['unitPrice'] as num?)?.toDouble() ?? 0.0;
                final totalPrice = (itemMap['totalPrice'] as num?)?.toDouble() ?? (qty * unitPrice);
                final sku = itemMap['sku']?.toString().trim();
                final mfg = itemMap['manufacturer']?.toString().trim();

                parsedItems.add(ParsedAutomationItem(
                  name: itemName,
                  category: cat,
                  quantity: qty,
                  unit: unit,
                  unitPrice: unitPrice,
                  totalPrice: totalPrice,
                  sku: sku,
                  manufacturer: mfg,
                ));
              }
            }
          }

          parsedEnvs.add(ParsedAutomationEnvironment(
            name: envName,
            notes: envNotes,
            description: envMap['description']?.toString() ?? envMap['miniexplanation']?.toString(),
            items: parsedItems,
          ));
        }
      }
    }

    return ParsedAutomationStudy(
      studyName: studyName,
      clientName: clientName,
      distributorOrIntegrator: distributor,
      notes: notes,
      environments: parsedEnvs,
      totalAmount: totalAmount,
      laborAmount: laborAmount,
    );
  }
}
