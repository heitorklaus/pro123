import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 20 SEGMENTOS COMERCIAIS MAIS COMUNS DO BRASIL (Baseados em CNAEs/Atividades)
// ─────────────────────────────────────────────────────────────────────────────
enum ProductSector {
  solarPlant('Usina Solar', 'Inversor, Placa Solar, Estrutura e acessórios', Icons.solar_power_rounded, Color(0xFFF59E0B)),
  cleaning('Produtos de Limpeza & Higiene', 'Detergentes, desinfetantes, saneantes e químicos', Icons.cleaning_services_rounded, Color(0xFF0284C7)),
  food('Alimentos, Bebidas & Mercearia', 'Alimentos, refrigerantes, grãos e produtos perecíveis', Icons.restaurant_rounded, Color(0xFFEA580C)),
  fashion('Vestuário, Calçados & Moda', 'Roupas, calçados, bolsas e acessórios de moda', Icons.checkroom_rounded, Color(0xFF8B5CF6)),
  construction('Material de Construção & Reforma', 'Tintas, pisos, ferramentas, hidráulica e elétrica', Icons.handyman_rounded, Color(0xFFD97706)),
  pharmacy('Farmácia, Cosméticos & Cuidados', 'Medicamentos, perfumaria, skincare e higiene pessoal', Icons.local_pharmacy_rounded, Color(0xFF059669)),
  tech('Informática, Eletrônicos & Telefonia', 'Computadores, smartphones, periféricos e cabos', Icons.computer_rounded, Color(0xFF2563EB)),
  autoparts('Autopeças, Moto & Acessórios', 'Peças mecânicas, óleos, baterias e pneus', Icons.directions_car_rounded, Color(0xFF475569)),
  stationery('Papelaria, Livraria & Escritório', 'Cadernos, materiais de escritório, tintas e presentes', Icons.edit_note_rounded, Color(0xFF7C3AED)),
  pet('Pet Shop & Agropecuária', 'Rações, medicamentos veterinários, sementes e insumos', Icons.pets_rounded, Color(0xFF16A34A)),
  furniture('Móveis, Decoração & Casa', 'Móveis, luminárias, cortinas e utilidades do lar', Icons.chair_rounded, Color(0xFFB45309)),
  restaurant('Restaurantes, Bares & Delivery', 'Pratos prontos, lanches, porções e marmitex', Icons.fastfood_rounded, Color(0xFFDC2626)),
  generalServices('Prestação de Serviços Gerais', 'Consultorias, manutenções, facilities e suporte', Icons.business_center_rounded, Color(0xFF0D9488)),
  healthServices('Saúde, Clínicas & Estética', 'Consultas, exames, procedimentos e tratamentos', Icons.medical_services_rounded, Color(0xFFE11D48)),
  education('Educação, Cursos & Treinamentos', 'Cursos presenciais/EAD, workshops e mentorias', Icons.school_rounded, Color(0xFF4F46E5)),
  mechanic('Oficina Mecânica & Manutenção Auto', 'Mão de obra mecânica, alinhamento e revisão', Icons.build_rounded, Color(0xFF334155)),
  printing('Gráfica & Comunicação Visual', 'Banners, cartões de visita, impressões e brindes', Icons.print_rounded, Color(0xFF9333EA)),
  optics('Óticas & Acessórios Visuais', 'Armações, lentes de grau, óculos de sol e estojos', Icons.visibility_rounded, Color(0xFF0891B2)),
  toys('Brinquedos, Presentes & Utilidades', 'Jogos, brinquedos infantis, variedades e lembranças', Icons.toys_rounded, Color(0xFFF59E0B)),
  gardening('Floricultura, Jardinagem & Plantas', 'Flores, vasos, terras, adubos e ferramentas de jardim', Icons.yard_rounded, Color(0xFF15803D)),
  industry('Indústria & Metalmecânica / Fabricação', 'Matérias-primas, insumos industriais e peças sob medida', Icons.precision_manufacturing_rounded, Color(0xFF4B5563));

  final String title;
  final String description;
  final IconData icon;
  final Color themeColor;

  const ProductSector(this.title, this.description, this.icon, this.themeColor);

