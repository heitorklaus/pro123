import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../clients/domain/models/client_model.dart';
import '../../domain/models/solar_site_model.dart';

class SolarSiteRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _sitesRef =>
      _db.collection('company_sites');

  Future<SolarSiteConfig?> getSiteByCompanyId(String companyId) async {
    final doc = await _sitesRef.doc(companyId).get();
    if (!doc.exists || doc.data() == null) return null;
    return SolarSiteConfig.fromMap(doc.data()!, doc.id);
  }

  Future<SolarSiteConfig?> getSiteBySlug(String slug) async {
    final clean = slug.trim().toLowerCase();
    if (clean.isEmpty) return null;

    final snap = await _sitesRef
        .where('slug', isEqualTo: clean)
        .where('isPublished', isEqualTo: true)
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) {
      final d = snap.docs.first;
      return SolarSiteConfig.fromMap(d.data(), d.id);
    }

    // Fallback por companyId direto
    final direct = await _sitesRef.doc(slug).get();
    if (direct.exists && direct.data() != null) {
      final cfg = SolarSiteConfig.fromMap(direct.data()!, direct.id);
      if (cfg.isPublished) return cfg;
    }
    return null;
  }

  Future<void> saveSite(SolarSiteConfig config) async {
    await _sitesRef
        .doc(config.companyId)
        .set(config.toMap(), SetOptions(merge: true));
  }

  /// Cadastra automaticamente um lead (Prospect) no CRM da empresa quando
  /// o visitante envia o formulário da Calculadora Solar na One-Page.
  Future<void> submitLeadFromSite({
    required String companyId,
    required String name,
    required String phone,
    required String email,
    required String city,
    required double monthlyBillRs,
    required double estimatedKwp,
  }) async {
    final now = DateTime.now();
    final ref = _db.collection('clients').doc();
    final client = ClientModel(
      id: ref.id,
      name: name.trim(),
      email: email.trim().isNotEmpty
          ? email.trim().toLowerCase()
          : 'lead-site@pendente.com',
      phone: phone.trim(),
      type: ClientType.person,
      status: ClientStatus.prospect,
      city: city.trim().isNotEmpty ? city.trim() : null,
      notes:
          'Lead captado pelo Site One-Page • Conta média: R\$ ${monthlyBillRs.toStringAsFixed(2)}/mês • Potência estimada: ${estimatedKwp.toStringAsFixed(2)} kWp.',
      companyId: companyId,
      isPublicForCompany: true,
      createdAt: now,
      updatedAt: now,
    );
    await ref.set(client.toMap());
  }
}
