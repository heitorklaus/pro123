import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Serviço para persistência do Modelo de Contrato Padrão Personalizado por Integrador / Empresa
class ContractSettingsService {
  static const _localCacheKeyPrefix = 'mavis_contract_custom_template_';
  static const _localTitleCacheKeyPrefix = 'mavis_contract_custom_title_';

  static DocumentReference<Map<String, dynamic>> _docRef(String companyId) {
    return FirebaseFirestore.instance
        .collection('companies')
        .doc(companyId)
        .collection('settings')
        .doc('contract_template');
  }

  /// Carrega o template customizado da empresa no Firestore ou cache local
  static Future<String?> getCompanyCustomTemplate(String? companyId) async {
    if (companyId == null || companyId.isEmpty) return null;

    try {
      final doc = await _docRef(companyId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final template = data['customTemplate'] as String?;
        if (template != null && template.trim().isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('$_localCacheKeyPrefix$companyId', template);
          return template;
        }
      }

      // Fallback cache local
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('$_localCacheKeyPrefix$companyId');
    } catch (e) {
      debugPrint('[ContractSettingsService] Erro ao carregar template customizado: $e');
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('$_localCacheKeyPrefix$companyId');
    }
  }

  /// Carrega o título padrão customizado da empresa
  static Future<String?> getCompanyCustomTitle(String? companyId) async {
    if (companyId == null || companyId.isEmpty) return null;

    try {
      final doc = await _docRef(companyId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final title = data['customTitle'] as String?;
        if (title != null && title.trim().isNotEmpty) {
          return title;
        }
      }
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('$_localTitleCacheKeyPrefix$companyId');
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('$_localTitleCacheKeyPrefix$companyId');
    }
  }

  /// Salva o template customizado do integrador para os próximos contratos
  static Future<void> saveCompanyCustomTemplate({
    required String companyId,
    required String templateContent,
    String? customTitle,
    String? userId,
  }) async {
    if (companyId.isEmpty) return;

    try {
      final data = <String, dynamic>{
        'customTemplate': templateContent,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': userId,
      };
      if (customTitle != null && customTitle.isNotEmpty) {
        data['customTitle'] = customTitle;
      }

      await _docRef(companyId).set(data, SetOptions(merge: true));

      // Salva em cache local
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_localCacheKeyPrefix$companyId', templateContent);
      if (customTitle != null) {
        await prefs.setString('$_localTitleCacheKeyPrefix$companyId', customTitle);
      }
    } catch (e) {
      debugPrint('[ContractSettingsService] Erro ao salvar template da empresa: $e');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_localCacheKeyPrefix$companyId', templateContent);
    }
  }

  /// Restaura o modelo do contrato para o padrão oficial do sistema
  static Future<void> resetCompanyTemplateToDefault({
    required String companyId,
  }) async {
    if (companyId.isEmpty) return;

    try {
      await _docRef(companyId).delete();

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_localCacheKeyPrefix$companyId');
      await prefs.remove('$_localTitleCacheKeyPrefix$companyId');
    } catch (e) {
      debugPrint('[ContractSettingsService] Erro ao resetar template: $e');
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_localCacheKeyPrefix$companyId');
      await prefs.remove('$_localTitleCacheKeyPrefix$companyId');
    }
  }
}
