import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../../../products/data/services/gemini_solar_vision_service.dart';
import '../../domain/models/solar_credit_models.dart';

/// Resultado estruturado da explosão de uma conta de energia GD1/GD2 pela IA
class ExplodedGdEnergyBill {
  final String utilityCompany;
  final String ucNumber;
  final String accountHolderName;
  final String accountHolderDocument;
  final String addressStreet;
  final String addressNeighborhood;
  final String addressCity;
  final String addressState;
  final String addressZipCode;
  final String connectionType;
  final String referenceMonth;
  final String dueDate;
  final String? readingPreviousDate;
  final String? readingCurrentDate;
  final int billingDays;

  final double consumptionKwh;
  final double consumptionUnitTariff;
  final double consumptionValueRs;

  final List<InjectedEnergyLineItem> injectedLines;
  final double injectedGdiKwh;
  final double injectedGdiValueRs;
  final double injectedGdiiKwh;
  final double injectedGdiiValueRs;
  final double totalInjectedKwh;
  final double totalInjectedGrossValueRs;

  final double gdAdjustmentKwh;
  final double gdAdjustmentTariff;
  final double gdAdjustmentValueRs;

  final double publicLightingValueRs;
  final double finesAndInterestValueRs;
  final double otherChargesValueRs;
  final double utilityBillTotalToPayRs;

  final double accumulatedBalanceKwh;
  final double expiringNextCycleKwh;
  final String ucGdClassification;
  final List<MonthlyConsumptionHistoryItem> consumptionHistory;

  const ExplodedGdEnergyBill({
    required this.utilityCompany,
    required this.ucNumber,
    required this.accountHolderName,
    this.accountHolderDocument = '',
    required this.addressStreet,
    this.addressNeighborhood = '',
    this.addressCity = 'Cuiabá',
    this.addressState = 'MT',
    this.addressZipCode = '',
    this.connectionType = 'Trifásico',
    required this.referenceMonth,
    required this.dueDate,
    this.readingPreviousDate,
    this.readingCurrentDate,
    this.billingDays = 30,
    required this.consumptionKwh,
    this.consumptionUnitTariff = 0.0,
    required this.consumptionValueRs,
    required this.injectedLines,
    required this.injectedGdiKwh,
    required this.injectedGdiValueRs,
    required this.injectedGdiiKwh,
    required this.injectedGdiiValueRs,
    required this.totalInjectedKwh,
    required this.totalInjectedGrossValueRs,
    required this.gdAdjustmentKwh,
    this.gdAdjustmentTariff = 0.0,
    required this.gdAdjustmentValueRs,
    this.publicLightingValueRs = 0.0,
    this.finesAndInterestValueRs = 0.0,
    this.otherChargesValueRs = 0.0,
    required this.utilityBillTotalToPayRs,
    required this.accumulatedBalanceKwh,
    this.expiringNextCycleKwh = 0.0,
    this.ucGdClassification = '',
    this.consumptionHistory = const [],
  });

