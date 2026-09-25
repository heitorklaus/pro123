import 'dart:math' as math;

/// Construtor de SVGs dos 10 divisores matemáticos / separadores da capa de propostas.
/// Replica com 100% de fidelidade visual os mesmos algoritmos de `SolarCoverDividerPainter`.
class CoverDividerSvgBuilder {
  /// Gera a string do SVG completo contendo todos os layers do divisor vetorial selecionado.
  static String buildSvg({
    required int dividerType,
    required double width,
    required double height,
    double splitYRatio = 0.70,
    required String primaryColorHex,
    required String bottomAreaColorHex,
  }) {
    final w = width;
    final h = height;
    final splitY = h * splitYRatio;

    final primaryHex = _formatHex(primaryColorHex, '#F59E0B');
    final bottomHex = _formatHex(bottomAreaColorHex, '#FFFFFF');
    final accentHex = _calculateAccentHex(primaryHex, bottomHex, factor: 0.60);

    if (dividerType < 0) {
      return '<svg viewBox="0 0 $w $h" width="$w" height="$h" xmlns="http://www.w3.org/2000/svg"></svg>';
    }

    final sb = StringBuffer();
    sb.writeln('<svg viewBox="0 0 $w $h" width="$w" height="$h" xmlns="http://www.w3.org/2000/svg">');

    switch (dividerType) {
      // 0. Onda Suave Clássica (S-Curve)
      case 0:
        final p1 = _buildSampledPath(w, h, (x, t) {
          return splitY + math.sin(t * math.pi * 1.5) * (h * 0.045) - (t * h * 0.035);
        });
        final p2 = _buildSampledPath(w, h, (x, t) {
          return splitY + 12 + math.sin(t * math.pi * 1.5) * (h * 0.045) - (t * h * 0.035);
        });
        final pWhite = _buildSampledPath(w, h, (x, t) {
          return splitY + 28 + math.sin(t * math.pi * 1.5) * (h * 0.045) - (t * h * 0.035);
        });

        sb.writeln('  <path d="$p1" fill="$accentHex" />');
        sb.writeln('  <path d="$p2" fill="$primaryHex" />');
        sb.writeln('  <path d="$pWhite" fill="$bottomHex" />');
        break;

      // 1. Onda Dupla Harmônica (Intersecting Harmonic Waves)
      case 1:
        final p1 = _buildSampledPath(w, h, (x, t) {
          return splitY + math.sin(t * math.pi * 2.2) * (h * 0.03) + math.cos(t * math.pi) * (h * 0.015);
        });
        final p2 = _buildSampledPath(w, h, (x, t) {
          return splitY + 10 + math.cos(t * math.pi * 1.8) * (h * 0.035);
        });
        final pWhite = _buildSampledPath(w, h, (x, t) {
          return splitY + 25 + math.cos(t * math.pi * 1.8) * (h * 0.035);
        });

        sb.writeln('  <path d="$p1" fill="$primaryHex" />');
        sb.writeln('  <path d="$p2" fill="$accentHex" />');
        sb.writeln('  <path d="$pWhite" fill="$bottomHex" />');
        break;

      // 2. Corte Diagonal Moderno (Tri-Stripe Angular)
      case 2:
        sb.writeln('  <polygon points="0,${(splitY + 20).toStringAsFixed(1)} $w,${(splitY - 40).toStringAsFixed(1)} $w,$h 0,$h" fill="#0F172A" />');
        sb.writeln('  <polygon points="0,${(splitY + 32).toStringAsFixed(1)} $w,${(splitY - 28).toStringAsFixed(1)} $w,$h 0,$h" fill="$accentHex" />');
        sb.writeln('  <polygon points="0,${(splitY + 44).toStringAsFixed(1)} $w,${(splitY - 16).toStringAsFixed(1)} $w,$h 0,$h" fill="$primaryHex" />');
        sb.writeln('  <polygon points="0,${(splitY + 58).toStringAsFixed(1)} $w,${(splitY - 2).toStringAsFixed(1)} $w,$h 0,$h" fill="$bottomHex" />');
        break;

      // 3. Polígonos Facetados (Chevron)
      case 3:
        final midX = (w * 0.65).toStringAsFixed(1);
        sb.writeln('  <polygon points="0,${(splitY + 15).toStringAsFixed(1)} $midX,${(splitY - 25).toStringAsFixed(1)} $w,${(splitY + 20).toStringAsFixed(1)} $w,$h 0,$h" fill="$accentHex" />');
        sb.writeln('  <polygon points="0,${(splitY + 30).toStringAsFixed(1)} $midX,${(splitY - 10).toStringAsFixed(1)} $w,${(splitY + 35).toStringAsFixed(1)} $w,$h 0,$h" fill="$primaryHex" />');
        sb.writeln('  <polygon points="0,${(splitY + 45).toStringAsFixed(1)} $midX,${(splitY + 5).toStringAsFixed(1)} $w,${(splitY + 50).toStringAsFixed(1)} $w,$h 0,$h" fill="$bottomHex" />');
        break;

      // 4. Arco Aerodinâmico Côncavo
      case 4:
        final p1 = _buildSampledPath(w, h, (x, t) {
          final relT = (x - w / 2) / (w / 2);
          return splitY - (1 - relT * relT) * (h * 0.05);
        });
        final p2 = _buildSampledPath(w, h, (x, t) {
          final relT = (x - w / 2) / (w / 2);
          return splitY + 14 - (1 - relT * relT) * (h * 0.05);
        });
        final pWhite = _buildSampledPath(w, h, (x, t) {
          final relT = (x - w / 2) / (w / 2);
          return splitY + 28 - (1 - relT * relT) * (h * 0.05);
        });

        sb.writeln('  <path d="$p1" fill="$accentHex" />');
        sb.writeln('  <path d="$p2" fill="$primaryHex" />');
        sb.writeln('  <path d="$pWhite" fill="$bottomHex" />');
        break;

      // 5. Declive Arquitetônico Solar / Minimalista
      case 5:
        final x1 = (w * 0.35).toStringAsFixed(1);
        final x2 = (w * 0.75).toStringAsFixed(1);
        sb.writeln('  <polygon points="0,${(splitY + 25).toStringAsFixed(1)} $x1,${(splitY - 15).toStringAsFixed(1)} $x2,${(splitY + 10).toStringAsFixed(1)} $w,${(splitY - 20).toStringAsFixed(1)} $w,$h 0,$h" fill="$accentHex" />');
        sb.writeln('  <polygon points="0,${(splitY + 38).toStringAsFixed(1)} $x1,${(splitY - 2).toStringAsFixed(1)} $x2,${(splitY + 23).toStringAsFixed(1)} $w,${(splitY - 7).toStringAsFixed(1)} $w,$h 0,$h" fill="$primaryHex" />');
        sb.writeln('  <polygon points="0,${(splitY + 50).toStringAsFixed(1)} $x1,${(splitY + 10).toStringAsFixed(1)} $x2,${(splitY + 35).toStringAsFixed(1)} $w,${(splitY + 5).toStringAsFixed(1)} $w,$h 0,$h" fill="$bottomHex" />');
        break;

      // 6. Cascata Tripla de Ondas
      case 6:
        final p1 = _buildSampledPath(w, h, (x, t) {
          return splitY + math.sin(t * math.pi * 3.0) * (h * 0.02) - (t * 10);
        });
        final p2 = _buildSampledPath(w, h, (x, t) {
          return splitY + 12 + math.sin(t * math.pi * 3.0) * (h * 0.02) - (t * 10);
        });
        final pWhite = _buildSampledPath(w, h, (x, t) {
          return splitY + 25 + math.sin(t * math.pi * 3.0) * (h * 0.02) - (t * 10);
        });

        sb.writeln('  <path d="$p1" fill="$accentHex" />');
        sb.writeln('  <path d="$p2" fill="$primaryHex" />');
        sb.writeln('  <path d="$pWhite" fill="$bottomHex" />');
        break;

      // 7. Hexágono Tech Futurista
      case 7:
        final hx1 = (w * 0.4).toStringAsFixed(1);
        final hx2 = (w * 0.52).toStringAsFixed(1);
        final hx1b = (w * 0.4 + 5).toStringAsFixed(1);
        final hx2b = (w * 0.52 + 5).toStringAsFixed(1);
        final hx1c = (w * 0.4 + 10).toStringAsFixed(1);
        final hx2c = (w * 0.52 + 10).toStringAsFixed(1);

        sb.writeln('  <polygon points="0,${(splitY - 10).toStringAsFixed(1)} $hx1,${(splitY - 10).toStringAsFixed(1)} $hx2,${(splitY + 30).toStringAsFixed(1)} $w,${(splitY + 30).toStringAsFixed(1)} $w,$h 0,$h" fill="$accentHex" />');
        sb.writeln('  <polygon points="0,${(splitY + 5).toStringAsFixed(1)} $hx1b,${(splitY + 5).toStringAsFixed(1)} $hx2b,${(splitY + 45).toStringAsFixed(1)} $w,${(splitY + 45).toStringAsFixed(1)} $w,$h 0,$h" fill="$primaryHex" />');
        sb.writeln('  <polygon points="0,${(splitY + 20).toStringAsFixed(1)} $hx1c,${(splitY + 20).toStringAsFixed(1)} $hx2c,${(splitY + 60).toStringAsFixed(1)} $w,${(splitY + 60).toStringAsFixed(1)} $w,$h 0,$h" fill="$bottomHex" />');
        break;

      // 8. Arco Convexo Aerodinâmico
      case 8:
        final p1 = _buildSampledPath(w, h, (x, t) {
          final relT = (x - w / 2) / (w / 2);
          return splitY + (1 - relT * relT) * (h * 0.04);
        });
        final p2 = _buildSampledPath(w, h, (x, t) {
          final relT = (x - w / 2) / (w / 2);
          return splitY + 12 + (1 - relT * relT) * (h * 0.04);
        });
        final pWhite = _buildSampledPath(w, h, (x, t) {
          final relT = (x - w / 2) / (w / 2);
          return splitY + 25 + (1 - relT * relT) * (h * 0.04);
        });

        sb.writeln('  <path d="$p1" fill="$accentHex" />');
        sb.writeln('  <path d="$p2" fill="$primaryHex" />');
        sb.writeln('  <path d="$pWhite" fill="$bottomHex" />');
        break;

      // 9. Varredura Angular Ascendente (ou default)
      case 9:
      default:
        final p1 = _buildSampledPath(w, h, (x, t) {
          return splitY + 30 + (0.5 - t) * (h * 0.08) + math.sin(t * math.pi) * (h * 0.02);
        });
        final p2 = _buildSampledPath(w, h, (x, t) {
          return splitY + 42 + (0.5 - t) * (h * 0.08) + math.sin(t * math.pi) * (h * 0.02);
        });
        final pWhite = _buildSampledPath(w, h, (x, t) {
          return splitY + 55 + (0.5 - t) * (h * 0.08) + math.sin(t * math.pi) * (h * 0.02);
        });

        sb.writeln('  <path d="$p1" fill="$accentHex" />');
        sb.writeln('  <path d="$p2" fill="$primaryHex" />');
        sb.writeln('  <path d="$pWhite" fill="$bottomHex" />');
        break;
    }

    sb.writeln('</svg>');
    return sb.toString();
  }

