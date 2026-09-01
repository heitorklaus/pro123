import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../domain/models/ai_agent_settings_model.dart';

class AiAgentSettingsService {
  static const _localCacheKeyPrefix = 'mavis_ai_agent_settings_';

  /// Retorna as configurações do Agente de IA da empresa ativa
  static Future<AiAgentSettingsModel> getSettings({String? companyId}) async {
    try {
      String? cid = companyId;
      if (cid == null || cid.isEmpty) {
        final auth = AuthRepository();
        cid = await auth.getCurrentCompanyId();
      }

      // 1. Busca no Cloud Firestore da empresa
      if (cid != null && cid.isNotEmpty) {
        final doc = await FirebaseFirestore.instance
            .collection('companies')
            .doc(cid)
            .collection('settings')
            .doc('ai_agent')
            .get();

        if (doc.exists && doc.data() != null) {
          final model = AiAgentSettingsModel.fromMap(doc.data()!, companyId: cid);
          await _cacheLocalSettings(model, cid);
          return model;
        }
      }

      // 2. Fallback no cache local
      final local = await _loadLocalSettings(cid);
      if (local != null) return local;
    } catch (e) {
      debugPrint('[AiAgentSettingsService] Erro ao buscar configurações: $e');
    }

    // 3. Padrão oficial (DEFAULT)
    return AiAgentSettingsModel.defaultSettings(companyId: companyId);
  }

  /// Salva as configurações de IA no Firestore da empresa e no cache local
  static Future<void> saveSettings(AiAgentSettingsModel settings, {String? companyId}) async {
    try {
      String? cid = companyId ?? settings.companyId;
      if (cid == null || cid.isEmpty) {
        final auth = AuthRepository();
        cid = await auth.getCurrentCompanyId();
      }

      final updated = settings.copyWith(
        companyId: cid,
        updatedAt: DateTime.now(),
      );

      if (cid != null && cid.isNotEmpty) {
        await _cacheLocalSettings(updated, cid);

        await FirebaseFirestore.instance
            .collection('companies')
            .doc(cid)
            .collection('settings')
            .doc('ai_agent')
            .set(updated.toMap(), SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('[AiAgentSettingsService] Erro ao salvar configurações de IA: $e');
      rethrow;
    }
  }

  /// Restaura as configurações padrão (DEFAULT) para a empresa
  static Future<AiAgentSettingsModel> restoreDefaults({String? companyId}) async {
    String? cid = companyId;
    if (cid == null || cid.isEmpty) {
      final auth = AuthRepository();
      cid = await auth.getCurrentCompanyId();
    }

    final defaultModel = AiAgentSettingsModel.defaultSettings(companyId: cid);
    await saveSettings(defaultModel, companyId: cid);
    return defaultModel;
  }

  /// Monta o prompt do sistema completo e enriquecido com todas as preferências da empresa
  static String buildEffectiveSystemPrompt(AiAgentSettingsModel settings) {
    final buffer = StringBuffer();
    buffer.writeln(settings.systemInstruction.trim());

    // Regras Comerciais Personalizadas da Empresa
    if (settings.customCommercialRules.trim().isNotEmpty) {
      buffer.writeln('\n---');
      buffer.writeln('DIRETRIZES E REGRAS COMERCIAIS ESPECÍFICAS DESTA EMPRESA:');
      buffer.writeln(settings.customCommercialRules.trim());
    }

    // Preferências de Parceiros e Marcas
    buffer.writeln('\n---');
    buffer.writeln('PREFERÊNCIAS DE MARCAS E DISTRIBUIDORAS:');
    if (settings.preferredDistributors.isNotEmpty) {
      buffer.writeln('• Distribuidoras Parceiras: ${settings.preferredDistributors.join(', ')}');
    }
    if (settings.preferredModuleBrands.isNotEmpty) {
      buffer.writeln('• Módulos Preferenciais: ${settings.preferredModuleBrands.join(', ')}');
    }
    if (settings.preferredInverterBrands.isNotEmpty) {
      buffer.writeln('• Inversores Preferenciais: ${settings.preferredInverterBrands.join(', ')}');
    }
    buffer.writeln('• Tipo de telhado padrão sugerido: ${settings.defaultRoofType}');
    buffer.writeln('• Fator de geração médio regional: ${settings.defaultGenerationFactor} kWh/kWp');
    buffer.writeln('• Margem/serviço estimado padrão: ${settings.defaultServicePriceMarginPercent}%');

    // Exemplos de Treinamento (Few-Shot) Ativos
    final activeExamples = settings.trainingExamples.where((e) => e.isActive).toList();
    if (activeExamples.isNotEmpty) {
      buffer.writeln('\n---');
      buffer.writeln('EXEMPLOS DE TREINAMENTO REAL DA EMPRESA (SIGA ESTES PADRÕES DE RACIOCÍNIO):');
      for (int i = 0; i < activeExamples.length; i++) {
        final ex = activeExamples[i];
        buffer.writeln('EXEMPLO ${i + 1} - ${ex.title}:');
        buffer.writeln('Entrada do Usuário: "${ex.userInput}"');
        buffer.writeln('Comportamento Esperado: ${ex.expectedOutput}\n');
      }
    }

    return buffer.toString();
  }

  static Future<void> _cacheLocalSettings(AiAgentSettingsModel model, String? cid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_localCacheKeyPrefix${cid ?? "default"}';
      await prefs.setString(key, jsonEncode(model.toMap()));
    } catch (_) {}
  }

  static Future<AiAgentSettingsModel?> _loadLocalSettings(String? cid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_localCacheKeyPrefix${cid ?? "default"}';
      final str = prefs.getString(key);
      if (str != null && str.isNotEmpty) {
        final map = jsonDecode(str) as Map<String, dynamic>;
        return AiAgentSettingsModel.fromMap(map, companyId: cid);
      }
    } catch (_) {}
    return null;
  }
}
