/// Exemplo de Treinamento (Few-Shot Learning) para o Agente de IA
class AiTrainingExample {
  final String id;
  final String title;
  final String userInput;
  final String expectedOutput;
  final bool isActive;

  AiTrainingExample({
    required this.id,
    required this.title,
    required this.userInput,
    required this.expectedOutput,
    this.isActive = true,
  });

  AiTrainingExample copyWith({
    String? id,
    String? title,
    String? userInput,
    String? expectedOutput,
    bool? isActive,
  }) {
    return AiTrainingExample(
      id: id ?? this.id,
      title: title ?? this.title,
      userInput: userInput ?? this.userInput,
      expectedOutput: expectedOutput ?? this.expectedOutput,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'userInput': userInput,
      'expectedOutput': expectedOutput,
      'isActive': isActive,
    };
  }

  factory AiTrainingExample.fromMap(Map<String, dynamic> map) {
    return AiTrainingExample(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      userInput: map['userInput'] ?? '',
      expectedOutput: map['expectedOutput'] ?? '',
      isActive: map['isActive'] ?? true,
    );
  }
}

/// Configurações e Treinamento do Agente de IA da Empresa
class AiAgentSettingsModel {
  final String? companyId;
  final bool isAiActive;
  final String agentName;
  final String systemInstruction;
  final String customCommercialRules;
  final double defaultServicePriceMarginPercent;
  final double defaultGenerationFactor;
  final String defaultRoofType;
  final int defaultValidityDays;
  final String defaultPaymentTerms;
  final List<String> preferredDistributors;
  final List<String> preferredModuleBrands;
  final List<String> preferredInverterBrands;
  final List<AiTrainingExample> trainingExamples;
  final double temperature;
  final DateTime? updatedAt;

  AiAgentSettingsModel({
    this.companyId,
    this.isAiActive = true,
    this.agentName = 'Mavis Solar AI Assistant',
    required this.systemInstruction,
    this.customCommercialRules = '',
    this.defaultServicePriceMarginPercent = 20.0,
    this.defaultGenerationFactor = 110.0,
    this.defaultRoofType = 'Cerâmico',
    this.defaultValidityDays = 15,
    this.defaultPaymentTerms = 'À vista via PIX (5% desc) ou Boleto 30DD',
    required this.preferredDistributors,
    required this.preferredModuleBrands,
    required this.preferredInverterBrands,
    required this.trainingExamples,
    this.temperature = 0.2,
    this.updatedAt,
  });

  /// Configuração padrão com todas as regras pré-definidas (DEFAULT)
  factory AiAgentSettingsModel.defaultSettings({String? companyId}) {
    return AiAgentSettingsModel(
      companyId: companyId,
      isAiActive: true,
      agentName: 'Mavis Solar AI Assistant',
      systemInstruction: _defaultSystemInstruction,
      customCommercialRules: _defaultCustomCommercialRules,
      defaultServicePriceMarginPercent: 20.0,
      defaultGenerationFactor: 110.0,
      defaultRoofType: 'Cerâmico',
      defaultValidityDays: 15,
      defaultPaymentTerms: 'À vista via PIX (5% desc) ou Boleto 30DD',
      preferredDistributors: [
        'BelEnergy',
        'Edeltec',
        'WEG',
        'Fortlev',
        'Aldo Solar',
        'Sou Energy',
        'Canadian Solar',
        'Elgin',
        'Amara NZero',
        'Neosolar',
      ],
      preferredModuleBrands: [
        'Canadian Solar',
        'TCL Solar',
        'Jinko Solar',
        'JA Solar',
        'LONGi',
        'Trina Solar',
        'Risen',
        'OSDA',
        'ZNShine',
        'Astronergy',
      ],
      preferredInverterBrands: [
        'AUXSOL',
        'Deye',
        'Growatt',
        'Solis',
        'Sungrow',
        'Fronius',
        'GoodWe',
        'Hoymiles',
        'Huawei',
        'WEG',
        'Sofar',
        'TSUN',
      ],
      trainingExamples: _defaultTrainingExamples,
      temperature: 0.2,
      updatedAt: DateTime.now(),
    );
  }

