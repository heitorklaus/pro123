import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../../../clients/domain/models/client_model.dart';
import '../../../products/data/services/gemini_solar_vision_service.dart';
import '../../../products/data/services/solar_proposal_parser_service.dart';
import '../../../settings/data/services/ai_agent_settings_service.dart';
import '../../../settings/domain/models/ai_agent_settings_model.dart';
import '../../domain/models/proposal_item_model.dart';

/// Payload de arquivo para análise multimodal
class ProposalFilePayload {
  final String name;
  final String extension;
  final Uint8List bytes;

  const ProposalFilePayload({
    required this.name,
    required this.extension,
    required this.bytes,
  });

  String get mimeType {
    final ext = extension.toLowerCase().replaceAll('.', '');
    if (ext == 'png') return 'image/png';
    if (ext == 'jpg' || ext == 'jpeg') return 'image/jpeg';
    if (ext == 'webp') return 'image/webp';
    return 'application/pdf';
  }
}

/// Resultado unificado e completo da análise da IA (Cliente + Usina Solar + Serviços)
class ParsedUnifiedProposal {
  // ── Dados do Cliente ───────────────────────────────────────────────────────
  final String? clientId;
  final String? clientName;
  final String? clientDocument;
  final String? clientType; // 'person' | 'company'
  final String? clientEmail;
  final String? clientPhone;
  final String? street;
  final String? addressNumber;
  final String? complement;
  final String? neighborhood;
  final String? city;
  final String? state;
  final String? zipCode;
  final String? ucNumber;
  final String? utilityCompany;
  final double? averageMonthlyConsumptionKwh;

  // ── Dados da Usina Solar / Kit Fotovoltaico ─────────────────────────────────
  final String? proposalNumber;
  final String? distributorName;
  final String plantName;
  final double kilowatts; // kWp
  final double? generationKwh; // kWh/mês
  final String roofType;
  final double productsPrice;
  final double servicePrice;
  final double shippingFee;
  final double totalAmount;
  final List<ParsedSolarItem> items;

  // ── Condições Comerciais ──────────────────────────────────────────────────
  final String? paymentTerms;
  final int validityDays;
  final String? deliveryTime;
  final String? notes;

  // ── Metadados do Diagnóstico ──────────────────────────────────────────────
  final List<String> analyzedFiles;
  final bool hasClientData;
  final bool hasSolarKit;
  final String? aiSummary;
  final String? rawText;

  const ParsedUnifiedProposal({
    this.clientId,
    this.clientName,
    this.clientDocument,
    this.clientType,
    this.clientEmail,
    this.clientPhone,
    this.street,
    this.addressNumber,
    this.complement,
    this.neighborhood,
    this.city,
    this.state,
    this.zipCode,
    this.ucNumber,
    this.utilityCompany,
    this.averageMonthlyConsumptionKwh,
    this.proposalNumber,
    this.distributorName,
    required this.plantName,
    required this.kilowatts,
    this.generationKwh,
    required this.roofType,
    required this.productsPrice,
    required this.servicePrice,
    this.shippingFee = 0.0,
    required this.totalAmount,
    required this.items,
    this.paymentTerms,
    this.validityDays = 15,
    this.deliveryTime,
    this.notes,
    this.analyzedFiles = const [],
    this.hasClientData = false,
    this.hasSolarKit = true,
    this.aiSummary,
    this.rawText,
  });

  /// Converte a usina solar em um item de proposta fotovoltaico consolidado
  ProposalItemModel toSolarPlantProposalItem() {
    final componentsList = items
        .map((it) =>
            '${it.quantity.toStringAsFixed(0)}x ${it.name}${it.sku != null && it.sku!.isNotEmpty ? " (SKU: ${it.sku})" : ""}')
        .toList();

    return ProposalItemModel(
      productId: null,
      name: plantName,
      sku: proposalNumber ?? 'SOLAR-KIT-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      quantity: 1.0,
      unit: 'UN',
      unitPrice: totalAmount > 0 ? totalAmount : (productsPrice + servicePrice),
      discountPercent: 0.0,
      totalPrice: totalAmount > 0 ? totalAmount : (productsPrice + servicePrice),
      isSolarPlant: true,
      solarRoofType: roofType,
      solarKilowatts: kilowatts,
      solarComponents: componentsList,
    );
  }

