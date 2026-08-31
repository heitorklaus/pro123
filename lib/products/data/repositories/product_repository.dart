import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/product_model.dart';
import '../../domain/models/subcategory_model.dart';
import '../../domain/models/category_model.dart';
import '../services/product_seed_data.dart';

/// Repositório de persistência e consultas da coleção 'products' e 'subcategories' no Cloud Firestore
class ProductRepository {
  final FirebaseFirestore _firestore;

  ProductRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _productsRef =>
      _firestore.collection('products');

  CollectionReference<Map<String, dynamic>> get _subcategoriesRef =>
      _firestore.collection('subcategories');

  /// Stream em tempo real da lista de produtos cadastrados
  Stream<List<ProductModel>> getProductsStream({String? companyId, bool isSuperAdmin = false}) {
    Query<Map<String, dynamic>> query = _productsRef;
    if (!isSuperAdmin || (companyId != null && companyId.isNotEmpty && companyId != 'GLOBAL_MASTER' && companyId != 'ALL')) {
      if (companyId == null || companyId.isEmpty) {
        return Stream.value([]);
      }
      query = query.where('companyId', isEqualTo: companyId);
    }
    return query.snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => ProductModel.fromMap(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Retorna todos os produtos do Firestore em lista única (útil para checagem/deduplicação)
  Future<List<ProductModel>> getAllProducts({String? companyId}) async {
    if (companyId == null || companyId.isEmpty) return [];
    final query = _productsRef.where('companyId', isEqualTo: companyId);
    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => ProductModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  /// Retorna produtos do setor solar para deduplicação ultrarrápida e econômica (filtra apenas usinas/itens solares)
  Future<List<ProductModel>> getSolarProductsForDeduplication({String? companyId}) async {
    if (companyId == null || companyId.isEmpty) return [];
    try {
      final query = _productsRef
          .where('companyId', isEqualTo: companyId)
          .where('sector', isEqualTo: ProductSector.solarPlant.name);
      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => ProductModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Cadastra múltiplos produtos inéditos em um único batch atômico (1 única viagem de rede)
  Future<List<ProductModel>> createProductsBatch(List<ProductModel> products, {String? companyId}) async {
    if (products.isEmpty) return [];
    final batch = _firestore.batch();
    final createdList = <ProductModel>[];

    for (final prod in products) {
      final docRef = _productsRef.doc();
      final finalProd = prod.copyWith(
        id: docRef.id,
        companyId: prod.companyId ?? companyId,
      );
      batch.set(docRef, finalProd.toMap());
      createdList.add(finalProd);
    }

    await batch.commit();
    return createdList;
  }

  /// Helper de normalização para comparação de strings
  static String normalizeKey(String str) {
    return str
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\d]'), '')
        .trim();
  }

  /// Cria um novo produto no Firestore
  Future<ProductModel> createProduct({
    required String name,
    String? sku,
    String? barcode,
    required ProductSector sector,
    String? categoryTitle,
    String? subcategory,
    String? description,
    String? supplierId,
    String? supplierName,
    required double salePrice,
    double? costPrice,
    double stockQuantity = 0.0,
    double minStock = 5.0,
    ProductUnit unit = ProductUnit.un,
    String? ncm,
    ProductStatus status = ProductStatus.active,
    Map<String, dynamic> specificAttributes = const {},
    String? companyId,
  }) async {
    final now = DateTime.now();
    final docRef = _productsRef.doc();

    final product = ProductModel(
      id: docRef.id,
      name: name.trim(),
      sku: sku?.trim(),
      barcode: barcode?.trim(),
      sector: sector,
      categoryTitle: categoryTitle?.trim(),
      subcategory: subcategory?.trim(),
      description: description?.trim(),
      supplierId: supplierId?.trim(),
      supplierName: supplierName?.trim(),
      salePrice: salePrice,
      costPrice: costPrice,
      stockQuantity: stockQuantity,
      minStock: minStock,
      unit: unit,
      ncm: ncm?.trim(),
      status: status,
      specificAttributes: specificAttributes,
      companyId: companyId,
      createdAt: now,
      updatedAt: now,
    );

    await docRef.set(product.toMap());
    return product;
  }

  /// Atualiza os dados de um produto existente
  Future<void> updateProduct(ProductModel product) async {
    await _productsRef.doc(product.id).update(product.toMap());
  }

  /// Ajusta a quantidade em estoque de um produto
  Future<void> updateStock(String productId, double newQuantity) async {
    await _productsRef.doc(productId).update({
      'stockQuantity': newQuantity,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Remove um produto do Firestore
  Future<void> deleteProduct(String id) async {
    await _productsRef.doc(id).delete();
  }

  /// Cadastra 200 produtos de teste realistas em lote (WriteBatch) no Firestore
  Future<int> seed200TestProducts({String? companyId}) async {
    final rawList = generate200TestProducts();
    final batch = _firestore.batch();
    final now = DateTime.now();

    for (int i = 0; i < rawList.length; i++) {
      final item = rawList[i];
      final docRef = _productsRef.doc();
      final productMap = Map<String, dynamic>.from(item);
      if (companyId != null) {
        productMap['companyId'] = companyId;
      }
      // Espalha os timestamps para que a ordenação cronológica fique perfeita
      final itemDate = now.subtract(Duration(minutes: (rawList.length - i) * 5));
      productMap['createdAt'] = Timestamp.fromDate(itemDate);
      productMap['updatedAt'] = Timestamp.fromDate(itemDate);
      batch.set(docRef, productMap);
    }

    await batch.commit();
    return rawList.length;
  }

  /// Remove TODOS os produtos cadastrados da empresa na coleção 'products' (em batches de até 450 itens)
  Future<int> deleteAllProducts({String? companyId}) async {
    Query<Map<String, dynamic>> query = _productsRef;
    if (companyId != null && companyId.isNotEmpty) {
      query = query.where('companyId', isEqualTo: companyId);
    }
    final snapshot = await query.get();
    if (snapshot.docs.isEmpty) return 0;

    int totalDeleted = 0;
    WriteBatch batch = _firestore.batch();
    int batchCount = 0;

    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
      batchCount++;
      totalDeleted++;

      if (batchCount >= 450) {
        await batch.commit();
        batch = _firestore.batch();
        batchCount = 0;
      }
    }

    if (batchCount > 0) {
      await batch.commit();
    }

    return totalDeleted;
  }

  // ── SUBCATEGORIAS ─────────────────────────────────────────────────────────

  /// Stream de subcategorias filtradas por segmento comercial
  Stream<List<SubcategoryModel>> getSubcategoriesStream(String sector) {
    return _subcategoriesRef
        .where('sector', isEqualTo: sector)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => SubcategoryModel.fromMap(doc.data(), doc.id))
              .toList();
          list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
          return list;
        });
  }

  /// Cria uma nova subcategoria
  Future<SubcategoryModel> createSubcategory({
    required String name,
    required String sector,
  }) async {
    final now = DateTime.now();
    final docRef = _subcategoriesRef.doc();
    final subcategory = SubcategoryModel(
      id: docRef.id,
      name: name.trim(),
      sector: sector,
      createdAt: now,
    );
    await docRef.set(subcategory.toMap());
    return subcategory;
  }

  /// Atualiza o nome de uma subcategoria existente
  Future<void> updateSubcategory(String id, String newName) async {
    await _subcategoriesRef.doc(id).update({
      'name': newName.trim(),
    });
  }

  /// Remove uma subcategoria do Firestore
  Future<void> deleteSubcategory(String id) async {
    await _subcategoriesRef.doc(id).delete();
  }

  // ── CATEGORIAS / SEGMENTOS ───────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> get _categoriesRef =>
      _firestore.collection('categories');

  /// Stream que combina as 20 categorias padrão do sistema com as categorias
  /// cadastradas de forma personalizada pela empresa no Firestore.
  Stream<List<CategoryModel>> getCategoriesStream({String? companyId}) {
    if (companyId == null || companyId.isEmpty) {
      return Stream.value(CategoryModel.nativeCategories);
    }
    final query = _categoriesRef.where('companyId', isEqualTo: companyId);
    return query.snapshots().map((snapshot) {
      final customList = snapshot.docs
          .map((doc) => CategoryModel.fromMap(doc.data(), doc.id))
          .toList();
      customList.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      final result = <CategoryModel>[
        ...CategoryModel.nativeCategories,
        ...customList,
      ];

      return result;
    });
  }

  /// Cria uma nova categoria personalizada no Firestore
  Future<CategoryModel> createCategory({
    required String title,
    required String description,
    required int iconCodePoint,
    String? iconFontFamily,
    required int colorValue,
    String? companyId,
  }) async {
    final now = DateTime.now();
    final docRef = _categoriesRef.doc();

    final category = CategoryModel(
      id: docRef.id,
      title: title.trim(),
      description: description.trim(),
      iconCodePoint: iconCodePoint,
      iconFontFamily: iconFontFamily ?? 'MaterialIcons',
      colorValue: colorValue,
      isCustom: true,
      companyId: companyId,
      createdAt: now,
    );

    await docRef.set(category.toMap());
    return category;
  }

  /// Atualiza uma categoria existente no Firestore
  Future<void> updateCategory(CategoryModel category) async {
    await _categoriesRef.doc(category.id).update(category.toMap());
  }

  /// Remove uma categoria do Firestore
  Future<void> deleteCategory(String id) async {
    await _categoriesRef.doc(id).delete();
  }
}


