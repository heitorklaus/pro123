import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../domain/models/solar_credit_models.dart';

class SolarCreditRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  SolarCreditRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _plantsRef =>
      _firestore.collection('solar_credit_plants');

  CollectionReference<Map<String, dynamic>> get _beneficiariesRef =>
      _firestore.collection('solar_credit_beneficiaries');

  CollectionReference<Map<String, dynamic>> get _billsRef =>
      _firestore.collection('solar_credit_bills');

  String _resolveCompanyId(String? companyId) {
    if (companyId != null && companyId.trim().isNotEmpty) {
      return companyId.trim();
    }
    return _auth.currentUser?.uid ?? 'default_company';
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 1. CRUD DE USINAS GERADORAS (ORIGEM DOS CRÉDITOS)
  // ═══════════════════════════════════════════════════════════════════════════
  Stream<List<SolarGeneratorPlantModel>> getPlantsStream({String? companyId}) {
    final cid = _resolveCompanyId(companyId);
    return _plantsRef
        .where('companyId', isEqualTo: cid)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((doc) => SolarGeneratorPlantModel.fromMap(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return list;
    });
  }

  Future<String> savePlant(
    SolarGeneratorPlantModel plant, {
    String? companyId,
  }) async {
    final cid = _resolveCompanyId(
      plant.companyId.isNotEmpty ? plant.companyId : companyId,
    );
    final now = DateTime.now();

    if (plant.id.isEmpty) {
      final docRef = _plantsRef.doc();
      final toSave = plant.copyWith(
        id: docRef.id,
        companyId: cid,
        createdAt: now,
        updatedAt: now,
      );
      await docRef.set(toSave.toMap());
      return docRef.id;
    } else {
      final toSave = plant.copyWith(
        companyId: cid,
        updatedAt: now,
      );
      await _plantsRef.doc(plant.id).set(toSave.toMap(), SetOptions(merge: true));

      // Sincroniza nome e regime da usina nos beneficiários vinculados
      try {
        final benSnap = await _beneficiariesRef
            .where('companyId', isEqualTo: cid)
            .get();
        if (benSnap.docs.isNotEmpty) {
          final batch = _firestore.batch();
          bool hasUpdates = false;
          for (final doc in benSnap.docs) {
            final ben = SolarCreditBeneficiaryModel.fromMap(doc.data(), doc.id);
            if (ben.receivesFromPlant(plant.id)) {
              final updatedAllocs = ben.effectivePlantAllocations.map((a) {
                if (a.generatorPlantId == plant.id) {
                  return a.copyWith(
                    generatorPlantName: plant.name,
                    generatorRegime: plant.regime,
                  );
                }
                return a;
              }).toList();
              batch.update(doc.reference, {
                if (ben.generatorPlantId == plant.id) ...{
                  'generatorPlantName': plant.name,
                  'generatorRegime': plant.regime.name,
                },
                'plantAllocations':
                    updatedAllocs.map((e) => e.toMap()).toList(),
                'updatedAt': Timestamp.fromDate(now),
              });
              hasUpdates = true;
            }
          }
          if (hasUpdates) {
            await batch.commit();
          }
        }
      } catch (e) {
        debugPrint('[SolarCreditRepository] Aviso ao sincronizar usina: $e');
      }

      return plant.id;
    }
  }

  Future<void> deletePlant(String plantId) async {
    await _plantsRef.doc(plantId).delete();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. CRUD DE CLIENTES / UNIDADES CONSUMIDORAS BENEFICIÁRIAS
  // ═══════════════════════════════════════════════════════════════════════════
  Stream<List<SolarCreditBeneficiaryModel>> getBeneficiariesStream({
    String? companyId,
  }) {
    final cid = _resolveCompanyId(companyId);
    return _beneficiariesRef
        .where('companyId', isEqualTo: cid)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((doc) =>
              SolarCreditBeneficiaryModel.fromMap(doc.data(), doc.id))
          .toList();
      list.sort(
        (a, b) =>
            a.clientName.toLowerCase().compareTo(b.clientName.toLowerCase()),
      );
      return list;
    });
  }

  Future<String> saveBeneficiary(
    SolarCreditBeneficiaryModel beneficiary, {
    String? companyId,
  }) async {
    final cid = _resolveCompanyId(
      beneficiary.companyId.isNotEmpty ? beneficiary.companyId : companyId,
    );
    final now = DateTime.now();

    if (beneficiary.id.isEmpty) {
      final docRef = _beneficiariesRef.doc();
      final toSave = beneficiary.copyWith(
        id: docRef.id,
        companyId: cid,
        createdAt: now,
        updatedAt: now,
      );
      await docRef.set(toSave.toMap());
      return docRef.id;
    } else {
      final toSave = beneficiary.copyWith(
        companyId: cid,
        updatedAt: now,
      );
      await _beneficiariesRef
          .doc(beneficiary.id)
          .set(toSave.toMap(), SetOptions(merge: true));
      return beneficiary.id;
    }
  }

  Future<void> deleteBeneficiary(String beneficiaryId) async {
    await _beneficiariesRef.doc(beneficiaryId).delete();
  }

  /// Atualiza diretamente a porcentagem de rateio na concessionária (por usina) e/ou deságio
  Future<void> updateBeneficiaryAllocation({
    required String beneficiaryId,
    required double newAllocationPercent,
    String? plantId,
    double? newDiscountPercent,
  }) async {
    final docSnap = await _beneficiariesRef.doc(beneficiaryId).get();
    final data = <String, dynamic>{
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    };

    if (docSnap.exists && docSnap.data() != null) {
      final ben = SolarCreditBeneficiaryModel.fromMap(
        docSnap.data()!,
        docSnap.id,
      );
      final updatedAllocs = ben.effectivePlantAllocations.map((a) {
        if (plantId == null ||
            plantId.isEmpty ||
            a.generatorPlantId == plantId) {
          return a.copyWith(allocationPercent: newAllocationPercent);
        }
        return a;
      }).toList();
      data['plantAllocations'] = updatedAllocs.map((e) => e.toMap()).toList();
      if (updatedAllocs.isNotEmpty) {
        data['utilityAllocationPercent'] =
            updatedAllocs.first.allocationPercent;
      }
    } else {
      data['utilityAllocationPercent'] = newAllocationPercent;
    }

    if (newDiscountPercent != null) {
      data['clientDiscountPercent'] = newDiscountPercent;
    }
    await _beneficiariesRef.doc(beneficiaryId).update(data);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. CRUD DE LANÇAMENTOS MENSAIS DE CONTAS DE ENERGIA & BOLETOS
  // ═══════════════════════════════════════════════════════════════════════════
  Stream<List<SolarCreditBillModel>> getBillsStream({String? companyId}) {
    final cid = _resolveCompanyId(companyId);
    return _billsRef
        .where('companyId', isEqualTo: cid)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((doc) => SolarCreditBillModel.fromMap(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Future<String> saveBill(
    SolarCreditBillModel bill, {
    String? companyId,
  }) async {
    final cid = _resolveCompanyId(
      bill.companyId.isNotEmpty ? bill.companyId : companyId,
    );
    final now = DateTime.now();

    String savedId = bill.id;
    if (savedId.isEmpty) {
      final docRef = _billsRef.doc();
      savedId = docRef.id;
      final data = bill.toMap();
      data['companyId'] = cid;
      data['createdAt'] = Timestamp.fromDate(now);
      data['updatedAt'] = Timestamp.fromDate(now);
      await docRef.set(data);
    } else {
      final data = bill.toMap();
      data['companyId'] = cid;
      data['updatedAt'] = Timestamp.fromDate(now);
      await _billsRef.doc(savedId).set(data, SetOptions(merge: true));
    }

    // Atualiza automaticamente os indicadores do Cliente / UC Beneficiária
    if (bill.beneficiaryId.isNotEmpty) {
      try {
        double avgConsumption = bill.consumptionKwh;
        if (bill.consumptionHistory.isNotEmpty) {
          final validMonths = bill.consumptionHistory
              .where((m) => m.consumptionKwh > 0)
              .toList();
          if (validMonths.isNotEmpty) {
            final sum = validMonths.fold<double>(
              0.0,
              (acc, item) => acc + item.consumptionKwh,
            );
            avgConsumption = sum / validMonths.length;
          }
        }

        await _beneficiariesRef.doc(bill.beneficiaryId).set({
          'lastAccumulatedBalanceKwh': bill.accumulatedBalanceKwh,
          'lastInjectedKwh': bill.totalInjectedKwh,
          'averageMonthlyConsumptionKwh': avgConsumption,
          'lastReferenceMonth': bill.referenceMonth,
          'updatedAt': Timestamp.fromDate(now),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint(
          '[SolarCreditRepository] Aviso ao atualizar saldo do beneficiário: $e',
        );
      }
    }

    return savedId;
  }

  Future<void> updateBillPaymentStatus(String billId, String status) async {
    await _billsRef.doc(billId).update({
      'paymentStatus': status,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> deleteBill(String billId) async {
    await _billsRef.doc(billId).delete();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 4. MATCH INTELIGENTE DE CLIENTE / UC A PARTIR DA CONTA EXPLODIDA PELA IA
  // ═══════════════════════════════════════════════════════════════════════════
  static SolarCreditBeneficiaryModel? findMatchingBeneficiary({
    required String extractedUcNumber,
    required String extractedStreet,
    required List<SolarCreditBeneficiaryModel> beneficiaries,
  }) {
    if (beneficiaries.isEmpty) return null;

    final cleanUc = extractedUcNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanUc.isNotEmpty) {
      // 1. Match exato pelos dígitos da UC
      for (final b in beneficiaries) {
        final bDigits = b.normalizedUcDigits;
        if (bDigits.isNotEmpty &&
            (bDigits == cleanUc ||
                bDigits.endsWith(cleanUc) ||
                cleanUc.endsWith(bDigits))) {
          return b;
        }
      }
    }

    // 2. Match por endereço (Logradouro + Número)
    final cleanStreet = extractedStreet.toLowerCase().trim();
    if (cleanStreet.length >= 5) {
      for (final b in beneficiaries) {
        final bStreet = b.addressStreet.toLowerCase().trim();
        if (bStreet.isNotEmpty &&
            (cleanStreet.contains(bStreet) || bStreet.contains(cleanStreet))) {
          return b;
        }
      }
    }

    return null;
  }
}