  /// Retorna os dados do cliente estruturados para modelo ClientModel
  ClientModel toClientModel({String? companyId}) {
    return ClientModel(
      id: clientId ?? '',
      name: (clientName != null && clientName!.trim().isNotEmpty)
          ? clientName!.trim()
          : 'Cliente Identificado IA',
      email: (clientEmail != null && clientEmail!.trim().isNotEmpty)
          ? clientEmail!.trim().toLowerCase()
          : 'cliente@mavis.com',
      phone: clientPhone,
      document: clientDocument,
      type: (clientType?.toLowerCase() == 'company' || (clientDocument != null && clientDocument!.length > 14))
          ? ClientType.company
          : ClientType.person,
      status: ClientStatus.active,
      street: street,
      addressNumber: addressNumber,
      complement: complement,
      neighborhood: neighborhood,
      city: city,
      state: state,
      zipCode: zipCode,
      notes: 'Cadastrado automaticamente via Assistente de IA.${ucNumber != null ? " UC: $ucNumber" : ""}',
      companyId: companyId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  ParsedUnifiedProposal copyWith({
    String? clientId,
    String? clientName,
    String? clientDocument,
    String? clientType,
    String? clientEmail,
    String? clientPhone,
    String? street,
    String? addressNumber,
    String? complement,
    String? neighborhood,
    String? city,
    String? state,
    String? zipCode,
    String? ucNumber,
    String? utilityCompany,
    double? averageMonthlyConsumptionKwh,
    String? proposalNumber,
    String? distributorName,
    String? plantName,
    double? kilowatts,
    double? generationKwh,
    String? roofType,
    double? productsPrice,
    double? servicePrice,
    double? shippingFee,
    double? totalAmount,
    List<ParsedSolarItem>? items,
    String? paymentTerms,
    int? validityDays,
    String? deliveryTime,
    String? notes,
    List<String>? analyzedFiles,
    bool? hasClientData,
    bool? hasSolarKit,
    String? aiSummary,
    String? rawText,
  }) {
    return ParsedUnifiedProposal(
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      clientDocument: clientDocument ?? this.clientDocument,
      clientType: clientType ?? this.clientType,
      clientEmail: clientEmail ?? this.clientEmail,
      clientPhone: clientPhone ?? this.clientPhone,
      street: street ?? this.street,
      addressNumber: addressNumber ?? this.addressNumber,
      complement: complement ?? this.complement,
      neighborhood: neighborhood ?? this.neighborhood,
      city: city ?? this.city,
      state: state ?? this.state,
      zipCode: zipCode ?? this.zipCode,
      ucNumber: ucNumber ?? this.ucNumber,
      utilityCompany: utilityCompany ?? this.utilityCompany,
      averageMonthlyConsumptionKwh:
          averageMonthlyConsumptionKwh ?? this.averageMonthlyConsumptionKwh,
      proposalNumber: proposalNumber ?? this.proposalNumber,
      distributorName: distributorName ?? this.distributorName,
      plantName: plantName ?? this.plantName,
      kilowatts: kilowatts ?? this.kilowatts,
      generationKwh: generationKwh ?? this.generationKwh,
      roofType: roofType ?? this.roofType,
      productsPrice: productsPrice ?? this.productsPrice,
      servicePrice: servicePrice ?? this.servicePrice,
      shippingFee: shippingFee ?? this.shippingFee,
      totalAmount: totalAmount ?? this.totalAmount,
      items: items ?? this.items,
      paymentTerms: paymentTerms ?? this.paymentTerms,
      validityDays: validityDays ?? this.validityDays,
      deliveryTime: deliveryTime ?? this.deliveryTime,
      notes: notes ?? this.notes,
      analyzedFiles: analyzedFiles ?? this.analyzedFiles,
      hasClientData: hasClientData ?? this.hasClientData,
      hasSolarKit: hasSolarKit ?? this.hasSolarKit,
      aiSummary: aiSummary ?? this.aiSummary,
      rawText: rawText ?? this.rawText,
    );
  }
}

/// Microserviço Avançado de Inteligência Artificial para Propostas e Usinas Solares
class GeminiProposalAssistantService {
  /// Processa arquivos e/ou texto através da IA Google Gemini
  static Future<ParsedUnifiedProposal> analyzeProposal({
    List<ProposalFilePayload>? files,
    String? textPrompt,
    String? customApiKey,
    String? companyId,
    AiAgentSettingsModel? customAiSettings,
  }) async {
    final apiKey = (customApiKey != null && customApiKey.trim().isNotEmpty)
        ? customApiKey.trim()
        : await GeminiSolarVisionService.getSavedApiKey();

    final aiSettings = customAiSettings ?? await AiAgentSettingsService.getSettings(companyId: companyId);

    final hasFiles = files != null && files.isNotEmpty;
    final hasText = textPrompt != null && textPrompt.trim().isNotEmpty;

    if (!hasFiles && !hasText) {
      throw Exception('Envie ao menos um arquivo ou digite as instruções da proposta.');
    }

    // Se temos chave API do Gemini, faz a chamada multimodal avançada
    if (apiKey.isNotEmpty) {
      try {
        return await _callGeminiApi(
          apiKey: apiKey,
          files: files ?? [],
          textPrompt: textPrompt,
          aiSettings: aiSettings,
        );
      } catch (e) {
        // Se falhar e houver texto, tenta o fallback local
        if (hasText) {
          return _fallbackLocalTextParser(textPrompt, files: files, aiSettings: aiSettings);
        }
        rethrow;
      }
    }

    // Caso não tenha chave API, executa o parser local inteligente
    if (hasText) {
      return _fallbackLocalTextParser(textPrompt, files: files, aiSettings: aiSettings);
    }

    throw Exception(
      'Para analisar arquivos (PDFs/Imagens) com inteligência multimodal, configure sua chave do Google Gemini.',
    );
  }

  /// Chamada HTTP direta à API Gemini com suporte a múltiplos arquivos e texto simultâneos
  static Future<ParsedUnifiedProposal> _callGeminiApi({
    required String apiKey,
    required List<ProposalFilePayload> files,
    String? textPrompt,
    required AiAgentSettingsModel aiSettings,
  }) async {
    final parts = <Map<String, dynamic>>[];

    // 1. Adiciona cada arquivo como inlineData
    for (final f in files) {
      final base64Content = base64Encode(f.bytes);
      parts.add({
        'inlineData': {
          'mimeType': f.mimeType,
          'data': base64Content,
        },
      });
    }

    // 2. Monta a instrução de texto combinada a partir das configurações ativas do Agente
    final userInstructions = StringBuffer();
    userInstructions.writeln(AiAgentSettingsService.buildEffectiveSystemPrompt(aiSettings));

    if (files.isNotEmpty) {
      userInstructions.writeln('\nArquivos anexados pelo usuário para análise conjunta:');
      for (int i = 0; i < files.length; i++) {
        userInstructions.writeln('- Arquivo ${i + 1}: ${files[i].name} (${files[i].extension})');
      }
    }

    if (textPrompt != null && textPrompt.trim().isNotEmpty) {
      userInstructions.writeln('\nInstruções / Texto digitado pelo usuário:');
      userInstructions.writeln('"""\n$textPrompt\n"""');
    }

    parts.add({
      'text': userInstructions.toString(),
    });

    final requestBody = {
      'contents': [
        {
          'parts': parts,
        },
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'temperature': aiSettings.temperature,
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
      try {
        final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
        );

        response = await http
            .post(
              url,
              headers: {
                'Content-Type': 'application/json',
                'x-goog-api-key': apiKey,
              },
              body: jsonEncode(requestBody),
            )
            .timeout(const Duration(seconds: 45));

        if (response.statusCode == 200) {
          break;
        } else {
          lastError = 'Status ${response.statusCode}: ${response.body}';
        }
      } catch (e) {
        lastError = e.toString();
      }
    }

    if (response == null || response.statusCode != 200) {
      throw Exception('Falha ao comunicar com a IA do Google Gemini: $lastError');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('Nenhuma resposta retornada pela IA.');
    }

    final content = candidates[0]['content'] as Map<String, dynamic>?;
    final partsResponse = content?['parts'] as List?;
    if (partsResponse == null || partsResponse.isEmpty) {
      throw Exception('Conteúdo vazio retornado pela IA.');
    }

    final rawJsonText = partsResponse[0]['text'] as String;
    return _parseGeminiJsonResponse(
      rawJsonText,
      files: files,
      userText: textPrompt,
    );
  }

  /// Converte o JSON estruturado retornado pelo Gemini em ParsedUnifiedProposal
  static ParsedUnifiedProposal _parseGeminiJsonResponse(
    String jsonString, {
    List<ProposalFilePayload> files = const [],
    String? userText,
  }) {
    String cleanJson = jsonString.trim();
    if (cleanJson.startsWith('```json')) {
      cleanJson = cleanJson.substring(7);
    }
    if (cleanJson.startsWith('```')) {
      cleanJson = cleanJson.substring(3);
    }
    if (cleanJson.endsWith('```')) {
      cleanJson = cleanJson.substring(0, cleanJson.length - 3);
    }
    cleanJson = cleanJson.trim();

    final map = jsonDecode(cleanJson) as Map<String, dynamic>;

    final clientMap = (map['client'] is Map) ? Map<String, dynamic>.from(map['client'] as Map) : null;
    final solarMap = (map['solarPlant'] is Map) ? Map<String, dynamic>.from(map['solarPlant'] as Map) : null;
    final commMap = (map['commercial'] is Map) ? Map<String, dynamic>.from(map['commercial'] as Map) : null;

    // Extrai itens
    final itemsList = <ParsedSolarItem>[];
    final rawItemsList = (solarMap?['items'] ?? map['items']) as List?;

    if (rawItemsList != null) {
      for (final rawItem in rawItemsList) {
        if (rawItem is Map) {
          final itMap = Map<String, dynamic>.from(rawItem);
          final compTypeStr = itMap['componentType'] as String? ?? 'other';
          final wattsNum = itMap['watts'] != null ? (itMap['watts'] as num).toDouble() : null;

          SolarComponentType cType = SolarComponentType.other;
          switch (compTypeStr.toLowerCase()) {
            case 'module':
              cType = SolarComponentType.module;
              break;
            case 'inverter':
              cType = SolarComponentType.inverter;
              break;
            case 'structure':
              cType = SolarComponentType.structure;
              break;
            case 'cable':
              cType = SolarComponentType.cable;
              break;
            case 'connector':
              cType = SolarComponentType.connector;
              break;
            case 'protection':
              cType = SolarComponentType.protection;
              break;
            case 'battery':
              cType = SolarComponentType.battery;
              break;
            default:
              cType = SolarComponentType.other;
          }

          itemsList.add(
            ParsedSolarItem(
              name: itMap['name'] as String? ?? 'Item Solar',
              sku: itMap['sku'] as String?,
              manufacturer: itMap['manufacturer'] as String?,
              quantity: (itMap['quantity'] as num?)?.toDouble() ?? 1.0,
              unit: itMap['unit'] as String? ?? 'UN',
              unitPrice: (itMap['unitPrice'] as num?)?.toDouble() ?? 0.0,
              totalPrice: (itMap['totalPrice'] as num?)?.toDouble() ?? 0.0,
              componentType: cType,
              moduleWatts: wattsNum,
            ),
          );
        }
      }
    }

    // Calcula potência em kWp se veio 0 ou inconsistente
    double kwp = (solarMap?['kilowatts'] ?? map['kilowatts'] as num?)?.toDouble() ?? 0.0;
    if (kwp <= 0) {
      double totalW = 0.0;
      for (final it in itemsList) {
        final w = it.effectiveModuleWatts;
        if (w != null && w > 0 && (it.componentType == SolarComponentType.module || it.moduleWatts != null)) {
          totalW += (w * it.quantity);
        }
      }
      if (totalW > 0) {
        kwp = totalW / 1000.0;
      }
    }

    final clientName = (clientMap?['name'] ?? clientMap?['clientName'] ?? map['clientName'] ?? map['name']) as String?;
    final clientDoc = (clientMap?['document'] ?? clientMap?['clientDocument'] ?? map['clientDocument'] ?? map['document']) as String?;
    final hasClient = (clientName != null && clientName.trim().isNotEmpty) ||
        (clientDoc != null && clientDoc.trim().isNotEmpty);

    final genKwh = (solarMap?['generationKwh'] ?? map['generationKwh'] as num?)?.toDouble();
    final prodPrice = (solarMap?['productsPrice'] ?? map['productsPrice'] as num?)?.toDouble() ?? 0.0;
    final servPrice = (solarMap?['servicePrice'] ?? map['servicePrice'] as num?)?.toDouble() ?? 0.0;
    final shipFee = (solarMap?['shippingFee'] ?? map['shippingFee'] as num?)?.toDouble() ?? 0.0;
    final totAmount = (solarMap?['totalAmount'] ?? map['totalAmount'] as num?)?.toDouble() ?? (prodPrice + servPrice + shipFee);

    final proposalNum = (solarMap?['proposalNumber'] ?? map['proposalNumber']) as String?;
    final distributorName = (solarMap?['distributorName'] ?? map['distributorName']) as String?;
    final plantTitle = (solarMap?['plantName'] ?? map['plantName']) as String? ??
        'Usina Solar ${kwp > 0 ? "${kwp.toStringAsFixed(2)} kWp" : "Fotovoltaica"}';
    final roofType = (solarMap?['roofType'] ?? map['roofType']) as String? ?? 'Cerâmico';

    final paymentTerms = (commMap?['paymentTerms'] ?? map['paymentTerms']) as String? ?? 'À vista via PIX ou Financiamento Solar em até 120x';
    final validityDays = (commMap?['validityDays'] ?? map['validityDays'] as num?)?.toInt() ?? 15;
    final deliveryTime = (commMap?['deliveryTime'] ?? map['deliveryTime']) as String? ?? '15 a 20 dias úteis';
    final notes = (commMap?['notes'] ?? map['notes']) as String?;

    return ParsedUnifiedProposal(
      clientName: clientName,
      clientDocument: clientDoc,
      clientType: (clientMap?['type'] ?? map['clientType']) as String?,
      clientEmail: (clientMap?['email'] ?? map['clientEmail']) as String?,
      clientPhone: (clientMap?['phone'] ?? map['clientPhone']) as String?,
      street: (clientMap?['street'] ?? map['street']) as String?,
      addressNumber: (clientMap?['number'] ?? clientMap?['addressNumber'] ?? map['addressNumber'] ?? map['number']) as String?,
      complement: (clientMap?['complement'] ?? map['complement']) as String?,
      neighborhood: (clientMap?['neighborhood'] ?? map['neighborhood']) as String?,
      city: (clientMap?['city'] ?? map['city']) as String?,
      state: (clientMap?['state'] ?? map['state']) as String?,
      zipCode: (clientMap?['zipCode'] ?? map['zipCode']) as String?,
      ucNumber: (clientMap?['ucNumber'] ?? map['ucNumber']) as String?,
      utilityCompany: (clientMap?['utilityCompany'] ?? map['utilityCompany']) as String?,
      averageMonthlyConsumptionKwh:
          (clientMap?['averageMonthlyConsumptionKwh'] ?? map['averageMonthlyConsumptionKwh'] as num?)?.toDouble(),
      proposalNumber: proposalNum,
      distributorName: distributorName,
      plantName: plantTitle,
      kilowatts: kwp,
      generationKwh: genKwh ?? (kwp > 0 ? (kwp * 120.0).roundToDouble() : null),
      roofType: roofType,
      productsPrice: prodPrice,
      servicePrice: servPrice,
      shippingFee: shipFee,
      totalAmount: totAmount,
      items: itemsList,
      paymentTerms: paymentTerms,
      validityDays: validityDays,
      deliveryTime: deliveryTime,
      notes: notes,
      analyzedFiles: files.map((f) => f.name).toList(),
      hasClientData: hasClient,
      hasSolarKit: itemsList.isNotEmpty || kwp > 0,
      aiSummary: map['aiSummary'] as String? ??
          'Proposta gerada com sucesso pela IA do Mavis CRM.',
      rawText: userText,
    );
  }

  /// Parser de texto local inteligente (Fallback robusto com RegEx avançado)
  static ParsedUnifiedProposal _fallbackLocalTextParser(
    String text, {
    List<ProposalFilePayload>? files,
    AiAgentSettingsModel? aiSettings,
  }) {
    final lower = text.toLowerCase();

    // 1. Módulos / Placas
    int moduleCount = 0;
    double moduleWatts = 0.0;
    String moduleBrand = 'Solar';

    final moduleMatch = RegExp(
      r'(\d+)\s*(?:placas?|paineis?|painéis?|modulos?|módulos?)\s*(?:de\s*)?(\d{3,4})\s*(?:w|watts|wp)?',
      caseSensitive: false,
    ).firstMatch(text);

    if (moduleMatch != null) {
      moduleCount = int.tryParse(moduleMatch.group(1)!) ?? 0;
      moduleWatts = double.tryParse(moduleMatch.group(2)!) ?? 0.0;
    } else {
      // Tenta achar placas avulsas
      final qtyMatch = RegExp(r'(\d+)\s*(?:placas?|paineis?|painéis?|modulos?|módulos?)', caseSensitive: false).firstMatch(text);
      if (qtyMatch != null) {
        moduleCount = int.tryParse(qtyMatch.group(1)!) ?? 0;
      }
      final wMatch = RegExp(r'(\d{3,4})\s*(?:w|watts|wp)\b', caseSensitive: false).firstMatch(text);
      if (wMatch != null) {
        moduleWatts = double.tryParse(wMatch.group(1)!) ?? 550.0;
      }
    }

    if (moduleWatts <= 0) moduleWatts = 615.0;

    // Identifica marca de módulo
    if (lower.contains('tcl')) {
      moduleBrand = 'TCL';
    } else if (lower.contains('canadian')) {
      moduleBrand = 'Canadian Solar';
    } else if (lower.contains('jinko')) {
      moduleBrand = 'Jinko Solar';
    } else if (lower.contains('ja solar')) {
      moduleBrand = 'JA Solar';
    } else if (lower.contains('longi')) {
      moduleBrand = 'LONGi';
    } else if (lower.contains('trina')) {
      moduleBrand = 'Trina Solar';
    } else if (lower.contains('risen')) {
      moduleBrand = 'Risen';
    } else if (lower.contains('osda')) {
      moduleBrand = 'OSDA';
    }

    // 2. Inversor
    int inverterCount = 1;
    double inverterKw = 0.0;
    String inverterBrand = 'Inversor';

    final invMatch = RegExp(
      r'(\d+)?\s*inversor(?:es)?\s*([a-zA-Z\s]+)?\s*(?:de\s*)?(\d+(?:[.,]\d+)?)\s*(?:kw|kva|w)?',
      caseSensitive: false,
    ).firstMatch(text);

    if (invMatch != null) {
      inverterCount = int.tryParse(invMatch.group(1) ?? '1') ?? 1;
      inverterKw = double.tryParse((invMatch.group(3) ?? '0').replaceAll(',', '.')) ?? 0.0;
      if (invMatch.group(2) != null && invMatch.group(2)!.trim().isNotEmpty) {
        inverterBrand = invMatch.group(2)!.trim().toUpperCase();
      }
    }

    if (lower.contains('auxsol')) {
      inverterBrand = 'AUXSOL';
    } else if (lower.contains('deye')) {
      inverterBrand = 'Deye';
    } else if (lower.contains('growatt')) {
      inverterBrand = 'Growatt';
    } else if (lower.contains('solis')) {
      inverterBrand = 'Solis';
    } else if (lower.contains('sungrow')) {
      inverterBrand = 'Sungrow';
    } else if (lower.contains('fronius')) {
      inverterBrand = 'Fronius';
    } else if (lower.contains('goodwe')) {
      inverterBrand = 'GoodWe';
    } else if (lower.contains('hoymiles')) {
      inverterBrand = 'Hoymiles';
    } else if (lower.contains('huawei')) {
      inverterBrand = 'Huawei';
    } else if (lower.contains('weg')) {
      inverterBrand = 'WEG';
    }

    // 3. Geração em kWh/mês
    double? generationKwh;
    final genMatch = RegExp(
      r'(?:geração|geracao|estimativa|gera)\s*(?:de\s*)?(\d+(?:[.,]\d+)?)\s*(?:kwh|kw\/h)?',
      caseSensitive: false,
    ).firstMatch(text);
    if (genMatch != null) {
      generationKwh = double.tryParse(genMatch.group(1)!.replaceAll('.', '').replaceAll(',', '.'));
    }

    // 4. Valor do Serviço
    double servicePrice = 0.0;
    final servMatch = RegExp(
      r'(?:serviço|servico|instalação|instalacao|mao de obra|mão de obra)\s*(?:de\s*)?(?:r\$\s*)?(\d{1,3}(?:\.\d{3})*(?:,\d{2})?|\d+(?:[.,]\d+)?)',
      caseSensitive: false,
    ).firstMatch(text);
    if (servMatch != null) {
      final rawNum = servMatch.group(1)!.replaceAll('.', '').replaceAll(',', '.');
      servicePrice = double.tryParse(rawNum) ?? 0.0;
    }

    // 5. Cliente (se mencionado no texto)
    String? clientName;
    final clientMatch = RegExp(
      r'(?:para o cliente|para a cliente|cliente|destinat[áa]rio|titular)\s*(?::\s*|\s+)?([a-zA-ZÀ-ÿ\s]+?)(?:,|\.|\bcpf\b|\bcnpj\b|\bgera[çc]|\bcom\b|\bservi[çc]|\be\b|$)',
      caseSensitive: false,
    ).firstMatch(text);
    if (clientMatch != null) {
      final candidate = clientMatch.group(1)?.trim();
      if (candidate != null && candidate.isNotEmpty && candidate.length >= 3) {
        clientName = candidate;
      }
    }

    // 6. Tipo de Telhado
    String roofType = aiSettings?.defaultRoofType ?? 'Cerâmico';
    if (lower.contains('metálico') || lower.contains('metalico')) {
      roofType = 'Metálico';
    } else if (lower.contains('fibrocimento') || lower.contains('fibro')) {
      roofType = 'Fibrocimento';
    } else if (lower.contains('cerâmico') || lower.contains('ceramico') || lower.contains('colonial') || lower.contains('telha')) {
      roofType = 'Cerâmico';
    } else if (lower.contains('solo') || lower.contains('chão')) {
      roofType = 'Solo';
    } else if (lower.contains('laje') || lower.contains('concreto')) {
      roofType = 'Laje';
    } else if (lower.contains('isotérmico') || lower.contains('isotermico') || lower.contains('sanduiche')) {
      roofType = 'Isotérmico';
    } else if (lower.contains('sem estrutura')) {
      roofType = 'Sem Estrutura';
    }

    // 7. Potência Total em kWp
    double kwp = 0.0;
    if (moduleCount > 0 && moduleWatts > 0) {
      kwp = (moduleCount * moduleWatts) / 1000.0;
    } else if (inverterKw > 0) {
      kwp = inverterKw * 1.25; // Suposição de overload
    }

    if (generationKwh == null && kwp > 0) {
      final factor = aiSettings?.defaultGenerationFactor ?? 120.0;
      generationKwh = (kwp * factor).roundToDouble();
    }

    // 8. Montagem dos itens do kit
    final items = <ParsedSolarItem>[];
    if (moduleCount > 0) {
      items.add(
        ParsedSolarItem(
          name: 'Módulo Solar Fotovoltaico $moduleBrand ${moduleWatts.toStringAsFixed(0)}W Monocristalino',
          sku: 'MOD-${moduleWatts.toStringAsFixed(0)}W',
          manufacturer: moduleBrand,
          quantity: moduleCount.toDouble(),
          unit: 'PC',
          componentType: SolarComponentType.module,
          moduleWatts: moduleWatts,
        ),
      );
    }

    if (inverterKw > 0 || inverterBrand != 'Inversor') {
      items.add(
        ParsedSolarItem(
          name: 'Inversor Solar On-Grid $inverterBrand ${inverterKw > 0 ? "${inverterKw.toStringAsFixed(1)}kW" : "Fotovoltaico"}',
          sku: 'INV-${inverterBrand.toUpperCase()}',
          manufacturer: inverterBrand,
          quantity: inverterCount.toDouble(),
          unit: 'UN',
          componentType: SolarComponentType.inverter,
        ),
      );
    }

    final plantTitle = 'Usina Solar ${kwp > 0 ? "${kwp.toStringAsFixed(2)} kWp" : "Fotovoltaica"} - Inversor $inverterBrand + ${moduleCount > 0 ? "${moduleCount}x Módulos ${moduleWatts.toStringAsFixed(0)}W" : ""}';

    return ParsedUnifiedProposal(
      clientName: clientName,
      hasClientData: clientName != null && clientName.isNotEmpty,
      plantName: plantTitle,
      kilowatts: kwp,
      generationKwh: generationKwh,
      roofType: roofType,
      productsPrice: 0.0,
      servicePrice: servicePrice,
      totalAmount: servicePrice,
      items: items,
      paymentTerms: aiSettings?.defaultPaymentTerms ?? 'À vista via PIX ou Financiamento Bancário',
      validityDays: aiSettings?.defaultValidityDays ?? 15,
      deliveryTime: '15 a 20 dias úteis',
      analyzedFiles: files?.map((f) => f.name).toList() ?? [],
      hasSolarKit: items.isNotEmpty,
      aiSummary: 'Instruções em texto processadas com sucesso.',
      rawText: text,
    );
  }
}
