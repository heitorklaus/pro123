import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Painter que desenha em tempo real qualquer um dos 10 decalques/separadores sobre fotos customizadas
class SolarCoverDividerPainter extends CustomPainter {
  final int dividerType; // 0 a 9
  final Color primaryColor;
  final Color accentColor;
  final Color darkColor;
  final double splitYRatio; // Posição do corte (ex: 0.72)

  SolarCoverDividerPainter({
    required this.dividerType,
    required this.primaryColor,
    Color? accentColor,
    Color? darkColor,
    this.splitYRatio = 0.72,
  })  : accentColor = accentColor ?? primaryColor.withValues(alpha: 0.6),
        darkColor = darkColor ?? const Color(0xFF0F172A);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final splitY = h * splitYRatio;

    final paintMain = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill;

    final paintAccent = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;

    final paintDark = Paint()
      ..color = darkColor
      ..style = PaintingStyle.fill;

    final paintWhite = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // 0. Classic Smooth S-Wave
    if (dividerType == 0) {
      final p1 = Path();
      p1.moveTo(0, splitY);
      for (double x = 0; x <= w; x += 10) {
        final t = x / w;
        final y = splitY + math.sin(t * math.pi * 1.5) * (h * 0.045) - (t * h * 0.035);
        p1.lineTo(x, y);
      }
      p1.lineTo(w, h);
      p1.lineTo(0, h);
      p1.close();
      canvas.drawPath(p1, paintAccent);

      final p2 = Path();
      p2.moveTo(0, splitY + 12);
      for (double x = 0; x <= w; x += 10) {
        final t = x / w;
        final y = splitY + 12 + math.sin(t * math.pi * 1.5) * (h * 0.045) - (t * h * 0.035);
        p2.lineTo(x, y);
      }
      p2.lineTo(w, h);
      p2.lineTo(0, h);
      p2.close();
      canvas.drawPath(p2, paintMain);

      final pWhite = Path();
      pWhite.moveTo(0, splitY + 28);
      for (double x = 0; x <= w; x += 10) {
        final t = x / w;
        final y = splitY + 28 + math.sin(t * math.pi * 1.5) * (h * 0.045) - (t * h * 0.035);
        pWhite.lineTo(x, y);
      }
      pWhite.lineTo(w, h);
      pWhite.lineTo(0, h);
      pWhite.close();
      canvas.drawPath(pWhite, paintWhite);
    }
    // 1. Double Harmonic Intersecting Waves
    else if (dividerType == 1) {
      final p1 = Path();
      p1.moveTo(0, splitY);
      for (double x = 0; x <= w; x += 10) {
        final t = x / w;
        final y = splitY + math.sin(t * math.pi * 2.2) * (h * 0.03) + math.cos(t * math.pi) * (h * 0.015);
        p1.lineTo(x, y);
      }
      p1.lineTo(w, h);
      p1.lineTo(0, h);
      p1.close();
      canvas.drawPath(p1, paintMain);

      final p2 = Path();
      p2.moveTo(0, splitY + 10);
      for (double x = 0; x <= w; x += 10) {
        final t = x / w;
        final y = splitY + 10 + math.cos(t * math.pi * 1.8) * (h * 0.035);
        p2.lineTo(x, y);
      }
      p2.lineTo(w, h);
      p2.lineTo(0, h);
      p2.close();
      canvas.drawPath(p2, paintAccent);

      final pWhite = Path();
      pWhite.moveTo(0, splitY + 25);
      for (double x = 0; x <= w; x += 10) {
        final t = x / w;
        final y = splitY + 25 + math.cos(t * math.pi * 1.8) * (h * 0.035);
        pWhite.lineTo(x, y);
      }
      pWhite.lineTo(w, h);
      pWhite.lineTo(0, h);
      pWhite.close();
      canvas.drawPath(pWhite, paintWhite);
    }
    // 2. Modern Angular Diagonal Slash
    else if (dividerType == 2) {
      final p1 = Path()
        ..moveTo(0, splitY + 20)
        ..lineTo(w, splitY - 40)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
      canvas.drawPath(p1, paintDark);

      final p2 = Path()
        ..moveTo(0, splitY + 32)
        ..lineTo(w, splitY - 28)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
      canvas.drawPath(p2, paintAccent);

      final p3 = Path()
        ..moveTo(0, splitY + 44)
        ..lineTo(w, splitY - 16)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
      canvas.drawPath(p3, paintMain);

      final pWhite = Path()
        ..moveTo(0, splitY + 58)
        ..lineTo(w, splitY - 2)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
      canvas.drawPath(pWhite, paintWhite);
    }
    // 3. Geometric Faceted Triangles / Chevrons
    else if (dividerType == 3) {
      final midX = w * 0.65;
      final p1 = Path()
        ..moveTo(0, splitY + 15)
        ..lineTo(midX, splitY - 25)
        ..lineTo(w, splitY + 20)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
      canvas.drawPath(p1, paintAccent);

      final p2 = Path()
        ..moveTo(0, splitY + 30)
        ..lineTo(midX, splitY - 10)
        ..lineTo(w, splitY + 35)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
      canvas.drawPath(p2, paintMain);

      final pWhite = Path()
        ..moveTo(0, splitY + 45)
        ..lineTo(midX, splitY + 5)
        ..lineTo(w, splitY + 50)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
      canvas.drawPath(pWhite, paintWhite);
    }
    // 4. Aerodynamic Concave Curved Arch
    else if (dividerType == 4) {
      final p1 = Path();
      p1.moveTo(0, splitY);
      for (double x = 0; x <= w; x += 10) {
        final t = (x - w / 2) / (w / 2);
        final y = splitY - (1 - t * t) * (h * 0.05);
        p1.lineTo(x, y);
      }
      p1.lineTo(w, h);
      p1.lineTo(0, h);
      p1.close();
      canvas.drawPath(p1, paintAccent);

      final p2 = Path();
      p2.moveTo(0, splitY + 14);
      for (double x = 0; x <= w; x += 10) {
        final t = (x - w / 2) / (w / 2);
        final y = splitY + 14 - (1 - t * t) * (h * 0.05);
        p2.lineTo(x, y);
      }
      p2.lineTo(w, h);
      p2.lineTo(0, h);
      p2.close();
      canvas.drawPath(p2, paintMain);

      final pWhite = Path();
      pWhite.moveTo(0, splitY + 28);
      for (double x = 0; x <= w; x += 10) {
        final t = (x - w / 2) / (w / 2);
        final y = splitY + 28 - (1 - t * t) * (h * 0.05);
        pWhite.lineTo(x, y);
      }
      pWhite.lineTo(w, h);
      pWhite.lineTo(0, h);
      pWhite.close();
      canvas.drawPath(pWhite, paintWhite);
    }
    // 5. Dual Slope Architectural Facet
    else if (dividerType == 5) {
      final p1 = Path()
        ..moveTo(0, splitY + 25)
        ..lineTo(w * 0.35, splitY - 15)
        ..lineTo(w * 0.75, splitY + 10)
        ..lineTo(w, splitY - 20)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
      canvas.drawPath(p1, paintAccent);

      final p2 = Path()
        ..moveTo(0, splitY + 38)
        ..lineTo(w * 0.35, splitY - 2)
        ..lineTo(w * 0.75, splitY + 23)
        ..lineTo(w, splitY - 7)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
      canvas.drawPath(p2, paintMain);

      final pWhite = Path()
        ..moveTo(0, splitY + 50)
        ..lineTo(w * 0.35, splitY + 10)
        ..lineTo(w * 0.75, splitY + 35)
        ..lineTo(w, splitY + 5)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
      canvas.drawPath(pWhite, paintWhite);
    }
    // 6. Triple Ripple Wave Cascade
    else if (dividerType == 6) {
      final p1 = Path();
      p1.moveTo(0, splitY);
      for (double x = 0; x <= w; x += 10) {
        final t = x / w;
        final y = splitY + math.sin(t * math.pi * 3.0) * (h * 0.02) - (t * 10);
        p1.lineTo(x, y);
      }
      p1.lineTo(w, h);
      p1.lineTo(0, h);
      p1.close();
      canvas.drawPath(p1, paintAccent);

      final p2 = Path();
      p2.moveTo(0, splitY + 12);
      for (double x = 0; x <= w; x += 10) {
        final t = x / w;
        final y = splitY + 12 + math.sin(t * math.pi * 3.0) * (h * 0.02) - (t * 10);
        p2.lineTo(x, y);
      }
      p2.lineTo(w, h);
      p2.lineTo(0, h);
      p2.close();
      canvas.drawPath(p2, paintMain);

      final pWhite = Path();
      pWhite.moveTo(0, splitY + 25);
      for (double x = 0; x <= w; x += 10) {
        final t = x / w;
        final y = splitY + 25 + math.sin(t * math.pi * 3.0) * (h * 0.02) - (t * 10);
        pWhite.lineTo(x, y);
      }
      pWhite.lineTo(w, h);
      pWhite.lineTo(0, h);
      pWhite.close();
      canvas.drawPath(pWhite, paintWhite);
    }
    // 7. Hexagonal Tech Polygon
    else if (dividerType == 7) {
      final p1 = Path()
        ..moveTo(0, splitY - 10)
        ..lineTo(w * 0.4, splitY - 10)
        ..lineTo(w * 0.52, splitY + 30)
        ..lineTo(w, splitY + 30)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
      canvas.drawPath(p1, paintAccent);

      final p2 = Path()
        ..moveTo(0, splitY + 5)
        ..lineTo(w * 0.4 + 5, splitY + 5)
        ..lineTo(w * 0.52 + 5, splitY + 45)
        ..lineTo(w, splitY + 45)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
      canvas.drawPath(p2, paintMain);

      final pWhite = Path()
        ..moveTo(0, splitY + 20)
        ..lineTo(w * 0.4 + 10, splitY + 20)
        ..lineTo(w * 0.52 + 10, splitY + 60)
        ..lineTo(w, splitY + 60)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
      canvas.drawPath(pWhite, paintWhite);
    }
    // 8. Convex Arch
    else if (dividerType == 8) {
      final p1 = Path();
      p1.moveTo(0, splitY);
      for (double x = 0; x <= w; x += 10) {
        final t = (x - w / 2) / (w / 2);
        final y = splitY + (1 - t * t) * (h * 0.04);
        p1.lineTo(x, y);
      }
      p1.lineTo(w, h);
      p1.lineTo(0, h);
      p1.close();
      canvas.drawPath(p1, paintAccent);

      final p2 = Path();
      p2.moveTo(0, splitY + 12);
      for (double x = 0; x <= w; x += 10) {
        final t = (x - w / 2) / (w / 2);
        final y = splitY + 12 + (1 - t * t) * (h * 0.04);
        p2.lineTo(x, y);
      }
      p2.lineTo(w, h);
      p2.lineTo(0, h);
      p2.close();
      canvas.drawPath(p2, paintMain);

      final pWhite = Path();
      pWhite.moveTo(0, splitY + 25);
      for (double x = 0; x <= w; x += 10) {
        final t = (x - w / 2) / (w / 2);
        final y = splitY + 25 + (1 - t * t) * (h * 0.04);
        pWhite.lineTo(x, y);
      }
      pWhite.lineTo(w, h);
      pWhite.lineTo(0, h);
      pWhite.close();
      canvas.drawPath(pWhite, paintWhite);
    }
    // 9. Angular Sweep
    else {
      final p1 = Path();
      p1.moveTo(0, splitY + 30);
      for (double x = 0; x <= w; x += 10) {
        final t = x / w;
        final y = splitY + (0.5 - t) * (h * 0.08) + math.sin(t * math.pi) * (h * 0.02);
        p1.lineTo(x, y);
      }
      p1.lineTo(w, h);
      p1.lineTo(0, h);
      p1.close();
      canvas.drawPath(p1, paintAccent);

      final p2 = Path();
      p2.moveTo(0, splitY + 42);
      for (double x = 0; x <= w; x += 10) {
        final t = x / w;
        final y = splitY + 12 + (0.5 - t) * (h * 0.08) + math.sin(t * math.pi) * (h * 0.02);
        p2.lineTo(x, y);
      }
      p2.lineTo(w, h);
      p2.lineTo(0, h);
      p2.close();
      canvas.drawPath(p2, paintMain);

      final pWhite = Path();
      pWhite.moveTo(0, splitY + 55);
      for (double x = 0; x <= w; x += 10) {
        final t = x / w;
        final y = splitY + 25 + (0.5 - t) * (h * 0.08) + math.sin(t * math.pi) * (h * 0.02);
        pWhite.lineTo(x, y);
      }
      pWhite.lineTo(w, h);
      pWhite.lineTo(0, h);
      pWhite.close();
      canvas.drawPath(pWhite, paintWhite);
    }
  }

  @override
  bool shouldRepaint(covariant SolarCoverDividerPainter oldDelegate) {
    return oldDelegate.dividerType != dividerType ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.darkColor != darkColor ||
        oldDelegate.splitYRatio != splitYRatio;
  }
}
