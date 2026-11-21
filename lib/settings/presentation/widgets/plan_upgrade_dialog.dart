import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/models/plan_cost_policy.dart';

/// Diálogo exibido ao usuário quando o consumo mensal atinge o teto de custo do plano,
/// travando IA/Agentes/Uploads e oferecendo upgrade gratuito para GOLD ou DIAMOND.
class PlanUpgradeDialog extends StatefulWidget {
  final String companyId;
  final String currentTier;
  final double usedBrl;
  final double maxCostBrl;
  final double planPriceBrl;
  final String actionLabel;

  const PlanUpgradeDialog({
    super.key,
    required this.companyId,
    required this.currentTier,
    required this.usedBrl,
    required this.maxCostBrl,
    required this.planPriceBrl,
    required this.actionLabel,
  });

  static Future<bool> show(
    BuildContext context, {
    required String companyId,
    required String currentTier,
    required double usedBrl,
    required double maxCostBrl,
    required double planPriceBrl,
    required String actionLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => PlanUpgradeDialog(
        companyId: companyId,
        currentTier: currentTier,
        usedBrl: usedBrl,
        maxCostBrl: maxCostBrl,
        planPriceBrl: planPriceBrl,
        actionLabel: actionLabel,
      ),
    );
    return result == true;
  }

  @override
  State<PlanUpgradeDialog> createState() => _PlanUpgradeDialogState();
}

class _PlanUpgradeDialogState extends State<PlanUpgradeDialog> {
  bool _isUpgrading = false;

  Future<void> _upgradeTo(String targetTier) async {
    setState(() => _isUpgrading = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.companyId)
          .set({'aiPlanTier': targetTier}, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Plano atualizado gratuitamente para ${targetTier.toUpperCase()}! Recursos liberados.',
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUpgrading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao atualizar plano: $e'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final norm = PlanCostPolicy.normalizeTier(widget.currentTier);
    final canGold = norm == 'premium';
    final canDiamond = norm == 'premium' || norm == 'gold';

    return Dialog(
      backgroundColor: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
      ),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.lock_clock_rounded, color: Colors.white, size: 30),
            ),
            const SizedBox(height: 16),
            Text(
              'Limite do Plano ${PlanCostPolicy.tierDisplayName(norm)} Atingido',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'O recurso "${widget.actionLabel}" foi temporariamente pausado porque o consumo mensal (${PlanCostPolicy.formatBrl(widget.usedBrl)}) atingiu o limite do plano de ${PlanCostPolicy.formatBrl(widget.planPriceBrl)}.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFFCBD5E1),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded, color: Color(0xFF10B981), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Atualize agora gratuitamente para um plano superior e libere IA, Agentes e Uploads imediatamente.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFFE2E8F0),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (canGold) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isUpgrading ? null : () => _upgradeTo('gold'),
                  icon: const Icon(Icons.workspace_premium_rounded, size: 18),
                  label: const Text('ATUALIZAR GRÁTIS PARA GOLD (R\$ 79,90)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: const Color(0xFF0F172A),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 12.5),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (canDiamond) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isUpgrading ? null : () => _upgradeTo('diamond'),
                  icon: const Icon(Icons.diamond_rounded, size: 18),
                  label: const Text('ATUALIZAR GRÁTIS PARA DIAMOND (R\$ 99,90)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF06B6D4),
                    foregroundColor: const Color(0xFF0F172A),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 12.5),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            TextButton(
              onPressed: _isUpgrading ? null : () => Navigator.of(context).pop(false),
              child: Text(
                'Fechar',
                style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
