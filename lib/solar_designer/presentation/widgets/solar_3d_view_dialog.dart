import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/models/solar_designer_models.dart';
import '../../domain/services/solar_shading_engine.dart';

/// Diálogo Modal de Visualização Tridimensional da Edificação
class Solar3DViewDialog extends StatefulWidget {
  final List<RoofSection> sections;
  final double currentHour;
  final double latitude;

  const Solar3DViewDialog({
    super.key,
    required this.sections,
    this.currentHour = 12.0,
    this.latitude = -23.55,
  });

  static Future<void> show(
    BuildContext context, {
    required List<RoofSection> sections,
    double currentHour = 12.0,
    double latitude = -23.55,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Solar3DViewDialog(
        sections: sections,
        currentHour: currentHour,
        latitude: latitude,
      ),
    );
  }

  @override
  State<Solar3DViewDialog> createState() => _Solar3DViewDialogState();
}

class _Solar3DViewDialogState extends State<Solar3DViewDialog> {
  // Câmera Orbital 3D
  double _yawAngle = 0.85; // rotação horizontal em radianos
  double _pitchAngle = 0.55; // elevação vertical em radianos
  double _zoomScale = 1.0;
  Offset _panOffset = Offset.zero;

  late double _hour;

  @override
  void initState() {
    super.initState();
    _hour = widget.currentHour;
  }

  void _resetCamera() {
    setState(() {
      _yawAngle = 0.85;
      _pitchAngle = 0.55;
      _zoomScale = 1.0;
      _panOffset = Offset.zero;
    });
  }

