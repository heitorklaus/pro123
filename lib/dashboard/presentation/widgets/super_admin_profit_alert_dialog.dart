import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../auth/domain/models/user_model.dart';
import '../../../settings/domain/models/plan_cost_policy.dart';

class _AlertUserUsage {
  final UserModel user;
  final double usedBrl;
  final double maxCostBrl;
  final double planPriceBrl;
  final double ratio;

  const _AlertUserUsage({
    required this.user,
    required this.usedBrl,
    required this.maxCostBrl,
    required this.planPriceBrl,
    required this.ratio,
  });
}

/// Popup automática exibida ao Super Admin (heitorklaus@hotmail.com) ao logar
/// quando algum cliente está chegando perto ou ultrapassando o teto de 20% de custo (80% de lucro).
class SuperAdminProfitAlertDialog extends StatelessWidget {
  final List<_AlertUserUsage> alerts;
  final VoidCallback onGoToUsers;

  const SuperAdminProfitAlertDialog({
    super.key,
    required this.alerts,
    required this.onGoToUsers,
  });

  static Future<void> checkAndShowIfNeeded(
    BuildContext context, {
    required UserModel currentUser,
    required VoidCallback onGoToUsers,
  }) async {
    if (!currentUser.isSuperAdmin &&
        currentUser.email.trim().toLowerCase() != 'heitorklaus@hotmail.com') {
      return;
    }

    try {
      final db = FirebaseFirestore.instance;
      final monthKey = DateFormat('yyyy-MM').format(DateTime.now());
      final usersSnap = await db.collection('users').get();
      final usageSnap = await db.collection('ai_company_usage').get();

      final Map<String, double> monthCostByCompany = {};
      for (final doc in usageSnap.docs) {
        final data = doc.data();
        if (data['monthKey'] == monthKey) {
          monthCostByCompany[doc.id] =
              (data['monthCostBrl'] as num?)?.toDouble() ?? 0.0;
        }
      }

      final List<_AlertUserUsage> alerts = [];
      for (final doc in usersSnap.docs) {
        final u = UserModel.fromMap(doc.data(), doc.id);
        if (u.isSuperAdmin) continue;
        if (!u.isAdmin && u.companyId != null && u.companyId != u.uid) continue;

        final cid = u.effectiveCompanyId;
        final used = monthCostByCompany[cid] ?? 0.0;
        final planPrice = PlanCostPolicy.planPriceBrl(u.aiPlanTier);
        final maxCost = PlanCostPolicy.maxMonthlyCostBrl(u.aiPlanTier);
        final ratio = maxCost > 0 ? (used / maxCost) : 0.0;

        if (ratio >= PlanCostPolicy.nearLimitRatioOfCap) {
          alerts.add(
            _AlertUserUsage(
              user: u,
              usedBrl: used,
              maxCostBrl: maxCost,
              planPriceBrl: planPrice,
              ratio: ratio,
            ),
          );
        }
      }

      if (alerts.isEmpty || !context.mounted) return;
      alerts.sort((a, b) => b.ratio.compareTo(a.ratio));

      await showDialog<void>(
        context: context,
        builder: (_) => SuperAdminProfitAlertDialog(
          alerts: alerts,
          onGoToUsers: onGoToUsers,
        ),
      );
    } catch (e) {
      debugPrint('[SuperAdminProfitAlertDialog] Erro ao checar margem: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final exceededCount = alerts.where((a) => a.ratio >= 1.0).length;
    final nearCount = alerts.length - exceededCount;

    return Dialog(
      backgroundColor: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: const Color(0xFFEF4444).withValues(alpha: 0.45)),
      ),
      child: Container(
        width: 560,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.45),
                    ),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFF87171),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Alerta de Margem de Lucro (80%)',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '$exceededCount estourado(s) • $nearCount próximo(s) do limite de custo (20%)',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (alerts.length > 5)
              InkWell(
                onTap: () {
                  Navigator.of(context).pop();
                  onGoToUsers();
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.45),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.people_alt_rounded,
                        color: Color(0xFFF87171),
                        size: 26,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Existem ${alerts.length} usuários estourando a cota. Clique para ver...',
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Color(0xFF94A3B8),
                        size: 16,
                      ),
                    ],
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: alerts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final item = alerts[i];
                    final isExceeded = item.ratio >= 1.0;
                    final color = isExceeded
                        ? const Color(0xFFEF4444)
                        : const Color(0xFFF59E0B);
                    final pct = (item.ratio * 100).toStringAsFixed(0);
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: color.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.user.name.isNotEmpty
                                      ? item.user.name
                                      : item.user.email,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Consumindo ${PlanCostPolicy.formatBrl(item.usedBrl)} do plano de ${PlanCostPolicy.formatBrl(item.planPriceBrl)} (teto ${PlanCostPolicy.formatBrl(item.maxCostBrl)})',
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    color: const Color(0xFFCBD5E1),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isExceeded ? 'TRAVADO ($pct%)' : 'ALERTA ($pct%)',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Fechar',
                    style: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onGoToUsers();
                  },
                  icon: const Icon(Icons.people_alt_rounded, size: 17),
                  label: const Text('Ver Usuários'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
