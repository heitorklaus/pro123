import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Ícone estilizado da nova marca TAOS (Letra 'T' com corte diagonal e haste dupla) dentro de um quadrado branco com cantos arredondados
class TaosLogoIcon extends StatelessWidget {
  final double size;
  final double borderRadius;
  final bool showShadow;

  const TaosLogoIcon({
    super.key,
    this.size = 36,
    this.borderRadius = 10,
    this.showShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(size * 0.10),
          child: Image.asset(
            'assets/images/taos_t_icon.png',
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

/// Logo Horizontal para AppBar e Barras de Navegação (T no quadrado branco + TAOS solto + CRM)
class TaosLogo extends StatelessWidget {
  final double iconSize;
  final double fontSize;
  final bool isDarkBackground;
  final MainAxisSize mainAxisSize;

  const TaosLogo({
    super.key,
    this.iconSize = 36,
    this.fontSize = 20,
    this.isDarkBackground = true,
    this.mainAxisSize = MainAxisSize.min,
  });

  @override
  Widget build(BuildContext context) {
    final wordmarkHeight = fontSize * 0.85;

    return Row(
      mainAxisSize: mainAxisSize,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // T dentro do quadrado branco
        TaosLogoIcon(
          size: iconSize,
          borderRadius: iconSize * 0.28,
        ),
        const SizedBox(width: 10),
        // Tipografia TAOS solta
        Image.asset(
          isDarkBackground
              ? 'assets/images/taos_wordmark_white.png'
              : 'assets/images/taos_wordmark_dark.png',
          height: wordmarkHeight,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Text(
              'TΛOS',
              style: GoogleFonts.orbitron(
                fontWeight: FontWeight.w900,
                fontSize: fontSize,
                color: isDarkBackground ? Colors.white : const Color(0xFF0F172A),
                letterSpacing: 3.5,
              ),
            );
          },
        ),
        const SizedBox(width: 8),
        // Tag CRM estilizada em Cyan/Sky Blue
        Text(
          'CRM',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w900,
            fontSize: fontSize * 0.95,
            color: const Color(0xFF38BDF8),
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}

/// Logo Vertical Completa para Login e Cadastro (T no topo, TAOS abaixo e Slogan)
class TaosLoginLogo extends StatelessWidget {
  final double width;
  final bool isDarkBackground;

  const TaosLoginLogo({
    super.key,
    this.width = 220,
    this.isDarkBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset(
          'assets/images/taos_login_logo.png',
          width: width,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/images/taos_t_icon.png', width: width * 0.45),
                const SizedBox(height: 10),
                Image.asset('assets/images/taos_wordmark_dark.png', width: width * 0.8),
                const SizedBox(height: 6),
                Text(
                  'TECHNOLOGY • AI • OPERATIONS • SALES',
                  style: GoogleFonts.inter(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                    color: const Color(0xFF475569),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
