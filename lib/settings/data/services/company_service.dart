import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../domain/models/company_model.dart';
import 'solar_settings_service.dart';

/// Serviço responsável pelo gerenciamento de dados cadastrais, endereço e logomarca da Empresa no Firestore
class CompanyService {
  static const _localCompanyCacheKey = 'mavis_company_profile_cache';

  /// Retorna o ID da empresa ativa do usuário autenticado
  static Future<String?> getEffectiveCompanyId([String? companyId]) async {
    if (companyId != null && companyId.isNotEmpty) return companyId;
    final auth = AuthRepository();
    return await auth.getCurrentCompanyId();
  }

  /// Carrega os dados da empresa do Firestore ou cache local
  static Future<CompanyModel?> getCompany({String? companyId}) async {
    try {
      final cid = await getEffectiveCompanyId(companyId);
      if (cid != null && cid.isNotEmpty) {
        final doc = await FirebaseFirestore.instance
            .collection('companies')
            .doc(cid)
            .get();

        if (doc.exists && doc.data() != null) {
          final model = CompanyModel.fromMap(doc.data()!, cid);
          _cacheLocalCompany(model);
          return model;
        }
      }

      // Fallback no cache local
      final local = await _loadLocalCompany();
      return local;
    } catch (e) {
      debugPrint('[CompanyService] Erro ao carregar perfil da empresa: $e');
      return await _loadLocalCompany();
    }
  }

  /// Salva ou atualiza os dados da empresa no Firestore e sincroniza com os nichos
  static Future<void> saveCompany(CompanyModel company) async {
    try {
      final cid = await getEffectiveCompanyId(company.id);
      final effectiveId = (cid != null && cid.isNotEmpty) ? cid : company.id;

      final updatedCompany = company.copyWith(
        id: effectiveId,
        updatedAt: DateTime.now(),
      );

      // 1. Salva no cache local
      await _cacheLocalCompany(updatedCompany);

      // 2. Salva no documento raiz da empresa no Firestore
      if (effectiveId.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('companies')
            .doc(effectiveId)
            .set(updatedCompany.toMap(), SetOptions(merge: true));

        // 3. Sincroniza os dados institucionais e a logomarca com as configurações de Usina Solar (PDF / Proposta Web)
        try {
          final solarSettings = await SolarSettingsService.loadSettings(companyId: effectiveId);
          final mergedSolar = solarSettings.copyWith(
            companyName: updatedCompany.name,
            companyDocument: updatedCompany.document,
            companyPhone: updatedCompany.phone,
            companyWebsite: updatedCompany.website ?? '',
            companyInstagram: updatedCompany.instagram ?? '',
            companySlogan: updatedCompany.slogan ?? '',
            companyLogoBase64: updatedCompany.logoBase64,
          );
          await SolarSettingsService.saveSettings(mergedSolar, companyId: effectiveId);
        } catch (e) {
          debugPrint('[CompanyService] Aviso: Falha ao sincronizar com SolarSettings: $e');
        }
      }
    } catch (e) {
      debugPrint('[CompanyService] Erro ao salvar dados da empresa: $e');
      rethrow;
    }
  }

  /// Verifica se a empresa já concluiu a configuração de onboarding inicial
  static Future<bool> hasCompletedOnboarding({String? companyId}) async {
    try {
      final cid = await getEffectiveCompanyId(companyId);
      if (cid != null && cid.isNotEmpty) {
        final doc = await FirebaseFirestore.instance
            .collection('companies')
            .doc(cid)
            .get();

        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          final isCompleted = data['onboardingCompleted'] as bool? ?? false;
          return isCompleted;
        } else {
          return false;
        }
      }

      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('mavis_crm_has_completed_onboarding') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _cacheLocalCompany(CompanyModel model) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localCompanyCacheKey, jsonEncode(model.toMap()));
    } catch (_) {}
  }

  static Future<CompanyModel?> _loadLocalCompany() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_localCompanyCacheKey);
      if (str != null && str.isNotEmpty) {
        final map = jsonDecode(str) as Map<String, dynamic>;
        return CompanyModel.fromMap(map, 'local_company');
      }
    } catch (_) {}
    return null;
  }
}
