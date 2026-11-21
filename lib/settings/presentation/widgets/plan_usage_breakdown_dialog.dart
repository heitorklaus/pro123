import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../domain/models/plan_cost_policy.dart';

/// Janela executiva que detalha exatamente quanto o cliente consumiu em IA, Agentes e Uploads
/// dentro do mês atual em relação ao teto de 20% do plano (margem de 80% de lucro).
class PlanUsageBreakdownDialog extends StatelessWidget {
  final String companyId;
  final String userName;
  final String tier;

  const PlanUsageBreakdownDialog({
    super.key,
    required this.companyId,
    required this.userName,
    required this.tier,
  });

  static Future<void> show(
    BuildContext context, {
    required String companyId,
    required String userName,
    required String tier,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => PlanUsageBreakdownDialog(
        companyId: companyId,
        userName: userName,
        tier: tier,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final monthKey = DateFormat('yyyy-MM').format(DateTime.now());
    final planPrice = PlanCostPolicy.planPriceBrl(tier);
    final maxCost = PlanCostPolicy.maxMonthlyCostBrl(tier);
    final numFmt = NumberFormat.decimalPattern('pt_BR');

    return Dialog(
      backgroundColor: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: const Color(0xFF334155)),
      ),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(24),
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('ai_company_usage')
              .doc(companyId)
              .snapshots(),
          builder: (context, snap) {
            final raw = snap.data?.data();
            final sameMonth = raw != null && raw['monthKey'] == monthKey;

            final totalBrl = sameMonth
                ? ((raw['monthCostBrl'] as num?)?.toDouble() ?? 0.0)
                : 0.0;
            final uploadBrl = sameMonth
                ? ((raw['monthUploadCostBrl'] as num?)?.toDouble() ?? 0.0)
                : 0.0;
            final aiBrl = (totalBrl - uploadBrl).clamp(0.0, totalBrl);
            final monthTokens =
                sameMonth ? ((raw['monthTokens'] as num?)?.toInt() ?? 0) : 0;
            final monthRequests =
                sameMonth ? ((raw['monthRequests'] as num?)?.toInt() ?? 0) : 0;
            final uploadBytes = sameMonth
                ? ((raw['monthUploadBytes'] as num?)?.toInt() ?? 0)
                : 0;
            final uploadCount = sameMonth
                ? ((raw['monthUploadCount'] as num?)?.toInt() ?? 0)
                : 0;

            final uploadMb = uploadBytes / (1024.0 * 1024.0);
            final ratio = maxCost > 0 ? (totalBrl / maxCost) : 0.0;
            final isExceeded = ratio >= 1.0;
            final isNear = !isExceeded && ratio >= PlanCostPolicy.nearLimitRatioOfCap;
            final statusColor = isExceeded
                ? const Color(0xFFEF4444)
                : (isNear ? const Color(0xFFF59E0B) : const Color(0xFF10B981));
            final profitBrl = (planPrice - totalBrl).clamp(0.0, planPrice);
            final profitPct = planPrice > 0 ? (profitBrl / planPrice) * 100 : 0.0;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: statusColor.withValues(alpha: 0.45)),
                      ),
                      child: Icon(
                        Icons.analytics_rounded,
                        color: statusColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Detalhamento de Consumo • $userName',
                            style: GoogleFonts.outfit(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Plano ${PlanCostPolicy.tierDisplayName(tier)} (${PlanCostPolicy.formatBrl(planPrice)}) • Teto de custo (20%): ${PlanCostPolicy.formatBrl(maxCost)}',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded,
                          color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Barra de progresso do teto de 20%
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withValues(alpha: 0.35)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Consumindo ${PlanCostPolicy.formatBrl(totalBrl)} de ${PlanCostPolicy.formatBrl(maxCost)}',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            '${(ratio * 100).toStringAsFixed(0)}%',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: ratio.clamp(0.0, 1.0),
                          minHeight: 8,
                          backgroundColor: const Color(0xFF0F172A),
                          valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Lucro atual nesta conta: ${PlanCostPolicy.formatBrl(profitBrl)} (${profitPct.toStringAsFixed(1)}% da mensalidade)',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: const Color(0xFFCBD5E1),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Breakdown IA + Agentes vs Uploads
                _BreakdownCard(
                  icon: Icons.smart_toy_rounded,
                  iconColor: const Color(0xFF818CF8),
                  title: 'IA & Agentes (Web + WhatsApp)',
                  subtitle:
                      '${numFmt.format(monthRequests)} interações • ${numFmt.format(monthTokens)} tokens',
                  valueBrl: PlanCostPolicy.formatBrl(aiBrl),
                ),
                const SizedBox(height: 10),
                _BreakdownCard(
                  icon: Icons.cloud_upload_rounded,
                  iconColor: const Color(0xFF38BDF8),
                  title: 'Uploads (Capas, Logos, PDFs e Mídias)',
                  subtitle:
                      '${numFmt.format(uploadCount)} arquivos • ${uploadMb.toStringAsFixed(2)} MB trafegados',
                  valueBrl: PlanCostPolicy.formatBrl(uploadBrl),
                ),
                const SizedBox(height: 14),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B).withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Text(
                    isExceeded
                        ? '⚠️ Teto atingido! Novas interações de IA, Agentes e Uploads estão travadas para este usuário até o upgrade para GOLD (R\$ 79,90) ou DIAMOND (R\$ 99,90).'
                        : '💡 Quando o consumo somado de IA + Uploads atingir ${PlanCostPolicy.formatBrl(maxCost)} (20% do plano), o sistema trava automaticamente e sugere o upgrade.',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      color: const Color(0xFFCBD5E1),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String valueBrl;

  const _BreakdownCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.valueBrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          Text(
            valueBrl,
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
