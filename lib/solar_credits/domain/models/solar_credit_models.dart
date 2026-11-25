import 'package:cloud_firestore/cloud_firestore.dart';

/// Regime de Geração Distribuída (Lei 14.300/22)
enum GdRegime {
  gd1,
  gd2;

  String get label {
    switch (this) {
      case GdRegime.gd1:
        return 'GD I (Compensação Integral)';
      case GdRegime.gd2:
        return 'GD II (Lei 14.300 - Com Ajuste GD)';
    }
  }

  String get shortLabel => this == GdRegime.gd1 ? 'GD I' : 'GD II';

  static GdRegime fromString(String? value) {
    if (value == null) return GdRegime.gd2;
    final clean = value.toLowerCase().trim();
    if (clean == 'gd1' || clean == 'gdi' || clean == 'gd_i') {
      return GdRegime.gd1;
    }
    return GdRegime.gd2;
  }
}

/// Modelo de Usina Geradora (Origem dos Créditos de Energia Solar)
class SolarGeneratorPlantModel {
  final String id;
  final String companyId;
  final String name; // Ex: Usina Solar I - Cuiabá
  final String generatorUcNumber; // Nº da UC Geradora na Energisa
  final String accountHolderName; // Titular da Conta (Seu Nome ou Sua Empresa)
  final String accountHolderDocument; // CPF ou CNPJ do Titular
  final GdRegime regime; // GD1 ou GD2
  final double installedPowerKwp; // Potência instalada em kWp
  final double estimatedMonthlyGenerationKwh; // Geração média mensal em kWh
  final String city;
  final String state;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SolarGeneratorPlantModel({
    required this.id,
    required this.companyId,
    required this.name,
    required this.generatorUcNumber,
    required this.accountHolderName,
    this.accountHolderDocument = '',
    this.regime = GdRegime.gd2,
    this.installedPowerKwp = 0.0,
    required this.estimatedMonthlyGenerationKwh,
    this.city = 'Cuiabá',
    this.state = 'MT',
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SolarGeneratorPlantModel.fromMap(Map<String, dynamic> map, String id) {
    return SolarGeneratorPlantModel(
      id: id,
      companyId: map['companyId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      generatorUcNumber: map['generatorUcNumber'] as String? ?? '',
      accountHolderName: map['accountHolderName'] as String? ?? '',
      accountHolderDocument: map['accountHolderDocument'] as String? ?? '',
      regime: GdRegime.fromString(map['regime'] as String?),
      installedPowerKwp: (map['installedPowerKwp'] as num?)?.toDouble() ?? 0.0,
      estimatedMonthlyGenerationKwh:
          (map['estimatedMonthlyGenerationKwh'] as num?)?.toDouble() ?? 0.0,
      city: map['city'] as String? ?? 'Cuiabá',
      state: map['state'] as String? ?? 'MT',
      notes: map['notes'] as String?,
      createdAt: _parseDate(map['createdAt']),
      updatedAt: _parseDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'companyId': companyId,
      'name': name,
      'generatorUcNumber': generatorUcNumber,
      'accountHolderName': accountHolderName,
      'accountHolderDocument': accountHolderDocument,
      'regime': regime.name,
      'installedPowerKwp': installedPowerKwp,
      'estimatedMonthlyGenerationKwh': estimatedMonthlyGenerationKwh,
      'city': city,
      'state': state,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  SolarGeneratorPlantModel copyWith({
    String? id,
    String? companyId,
    String? name,
    String? generatorUcNumber,
    String? accountHolderName,
    String? accountHolderDocument,
    GdRegime? regime,
    double? installedPowerKwp,
    double? estimatedMonthlyGenerationKwh,
    String? city,
    String? state,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SolarGeneratorPlantModel(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      name: name ?? this.name,
      generatorUcNumber: generatorUcNumber ?? this.generatorUcNumber,
      accountHolderName: accountHolderName ?? this.accountHolderName,
      accountHolderDocument:
          accountHolderDocument ?? this.accountHolderDocument,
      regime: regime ?? this.regime,
      installedPowerKwp: installedPowerKwp ?? this.installedPowerKwp,
      estimatedMonthlyGenerationKwh:
          estimatedMonthlyGenerationKwh ?? this.estimatedMonthlyGenerationKwh,
      city: city ?? this.city,
      state: state ?? this.state,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Vínculo individual de uma Usina Geradora e sua % de rateio para um Cliente / UC
class BeneficiaryPlantAllocationItem {
  final String generatorPlantId;
  final String generatorPlantName;
  final GdRegime generatorRegime;
  final double allocationPercent; // % cadastrada na concessionária nesta usina específica

  const BeneficiaryPlantAllocationItem({
    required this.generatorPlantId,
    required this.generatorPlantName,
    this.generatorRegime = GdRegime.gd2,
    required this.allocationPercent,
  });

  factory BeneficiaryPlantAllocationItem.fromMap(Map<String, dynamic> map) {
    return BeneficiaryPlantAllocationItem(
      generatorPlantId: map['generatorPlantId'] as String? ?? '',
      generatorPlantName: map['generatorPlantName'] as String? ?? '',
      generatorRegime: GdRegime.fromString(map['generatorRegime'] as String?),
      allocationPercent: _normalizePercent(
        (map['allocationPercent'] as num?)?.toDouble() ??
            (map['utilityAllocationPercent'] as num?)?.toDouble() ??
            0.0,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'generatorPlantId': generatorPlantId,
      'generatorPlantName': generatorPlantName,
      'generatorRegime': generatorRegime.name,
      'allocationPercent': allocationPercent,
    };
  }

  BeneficiaryPlantAllocationItem copyWith({
    String? generatorPlantId,
    String? generatorPlantName,
    GdRegime? generatorRegime,
    double? allocationPercent,
  }) {
    return BeneficiaryPlantAllocationItem(
      generatorPlantId: generatorPlantId ?? this.generatorPlantId,
      generatorPlantName: generatorPlantName ?? this.generatorPlantName,
      generatorRegime: generatorRegime ?? this.generatorRegime,
      allocationPercent: allocationPercent ?? this.allocationPercent,
    );
  }
}

/// Modelo de Cliente / Unidade Consumidora Beneficiária de Créditos Solares
class SolarCreditBeneficiaryModel {
  final String id;
  final String companyId;
  final String clientName; // Nome do Cliente Final (quem usa e paga os créditos)
  final String clientPhone; // WhatsApp / Telefone do cliente
  final String clientDocument; // CPF / CNPJ do cliente final
  final String accountHolderName; // Titular impresso na conta da Energisa (Seu nome ou sua empresa)
  final String accountHolderDocument; // CPF / CNPJ do titular na conta
  final String ucNumber; // Número da UC na Energisa (ex: 2.024.081.017-07)
  final String addressStreet; // Logradouro e número (ex: RUA ALFENAS, 120)
  final String addressNeighborhood; // Bairro (ex: JARDIM MARIANA)
  final String addressCity; // Cidade (ex: Cuiabá)
  final String addressState; // UF (ex: MT)
  final String addressZipCode; // CEP (ex: 78040-600)
  final String connectionType; // Trifásico, Bifásico, Monofásico
  final String generatorPlantId; // ID da Usina Origem Principal
  final String generatorPlantName; // Nome da Usina Origem Principal (ou resumo)
  final GdRegime generatorRegime; // GD1 ou GD2
  final double utilityAllocationPercent; // % cadastrada na concessionária (Principal / Soma)
  final List<BeneficiaryPlantAllocationItem> plantAllocations; // Lista de 1 ou mais Usinas que enviam créditos para esta UC
  final double clientDiscountPercent; // % de Desconto / Deságio concedido ao cliente
  final double averageMonthlyConsumptionKwh; // Consumo médio mensal (kWh)
  final double lastAccumulatedBalanceKwh; // Último Saldo Acumulado lido no rodapé da fatura (kWh)
  final double lastInjectedKwh; // Última energia injetada no mês (kWh)
  final String? lastReferenceMonth; // Último mês de referência lançado
  final String status; // 'active' | 'inactive'
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SolarCreditBeneficiaryModel({
    required this.id,
    required this.companyId,
    required this.clientName,
    this.clientPhone = '',
    this.clientDocument = '',
    required this.accountHolderName,
    this.accountHolderDocument = '',
    required this.ucNumber,
    required this.addressStreet,
    this.addressNeighborhood = '',
    this.addressCity = 'Cuiabá',
    this.addressState = 'MT',
    this.addressZipCode = '',
    this.connectionType = 'Trifásico',
    required this.generatorPlantId,
    required this.generatorPlantName,
    this.generatorRegime = GdRegime.gd2,
    required this.utilityAllocationPercent,
    this.plantAllocations = const [],
    required this.clientDiscountPercent,
    this.averageMonthlyConsumptionKwh = 0.0,
    this.lastAccumulatedBalanceKwh = 0.0,
    this.lastInjectedKwh = 0.0,
    this.lastReferenceMonth,
    this.status = 'active',
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Retorna a lista efetiva de usinas vinculadas (garantindo compatibilidade com cadastros de 1 usina)
  List<BeneficiaryPlantAllocationItem> get effectivePlantAllocations {
    if (plantAllocations.isNotEmpty) return plantAllocations;
    return [
      BeneficiaryPlantAllocationItem(
        generatorPlantId: generatorPlantId,
        generatorPlantName: generatorPlantName.isNotEmpty
            ? generatorPlantName
            : 'Usina Principal',
        generatorRegime: generatorRegime,
        allocationPercent: utilityAllocationPercent,
      ),
    ];
  }

  /// Indica se este cliente recebe créditos de mais de uma usina geradora
  bool get hasMultiplePlants => effectivePlantAllocations.length > 1;

  /// Verifica se este cliente recebe créditos de uma determinada usina (por ID ou Nome)
  bool receivesFromPlant(String plantId, [String? plantName]) {
    for (final item in effectivePlantAllocations) {
      if (plantId.isNotEmpty && item.generatorPlantId == plantId) {
        return true;
      }
      if (plantName != null &&
          plantName.trim().isNotEmpty &&
          item.generatorPlantName.trim().toUpperCase() ==
              plantName.trim().toUpperCase()) {
        return true;
      }
    }
    return false;
  }

  /// Retorna a % de rateio cadastrada para este cliente especificamente na usina informada
  double allocationPercentForPlant(String plantId, [String? plantName]) {
    double sum = 0.0;
    for (final item in effectivePlantAllocations) {
      final matchId = plantId.isNotEmpty && item.generatorPlantId == plantId;
      final matchName = plantName != null &&
          plantName.trim().isNotEmpty &&
          item.generatorPlantName.trim().toUpperCase() ==
              plantName.trim().toUpperCase();
      if (matchId || matchName) {
        sum += item.allocationPercent;
      }
    }
    return sum;
  }

  /// Calcula o total estimado de créditos mensais (em kWh) somando todas as usinas vinculadas a este cliente
  double totalAllocatedCreditsKwh(List<SolarGeneratorPlantModel> allPlants) {
    double totalKwh = 0.0;
    for (final alloc in effectivePlantAllocations) {
      SolarGeneratorPlantModel? matched;
      for (final p in allPlants) {
        if (p.id == alloc.generatorPlantId ||
            p.name.trim().toUpperCase() ==
                alloc.generatorPlantName.trim().toUpperCase()) {
          matched = p;
          break;
        }
      }
      if (matched != null && matched.estimatedMonthlyGenerationKwh > 0) {
        totalKwh += matched.estimatedMonthlyGenerationKwh *
            (alloc.allocationPercent / 100.0);
      }
    }
    return totalKwh;
  }

  /// Retorna resumo textual de todas as usinas que enviam crédito para este cliente
  String get allPlantsSummaryLabel {
    final list = effectivePlantAllocations;
    if (list.length == 1) {
      final first = list.first;
      return '${first.generatorPlantName} (${first.generatorRegime.shortLabel})';
    }
    return list
        .map(
          (a) =>
              '${a.generatorPlantName} (${a.generatorRegime.shortLabel}: ${a.allocationPercent.toStringAsFixed(0)}%)',
        )
        .join(' + ');
  }

  /// Retorna apenas os dígitos da UC para comparação exata (ex: "2.024.081.017-07" -> "202408101707")
  String get normalizedUcDigits =>
      ucNumber.replaceAll(RegExp(r'[^0-9]'), '');

  /// Endereço resumido formatado
  String get fullAddressSummary {
    final parts = <String>[];
    if (addressStreet.trim().isNotEmpty) parts.add(addressStreet.trim());
    if (addressNeighborhood.trim().isNotEmpty) {
      parts.add(addressNeighborhood.trim());
    }
    if (addressCity.trim().isNotEmpty) {
      parts.add('${addressCity.trim()}/${addressState.trim()}');
    }
    return parts.join(' • ');
  }

  factory SolarCreditBeneficiaryModel.fromMap(
    Map<String, dynamic> map,
    String id,
  ) {
    final rawAllocations = map['plantAllocations'] as List<dynamic>? ?? [];
    final parsedAllocations = rawAllocations
        .whereType<Map>()
        .map(
          (e) => BeneficiaryPlantAllocationItem.fromMap(
            Map<String, dynamic>.from(e),
          ),
        )
        .toList();

    final primaryPlantId = map['generatorPlantId'] as String? ??
        (parsedAllocations.isNotEmpty
            ? parsedAllocations.first.generatorPlantId
            : '');
    final primaryPlantName = map['generatorPlantName'] as String? ??
        (parsedAllocations.isNotEmpty
            ? parsedAllocations.first.generatorPlantName
            : '');
    final primaryRegime = map['generatorRegime'] != null
        ? GdRegime.fromString(map['generatorRegime'] as String?)
        : (parsedAllocations.isNotEmpty
            ? parsedAllocations.first.generatorRegime
            : GdRegime.gd2);
    final primaryPct = _normalizePercent(
      (map['utilityAllocationPercent'] as num?)?.toDouble() ??
          (parsedAllocations.isNotEmpty
              ? parsedAllocations.first.allocationPercent
              : 0.0),
    );

    final effectiveAllocations = parsedAllocations.isNotEmpty
        ? parsedAllocations
        : [
            BeneficiaryPlantAllocationItem(
              generatorPlantId: primaryPlantId,
              generatorPlantName: primaryPlantName,
              generatorRegime: primaryRegime,
              allocationPercent: primaryPct,
            ),
          ];

    return SolarCreditBeneficiaryModel(
      id: id,
      companyId: map['companyId'] as String? ?? '',
      clientName: map['clientName'] as String? ?? '',
      clientPhone: map['clientPhone'] as String? ?? '',
      clientDocument: map['clientDocument'] as String? ?? '',
      accountHolderName: map['accountHolderName'] as String? ?? '',
      accountHolderDocument: map['accountHolderDocument'] as String? ?? '',
      ucNumber: map['ucNumber'] as String? ?? '',
      addressStreet: map['addressStreet'] as String? ?? '',
      addressNeighborhood: map['addressNeighborhood'] as String? ?? '',
      addressCity: map['addressCity'] as String? ?? 'Cuiabá',
      addressState: map['addressState'] as String? ?? 'MT',
      addressZipCode: map['addressZipCode'] as String? ?? '',
      connectionType: map['connectionType'] as String? ?? 'Trifásico',
      generatorPlantId: primaryPlantId,
      generatorPlantName: primaryPlantName,
      generatorRegime: primaryRegime,
      utilityAllocationPercent: primaryPct,
      plantAllocations: effectiveAllocations,
      clientDiscountPercent: _normalizePercent(
        (map['clientDiscountPercent'] as num?)?.toDouble() ?? 20.0,
      ),
      averageMonthlyConsumptionKwh:
          (map['averageMonthlyConsumptionKwh'] as num?)?.toDouble() ?? 0.0,
      lastAccumulatedBalanceKwh:
          (map['lastAccumulatedBalanceKwh'] as num?)?.toDouble() ?? 0.0,
      lastInjectedKwh: (map['lastInjectedKwh'] as num?)?.toDouble() ?? 0.0,
      lastReferenceMonth: map['lastReferenceMonth'] as String?,
      status: map['status'] as String? ?? 'active',
      notes: map['notes'] as String?,
      createdAt: _parseDate(map['createdAt']),
      updatedAt: _parseDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    final allocs = effectivePlantAllocations;
    return {
      'companyId': companyId,
      'clientName': clientName,
      'clientPhone': clientPhone,
      'clientDocument': clientDocument,
      'accountHolderName': accountHolderName,
      'accountHolderDocument': accountHolderDocument,
      'ucNumber': ucNumber,
      'normalizedUcDigits': normalizedUcDigits,
      'addressStreet': addressStreet,
      'addressNeighborhood': addressNeighborhood,
      'addressCity': addressCity,
      'addressState': addressState,
      'addressZipCode': addressZipCode,
      'connectionType': connectionType,
      'generatorPlantId': allocs.first.generatorPlantId,
      'generatorPlantName': allocs.first.generatorPlantName,
      'generatorRegime': allocs.first.generatorRegime.name,
      'utilityAllocationPercent': allocs.first.allocationPercent,
      'plantAllocations': allocs.map((e) => e.toMap()).toList(),
      'clientDiscountPercent': clientDiscountPercent,
      'averageMonthlyConsumptionKwh': averageMonthlyConsumptionKwh,
      'lastAccumulatedBalanceKwh': lastAccumulatedBalanceKwh,
      'lastInjectedKwh': lastInjectedKwh,
      'lastReferenceMonth': lastReferenceMonth,
      'status': status,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  SolarCreditBeneficiaryModel copyWith({
    String? id,
    String? companyId,
    String? clientName,
    String? clientPhone,
    String? clientDocument,
    String? accountHolderName,
    String? accountHolderDocument,
    String? ucNumber,
    String? addressStreet,
    String? addressNeighborhood,
    String? addressCity,
    String? addressState,
    String? addressZipCode,
    String? connectionType,
    String? generatorPlantId,
    String? generatorPlantName,
    GdRegime? generatorRegime,
    double? utilityAllocationPercent,
    List<BeneficiaryPlantAllocationItem>? plantAllocations,
    double? clientDiscountPercent,
    double? averageMonthlyConsumptionKwh,
    double? lastAccumulatedBalanceKwh,
    double? lastInjectedKwh,
    String? lastReferenceMonth,
    String? status,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SolarCreditBeneficiaryModel(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      clientName: clientName ?? this.clientName,
      clientPhone: clientPhone ?? this.clientPhone,
      clientDocument: clientDocument ?? this.clientDocument,
      accountHolderName: accountHolderName ?? this.accountHolderName,
      accountHolderDocument:
          accountHolderDocument ?? this.accountHolderDocument,
      ucNumber: ucNumber ?? this.ucNumber,
      addressStreet: addressStreet ?? this.addressStreet,
      addressNeighborhood: addressNeighborhood ?? this.addressNeighborhood,
      addressCity: addressCity ?? this.addressCity,
      addressState: addressState ?? this.addressState,
      addressZipCode: addressZipCode ?? this.addressZipCode,
      connectionType: connectionType ?? this.connectionType,
      generatorPlantId: generatorPlantId ?? this.generatorPlantId,
      generatorPlantName: generatorPlantName ?? this.generatorPlantName,
      generatorRegime: generatorRegime ?? this.generatorRegime,
      utilityAllocationPercent:
          utilityAllocationPercent ?? this.utilityAllocationPercent,
      plantAllocations: plantAllocations ?? this.plantAllocations,
      clientDiscountPercent:
          clientDiscountPercent ?? this.clientDiscountPercent,
      averageMonthlyConsumptionKwh:
          averageMonthlyConsumptionKwh ?? this.averageMonthlyConsumptionKwh,
      lastAccumulatedBalanceKwh:
          lastAccumulatedBalanceKwh ?? this.lastAccumulatedBalanceKwh,
      lastInjectedKwh: lastInjectedKwh ?? this.lastInjectedKwh,
      lastReferenceMonth: lastReferenceMonth ?? this.lastReferenceMonth,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Item individual de linha de "Energia Atv Injetada" na fatura da concessionária
class InjectedEnergyLineItem {
  final String description; // Ex: Energia Atv Injetada GDI oUC 10/2026 mPT
  final String regime; // 'GDI' ou 'GDII'
  final String originType; // 'oUC' (outra UC) ou 'mUC' (mesma UC)
  final String referencePeriod; // Ex: 10/2026, 10/2025, 11/2025
  final double quantityKwh; // Ex: 214.0, 492.0
  final double unitPriceWithTaxes; // Ex: 1.194080
  final double totalValueRs; // Valor em R$ positivo (ex: 255.53, 587.49)

  const InjectedEnergyLineItem({
    required this.description,
    this.regime = 'GDII',
    this.originType = 'oUC',
    this.referencePeriod = '',
    required this.quantityKwh,
    this.unitPriceWithTaxes = 0.0,
    required this.totalValueRs,
  });

  bool get isGdi =>
      regime.toUpperCase() == 'GDI' ||
      regime.toUpperCase() == 'GD1' ||
      (!description.toUpperCase().contains('GDII') &&
          !description.toUpperCase().contains('GD2') &&
          (description.toUpperCase().contains('GDI') ||
              description.toUpperCase().contains('GD1')));

  factory InjectedEnergyLineItem.fromMap(Map<String, dynamic> map) {
    final rawVal = (map['totalValueRs'] as num?)?.toDouble() ?? 0.0;
    return InjectedEnergyLineItem(
      description: map['description'] as String? ?? 'Energia Atv Injetada',
      regime: map['regime'] as String? ?? 'GDII',
      originType: map['originType'] as String? ?? 'oUC',
      referencePeriod: map['referencePeriod'] as String? ?? '',
      quantityKwh: ((map['quantityKwh'] as num?)?.toDouble() ?? 0.0).abs(),
      unitPriceWithTaxes:
          ((map['unitPriceWithTaxes'] as num?)?.toDouble() ?? 0.0).abs(),
      totalValueRs: rawVal.abs(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'description': description,
      'regime': regime,
      'originType': originType,
      'referencePeriod': referencePeriod,
      'quantityKwh': quantityKwh,
      'unitPriceWithTaxes': unitPriceWithTaxes,
      'totalValueRs': totalValueRs,
    };
  }
}

/// Item do histórico de consumo de 13 meses da fatura
class MonthlyConsumptionHistoryItem {
  final String monthYear; // Ex: OUT/26
  final double consumptionKwh; // Ex: 1472.0
  final int billingDays; // Ex: 32

  const MonthlyConsumptionHistoryItem({
    required this.monthYear,
    required this.consumptionKwh,
    this.billingDays = 30,
  });

  factory MonthlyConsumptionHistoryItem.fromMap(Map<String, dynamic> map) {
    return MonthlyConsumptionHistoryItem(
      monthYear:
          (map['monthYear'] ?? map['month'] ?? '').toString().trim(),
      consumptionKwh:
          (map['consumptionKwh'] as num?)?.toDouble() ?? 0.0,
      billingDays: (map['billingDays'] as num?)?.toInt() ?? 30,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'monthYear': monthYear,
      'consumptionKwh': consumptionKwh,
      'billingDays': billingDays,
    };
  }
}

/// Modelo Completo de Lançamento Mensal de Conta de Energia & Boleto/Demonstrativo Solar
class SolarCreditBillModel {
  final String id;
  final String companyId;
  final String beneficiaryId;
  final String clientName;
  final String clientPhone;
  final String accountHolderName;
  final String ucNumber;
  final String addressStreet;
  final String addressFull;
  final String generatorPlantId;
  final String generatorPlantName;
  final GdRegime generatorRegime;
  final double utilityAllocationPercent; // % na concessionária
  final double clientDiscountPercent; // % de deságio dado ao cliente

  // Datas e Referência
  final String referenceMonth; // Ex: Outubro / 2026
  final String dueDate; // Ex: 03/11/2026
  final String? promisedPaymentDate; // Nova data combinada somente para esta fatura (dd/MM/yyyy)
  final String? lastPushAlertDate; // Controle de envio diário de push (yyyy-MM-dd)
  final String? readingPreviousDate; // Ex: 18/09/2026
  final String? readingCurrentDate; // Ex: 20/10/2026
  final int billingDays; // Ex: 32

  // 1. Consumo Faturado
  final double consumptionKwh; // Ex: 1472.0
  final double consumptionUnitTariff; // Ex: 1.194080
  final double consumptionValueRs; // Ex: 1757.70

  // 2. Energia Injetada (Explodida e Somada)
  final List<InjectedEnergyLineItem> injectedLines;
  final double injectedGdiKwh; // Ex: 446.0
  final double injectedGdiValueRs; // Ex: 532.55
  final double injectedGdiiKwh; // Ex: 1026.0
  final double injectedGdiiValueRs; // Ex: 1225.13
  final double totalInjectedKwh; // Ex: 1472.0
  final double totalInjectedGrossValueRs; // Ex: 1757.68

  // 3. Ajuste GDII (Lei 14.300/22)
  final double gdAdjustmentKwh; // Ex: 1026.0
  final double gdAdjustmentTariff; // Ex: 0.189080
  final double gdAdjustmentValueRs; // Ex: 194.00

  // 4. Outros Lançamentos da Conta Energisa
  final double publicLightingValueRs; // Contrib de Ilum Pub (ex: 64.30)
  final double finesAndInterestValueRs; // Multa + Juros (ex: 3.94)
  final double otherChargesValueRs; // Outros encargos
  final double utilityBillTotalToPayRs; // Total a pagar na conta Energisa (ex: 262.26)

  // 5. Rodapé / Quadro Atenção (Página 2)
  final double accumulatedBalanceKwh; // Saldo Acumulado (ex: 4160.0)
  final double expiringNextCycleKwh; // A expirar no próximo ciclo (ex: 0.0)
  final String ucGdClassification; // Ex: GD_II, conforme Lei 14.300/22
  final List<MonthlyConsumptionHistoryItem> consumptionHistory;

  // 6. Fechamento Financeiro (Demonstrativo / Boleto do Cliente - Opção A)
  final double netCompensatedCreditRs; // Injetada Total - Ajuste GD (ex: 1563.68)
  final double solarCompanyAmountToPayRs; // Valor a pagar para Solar 7 (ex: 1250.94)
  final double totalWithSolarCompanyRs; // Solar 7 + Energisa (ex: 1513.20)
  final double totalWithoutSolarCompanyRs; // Valor final sem Solar 7 (ex: 1825.94)
  final double monthlySavingsRs; // Economia no mês (ex: 312.74)
  final double annualProjectedSavingsRs; // Economia anual projetada (ex: 3752.88)

  // 7. Dados Opcionais de Pagamento no Boleto PDF
  final String? qrCodeImageBase64; // Imagem do QR Code enviada pelo operador
  final String? pixCopyPasteCode; // Código PIX Copia e Cola ou Chave PIX
  final String? paymentLinkUrl; // Link clicável para pagamento
  final String paymentStatus; // 'pending' | 'paid'
  final String? notes;

  final DateTime createdAt;
  final DateTime updatedAt;

  const SolarCreditBillModel({
    required this.id,
    required this.companyId,
    required this.beneficiaryId,
    required this.clientName,
    this.clientPhone = '',
    required this.accountHolderName,
    required this.ucNumber,
    required this.addressStreet,
    this.addressFull = '',
    required this.generatorPlantId,
    required this.generatorPlantName,
    this.generatorRegime = GdRegime.gd2,
    required this.utilityAllocationPercent,
    required this.clientDiscountPercent,
    required this.referenceMonth,
    required this.dueDate,
    this.promisedPaymentDate,
    this.lastPushAlertDate,
    this.readingPreviousDate,
    this.readingCurrentDate,
    this.billingDays = 30,
    required this.consumptionKwh,
    this.consumptionUnitTariff = 0.0,
    required this.consumptionValueRs,
    this.injectedLines = const [],
    this.injectedGdiKwh = 0.0,
    this.injectedGdiValueRs = 0.0,
    this.injectedGdiiKwh = 0.0,
    this.injectedGdiiValueRs = 0.0,
    required this.totalInjectedKwh,
    required this.totalInjectedGrossValueRs,
    this.gdAdjustmentKwh = 0.0,
    this.gdAdjustmentTariff = 0.0,
    this.gdAdjustmentValueRs = 0.0,
    this.publicLightingValueRs = 0.0,
    this.finesAndInterestValueRs = 0.0,
    this.otherChargesValueRs = 0.0,
    required this.utilityBillTotalToPayRs,
    this.accumulatedBalanceKwh = 0.0,
    this.expiringNextCycleKwh = 0.0,
    this.ucGdClassification = '',
    this.consumptionHistory = const [],
    required this.netCompensatedCreditRs,
    required this.solarCompanyAmountToPayRs,
    required this.totalWithSolarCompanyRs,
    required this.totalWithoutSolarCompanyRs,
    required this.monthlySavingsRs,
    required this.annualProjectedSavingsRs,
    this.qrCodeImageBase64,
    this.pixCopyPasteCode,
    this.paymentLinkUrl,
    this.paymentStatus = 'pending',
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SolarCreditBillModel.fromMap(Map<String, dynamic> map, String id) {
    final rawLines = map['injectedLines'] as List<dynamic>? ?? [];
    final rawHist = map['consumptionHistory'] as List<dynamic>? ?? [];

    return SolarCreditBillModel(
      id: id,
      companyId: map['companyId'] as String? ?? '',
      beneficiaryId: map['beneficiaryId'] as String? ?? '',
      clientName: map['clientName'] as String? ?? '',
      clientPhone: map['clientPhone'] as String? ?? '',
      accountHolderName: map['accountHolderName'] as String? ?? '',
      ucNumber: map['ucNumber'] as String? ?? '',
      addressStreet: map['addressStreet'] as String? ?? '',
      addressFull: map['addressFull'] as String? ?? '',
      generatorPlantId: map['generatorPlantId'] as String? ?? '',
      generatorPlantName: map['generatorPlantName'] as String? ?? '',
      generatorRegime: GdRegime.fromString(map['generatorRegime'] as String?),
      utilityAllocationPercent: _normalizePercent(
        (map['utilityAllocationPercent'] as num?)?.toDouble() ?? 0.0,
      ),
      clientDiscountPercent: _normalizePercent(
        (map['clientDiscountPercent'] as num?)?.toDouble() ?? 20.0,
      ),
      referenceMonth: map['referenceMonth'] as String? ?? '',
      dueDate: map['dueDate'] as String? ?? '',
      promisedPaymentDate: map['promisedPaymentDate'] as String?,
      lastPushAlertDate: map['lastPushAlertDate'] as String?,
      readingPreviousDate: map['readingPreviousDate'] as String?,
      readingCurrentDate: map['readingCurrentDate'] as String?,
      billingDays: (map['billingDays'] as num?)?.toInt() ?? 30,
      consumptionKwh: (map['consumptionKwh'] as num?)?.toDouble() ?? 0.0,
      consumptionUnitTariff:
          (map['consumptionUnitTariff'] as num?)?.toDouble() ?? 0.0,
      consumptionValueRs:
          (map['consumptionValueRs'] as num?)?.toDouble() ?? 0.0,
      injectedLines: rawLines
          .whereType<Map>()
          .map((e) => InjectedEnergyLineItem.fromMap(
                Map<String, dynamic>.from(e),
              ))
          .toList(),
      injectedGdiKwh: (map['injectedGdiKwh'] as num?)?.toDouble() ?? 0.0,
      injectedGdiValueRs:
          (map['injectedGdiValueRs'] as num?)?.toDouble() ?? 0.0,
      injectedGdiiKwh: (map['injectedGdiiKwh'] as num?)?.toDouble() ?? 0.0,
      injectedGdiiValueRs:
          (map['injectedGdiiValueRs'] as num?)?.toDouble() ?? 0.0,
      totalInjectedKwh: (map['totalInjectedKwh'] as num?)?.toDouble() ?? 0.0,
      totalInjectedGrossValueRs:
          (map['totalInjectedGrossValueRs'] as num?)?.toDouble() ?? 0.0,
      gdAdjustmentKwh: (map['gdAdjustmentKwh'] as num?)?.toDouble() ?? 0.0,
      gdAdjustmentTariff:
          (map['gdAdjustmentTariff'] as num?)?.toDouble() ?? 0.0,
      gdAdjustmentValueRs:
          (map['gdAdjustmentValueRs'] as num?)?.toDouble() ?? 0.0,
      publicLightingValueRs:
          (map['publicLightingValueRs'] as num?)?.toDouble() ?? 0.0,
      finesAndInterestValueRs:
          (map['finesAndInterestValueRs'] as num?)?.toDouble() ?? 0.0,
      otherChargesValueRs:
          (map['otherChargesValueRs'] as num?)?.toDouble() ?? 0.0,
      utilityBillTotalToPayRs:
          (map['utilityBillTotalToPayRs'] as num?)?.toDouble() ?? 0.0,
      accumulatedBalanceKwh:
          (map['accumulatedBalanceKwh'] as num?)?.toDouble() ?? 0.0,
      expiringNextCycleKwh:
          (map['expiringNextCycleKwh'] as num?)?.toDouble() ?? 0.0,
      ucGdClassification: map['ucGdClassification'] as String? ?? '',
      consumptionHistory: rawHist
          .whereType<Map>()
          .map((e) => MonthlyConsumptionHistoryItem.fromMap(
                Map<String, dynamic>.from(e),
              ))
          .toList(),
      netCompensatedCreditRs:
          (map['netCompensatedCreditRs'] as num?)?.toDouble() ?? 0.0,
      solarCompanyAmountToPayRs:
          (map['solarCompanyAmountToPayRs'] as num?)?.toDouble() ?? 0.0,
      totalWithSolarCompanyRs:
          (map['totalWithSolarCompanyRs'] as num?)?.toDouble() ?? 0.0,
      totalWithoutSolarCompanyRs:
          (map['totalWithoutSolarCompanyRs'] as num?)?.toDouble() ?? 0.0,
      monthlySavingsRs: (map['monthlySavingsRs'] as num?)?.toDouble() ?? 0.0,
      annualProjectedSavingsRs:
          (map['annualProjectedSavingsRs'] as num?)?.toDouble() ?? 0.0,
      qrCodeImageBase64: map['qrCodeImageBase64'] as String?,
      pixCopyPasteCode: map['pixCopyPasteCode'] as String?,
      paymentLinkUrl: map['paymentLinkUrl'] as String?,
      paymentStatus: map['paymentStatus'] as String? ?? 'pending',
      notes: map['notes'] as String?,
      createdAt: _parseDate(map['createdAt']),
      updatedAt: _parseDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'companyId': companyId,
      'beneficiaryId': beneficiaryId,
      'clientName': clientName,
      'clientPhone': clientPhone,
      'accountHolderName': accountHolderName,
      'ucNumber': ucNumber,
      'addressStreet': addressStreet,
      'addressFull': addressFull,
      'generatorPlantId': generatorPlantId,
      'generatorPlantName': generatorPlantName,
      'generatorRegime': generatorRegime.name,
      'utilityAllocationPercent': utilityAllocationPercent,
      'clientDiscountPercent': clientDiscountPercent,
      'referenceMonth': referenceMonth,
      'dueDate': dueDate,
      if (promisedPaymentDate != null) 'promisedPaymentDate': promisedPaymentDate,
      if (lastPushAlertDate != null) 'lastPushAlertDate': lastPushAlertDate,
      'readingPreviousDate': readingPreviousDate,
      'readingCurrentDate': readingCurrentDate,
      'billingDays': billingDays,
      'consumptionKwh': consumptionKwh,
      'consumptionUnitTariff': consumptionUnitTariff,
      'consumptionValueRs': consumptionValueRs,
      'injectedLines': injectedLines.map((e) => e.toMap()).toList(),
      'injectedGdiKwh': injectedGdiKwh,
      'injectedGdiValueRs': injectedGdiValueRs,
      'injectedGdiiKwh': injectedGdiiKwh,
      'injectedGdiiValueRs': injectedGdiiValueRs,
      'totalInjectedKwh': totalInjectedKwh,
      'totalInjectedGrossValueRs': totalInjectedGrossValueRs,
      'gdAdjustmentKwh': gdAdjustmentKwh,
      'gdAdjustmentTariff': gdAdjustmentTariff,
      'gdAdjustmentValueRs': gdAdjustmentValueRs,
      'publicLightingValueRs': publicLightingValueRs,
      'finesAndInterestValueRs': finesAndInterestValueRs,
      'otherChargesValueRs': otherChargesValueRs,
      'utilityBillTotalToPayRs': utilityBillTotalToPayRs,
      'accumulatedBalanceKwh': accumulatedBalanceKwh,
      'expiringNextCycleKwh': expiringNextCycleKwh,
      'ucGdClassification': ucGdClassification,
      'consumptionHistory': consumptionHistory.map((e) => e.toMap()).toList(),
      'netCompensatedCreditRs': netCompensatedCreditRs,
      'solarCompanyAmountToPayRs': solarCompanyAmountToPayRs,
      'totalWithSolarCompanyRs': totalWithSolarCompanyRs,
      'totalWithoutSolarCompanyRs': totalWithoutSolarCompanyRs,
      'monthlySavingsRs': monthlySavingsRs,
      'annualProjectedSavingsRs': annualProjectedSavingsRs,
      'qrCodeImageBase64': qrCodeImageBase64,
      'pixCopyPasteCode': pixCopyPasteCode,
      'paymentLinkUrl': paymentLinkUrl,
      'paymentStatus': paymentStatus,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Data efetiva considerada para alerta (prioriza data combinada somente desta fatura)
  String get effectiveDueDateStr =>
      (promisedPaymentDate != null && promisedPaymentDate!.trim().isNotEmpty)
          ? promisedPaymentDate!.trim()
          : dueDate.trim();

  /// Converte `effectiveDueDateStr` (dd/MM/yyyy ou yyyy-MM-dd) para DateTime à meia-noite
  DateTime? get effectiveDueDate => parseBrOrIsoDate(effectiveDueDateStr);

  /// Dias restantes até o vencimento efetivo (negativo = vencida, 0 = vence hoje)
  int? get daysUntilDue {
    final target = effectiveDueDate;
    if (target == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(target.year, target.month, target.day);
    return dueDay.difference(today).inDays;
  }

  /// Retorna true se a fatura estiver pendente e faltar 10 dias ou menos (ou já vencida)
  bool get isDueWithinAlertWindow {
    if (paymentStatus.toLowerCase() == 'paid') return false;
    final days = daysUntilDue;
    return days != null && days <= 10;
  }

  static DateTime? parseBrOrIsoDate(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    final br = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{2,4})$').firstMatch(s);
    if (br != null) {
      final d = int.tryParse(br.group(1)!);
      final m = int.tryParse(br.group(2)!);
      var y = int.tryParse(br.group(3)!);
      if (d != null && m != null && y != null) {
        if (y < 100) y += 2000;
        if (m >= 1 && m <= 12 && d >= 1 && d <= 31) {
          return DateTime(y, m, d);
        }
      }
    }
    return DateTime.tryParse(s);
  }
}

DateTime _parseDate(dynamic val) {
  if (val is Timestamp) return val.toDate();
  if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
  return DateTime.now();
}

/// Normaliza porcentagens caso tenham sido salvas multiplicadas por 10 ou 100 por separador decimal
double _normalizePercent(double val) {
  double v = val.abs();
  while (v > 100.0) {
    v = v / 10.0;
  }
  return v;
}

