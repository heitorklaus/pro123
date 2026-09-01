import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../auth/domain/models/user_model.dart';
import '../../domain/models/contract_model.dart';

/// Repositório Firestore para persistência e gestão em tempo real de Contratos
class ContractRepository {
  final FirebaseFirestore _firestore;

  ContractRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('contracts');

  /// Stream em tempo real de contratos filtrados por empresa e permissões
  Stream<List<ContractModel>> getContractsStream({
    String? companyId,
    UserModel? currentUser,
  }) {
    Query<Map<String, dynamic>> query = _collection.orderBy('createdAt', descending: true);

    // Se não for superAdmin, filtra pela empresa
    if (currentUser?.isSuperAdmin != true) {
      final effectiveCompany = companyId ?? currentUser?.effectiveCompanyId;
      if (effectiveCompany != null && effectiveCompany.isNotEmpty) {
        query = query.where('companyId', isEqualTo: effectiveCompany);
      }
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => ContractModel.fromFirestore(doc))
          .toList();
    });
  }

  /// Busca contrato por ID
  Future<ContractModel?> getContractById(String contractId) async {
    final doc = await _collection.doc(contractId).get();
    if (!doc.exists) return null;
    return ContractModel.fromFirestore(doc);
  }

  /// Salva ou atualiza um contrato
  Future<String> saveContract(ContractModel contract) async {
    if (contract.id.isEmpty) {
      final docRef = await _collection.add(contract.toMap());
      return docRef.id;
    } else {
      await _collection.doc(contract.id).set(contract.toMap(), SetOptions(merge: true));
      return contract.id;
    }
  }

  /// Atualiza o status do contrato
  Future<void> updateStatus(String contractId, ContractStatus status) async {
    final data = <String, dynamic>{
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (status == ContractStatus.signed) {
      data['signedAt'] = FieldValue.serverTimestamp();
    }
    await _collection.doc(contractId).update(data);
  }

  /// Exclui um contrato
  Future<void> deleteContract(String contractId) async {
    await _collection.doc(contractId).delete();
  }

  /// Gera o próximo número de contrato sequencial (ex: CTR-2026-001)
  Future<String> generateNextContractNumber({String? companyId}) async {
    try {
      final year = DateTime.now().year;
      Query<Map<String, dynamic>> query = _collection
          .orderBy('createdAt', descending: true)
          .limit(20);

      if (companyId != null && companyId.isNotEmpty) {
        query = query.where('companyId', isEqualTo: companyId);
      }

      final snap = await query.get();
      int maxSeq = 0;
      final pattern = RegExp(r'CTR-\d{4}-(\d+)');

      for (final doc in snap.docs) {
        final numStr = doc.data()['contractNumber'] as String? ?? '';
        final match = pattern.firstMatch(numStr);
        if (match != null) {
          final seq = int.tryParse(match.group(1)!) ?? 0;
          if (seq > maxSeq) maxSeq = seq;
        }
      }

      final nextSeq = (maxSeq + 1).toString().padLeft(3, '0');
      return 'CTR-$year-$nextSeq';
    } catch (_) {
      final rand = (100 + DateTime.now().millisecondsSinceEpoch % 900).toString();
      return 'CTR-${DateTime.now().year}-$rand';
    }
  }
}
