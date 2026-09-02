import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../app/theme/app_colors.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../../auth/domain/models/user_model.dart';
import '../../domain/models/global_system_config.dart';

/// Serviço responsável pelo gerenciamento de Cotas de IA, Limites de Vendedores por Integrador e Configurações Master
class SystemSettingsService {
  static const _collection = 'system_settings';
  static const _docId = 'global_config';

  static const _cachedAiQuotaKey = 'mavis_cached_daily_ai_quota';
  static const _cachedMaxSellersKey = 'mavis_cached_max_sellers_per_company';

  /// Retorna as configurações globais ativas do sistema
  static Future<GlobalSystemConfig> getGlobalConfig() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection(_collection)
          .doc(_docId)
          .get();

      if (doc.exists && doc.data() != null) {
        final config = GlobalSystemConfig.fromMap(doc.data());
        _cacheConfigLocally(config);
        return config;
      }

      // Se não existir no Firestore, inicializa o documento padrão
      final initial = GlobalSystemConfig.defaultConfig();
      await saveGlobalConfig(initial, updatedBy: 'system_init');
      return initial;
    } catch (e) {
      debugPrint('[SystemSettingsService] Erro ao carregar config global: $e');
      return _loadLocalConfig();
    }
  }

  /// Stream em tempo real das configurações globais do sistema
  static Stream<GlobalSystemConfig> getGlobalConfigStream() {
    return FirebaseFirestore.instance
        .collection(_collection)
        .doc(_docId)
        .snapshots()
        .map((snap) {
      if (snap.exists && snap.data() != null) {
        final config = GlobalSystemConfig.fromMap(snap.data());
        _cacheConfigLocally(config);
        return config;
      }
      return GlobalSystemConfig.defaultConfig();
    });
  }

  /// Salva as configurações globais no Cloud Firestore (SuperAdmin)
  static Future<void> saveGlobalConfig(
    GlobalSystemConfig config, {
    String? updatedBy,
  }) async {
    try {
      final updated = config.copyWith(
        updatedAt: DateTime.now(),
        updatedBy: updatedBy ?? 'master_admin',
      );

      await FirebaseFirestore.instance
          .collection(_collection)
          .doc(_docId)
          .set(updated.toMap(), SetOptions(merge: true));

      await _cacheConfigLocally(updated);
    } catch (e) {
      debugPrint('[SystemSettingsService] Erro ao salvar config global: $e');
      rethrow;
    }
  }

  /// Salva limites customizados para uma empresa/integrador específica
  static Future<void> saveCompanyCustomLimits({
    required String companyId,
    int? maxSellers,
    int? maxDailyAiAnalyses,
  }) async {
    try {
      final Map<String, dynamic> data = {};
      if (maxSellers != null) data['maxSellers'] = maxSellers;
      if (maxDailyAiAnalyses != null) data['maxDailyAiAnalyses'] = maxDailyAiAnalyses;

      if (data.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('companies')
            .doc(companyId)
            .set(data, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('[SystemSettingsService] Erro ao salvar limites da empresa: $e');
      rethrow;
    }
  }

  /// Retorna o limite máximo de vendedores para a empresa (respeitando customização da empresa ou padrão global)
  static Future<int> getCompanyMaxSellers(String companyId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('companies').doc(companyId).get();
      if (doc.exists && doc.data() != null) {
        final custom = doc.data()!['maxSellers'] as int?;
        if (custom != null && custom > 0) return custom;
      }
      final global = await getGlobalConfig();
      return global.defaultMaxSellersPerCompany;
    } catch (_) {
      return 5;
    }
  }

  /// Retorna a cota diária efetiva de análises de IA para um usuário específico
  static Future<int> getEffectiveDailyAiQuota(UserModel user) async {
    if (user.isSuperAdmin) return 999999;
    if (user.customDailyAiQuota != null && user.customDailyAiQuota! > 0) {
      return user.customDailyAiQuota!;
    }
    try {
      final cid = user.effectiveCompanyId;
      if (cid.isNotEmpty) {
        final doc = await FirebaseFirestore.instance.collection('companies').doc(cid).get();
        if (doc.exists && doc.data() != null) {
          final compCustom = doc.data()!['maxDailyAiAnalyses'] as int?;
          if (compCustom != null && compCustom > 0) return compCustom;
        }
      }
    } catch (_) {}

    final global = await getGlobalConfig();
    return global.defaultDailyAiQuota;
  }

  /// Valida e consome 1 crédito de análise de IA para o usuário.
  /// Se a cota diária for ultrapassada ou não tiver permissão, exibe modal amigável e retorna false.
  static Future<bool> checkAndConsumeAiQuota(
    BuildContext context, {
    UserModel? user,
  }) async {
    final authRepo = AuthRepository();
    final currentUser = user ?? await authRepo.getCurrentUser();

    if (currentUser == null) return true; // Fallback se não autenticado

    // 1. Verificação de Permissão no RBAC
    if (!currentUser.canUseAi) {
      if (context.mounted) {
        showAiPermissionDeniedDialog(context);
      }
      return false;
    }

    // 2. SuperAdmin tem acesso irrestrito e ilimitado
    if (currentUser.isSuperAdmin) {
      return true;
    }

    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final currentCount = (currentUser.aiUsageDate == todayStr) ? currentUser.aiUsageCount : 0;
    final maxQuota = await getEffectiveDailyAiQuota(currentUser);

    // 3. Verificação de Limite Diário
    if (currentCount >= maxQuota) {
      if (context.mounted) {
        showAiLimitExceededDialog(context, limit: maxQuota);
      }
      return false;
    }

    // 4. Incremento e gravação atômica da utilização
    try {
      final newCount = currentCount + 1;
      await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).update({
        'aiUsageCount': newCount,
        'aiUsageDate': todayStr,
      });
      return true;
    } catch (e) {
      debugPrint('[SystemSettingsService] Aviso: Erro ao incrementar uso de IA: $e');
      return true; // Permite prosseguir em caso de falha de conexão secundária
    }
  }

  /// Exibe diálogo informativo quando a cota diária de IA é atingida
  static void showAiLimitExceededDialog(BuildContext context, {required int limit}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 440,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 32),
              ),
              const SizedBox(height: 18),
              Text(
                'Limite Diário de IA Atingido',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Você atingiu a cota diária de $limit análises com Inteligência Artificial para o dia de hoje.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.schedule_rounded, color: Color(0xFF818CF8), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Sua cota renovará automaticamente à meia-noite (00:00). Caso precise de mais análises, solicite liberação ao administrador master.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'ENTENDI',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Exibe diálogo quando o usuário não possui permissão de IA
  static void showAiPermissionDeniedDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 440,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.lock_person_rounded, color: Color(0xFFEF4444), size: 30),
              ),
              const SizedBox(height: 16),
              Text(
                'Acesso a Recursos de IA Bloqueado',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Seu perfil de usuário não possui permissão ativa para utilizar ferramentas com IA (leitura de faturas, PDF de usinas ou assistente de propostas).\n\nSolicite a ativação da permissão "🤖 Inteligência Artificial" ao administrador da sua empresa.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF475569),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('FECHAR', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Exibe diálogo quando o limite de vendedores por integrador é atingido
  static void showSellerLimitExceededDialog(
    BuildContext context, {
    required int limit,
    required String companyName,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 460,
          padding: const EdgeInsets.all(26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.group_off_rounded, color: Color(0xFFD97706), size: 32),
              ),
              const SizedBox(height: 18),
              Text(
                'Limite de Vendedores Atingido',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'A empresa "$companyName" atingiu a capacidade máxima de $limit vendedores cadastrados simultaneamente.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.workspace_premium_rounded, color: Color(0xFFD97706), size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Para expandir o número de vendedores da sua equipe, solicite o upgrade de vagas ao administrador master.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('OK, COMPREENDI', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helpers de Cache Local
  static Future<void> _cacheConfigLocally(GlobalSystemConfig config) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_cachedAiQuotaKey, config.defaultDailyAiQuota);
      await prefs.setInt(_cachedMaxSellersKey, config.defaultMaxSellersPerCompany);
    } catch (_) {}
  }

  static Future<GlobalSystemConfig> _loadLocalConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ai = prefs.getInt(_cachedAiQuotaKey) ?? 25;
      final sellers = prefs.getInt(_cachedMaxSellersKey) ?? 5;
      return GlobalSystemConfig(
        defaultDailyAiQuota: ai,
        defaultMaxSellersPerCompany: sellers,
        updatedAt: DateTime.now(),
      );
    } catch (_) {
      return GlobalSystemConfig.defaultConfig();
    }
  }
}