  static const String _defaultSystemInstruction = r'''Você é o Assistente Especialista em Engenharia Solar e Emissão de Propostas Comerciais do CRM.
Sua missão é analisar os arquivos anexados (PDFs, Imagens, Documentos de Identificação, Faturas de Energia, Cotações de Usina Solar) e/ou instruções em texto livre do usuário para gerar uma proposta comercial completa, precisa e estruturada.

REGRAS DE IDENTIFICAÇÃO E CLASSIFICAÇÃO AUTOMÁTICA DE MÚLTIPLOS DOCUMENTOS:
1. DOCUMENTO DO CLIENTE / IDENTIFICAÇÃO / CONTA DE ENERGIA:
   - Se um dos arquivos for CNH, RG, CPF, Cartão CNPJ, Contrato ou Fatura de Energia Elétrica (DANF3E, Energisa, Enel, CPFL, Cemig, Copel, Equatorial, etc.):
   - Identifique e extraia: Nome Completo / Razão Social ("clientName"), CPF ou CNPJ formatado ("clientDocument"), tipo de pessoa ("clientType": "person" | "company"), e-mail ("clientEmail"), telefone/whatsapp ("clientPhone"), endereço completo ("street", "addressNumber", "complement", "neighborhood", "city", "state" com 2 letras, "zipCode" com 8 dígitos), código da unidade consumidora ("ucNumber"), distribuidora ("utilityCompany") e média mensal de consumo ("averageMonthlyConsumptionKwh").

2. COTAÇÃO FOTOVOLTAICA / ORÇAMENTO DE DISTRIBUIDORA / KIT SOLAR:
   - Se um dos arquivos for cotação de distribuidora (BelEnergy, Edeltec, Fortlev, WEG, Aldo, Sou Energy, Canadian, Elgin, etc.) ou lista de equipamentos:
   - Extraia o código/número da proposta ("proposalNumber"), nome da distribuidora ("distributorName"), tipo de telhado/cobertura ("roofType": "Cerâmico" | "Metálico" | "Fibrocimento" | "Isotérmico" | "Solo" | "Laje" | "Sem Estrutura"), valor dos produtos ("productsPrice"), potência da usina em kWp ("kilowatts"), estimativa de geração mensal em kWh ("generationKwh") e TODOS os componentes na lista "items".

3. PROMPT EM TEXTO LIVRE (OU INSTRUÇÕES ENVIADAS POR PARTES):
   - Se o usuário escrever em linguagem natural (ex: "Monte uma proposta pra mim com 15 placas de 615W e 1 inversor AUXSOL de 8kw, com geração de 1000kwh mes e valor de servico R$ 10.000" ou colar mensagens de WhatsApp):
   - Extraia a quantidade de módulos (ex: 15), potência em Watts (ex: 615W), inversor (ex: AUXSOL 8kW), geração em kWh/mês (ex: 1000), valor do serviço ("servicePrice", ex: 10000.0) e dados do cliente se mencionados.
   - Calcule a potência da usina: kilowatts = (Quantidade de Módulos * Watts do Módulo) / 1000 (ex: 15 * 615 / 1000 = 9.225 kWp).

4. CLASSIFICAÇÃO DE COMPONENTES ("componentType"):
   - "module": Módulos fotovoltaicos. OBRIGATÓRIO preencher o campo numérico "watts" (ex: 615, 580, 550, 670).
   - "inverter": Inversores centrais e microinversores.
   - "structure": Estruturas e perfis de fixação.
   - "cable": Cabos solares.
   - "connector": Conectores MC4.
   - "protection": String boxes e dispositivos de proteção.
   - "battery": Baterias solares.
   - "other": Demais acessórios.

5. FORMATO DE RESPOSTA:
Retorne ESTRITAMENTE um objeto JSON válido (sem markdown ```json e sem texto antes ou depois) no seguinte formato:
{
  "client": {
    "name": "Nome do Cliente",
    "document": "000.000.000-00",
    "type": "person",
    "email": "cliente@email.com",
    "phone": "(00) 00000-0000",
    "street": "Rua Exemplo",
    "number": "123",
    "complement": "Apto 101",
    "neighborhood": "Centro",
    "city": "Cidade",
    "state": "UF",
    "zipCode": "00000-000",
    "ucNumber": "12345678",
    "utilityCompany": "Energisa",
    "averageMonthlyConsumptionKwh": 850.0
  },
  "solarPlant": {
    "proposalNumber": "123456",
    "distributorName": "BelEnergy",
    "plantName": "Usina Solar Fotovoltaica 9.22 kWp",
    "roofType": "Cerâmico",
    "kilowatts": 9.225,
    "generationKwh": 1150.0,
    "moduleWatts": 615,
    "moduleCount": 15,
    "moduleBrand": "Canadian Solar",
    "inverterBrand": "AUXSOL",
    "productsPrice": 18500.0,
    "servicePrice": 6500.0,
    "shippingFee": 0.0,
    "items": [
      {
        "name": "Módulo Fotovoltaico Canadian 615W Bifacial N-Type",
        "sku": "CS-615W",
        "quantity": 15,
        "unit": "un",
        "unitPrice": 520.0,
        "componentType": "module",
        "watts": 615
      },
      {
        "name": "Inversor Solar AUXSOL 8kW 220V Monofásico",
        "sku": "AUX-8K",
        "quantity": 1,
        "unit": "un",
        "unitPrice": 5800.0,
        "componentType": "inverter"
      }
    ]
  },
  "commercial": {
    "paymentTerms": "À vista via PIX (5% desc) ou Boleto 30DD",
    "validityDays": 15,
    "deliveryTime": "Imediata / 3 a 5 dias úteis",
    "notes": "Instalação turn-key completa com engenharia, projeto e homologação inclusos."
  }
}''';

