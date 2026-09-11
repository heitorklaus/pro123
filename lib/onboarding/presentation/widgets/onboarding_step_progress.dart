import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class OnboardingStepProgress extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final VoidCallback? onHelpTap;

  const OnboardingStepProgress({
    super.key,
    required this.currentStep,
    this.totalSteps = 3,
    this.onHelpTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Indicador de Texto e Barras
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Passo $currentStep de $totalSteps',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(totalSteps, (index) {
                final isCompletedOrCurrent = index < currentStep;
                return Container(
                  width: 32,
                  height: 4,
                  margin: EdgeInsets.only(left: index > 0 ? 6 : 0),
                  decoration: BoxDecoration(
                    color: isCompletedOrCurrent
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
          ],
        ),
        const SizedBox(width: 24),
        // Botão de Ajuda (?)
        InkWell(
          onTap: onHelpTap ?? () => _showDefaultHelp(context),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Ajuda',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF475569),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.help_outline_rounded,
                  size: 16,
                  color: Color(0xFF475569),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showDefaultHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.help_rounded, color: Color(0xFF0F172A), size: 24),
            const SizedBox(width: 8),
            Text(
              'Configuração Inicial TAOS',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        content: Text(
          'Bem-vindo ao TAOS CRM! Neste primeiro passo você define o segmento principal de atuação da sua empresa. Você poderá adicionar mais módulos ou alterar sua escolha a qualquer momento nas configurações do sistema.',
          style: GoogleFonts.inter(
            fontSize: 14,
            height: 1.5,
            color: const Color(0xFF475569),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'ENTENDI',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