  @override
  Widget build(BuildContext context) {
    final sun = SolarShadingEngine.calculateSunPosition(
      hourOfDay: _hour,
      latitude: widget.latitude,
    );

    final simulation = SolarShadingEngine.simulateFullDay(
      sections: widget.sections,
      currentHour: _hour,
      latitude: widget.latitude,
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Container(
        width: 1100,
        height: 760,
        decoration: BoxDecoration(
          color: const Color(0xFF0B1120),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.35), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.70),
              blurRadius: 40,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── ÁREA DE INTERAÇÃO E RENDERIZAÇÃO 3D ──────────────────────
              GestureDetector(
                onScaleUpdate: (details) {
                  setState(() {
                    if (details.pointerCount == 1) {
                      // Rotação orbital
                      _yawAngle += details.focalPointDelta.dx * 0.008;
                      _pitchAngle = (_pitchAngle - details.focalPointDelta.dy * 0.008)
                          .clamp(0.10, math.pi / 2 - 0.05);
                    } else if (details.pointerCount >= 2) {
                      // Zoom e Pan
                      _zoomScale = (_zoomScale * details.scale).clamp(0.4, 4.0);
                      _panOffset += details.focalPointDelta;
                    }
                  });
                },
                child: CustomPaint(
                  painter: _Building3DPainter(
                    sections: widget.sections,
                    yaw: _yawAngle,
                    pitch: _pitchAngle,
                    zoom: _zoomScale,
                    pan: _panOffset,
                    sun: sun,
                  ),
                ),
              ),

              // ── BARRA SUPERIOR EXECUTIVA ──────────────────────────────────
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF0F172A).withValues(alpha: 0.95),
                        const Color(0xFF0F172A).withValues(alpha: 0.60),
                        Colors.transparent,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF818CF8)),
                        ),
                        child: const Icon(Icons.view_in_ar_rounded, color: Color(0xFF818CF8), size: 22),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Modelo 3D da Edificação & Trajetória Solar',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Extrusão tridimensional dos volumes com placas e sombras projetadas',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),

                      // Botão Reset Câmera
                      IconButton(
                        onPressed: _resetCamera,
                        tooltip: 'Centralizar Câmera',
                        icon: const Icon(Icons.restart_alt_rounded, color: Color(0xFF94A3B8)),
                      ),
                      const SizedBox(width: 8),

                      // Botão Fechar
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),

              // ── PAINEL INFERIOR COM CONTROLE SOLAR 3D ─────────────────────
              Positioned(
                bottom: 20,
                left: 24,
                right: 24,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF334155)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Ícone Sol
                      Icon(
                        Icons.wb_sunny_rounded,
                        color: sun.isSunUp ? const Color(0xFFF59E0B) : const Color(0xFF64748B),
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Posição Solar:',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFCBD5E1),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        '${_hour.floor().toString().padLeft(2, '0')}:${((_hour % 1.0) * 60).round().toString().padLeft(2, '0')}',
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Slider Horário 3D
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 5,
                            activeTrackColor: const Color(0xFFF59E0B),
                            inactiveTrackColor: const Color(0xFF334155),
                            thumbColor: Colors.white,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                          ),
                          child: Slider(
                            value: _hour.clamp(6.0, 18.0),
                            min: 6.0,
                            max: 18.0,
                            divisions: 48,
                            onChanged: (val) => setState(() => _hour = val),
                          ),
                        ),
                      ),

                      const SizedBox(width: 16),
                      // Aproveitamento do Sistema
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Row(
                          children: [
                            Text(
                              'Aproveitamento: ',
                              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                            ),
                            Text(
                              '${simulation.overallEfficiencyPercentage.toStringAsFixed(1)}%',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Dica flutuante
              Positioned(
                top: 80,
                left: 24,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B).withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '💡 Arraste para orbitar • Role para dar zoom',
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// CustomPainter Tridimensional da Edificação
class _Building3DPainter extends CustomPainter {
  final List<RoofSection> sections;
  final double yaw;
  final double pitch;
  final double zoom;
  final Offset pan;
  final SolarSunPosition sun;

  _Building3DPainter({
    required this.sections,
    required this.yaw,
    required this.pitch,
    required this.zoom,
    required this.pan,
    required this.sun,
  });

  // Projeção Tridimensional Perspectiva Axonométrica
  // X: Leste (+), Y: Sul (+), Z: Altura (+)
  Offset _project3D(double x, double y, double z, Size size, Offset centerOrigin) {
    // 1. Centraliza em relação ao centro dos telhados
    final cx = x - centerOrigin.dx;
    final cy = y - centerOrigin.dy;

    // 2. Rotação em torno do eixo Z (Yaw)
    final cosYaw = math.cos(yaw);
    final sinYaw = math.sin(yaw);
    final rotX = cx * cosYaw - cy * sinYaw;
    final rotY = cx * sinYaw + cy * cosYaw;

    // 3. Rotação em torno do eixo X (Pitch / Inclinação)
    final cosPitch = math.cos(pitch);
    final sinPitch = math.sin(pitch);
    final projY = rotY * sinPitch - z * cosPitch;

    // 4. Escala e projeção para a tela
    final scale = 24.0 * zoom;
    final screenX = (size.width / 2.0) + pan.dx + (rotX * scale);
    final screenY = (size.height / 2.0) + pan.dy + (projY * scale);

    return Offset(screenX, screenY);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Fundo do Céu / Chão
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF0F172A), Color(0xFF020617)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Calcula o centróide global de todos os telhados
    double sumX = 0, sumY = 0;
    int pointCount = 0;
    for (final s in sections) {
      for (final v in s.vertices) {
        sumX += v.x;
        sumY += v.y;
        pointCount++;
      }
    }
    final centerOrigin = pointCount > 0
        ? Offset(sumX / pointCount, sumY / pointCount)
        : Offset.zero;

    // 2. Desenha a Grade do Chão (Grid 3D Z=0)
    final gridPaint = Paint()
      ..color = const Color(0xFF1E293B).withValues(alpha: 0.5)
      ..strokeWidth = 1.0;

    for (double g = -25.0; g <= 25.0; g += 5.0) {
      final p1 = _project3D(g, -25.0, 0, size, centerOrigin);
      final p2 = _project3D(g, 25.0, 0, size, centerOrigin);
      canvas.drawLine(p1, p2, gridPaint);

      final p3 = _project3D(-25.0, g, 0, size, centerOrigin);
      final p4 = _project3D(25.0, g, 0, size, centerOrigin);
      canvas.drawLine(p3, p4, gridPaint);
    }

    // 3. Desenha a Sombra Projetada no Chão (Z=0)
    if (sun.isSunUp && sun.elevationDegrees > 2.0) {
      final shadowElevationRad = sun.elevationDegrees * (math.pi / 180.0);
      final sunAzRad = sun.azimuthDegrees * (math.pi / 180.0);

      for (final sec in sections) {
        if (sec.vertices.length < 3) continue;
        final h = sec.peakHeightMeters;
        final sLen = math.min(30.0, h / math.tan(shadowElevationRad));
        final dx = -sLen * math.sin(sunAzRad);
        final dy = sLen * math.cos(sunAzRad);

        final shadowPath = Path();
        final firstProj = _project3D(sec.vertices.first.x + dx, sec.vertices.first.y + dy, 0, size, centerOrigin);
        shadowPath.moveTo(firstProj.dx, firstProj.dy);
        for (int i = 1; i < sec.vertices.length; i++) {
          final p = _project3D(sec.vertices[i].x + dx, sec.vertices[i].y + dy, 0, size, centerOrigin);
          shadowPath.lineTo(p.dx, p.dy);
        }
        shadowPath.close();

        final shadowPaint = Paint()
          ..color = Colors.black.withValues(alpha: 0.35)
          ..style = PaintingStyle.fill;
        canvas.drawPath(shadowPath, shadowPaint);
      }
    }

    // 4. Renderiza as Edificações e Paredes 3D (Ordenadas por profundidade estimada)
    for (final sec in sections) {
      if (sec.vertices.length < 3) continue;

      final baseH = sec.baseHeightMeters;
      final peakH = sec.peakHeightMeters;

      // Paredes Verticais (Extrusão do chão até a altura do telhado)
      for (int i = 0; i < sec.vertices.length; i++) {
        final p1 = sec.vertices[i];
        final p2 = sec.vertices[(i + 1) % sec.vertices.length];

        final b1 = _project3D(p1.x, p1.y, 0, size, centerOrigin);
        final b2 = _project3D(p2.x, p2.y, 0, size, centerOrigin);
        final t2 = _project3D(p2.x, p2.y, baseH, size, centerOrigin);
        final t1 = _project3D(p1.x, p1.y, baseH, size, centerOrigin);

        final wallPath = Path()
          ..moveTo(b1.dx, b1.dy)
          ..lineTo(b2.dx, b2.dy)
          ..lineTo(t2.dx, t2.dy)
          ..lineTo(t1.dx, t1.dy)
          ..close();

        // Shading da parede conforme a orientação do sol
        final wallPaint = Paint()
          ..color = const Color(0xFF334155).withValues(alpha: 0.90)
          ..style = PaintingStyle.fill;
        canvas.drawPath(wallPath, wallPaint);

        final wallBorder = Paint()
          ..color = const Color(0xFF475569)
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke;
        canvas.drawPath(wallPath, wallBorder);
      }

      // Face do Telhado (Teto)
      final roofPath = Path();
      final roofPts = sec.vertices.asMap().entries.map((entry) {
        final idx = entry.key;
        final v = entry.value;
        // Se for telhado cerâmico de cumeeira, pontos centrais/segunda metade sobem até o cume (peakH)
        final z = (sec.roofType == RoofStructureType.gabledCeramic && idx % 2 == 1)
            ? peakH
            : baseH;
        return _project3D(v.x, v.y, z, size, centerOrigin);
      }).toList();
      roofPath.moveTo(roofPts.first.dx, roofPts.first.dy);
      for (int i = 1; i < roofPts.length; i++) {
        roofPath.lineTo(roofPts[i].dx, roofPts[i].dy);
      }
      roofPath.close();

      final roofFill = Paint()
        ..color = (sec.roofType == RoofStructureType.gabledCeramic)
            ? const Color(0xFFB45309).withValues(alpha: 0.85) // Terracota cerâmico
            : const Color(0xFF1E293B).withValues(alpha: 0.95) // Platibanda / laje
        ..style = PaintingStyle.fill;
      canvas.drawPath(roofPath, roofFill);

      final roofBorder = Paint()
        ..color = sec.themeColor
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;
      canvas.drawPath(roofPath, roofBorder);

      // 5. Renderiza as Placas Fotovoltaicas no Teto em 3D
      for (final mod in sec.modules) {
        if (mod.isExcluded) continue;

        final corners = mod.getCorners();
        final mod3dPts = corners.map((c) => _project3D(c.x, c.y, baseH + 0.08, size, centerOrigin)).toList();

        final modPath = Path();
        modPath.moveTo(mod3dPts.first.dx, mod3dPts.first.dy);
        for (int i = 1; i < mod3dPts.length; i++) {
          modPath.lineTo(mod3dPts[i].dx, mod3dPts[i].dy);
        }
        modPath.close();

        // Cor da placa (Azul escuro fotovoltaico com reflexo)
        final modPaint = Paint()
          ..color = const Color(0xFF1E3A8A)
          ..style = PaintingStyle.fill;
        canvas.drawPath(modPath, modPaint);

        final modFrame = Paint()
          ..color = const Color(0xFFE2E8F0)
          ..strokeWidth = 0.9
          ..style = PaintingStyle.stroke;
        canvas.drawPath(modPath, modFrame);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _Building3DPainter oldDelegate) => true;
}