  /// Gera um caminho SVG com amostragem matemática de pontos para curvas suaves
  static String _buildSampledPath(
    double w,
    double h,
    double Function(double x, double t) yFunc, {
    double step = 8.0,
  }) {
    final sb = StringBuffer();
    final y0 = yFunc(0.0, 0.0);
    sb.write('M 0 ${y0.toStringAsFixed(2)}');

    for (double x = step; x < w; x += step) {
      final t = x / w;
      final y = yFunc(x, t);
      sb.write(' L ${x.toStringAsFixed(1)} ${y.toStringAsFixed(2)}');
    }

    final yEnd = yFunc(w, 1.0);
    sb.write(' L ${w.toStringAsFixed(1)} ${yEnd.toStringAsFixed(2)}');
    sb.write(' L ${w.toStringAsFixed(1)} ${h.toStringAsFixed(1)}');
    sb.write(' L 0 ${h.toStringAsFixed(1)} Z');
    return sb.toString();
  }

  /// Normaliza uma cor hexadecimal garantindo formato `#RRGGBB`
  static String _formatHex(String? raw, String fallback) {
    if (raw == null || raw.isEmpty) return fallback;
    var clean = raw.replaceAll('#', '').trim();
    if (clean.length == 8) {
      clean = clean.substring(2); // Remove canal alpha se houver
    }
    if (clean.length != 6) return fallback;
    return '#$clean';
  }

  /// Interpola duas cores matematicamente para criar o tom secundário de destaque
  static String _calculateAccentHex(String primaryHex, String bottomHex, {double factor = 0.60}) {
    try {
      final pClean = primaryHex.replaceAll('#', '');
      final bClean = bottomHex.replaceAll('#', '');

      final pR = int.parse(pClean.substring(0, 2), radix: 16);
      final pG = int.parse(pClean.substring(2, 4), radix: 16);
      final pB = int.parse(pClean.substring(4, 6), radix: 16);

      final bR = int.parse(bClean.substring(0, 2), radix: 16);
      final bG = int.parse(bClean.substring(2, 4), radix: 16);
      final bB = int.parse(bClean.substring(4, 6), radix: 16);

      final aR = (bR + (pR - bR) * factor).round().clamp(0, 255);
      final aG = (bG + (pG - bG) * factor).round().clamp(0, 255);
      final aB = (bB + (pB - bB) * factor).round().clamp(0, 255);

      return '#${aR.toRadixString(16).padLeft(2, '0')}${aG.toRadixString(16).padLeft(2, '0')}${aB.toRadixString(16).padLeft(2, '0')}';
    } catch (_) {
      return primaryHex;
    }
  }
}
