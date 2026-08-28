import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'product_model.dart';

/// Modelo para Categorias e Segmentos de Produtos & Serviços
class CategoryModel {
  final String id;
  final String title;
  final String description;
  final int iconCodePoint;
  final String? iconFontFamily;
  final int colorValue;
  final bool isCustom;
  final String? companyId;
  final DateTime createdAt;

  const CategoryModel({
    required this.id,
    required this.title,
    required this.description,
    required this.iconCodePoint,
    this.iconFontFamily = 'MaterialIcons',
    required this.colorValue,
    this.isCustom = false,
    this.companyId,
    required this.createdAt,
  });

  // ignore: non_const_argument_for_const_parameter
  IconData get icon => IconData(iconCodePoint, fontFamily: iconFontFamily ?? 'MaterialIcons');
  Color get themeColor => Color(colorValue);

  /// Tenta obter o ProductSector enum correspondente se for nativo
  ProductSector? get matchingSector {
    for (final s in ProductSector.values) {
      if (s.name == id || s.title == title) return s;
    }
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title.trim(),
      'description': description.trim(),
      'iconCodePoint': iconCodePoint,
      'iconFontFamily': iconFontFamily,
      'colorValue': colorValue,
      'isCustom': isCustom,
      'companyId': companyId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory CategoryModel.fromMap(Map<String, dynamic> map, String id) {
    return CategoryModel(
      id: id,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      iconCodePoint: map['iconCodePoint'] as int? ?? Icons.category_rounded.codePoint,
      iconFontFamily: map['iconFontFamily'] as String? ?? 'MaterialIcons',
      colorValue: map['colorValue'] as int? ?? 0xFF6366F1,
      isCustom: map['isCustom'] as bool? ?? true,
      companyId: map['companyId'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Converte um ProductSector pré-definido para CategoryModel
  factory CategoryModel.fromSector(ProductSector sector) {
    return CategoryModel(
      id: sector.name,
      title: sector.title,
      description: sector.description,
      iconCodePoint: sector.icon.codePoint,
      iconFontFamily: sector.icon.fontFamily,
      colorValue: sector.themeColor.toARGB32(),
      isCustom: false,
      createdAt: DateTime(2024, 1, 1),
    );
  }

  /// Lista das 20 categorias padrão do sistema
  static List<CategoryModel> get nativeCategories {
    return ProductSector.values.map((s) => CategoryModel.fromSector(s)).toList();
  }

  CategoryModel copyWith({
    String? id,
    String? title,
    String? description,
    int? iconCodePoint,
    String? iconFontFamily,
    int? colorValue,
    bool? isCustom,
    String? companyId,
    DateTime? createdAt,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      iconFontFamily: iconFontFamily ?? this.iconFontFamily,
      colorValue: colorValue ?? this.colorValue,
      isCustom: isCustom ?? this.isCustom,
      companyId: companyId ?? this.companyId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Ícones pré-selecionados para o usuário escolher ao criar uma categoria
class CategoryIconOption {
  final String label;
  final IconData icon;

  const CategoryIconOption(this.label, this.icon);

  static const List<CategoryIconOption> allIcons = [
    // Limpeza & Químicos
    CategoryIconOption('Limpeza', Icons.cleaning_services_rounded),
    CategoryIconOption('Sanitizante', Icons.sanitizer_rounded),
    CategoryIconOption('Água / Líquidos', Icons.water_drop_rounded),
    CategoryIconOption('Lixeira / Descarte', Icons.delete_sweep_rounded),

    // Alimentos & Bebidas
    CategoryIconOption('Restaurante', Icons.restaurant_rounded),
    CategoryIconOption('Fast Food', Icons.fastfood_rounded),
    CategoryIconOption('Cafeteria', Icons.local_cafe_rounded),
    CategoryIconOption('Padaria', Icons.bakery_dining_rounded),
    CategoryIconOption('Pizza', Icons.local_pizza_rounded),
    CategoryIconOption('Bebidas', Icons.liquor_rounded),
    CategoryIconOption('Sorvete', Icons.icecream_rounded),

    // Moda & Acessórios
    CategoryIconOption('Vestuário', Icons.checkroom_rounded),
    CategoryIconOption('Bolsas / Compras', Icons.shopping_bag_rounded),
    CategoryIconOption('Estilo', Icons.style_rounded),
    CategoryIconOption('Relógios / Joias', Icons.watch_rounded),

    // Ferramentas & Construção
    CategoryIconOption('Ferramentas', Icons.handyman_rounded),
    CategoryIconOption('Chave / Ajuste', Icons.build_rounded),
    CategoryIconOption('Pintura', Icons.format_paint_rounded),
    CategoryIconOption('Hidráulica', Icons.plumbing_rounded),
    CategoryIconOption('Elétrica', Icons.electric_bolt_rounded),

    // Saúde & Cuidados
    CategoryIconOption('Farmácia', Icons.local_pharmacy_rounded),
    CategoryIconOption('Saúde', Icons.medical_services_rounded),
    CategoryIconOption('Estética / Spa', Icons.spa_rounded),
    CategoryIconOption('Fitness / Academia', Icons.fitness_center_rounded),

    // Tecnologia & Eletrônicos
    CategoryIconOption('Computadores', Icons.computer_rounded),
    CategoryIconOption('Dispositivos', Icons.devices_rounded),
    CategoryIconOption('Smartphones', Icons.smartphone_rounded),
    CategoryIconOption('Rede / Roteador', Icons.router_rounded),
    CategoryIconOption('Hardware', Icons.memory_rounded),

    // Automotivo & Transporte
    CategoryIconOption('Automóveis', Icons.directions_car_rounded),
    CategoryIconOption('Motos', Icons.two_wheeler_rounded),
    CategoryIconOption('Velocidade / Performance', Icons.speed_rounded),
    CategoryIconOption('Mecânica Auto', Icons.car_repair_rounded),
    CategoryIconOption('Caminhões / Cargas', Icons.local_shipping_rounded),

    // Papelaria & Educação
    CategoryIconOption('Papelaria / Bloco', Icons.edit_note_rounded),
    CategoryIconOption('Educação / Cursos', Icons.school_rounded),
    CategoryIconOption('Livros', Icons.menu_book_rounded),
    CategoryIconOption('Arte / Desenho', Icons.brush_rounded),

    // Pets & Natureza
    CategoryIconOption('Pet Shop', Icons.pets_rounded),
    CategoryIconOption('Jardim / Flores', Icons.yard_rounded),
    CategoryIconOption('Natureza', Icons.nature_rounded),
    CategoryIconOption('Plantas / Gramado', Icons.grass_rounded),

    // Móveis & Casa
    CategoryIconOption('Móveis / Cadeiras', Icons.chair_rounded),
    CategoryIconOption('Cama / Quarto', Icons.bed_rounded),
    CategoryIconOption('Cozinha', Icons.kitchen_rounded),
    CategoryIconOption('Iluminação', Icons.lightbulb_rounded),

    // Serviços & Negócios
    CategoryIconOption('Negócios / Serviços', Icons.business_center_rounded),
    CategoryIconOption('Marketing / Anúncios', Icons.campaign_rounded),
    CategoryIconOption('Métricas / Relatórios', Icons.analytics_rounded),
    CategoryIconOption('Segurança', Icons.security_rounded),

    // Geral & Outros
    CategoryIconOption('Carrinho / Geral', Icons.shopping_cart_rounded),
    CategoryIconOption('Etiqueta / Promoção', Icons.sell_rounded),
    CategoryIconOption('Caixa / Pacote', Icons.inventory_2_rounded),
    CategoryIconOption('Destaque / Especial', Icons.stars_rounded),
    CategoryIconOption('Presentes', Icons.card_giftcard_rounded),
  ];
}

/// Paleta de cores selecionáveis para Categorias
class CategoryColorOption {
  final String name;
  final int value;

  const CategoryColorOption(this.name, this.value);

  Color get color => Color(value);

  static const List<CategoryColorOption> allColors = [
    CategoryColorOption('Azul Céu', 0xFF0284C7),
    CategoryColorOption('Laranja', 0xFFEA580C),
    CategoryColorOption('Violeta', 0xFF8B5CF6),
    CategoryColorOption('Âmbar', 0xFFD97706),
    CategoryColorOption('Esmeralda', 0xFF059669),
    CategoryColorOption('Azul Royal', 0xFF2563EB),
    CategoryColorOption('Ardósia', 0xFF475569),
    CategoryColorOption('Roxo', 0xFF7C3AED),
    CategoryColorOption('Verde', 0xFF16A34A),
    CategoryColorOption('Bronze', 0xFFB45309),
    CategoryColorOption('Vermelho', 0xFFDC2626),
    CategoryColorOption('Teal', 0xFF0D9488),
    CategoryColorOption('Rosa', 0xFFE11D48),
    CategoryColorOption('Índigo', 0xFF4F46E5),
    CategoryColorOption('Grafite', 0xFF334155),
    CategoryColorOption('Magenta', 0xFF9333EA),
    CategoryColorOption('Ciano', 0xFF0891B2),
    CategoryColorOption('Dourado', 0xFFF59E0B),
    CategoryColorOption('Verde Floresta', 0xFF15803D),
    CategoryColorOption('Cinza Aço', 0xFF4B5563),
  ];
}
