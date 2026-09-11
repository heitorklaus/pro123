import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../settings/data/services/company_service.dart';

enum SubscriptionPlan {
  trial,
  monthly, // R$ 99,00
  semiannual, // R$ 450,00
}

extension SubscriptionPlanExtension on SubscriptionPlan {
  String get title {
    switch (this) {
      case SubscriptionPlan.trial:
        return 'Teste Grátis 30 Dias';
      case SubscriptionPlan.monthly:
        return 'Plano Mensal';
      case SubscriptionPlan.semiannual:
        return 'Plano Semestral';
    }
  }

  double get price {
    switch (this) {
      case SubscriptionPlan.trial:
        return 0.0;
      case SubscriptionPlan.monthly:
        return 99.0;
      case SubscriptionPlan.semiannual:
        return 450.0;
    }
  }

  int get durationDays {
    switch (this) {
      case SubscriptionPlan.trial:
        return 30;
      case SubscriptionPlan.monthly:
        return 30;
      case SubscriptionPlan.semiannual:
        return 180;
    }
  }
}

class SubscriptionInfo {
  final String status; // 'trial', 'active', 'expired'
  final SubscriptionPlan plan;
  final DateTime? trialStartedAt;
  final DateTime? trialExpiresAt;
  final DateTime? paidUntil;
  final int remainingDays;

  const SubscriptionInfo({
    required this.status,
    required this.plan,
    this.trialStartedAt,
    this.trialExpiresAt,
    this.paidUntil,
    required this.remainingDays,
  });

  bool get isTrial => status == 'trial';
  bool get isActive => status == 'active';
  bool get isExpired => status == 'expired' || remainingDays <= 0;
}

/// Serviço de gerenciamento de assinaturas, planos e período de testes (30 dias)
class SubscriptionService {
  static const _statusKey = 'mavis_subscription_status';
  static const _planKey = 'mavis_subscription_plan';
  static const _trialExpiresKey = 'mavis_trial_expires_at';
  static const _paidUntilKey = 'mavis_paid_until';

