import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../../../products/data/services/gemini_solar_vision_service.dart';
import '../../domain/models/parsed_energy_bill.dart';

/// Serviço de Visão Computacional com IA Google Gemini especializado em Contas de Energia Brasileiras
class GeminiEnergyBillService {
  /// Analisa um arquivo PDF ou Imagem de conta de energia
  static Future<ParsedEnergyBill> analyzeEnergyBill({
    required Uint8List fileBytes,
    required String fileExtension,
    String? customApiKey,
  }) async {
    final apiKey = (customApiKey != null && customApiKey.trim().isNotEmpty)
        ? customApiKey.trim()
        : await GeminiSolarVisionService.getSavedApiKey();

    if (apiKey.isEmpty) {
      throw Exception('Chave da API do Google Gemini não configurada.');
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
Você é um especialista em análise de contas e faturas de energia elétrica brasileiras (DANF3E, Energisa, Enel, CPFL, Cemig, Copel, Equatorial, Neoenergia, Light, Celesc, etc.).
Analise visualmente e detalhadamente o documento enviado (PDF ou Imagem) e extraia todos os dados cadastrais, endereço, unidade consumidora e histórico de consumo de energia com máxima precisão.

Você DEVE extrair e identificar:
1. DADOS DO CLIENTE / TITULAR:
   - "clientName": Nome Completo ou Razão Social do Pagador / Titular da Conta (ex: CUIABA FORMAS LTDA, JOÃO DA SILVA).
   - "document": CPF ou CNPJ formatado (ex: 31.965.255/0001-12 ou 000.000.000-00). Procure no campo Pagador, Ficha de Compensação ou Cabeçalho.
   - "clientType": "company" se for PJ/CNPJ, ou "person" se for PF/CPF.
   - "email": E-mail se houver, ou null.
   - "phone": Telefone / WhatsApp se houver, ou null.

2. ENDEREÇO DA UNIDADE CONSUMIDORA (LOCAL DE ENTREGA):
   - "street": Nome da Rua, Avenida, Rodovia, Alameda (ex: RUA DAS PEROLAS).
   - "addressNumber": Número do imóvel (ex: 214, S/N, KM 10).
   - "complement": Complemento, Sala, Apto, Lote, Quadra se houver.
   - "neighborhood": Bairro (ex: BOSQUE DA SAUDE).
   - "city": Cidade / Município (ex: Cuiabá).
   - "state": Sigla do Estado / UF com 2 letras (ex: MT, SP, MG, GO, PR, RJ, etc.).
   - "zipCode": CEP de 8 dígitos com máscara (ex: 78050-090).

3. DADOS DA UNIDADE CONSUMIDORA & DISTRIBUIDORA:
   - "utilityCompany": Nome da distribuidora (ex: ENERGISA MATO GROSSO, CPFL PAULISTA, ENEL, CEMIG, COPEL, EQUATORIAL).
   - "ucNumber": Código da Unidade Consumidora / Número da UC / Instalação / Matrícula (ex: 833.185.017-11 ou 0005093531-1).
   - "connectionType": Tipo de Ligação: "Monofásico", "Bifásico" ou "Trifásico" (ex: Trifásico).
   - "tariffGroup": Classificação / Grupo tarifário (ex: B1 Residencial, B3 Comercial, A4, etc.).
   - "currentBillAmount": Valor total a pagar da fatura atual em reais (ex: 156.54).
   - "referenceMonth": Mês/Ano de referência da fatura (ex: Junho / 2026).
   - "currentMonthKwh": Consumo em kWh do mês atual faturado (ex: 439.0).

4. HISTÓRICO DE CONSUMO DOS ÚLTIMOS MESES (TABELA / GRÁFICO):
   - "history": Lista dos meses com histórico de consumo em kWh (geralmente tabela de 12 a 13 meses: JUN/26, MAI/26, ABR/26, MAR/26, FEV/26, JAN/26, DEZ/25, NOV/25, OUT/25, etc.).
   - Para cada mês do histórico:
     {
       "month": "Mês/Ano (ex: JUN/26)",
       "consumptionKwh": 439.0,
       "billingDays": 30
     }

5. MÉDIA E DIMENSIONAMENTO SOLAR:
   - "averageMonthlyConsumptionKwh": Média aritmética simples de consumo mensal em kWh calculada a partir dos meses faturados do histórico.
   - "suggestedSolarKwP": Potência fotovoltaica recomendada em kWp para suprir 100% desse consumo (Fórmula: Consumo Médio em kWh / 110.0).
   - "estimatedMonthlyGenerationKwh": Geração fotovoltaica mensal estimada em kWh (suggestedSolarKwP * 110.0).

Retorne ESTRITAMENTE um objeto JSON válido (sem tags markdown de código e sem texto antes ou depois) com o formato exato:
{
  "clientName": "CUIABA FORMAS LTDA",
  "document": "31.965.255/0001-12",
  "clientType": "company",
  "email": null,
  "phone": null,
  "street": "RUA DAS PEROLAS",
  "addressNumber": "214",
  "complement": null,
  "neighborhood": "BOSQUE DA SAUDE",
  "city": "Cuiabá",
  "state": "MT",
  "zipCode": "78050-090",
  "utilityCompany": "ENERGISA MATO GROSSO",
  "ucNumber": "833.185.017-11",
  "connectionType": "Trifásico",
  "tariffGroup": "B1 Residencial",
  "currentBillAmount": 156.54,
  "referenceMonth": "Junho / 2026",
  "currentMonthKwh": 439.0,
  "averageMonthlyConsumptionKwh": 600.0,
  "suggestedSolarKwP": 5.45,
  "estimatedMonthlyGenerationKwh": 600.0,
  "history": [
    {"month": "JUN/26", "consumptionKwh": 439.0, "billingDays": 30},
    {"month": "MAI/26", "consumptionKwh": 806.0, "billingDays": 30},
    {"month": "ABR/26", "consumptionKwh": 1063.0, "billingDays": 31},
    {"month": "MAR/26", "consumptionKwh": 337.0, "billingDays": 30},
    {"month": "FEV/26", "consumptionKwh": 493.0, "billingDays": 29},
    {"month": "JAN/26", "consumptionKwh": 487.0, "billingDays": 33},
    {"month": "DEZ/25", "consumptionKwh": 454.0, "billingDays": 29},
    {"month": "NOV/25", "consumptionKwh": 668.0, "billingDays": 30},
    {"month": "OUT/25", "consumptionKwh": 650.0, "billingDays": 34}
  ]
}
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
      'gemini-3.6-flash',
      'gemini-3.5-flash',
      'gemini-flash-latest',
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
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': apiKey,
          },
          body: jsonEncode(requestBody),
        );

