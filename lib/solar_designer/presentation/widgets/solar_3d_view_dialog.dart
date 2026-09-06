import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/services/drone_roof_vision_service.dart';
import '../../domain/models/solar_designer_models.dart';
import '../../domain/services/solar_shading_engine.dart';

/// Diálogo Modal de Visualização Tridimensional da Edificação
class Solar3DViewDialog extends StatefulWidget {
  final List<RoofSection> sections;
  final double currentHour;
  final double latitude;
  final Uint8List? droneImageBytes;
  final DroneRoofAnalysisResult? droneAnalysisResult;

  const Solar3DViewDialog({
    super.key,
    required this.sections,
    this.currentHour = 12.0,
    this.latitude = -23.55,
    this.droneImageBytes,
    this.droneAnalysisResult,
  });

  static Future<void> show(
    BuildContext context, {
    required List<RoofSection> sections,
    double currentHour = 12.0,
    double latitude = -23.55,
    Uint8List? droneImageBytes,
    DroneRoofAnalysisResult? droneAnalysisResult,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Solar3DViewDialog(
        sections: sections,
        currentHour: currentHour,
        latitude: latitude,
        droneImageBytes: droneImageBytes,
        droneAnalysisResult: droneAnalysisResult,
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
  bool _showLandscape = true; // Exibe gramado, piscina e paisagismo realista

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
                    showLandscape: _showLandscape,
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

                      // Botão Alternar Paisagem Realista (Grama, Piscina, Calçada)
                      ElevatedButton.icon(
                        onPressed: () => setState(() => _showLandscape = !_showLandscape),
                        icon: Icon(
                          _showLandscape ? Icons.park_rounded : Icons.grid_4x4_rounded,
                          size: 16,
                          color: _showLandscape ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                        ),
                        label: Text(
                          _showLandscape ? 'Paisagem Realista' : 'Grade Técnica',
                          style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E293B),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: _showLandscape ? const Color(0xFF10B981) : const Color(0xFF334155),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

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

/// CustomPainter Tridimensional da Edificação com Paisagismo e Iluminação Realista
class _Building3DPainter extends CustomPainter {
  final List<RoofSection> sections;
  final double yaw;
  final double pitch;
  final double zoom;
  final Offset pan;
  final SolarSunPosition sun;
  final bool showLandscape;

  _Building3DPainter({
    required this.sections,
    required this.yaw,
    required this.pitch,
    required this.zoom,
    required this.pan,
    required this.sun,
    this.showLandscape = true,
  });

  // Projeção Tridimensional Perspectiva Axonométrica
  // X: Leste (+), Y: Sul (+), Z: Altura (+)
  Offset _project3D(double x, double y, double z, Size size, Offset centerOrigin) {
    final cx = x - centerOrigin.dx;
    final cy = y - centerOrigin.dy;

    final cosYaw = math.cos(yaw);
    final sinYaw = math.sin(yaw);
    final rotX = cx * cosYaw - cy * sinYaw;
    final rotY = cx * sinYaw + cy * cosYaw;

    final cosPitch = math.cos(pitch);
    final sinPitch = math.sin(pitch);
    final projY = rotY * sinPitch - z * cosPitch;

    final scale = 24.0 * zoom;
    final screenX = (size.width / 2.0) + pan.dx + (rotX * scale);
    final screenY = (size.height / 2.0) + pan.dy + (projY * scale);

    return Offset(screenX, screenY);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // ── 1. CÉU ATMOSFÉRICO REALISTA ──────────────────────────────────────────
    // Cor do céu muda dinamicamente conforme a hora do sol (dourado às 6h/18h, azul celeste às 12h)
    Color skyTopColor;
    Color skyBottomColor;

    if (!sun.isSunUp || sun.elevationDegrees <= 2.0) {
      skyTopColor = const Color(0xFF020617);
      skyBottomColor = const Color(0xFF0F172A);
    } else if (sun.elevationDegrees < 20.0) {
      // Alvorecer ou Poente dourado
      skyTopColor = const Color(0xFF0C4A6E);
      skyBottomColor = const Color(0xFFEA580C);
    } else {
      // Céu pleno aberto
      skyTopColor = const Color(0xFF0284C7);
      skyBottomColor = const Color(0xFFBAE6FD);
    }

    final skyPaint = Paint()
      ..shader = LinearGradient(
        colors: [skyTopColor, skyBottomColor],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), skyPaint);

    // Centróide global dos telhados
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

    // ── 2. PAISAGISMO DO TERRENO (Gramado e Calçada Realista Z=0) ────────────
    if (showLandscape) {
      // Gramado Verde Natural
      final grassPath = Path();
      final gp1 = _project3D(-32.0, -32.0, 0, size, centerOrigin);
      final gp2 = _project3D(32.0, -32.0, 0, size, centerOrigin);
      final gp3 = _project3D(32.0, 32.0, 0, size, centerOrigin);
      final gp4 = _project3D(-32.0, 32.0, 0, size, centerOrigin);

      grassPath.moveTo(gp1.dx, gp1.dy);
      grassPath.lineTo(gp2.dx, gp2.dy);
      grassPath.lineTo(gp3.dx, gp3.dy);
      grassPath.lineTo(gp4.dx, gp4.dy);
      grassPath.close();

      final grassPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            const Color(0xFF15803D), // Verde esmeralda grama
            const Color(0xFF166534),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..style = PaintingStyle.fill;
      canvas.drawPath(grassPath, grassPaint);

      // Calçada / Piso de Concreto / Deck no entorno imediato da casa
      final patioPath = Path();
      final pp1 = _project3D(-16.0, -14.0, 0.01, size, centerOrigin);
      final pp2 = _project3D(18.0, -14.0, 0.01, size, centerOrigin);
      final pp3 = _project3D(18.0, 16.0, 0.01, size, centerOrigin);
      final pp4 = _project3D(-16.0, 16.0, 0.01, size, centerOrigin);

      patioPath.moveTo(pp1.dx, pp1.dy);
      patioPath.lineTo(pp2.dx, pp2.dy);
      patioPath.lineTo(pp3.dx, pp3.dy);
      patioPath.lineTo(pp4.dx, pp4.dy);
      patioPath.close();

      final patioPaint = Paint()
        ..color = const Color(0xFFE2E8F0).withValues(alpha: 0.85) // Piso claro moderno
        ..style = PaintingStyle.fill;
      canvas.drawPath(patioPath, patioPaint);

      // Piscina Azul com Água Translúcida e Reflexos no Lado Direito/Fundo
      final poolPath = Path();
      final poolP1 = _project3D(10.0, -11.0, 0.02, size, centerOrigin);
      final poolP2 = _project3D(16.0, -11.0, 0.02, size, centerOrigin);
      final poolP3 = _project3D(16.0, -3.0, 0.02, size, centerOrigin);
      final poolP4 = _project3D(10.0, -3.0, 0.02, size, centerOrigin);

      poolPath.moveTo(poolP1.dx, poolP1.dy);
      poolPath.lineTo(poolP2.dx, poolP2.dy);
      poolPath.lineTo(poolP3.dx, poolP3.dy);
      poolPath.lineTo(poolP4.dx, poolP4.dy);
      poolPath.close();

      final poolPaint = Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF06B6D4), Color(0xFF0284C7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..style = PaintingStyle.fill;
      canvas.drawPath(poolPath, poolPaint);

      final poolBorder = Paint()
        ..color = Colors.white
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;
      canvas.drawPath(poolPath, poolBorder);
    } else {
      // Grade clássica de arquitetura
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
    }

    // ── 3. SOMBRA PROJETADA REALISTA NO CHÃO ─────────────────────────────────
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
        final firstProj = _project3D(sec.vertices.first.x + dx, sec.vertices.first.y + dy, 0.03, size, centerOrigin);
        shadowPath.moveTo(firstProj.dx, firstProj.dy);
        for (int i = 1; i < sec.vertices.length; i++) {
          final p = _project3D(sec.vertices[i].x + dx, sec.vertices[i].y + dy, 0.03, size, centerOrigin);
          shadowPath.lineTo(p.dx, p.dy);
        }
        shadowPath.close();

        final shadowPaint = Paint()
          ..color = Colors.black.withValues(alpha: 0.45)
          ..style = PaintingStyle.fill;
        canvas.drawPath(shadowPath, shadowPaint);
      }
    }

    // ── 4. EDIFICAÇÃO (Paredes Claras com Iluminação Solar Shading) ──────────
    for (final sec in sections) {
      if (sec.vertices.length < 3) continue;

      final baseH = sec.baseHeightMeters;
      final peakH = sec.peakHeightMeters;

      // Paredes Verticais da Edificação
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

        // Shading dinâmico da parede: paredes voltadas para o sol ficam iluminadas (off-white limpo),
        // paredes opostas ficam sombreadas
        final edgeAngle = math.atan2(p2.y - p1.y, p2.x - p1.x);
        final normalAngle = edgeAngle + (math.pi / 2);
        final sunAngleRad = (sun.azimuthDegrees - 90.0) * (math.pi / 180.0);
        final dot = math.cos(normalAngle - sunAngleRad);

        // Cor da parede com acabamento arquitetônico premium
        final wallBrightness = (0.70 + (dot * 0.25)).clamp(0.45, 0.98);
        final wallColor = Color.fromRGBO(
          (248 * wallBrightness).toInt(),
          (250 * wallBrightness).toInt(),
          (252 * wallBrightness).toInt(),
          1.0,
        );

        final wallPaint = Paint()
          ..color = wallColor
          ..style = PaintingStyle.fill;
        canvas.drawPath(wallPath, wallPaint);

        final wallBorder = Paint()
          ..color = const Color(0xFFCBD5E1)
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke;
        canvas.drawPath(wallPath, wallBorder);
      }

      // Moldura da Platibanda Branca Elevada (como na foto)
      final parapetH = baseH + 0.40;
      final parapetPath = Path();
      final parapetPts = sec.vertices.map((v) => _project3D(v.x, v.y, parapetH, size, centerOrigin)).toList();
      parapetPath.moveTo(parapetPts.first.dx, parapetPts.first.dy);
      for (int i = 1; i < parapetPts.length; i++) {
        parapetPath.lineTo(parapetPts[i].dx, parapetPts[i].dy);
      }
      parapetPath.close();

      final parapetBorder = Paint()
        ..color = Colors.white
        ..strokeWidth = 3.5
        ..style = PaintingStyle.stroke;
      canvas.drawPath(parapetPath, parapetBorder);

      // Face do Telhado (Embutido dentro da platibanda)
      final roofPath = Path();
      final roofPts = sec.vertices.asMap().entries.map((entry) {
        final idx = entry.key;
        final v = entry.value;
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
            ? const Color(0xFFB45309).withValues(alpha: 0.90) // Telha Cerâmica
            : const Color(0xFFD1D5DB).withValues(alpha: 0.95) // Telha Fibrocimento ondulada clara
        ..style = PaintingStyle.fill;
      canvas.drawPath(roofPath, roofFill);

      final roofBorder = Paint()
        ..color = sec.themeColor
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke;
      canvas.drawPath(roofPath, roofBorder);

      // ── 5. MÓDULOS FOTOVOLTAICOS 3D COM VIDRO E REFLEXO SOLAR ───────────────
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

        // Vidro fotovoltaico azul escuro com gradiente de brilho especular
        final modPaint = Paint()
          ..shader = const LinearGradient(
            colors: [
              Color(0xFF1E3A8A), // Azul safira fotovoltaico
              Color(0xFF172554),
              Color(0xFF2563EB), // Brilho de reflexo
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
          ..style = PaintingStyle.fill;
        canvas.drawPath(modPath, modPaint);

        // Moldura prateada de alumínio anodizado
        final modFrame = Paint()
          ..color = const Color(0xFFE2E8F0)
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke;
        canvas.drawPath(modPath, modFrame);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _Building3DPainter oldDelegate) => true;
}
