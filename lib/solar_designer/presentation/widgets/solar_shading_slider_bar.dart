import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/models/solar_designer_models.dart';
import '../../domain/services/solar_shading_engine.dart';

/// Barra de Simulação Solar e Slider Diurno Interativo (06:00 às 18:00)
class SolarShadingSliderBar extends StatefulWidget {
  final double currentHour;
  final ValueChanged<double> onHourChanged;
  final List<RoofSection> sections;
  final double latitude;
  final VoidCallback onOpen3DView;

  const SolarShadingSliderBar({
    super.key,
    required this.currentHour,
    required this.onHourChanged,
    required this.sections,
    this.latitude = -23.55,
    required this.onOpen3DView,
  });

  @override
  State<SolarShadingSliderBar> createState() => _SolarShadingSliderBarState();
}

class _SolarShadingSliderBarState extends State<SolarShadingSliderBar>
    with SingleTickerProviderStateMixin {
  bool _isPlaying = false;
  late AnimationController _playController;

  @override
  void initState() {
    super.initState();
    _playController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..addListener(() {
        if (_isPlaying) {
          final newHour = 6.0 + (_playController.value * 12.0); // 06:00 a 18:00
          widget.onHourChanged(newHour);
        }
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() => _isPlaying = false);
          _playController.reset();
        }
      });
  }

  @override
  void dispose() {
    _playController.dispose();
    super.dispose();
  }

  void _togglePlay() {
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        final currentFraction = ((widget.currentHour - 6.0) / 12.0).clamp(0.0, 1.0);
        _playController.forward(from: currentFraction >= 0.98 ? 0.0 : currentFraction);
      } else {
        _playController.stop();
      }
    });
  }

  String _formatHour(double h) {
    final hour = h.floor();
    final minute = ((h - hour) * 60).round();
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final sun = SolarShadingEngine.calculateSunPosition(
      hourOfDay: widget.currentHour,
      latitude: widget.latitude,
    );

    final simulation = SolarShadingEngine.simulateFullDay(
      sections: widget.sections,
      currentHour: widget.currentHour,
      latitude: widget.latitude,
    );

    final totalActive = simulation.totalModulesCount;
    final shadedCount = simulation.shadedAtCurrentHourCount;
    final sunCount = totalActive - shadedCount;
    final currentSunRatio = totalActive > 0 ? (sunCount / totalActive) : 1.0;

    return Container(
      width: 780,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF334155), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
            blurRadius: 32,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── CABEÇALHO COM CONTROLE E KPIs ─────────────────────────────────
          Row(
            children: [
              // Botão Play / Pause animado
              InkWell(
                onTap: _togglePlay,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _isPlaying
                        ? const Color(0xFFEF4444).withValues(alpha: 0.2)
                        : const Color(0xFFF59E0B).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _isPlaying ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: _isPlaying ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isPlaying ? 'PAUSAR' : 'SIMULAR DIA',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Indicador da Hora Atual
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF475569)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.access_time_rounded, size: 15, color: Color(0xFF38BDF8)),
                    const SizedBox(width: 6),
                    Text(
                      _formatHour(widget.currentHour),
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Sol: Elevação e Azimute
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.wb_sunny_rounded,
                    size: 16,
                    color: sun.isSunUp ? const Color(0xFFF59E0B) : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Alt: ${sun.elevationDegrees.toStringAsFixed(1)}° • Az: ${sun.azimuthDegrees.toStringAsFixed(0)}°',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF94A3B8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // Badge: Placas 100% ao Sol vs Sombra
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (shadedCount > 0)
                      ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                      : const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (shadedCount > 0) ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      (shadedCount > 0) ? Icons.cloud_outlined : Icons.check_circle_outline_rounded,
                      size: 14,
                      color: (shadedCount > 0) ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      shadedCount > 0
                          ? '$shadedCount placas sombreadas (${(currentSunRatio * 100).toStringAsFixed(0)}% sol)'
                          : '100% das placas ao sol',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: (shadedCount > 0) ? const Color(0xFFFCA5A5) : const Color(0xFF6EE7B7),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // KPI de Aproveitamento Diário Consolidado
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Text(
                      'Dia: ',
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                    ),
                    Text(
                      '${simulation.overallEfficiencyPercentage.toStringAsFixed(1)}%',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: simulation.overallEfficiencyPercentage >= 90
                            ? const Color(0xFF10B981)
                            : (simulation.overallEfficiencyPercentage >= 75
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFFEF4444)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Botão 3D
              ElevatedButton.icon(
                onPressed: widget.onOpen3DView,
                icon: const Icon(Icons.view_in_ar_rounded, size: 16),
                label: Text(
                  'MODELO 3D',
                  style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 2,
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // ── SLIDER DE HORÁRIOS (06:00 às 18:00) ───────────────────────────
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 6,
              activeTrackColor: const Color(0xFFF59E0B),
              inactiveTrackColor: const Color(0xFF334155),
              thumbColor: Colors.white,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
              overlayColor: const Color(0xFFF59E0B).withValues(alpha: 0.25),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
              valueIndicatorColor: const Color(0xFF1E293B),
              valueIndicatorTextStyle: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            child: Slider(
              value: widget.currentHour.clamp(6.0, 18.0),
              min: 6.0,
              max: 18.0,
              divisions: 48, // passos de 15 minutos
              label: _formatHour(widget.currentHour),
              onChanged: (newVal) {
                if (_isPlaying) {
                  _playController.stop();
                  setState(() => _isPlaying = false);
                }
                widget.onHourChanged(newVal);
              },
            ),
          ),

          // ── RÓTULOS DE HORÁRIOS INFERIORES ───────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildTimeLabel('06:00', 'Nascente (Leste)'),
                _buildTimeLabel('09:00', 'Manhã'),
                _buildTimeLabel('12:00', 'Meio-dia (Zênite)'),
                _buildTimeLabel('15:00', 'Tarde'),
                _buildTimeLabel('18:00', 'Poente (Oeste)'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeLabel(String hour, String description) {
    return Column(
      children: [
        Text(
          hour,
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: const Color(0xFFCBD5E1),
          ),
        ),
        Text(
          description,
          style: GoogleFonts.inter(
            fontSize: 9,
            color: const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }
}
