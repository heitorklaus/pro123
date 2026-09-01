import 'package:flutter/material.dart';

/// Widget de Background de Alta Tecnologia (Grade Cyberpunk, Gradientes Radiais e Brilho)
class TechBackground extends StatelessWidget {
  final Widget child;

  const TechBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Stack(
      children: [
        // 1. Fundo Gradiente Profundo
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF030712), // Slate 950 Quase Preto
                  Color(0xFF0B1120), // Azul Noite Profundo
                  Color(0xFF0F172A), // Slate 900
                  Color(0xFF1E1B4B), // Indigo Escuro
                ],
                stops: [0.0, 0.35, 0.70, 1.0],
              ),
            ),
          ),
        ),

        // 2. Orbe de Luz Superior Esquerdo (Indigo / Violeta)
        Positioned(
          top: -120,
          left: -100,
          child: Container(
            width: (size.width * 0.45).clamp(320.0, 600.0),
            height: (size.width * 0.45).clamp(320.0, 600.0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF6366F1).withValues(alpha: 0.25),
                  const Color(0xFF4F46E5).withValues(alpha: 0.10),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
        ),

        // 3. Orbe de Luz Inferior Direito (Cyan / Sky)
        Positioned(
          bottom: -140,
          right: -100,
          child: Container(
            width: (size.width * 0.45).clamp(320.0, 600.0),
            height: (size.width * 0.45).clamp(320.0, 600.0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF06B6D4).withValues(alpha: 0.20),
                  const Color(0xFF0284C7).withValues(alpha: 0.08),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.50, 1.0],
              ),
            ),
          ),
        ),

        // 4. Orbe de Luz Central Secundário (Púrpura Sutil)
        Positioned(
          top: size.height * 0.35,
          right: size.width * 0.15,
          child: Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                  Colors.transparent,
                ],
                stops: const [0.0, 1.0],
              ),
            ),
          ),
        ),

        // 5. Pintor de Malha e Linhas Tecnológicas (Tech Grid CustomPainter)
        Positioned.fill(
          child: CustomPaint(
            painter: _TechGridPainter(),
          ),
        ),

        // 6. Conteúdo da Página
        Positioned.fill(
          child: child,
        ),
      ],
    );
  }
}

class _TechGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const double step = 44.0;
    final gridPaint = Paint()
      ..color = const Color(0xFF6366F1).withValues(alpha: 0.045)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;

    // Linhas Verticais
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    // Linhas Horizontais
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Pontos de interseção tecnológicos (Nodes)
    for (double x = step * 2; x < size.width; x += step * 3) {
      for (double y = step * 2; y < size.height; y += step * 3) {
        canvas.drawCircle(Offset(x, y), 1.6, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