  static const String _defaultCustomCommercialRules = r'''• Se a cotação não informar o valor do frete, considerar frete FOB incluso ou R$ 0,00.
• Ao calcular a potência em kWp, multiplique sempre (Qtd de Placas × Watts do Módulo) / 1000.
• Se a geração mensal em kWh não estiver explícita, estime como (kWp × 125 kWh/kWp).
• O prazo de validade padrão da proposta deve ser de 15 dias corridos.
• Destacar sempre a garantia padrão de 25 anos de desempenho nos módulos e 10 anos nos inversores.''';

  static final List<AiTrainingExample> _defaultTrainingExamples = [
    AiTrainingExample(
      id: 'ex_1',
      title: 'Prompt Rápido de Kit Solar por Texto',
      userInput: r'Monte uma proposta com 20 módulos de 615W e inversor Deye de 10kW em telhado metálico para o cliente Carlos Silva CPF 123.456.789-00, geração de 1500 kWh e serviço de 12.000.',
      expectedOutput: r'Cria proposta de 12.30 kWp (20 × 615W), inversor Deye 10kW, telhado Metálico, geração 1500 kWh/mês, cliente Carlos Silva vinculado e valor do serviço R$ 12.000,00.',
      isActive: true,
    ),
    AiTrainingExample(
      id: 'ex_2',
      title: 'Cotação + Conta de Energia (2 Arquivos)',
      userInput: r'[Arquivo 1: cotacao_belenergy_14placas.pdf] + [Arquivo 2: conta_enel_joao_souza.pdf]',
      expectedOutput: r'Identifica Arquivo 2 como fatura do cliente João Souza (extrai endereço, CPF e UC) e Arquivo 1 como cotação da BelEnergy (extrai os 14 módulos de 580W, inversor Growatt 6kW e valor de produtos R$ 14.800).',
      isActive: true,
    ),
    AiTrainingExample(
      id: 'ex_3',
      title: 'Apenas Cotação sem Dados do Cliente',
      userInput: r'[Arquivo: cotacao_edeltec.pdf]',
      expectedOutput: r'Extrai todos os equipamentos do kit, calcula os kWp, produtos R$, e abre a proposta solicitando a seleção do cliente no autocomplete.',
      isActive: true,
    ),
  ];

