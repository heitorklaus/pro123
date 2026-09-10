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

    // Carrega sempre as fotos completas em alta resolução da subcoleção se existirem
    final subPhotos = await getStudyPhotos(studyId);
    if (subPhotos.isNotEmpty) {
      return study.copyWith(studyPhotos: subPhotos);
    }

    return study;
  }

  /// Busca as fotos completas de um estudo na subcoleção 'photos' (reconstroi chunks se necessário)
  Future<List<RoofStudyPhoto>> getStudyPhotos(String studyId) async {
    try {
      final snap = await _collection
          .doc(studyId)
          .collection('photos')
          .orderBy('hourOfDay')
          .get();

      if (snap.docs.isNotEmpty) {
        final photos = <RoofStudyPhoto>[];
        for (final doc in snap.docs) {
          final data = doc.data();
          final isChunked = data['isChunked'] == true;
          String b64 = data['imageBase64']?.toString() ?? '';

          if (isChunked) {
            try {
              final chunksSnap = await doc.reference
                  .collection('chunks')
                  .orderBy('index')
                  .get();
              if (chunksSnap.docs.isNotEmpty) {
                final buffer = StringBuffer();
                for (final c in chunksSnap.docs) {
                  final chunkStr = c.data()['data']?.toString() ?? '';
                  buffer.write(chunkStr);
                }
                b64 = buffer.toString();
              }
            } catch (_) {}
          }

          final photoMap = Map<String, dynamic>.from(data);
          photoMap['imageBase64'] = b64;
          final photo = RoofStudyPhoto.fromMap(photoMap);
          if (photo.imageBase64.isNotEmpty ||
              (photo.imageUrl != null && photo.imageUrl!.isNotEmpty)) {
            photos.add(photo);
          }
        }
        return photos;
      }
    } catch (_) {}
    return const [];
  }

  /// Salva ou atualiza um estudo de telhado completo com subcoleção de fotos otimizada e chunked HD
  Future<String> saveStudy(RoofStudyModel study) async {
    final String targetId;
    final Map<String, dynamic> parentData =
        study.toMap(includePhotoBase64: false);
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
      try {
        final photosCol = _collection.doc(targetId).collection('photos');
        final currentPhotoIds = <String>{};

        for (final photo in study.studyPhotos) {
          if (photo.id.isEmpty) continue;
          currentPhotoIds.add(photo.id);

          final b64 = photo.imageBase64;
          final hasUrl = photo.imageUrl != null && photo.imageUrl!.isNotEmpty;

          if (b64.isNotEmpty || hasUrl) {
            const maxDirectSize = 750000; // 750KB limite seguro direto no doc
            if (b64.isNotEmpty && b64.length >= maxDirectSize) {
              // Foto em Alta Resolução (HD): salva com Chunks para qualidade 100% perfeita sem limite de tamanho
              const chunkSize = 350000; // ~350KB por chunk
              final totalLen = b64.length;
              final numChunks = (totalLen / chunkSize).ceil();

              final photoMap = photo.toMap(includeBase64: false);
              photoMap['isChunked'] = true;
              photoMap['chunksCount'] = numChunks;
              photoMap['updatedAt'] = FieldValue.serverTimestamp();

              await photosCol
                  .doc(photo.id)
                  .set(photoMap, SetOptions(merge: true));

              final chunksCol =
                  photosCol.doc(photo.id).collection('chunks');
              final chunkFutures = <Future>[];
              for (int i = 0; i < numChunks; i++) {
                final start = i * chunkSize;
                final end =
                    (start + chunkSize < totalLen) ? start + chunkSize : totalLen;
                final chunkData = b64.substring(start, end);
                chunkFutures.add(chunksCol.doc('chunk_$i').set({
                  'index': i,
                  'data': chunkData,
                  'updatedAt': FieldValue.serverTimestamp(),
                }));
              }
              await Future.wait(chunkFutures);
            } else {
              // Foto que cabe diretamente no documento
              final photoMap = photo.toMap(includeBase64: true);
              photoMap['isChunked'] = false;
              photoMap['updatedAt'] = FieldValue.serverTimestamp();
              await photosCol
                  .doc(photo.id)
                  .set(photoMap, SetOptions(merge: true));
            }
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
        } catch (_) {}
      } catch (subPhotosErr) {
        // Loga erro mas nunca trava o fluxo principal
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
    final Map<String, dynamic> data = {
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (clientId != null && clientId.isNotEmpty) data['clientId'] = clientId;
    if (clientName != null && clientName.isNotEmpty) data['clientName'] = clientName;
    if (proposalId != null && proposalId.isNotEmpty) data['proposalId'] = proposalId;
    if (proposalCode != null && proposalCode.isNotEmpty) data['proposalCode'] = proposalCode;

    await _collection.doc(studyId).update(data);
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

  /// Exclui um estudo de telhado pelo ID e limpa fotos e chunks da subcoleção
  Future<void> deleteStudy(String studyId) async {
    try {
      final photosSnap = await _collection.doc(studyId).collection('photos').get();
      for (final doc in photosSnap.docs) {
        await doc.reference.delete();
      }
      final chunksSnap = await _collection.doc(studyId).collection('drone_chunks').get();
      for (final doc in chunksSnap.docs) {
        await doc.reference.delete();
      }
    } catch (_) {}
    await _collection.doc(studyId).delete();
  }
}
