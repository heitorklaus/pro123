import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/widgets/taos_logo.dart';

/// Popup flutuante de carregamento no mesmo estilo visual da tela inicial (Splash TAOS).
class TaosLoadingPopup extends StatefulWidget {
  final String message;

  const TaosLoadingPopup({
    super.key,
    this.message = 'Carregando Imagem',
  });

  static const BoxDecoration pdfBackdropDecoration = BoxDecoration(
    gradient: RadialGradient(
      center: Alignment(0, -0.2),
      radius: 1.35,
      colors: [
        Color(0xFF1E293B),
        Color(0xFF0F172A),
        Color(0xFF070B14),
      ],
    ),
  );

  static Widget pdfLoadingWidget({
    String message = 'Proposta sendo gerada...',
  }) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: pdfBackdropDecoration,
      child: TaosLoadingPopup(message: message),
    );
  }

  static Future<void> show(
    BuildContext context, {
    String message = 'Carregando Imagem',
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => TaosLoadingPopup(message: message),
    );
  }

  static void hide(BuildContext context) {
    final nav = Navigator.of(context, rootNavigator: true);
    if (nav.canPop()) {
      nav.pop();
    }
  }

  @override
  State<TaosLoadingPopup> createState() => _TaosLoadingPopupState();
}

class _TaosLoadingPopupState extends State<TaosLoadingPopup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1250),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 300,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 30),
            decoration: BoxDecoration(
              gradient: const RadialGradient(
                center: Alignment(0, -0.3),
                radius: 1.1,
                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF06B6D4).withValues(alpha: 0.35),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF06B6D4).withValues(alpha: 0.18),
                  blurRadius: 32,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.55),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const TaosLoginLogo(
                  width: 190,
                  isDarkBackground: true,
                ),
                const SizedBox(height: 20),
                Container(
                  width: 220,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF94A3B8).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: AnimatedBuilder(
                    animation: _ctrl,
                    builder: (_, __) {
                      final dx = -110.0 + (_ctrl.value * 330.0);
                      return Transform.translate(
                        offset: Offset(dx, 0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            width: 99,
                            height: 4,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF6366F1),
                                  Color(0xFF06B6D4),
                                  Color(0xFF10B981),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  widget.message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: const Color(0xFFCBD5E1),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
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
