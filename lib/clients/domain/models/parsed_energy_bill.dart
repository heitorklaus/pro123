import 'client_model.dart';

/// Item de consumo mensal faturado extraído da conta de energia
class EnergyBillMonthlyConsumption {
  final String month; // Ex: 'JUN/26', 'MAI/26', '06/2026'
  final double consumptionKwh; // Consumo em kWh
  final int? billingDays; // Dias faturados (ex: 30)

  const EnergyBillMonthlyConsumption({
    required this.month,
    required this.consumptionKwh,
    this.billingDays,
  });

  factory EnergyBillMonthlyConsumption.fromJson(Map<String, dynamic> json) {
    return EnergyBillMonthlyConsumption(
      month: json['month'] as String? ?? '',
      consumptionKwh: (json['consumptionKwh'] as num?)?.toDouble() ?? 0.0,
      billingDays: json['billingDays'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'month': month,
      'consumptionKwh': consumptionKwh,
      'billingDays': billingDays,
    };
  }
}

/// Resultado completo da análise de conta de energia por IA Gemini
class ParsedEnergyBill {
  final String? clientName;
  final String? document; // CPF ou CNPJ
  final ClientType clientType;
  final String? email;
  final String? phone;

  // Endereço
  final String? zipCode;
  final String? street;
  final String? addressNumber;
  final String? complement;
  final String? neighborhood;
  final String? city;
  final String? state;

  // Dados Técnicos da Unidade Consumidora (UC)
  final String? utilityCompany; // Ex: Energisa, CPFL, Enel, Cemig, Copel
  final String? ucNumber; // Código da UC / Instalação / Matrícula
  final String? connectionType; // Monofásico, Bifásico, Trifásico
  final String? tariffGroup; // Ex: B1 Residencial, B3 Comercial, A4
  final double? currentBillAmount; // Valor da Fatura Atual (R$)
  final String? referenceMonth; // Mês de referência (ex: Junho / 2026)

  // Histórico de Consumo (kWh)
  final List<EnergyBillMonthlyConsumption> history;

  // Diagnóstico Solar Calculado
  final double averageMonthlyConsumptionKwh;
  final double suggestedSolarKwP;
  final double estimatedMonthlyGenerationKwh;
  final double estimatedMonthlySavings;

  const ParsedEnergyBill({
    this.clientName,
    this.document,
    this.clientType = ClientType.person,
    this.email,
    this.phone,
    this.zipCode,
    this.street,
    this.addressNumber,
    this.complement,
    this.neighborhood,
    this.city,
    this.state,
    this.utilityCompany,
    this.ucNumber,
    this.connectionType,
    this.tariffGroup,
    this.currentBillAmount,
    this.referenceMonth,
    this.history = const [],
    required this.averageMonthlyConsumptionKwh,
    required this.suggestedSolarKwP,
    required this.estimatedMonthlyGenerationKwh,
    required this.estimatedMonthlySavings,
  });

  factory ParsedEnergyBill.fromJson(Map<String, dynamic> json) {
    // 1. Extração do histórico de consumo
    final historyList = <EnergyBillMonthlyConsumption>[];
    if (json['history'] is List) {
      for (final item in json['history'] as List) {
        if (item is Map<String, dynamic>) {
          historyList.add(EnergyBillMonthlyConsumption.fromJson(item));
        }
      }
    }

    // 2. Média de Consumo (se não vier pronta, calcula a partir do histórico)
    double avgKwh = (json['averageMonthlyConsumptionKwh'] as num?)?.toDouble() ?? 0.0;
    if (avgKwh <= 0 && historyList.isNotEmpty) {
      final sum = historyList.fold(0.0, (acc, item) => acc + item.consumptionKwh);
      avgKwh = sum / historyList.length;
    }

    // Se ainda for 0 e houver consumo do mês atual
    if (avgKwh <= 0 && json['currentMonthKwh'] != null) {
      avgKwh = (json['currentMonthKwh'] as num).toDouble();
    }

    // 3. Dimensionamento Fotovoltaico (kWp)
    // Fator médio brasileiro de produtividade: ~110 a 115 kWh/mês por kWp instalado
    double suggestedKwP = (json['suggestedSolarKwP'] as num?)?.toDouble() ?? 0.0;
    if (suggestedKwP <= 0 && avgKwh > 0) {
      suggestedKwP = double.parse((avgKwh / 110.0).toStringAsFixed(2));
    }

    // 4. Geração Mensal Estimada
    double genKwh = (json['estimatedMonthlyGenerationKwh'] as num?)?.toDouble() ?? 0.0;
    if (genKwh <= 0 && suggestedKwP > 0) {
      genKwh = double.parse((suggestedKwP * 110.0).toStringAsFixed(1));
    }

    // 5. Economia Estimada em R$ (tarifa média R$ 0.95/kWh)
    double savings = (json['estimatedMonthlySavings'] as num?)?.toDouble() ?? 0.0;
    if (savings <= 0 && avgKwh > 0) {
      savings = double.parse((avgKwh * 0.92).toStringAsFixed(2));
    }

    // 6. Tipo de Cliente
    final doc = (json['document'] as String?)?.replaceAll(RegExp(r'\D'), '') ?? '';
    final rawType = (json['clientType'] as String?)?.toLowerCase();
    ClientType type = ClientType.person;
    if (rawType == 'company' || rawType == 'pj' || doc.length == 14) {
      type = ClientType.company;
    }

    return ParsedEnergyBill(
      clientName: json['clientName'] as String?,
      document: json['document'] as String?,
      clientType: type,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      zipCode: json['zipCode'] as String?,
      street: json['street'] as String?,
      addressNumber: json['addressNumber'] as String?,
      complement: json['complement'] as String?,
      neighborhood: json['neighborhood'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      utilityCompany: json['utilityCompany'] as String?,
      ucNumber: json['ucNumber'] as String?,
      connectionType: json['connectionType'] as String?,
      tariffGroup: json['tariffGroup'] as String?,
      currentBillAmount: (json['currentBillAmount'] as num?)?.toDouble(),
      referenceMonth: json['referenceMonth'] as String?,
      history: historyList,
      averageMonthlyConsumptionKwh: avgKwh,
      suggestedSolarKwP: suggestedKwP,
      estimatedMonthlyGenerationKwh: genKwh,
      estimatedMonthlySavings: savings,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'clientName': clientName,
      'document': document,
      'clientType': clientType.name,
      'email': email,
      'phone': phone,
      'zipCode': zipCode,
      'street': street,
      'addressNumber': addressNumber,
      'complement': complement,
      'neighborhood': neighborhood,
      'city': city,
      'state': state,
      'utilityCompany': utilityCompany,
      'ucNumber': ucNumber,
      'connectionType': connectionType,
      'tariffGroup': tariffGroup,
      'currentBillAmount': currentBillAmount,
      'referenceMonth': referenceMonth,
      'history': history.map((e) => e.toJson()).toList(),
      'averageMonthlyConsumptionKwh': averageMonthlyConsumptionKwh,
      'suggestedSolarKwP': suggestedSolarKwP,
      'estimatedMonthlyGenerationKwh': estimatedMonthlyGenerationKwh,
      'estimatedMonthlySavings': estimatedMonthlySavings,
    };
  }
}
