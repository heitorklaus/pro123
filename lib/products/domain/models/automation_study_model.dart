// ignore_for_file: non_const_argument_for_const_parameter
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Modelo de Categoria de Automação (Nativas do sistema ou Customizadas da Empresa)
class AutomationCategoryModel {
  final String id;
  final String title;
  final IconData icon;
  final Color color;
  final bool isCustom;
  final String? companyId;
  final DateTime? createdAt;

  const AutomationCategoryModel({
    required this.id,
    required this.title,
    required this.icon,
    required this.color,
    this.isCustom = false,
    this.companyId,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title.trim(),
      'iconCodePoint': icon.codePoint,
      'iconFontFamily': icon.fontFamily ?? 'MaterialIcons',
      'colorValue': color.toARGB32(),
      'isCustom': isCustom,
      'companyId': companyId,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }

  factory AutomationCategoryModel.fromMap(Map<String, dynamic> map, String id) {
    return AutomationCategoryModel(
      id: id,
      title: map['title']?.toString() ?? 'Categoria',
      icon: IconData(
        (map['iconCodePoint'] as num?)?.toInt() ?? Icons.category_rounded.codePoint,
        fontFamily: map['iconFontFamily']?.toString() ?? 'MaterialIcons',
      ),
      color: Color((map['colorValue'] as num?)?.toInt() ?? 0xFF6366F1),
      isCustom: map['isCustom'] as bool? ?? true,
      companyId: map['companyId']?.toString(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  factory AutomationCategoryModel.fromEnum(AutomationItemCategory cat) {
    return AutomationCategoryModel(
      id: cat.name,
      title: cat.title,
      icon: cat.icon,
      color: cat.color,
      isCustom: false,
    );
  }

  static List<AutomationCategoryModel> get defaultCategories {
    return AutomationItemCategory.values
        .map((e) => AutomationCategoryModel.fromEnum(e))
        .toList();
  }

  AutomationCategoryModel copyWith({
    String? id,
    String? title,
    IconData? icon,
    Color? color,
    bool? isCustom,
    String? companyId,
    DateTime? createdAt,
  }) {
    return AutomationCategoryModel(
      id: id ?? this.id,
      title: title ?? this.title,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      isCustom: isCustom ?? this.isCustom,
      companyId: companyId ?? this.companyId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Categorias de equipamentos e soluções em Automação Residencial e Comercial
enum AutomationItemCategory {
  lighting('Iluminação & Cenas', Icons.lightbulb_outline_rounded, Color(0xFFF59E0B)),
  curtains('Persianas & Cortinas', Icons.blinds_rounded, Color(0xFF0284C7)),
  audioVideo('Áudio, Vídeo & Home Theater', Icons.speaker_rounded, Color(0xFF8B5CF6)),
  climate('Climatização & AC', Icons.ac_unit_rounded, Color(0xFF06B6D4)),
  network('Rede, Wi-Fi & Cabeamento', Icons.router_rounded, Color(0xFF10B981)),
  security('Segurança & Controle de Acesso', Icons.lock_outline_rounded, Color(0xFFEF4444)),
  sensors('Sensores & Atuadores', Icons.sensors_rounded, Color(0xFFEC4899)),
  other('Infraestrutura & Acessórios', Icons.category_rounded, Color(0xFF64748B));

  final String title;
  final IconData icon;
  final Color color;

  const AutomationItemCategory(this.title, this.icon, this.color);

  static AutomationItemCategory fromString(String? val) {
    if (val == null) return AutomationItemCategory.other;
    final clean = val.toLowerCase().trim();
    if (clean.contains('ilumina') || clean.contains('luz') || clean.contains('dimmer') || clean.contains('led') || clean.contains('lamp')) {
      return AutomationItemCategory.lighting;
    }
    if (clean.contains('persiana') || clean.contains('cortina') || clean.contains('motor') || clean.contains('tubular')) {
      return AutomationItemCategory.curtains;
    }
    if (clean.contains('audio') || clean.contains('áudio') || clean.contains('som') || clean.contains('video') || clean.contains('vídeo') || clean.contains('tv') || clean.contains('receiver') || clean.contains('caixa') || clean.contains('subwoofer') || clean.contains('home')) {
      return AutomationItemCategory.audioVideo;
    }
    if (clean.contains('clima') || clean.contains('ar') || clean.contains('ac') || clean.contains('temperatura') || clean.contains('termostato')) {
      return AutomationItemCategory.climate;
    }
    if (clean.contains('rede') || clean.contains('wifi') || clean.contains('wi-fi') || clean.contains('router') || clean.contains('switch') || clean.contains('cabo') || clean.contains('access')) {
      return AutomationItemCategory.network;
    }
    if (clean.contains('seguran') || clean.contains('fechadura') || clean.contains('alarme') || clean.contains('camera') || clean.contains('câmera') || clean.contains('acesso')) {
      return AutomationItemCategory.security;
    }
    if (clean.contains('sensor') || clean.contains('presenca') || clean.contains('presença') || clean.contains('atuador') || clean.contains('rele') || clean.contains('relé')) {
      return AutomationItemCategory.sensors;
    }
    return AutomationItemCategory.other;
  }
}

/// Item ou Equipamento pertencente a um Ambiente no Estudo de Automação
class AutomationItem {
  final String id;
  final String name;
  final String? productId;
  final AutomationItemCategory category;
  final String categoryTitle;
  final int categoryIconCodePoint;
  final String? categoryIconFontFamily;
  final int categoryColorValue;
  final int quantity;
  final String unit;
  final double unitPrice;
  final double totalPrice;
  final String? sku;
  final String? manufacturer;
  final String? notes;

  AutomationItem({
    required this.id,
    required this.name,
    this.productId,
    this.category = AutomationItemCategory.other,
    String? categoryTitle,
    int? categoryIconCodePoint,
    this.categoryIconFontFamily = 'MaterialIcons',
    int? categoryColorValue,
    this.quantity = 1,
    this.unit = 'UN',
    this.unitPrice = 0.0,
    this.totalPrice = 0.0,
    this.sku,
    this.manufacturer,
    this.notes,
  })  : categoryTitle = categoryTitle ?? category.title,
        categoryIconCodePoint = categoryIconCodePoint ?? category.icon.codePoint,
        categoryColorValue = categoryColorValue ?? (category.color.toARGB32());

  IconData get categoryIcon => IconData(categoryIconCodePoint, fontFamily: categoryIconFontFamily ?? 'MaterialIcons');
  Color get categoryColor => Color(categoryColorValue);
  String? get brandModel => manufacturer;

  double get calculatedTotal => (totalPrice > 0) ? totalPrice : (quantity * unitPrice);

  AutomationItem copyWith({
    String? id,
    String? name,
    String? productId,
    AutomationItemCategory? category,
    String? categoryTitle,
    int? categoryIconCodePoint,
    String? categoryIconFontFamily,
    int? categoryColorValue,
    int? quantity,
    String? unit,
    double? unitPrice,
    double? totalPrice,
    String? sku,
    String? manufacturer,
    String? notes,
  }) {
    return AutomationItem(
      id: id ?? this.id,
      name: name ?? this.name,
      productId: productId ?? this.productId,
      category: category ?? this.category,
      categoryTitle: categoryTitle ?? this.categoryTitle,
      categoryIconCodePoint: categoryIconCodePoint ?? this.categoryIconCodePoint,
      categoryIconFontFamily: categoryIconFontFamily ?? this.categoryIconFontFamily,
      categoryColorValue: categoryColorValue ?? this.categoryColorValue,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      unitPrice: unitPrice ?? this.unitPrice,
      totalPrice: totalPrice ?? this.totalPrice,
      sku: sku ?? this.sku,
      manufacturer: manufacturer ?? this.manufacturer,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      if (productId != null && productId!.isNotEmpty) 'productId': productId,
      'category': category.name,
      'categoryTitle': categoryTitle,
      'categoryIconCodePoint': categoryIconCodePoint,
      'categoryIconFontFamily': categoryIconFontFamily,
      'categoryColorValue': categoryColorValue,
      'quantity': quantity,
      'unit': unit,
      'unitPrice': unitPrice,
      'totalPrice': calculatedTotal,
      if (sku != null && sku!.isNotEmpty) 'sku': sku,
      if (manufacturer != null && manufacturer!.isNotEmpty) 'manufacturer': manufacturer,
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
    };
  }

  factory AutomationItem.fromMap(Map<String, dynamic> map) {
    final qty = (map['quantity'] as num?)?.toInt() ?? 1;
    final uPrice = (map['unitPrice'] as num?)?.toDouble() ?? 0.0;
    final tPrice = (map['totalPrice'] as num?)?.toDouble() ?? (qty * uPrice);

    final rawCat = map['categoryTitle']?.toString() ?? map['category']?.toString();
    final matchedEnum = AutomationItemCategory.fromString(rawCat);

    final iconCode = (map['categoryIconCodePoint'] as num?)?.toInt() ??
        (map['categoryIcon'] as num?)?.toInt() ??
        matchedEnum.icon.codePoint;

    final colorVal = (map['categoryColorValue'] as num?)?.toInt() ??
        (map['categoryColor'] as num?)?.toInt() ??
        matchedEnum.color.toARGB32();

    return AutomationItem(
      id: map['id']?.toString() ?? UniqueKey().toString(),
      name: map['name']?.toString() ?? 'Equipamento',
      productId: map['productId']?.toString(),
      category: matchedEnum,
      categoryTitle: rawCat?.isNotEmpty == true ? rawCat! : matchedEnum.title,
      categoryIconCodePoint: iconCode,
      categoryIconFontFamily: map['categoryIconFontFamily']?.toString() ?? 'MaterialIcons',
      categoryColorValue: colorVal,
      quantity: qty,
      unit: map['unit']?.toString() ?? 'UN',
      unitPrice: uPrice,
      totalPrice: tPrice,
      sku: map['sku']?.toString(),
      manufacturer: map['manufacturer']?.toString(),
      notes: map['notes']?.toString(),
    );
  }
}

/// Ambiente / Cômodo do Estudo de Automação
class AutomationEnvironment {
  final String id;
  final String name;
  final List<AutomationItem> items;
  final String? notes;
  final String? description;
  final String? imageUrl;

  const AutomationEnvironment({
    required this.id,
    required this.name,
    this.items = const [],
    this.notes,
    this.description,
    this.imageUrl,
  });

  /// Soma total dos itens deste ambiente
  double get subtotal => items.fold(0.0, (acc, item) => acc + item.calculatedTotal);

  /// Getter alternativo de compatibilidade para valor total
  double get totalPrice => subtotal;

  /// Miniexplicação do ambiente com fallback inteligente contextual
  String get miniexplanation {
    if (description != null && description!.trim().isNotEmpty) {
      return description!.trim();
    }
    final lower = name.toLowerCase();
    if (lower.contains('sala') || lower.contains('living') || lower.contains('estar') || lower.contains('tv')) {
      return 'Conforto e entretenimento para a família e convidados.';
    }
    if (lower.contains('quarto') || lower.contains('dorm') || lower.contains('suite') || lower.contains('suíte')) {
      return 'Bem-estar e privacidade com automação de iluminação e climatização.';
    }
    if (lower.contains('cozinha') || lower.contains('gourmet') || lower.contains('jantar') || lower.contains('copa')) {
      return 'Conexões especiais e alta gastronomia com som ambiente integrado.';
    }
    if (lower.contains('cinema') || lower.contains('theater') || lower.contains('áudio') || lower.contains('audio')) {
      return 'Imersão cinematográfica completa com acionamento unificado de som e luzes.';
    }
    if (lower.contains('jardim') || lower.contains('extern') || lower.contains('piscina') || lower.contains('sacada') || lower.contains('varanda')) {
      return 'Lazer e tranquilidade com cenários paisagísticos e controle externo.';
    }
    if (lower.contains('garagem') || lower.contains('estacionamento')) {
      return 'Segurança perimetral e comodidade no acesso diário inteligente.';
    }
    if (lower.contains('escritorio') || lower.contains('escritório') || lower.contains('office') || lower.contains('estudo')) {
      return 'Produtividade máxima com iluminação focada e controle térmico.';
    }
    return 'Ambiente inteligente para mais conforto, praticidade e eficiência.';
  }

  /// Ícone contextual deduzido pelo nome do ambiente
  IconData get icon {
    final lower = name.toLowerCase();
    if (lower.contains('sala') || lower.contains('living') || lower.contains('estar') || lower.contains('tv')) {
      return Icons.weekend_rounded;
    }
    if (lower.contains('quarto') || lower.contains('dorm') || lower.contains('suite') || lower.contains('suíte')) {
      return Icons.bed_rounded;
    }
    if (lower.contains('cozinha') || lower.contains('gourmet') || lower.contains('jantar') || lower.contains('copa')) {
      return Icons.kitchen_rounded;
    }
    if (lower.contains('cinema') || lower.contains('theater') || lower.contains('áudio') || lower.contains('audio')) {
      return Icons.movie_rounded;
    }
    if (lower.contains('escritorio') || lower.contains('escritório') || lower.contains('office') || lower.contains('estudo')) {
      return Icons.desk_rounded;
    }
    if (lower.contains('banheiro') || lower.contains('lavabo') || lower.contains('wc')) {
      return Icons.bathtub_rounded;
    }
    if (lower.contains('jardim') || lower.contains('extern') || lower.contains('piscina') || lower.contains('sacada') || lower.contains('varanda')) {
      return Icons.deck_rounded;
    }
    if (lower.contains('garagem') || lower.contains('estacionamento')) {
      return Icons.directions_car_rounded;
    }
    return Icons.room_preferences_rounded;
  }

  /// Quantidade total de dispositivos neste ambiente
  int get totalItemsCount => items.fold(0, (acc, item) => acc + item.quantity);

  AutomationEnvironment copyWith({
    String? id,
    String? name,
    List<AutomationItem>? items,
    String? notes,
    String? description,
    String? imageUrl,
  }) {
    return AutomationEnvironment(
      id: id ?? this.id,
      name: name ?? this.name,
      items: items ?? this.items,
      notes: notes ?? this.notes,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'items': items.map((i) => i.toMap()).toList(),
      'subtotal': subtotal,
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
      if (description != null && description!.isNotEmpty) 'description': description,
      if (imageUrl != null && imageUrl!.isNotEmpty) 'imageUrl': imageUrl,
    };
  }

  factory AutomationEnvironment.fromMap(Map<String, dynamic> map) {
    final rawItems = map['items'];
    final itemsList = <AutomationItem>[];
    if (rawItems is List) {
      for (final it in rawItems) {
        if (it is Map) {
          itemsList.add(AutomationItem.fromMap(Map<String, dynamic>.from(it)));
        }
      }
    }

    return AutomationEnvironment(
      id: map['id']?.toString() ?? UniqueKey().toString(),
      name: map['name']?.toString() ?? 'Ambiente',
      items: itemsList,
      notes: map['notes']?.toString(),
      description: map['description']?.toString(),
      imageUrl: map['imageUrl']?.toString(),
    );
  }
}
