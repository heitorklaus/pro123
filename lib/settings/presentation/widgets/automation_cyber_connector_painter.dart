import 'package:flutter/material.dart';
import '../../domain/models/automation_settings_model.dart';

/// CustomPainter que desenha as linhas cibernéticas luminosas neon conectando os nós de automação aos pontos de arquitetura
class AutomationCyberConnectorPainter extends CustomPainter {
  final List<AutomationCyberNode> nodes;
  final Color primaryColor;
  final String? selectedNodeId;

  AutomationCyberConnectorPainter({
    required this.nodes,
    required this.primaryColor,
    this.selectedNodeId,
  });

  static Color _parseColor(String? hex, Color fallback) {
    if (hex == null || hex.isEmpty) return fallback;
    try {
      final clean = hex.replaceAll('#', '').trim();
      if (clean.length == 6) return Color(int.parse('FF$clean', radix: 16));
      if (clean.length == 8) return Color(int.parse(clean, radix: 16));
      return fallback;
    } catch (_) {
      return fallback;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (nodes.isEmpty) return;

    for (final node in nodes) {
      if (!node.showConnectorLine) continue;

      final nodeColor = _parseColor(node.colorHex, primaryColor);
      final isSelected = selectedNodeId != null && selectedNodeId == node.id;

      final glowPaint = Paint()
        ..color = nodeColor.withValues(alpha: isSelected ? 0.75 : 0.45)
        ..strokeWidth = isSelected ? 5.0 : 3.8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = MaskFilter.blur(BlurStyle.solid, isSelected ? 5.0 : 3.5);

      final linePaint = Paint()
        ..color = isSelected ? Colors.white : nodeColor
        ..strokeWidth = isSelected ? 2.4 : 1.8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final ringPaint = Paint()
        ..color = nodeColor
        ..strokeWidth = isSelected ? 2.2 : 1.8
        ..style = PaintingStyle.stroke;

      final dotPaint = Paint()
        ..color = isSelected ? Colors.white : nodeColor
        ..style = PaintingStyle.fill;

      final pulsePaint = Paint()
        ..color = nodeColor.withValues(alpha: isSelected ? 0.40 : 0.25)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;

      final startX = node.posX * size.width;
      final startY = node.posY * size.height;
      final targetX = node.targetX * size.width;
      final targetY = node.targetY * size.height;

      // Traçado ortogonal em 90° estilo circuito/cyber (cotovelo de 2 segmentos)
      final path = Path();
      path.moveTo(startX, startY);

      final isVerticalFirst = (targetY - startY).abs() >= (targetX - startX).abs();
      if (isVerticalFirst) {
        path.lineTo(startX, targetY);
        path.lineTo(targetX, targetY);
      } else {
        path.lineTo(targetX, startY);
        path.lineTo(targetX, targetY);
      }

      // Desenhar brilho neon + linha principal
      canvas.drawPath(path, glowPaint);
      canvas.drawPath(path, linePaint);

      // Ponto terminal luminoso / anel alvo na arquitetura da residência
      canvas.drawCircle(Offset(targetX, targetY), isSelected ? 9.0 : 7.5, pulsePaint);
      canvas.drawCircle(Offset(targetX, targetY), 5.5, ringPaint);
      canvas.drawCircle(Offset(targetX, targetY), 2.2, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant AutomationCyberConnectorPainter oldDelegate) {
    return oldDelegate.nodes != nodes ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.selectedNodeId != selectedNodeId;
  }
}