  factory ExplodedGdEnergyBill.fromJson(Map<String, dynamic> map) {
    final rawLines = map['injectedLines'] as List<dynamic>? ?? [];
    final lines = rawLines
        .whereType<Map>()
        .map((e) => InjectedEnergyLineItem.fromMap(Map<String, dynamic>.from(e)))
        .where(
          (l) =>
              !l.description.toLowerCase().contains('ajuste') &&
              !l.description.toLowerCase().contains('trf reduzida'),
        )
        .toList();

    double gdiKwh = 0.0;
    double gdiRs = 0.0;
    double gdiiKwh = 0.0;
    double gdiiRs = 0.0;

    for (final line in lines) {
      if (line.isGdi) {
        gdiKwh += line.quantityKwh;
        gdiRs += line.totalValueRs;
      } else {
        gdiiKwh += line.quantityKwh;
        gdiiRs += line.totalValueRs;
      }
    }

    if (lines.isEmpty) {
      gdiKwh = ((map['injectedGdiKwh'] as num?)?.toDouble() ?? 0.0).abs();
      gdiRs = ((map['injectedGdiValueRs'] as num?)?.toDouble() ?? 0.0).abs();
      gdiiKwh = ((map['injectedGdiiKwh'] as num?)?.toDouble() ?? 0.0).abs();
      gdiiRs = ((map['injectedGdiiValueRs'] as num?)?.toDouble() ?? 0.0).abs();
    }

    final totInjKwh = lines.isNotEmpty
        ? (gdiKwh + gdiiKwh)
        : (((map['totalInjectedKwh'] as num?)?.toDouble() ?? (gdiKwh + gdiiKwh))
            .abs());
    final totInjRs = lines.isNotEmpty
        ? (gdiRs + gdiiRs)
        : (((map['totalInjectedGrossValueRs'] as num?)?.toDouble() ??
                (gdiRs + gdiiRs))
            .abs());

    final rawHist = map['consumptionHistory'] as List<dynamic>? ?? [];
    final history = rawHist
        .whereType<Map>()
        .map((e) =>
            MonthlyConsumptionHistoryItem.fromMap(Map<String, dynamic>.from(e)))
        .toList();

    return ExplodedGdEnergyBill(
      utilityCompany:
          (map['utilityCompany'] as String? ?? 'ENERGISA').trim(),
      ucNumber: (map['ucNumber'] as String? ?? '').trim(),
      accountHolderName: (map['accountHolderName'] as String? ?? '').trim(),
      accountHolderDocument:
          (map['accountHolderDocument'] as String? ?? '').trim(),
      addressStreet: (map['addressStreet'] as String? ?? '').trim(),
      addressNeighborhood:
          (map['addressNeighborhood'] as String? ?? '').trim(),
      addressCity: (map['addressCity'] as String? ?? 'Cuiabá').trim(),
      addressState: (map['addressState'] as String? ?? 'MT').trim(),
      addressZipCode: (map['addressZipCode'] as String? ?? '').trim(),
      connectionType: (map['connectionType'] as String? ?? 'Trifásico').trim(),
      referenceMonth: (map['referenceMonth'] as String? ?? '').trim(),
      dueDate: (map['dueDate'] as String? ?? '').trim(),
      readingPreviousDate: map['readingPreviousDate'] as String?,
      readingCurrentDate: map['readingCurrentDate'] as String?,
      billingDays: (map['billingDays'] as num?)?.toInt() ?? 30,
      consumptionKwh:
          ((map['consumptionKwh'] as num?)?.toDouble() ?? 0.0).abs(),
      consumptionUnitTariff:
          ((map['consumptionUnitTariff'] as num?)?.toDouble() ?? 0.0).abs(),
      consumptionValueRs:
          ((map['consumptionValueRs'] as num?)?.toDouble() ?? 0.0).abs(),
      injectedLines: lines,
      injectedGdiKwh: gdiKwh,
      injectedGdiValueRs: gdiRs,
      injectedGdiiKwh: gdiiKwh,
      injectedGdiiValueRs: gdiiRs,
      totalInjectedKwh: totInjKwh,
      totalInjectedGrossValueRs: totInjRs,
      gdAdjustmentKwh:
          ((map['gdAdjustmentKwh'] as num?)?.toDouble() ?? 0.0).abs(),
      gdAdjustmentTariff:
          ((map['gdAdjustmentTariff'] as num?)?.toDouble() ?? 0.0).abs(),
      gdAdjustmentValueRs:
          ((map['gdAdjustmentValueRs'] as num?)?.toDouble() ?? 0.0).abs(),
      publicLightingValueRs:
          ((map['publicLightingValueRs'] as num?)?.toDouble() ?? 0.0).abs(),
      finesAndInterestValueRs:
          ((map['finesAndInterestValueRs'] as num?)?.toDouble() ?? 0.0).abs(),
      otherChargesValueRs:
          ((map['otherChargesValueRs'] as num?)?.toDouble() ?? 0.0).abs(),
      utilityBillTotalToPayRs:
          ((map['utilityBillTotalToPayRs'] as num?)?.toDouble() ?? 0.0).abs(),
      accumulatedBalanceKwh:
          ((map['accumulatedBalanceKwh'] as num?)?.toDouble() ?? 0.0).abs(),
      expiringNextCycleKwh:
          ((map['expiringNextCycleKwh'] as num?)?.toDouble() ?? 0.0).abs(),
      ucGdClassification: (map['ucGdClassification'] as String? ?? '').trim(),
      consumptionHistory: history,
    );
  }
}

