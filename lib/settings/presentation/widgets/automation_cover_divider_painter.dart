import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Painter que desenha os separadores geométricos / decalques matemáticos sobre a foto da capa da proposta
class AutomationCoverDividerPainter extends CustomPainter {
  final int dividerType; // 0 a 9 (10 Opções Matemáticas)
  final Color primaryColor;
  final Color accentColor;
  final Color darkColor;
  final double splitYRatio;

  AutomationCoverDividerPainter({
    required this.dividerType,
    required this.primaryColor,
    Color? accentColor,
    Color? darkColor,
    Color? bottomAreaColor,
    this.splitYRatio = 0.72,
  })  : accentColor = accentColor ?? primaryColor.withValues(alpha: 0.6),
        darkColor = bottomAreaColor ?? darkColor ?? const Color(0xFF0F172A);

  @override
  void paint(Canvas canvas, Size size) {
    if (dividerType < 0) return;

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

    // 0. Onda Suave Clássica (S-Curve)
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
      canvas.drawPath(p2, paintDark);
    }
    // 1. Onda Dupla Harmônica
    else if (dividerType == 1) {
      final p1 = Path();
      p1.moveTo(0, splitY - 15);
      p1.cubicTo(w * 0.25, splitY - 45, w * 0.75, splitY + 35, w, splitY - 10);
      p1.lineTo(w, h);
      p1.lineTo(0, h);
      p1.close();
      canvas.drawPath(p1, paintAccent);

      final p2 = Path();
      p2.moveTo(0, splitY);
      p2.cubicTo(w * 0.3, splitY - 30, w * 0.7, splitY + 45, w, splitY);
      p2.lineTo(w, h);
      p2.lineTo(0, h);
      p2.close();
      canvas.drawPath(p2, paintDark);
    }
    // 2. Corte Diagonal Moderno
    else if (dividerType == 2) {
      final p1 = Path();
      p1.moveTo(0, splitY - 20);
      p1.lineTo(w, splitY + 30);
      p1.lineTo(w, h);
      p1.lineTo(0, h);
      p1.close();
      canvas.drawPath(p1, paintAccent);

      final p2 = Path();
      p2.moveTo(0, splitY);
      p2.lineTo(w, splitY + 45);
      p2.lineTo(w, h);
      p2.lineTo(0, h);
      p2.close();
      canvas.drawPath(p2, paintDark);

      final pLine = Path();
      pLine.moveTo(0, splitY - 20);
      pLine.lineTo(w, splitY + 30);
      final paintLine = Paint()
        ..color = primaryColor
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke;
      canvas.drawPath(pLine, paintLine);
    }
    // 3. Polígonos Facetados (Chevron)
    else if (dividerType == 3) {
      final p1 = Path();
      p1.moveTo(0, splitY);
      p1.lineTo(w * 0.5, splitY - 40);
      p1.lineTo(w, splitY);
      p1.lineTo(w, h);
      p1.lineTo(0, h);
      p1.close();
      canvas.drawPath(p1, paintAccent);

      final p2 = Path();
      p2.moveTo(0, splitY + 12);
      p2.lineTo(w * 0.5, splitY - 28);
      p2.lineTo(w, splitY + 12);
      p2.lineTo(w, h);
      p2.lineTo(0, h);
      p2.close();
      canvas.drawPath(p2, paintDark);
    }
    // 4. Arco Aerodinâmico Côncavo
    else if (dividerType == 4) {
      final p1 = Path();
      p1.moveTo(0, splitY);
      p1.quadraticBezierTo(w * 0.5, splitY - 50, w, splitY);
      p1.lineTo(w, h);
      p1.lineTo(0, h);
      p1.close();
      canvas.drawPath(p1, paintDark);

      final pBorder = Path();
      pBorder.moveTo(0, splitY);
      pBorder.quadraticBezierTo(w * 0.5, splitY - 50, w, splitY);
      final paintBorder = Paint()
        ..color = primaryColor
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke;
      canvas.drawPath(pBorder, paintBorder);
    }
    // 5. Declive Arquitetônico Solar
    else if (dividerType == 5) {
      final p1 = Path();
      p1.moveTo(0, splitY + 40);
      p1.lineTo(w * 0.6, splitY - 30);
      p1.lineTo(w, splitY - 10);
      p1.lineTo(w, h);
      p1.lineTo(0, h);
      p1.close();
      canvas.drawPath(p1, paintDark);

      final pLine = Path();
      pLine.moveTo(0, splitY + 40);
      pLine.lineTo(w * 0.6, splitY - 30);
      pLine.lineTo(w, splitY - 10);
      final paintBorder = Paint()
        ..color = primaryColor
        ..strokeWidth = 3.5
        ..style = PaintingStyle.stroke;
      canvas.drawPath(pLine, paintBorder);
    }
    // 6. Trapezoidal High-End
    else if (dividerType == 6) {
      final p1 = Path();
      p1.moveTo(0, splitY);
      p1.lineTo(w * 0.35, splitY - 25);
      p1.lineTo(w * 0.65, splitY - 25);
      p1.lineTo(w, splitY);
      p1.lineTo(w, h);
      p1.lineTo(0, h);
      p1.close();
      canvas.drawPath(p1, paintDark);
    }
    // 7. Split Vertical Sólido
    else if (dividerType == 7) {
      canvas.drawRect(Rect.fromLTRB(0, 0, w * 0.38, h), paintDark);
      canvas.drawRect(Rect.fromLTRB(w * 0.38, 0, w * 0.39, h), paintMain);
    }
    // 8. Curva Senoidal Tripla
    else if (dividerType == 8) {
      final p1 = Path();
      p1.moveTo(0, splitY);
      for (double x = 0; x <= w; x += 5) {
        final t = x / w;
        final y = splitY + math.sin(t * math.pi * 3) * 15;
        p1.lineTo(x, y);
      }
      p1.lineTo(w, h);
      p1.lineTo(0, h);
      p1.close();
      canvas.drawPath(p1, paintDark);
    }
    // 9. Bloco Minimalista Clean
    else {
      canvas.drawRect(Rect.fromLTRB(0, splitY, w, h), paintDark);
      canvas.drawRect(Rect.fromLTRB(0, splitY - 4, w, splitY), paintMain);
    }
  }

  @override
  bool shouldRepaint(covariant AutomationCoverDividerPainter oldDelegate) {
    return oldDelegate.dividerType != dividerType ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.darkColor != darkColor ||
        oldDelegate.splitYRatio != splitYRatio;
  }
}