        if (res.statusCode == 200) {
          response = res;
          break;
        } else {
          lastError = 'Erro ($model - ${res.statusCode}): ${res.body}';
        }
      } catch (e) {
        lastError = 'Exceção de rede ($model): $e';
      }
    }

    if (response == null || response.statusCode != 200) {
      throw Exception(
        'Não foi possível analisar a conta de energia com a IA Gemini.\nDetalhes: $lastError',
      );
    }

    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = data['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) {
        throw Exception('A IA não retornou conteúdo para esta conta de energia.');
      }

      final firstCandidate = candidates[0] as Map<String, dynamic>;
      final content = firstCandidate['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List<dynamic>?;
      if (parts == null || parts.isEmpty) {
        throw Exception('Resposta vazia da IA Gemini.');
      }

      String rawText = parts[0]['text'] as String? ?? '';
      rawText = rawText.trim();
      if (rawText.startsWith('```json')) {
        rawText = rawText.substring(7);
      } else if (rawText.startsWith('```')) {
        rawText = rawText.substring(3);
      }
      if (rawText.endsWith('```')) {
        rawText = rawText.substring(0, rawText.length - 3);
      }
      rawText = rawText.trim();

      final parsedJson = jsonDecode(rawText) as Map<String, dynamic>;
      return ParsedEnergyBill.fromJson(parsedJson);
    } catch (e) {
      throw Exception('Falha ao interpretar dados estruturados da conta de energia: $e');
    }
  }
}
