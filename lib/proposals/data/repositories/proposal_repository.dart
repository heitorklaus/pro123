import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/proposal_model.dart';
import '../../domain/models/proposal_item_model.dart';

/// Repositório de persistência e consultas da coleção 'proposals' no Cloud Firestore
class ProposalRepository {
  final FirebaseFirestore _firestore;

  ProposalRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _proposalsRef =>
      _firestore.collection('proposals');

  /// Stream em tempo real da lista de propostas ordenadas pela data de criação
  Stream<List<ProposalModel>> getProposalsStream({String? companyId}) {
    if (companyId == null || companyId.isEmpty) {
      return Stream.value([]);
    }
    final query = _proposalsRef.where('companyId', isEqualTo: companyId);
    return query.snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => ProposalModel.fromMap(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Gera um código sequencial de proposta amigável (ex: PROP-2026-001)
  Future<String> generateProposalNumber() async {
    final year = DateTime.now().year;
    try {
      final snap = await _proposalsRef
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        return 'PROP-$year-001';
      }

      final lastDoc = snap.docs.first.data();
      final lastNumStr = lastDoc['proposalNumber'] as String?;
      if (lastNumStr != null && lastNumStr.startsWith('PROP-$year-')) {
        final parts = lastNumStr.split('-');
        if (parts.length >= 3) {
          final seq = int.tryParse(parts[2]) ?? 0;
          final nextSeq = (seq + 1).toString().padLeft(3, '0');
          return 'PROP-$year-$nextSeq';
        }
      }

      return 'PROP-$year-001';
    } catch (_) {
      final rand = DateTime.now().millisecondsSinceEpoch % 1000;
      return 'PROP-$year-${rand.toString().padLeft(3, '0')}';
    }
  }

  /// Cria uma nova proposta comercial no Firestore
  Future<ProposalModel> createProposal({
    required String title,
    String? clientId,
    required String clientName,
    String? clientEmail,
    String? clientPhone,
    String? clientDocument,
    String? clientAddress,
    required List<ProposalItemModel> items,
    required double subtotal,
    double discount = 0.0,
    double shippingFee = 0.0,
    required double totalAmount,
    String paymentTerms = 'À vista via PIX',
    int validityDays = 15,
    String? deliveryTime,
    String? notes,
    int themeColorValue = 0xFF4F46E5,
    ProposalStatus status = ProposalStatus.draft,
    String? companyId,
  }) async {
    final now = DateTime.now();
    final docRef = _proposalsRef.doc();
    final proposalNumber = await generateProposalNumber();

    final proposal = ProposalModel(
      id: docRef.id,
      proposalNumber: proposalNumber,
      title: title.trim(),
      clientId: clientId?.trim(),
      clientName: clientName.trim(),
      clientEmail: clientEmail?.trim(),
      clientPhone: clientPhone?.trim(),
      clientDocument: clientDocument?.trim(),
      clientAddress: clientAddress?.trim(),
      items: items,
      subtotal: subtotal,
      discount: discount,
      shippingFee: shippingFee,
      totalAmount: totalAmount,
      paymentTerms: paymentTerms.trim(),
      validityDays: validityDays,
      deliveryTime: deliveryTime?.trim(),
      notes: notes?.trim(),
      themeColorValue: themeColorValue,
      status: status,
      companyId: companyId,
      createdAt: now,
      updatedAt: now,
    );

    await docRef.set(proposal.toMap());
    return proposal;
  }

  /// Atualiza os dados de uma proposta existente
  Future<void> updateProposal(ProposalModel proposal) async {
    final updated = proposal.copyWith(updatedAt: DateTime.now());
    await _proposalsRef.doc(proposal.id).update(updated.toMap());
  }

  /// Altera apenas o status de uma proposta
  Future<void> updateStatus(String id, ProposalStatus newStatus) async {
    await _proposalsRef.doc(id).update({
      'status': newStatus.name,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Remove uma proposta do Firestore
  Future<void> deleteProposal(String id) async {
    await _proposalsRef.doc(id).delete();
  }
}