  AiAgentSettingsModel copyWith({
    String? companyId,
    bool? isAiActive,
    String? agentName,
    String? systemInstruction,
    String? customCommercialRules,
    double? defaultServicePriceMarginPercent,
    double? defaultGenerationFactor,
    String? defaultRoofType,
    int? defaultValidityDays,
    String? defaultPaymentTerms,
    List<String>? preferredDistributors,
    List<String>? preferredModuleBrands,
    List<String>? preferredInverterBrands,
    List<AiTrainingExample>? trainingExamples,
    double? temperature,
    DateTime? updatedAt,
  }) {
    return AiAgentSettingsModel(
      companyId: companyId ?? this.companyId,
      isAiActive: isAiActive ?? this.isAiActive,
      agentName: agentName ?? this.agentName,
      systemInstruction: systemInstruction ?? this.systemInstruction,
      customCommercialRules: customCommercialRules ?? this.customCommercialRules,
      defaultServicePriceMarginPercent: defaultServicePriceMarginPercent ?? this.defaultServicePriceMarginPercent,
      defaultGenerationFactor: defaultGenerationFactor ?? this.defaultGenerationFactor,
      defaultRoofType: defaultRoofType ?? this.defaultRoofType,
      defaultValidityDays: defaultValidityDays ?? this.defaultValidityDays,
      defaultPaymentTerms: defaultPaymentTerms ?? this.defaultPaymentTerms,
      preferredDistributors: preferredDistributors ?? this.preferredDistributors,
      preferredModuleBrands: preferredModuleBrands ?? this.preferredModuleBrands,
      preferredInverterBrands: preferredInverterBrands ?? this.preferredInverterBrands,
      trainingExamples: trainingExamples ?? this.trainingExamples,
      temperature: temperature ?? this.temperature,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'companyId': companyId,
      'isAiActive': isAiActive,
      'agentName': agentName,
      'systemInstruction': systemInstruction,
      'customCommercialRules': customCommercialRules,
      'defaultServicePriceMarginPercent': defaultServicePriceMarginPercent,
      'defaultGenerationFactor': defaultGenerationFactor,
      'defaultRoofType': defaultRoofType,
      'defaultValidityDays': defaultValidityDays,
      'defaultPaymentTerms': defaultPaymentTerms,
      'preferredDistributors': preferredDistributors,
      'preferredModuleBrands': preferredModuleBrands,
      'preferredInverterBrands': preferredInverterBrands,
      'trainingExamples': trainingExamples.map((e) => e.toMap()).toList(),
      'temperature': temperature,
      'updatedAt': (updatedAt ?? DateTime.now()).toIso8601String(),
    };
  }

  factory AiAgentSettingsModel.fromMap(Map<String, dynamic> map, {String? companyId}) {
    final def = AiAgentSettingsModel.defaultSettings(companyId: companyId);

    List<AiTrainingExample> parsedExamples = def.trainingExamples;
    if (map['trainingExamples'] != null && map['trainingExamples'] is List) {
      try {
        parsedExamples = (map['trainingExamples'] as List)
            .map((e) => AiTrainingExample.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList();
      } catch (_) {}
    }

    return AiAgentSettingsModel(
      companyId: companyId ?? map['companyId'],
      isAiActive: map['isAiActive'] ?? true,
      agentName: map['agentName'] ?? def.agentName,
      systemInstruction: map['systemInstruction'] ?? def.systemInstruction,
      customCommercialRules: map['customCommercialRules'] ?? def.customCommercialRules,
      defaultServicePriceMarginPercent: (map['defaultServicePriceMarginPercent'] as num?)?.toDouble() ?? def.defaultServicePriceMarginPercent,
      defaultGenerationFactor: (map['defaultGenerationFactor'] as num?)?.toDouble() ?? def.defaultGenerationFactor,
      defaultRoofType: map['defaultRoofType'] ?? def.defaultRoofType,
      defaultValidityDays: (map['defaultValidityDays'] as num?)?.toInt() ?? def.defaultValidityDays,
      defaultPaymentTerms: map['defaultPaymentTerms'] ?? def.defaultPaymentTerms,
      preferredDistributors: map['preferredDistributors'] != null
          ? List<String>.from(map['preferredDistributors'])
          : def.preferredDistributors,
      preferredModuleBrands: map['preferredModuleBrands'] != null
          ? List<String>.from(map['preferredModuleBrands'])
          : def.preferredModuleBrands,
      preferredInverterBrands: map['preferredInverterBrands'] != null
          ? List<String>.from(map['preferredInverterBrands'])
          : def.preferredInverterBrands,
      trainingExamples: parsedExamples,
      temperature: (map['temperature'] as num?)?.toDouble() ?? def.temperature,
      updatedAt: map['updatedAt'] != null ? DateTime.tryParse(map['updatedAt']) : null,
    );
  }
}
