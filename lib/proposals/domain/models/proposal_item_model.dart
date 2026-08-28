import '../../../products/domain/models/product_model.dart';

/// Modelo de item / produto incluído na Proposta Comercial
class ProposalItemModel {
  final String? productId;
  final String name;
  final String? sku;
  final double quantity;
  final String unit;
  final double unitPrice;
  final double discountPercent;
  final double totalPrice;

  // ☀️ Propriedades exclusivas para Usinas Solares / Kits Fotovoltaicos
  final bool isSolarPlant;
  final String? solarRoofType;
  final double? solarKilowatts;
  final List<String>? solarComponents;
  final double? moduleWatts; // Potência em Watts se for módulo solar (ex: 550W)

  const ProposalItemModel({
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
  });

  /// Extrai a potência do módulo em Watts, seja do atributo explícito ou da descrição/nome (ex: "550W", "580 W", "670W", "500 Watts", "615W")
  double? get effectiveModuleWatts {
    if (moduleWatts != null && moduleWatts! > 0) {
      return moduleWatts;
    }
    // Tenta extrair do nome ou SKU: "550W", "550 W", "580w", "670 watts", "550wp", "615w"
    final text = '$name ${sku ?? ""}';
    final match = RegExp(r'(\d{3,4}(?:\.\d+)?)\s*(?:w|watts|wp)\b', caseSensitive: false).firstMatch(text);
    if (match != null) {
      return double.tryParse(match.group(1)!);
    }
    return null;
  }

  /// Verifica se o item é um módulo solar fotovoltaico
  bool get isSolarModule {
    final lower = '$name ${sku ?? ""}'.toLowerCase();

    // 1. Identificação prioritária por palavras-chave de módulo/painel
    if (lower.contains('módulo') ||
        lower.contains('modulo') ||
        lower.contains('painel') ||
        lower.contains('placa') ||
        lower.contains('bifacial') ||
        lower.contains('cel.') ||
        lower.contains('half-cell') ||
        lower.contains('n-type') ||
        lower.contains('monocristalino') ||
        lower.contains('policristalino')) {
      return true;
    }

    if (moduleWatts != null && moduleWatts! > 0) return true;

    // 2. Exclui inversores, baterias, estruturas e cabos isolados
    if (lower.contains('cabo') ||
        lower.contains('conector') ||
        lower.contains('estrutura') ||
        lower.contains('trilho') ||
        lower.contains('string')) {
      return false;
    }
    if (lower.contains('inversor') ||
        lower.contains('microinversor') ||
        lower.contains('bateria')) {
      return false;
    }

    return lower.contains('fotovoltaico');
  }

  /// Calcula o preço total considerando a quantidade e o percentual de desconto
  static double calculateTotal(double qty, double price, double discountPct) {
    final sub = qty * price;
    final disc = sub * (discountPct.clamp(0.0, 100.0) / 100.0);
    return (sub - disc).clamp(0.0, double.infinity);
  }

  ProposalItemModel copyWith({
    String? productId,
    String? name,
    String? sku,
    double? quantity,
    String? unit,
    double? unitPrice,
    double? discountPercent,
    double? totalPrice,
    bool? isSolarPlant,
    String? solarRoofType,
    double? solarKilowatts,
    List<String>? solarComponents,
    double? moduleWatts,
  }) {
    final newQty = quantity ?? this.quantity;
    final newPrice = unitPrice ?? this.unitPrice;
    final newDisc = discountPercent ?? this.discountPercent;
    return ProposalItemModel(
      productId: productId ?? this.productId,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      quantity: newQty,
      unit: unit ?? this.unit,
      unitPrice: newPrice,
      discountPercent: newDisc,
      totalPrice: totalPrice ?? calculateTotal(newQty, newPrice, newDisc),
      isSolarPlant: isSolarPlant ?? this.isSolarPlant,
      solarRoofType: solarRoofType ?? this.solarRoofType,
      solarKilowatts: solarKilowatts ?? this.solarKilowatts,
      solarComponents: solarComponents ?? this.solarComponents,
      moduleWatts: moduleWatts ?? this.moduleWatts,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'name': name,
      'sku': sku,
      'quantity': quantity,
      'unit': unit,
      'unitPrice': unitPrice,
      'discountPercent': discountPercent,
      'totalPrice': totalPrice,
      'isSolarPlant': isSolarPlant,
      'solarRoofType': solarRoofType,
      'solarKilowatts': solarKilowatts,
      'solarComponents': solarComponents,
      'moduleWatts': moduleWatts,
    };
  }

