import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Ícone estilizado da letra 'T' da marca TAOS com cortes de painel solar e brilho
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
      child: Center(
        child: CustomPaint(
          size: Size(size * 0.72, size * 0.72),
          painter: _TaosTPainter(),
        ),
      ),
    );
  }
}

class _TaosTPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF0A192F),
          Color(0xFF112240),
          Color(0xFF1B3A57),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;

    // Espaçamentos proporcionais
    final gap = w * 0.04;
    final topBarH = h * 0.28;
    final stemW = w * 0.32;
    final cornerR = Radius.circular(w * 0.08);

    // ── 1. Barra Horizontal Superior ──────────────────────────────────────
    // 1.1 Segmento Esquerdo
    final leftW = w * 0.32;
    final leftPath = Path()
      ..addRRect(RRect.fromRectAndCorners(
        Rect.fromLTWH(0, 0, leftW, topBarH),
        topLeft: cornerR,
        bottomLeft: cornerR,
      ));
    canvas.drawPath(leftPath, paint);

    // 1.2 Segmento Central
    final midLeft = leftW + gap;
    final midW = w * 0.42;
    final midRect = Rect.fromLTWH(midLeft, 0, midW, topBarH);
    canvas.drawRect(midRect, paint);

    // 1.3 Segmento Direito
    final rightLeft = midLeft + midW + gap;
    final rightW = w - rightLeft;
    if (rightW > 0) {
      final rightPath = Path()
        ..addRRect(RRect.fromRectAndCorners(
          Rect.fromLTWH(rightLeft, 0, rightW, topBarH),
          topRight: cornerR,
          bottomRight: cornerR,
        ));
      canvas.drawPath(rightPath, paint);
    }

    // ── 2. Ponto de Brilho Solar / Flare no canto superior direito ─────────
    final flareCenter = Offset(w * 0.94, topBarH * 0.18);
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFBBF24).withValues(alpha: 0.9),
          const Color(0xFFF59E0B).withValues(alpha: 0.4),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: flareCenter, radius: w * 0.18));
    canvas.drawCircle(flareCenter, w * 0.16, glowPaint);

    final flareCorePaint = Paint()
      ..color = const Color(0xFFFEF3C7)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(flareCenter, w * 0.045, flareCorePaint);

    // ── 3. Haste Vertical (Dividida em 2 painéis) ──────────────────────────
    final stemLeft = (w - stemW) / 2;
    final stemTop1 = topBarH + gap;
    final stemH1 = (h - stemTop1 - gap) * 0.48;

    // 3.1 Painel Vertical Superior
    canvas.drawRect(
      Rect.fromLTWH(stemLeft, stemTop1, stemW, stemH1),
      paint,
    );

    // 3.2 Painel Vertical Inferior
    final stemTop2 = stemTop1 + stemH1 + gap;
    final stemH2 = h - stemTop2;
    if (stemH2 > 0) {
      final bottomPath = Path()
        ..addRRect(RRect.fromRectAndCorners(
          Rect.fromLTWH(stemLeft, stemTop2, stemW, stemH2),
          bottomLeft: Radius.circular(w * 0.04),
          bottomRight: Radius.circular(w * 0.12),
        ));
      canvas.drawPath(bottomPath, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Logo Completa TAOS CRM com Ícone Branco + Tipografia 'TAOS' e 'CRM'
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
    return Row(
      mainAxisSize: mainAxisSize,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        TaosLogoIcon(size: iconSize),
        const SizedBox(width: 12),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'TAOS',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w900,
                  fontSize: fontSize,
                  color: isDarkBackground ? Colors.white : const Color(0xFF0F172A),
                  letterSpacing: 2.2,
                ),
              ),
              const WidgetSpan(child: SizedBox(width: 6)),
              TextSpan(
                text: 'CRM',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w800,
                  fontSize: fontSize,
                  color: const Color(0xFF38BDF8), // Cyan / Sky Blue moderno
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
