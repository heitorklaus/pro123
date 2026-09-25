import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../../products/domain/models/product_model.dart';
import '../../domain/models/company_model.dart';
import 'solar_settings_service.dart';
import 'automation_settings_service.dart';

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

        // 4. Sincroniza os dados institucionais, endereço completo e logomarca com as configurações de Automação Residencial
        try {
          final autoSettings = await AutomationSettingsService.loadSettings(companyId: effectiveId);
          final effectiveName = updatedCompany.tradeName?.trim().isNotEmpty == true
              ? updatedCompany.tradeName!.trim()
              : (updatedCompany.name.trim().isNotEmpty ? updatedCompany.name.trim() : (updatedCompany.corporateName ?? ''));

          final mergedAuto = autoSettings.copyWith(
            companyId: effectiveId,
            companyName: effectiveName.isNotEmpty ? effectiveName : autoSettings.companyName,
            companyDoc: updatedCompany.document.isNotEmpty ? updatedCompany.document : autoSettings.companyDoc,
            companyPhone: updatedCompany.phone.isNotEmpty ? updatedCompany.phone : autoSettings.companyPhone,
            companyEmail: (updatedCompany.email?.isNotEmpty == true ? updatedCompany.email : updatedCompany.companyEmail) ?? autoSettings.companyEmail,
            companyWebsite: updatedCompany.website?.isNotEmpty == true ? updatedCompany.website! : autoSettings.companyWebsite,
            companyInstagram: updatedCompany.instagram?.isNotEmpty == true ? updatedCompany.instagram! : autoSettings.companyInstagram,
            companySlogan: updatedCompany.slogan?.isNotEmpty == true ? updatedCompany.slogan! : autoSettings.companySlogan,
            companyLogoBase64: updatedCompany.logoBase64 ?? autoSettings.companyLogoBase64,
            cep: updatedCompany.zipCode?.isNotEmpty == true ? updatedCompany.zipCode! : autoSettings.cep,
            logradouro: updatedCompany.street?.isNotEmpty == true ? updatedCompany.street! : autoSettings.logradouro,
            numero: updatedCompany.number?.isNotEmpty == true ? updatedCompany.number! : autoSettings.numero,
            complemento: updatedCompany.complement?.isNotEmpty == true ? updatedCompany.complement! : autoSettings.complemento,
            bairro: updatedCompany.neighborhood?.isNotEmpty == true ? updatedCompany.neighborhood! : autoSettings.bairro,
            cidade: updatedCompany.city?.isNotEmpty == true ? updatedCompany.city! : autoSettings.cidade,
            uf: updatedCompany.state?.isNotEmpty == true ? updatedCompany.state! : autoSettings.uf,
          );
          await AutomationSettingsService.saveSettings(mergedAuto);
        } catch (e) {
          debugPrint('[CompanyService] Aviso: Falha ao sincronizar com AutomationSettings: $e');
        }
      }
    } catch (e) {
      debugPrint('[CompanyService] Erro ao salvar dados da empresa: $e');
      rethrow;
    }
  }

  /// Salva imediatamente o nicho/ramo da empresa e usuário no Cloud Firestore
  static Future<void> saveCompanySector(
    ProductSector sector, {
    String? companyId,
    String? userId,
  }) async {
    try {
      final cid = await getEffectiveCompanyId(companyId);
      final auth = FirebaseAuth.instance;
      final uid = userId ?? auth.currentUser?.uid;
      final effectiveId = (cid != null && cid.isNotEmpty) ? cid : uid;

      if (effectiveId != null && effectiveId.isNotEmpty) {
        final companyRef = FirebaseFirestore.instance.collection('companies').doc(effectiveId);
        final doc = await companyRef.get();
        if (!doc.exists) {
          final user = auth.currentUser;
          await companyRef.set({
            'id': effectiveId,
            'name': user?.displayName ?? 'Minha Empresa',
            'document': '',
            'phone': '',
            'email': user?.email ?? '',
            'sector': sector.name,
            'onboardingCompleted': false,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } else {
          await companyRef.set({
            'sector': sector.name,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }

      if (uid != null && uid.isNotEmpty) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'sector': sector.name,
          'preferredSector': sector.name,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('[CompanyService] Erro ao salvar nicho no Firestore: $e');
    }
  }

  /// Obtém o nicho salvo no Banco de Dados (Firestore) na empresa ou usuário
  static Future<ProductSector?> getSectorFromDatabase({
    String? companyId,
    String? userId,
  }) async {
    try {
      final cid = await getEffectiveCompanyId(companyId);
      final uid = userId ?? FirebaseAuth.instance.currentUser?.uid;

      // 1. Checa no documento da empresa
      if (cid != null && cid.isNotEmpty) {
        final doc = await FirebaseFirestore.instance.collection('companies').doc(cid).get();
        if (doc.exists && doc.data() != null) {
          final sName = doc.data()!['sector'] as String?;
          if (sName != null && sName.isNotEmpty) {
            for (final s in ProductSector.values) {
              if (s.name == sName) return s;
            }
          }
        }
      }

      // 2. Checa no documento do usuário
      if (uid != null && uid.isNotEmpty) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (userDoc.exists && userDoc.data() != null) {
          final sName = (userDoc.data()!['preferredSector'] ?? userDoc.data()!['sector']) as String?;
          if (sName != null && sName.isNotEmpty) {
            for (final s in ProductSector.values) {
              if (s.name == sName) return s;
            }
          }
        }
      }

      return null;
    } catch (e) {
      debugPrint('[CompanyService] Erro ao buscar nicho do banco: $e');
      return null;
    }
  }

  /// Verifica se o usuário ou a empresa já definiram e salvaram o nicho no Banco de Dados
  static Future<bool> hasCompletedOnboarding({String? companyId, String? userId}) async {
    try {
      // 0. Checagem prioritária no SharedPreferences local
      final prefs = await SharedPreferences.getInstance();
      final localCompleted = prefs.getBool('mavis_crm_has_completed_onboarding') ?? false;
      if (localCompleted) {
        return true;
      }

      final cid = await getEffectiveCompanyId(companyId);
      final uid = userId ?? FirebaseAuth.instance.currentUser?.uid;

      // 1. Checa no documento da empresa no Firestore
      if (cid != null && cid.isNotEmpty) {
        final doc = await FirebaseFirestore.instance
            .collection('companies')
            .doc(cid)
            .get();

        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          final isCompleted = data['onboardingCompleted'] as bool? ?? false;
          final docNumber = (data['document'] as String?)?.trim() ?? '';
          final name = (data['name'] as String?)?.trim() ?? '';

          // Onboarding só está completo se a empresa finalizou o cadastro (onboardingCompleted: true)
          // OU se for uma conta antiga que já possui CNPJ e Razão Social cadastrados
          if (isCompleted) {
            return true;
          }
          if (docNumber.isNotEmpty && name.isNotEmpty && name != 'Minha Empresa') {
            return true;
          }
        }
      }

      // 2. Checa no documento do usuário no Firestore
      if (uid != null && uid.isNotEmpty) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();

        if (userDoc.exists && userDoc.data() != null) {
          final data = userDoc.data()!;
          final isCompleted = data['onboardingCompleted'] as bool? ?? false;
          if (isCompleted) {
            return true;
          }
        }
      }

      // Se não completou a configuração da empresa no Firestore, retorna false para manter no onboarding
      return false;
    } catch (e) {
      debugPrint('[CompanyService] Erro ao verificar nicho no Firestore: $e');
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('mavis_crm_has_completed_onboarding') ?? false;
    }
  }

  /// Verifica se o CNPJ já está cadastrado no banco de dados Firestore por outra empresa (Unicidade de CNPJ)
  static Future<bool> isCnpjAlreadyRegistered(
    String rawCnpj, {
    String? currentCompanyId,
    String? currentUserId,
  }) async {
    final clean = rawCnpj.replaceAll(RegExp(r'\D'), '');
    if (clean.length != 14) return false;

    // Se for o CNPJ de testes de desenvolvimento (31.965.255/0001-12), permite sempre para facilitar homologações
    if (clean == '31965255000112') {
      return false;
    }

    try {
      final effectiveId = await getEffectiveCompanyId(currentCompanyId);
      final uid = currentUserId ?? FirebaseAuth.instance.currentUser?.uid;

      final snap = await FirebaseFirestore.instance
          .collection('companies')
          .get();

      for (final doc in snap.docs) {
        // Se pertencer à empresa atual ou ao UID do próprio usuário, é o mesmo usuário atualizando seus dados!
        if (effectiveId != null && doc.id == effectiveId) continue;
        if (uid != null && doc.id == uid) continue;
        final docData = doc.data();
        if (uid != null && (docData['createdByUserId'] == uid || docData['ownerId'] == uid)) continue;

        final docDoc = (docData['document'] as String? ?? '').replaceAll(RegExp(r'\D'), '');
        final docCnpj = (docData['cnpj'] as String? ?? '').replaceAll(RegExp(r'\D'), '');
        if (docDoc == clean || docCnpj == clean) {
          return true; // CNPJ já cadastrado por OUTRA empresa!
        }
      }

      return false;
    } catch (e) {
      debugPrint('[CompanyService] Erro ao verificar unicidade de CNPJ: $e');
      return false;
    }
  }

  /// Remove todas as empresas que possuam o CNPJ especificado (útil para testes de desenvolvimento e homologação)
  static Future<int> deleteCompanyByCnpj(String rawCnpj) async {
    final clean = rawCnpj.replaceAll(RegExp(r'\D'), '');
    if (clean.isEmpty) return 0;
    int deleted = 0;
    try {
      final snap = await FirebaseFirestore.instance.collection('companies').get();
      for (final doc in snap.docs) {
        final data = doc.data();
        final docDoc = (data['document'] as String? ?? '').replaceAll(RegExp(r'\D'), '');
        final docCnpj = (data['cnpj'] as String? ?? '').replaceAll(RegExp(r'\D'), '');
        if (docDoc == clean || docCnpj == clean) {
          await FirebaseFirestore.instance.collection('companies').doc(doc.id).delete();
          deleted++;
        }
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_localCompanyCacheKey);
    } catch (e) {
      debugPrint('[CompanyService] Erro ao deletar empresa por CNPJ: $e');
    }
    return deleted;
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