  static ProductSector fromString(String? val) {
    if (val == null) return ProductSector.cleaning;
    return ProductSector.values.firstWhere(
      (s) => s.name == val,
      orElse: () => ProductSector.cleaning,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// UNIDADES DE MEDIDA COMERCIAIS
// ─────────────────────────────────────────────────────────────────────────────
enum ProductUnit {
  un('UN', 'Unidade'),
  cx('CX', 'Caixa'),
  kg('KG', 'Quilo'),
  g('G', 'Grama'),
  lt('LT', 'Litro'),
  ml('ML', 'Mililitro'),
  mt('MT', 'Metro'),
  m2('M²', 'Metro Quadrado'),
  par('PAR', 'Par'),
  pct('PCT', 'Pacote'),
  hr('HR', 'Hora (Serviço)'),
  sv('SV', 'Serviço');

  final String symbol;
  final String label;

  const ProductUnit(this.symbol, this.label);

  static ProductUnit fromString(String? val) {
    if (val == null) return ProductUnit.un;
    return ProductUnit.values.firstWhere(
      (u) => u.symbol == val || u.name == val,
      orElse: () => ProductUnit.un,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STATUS DO PRODUTO
// ─────────────────────────────────────────────────────────────────────────────
enum ProductStatus {
  active('Ativo', Color(0xFF059669), Color(0xFFD1FAE5)),
  inactive('Inativo', Color(0xFF64748B), Color(0xFFF1F5F9)),
  outOfStock('Sem Estoque', Color(0xFFDC2626), Color(0xFFFEF2F2));

  final String label;
  final Color textColor;
  final Color bgColor;

  const ProductStatus(this.label, this.textColor, this.bgColor);

  static ProductStatus fromString(String? val) {
    if (val == null) return ProductStatus.active;
    return ProductStatus.values.firstWhere(
      (s) => s.name == val,
      orElse: () => ProductStatus.active,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MODELO PRINCIPAL DO PRODUTO / SERVIÇO
// ─────────────────────────────────────────────────────────────────────────────
class ProductModel {
  final String id;
  final String name;
  final String? sku; // Código SKU interno
  final String? barcode; // Código de barras / EAN
  final ProductSector sector;
  final String? categoryTitle; // Título da categoria (para categorias customizadas ou exibição)
  final String? subcategory;
  final String? description;
  final String? supplierId; // ID do Fornecedor vinculado
  final String? supplierName; // Nome / Razão Social do Fornecedor para leitura rápida
  final double salePrice; // Preço de venda
  final double? costPrice; // Preço de custo
  final double stockQuantity; // Quantidade atual em estoque
  final double minStock; // Quantidade mínima para alerta
  final ProductUnit unit;
  final String? ncm; // Código Fiscal NCM (opcional)
  final ProductStatus status;
  final Map<String, dynamic> specificAttributes; // Atributos dinâmicos do segmento
  final String? companyId; // Multi-tenancy
  final DateTime createdAt;
  final DateTime updatedAt;

  ProductModel({
    required this.id,
    required this.name,
    this.sku,
    this.barcode,
    required this.sector,
    this.categoryTitle,
    this.subcategory,
    this.description,
    this.supplierId,
    this.supplierName,
    required this.salePrice,
    this.costPrice,
    this.stockQuantity = 0.0,
    this.minStock = 5.0,
    this.unit = ProductUnit.un,
    this.ncm,
    this.status = ProductStatus.active,
    this.specificAttributes = const {},
    this.companyId,
    required this.createdAt,
    required this.updatedAt,
  });

  String get displaySectorTitle => categoryTitle?.isNotEmpty == true ? categoryTitle! : sector.title;

  bool get isLowStock => stockQuantity <= minStock && stockQuantity > 0;
  bool get isOutOfStock => stockQuantity <= 0;
  
  double get profitMargin {
    if (costPrice == null || costPrice! <= 0) return 0;
    return ((salePrice - costPrice!) / salePrice) * 100;
  }

  // ☀️ Propriedades e Getters exclusivos para Usinas Solares e Kits
  bool get isSolarPlantKit {
    if (sector != ProductSector.solarPlant) return false;
    final attrs = specificAttributes;
    if (attrs['isSolarPlantKit'] == true || attrs['isSolarPlant'] == true) return true;
    if (attrs['items'] is List && (attrs['items'] as List).isNotEmpty) return true;
    if (attrs['solarComponents'] is List && (attrs['solarComponents'] as List).isNotEmpty) return true;
    if (attrs['kilowatts'] != null && ((attrs['kilowatts'] as num?) ?? 0) > 0) return true;
    if (attrs['solarPlantKwp'] != null && ((attrs['solarPlantKwp'] as num?) ?? 0) > 0) return true;
    if (name.toLowerCase().startsWith('usina solar')) return true;
    return false;
  }

  bool get isSolarComponent => sector == ProductSector.solarPlant && !isSolarPlantKit;

  List<Map<String, dynamic>> get solarKitItems {
    final raw = specificAttributes['items'];
    if (raw is List && raw.isNotEmpty) {
      return raw.map((e) {
        if (e is Map) return Map<String, dynamic>.from(e);
        return {'name': e.toString(), 'quantity': 1, 'unit': 'UN'};
      }).toList();
    }
    final comps = specificAttributes['solarComponents'];
    if (comps is List && comps.isNotEmpty) {
      return comps.map((e) {
        if (e is Map) return Map<String, dynamic>.from(e);
        return {'name': e.toString(), 'quantity': 1, 'unit': 'UN'};
      }).toList();
    }
    return [];
  }

  double? get solarKilowatts {
    final kw = specificAttributes['kilowatts'] ?? specificAttributes['solarPlantKwp'];
    if (kw is num) return kw.toDouble();
    final match = RegExp(r'(\d+(?:\.\d+)?)\s*kWp', caseSensitive: false).firstMatch(name);
    if (match != null) return double.tryParse(match.group(1)!);
    return null;
  }

  double? get solarGenerationKwh {
    final g = specificAttributes['generationKwh'] ?? specificAttributes['estimatedMonthlyKwh'];
    if (g is num) return g.toDouble();
    final match = RegExp(r'(\d+(?:\.\d+)?)\s*kWh', caseSensitive: false).firstMatch(name);
    if (match != null) return double.tryParse(match.group(1)!);
    return null;
  }

  String? get solarRoofType =>
      (specificAttributes['roofType'] ?? specificAttributes['solarRoofType']) as String?;

  double? get solarProductsPrice {
    final p = specificAttributes['productsPrice'] ?? specificAttributes['productsCostPrice'] ?? costPrice;
    if (p is num) return p.toDouble();
    return null;
  }

  double? get solarServicePrice {
    final s = specificAttributes['servicePrice'];
    if (s is num) return s.toDouble();
    return null;
  }

  List<Map<String, dynamic>> get solarAdditionalServices {
    final raw = specificAttributes['additionalServices'];
    if (raw is List) {
      return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }


  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'sku': sku,
      'barcode': barcode,
      'sector': sector.name,
      'categoryTitle': categoryTitle,
      'subcategory': subcategory,
      'description': description,
      'supplierId': supplierId,
      'supplierName': supplierName,
      'salePrice': salePrice,
      'costPrice': costPrice,
      'stockQuantity': stockQuantity,
      'minStock': minStock,
      'unit': unit.symbol,
      'ncm': ncm,
      'status': status.name,
      'specificAttributes': specificAttributes,
      'companyId': companyId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory ProductModel.fromMap(Map<String, dynamic> map, String id) {
    return ProductModel(
      id: id,
      name: map['name'] as String? ?? '',
      sku: map['sku'] as String?,
      barcode: map['barcode'] as String?,
      sector: ProductSector.fromString(map['sector'] as String?),
      categoryTitle: map['categoryTitle'] as String?,
      subcategory: map['subcategory'] as String?,
      description: map['description'] as String?,
      supplierId: map['supplierId'] as String?,
      supplierName: map['supplierName'] as String?,
      salePrice: (map['salePrice'] as num?)?.toDouble() ?? 0.0,
      costPrice: (map['costPrice'] as num?)?.toDouble(),
      stockQuantity: (map['stockQuantity'] as num?)?.toDouble() ?? 0.0,
      minStock: (map['minStock'] as num?)?.toDouble() ?? 5.0,
      unit: ProductUnit.fromString(map['unit'] as String?),
      ncm: map['ncm'] as String?,
      status: ProductStatus.fromString(map['status'] as String?),
      specificAttributes: (map['specificAttributes'] as Map<String, dynamic>?) ?? {},
      companyId: map['companyId'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  ProductModel copyWith({
    String? id,
    String? name,
    String? sku,
    String? barcode,
    ProductSector? sector,
    String? categoryTitle,
    String? subcategory,
    String? description,
    String? supplierId,
    String? supplierName,
    double? salePrice,
    double? costPrice,
    double? stockQuantity,
    double? minStock,
    ProductUnit? unit,
    String? ncm,
    ProductStatus? status,
    Map<String, dynamic>? specificAttributes,
    String? companyId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      sector: sector ?? this.sector,
      categoryTitle: categoryTitle ?? this.categoryTitle,
      subcategory: subcategory ?? this.subcategory,
      description: description ?? this.description,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      salePrice: salePrice ?? this.salePrice,
      costPrice: costPrice ?? this.costPrice,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      minStock: minStock ?? this.minStock,
      unit: unit ?? this.unit,
      ncm: ncm ?? this.ncm,
      status: status ?? this.status,
      specificAttributes: specificAttributes ?? this.specificAttributes,
      companyId: companyId ?? this.companyId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
