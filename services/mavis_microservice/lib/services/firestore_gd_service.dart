import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/solar_credit_dto.dart';

/// Serviço de consulta e lançamento de Créditos Solares (GD) no Cloud Firestore.
/// Restrito inicialmente à conta master `admin@admin.com.br`.
class FirestoreGdService {
  static const String _projectId = 'mavis-crm-80885';
  static const String _documentsBaseUrl =
      'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents';
  static const Set<String> _allowedEmails = {
    'admin@admin.com.br',
    'heitorklaus@hotmail.com',
  };
  static const Set<String> _knownAdminCompanyIds = {
    'XeKKr3jD1WdmyHJJNayTEX18x9I2',
    '0Y5DVRzkIQXrb6wyyUwxslbxeOB2',
    '5NqpP8D5qRfbu7s8ZouYu1NIcKv1',
  };

  static bool isAllowedForAdmin({String? ownerEmail, String? companyId}) {
    final email = (ownerEmail ?? '').trim().toLowerCase();
    if (email.isNotEmpty) {
      return _allowedEmails.contains(email);
    }
    final cid = (companyId ?? '').trim();
    if (cid.isNotEmpty) {
      return _knownAdminCompanyIds.contains(cid);
    }
    return false;
  }

  /// Busca um recebedor de créditos cadastrado em `solar_credit_beneficiaries` pelo número da UC
  static Future<GdBeneficiaryDTO?> findBeneficiaryByUc({
    required String ucNumber,
    String? companyId,
  }) async {
    final digits = ucNumber.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null;

    final queryUrl = Uri.parse('$_documentsBaseUrl:runQuery');
    final filters = <Map<String, dynamic>>[
      {
        'fieldFilter': {
          'field': {'fieldPath': 'normalizedUcDigits'},
          'op': 'EQUAL',
          'value': {'stringValue': digits},
        },
      },
    ];

    if (companyId != null && companyId.trim().isNotEmpty) {
      filters.add({
        'fieldFilter': {
          'field': {'fieldPath': 'companyId'},
          'op': 'EQUAL',
          'value': {'stringValue': companyId.trim()},
        },
      });
    }

    final body = {
      'structuredQuery': {
        'from': [
          {'collectionId': 'solar_credit_beneficiaries'}
        ],
        'where': filters.length == 1
            ? filters.first
            : {
                'compositeFilter': {
                  'op': 'AND',
                  'filters': filters,
                },
              },
        'limit': 5,
      },
    };

    try {
      final resp = await http
          .post(
            queryUrl,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 8));

      if (resp.statusCode != 200) {
        print('⚠️ [FirestoreGdService] runQuery falhou (${resp.statusCode}): ${resp.body}');
        return null;
      }

      final decoded = jsonDecode(resp.body);
      if (decoded is! List) return null;

      for (final row in decoded) {
        if (row is! Map || row['document'] == null) continue;
        final doc = Map<String, dynamic>.from(row['document'] as Map);
        final name = (doc['name'] ?? '').toString();
        final docId = name.split('/').last;
        final fields = doc['fields'] as Map<String, dynamic>? ?? {};
        final map = _decodeFirestoreFields(fields);
        final beneficiary = GdBeneficiaryDTO.fromMap(map, docId);
        if (beneficiary.status != 'inactive') {
          return beneficiary;
        }
      }
      return null;
    } catch (e) {
      print('⚠️ [FirestoreGdService] Erro ao buscar UC $digits: $e');
      return null;
    }
  }

  /// Grava o demonstrativo/boleto calculado na coleção `solar_credit_bills` do Firestore
  static Future<String?> saveBillToFirestore(GdBillCalculationDTO calc) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final url = Uri.parse('$_documentsBaseUrl/solar_credit_bills');

    final fields = _encodeFirestoreMap({
      'companyId': calc.beneficiary.companyId,
      'beneficiaryId': calc.beneficiary.id,
      'clientName': calc.beneficiary.clientName,
      'clientPhone': calc.beneficiary.clientPhone,
      'accountHolderName': calc.accountHolderName,
      'ucNumber': calc.ucNumber,
      'addressStreet': calc.addressStreet,
      'addressFull': calc.addressStreet,
      'generatorPlantId': calc.beneficiary.generatorPlantId,
      'generatorPlantName': calc.beneficiary.generatorPlantName,
      'generatorRegime': calc.beneficiary.generatorRegime,
      'utilityAllocationPercent': calc.utilityAllocationPercent,
      'clientDiscountPercent': calc.clientDiscountPercent,
      'referenceMonth': calc.referenceMonth,
      'dueDate': calc.dueDate,
      'consumptionKwh': calc.consumptionKwh,
      'consumptionValueRs': calc.consumptionValueRs,
      'injectedLines': calc.injectedLines.map((e) => e.toMap()).toList(),
      'injectedGdiKwh': calc.injectedGdiKwh,
      'injectedGdiValueRs': calc.injectedGdiValueRs,
      'injectedGdiiKwh': calc.injectedGdiiKwh,
      'injectedGdiiValueRs': calc.injectedGdiiValueRs,
      'totalInjectedKwh': calc.totalInjectedKwh,
      'totalInjectedGrossValueRs': calc.totalInjectedGrossValueRs,
      'gdAdjustmentKwh': calc.gdAdjustmentKwh,
      'gdAdjustmentTariff': calc.gdAdjustmentTariff,
      'gdAdjustmentValueRs': calc.gdAdjustmentValueRs,
      'publicLightingValueRs': calc.publicLightingValueRs,
      'finesAndInterestValueRs': calc.finesAndInterestValueRs,
      'otherChargesValueRs': calc.otherChargesValueRs,
      'utilityBillTotalToPayRs': calc.utilityBillTotalToPayRs,
      'accumulatedBalanceKwh': calc.accumulatedBalanceKwh,
      'netCompensatedCreditRs': calc.netCompensatedCreditRs,
      'solarCompanyAmountToPayRs': calc.solarCompanyAmountToPayRs,
      'totalWithSolarCompanyRs': calc.totalWithSolarCompanyRs,
      'totalWithoutSolarCompanyRs': calc.totalWithoutSolarCompanyRs,
      'monthlySavingsRs': calc.monthlySavingsRs,
      'annualProjectedSavingsRs': calc.annualProjectedSavingsRs,
      'paymentStatus': 'pending',
      'source': 'whatsapp_agent',
      'createdAt': DateTime.now().toUtc(),
      'updatedAt': DateTime.now().toUtc(),
    });

    // Garante timestamp válido no payload caso não use DateTime
    fields['createdAt'] = {'timestampValue': nowIso};
    fields['updatedAt'] = {'timestampValue': nowIso};

    try {
      final resp = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'fields': fields}),
          )
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
        final docName = (decoded['name'] ?? '').toString();
        return docName.split('/').last;
      }
      print('⚠️ [FirestoreGdService] Erro ao salvar fatura (${resp.statusCode}): ${resp.body}');
      return null;
    } catch (e) {
      print('⚠️ [FirestoreGdService] Exceção ao salvar fatura: $e');
      return null;
    }
  }

  static Map<String, dynamic> _decodeFirestoreFields(Map<String, dynamic> fields) {
    final result = <String, dynamic>{};
    fields.forEach((key, val) {
      if (val is Map<String, dynamic>) {
        result[key] = _decodeFirestoreValue(val);
      }
    });
    return result;
  }

  static dynamic _decodeFirestoreValue(Map<String, dynamic> val) {
    if (val.containsKey('stringValue')) return val['stringValue'];
    if (val.containsKey('integerValue')) return int.tryParse(val['integerValue'].toString()) ?? 0;
    if (val.containsKey('doubleValue')) return (val['doubleValue'] as num).toDouble();
    if (val.containsKey('booleanValue')) return val['booleanValue'] == true;
    if (val.containsKey('timestampValue')) return val['timestampValue'];
    if (val.containsKey('nullValue')) return null;
    if (val.containsKey('arrayValue')) {
      final arr = val['arrayValue'] as Map<String, dynamic>? ?? {};
      final values = arr['values'] as List<dynamic>? ?? [];
      return values.whereType<Map<String, dynamic>>().map(_decodeFirestoreValue).toList();
    }
    if (val.containsKey('mapValue')) {
      final mv = val['mapValue'] as Map<String, dynamic>? ?? {};
      final fields = mv['fields'] as Map<String, dynamic>? ?? {};
      return _decodeFirestoreFields(fields);
    }
    return null;
  }

  static Map<String, dynamic> _encodeFirestoreMap(Map<String, dynamic> map) {
    final out = <String, dynamic>{};
    map.forEach((key, value) {
      out[key] = _encodeFirestoreValue(value);
    });
    return out;
  }

  static Map<String, dynamic> _encodeFirestoreValue(dynamic v) {
    if (v == null) return {'nullValue': null};
    if (v is bool) return {'booleanValue': v};
    if (v is int) return {'integerValue': v.toString()};
    if (v is double) return {'doubleValue': v};
    if (v is DateTime) return {'timestampValue': v.toUtc().toIso8601String()};
    if (v is List) {
      return {
        'arrayValue': {
          'values': v.map(_encodeFirestoreValue).toList(),
        },
      };
    }
    if (v is Map) {
      return {
        'mapValue': {
          'fields': _encodeFirestoreMap(Map<String, dynamic>.from(v)),
        },
      };
    }
    return {'stringValue': v.toString()};
  }
}