  /// Inicia o período de teste grátis de 30 dias
  static Future<void> startTrial({String? companyId, String? userId}) async {
    try {
      final now = DateTime.now();
      final expiresAt = now.add(const Duration(days: 30));

      final auth = FirebaseAuth.instance;
      final uid = userId ?? auth.currentUser?.uid;
      final cid = await CompanyService.getEffectiveCompanyId(companyId);
      final effectiveId = (cid != null && cid.isNotEmpty) ? cid : uid;

      // 1. Salva na empresa no Firestore
      if (effectiveId != null && effectiveId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('companies').doc(effectiveId).set({
          'subscriptionStatus': 'trial',
          'subscriptionPlan': SubscriptionPlan.trial.name,
          'trialStartedAt': Timestamp.fromDate(now),
          'trialExpiresAt': Timestamp.fromDate(expiresAt),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // 2. Salva no usuário no Firestore
      if (uid != null && uid.isNotEmpty) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'subscriptionStatus': 'trial',
          'subscriptionPlan': SubscriptionPlan.trial.name,
          'trialStartedAt': Timestamp.fromDate(now),
          'trialExpiresAt': Timestamp.fromDate(expiresAt),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // 3. Salva localmente em SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_statusKey, 'trial');
      await prefs.setString(_planKey, SubscriptionPlan.trial.name);
      await prefs.setString(_trialExpiresKey, expiresAt.toIso8601String());
    } catch (e) {
      debugPrint('[SubscriptionService] Erro ao iniciar trial: $e');
    }
  }

  /// Ativa o plano pago (Mensal ou Semestral) após pagamento com PIX
  static Future<void> activatePlan(
    SubscriptionPlan plan, {
    String? companyId,
    String? userId,
  }) async {
    try {
      final now = DateTime.now();
      final paidUntil = now.add(Duration(days: plan.durationDays));

      final auth = FirebaseAuth.instance;
      final uid = userId ?? auth.currentUser?.uid;
      final cid = await CompanyService.getEffectiveCompanyId(companyId);
      final effectiveId = (cid != null && cid.isNotEmpty) ? cid : uid;

      // 1. Salva na empresa no Firestore
      if (effectiveId != null && effectiveId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('companies').doc(effectiveId).set({
          'subscriptionStatus': 'active',
          'subscriptionPlan': plan.name,
          'planPrice': plan.price,
          'paidAt': Timestamp.fromDate(now),
          'paidUntil': Timestamp.fromDate(paidUntil),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // 2. Salva no usuário no Firestore
      if (uid != null && uid.isNotEmpty) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'subscriptionStatus': 'active',
          'subscriptionPlan': plan.name,
          'planPrice': plan.price,
          'paidAt': Timestamp.fromDate(now),
          'paidUntil': Timestamp.fromDate(paidUntil),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // 3. Salva localmente em SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_statusKey, 'active');
      await prefs.setString(_planKey, plan.name);
      await prefs.setString(_paidUntilKey, paidUntil.toIso8601String());
    } catch (e) {
      debugPrint('[SubscriptionService] Erro ao ativar plano: $e');
    }
  }

  /// Retorna as informações completas de assinatura e dias restantes
  static Future<SubscriptionInfo> getSubscriptionInfo({
    String? companyId,
    String? userId,
  }) async {
    try {
      final cid = await CompanyService.getEffectiveCompanyId(companyId);
      final uid = userId ?? FirebaseAuth.instance.currentUser?.uid;
      final effectiveId = (cid != null && cid.isNotEmpty) ? cid : uid;

      if (effectiveId != null && effectiveId.isNotEmpty) {
        final doc = await FirebaseFirestore.instance
            .collection('companies')
            .doc(effectiveId)
            .get();

        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          final status = (data['subscriptionStatus'] as String?) ?? 'trial';
          final planName = (data['subscriptionPlan'] as String?) ?? 'trial';
          final trialExpiresTimestamp = data['trialExpiresAt'] as Timestamp?;
          final paidUntilTimestamp = data['paidUntil'] as Timestamp?;

          SubscriptionPlan plan = SubscriptionPlan.trial;
          for (final p in SubscriptionPlan.values) {
            if (p.name == planName) {
              plan = p;
              break;
            }
          }

          final now = DateTime.now();
          int remaining = 30;

          if (status == 'active' && paidUntilTimestamp != null) {
            final until = paidUntilTimestamp.toDate();
            remaining = until.difference(now).inDays.clamp(0, 365);
          } else if (trialExpiresTimestamp != null) {
            final until = trialExpiresTimestamp.toDate();
            remaining = until.difference(now).inDays.clamp(0, 30);
          }

          return SubscriptionInfo(
            status: status,
            plan: plan,
            trialStartedAt: (data['trialStartedAt'] as Timestamp?)?.toDate(),
            trialExpiresAt: trialExpiresTimestamp?.toDate(),
            paidUntil: paidUntilTimestamp?.toDate(),
            remainingDays: remaining,
          );
        }
      }

      // Fallback local via SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final status = prefs.getString(_statusKey) ?? 'trial';
      final planName = prefs.getString(_planKey) ?? 'trial';
      final trialExpStr = prefs.getString(_trialExpiresKey);
      final paidUntilStr = prefs.getString(_paidUntilKey);

      final now = DateTime.now();
      int remaining = 30;

      if (status == 'active' && paidUntilStr != null) {
        final until = DateTime.tryParse(paidUntilStr);
        if (until != null) remaining = until.difference(now).inDays.clamp(0, 365);
      } else if (trialExpStr != null) {
        final until = DateTime.tryParse(trialExpStr);
        if (until != null) remaining = until.difference(now).inDays.clamp(0, 30);
      }

      SubscriptionPlan plan = SubscriptionPlan.trial;
      for (final p in SubscriptionPlan.values) {
        if (p.name == planName) {
          plan = p;
          break;
        }
      }

      return SubscriptionInfo(
        status: status,
        plan: plan,
        remainingDays: remaining,
      );
    } catch (e) {
      debugPrint('[SubscriptionService] Erro ao ler informações: $e');
      return const SubscriptionInfo(
        status: 'trial',
        plan: SubscriptionPlan.trial,
        remainingDays: 30,
      );
    }
  }

  /// Retorna apenas a contagem de dias restantes de teste
  static Future<int> getRemainingTrialDays({
    String? companyId,
    String? userId,
  }) async {
    final info = await getSubscriptionInfo(companyId: companyId, userId: userId);
    return info.remainingDays;
  }
}
