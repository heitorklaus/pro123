import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Ícone estilizado da letra 'T' da marca TAOS dentro de um quadrado branco com cantos arredondados
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
          padding: EdgeInsets.all(size * 0.12),
          child: Image.asset(
            'assets/images/taos_t_icon.png',
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return CustomPaint(
                size: Size(size * 0.76, size * 0.76),
                painter: _TaosTPainter(),
              );
            },
          ),
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

    final gap = w * 0.04;
    final topBarH = h * 0.28;
    final stemW = w * 0.32;
    final cornerR = Radius.circular(w * 0.08);

    // Barra Superior
    final leftW = w * 0.32;
    final leftPath = Path()
      ..addRRect(RRect.fromRectAndCorners(
        Rect.fromLTWH(0, 0, leftW, topBarH),
        topLeft: cornerR,
        bottomLeft: cornerR,
      ));
    canvas.drawPath(leftPath, paint);

    final midLeft = leftW + gap;
    final midW = w * 0.42;
    canvas.drawRect(Rect.fromLTWH(midLeft, 0, midW, topBarH), paint);

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

    // Flare Solar
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

    // Haste Vertical
    final stemLeft = (w - stemW) / 2;
    final stemTop1 = topBarH + gap;
    final stemH1 = (h - stemTop1 - gap) * 0.48;

    canvas.drawRect(
      Rect.fromLTWH(stemLeft, stemTop1, stemW, stemH1),
      paint,
    );

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

/// Logo Completa TAOS CRM com Ícone T Branco + Tipografia Oficial 'TAOS' e 'CRM'
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
    final wordmarkHeight = fontSize * 0.82;

    return Row(
      mainAxisSize: mainAxisSize,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        TaosLogoIcon(size: iconSize),
        const SizedBox(width: 10),
        // Tipografia Oficial TAOS (com o A futurista / lambda)
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
        // Badge / Texto CRM
        Text(
          'CRM',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w900,
            fontSize: fontSize * 0.95,
            color: const Color(0xFF38BDF8), // Sky / Cyan moderno
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}
