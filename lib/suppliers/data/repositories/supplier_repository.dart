import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/supplier_model.dart';

/// Repositório de persistência e consultas da coleção 'suppliers' no Cloud Firestore
class SupplierRepository {
  final FirebaseFirestore _firestore;

  SupplierRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _suppliersRef =>
      _firestore.collection('suppliers');

  /// Stream em tempo real dos fornecedores cadastrados
  Stream<List<SupplierModel>> getSuppliersStream({String? companyId}) {
    if (companyId == null || companyId.isEmpty) {
      return Stream.value([]);
    }
    final query = _suppliersRef.where('companyId', isEqualTo: companyId);
    return query.snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => SupplierModel.fromMap(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => a.tradeName.toLowerCase().compareTo(b.tradeName.toLowerCase()));
      return list;
    });
  }

  /// Cria um novo fornecedor no Firestore
  Future<SupplierModel> createSupplier({
    required String corporateName,
    required String tradeName,
    String? cnpj,
    String? stateRegistration,
    required String email,
    required String phone,
    String? contactPerson,
    String? category,
    SupplierStatus status = SupplierStatus.active,
    String? zipCode,
    String? street,
    String? addressNumber,
    String? complement,
    String? neighborhood,
    String? city,
    String? state,
    String? paymentTerms,
    String? notes,
    String? companyId,
  }) async {
    final now = DateTime.now();
    final docRef = _suppliersRef.doc();

    final supplier = SupplierModel(
      id: docRef.id,
      corporateName: corporateName.trim(),
      tradeName: tradeName.trim(),
      cnpj: cnpj?.trim(),
      stateRegistration: stateRegistration?.trim(),
      email: email.trim().toLowerCase(),
      phone: phone.trim(),
      contactPerson: contactPerson?.trim(),
      category: category?.trim(),
      status: status,
      zipCode: zipCode?.trim(),
      street: street?.trim(),
      addressNumber: addressNumber?.trim(),
      complement: complement?.trim(),
      neighborhood: neighborhood?.trim(),
      city: city?.trim(),
      state: state?.trim().toUpperCase(),
      paymentTerms: paymentTerms?.trim(),
      notes: notes?.trim(),
      companyId: companyId,
      createdAt: now,
      updatedAt: now,
    );

    await docRef.set(supplier.toMap());
    return supplier;
  }

  /// Atualiza os dados de um fornecedor existente
  Future<void> updateSupplier(SupplierModel supplier) async {
    final updated = supplier.copyWith(updatedAt: DateTime.now());
    await _suppliersRef.doc(supplier.id).update(updated.toMap());
  }

  /// Remove um fornecedor do Firestore
  Future<void> deleteSupplier(String id) async {
    await _suppliersRef.doc(id).delete();
  }
}
