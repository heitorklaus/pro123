import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Modelo de dados que define um passo educativo em um Tour Guiado
class TourStep {
  final String title;
  final String description;
  final IconData icon;
  final Color iconColor;
  final String? badgeText;
  final Color? badgeColor;
  final Widget? previewWidget;

  const TourStep({
    required this.title,
    required this.description,
    required this.icon,
    this.iconColor = const Color(0xFFF59E0B),
    this.badgeText,
    this.badgeColor,
    this.previewWidget,
  });
}

/// Gerenciador de persistência do status de tours guiados
class FeatureTourService {
  static const _storagePrefix = 'mavis_feature_tour_completed_';

  static Future<bool> isTourCompleted(String tourKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('$_storagePrefix$tourKey') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> markTourCompleted(String tourKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('$_storagePrefix$tourKey', true);
    } catch (_) {}
  }

  static Future<void> resetTour(String tourKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_storagePrefix$tourKey');
    } catch (_) {}
  }
}

/// Botão permanente e elegante para o usuário acionar as dicas da tela a qualquer momento
class FeatureTourHelpButton extends StatelessWidget {
  final VoidCallback onTap;
  final String label;
  final String tooltip;
  final Color primaryColor;

  const FeatureTourHelpButton({
    super.key,
    required this.onTap,
    this.label = 'Dicas da Tela',
    this.tooltip = 'Clique para ver o passo a passo de como usar esta tela',
    this.primaryColor = const Color(0xFFF59E0B),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 8 : 12,
              vertical: isMobile ? 6 : 8,
            ),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: primaryColor.withValues(alpha: isDark ? 0.5 : 0.35),
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lightbulb_rounded, size: isMobile ? 15 : 17, color: primaryColor),
                if (!isMobile) ...[
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Banner animado e interativo de Tour Educativo (balão de dicas passo a passo)
class FeatureGuidedTourBanner extends StatefulWidget {
  final String tourKey;
  final List<TourStep> steps;
  final VoidCallback? onDismissed;
  final bool autoCheckCompletion;

  const FeatureGuidedTourBanner({
    super.key,
    required this.tourKey,
    required this.steps,
    this.onDismissed,
    this.autoCheckCompletion = true,
  });

  @override
  State<FeatureGuidedTourBanner> createState() => FeatureGuidedTourBannerState();
}

class FeatureGuidedTourBannerState extends State<FeatureGuidedTourBanner>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  bool _isVisible = false;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));

    if (widget.autoCheckCompletion) {
      _checkIfShouldShow();
    } else {
      _show();
    }
  }

  Future<void> _checkIfShouldShow() async {
    final completed = await FeatureTourService.isTourCompleted(widget.tourKey);
    if (!completed && mounted) {
      _show();
    }
  }

  /// Método público para reabrir o tour externamente (por exemplo via FeatureTourHelpButton)
  void reopen() {
    setState(() => _currentStep = 0);
    _show();
  }

  void _show() {
    setState(() => _isVisible = true);
    _animCtrl.forward(from: 0.0);
  }

  Future<void> _dismiss({bool markCompleted = true}) async {
    await _animCtrl.reverse();
    if (mounted) {
      setState(() => _isVisible = false);
      if (markCompleted) {
        await FeatureTourService.markTourCompleted(widget.tourKey);
      }
      widget.onDismissed?.call();
    }
  }

  void _nextStep() {
    if (_currentStep < widget.steps.length - 1) {
      setState(() => _currentStep++);
    } else {
      _dismiss(markCompleted: true);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible || widget.steps.isEmpty) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = MediaQuery.of(context).size.width < 768;
    final step = widget.steps[_currentStep];
    final totalSteps = widget.steps.length;
    final isLastStep = _currentStep == totalSteps - 1;

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                  : [const Color(0xFFFFFFFF), const Color(0xFFF8FAFC)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: step.iconColor.withValues(alpha: isDark ? 0.4 : 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: step.iconColor.withValues(alpha: isDark ? 0.15 : 0.1),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                // Detalhe sutil de iluminação decorativa no topo
                PositionEdgeHighlight(color: step.iconColor),

                Padding(
                  padding: EdgeInsets.all(isMobile ? 16 : 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Cabeçalho do Balão (Badge do Passo + Indicadores de Bolinha + Botão Fechar)
                      Row(
                        children: [
                          // Badge do Passo
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: (step.badgeColor ?? step.iconColor).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: (step.badgeColor ?? step.iconColor).withValues(alpha: 0.35),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.school_rounded,
                                  size: 13,
                                  color: step.badgeColor ?? step.iconColor,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  step.badgeText ?? 'PASSO ${_currentStep + 1} DE $totalSteps',
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                    color: step.badgeColor ?? step.iconColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),

                          // Indicador de Progresso (Dots)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(totalSteps, (index) {
                              final isActive = index == _currentStep;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                width: isActive ? 18 : 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? step.iconColor
                                      : (isDark
                                          ? const Color(0xFF475569)
                                          : const Color(0xFFCBD5E1)),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(width: 12),

                          // Botão Fechar / Dispensar
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                            splashRadius: 16,
                            tooltip: 'Pular tour e fechar',
                            onPressed: () => _dismiss(markCompleted: true),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Conteúdo Principal: Ícone 3D estilizado + Textos
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Ícone com gradiente e sombra suave
                          Container(
                            width: isMobile ? 42 : 54,
                            height: isMobile ? 42 : 54,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  step.iconColor.withValues(alpha: 0.25),
                                  step.iconColor.withValues(alpha: 0.08),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: step.iconColor.withValues(alpha: 0.4),
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              step.icon,
                              size: isMobile ? 22 : 28,
                              color: step.iconColor,
                            ),
                          ),
                          const SizedBox(width: 14),

                          // Título e Descrição
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  step.title,
                                  style: GoogleFonts.outfit(
                                    fontSize: isMobile ? 15.5 : 18,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  step.description,
                                  style: GoogleFonts.inter(
                                    fontSize: isMobile ? 12.5 : 14,
                                    height: 1.45,
                                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                  ),
                                ),

                                // Preview/Destaque visual opcional (ex: botão simulado da tela)
                                if (step.previewWidget != null) ...[
                                  const SizedBox(height: 12),
                                  step.previewWidget!,
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Rodapé com Botões de Navegação (Pular, Anterior, Próximo)
                      Row(
                        children: [
                          TextButton(
                            onPressed: () => _dismiss(markCompleted: true),
                            style: TextButton.styleFrom(
                              foregroundColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            ),
                            child: Text(
                              'Pular Tour',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Spacer(),

                          // Botão Anterior
                          if (_currentStep > 0) ...[
                            OutlinedButton.icon(
                              onPressed: _prevStep,
                              icon: const Icon(Icons.arrow_back_rounded, size: 15),
                              label: Text(
                                'Anterior',
                                style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: isDark ? Colors.white : const Color(0xFF334155),
                                side: BorderSide(
                                  color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                                ),
                                padding: EdgeInsets.symmetric(
                                  horizontal: isMobile ? 12 : 16,
                                  vertical: isMobile ? 8 : 10,
                                ),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],

                          // Botão Próximo / Concluir
                          ElevatedButton.icon(
                            onPressed: _nextStep,
                            icon: Icon(
                              isLastStep ? Icons.check_circle_rounded : Icons.arrow_forward_rounded,
                              size: 16,
                            ),
                            label: Text(
                              isLastStep
                                  ? (isMobile ? 'Concluir' : 'Concluir Tour ✨')
                                  : (isMobile ? 'Próximo' : 'Próximo Passo ➜'),
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: step.iconColor,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              padding: EdgeInsets.symmetric(
                                horizontal: isMobile ? 14 : 20,
                                vertical: isMobile ? 8 : 11,
                              ),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Linha de brilho visual no topo do card
class PositionEdgeHighlight extends StatelessWidget {
  final Color color;

  const PositionEdgeHighlight({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 3,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.transparent,
              color,
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}
