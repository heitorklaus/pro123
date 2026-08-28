import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'solar_proposal_parser_service.dart';

/// Serviço que integra a API do Google Gemini (Vision & PDF) para análise inteligente de cotações solares
class GeminiSolarVisionService {
  static const _apiKeyStorageKey = 'mavis_gemini_api_key';
  static const defaultApiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

  /// Obtém a chave API do Gemini salva nas preferências ou a padrão fixa
  static Future<String> getSavedApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_apiKeyStorageKey);
    if (saved != null && saved.trim().isNotEmpty) {
      return saved.trim();
    }
    return defaultApiKey;
  }

  /// Salva a chave API do Gemini nas preferências
  static Future<void> saveApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyStorageKey, apiKey.trim());
  }

  /// Remove a chave API personalizada
  static Future<void> clearApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_apiKeyStorageKey);
  }

  /// Analisa um arquivo PDF ou Imagem diretamente na API multimodal do Google Gemini 1.5 Flash
  static Future<ParsedSolarProposal> analyzeSolarProposal({
    required Uint8List fileBytes,
    required String fileExtension,
    String? customApiKey,
  }) async {
    final apiKey = (customApiKey != null && customApiKey.trim().isNotEmpty)
        ? customApiKey.trim()
        : await getSavedApiKey();

    if (apiKey.isEmpty) {
      throw Exception(
        'Chave da API do Google Gemini não configurada.',
      );
    }

    // Define o MIME type do arquivo
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
Você é um especialista em leitura de orçamentos e cotações de Usinas Solares Fotovoltaicas.
Analise visualmente o documento enviado (PDF ou Imagem) de ponta a ponta e extraia todos os dados com máxima exatidão.

Você DEVE identificar obrigatoriamente:
1. TODOS OS PRODUTOS/EQUIPAMENTOS DO KIT: Para cada item da tabela ou lista, extraia o NOME DO PRODUTO completo e a QUANTIDADE com sua UNIDADE (ex: 14 PC, 1 UN, 2 JG, 35 M, 10 PT, etc.). Não omita nenhum item listado no documento.
2. VALOR TOTAL FINAL DO ORÇAMENTO: Localize o valor total consolidado no final do documento (Valor Total, Total Geral, Total da Proposta, Total com Frete). Esse valor é soberano.
3. POTÊNCIA DA USINA (kWp): Potência nominal pico total da usina fotovoltaica em kWp (ex: 25.83 kWp, 8.68 kWp ou a soma da potência dos módulos em Watts dividida por 1000). Preencha no campo "kilowatts".
4. GERAÇÃO MÉDIA ESTIMADA (kWh/mês): Se o documento contiver estimativa de geração mensal em kWh (ex: 3200 kWh/mês), extraia no campo "generationKwh". Se não constar, preencha null.
5. TIPO DE COBERTURA / TELHADO: Cerâmico, Metálico, Fibrocimento, Isotérmico, Solo, Laje ou Sem Estrutura.
6. DISTRIBUIDORA / FABRICANTE: Nome da empresa que emitiu o orçamento (BelEnergy, Edeltec, Fortlev, WEG, Aldo, Sou Energy, Canadian, Elgin, Intelbras, Neosolar, Serrana, etc.).

Retorne ESTRITAMENTE um objeto JSON válido (sem tags markdown e sem texto antes ou depois) com o formato exato:
{
  "proposalNumber": "Número ou código do orçamento/pedido",
  "distributorName": "Nome da distribuidora ou integrador",
  "plantName": "Nome descritivo da usina (ex: Usina Solar 25.83 kWp - Inversor Auxsol + 42x Módulos TCL 615W)",
  "kilowatts": 25.83,
  "generationKwh": 3200.0,
  "roofType": "Cerâmico | Metálico | Fibrocimento | Isotérmico | Solo | Laje | Sem Estrutura",
  "totalAmount": 12062.30,
  "shippingFee": 760.22,
  "items": [
    {
      "name": "Nome e descrição completa do produto/equipamento",
      "sku": "Código ou SKU do produto (se houver)",
      "manufacturer": "Fabricante (ex: TCL, Auxsol, WEG, Deye, Growatt, etc.)",
      "quantity": 14,
      "unit": "PC, JG, M, PT, UN, CX, etc.",
      "componentType": "module | inverter | structure | cable | connector | protection | battery | other",
      "watts": 615
    }
  ]
}

Regras de classificação dos componentes ("componentType"):
- "module": Paineis, placas solares, módulos fotovoltaicos monocristalinos/bifaciais. SEMPRE informe o valor numérico da potência em Watts no campo "watts" (ex: 615, 580, 550, 450, etc.).
- "inverter": Inversores centrais, microinversores, string boxes acopladas.
- "structure": Perfis de alumínio, trilhos, ganchos de fixação, grampos intermediários/finais, emendas/junções.
- "cable": Cabos solares fotovoltaicos (ex: 4mm, 6mm, vermelho, preto).
- "connector": Conectores MC4 macho/fêmea ou derivações.
- "protection": Garras de aterramento, DPS, caixas de proteção, disjuntores.
- "battery": Baterias solares, acumuladores lítio/Lifepo4.
- "other": Demais acessórios e insumos.
''';

    final requestBody = {
      'contents': [
        {
          'parts': [
            {
              'inlineData': {
                'mimeType': mimeType,
                'data': base64File,
              },
            },
            {
              'text': promptText,
            },
          ],
        },
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'temperature': 0.1,
      },
    };

    final candidateModels = [
      'gemini-1.5-flash',
      'gemini-1.5-flash-latest',
      'gemini-2.0-flash',
      'gemini-1.5-pro',
    ];
    http.Response? response;
    String lastError = '';

    for (final model in candidateModels) {
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
      );

      try {
        final res = await http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(requestBody),
        );

        if (res.statusCode == 200) {
          response = res;
          break;
        } else {
          lastError = 'Erro ($model - ${res.statusCode}): ${res.body}';
          try {
            final errJson = jsonDecode(res.body);
            if (errJson['error'] != null && errJson['error']['message'] != null) {
              lastError = errJson['error']['message'];
            }
          } catch (_) {}
        }
      } catch (e) {
        lastError = e.toString();
      }
    }

    if (response == null || response.statusCode != 200) {
      throw Exception('Erro na API do Google Gemini: $lastError');
    }

    final responseJson = jsonDecode(response.body);
    final candidates = responseJson['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('Nenhuma resposta retornada pela IA Gemini.');
    }

    final content = candidates.first['content'];
    final parts = content['parts'] as List?;
    if (parts == null || parts.isEmpty) {
      throw Exception('Resposta da IA Gemini vazia.');
    }

    String rawText = parts.first['text'] as String? ?? '';
    rawText = rawText.trim();
    if (rawText.startsWith('```json')) {
      rawText = rawText.replaceFirst('```json', '').trim();
    }
    if (rawText.startsWith('```')) {
      rawText = rawText.replaceFirst('```', '').trim();
    }
    if (rawText.endsWith('```')) {
      rawText = rawText.substring(0, rawText.length - 3).trim();
    }

    final Map<String, dynamic> parsedJson = jsonDecode(rawText);

    // Converte os itens retornados pela IA
    final List<ParsedSolarItem> parsedItems = [];
    final itemsList = parsedJson['items'] as List?;
    if (itemsList != null) {
      for (final it in itemsList) {
        if (it is Map) {
          final compTypeStr = (it['componentType'] as String? ?? 'other').toLowerCase();
          final itemName = it['name']?.toString() ?? '';
          final lowerName = itemName.toLowerCase();

          SolarComponentType compType = SolarComponentType.other;
          if (compTypeStr == 'module' ||
              lowerName.contains('modulo') ||
              lowerName.contains('módulo') ||
              lowerName.contains('painel') ||
              lowerName.contains('placa') ||
              lowerName.contains('bifacial') ||
              lowerName.contains('cel.')) {
            compType = SolarComponentType.module;
          } else {
            for (final ct in SolarComponentType.values) {
              if (ct.name.toLowerCase() == compTypeStr) {
                compType = ct;
                break;
              }
            }
          }

          final rawWatts = double.tryParse(it['watts']?.toString() ?? '');

          parsedItems.add(ParsedSolarItem(
            name: itemName,
            sku: it['sku']?.toString(),
            manufacturer: it['manufacturer']?.toString(),
            quantity: double.tryParse(it['quantity']?.toString() ?? '1') ?? 1.0,
            unit: it['unit']?.toString().toUpperCase() ?? 'UN',
            unitPrice: 0.0,
            totalPrice: 0.0,
            componentType: compType,
            moduleWatts: rawWatts,
          ));
        }
      }
    }

    final totalAmount = double.tryParse(parsedJson['totalAmount']?.toString() ?? '0') ?? 0.0;
    final shippingFee = double.tryParse(parsedJson['shippingFee']?.toString() ?? '0') ?? 0.0;
    final kilowatts = double.tryParse(parsedJson['kilowatts']?.toString() ?? '0') ?? 0.0;
    final generationKwh = double.tryParse(parsedJson['generationKwh']?.toString() ?? '');

    return ParsedSolarProposal(
      proposalNumber: parsedJson['proposalNumber']?.toString() ?? 'COT-${DateTime.now().millisecondsSinceEpoch}',
      distributorName: parsedJson['distributorName']?.toString() ?? 'Distribuidora Solar',
      plantName: parsedJson['plantName']?.toString() ?? 'Usina Solar ${kilowatts > 0 ? "${kilowatts.toStringAsFixed(2)} kWp" : ""}',
      kilowatts: kilowatts,
      generationKwh: generationKwh,
      roofType: parsedJson['roofType']?.toString() ?? 'Cerâmico',
      productsPrice: totalAmount,
      shippingFee: shippingFee,
      totalAmount: totalAmount,
      items: parsedItems,
      rawText: rawText,
    );
  }
}
