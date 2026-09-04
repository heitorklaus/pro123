import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../auth/domain/models/user_model.dart';
import '../../domain/models/roof_study_model.dart';

/// Repositório Firestore para persistência e gestão em tempo real de Estudos de Telhado
class RoofStudyRepository {
  final FirebaseFirestore _firestore;

  RoofStudyRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('roof_studies');

  /// Stream em tempo real dos estudos de telhado filtrados por empresa e usuário
  Stream<List<RoofStudyModel>> getRoofStudiesStream({
    String? companyId,
    UserModel? currentUser,
    bool isSuperAdmin = false,
  }) {
    Query<Map<String, dynamic>> query = _collection;

    final isSuper = isSuperAdmin ||
        currentUser?.isSuperAdmin == true ||
        currentUser?.role == 'superAdmin' ||
        currentUser?.email == 'admin@admin.com.br';

    final effectiveCompany =
        companyId ?? currentUser?.effectiveCompanyId ?? currentUser?.companyId;

    if (!isSuper &&
        effectiveCompany != null &&
        effectiveCompany.isNotEmpty &&
        effectiveCompany != 'GLOBAL_MASTER' &&
        effectiveCompany != 'ALL') {
      query = query.where('companyId', isEqualTo: effectiveCompany);
    }

    return query.snapshots().map((snapshot) {
      var list = snapshot.docs
          .map((doc) => RoofStudyModel.fromMap(doc.data(), doc.id))
          .toList();

      // Se o usuário for comum e não tiver permissão para ver todos os estudos da empresa
      if (!isSuper &&
          currentUser != null &&
          currentUser.permissions.viewAllProposals == false) {
        list = list
            .where((s) =>
                s.createdByUserId == currentUser.uid ||
                s.createdByUserId.isEmpty)
            .toList();
      }

      // Ordenação decrescente por data de atualização em memória
      list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return list;
    });
  }

  /// Busca um estudo específico pelo ID
  Future<RoofStudyModel?> getStudyById(String studyId) async {
    final doc = await _collection.doc(studyId).get();
    if (!doc.exists || doc.data() == null) return null;
    return RoofStudyModel.fromMap(doc.data()!, doc.id);
  }

  /// Salva ou atualiza um estudo de telhado completo
  Future<String> saveStudy(RoofStudyModel study) async {
    if (study.id.isNotEmpty && study.id != 'new') {
      await _collection.doc(study.id).set(
            study.toMap()..['updatedAt'] = FieldValue.serverTimestamp(),
            SetOptions(merge: true),
          );
      return study.id;
    } else {
      final docRef = await _collection.add(study.toMap());
      return docRef.id;
    }
  }

  /// Atualiza apenas os vínculos de Cliente e Proposta de um estudo existente
  Future<void> updateStudyLinks(
    String studyId, {
    String? clientId,
    String? clientName,
    String? proposalId,
    String? proposalCode,
  }) async {
    await _collection.doc(studyId).update({
      'clientId': clientId,
      'clientName': clientName,
      'proposalId': proposalId,
      'proposalCode': proposalCode,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Atualiza a URL da foto de drone de um estudo existente
  Future<void> updateDroneImageUrl(String studyId, String droneImageUrl) async {
    try {
      await _collection.doc(studyId).update({
        'droneImageUrl': droneImageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Falha silenciosa para manter resiliência
    }
  }

  /// Exclui um estudo de telhado pelo ID
  Future<void> deleteStudy(String studyId) async {
    await _collection.doc(studyId).delete();
  }
}
