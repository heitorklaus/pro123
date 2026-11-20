import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../../auth/domain/models/user_model.dart';
import '../../domain/models/global_system_config.dart';
import 'system_settings_service.dart';

/// Serviço central de telemetria, cálculo de custos em R$ e controle de tokens de IA.
class AiUsageTelemetryService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Busca a cotação atual do Dólar (USD -> BRL) via AwesomeAPI.
  static Future<double?> fetchLiveUsdToBrlRate() async {
    try {
      final res = await http
          .get(Uri.parse('https://economia.awesomeapi.com.br/json/last/USD-BRL'))
          .timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final bidStr = json['USDBRL']?['bid']?.toString();
        final rate = double.tryParse(bidStr ?? '');
        if (rate != null && rate > 1.0) {
          return rate;
        }
      }
    } catch (e) {
      debugPrint('[AiUsageTelemetryService] Erro ao buscar cotação USD-BRL: $e');
    }
    return null;
  }

  /// Calcula o custo em USD a partir dos tokens e da configuração global.
  static double calculateCostUsd({
    required int inputTokens,
    required int outputTokens,
    required GlobalSystemConfig config,
  }) {
    final inCost = (inputTokens / 1000000.0) * config.geminiInputUsdPer1M;
    final outCost = (outputTokens / 1000000.0) * config.geminiOutputUsdPer1M;
    return inCost + outCost;
  }

  /// Calcula o custo aproximado em Reais (BRL).
  static double calculateCostBrl({
    required int inputTokens,
    required int outputTokens,
    required GlobalSystemConfig config,
  }) {
    return calculateCostUsd(
          inputTokens: inputTokens,
          outputTokens: outputTokens,
          config: config,
        ) *
        config.usdToBrlRate;
  }

  /// Resolve a cota efetiva diária de tokens para um usuário/dono de empresa.
  static int getEffectiveDailyTokenQuota(
    UserModel user,
    GlobalSystemConfig config, {
    UserModel? companyOwner,
  }) {
    if (user.isSuperAdmin) return 999999999;
    if (user.customDailyTokenQuota != null && user.customDailyTokenQuota! > 0) {
      return user.customDailyTokenQuota!;
    }
    if (companyOwner != null) {
      if (companyOwner.customDailyTokenQuota != null &&
          companyOwner.customDailyTokenQuota! > 0) {
        return companyOwner.customDailyTokenQuota!;
      }
      return config.tokenQuotaForTier(companyOwner.aiPlanTier);
    }
    return config.tokenQuotaForTier(user.aiPlanTier);
  }

  /// Resolve o teto opcional diário em R$ (0.0 = sem teto extra em R$).
  static double getEffectiveDailyBrlQuota(
    UserModel user,
    GlobalSystemConfig config, {
    UserModel? companyOwner,
  }) {
    if (user.isSuperAdmin) return 0.0;
    if (user.customDailyBrlQuota != null && user.customDailyBrlQuota! > 0) {
      return user.customDailyBrlQuota!;
    }
    if (companyOwner != null) {
      if (companyOwner.customDailyBrlQuota != null &&
          companyOwner.customDailyBrlQuota! > 0) {
        return companyOwner.customDailyBrlQuota!;
      }
      return config.brlQuotaForTier(companyOwner.aiPlanTier);
    }
    return config.brlQuotaForTier(user.aiPlanTier);
  }

  /// Registra automaticamente uma chamada Gemini (sucesso ou erro 429) sem bloquear o fluxo principal.
  static Future<void> recordGeminiResponse({
    required String source,
    required String model,
    Map<String, dynamic>? responseJson,
    bool isQuotaError429 = false,
  }) async {
    try {
      final usage = responseJson?['usageMetadata'] as Map<String, dynamic>?;
      final inputTokens = (usage?['promptTokenCount'] as num?)?.toInt() ?? 0;
      final outputTokens =
          (usage?['candidatesTokenCount'] as num?)?.toInt() ?? 0;
      final totalTokens = (usage?['totalTokenCount'] as num?)?.toInt() ??
          (inputTokens + outputTokens);

      // Se não houve tokens e não foi erro 429, não polui os logs
      if (totalTokens == 0 && !isQuotaError429) return;

      UserModel? currentUser;
      try {
        if (FirebaseAuth.instance.currentUser != null) {
          currentUser = await AuthRepository().getCurrentUser();
        }
      } catch (_) {}

      final companyId = currentUser?.effectiveCompanyId ?? 'system';
      final userId = currentUser?.uid ?? 'system';
      final userName = currentUser?.name.isNotEmpty == true
          ? currentUser!.name
          : (currentUser?.email ?? 'Sistema');

      final config = await SystemSettingsService.getGlobalConfig();
      final costUsd = calculateCostUsd(
        inputTokens: inputTokens,
        outputTokens: outputTokens,
        config: config,
      );
      final costBrl = costUsd * config.usdToBrlRate;

      final now = DateTime.now();
      final dateKey = DateFormat('yyyy-MM-dd').format(now);
      final monthKey = DateFormat('yyyy-MM').format(now);

      // 1. Grava log detalhado
      await _db.collection('ai_usage_logs').add({
        'companyId': companyId,
        'userId': userId,
        'userName': userName,
        'source': source,
        'channel': 'web',
        'model': model,
        'inputTokens': inputTokens,
        'outputTokens': outputTokens,
        'totalTokens': totalTokens,
        'costUsd': costUsd,
        'costBrl': costBrl,
        'usdToBrlRate': config.usdToBrlRate,
        'isQuotaError429': isQuotaError429,
        'dateKey': dateKey,
        'monthKey': monthKey,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. Atualiza agregado por empresa/dono em tempo real
      await _incrementSummaryDoc(
        _db.collection('ai_company_usage').doc(companyId),
        dateKey: dateKey,
        monthKey: monthKey,
        inputTokens: inputTokens,
        outputTokens: outputTokens,
        totalTokens: totalTokens,
        costUsd: costUsd,
        costBrl: costBrl,
        isQuotaError429: isQuotaError429,
        model: model,
        source: source,
        extraFields: {'companyId': companyId},
      );

      // 3. Atualiza agregado global do sistema em tempo real
      await _incrementSummaryDoc(
        _db.collection('ai_system_totals').doc('global'),
        dateKey: dateKey,
        monthKey: monthKey,
        inputTokens: inputTokens,
        outputTokens: outputTokens,
        totalTokens: totalTokens,
        costUsd: costUsd,
        costBrl: costBrl,
        isQuotaError429: isQuotaError429,
        model: model,
        source: source,
      );
    } catch (e) {
      debugPrint('[AiUsageTelemetryService] Falha silenciosa ao gravar log: $e');
    }
  }

  static Future<void> _incrementSummaryDoc(
    DocumentReference<Map<String, dynamic>> docRef, {
    required String dateKey,
    required String monthKey,
    required int inputTokens,
    required int outputTokens,
    required int totalTokens,
    required double costUsd,
    required double costBrl,
    required bool isQuotaError429,
    required String model,
    required String source,
    Map<String, dynamic>? extraFields,
  }) async {
    await _db.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      final data = snap.data() ?? <String, dynamic>{};

      final sameDay = data['todayDate'] == dateKey;
      final sameMonth = data['monthKey'] == monthKey;

      final prevTodayTokens =
          sameDay ? ((data['todayTokens'] as num?)?.toInt() ?? 0) : 0;
      final prevTodayIn =
          sameDay ? ((data['todayInputTokens'] as num?)?.toInt() ?? 0) : 0;
      final prevTodayOut =
          sameDay ? ((data['todayOutputTokens'] as num?)?.toInt() ?? 0) : 0;
      final prevTodayReqs =
          sameDay ? ((data['todayRequests'] as num?)?.toInt() ?? 0) : 0;
      final prevTodayUsd =
          sameDay ? ((data['todayCostUsd'] as num?)?.toDouble() ?? 0.0) : 0.0;
      final prevTodayBrl =
          sameDay ? ((data['todayCostBrl'] as num?)?.toDouble() ?? 0.0) : 0.0;
      final prevToday429 =
          sameDay ? ((data['today429Errors'] as num?)?.toInt() ?? 0) : 0;

      final prevMonthTokens =
          sameMonth ? ((data['monthTokens'] as num?)?.toInt() ?? 0) : 0;
      final prevMonthReqs =
          sameMonth ? ((data['monthRequests'] as num?)?.toInt() ?? 0) : 0;
      final prevMonthUsd =
          sameMonth ? ((data['monthCostUsd'] as num?)?.toDouble() ?? 0.0) : 0.0;
      final prevMonthBrl =
          sameMonth ? ((data['monthCostBrl'] as num?)?.toDouble() ?? 0.0) : 0.0;
      final prevMonth429 =
          sameMonth ? ((data['month429Errors'] as num?)?.toInt() ?? 0) : 0;

      final prevWebReqs =
          sameDay ? ((data['todayWebRequests'] as num?)?.toInt() ?? 0) : 0;
      final prevBotReqs =
          sameDay ? ((data['todayBotRequests'] as num?)?.toInt() ?? 0) : 0;

      tx.set(
        docRef,
        {
          if (extraFields != null) ...extraFields,
          'todayDate': dateKey,
          'todayTokens': prevTodayTokens + totalTokens,
          'todayInputTokens': prevTodayIn + inputTokens,
          'todayOutputTokens': prevTodayOut + outputTokens,
          'todayRequests': prevTodayReqs + 1,
          'todayWebRequests': prevWebReqs + 1,
          'todayBotRequests': prevBotReqs,
          'todayCostUsd': prevTodayUsd + costUsd,
          'todayCostBrl': prevTodayBrl + costBrl,
          'today429Errors': prevToday429 + (isQuotaError429 ? 1 : 0),
          'monthKey': monthKey,
          'monthTokens': prevMonthTokens + totalTokens,
          'monthRequests': prevMonthReqs + 1,
          'monthCostUsd': prevMonthUsd + costUsd,
          'monthCostBrl': prevMonthBrl + costBrl,
          'month429Errors': prevMonth429 + (isQuotaError429 ? 1 : 0),
          'lastModel': model,
          'lastSource': source,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  /// Verifica se a empresa/dono ainda tem cota de tokens e R$ disponível hoje.
  static Future<({bool allowed, int usedTokens, int maxTokens, double usedBrl, double maxBrl, String tier})>
      checkCompanyTokenQuota(UserModel user) async {
    if (user.isSuperAdmin) {
      return (
        allowed: true,
        usedTokens: 0,
        maxTokens: 999999999,
        usedBrl: 0.0,
        maxBrl: 0.0,
        tier: 'master',
      );
    }

    final config = await SystemSettingsService.getGlobalConfig();
    final companyId = user.effectiveCompanyId;

    UserModel? companyOwner;
    if (companyId.isNotEmpty && companyId != user.uid) {
      try {
        final ownerDoc = await _db.collection('users').doc(companyId).get();
        if (ownerDoc.exists && ownerDoc.data() != null) {
          companyOwner = UserModel.fromMap(ownerDoc.data()!, ownerDoc.id);
        }
      } catch (_) {}
    }

    final tier = (companyOwner?.aiPlanTier ?? user.aiPlanTier).toUpperCase();
    final maxTokens = getEffectiveDailyTokenQuota(
      user,
      config,
      companyOwner: companyOwner,
    );
    final maxBrl = getEffectiveDailyBrlQuota(
      user,
      config,
      companyOwner: companyOwner,
    );

    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    int usedTokens = 0;
    double usedBrl = 0.0;

    try {
      final usageDoc =
          await _db.collection('ai_company_usage').doc(companyId).get();
      if (usageDoc.exists && usageDoc.data() != null) {
        final data = usageDoc.data()!;
        if (data['todayDate'] == todayStr) {
          usedTokens = (data['todayTokens'] as num?)?.toInt() ?? 0;
          usedBrl = (data['todayCostBrl'] as num?)?.toDouble() ?? 0.0;
        }
      }
    } catch (_) {}

    final exceededTokens = maxTokens > 0 && usedTokens >= maxTokens;
    final exceededBrl = maxBrl > 0 && usedBrl >= maxBrl;

    return (
      allowed: !exceededTokens && !exceededBrl,
      usedTokens: usedTokens,
      maxTokens: maxTokens,
      usedBrl: usedBrl,
      maxBrl: maxBrl,
      tier: tier,
    );
  }
}
