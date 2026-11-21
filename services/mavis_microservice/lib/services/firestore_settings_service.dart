import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/proposal_dto.dart';
import '../models/solar_settings_dto.dart';

/// Serviço que busca as configurações de Usina Solar e Capa (`sector_settings/solarPlant`)
/// do Cloud Firestore (`mavis-crm-80885`) com cache em memória (TTL 5 minutos) e fallback
/// automático caso a cota do Firestore esteja esgotada (HTTP 429 RESOURCE_EXHAUSTED).
class FirestoreSettingsService {
  static const String _projectId = 'mavis-crm-80885';
  static const String _baseUrl =
      'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents';

  static final Map<String, Map<String, dynamic>> _docCache = {};
  static final Map<String, DateTime> _docCacheTime = {};
  static const Duration _cacheTtl = Duration(minutes: 5);

  static Future<SolarSettingsDTO> resolveSettings({
    required ProposalDTO proposal,
    Map<String, dynamic>? requestSettingsMap,
  }) async {
    final List<String> candidateCompanyIds = [];
    if (proposal.companyId != null &&
        proposal.companyId!.trim().isNotEmpty &&
        proposal.companyId != 'default_company') {
      candidateCompanyIds.add(proposal.companyId!.trim());
    }

    if (requestSettingsMap != null && requestSettingsMap['companyId'] != null) {
      final reqCid = requestSettingsMap['companyId'].toString().trim();
      if (reqCid.isNotEmpty && !candidateCompanyIds.contains(reqCid)) {
        candidateCompanyIds.add(reqCid);
      }
    }

    if (proposal.createdByUserId != null &&
        proposal.createdByUserId!.trim().isNotEmpty &&
        proposal.createdByUserId != 'default_user') {
      final uid = proposal.createdByUserId!.trim();
      if (!candidateCompanyIds.contains(uid)) {
        candidateCompanyIds.add(uid);
      }
    }

    for (final fallbackCid in [
      'GLOBAL_MASTER',
      '5NqpP8D5qRfbu7s8ZouYu1NIcKv1',
      '0Y5DVRzkIQXrb6wyyUwxslbxeOB2'
    ]) {
      if (!candidateCompanyIds.contains(fallbackCid)) {
        candidateCompanyIds.add(fallbackCid);
      }
    }

    Map<String, dynamic>? foundSolarSettings;
    String? resolvedCid;

    for (final cid in candidateCompanyIds) {
      final docMap = await _fetchFirestoreDoc('companies/$cid/sector_settings/solarPlant');
      if (docMap == null && _lastStatusWasQuotaExceeded) {
        // Se o Firestore retornou 429 (Quota Exceeded), interrompe buscas extras imediatamente
        break;
      }
      if (docMap != null && docMap.isNotEmpty) {
        foundSolarSettings = docMap;
        resolvedCid = cid;
        break;
      }
    }

    final Map<String, dynamic> merged = {};

    if (requestSettingsMap != null && requestSettingsMap.isNotEmpty) {
      merged.addAll(requestSettingsMap);
    }

    if (foundSolarSettings != null) {
      merged.addAll(foundSolarSettings);
      print('✅ [FirestoreSettingsService] Configurações da empresa ($resolvedCid) aplicadas!');
    }

    final targetCompanyId = resolvedCid ?? (candidateCompanyIds.isNotEmpty ? candidateCompanyIds.first : null);
    if (targetCompanyId != null && !_lastStatusWasQuotaExceeded) {
      final companyDoc = await _fetchFirestoreDoc('companies/$targetCompanyId');
      if (companyDoc != null && companyDoc.isNotEmpty) {
        void fillIfEmpty(String targetKey, dynamic fallbackValue) {
          if (fallbackValue == null) return;
          final str = fallbackValue.toString().trim();
          if (str.isEmpty) return;
          final current = merged[targetKey]?.toString().trim() ?? '';
          if (current.isEmpty) {
            merged[targetKey] = str;
          }
        }

        fillIfEmpty('companyName', companyDoc['name'] ?? companyDoc['tradeName']);
        fillIfEmpty('companyDocument', companyDoc['document'] ?? companyDoc['cnpj']);
        fillIfEmpty('companyPhone', companyDoc['phone']);
        fillIfEmpty('companyWebsite', companyDoc['website']);
        fillIfEmpty('companyInstagram', companyDoc['instagram']);
        fillIfEmpty('companySlogan', companyDoc['slogan']);
        fillIfEmpty('companyLogoBase64', companyDoc['logoBase64']);
      }
    }

    return SolarSettingsDTO.fromMap(merged);
  }

  static bool _lastStatusWasQuotaExceeded = false;

  static Future<Map<String, dynamic>?> _fetchFirestoreDoc(String relativePath) async {
    final now = DateTime.now();
    if (_docCache.containsKey(relativePath) && _docCacheTime.containsKey(relativePath)) {
      if (now.difference(_docCacheTime[relativePath]!) < _cacheTtl) {
        return _docCache[relativePath];
      }
    }

    try {
      final uri = Uri.parse('$_baseUrl/$relativePath');
      final response = await http.get(uri).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        _lastStatusWasQuotaExceeded = false;
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded['fields'] is Map<String, dynamic>) {
          final map = _decodeFieldsMap(decoded['fields'] as Map<String, dynamic>);
          _docCache[relativePath] = map;
          _docCacheTime[relativePath] = now;
          return map;
        }
      } else if (response.statusCode == 429) {
        _lastStatusWasQuotaExceeded = true;
        print('⚠️ [FirestoreSettingsService] Firestore HTTP 429 (Quota Exceeded). Usando cache/fallback.');
        return _docCache[relativePath];
      }
    } catch (e) {
      print('⚠️ [FirestoreSettingsService] Falha ao ler $relativePath: $e');
    }
    return _docCache[relativePath];
  }

  static Map<String, dynamic> _decodeFieldsMap(Map<String, dynamic> fields) {
    final result = <String, dynamic>{};
    fields.forEach((key, value) {
      result[key] = _decodeFirestoreValue(value);
    });
    return result;
  }

  static dynamic _decodeFirestoreValue(dynamic value) {
    if (value is! Map<String, dynamic>) return value;
    if (value.containsKey('stringValue')) return value['stringValue']?.toString() ?? '';
    if (value.containsKey('booleanValue')) return value['booleanValue'] == true;
    if (value.containsKey('integerValue')) {
      return int.tryParse(value['integerValue'].toString()) ?? 0;
    }
    if (value.containsKey('doubleValue')) {
      return (value['doubleValue'] as num?)?.toDouble() ??
          double.tryParse(value['doubleValue'].toString()) ??
          0.0;
    }
    if (value.containsKey('nullValue')) return null;
    if (value.containsKey('timestampValue')) return value['timestampValue']?.toString();
    if (value.containsKey('mapValue')) {
      final mapVal = value['mapValue'];
      if (mapVal is Map<String, dynamic> && mapVal['fields'] is Map<String, dynamic>) {
        return _decodeFieldsMap(mapVal['fields'] as Map<String, dynamic>);
      }
      return <String, dynamic>{};
    }
    if (value.containsKey('arrayValue')) {
      final arrVal = value['arrayValue'];
      if (arrVal is Map<String, dynamic> && arrVal['values'] is List) {
        return (arrVal['values'] as List).map(_decodeFirestoreValue).toList();
      }
      return <dynamic>[];
    }
    return null;
  }
}
