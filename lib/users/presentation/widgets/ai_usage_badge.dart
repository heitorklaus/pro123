import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../auth/domain/models/user_model.dart';

/// Badge visual moderna que exibe o consumo de Inteligência Artificial do usuário no dia atual
class AiUsageBadge extends StatelessWidget {
  final UserModel user;
  final int? maxQuota; // Cota diária máxima (se null, usa a do user ou padrão 25)
  final bool compact; // Se true, exibe versão enxuta para tabelas densas

  const AiUsageBadge({
    super.key,
    required this.user,
    this.maxQuota,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (user.isSuperAdmin) {
      return Tooltip(
        message: 'SuperAdmin: Cota de Inteligência Artificial Ilimitada',
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: compact ? 2 : 3),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF5FF),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFD8B4FE)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_awesome_rounded, size: 12, color: Color(0xFF9333EA)),
              const SizedBox(width: 4),
              Text(
                'IA: Ilimitada',
                style: GoogleFonts.inter(
                  fontSize: compact ? 10 : 11,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF7E22CE),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!user.canUseAi) {
      return Tooltip(
        message: 'Acesso à Inteligência Artificial desativado nas permissões deste usuário',
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: compact ? 2 : 3),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.block_rounded, size: 11, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Text(
                'IA: Bloqueada',
                style: GoogleFonts.inter(
                  fontSize: compact ? 10 : 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final usedToday = (user.aiUsageDate == todayStr) ? user.aiUsageCount : 0;
    final effectiveQuota = user.customDailyAiQuota ?? maxQuota ?? 25;
    final isExceeded = usedToday >= effectiveQuota;
    final isNearLimit = !isExceeded && usedToday >= (effectiveQuota * 0.8);

    Color bg;
    Color border;
    Color text;
    Color iconColor;

    if (isExceeded) {
      bg = const Color(0xFFFEF2F2);
      border = const Color(0xFFFECACA);
      text = const Color(0xFFDC2626);
      iconColor = const Color(0xFFEF4444);
    } else if (isNearLimit) {
      bg = const Color(0xFFFFFBEB);
      border = const Color(0xFFFDE68A);
      text = const Color(0xFFD97706);
      iconColor = const Color(0xFFF59E0B);
    } else if (usedToday > 0) {
      bg = const Color(0xFFEEF2FF);
      border = const Color(0xFFC7D2FE);
      text = const Color(0xFF4338CA);
      iconColor = const Color(0xFF6366F1);
    } else {
      bg = const Color(0xFFF8FAFC);
      border = const Color(0xFFE2E8F0);
      text = const Color(0xFF64748B);
      iconColor = const Color(0xFF94A3B8);
    }

    final tooltipText = isExceeded
        ? 'Limite Diário Atingido! ($usedToday de $effectiveQuota análises consumidas hoje. Renova à meia-noite)'
        : '$usedToday de $effectiveQuota análises com IA consumidas hoje (leitura de faturas, kits solares e orçamentos)';

    return Tooltip(
      message: tooltipText,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: compact ? 2 : 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isExceeded ? Icons.warning_amber_rounded : Icons.auto_awesome_rounded,
              size: compact ? 11 : 12,
              color: iconColor,
            ),
            const SizedBox(width: 4),
            Text(
              compact ? '$usedToday/$effectiveQuota IA' : 'IA: $usedToday / $effectiveQuota hoje',
              style: GoogleFonts.inter(
                fontSize: compact ? 10 : 11,
                fontWeight: FontWeight.bold,
                color: text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
