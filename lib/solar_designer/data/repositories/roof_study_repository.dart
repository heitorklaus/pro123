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

  /// Busca um estudo específico pelo ID (com fotos completas da subcoleção se existirem)
  Future<RoofStudyModel?> getStudyById(String studyId) async {
    final doc = await _collection.doc(studyId).get();
    if (!doc.exists || doc.data() == null) return null;
    final study = RoofStudyModel.fromMap(doc.data()!, doc.id);

    // Se o estudo tem fotos registradas na subcoleção
    if (study.photosCount > 0 || study.studyPhotos.any((p) => p.imageBase64.isEmpty)) {
      final subPhotos = await getStudyPhotos(studyId);
      if (subPhotos.isNotEmpty) {
        return study.copyWith(studyPhotos: subPhotos);
      }
    }

    return study;
  }

  /// Busca as fotos completas de um estudo na subcoleção 'photos'
  Future<List<RoofStudyPhoto>> getStudyPhotos(String studyId) async {
    try {
      final snap = await _collection
          .doc(studyId)
          .collection('photos')
          .orderBy('hourOfDay')
          .get();

      if (snap.docs.isNotEmpty) {
        return snap.docs
            .map((d) => RoofStudyPhoto.fromMap(d.data()))
            .where((p) => p.imageBase64.isNotEmpty || (p.imageUrl != null && p.imageUrl!.isNotEmpty))
            .toList();
      }
    } catch (_) {}
    return const [];
  }

  /// Salva ou atualiza um estudo de telhado completo com subcoleção de fotos otimizada
  Future<String> saveStudy(RoofStudyModel study) async {
    final String targetId;
    final Map<String, dynamic> parentData = study.toMap(includePhotoBase64: false);
    parentData['updatedAt'] = FieldValue.serverTimestamp();

    if (study.id.isNotEmpty && study.id != 'new') {
      targetId = study.id;
      await _collection.doc(targetId).set(
            parentData,
            SetOptions(merge: true),
          );
    } else {
      final docRef = await _collection.add(parentData);
      targetId = docRef.id;
    }

    // Persiste as fotos completas na subcoleção 'photos'
    // Cada foto ganha seu documento independente, mantendo o doc pai extremamente leve (~25KB)
    if (study.studyPhotos.isNotEmpty) {
      final photosCol = _collection.doc(targetId).collection('photos');
      final currentPhotoIds = <String>{};

      for (final photo in study.studyPhotos) {
        if (photo.id.isEmpty) continue;
        currentPhotoIds.add(photo.id);

        // Se a foto tiver imagem Base64 ou URL, salva na subcoleção
        if (photo.imageBase64.isNotEmpty || (photo.imageUrl != null && photo.imageUrl!.isNotEmpty)) {
          final photoMap = photo.toMap(includeBase64: true);
          photoMap['updatedAt'] = FieldValue.serverTimestamp();
          await photosCol.doc(photo.id).set(photoMap, SetOptions(merge: true));
        }
      }

      // Sincroniza exclusões: remove fotos que o usuário excluiu da lista
      try {
        final existingPhotosSnap = await photosCol.get();
        for (final doc in existingPhotosSnap.docs) {
          if (!currentPhotoIds.contains(doc.id)) {
            await doc.reference.delete();
          }
        }
      } catch (_) {
        // Falha silenciosa para não travar salvamento caso regras restrinjam delete
      }
    }

    return targetId;
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

  /// Exclui um estudo de telhado pelo ID e limpa fotos da subcoleção
  Future<void> deleteStudy(String studyId) async {
    try {
      final photosSnap = await _collection.doc(studyId).collection('photos').get();
      for (final doc in photosSnap.docs) {
        await doc.reference.delete();
      }
    } catch (_) {}
    await _collection.doc(studyId).delete();
  }
}