/// Serviço IA Google Gemini especializado em Explodir Faturas de Energia com Geração Distribuída (GDI / GDII / Energisa)
class GeminiGdBillExplosionService {
  static Future<ExplodedGdEnergyBill> explodeEnergyBill({
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

    const promptText = r'''
Você é um engenheiro especialista em faturamento de Geração Distribuída (GD I e GD II - Lei 14.300/22) em contas de energia elétrica brasileiras (especialmente DANF3E da ENERGISA e demais concessionárias).
Analise visualmente TODAS AS PÁGINAS do documento (PDF ou Imagem) e faça a EXPLOSÃO COMPLETA dos dados com precisão cirúrgica de centavos e kWh.

Extraia os seguintes blocos:

1. IDENTIFICAÇÃO E CABEÇALHO (Página 1):
   - "utilityCompany": Nome da concessionária (ex: "ENERGISA MATO GROSSO").
   - "ucNumber": Número da UC exatamente como impresso (ex: "2.024.081.017-07").
   - "accountHolderName": Nome do Titular da conta impresso na fatura (ex: "HEITOR FABRICIO KLAUS DE OLIVEIRA").
   - "accountHolderDocument": CPF ou CNPJ impresso na conta (ex: "01X.XXX.XX1-01").
   - "addressStreet": Rua e Número da Unidade Consumidora (ex: "RUA ALFENAS, 120" - limpe códigos de roteiro como 0050717500500 se quiser ou mantenha Rua e Número claros).
   - "addressNeighborhood": Bairro (ex: "JARDIM MARIANA").
   - "addressCity": Cidade (ex: "Cuiabá").
   - "addressState": UF (ex: "MT").
   - "addressZipCode": CEP (ex: "78040-600").
   - "connectionType": Tipo de ligação ("Trifásico", "Bifásico" ou "Monofásico").
   - "referenceMonth": Mês/Ano de referência (ex: "Outubro / 2026").
   - "dueDate": Data de vencimento (ex: "03/11/2026").
   - "readingPreviousDate": Data da leitura anterior (ex: "18/09/2026").
   - "readingCurrentDate": Data da leitura atual (ex: "20/10/2026").
   - "billingDays": Número de dias de faturamento (ex: 32).
   - "utilityBillTotalToPayRs": Valor TOTAL A PAGAR da fatura para a concessionária em R$ (ex: 262.26).

2. CONSUMO DO MÊS (Tabela Itens da Fatura):
   - "consumptionKwh": Quantidade de Consumo em kWh (ex: 1472.00).
   - "consumptionUnitTariff": Preço unitário (R$) com tributos da linha de Consumo (ex: 1.194080).
   - "consumptionValueRs": Valor total em R$ da linha de Consumo (ex: 1757.70).

3. LINHAS DE ENERGIA ATIVA INJETADA (GDI e GDII):
   - Na tabela "Itens da Fatura", procure TODAS as linhas que começam com "Energia Atv Injetada" (ou "Energia Injetada").
   - Podem existir várias linhas (ex: "Energia Atv Injetada GDI oUC 10/2026 mPT", "Energia Atv Injetada GDII oUC 10/2026 mPT", "Energia Atv Injetada GDI mUC 10/2025 mPT", "Energia Atv Injetada GDII mUC 10/2025 mPT", etc.).
   - Liste CADA linha individualmente no array "injectedLines" com valores positivos:
     * "description": Descrição completa da linha
     * "regime": "GDI" se for GD I (tiver GDI ou GD1), ou "GDII" se for GD II (tiver GDII ou GD2)
     * "originType": "oUC" (outra UC) ou "mUC" (mesma UC)
     * "referencePeriod": Mês/ano daquela linha (ex: "10/2026", "10/2025", "11/2025")
     * "quantityKwh": Quantidade em kWh da linha (positivo, ex: 214.00, 492.00)
     * "unitPriceWithTaxes": Preço unit (R$) com tributos (ex: 1.194080)
     * "totalValueRs": Valor absoluto em R$ da linha (positivo, ex: 255.53, 587.49)
   - Some também:
     * "injectedGdiKwh": Soma em kWh das linhas GDI
     * "injectedGdiValueRs": Soma em R$ das linhas GDI (positivo)
     * "injectedGdiiKwh": Soma em kWh das linhas GDII
     * "injectedGdiiValueRs": Soma em R$ das linhas GDII (positivo)
     * "totalInjectedKwh": Soma total em kWh de todas as linhas de Energia Injetada
     * "totalInjectedGrossValueRs": Soma total em R$ (positivo) de todas as linhas de Energia Injetada

4. AJUSTE GD / FIO B (Lei 14.300/22):
   - Procure a linha "Ajuste GDII - TRF Reduzida(Lei 14.300/22)" (ou "Ajuste GD" / "Fio B"):
     * "gdAdjustmentKwh": Quantidade em kWh da linha de Ajuste GD (ex: 1026.00). Se não houver, 0.0.
     * "gdAdjustmentTariff": Preço unitário com tributos do Ajuste GD (ex: 0.189080). Se não houver, 0.0.
     * "gdAdjustmentValueRs": Valor em R$ cobrado no Ajuste GD (ex: 194.00). Se não houver, 0.0.

5. LANÇAMENTOS E SERVIÇOS (Outros Encargos da Fatura):
   - "publicLightingValueRs": Valor de Contrib de Ilum Pub / CIP / COSIP em R$ (ex: 64.30).
   - "finesAndInterestValueRs": Soma de MULTA + JUROS DE MORA + Atualização Monetária em R$ (ex: 3.53 + 0.41 = 3.94).
   - "otherChargesValueRs": Soma de quaisquer outros serviços ou taxas extras cobradas na fatura em R$.

6. QUADRO "ATENÇÃO" / RODAPÉ / PÁGINA 2 (SALDO ACUMULADO DE CRÉDITOS):
   - Procure no quadro "ATENÇÃO" (geralmente no topo da Página 2 da Energisa ou no rodapé):
     * "ucGdClassification": Texto da classificação (ex: "GD_II, conforme Lei 14.300/22" ou "GD_I").
     * "accumulatedBalanceKwh": Valor numérico de "Saldo Acumulado:" em kWh (ex: 4160.0).
     * "expiringNextCycleKwh": Valor numérico de "A expirar no próximo ciclo:" em kWh (ex: 0.0).

7. HISTÓRICO DE CONSUMO DOS ÚLTIMOS 13 MESES:
   - Extraia a lista "consumptionHistory" com todos os meses listados em "CONSUMO FATURADO" ou "CONSUMO DOS ÚLTIMOS 13 MESES":
     [{"monthYear": "OUT/26", "consumptionKwh": 1472.0, "billingDays": 32}, ...]

Retorne ESTRITAMENTE um JSON válido (sem markdown ```json) com todas essas chaves.
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
        'Não foi possível explodir a fatura com a IA Gemini.\nDetalhes: $lastError',
      );
    }

    final decodedResponse = jsonDecode(utf8.decode(response.bodyBytes));
    final candidates = decodedResponse['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('A IA Gemini não retornou resultados para este documento.');
    }

    final content = candidates.first['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>?;
    if (parts == null || parts.isEmpty) {
      throw Exception('Resposta vazia da IA Gemini.');
    }

    String rawJsonText = parts.first['text'] as String? ?? '';
    rawJsonText = rawJsonText
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .trim();

    final parsedMap = jsonDecode(rawJsonText) as Map<String, dynamic>;
    return ExplodedGdEnergyBill.fromJson(parsedMap);
  }
}

