import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/client_model.dart';

/// Repositório de Clientes — integrado ao Cloud Firestore (`clients/`)
class ClientRepository {
  final FirebaseFirestore _firestore;

  ClientRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('clients');

  // ── Stream em tempo real ──────────────────────────────────────────────────
  Stream<List<ClientModel>> getClientsStream({String? companyId}) {
    if (companyId == null || companyId.isEmpty) {
      return Stream.value([]);
    }
    final query = _collection.where('companyId', isEqualTo: companyId);
    return query.snapshots().map((snap) {
      final list = snap.docs
          .map((doc) => ClientModel.fromMap(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  // ── Criar Cliente ─────────────────────────────────────────────────────────
  Future<void> createClient({
    required String name,
    required String email,
    String? phone,
    String? document,
    ClientType type = ClientType.person,
    String? company,
    String? zipCode,
    String? street,
    String? addressNumber,
    String? complement,
    String? neighborhood,
    String? city,
    String? state,
    String? notes,
    String? companyId,
  }) async {
    final now = DateTime.now();
    final ref = _collection.doc();

    final client = ClientModel(
      id: ref.id,
      name: name.trim(),
      email: email.trim().toLowerCase(),
      phone: phone?.trim(),
      document: document?.trim(),
      type: type,
      status: ClientStatus.active,
      company: company?.trim(),
      zipCode: zipCode?.trim(),
      street: street?.trim(),
      addressNumber: addressNumber?.trim(),
      complement: complement?.trim(),
      neighborhood: neighborhood?.trim(),
      city: city?.trim(),
      state: state?.trim(),
      notes: notes?.trim(),
      companyId: companyId,
      createdAt: now,
      updatedAt: now,
    );

    await ref.set(client.toMap());
  }

  // ── Atualizar Cliente ─────────────────────────────────────────────────────
  Future<void> updateClient(ClientModel client) async {
    await _collection.doc(client.id).update({
      ...client.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Excluir Cliente ───────────────────────────────────────────────────────
  Future<void> deleteClient(String clientId) async {
    await _collection.doc(clientId).delete();
  }

  // ── Buscar por ID ─────────────────────────────────────────────────────────
  Future<ClientModel?> getClientById(String clientId) async {
    final doc = await _collection.doc(clientId).get();
    if (!doc.exists || doc.data() == null) return null;
    return ClientModel.fromMap(doc.data()!, doc.id);
  }
}