  factory ProposalItemModel.fromProduct(ProductModel p) {
    final isSolar = p.sector == ProductSector.solarPlant ||
        p.specificAttributes['isSolarPlantKit'] == true;

    List<String> components = [];
    String? roofType;
    double? kilowatts;
    double? modWatts;

    final attrs = p.specificAttributes;
    if (attrs['moduleWatts'] != null) {
      modWatts = (attrs['moduleWatts'] as num).toDouble();
    }

    if (isSolar) {
      roofType = attrs['roofType'] as String?;
      if (attrs['kilowatts'] != null) {
        kilowatts = (attrs['kilowatts'] as num).toDouble();
      }
      if (attrs['items'] is List) {
        final rawItems = attrs['items'] as List;
        for (final raw in rawItems) {
          if (raw is Map) {
            final name = raw['name'] as String? ?? 'Item';
            final qty = (raw['quantity'] as num?)?.toDouble() ?? 1.0;
            final unit = raw['unit'] as String? ?? 'UN';
            final qtyStr = qty % 1 == 0 ? qty.toInt().toString() : qty.toString();
            components.add('$qtyStr $unit - $name');
          }
        }
      }
      if (attrs['servicePrice'] != null && (attrs['servicePrice'] as num) > 0) {
        components.add('Serviço de Instalação, Homologação e Engenharia');
      }
      if (attrs['additionalServices'] is List) {
        final addServs = attrs['additionalServices'] as List;
        for (final asItem in addServs) {
          if (asItem is Map && (asItem['type'] as String? ?? '').isNotEmpty) {
            components.add('Serviço Extra: ${asItem['type']}');
          }
        }
      }
    }

    return ProposalItemModel(
      productId: p.id,
      name: p.name,
      sku: p.sku,
      quantity: 1.0,
      unit: p.unit.symbol,
      unitPrice: p.salePrice,
      totalPrice: p.salePrice,
      isSolarPlant: isSolar,
      solarRoofType: roofType,
      solarKilowatts: kilowatts,
      solarComponents: components.isNotEmpty ? components : null,
      moduleWatts: modWatts,
    );
  }

  factory ProposalItemModel.fromMap(Map<String, dynamic> map) {
    final qty = (map['quantity'] as num?)?.toDouble() ?? 1.0;
    final price = (map['unitPrice'] as num?)?.toDouble() ?? 0.0;
    final disc = (map['discountPercent'] as num?)?.toDouble() ?? 0.0;
    final tot = (map['totalPrice'] as num?)?.toDouble() ?? calculateTotal(qty, price, disc);

    List<String>? components;
    if (map['solarComponents'] is List) {
      components = (map['solarComponents'] as List).map((e) => e.toString()).toList();
    }

    return ProposalItemModel(
      productId: map['productId'] as String?,
      name: map['name'] as String? ?? 'Item sem descrição',
      sku: map['sku'] as String?,
      quantity: qty,
      unit: map['unit'] as String? ?? 'UN',
      unitPrice: price,
      discountPercent: disc,
      totalPrice: tot,
      isSolarPlant: map['isSolarPlant'] as bool? ?? false,
      solarRoofType: map['solarRoofType'] as String?,
      solarKilowatts: (map['solarKilowatts'] as num?)?.toDouble(),
      solarComponents: components,
      moduleWatts: (map['moduleWatts'] as num?)?.toDouble(),
    );
  }
}
