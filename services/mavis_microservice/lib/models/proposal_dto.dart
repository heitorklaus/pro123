class ProposalItemDTO {
  final String? productId;
  final String name;
  final String? sku;
  final double quantity;
  final String unit;
  final double unitPrice;
  final double discountPercent;
  final double totalPrice;
  final bool isSolarPlant;
  final String? solarRoofType;
  final double? solarKilowatts;
  final List<String>? solarComponents;
  final double? moduleWatts;
  final double? estimatedMonthlyKwh;

  const ProposalItemDTO({
    this.productId,
    required this.name,
    this.sku,
    this.quantity = 1.0,
    this.unit = 'UN',
    required this.unitPrice,
    this.discountPercent = 0.0,
    required this.totalPrice,
    this.isSolarPlant = false,
    this.solarRoofType,
    this.solarKilowatts,
    this.solarComponents,
    this.moduleWatts,
    this.estimatedMonthlyKwh,
  });

  double? get effectiveModuleWatts {
    if (moduleWatts != null && moduleWatts! > 0) return moduleWatts;
    final text = '$name ${sku ?? ""}';
    final match = RegExp(r'(\d{3,4}(?:\.\d+)?)\s*(?:w|watts|wp)\b', caseSensitive: false).firstMatch(text);
    if (match != null) return double.tryParse(match.group(1)!);
    return null;
  }

  factory ProposalItemDTO.fromMap(Map<String, dynamic> map) {
    List<String>? components;
    if (map['solarComponents'] != null) {
      components = (map['solarComponents'] as List).map((e) => e.toString()).toList();
    } else if (map['specificAttributes'] != null && map['specificAttributes']['solarComponents'] != null) {
      components = (map['specificAttributes']['solarComponents'] as List).map((e) => e.toString()).toList();
    }

    final isPlant = map['isSolarPlant'] == true ||
        (map['specificAttributes'] != null && map['specificAttributes']['isSolarPlant'] == true);

    final kw = (map['solarKilowatts'] as num?)?.toDouble() ??
        (map['specificAttributes'] != null ? (map['specificAttributes']['solarPlantKwp'] as num?)?.toDouble() : null);

    final roof = (map['solarRoofType'] as String?) ??
        (map['specificAttributes'] != null ? map['specificAttributes']['roofType'] as String? : null);

    final watts = (map['moduleWatts'] as num?)?.toDouble() ??
        (map['specificAttributes'] != null ? (map['specificAttributes']['moduleWatts'] as num?)?.toDouble() : null);

    final kwh = (map['estimatedMonthlyKwh'] as num?)?.toDouble() ??
        (map['monthlyKwh'] as num?)?.toDouble() ??
        (map['specificAttributes'] != null ? (map['specificAttributes']['estimatedMonthlyKwh'] as num?)?.toDouble() : null);

    return ProposalItemDTO(
      productId: map['productId']?.toString(),
      name: map['name']?.toString() ?? map['title']?.toString() ?? 'Item',
      sku: map['sku']?.toString(),
      quantity: (map['quantity'] as num?)?.toDouble() ?? 1.0,
      unit: map['unit']?.toString() ?? 'UN',
      unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? (map['total'] as num?)?.toDouble() ?? 0.0,
      discountPercent: (map['discountPercent'] as num?)?.toDouble() ?? 0.0,
      totalPrice: (map['totalPrice'] as num?)?.toDouble() ?? (map['total'] as num?)?.toDouble() ?? 0.0,
      isSolarPlant: isPlant,
      solarRoofType: roof,
      solarKilowatts: kw,
      solarComponents: components,
      moduleWatts: watts,
      estimatedMonthlyKwh: kwh,
    );
  }

}

class ProposalDTO {
  final String id;
  final String proposalNumber;
  final String title;
  final String? clientId;
  final String clientName;
  final String? clientEmail;
  final String? clientPhone;
  final String? clientDocument;
  final String? clientAddress;
  final List<ProposalItemDTO> items;
  final double subtotal;
  final double discount;
  final double shippingFee;
  final double totalAmount;
  final String paymentTerms;
  final int validityDays;
  final String? deliveryTime;
  final String? notes;
  final int themeColorValue;
  final String status;
  final String? companyId;
  final String? createdByUserId;
  final String? createdByUserName;
  final String? pdfUrl;
  final String? pdfPath;
  final DateTime createdAt;

  const ProposalDTO({
    required this.id,
    required this.proposalNumber,
    required this.title,
    this.clientId,
    required this.clientName,
    this.clientEmail,
    this.clientPhone,
    this.clientDocument,
    this.clientAddress,
    this.items = const [],
    required this.subtotal,
    this.discount = 0.0,
    this.shippingFee = 0.0,
    required this.totalAmount,
    this.paymentTerms = 'À vista via PIX',
    this.validityDays = 15,
    this.deliveryTime,
    this.notes,
    this.themeColorValue = 0xFF0284C7,
    this.status = 'inApproval',
    this.companyId,
    this.createdByUserId,
    this.createdByUserName,
    this.pdfUrl,
    this.pdfPath,
    required this.createdAt,
  });

  factory ProposalDTO.fromMap(Map<String, dynamic> map, [String? id]) {
    final rawItems = map['items'] as List<dynamic>? ?? [];
    final itemsList = rawItems
        .map((item) => ProposalItemDTO.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();

    DateTime parseDate(dynamic val) {
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      if (val is Map && val['_seconds'] != null) {
        return DateTime.fromMillisecondsSinceEpoch(val['_seconds'] * 1000);
      }
      return DateTime.now();
    }

    return ProposalDTO(
      id: id ?? map['id']?.toString() ?? '',
      proposalNumber: map['proposalNumber']?.toString() ?? 'PROP-2026-001',
      title: map['title']?.toString() ?? 'Proposta Comercial Usina Solar',
      clientId: map['clientId']?.toString(),
      clientName: map['clientName']?.toString() ?? 'Consumidor Final',
      clientEmail: map['clientEmail']?.toString(),
      clientPhone: map['clientPhone']?.toString(),
      clientDocument: map['clientDocument']?.toString(),
      clientAddress: map['clientAddress']?.toString(),
      items: itemsList,
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      shippingFee: (map['shippingFee'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      paymentTerms: map['paymentTerms']?.toString() ?? 'À vista via PIX (5% desc) ou Financiamento Solar',
      validityDays: (map['validityDays'] as num?)?.toInt() ?? 15,
      deliveryTime: map['deliveryTime']?.toString() ?? 'Imediata / 3 a 5 dias úteis',
      notes: map['notes']?.toString(),
      themeColorValue: (map['themeColorValue'] as num?)?.toInt() ?? 0xFF0284C7,
      status: map['status']?.toString() ?? 'inApproval',
      companyId: map['companyId']?.toString(),
      createdByUserId: map['createdByUserId']?.toString(),
      createdByUserName: map['createdByUserName']?.toString(),
      pdfUrl: map['pdfUrl']?.toString(),
      pdfPath: map['pdfPath']?.toString(),
      createdAt: parseDate(map['createdAt']),
    );
  }
}
