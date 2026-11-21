import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../domain/models/plan_cost_policy.dart';

/// Tabela explicativa visual para o cliente final mostrando o que cada plano inclui
/// em termos de propostas no WhatsApp, análises de PDF/IA e MB de uploads (sem expor custos internos).
class PlanBenefitsTableDialog extends StatelessWidget {
  final String highlightTier;

  const PlanBenefitsTableDialog({
    super.key,
    this.highlightTier = 'premium',
  });

  static Future<void> show(
    BuildContext context, {
    String highlightTier = 'premium',
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => PlanBenefitsTableDialog(highlightTier: highlightTier),
    );
  }

  @override
  Widget build(BuildContext context) {
    final normHighlight = PlanCostPolicy.normalizeTier(highlightTier);
    final numFmt = NumberFormat.decimalPattern('pt_BR');
    final tiers = [
      (
        key: 'premium',
        accent: const Color(0xFF38BDF8),
        badge: 'IDEAL PARA COMEÇAR',
        data: PlanCostPolicy.clientBenefitsForTier('premium'),
      ),
      (
        key: 'gold',
        accent: const Color(0xFFF59E0B),
        badge: 'MAIS POPULAR',
        data: PlanCostPolicy.clientBenefitsForTier('gold'),
      ),
      (
        key: 'diamond',
        accent: const Color(0xFF10B981),
        badge: 'ALTA ESCALA',
        data: PlanCostPolicy.clientBenefitsForTier('diamond'),
      ),
    ];

    return Dialog(
      backgroundColor: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: const Color(0xFF38BDF8).withValues(alpha: 0.35)),
      ),
      child: Container(
        width: 760,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0EA5E9).withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Icon(
                      Icons.info_outline_rounded,
                      color: Color(0xFF38BDF8),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'O que cada plano inclui por mês',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Capacidade aproximada de propostas no WhatsApp, análises de IA e uploads de capas e imagens',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
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
              const SizedBox(height: 20),

              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 600;
                  final cards = tiers.map((t) {
                    final isSelected = t.key == normHighlight;
                    final d = t.data;
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? t.accent
                              : const Color(0xFF334155),
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: t.accent.withValues(alpha: 0.22),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: t.accent.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              t.badge,
                              style: GoogleFonts.inter(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: t.accent,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            d.title,
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                d.priceLabel,
                                style: GoogleFonts.outfit(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: t.accent,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '/mês',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const Divider(color: Color(0xFF334155), height: 1),
                          const SizedBox(height: 14),
                          _BenefitLine(
                            icon: Icons.chat_rounded,
                            color: t.accent,
                            title: 'Propostas pelo WhatsApp',
                            value:
                                'Até ~${numFmt.format(d.monthlyWhatsAppProposals)} interações/mês com o Agente IA',
                          ),
                          const SizedBox(height: 10),
                          _BenefitLine(
                            icon: Icons.picture_as_pdf_rounded,
                            color: t.accent,
                            title: 'Análises de PDF & Contas',
                            value:
                                'Até ~${numFmt.format(d.monthlyPdfAnalyses)} leituras inteligentes/mês',
                          ),
                          const SizedBox(height: 10),
                          _BenefitLine(
                            icon: Icons.cloud_upload_rounded,
                            color: t.accent,
                            title: 'Uploads (Capas e Imagens)',
                            value:
                                'Até ~${numFmt.format(d.monthlyUploadMb)} MB/mês em capas, logos e mídias',
                          ),
                          const SizedBox(height: 10),
                          _BenefitLine(
                            icon: Icons.auto_awesome_rounded,
                            color: t.accent,
                            title: 'Média Diária Combinada',
                            value: d.dailyMixedSummary,
                          ),
                        ],
                      ),
                    );
                  }).toList();

                  if (isNarrow) {
                    return Column(
                      children: [
                        for (int i = 0; i < cards.length; i++) ...[
                          cards[i],
                          if (i < cards.length - 1) const SizedBox(height: 12),
                        ],
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int i = 0; i < cards.length; i++) ...[
                        Expanded(child: cards[i]),
                        if (i < cards.length - 1) const SizedBox(width: 12),
                      ],
                    ],
                  );
                },
              ),

              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B).withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.tips_and_updates_rounded,
                      color: Color(0xFFFBBF24),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Os recursos acima são compartilhados de forma flexível no mês: se você usar menos análises de PDF, sobra mais espaço para uploads de capas, imagens e mensagens com o Agente no WhatsApp — e você pode mudar de plano a qualquer momento.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFFCBD5E1),
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BenefitLine extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String value;

  const _BenefitLine({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: const Color(0xFF94A3B8),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
