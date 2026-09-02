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
  /// Ordenação feita em memória para não exigir índices compostos complexos no Firestore
  Stream<List<ContractModel>> getContractsStream({
    String? companyId,
    UserModel? currentUser,
  }) {
    Query<Map<String, dynamic>> query = _collection;

    final isSuperAdmin = currentUser?.isSuperAdmin == true ||
        currentUser?.role == 'superAdmin' ||
        currentUser?.email == 'admin@admin.com.br';

    final effectiveCompany = companyId ?? currentUser?.effectiveCompanyId ?? currentUser?.companyId;

    if (!isSuperAdmin && effectiveCompany != null && effectiveCompany.isNotEmpty && effectiveCompany != 'GLOBAL_MASTER' && effectiveCompany != 'ALL') {
      query = query.where('companyId', isEqualTo: effectiveCompany);
    }

    return query.snapshots().map((snapshot) {
      var list = snapshot.docs
          .map((doc) => ContractModel.fromFirestore(doc))
          .toList();

      // Se o usuário não tiver permissão para ver todas as propostas/contratos, filtra os próprios
      if (!isSuperAdmin && currentUser != null && currentUser.permissions.viewAllProposals == false) {
        list = list.where((c) =>
            c.createdByUserId == currentUser.uid ||
            c.createdByUserId == null ||
            c.createdByUserId!.isEmpty).toList();
      }

      // Ordenação decrescente em memória
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
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
      Query<Map<String, dynamic>> query = _collection;

      if (companyId != null && companyId.isNotEmpty && companyId != 'GLOBAL_MASTER' && companyId != 'ALL') {
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
