import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/models/solar_designer_models.dart';
import '../../domain/services/solar_shading_engine.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Presets de datas sazonais para o Hemisfério Sul (Brasil)
// ─────────────────────────────────────────────────────────────────────────────
class _SeasonPreset {
  final String label;
  final String emoji;
  final int dayOfYear;
  final Color color;

  const _SeasonPreset({
    required this.label,
    required this.emoji,
    required this.dayOfYear,
    required this.color,
  });
}

const _kSeasonPresets = [
  _SeasonPreset(
    label: 'Verão',
    emoji: '☀️',
    dayOfYear: 355, // ~21 dez — Solstício de Verão (HS)
    color: Color(0xFFF59E0B),
  ),
  _SeasonPreset(
    label: 'Outono',
    emoji: '🍂',
    dayOfYear: 80, // ~21 mar — Equinócio de Outono (HS)
    color: Color(0xFFEA580C),
  ),
  _SeasonPreset(
    label: 'Inverno',
    emoji: '❄️',
    dayOfYear: 172, // ~21 jun — Solstício de Inverno (HS)
    color: Color(0xFF38BDF8),
  ),
  _SeasonPreset(
    label: 'Primavera',
    emoji: '🌸',
    dayOfYear: 264, // ~21 set — Equinócio de Primavera (HS)
    color: Color(0xFF10B981),
  ),
];

/// Converte dia do ano para data aproximada (mês/dia) — usado na exibição
String _dayOfYearToLabel(int doy) {
  const months = [
    (31, 'jan'),
    (28, 'fev'),
    (31, 'mar'),
    (30, 'abr'),
    (31, 'mai'),
    (30, 'jun'),
    (31, 'jul'),
    (31, 'ago'),
    (30, 'set'),
    (31, 'out'),
    (30, 'nov'),
    (31, 'dez'),
  ];
  int remaining = doy.clamp(1, 365);
  for (final (days, name) in months) {
    if (remaining <= days) {
      return '$remaining $name';
    }
    remaining -= days;
  }
  return '$doy';
}

/// Barra de Simulação Solar e Slider Diurno Interativo (06:00 às 18:00)
/// com seletor de estação/data para variação realista da sombra ao longo do ano.
class SolarShadingSliderBar extends StatefulWidget {
  final double currentHour;
  final ValueChanged<double> onHourChanged;
  final List<RoofSection> sections;
  final double latitude;
  final double northRotationRadians;
  final VoidCallback onOpen3DView;

  /// Dia do ano atual (1–365). Muda as sombras por estação.
  final int dayOfYear;
  final ValueChanged<int> onDayOfYearChanged;

  /// Oculta o mostrador/trajetória do sol desenhado no mapa (a sombra real
  /// projetada nas placas continua calculada normalmente)
  final bool hideSunPath;
  final ValueChanged<bool> onHideSunPathChanged;

  const SolarShadingSliderBar({
    super.key,
    required this.currentHour,
    required this.onHourChanged,
    required this.sections,
    this.latitude = -23.55,
    this.northRotationRadians = 0.0,
    required this.onOpen3DView,
    this.dayOfYear = 172, // Padrão: Inverno (pior caso = mais conservador)
    required this.onDayOfYearChanged,
    this.hideSunPath = false,
    required this.onHideSunPathChanged,
  });

  @override
  State<SolarShadingSliderBar> createState() => _SolarShadingSliderBarState();
}

class _SolarShadingSliderBarState extends State<SolarShadingSliderBar>
    with SingleTickerProviderStateMixin {
  bool _isPlaying = false;
  bool _showDatePicker = false;
  bool _isCollapsed = false;
  late AnimationController _playController;

  @override
  void initState() {
    super.initState();
    _playController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )
      ..addListener(() {
        if (_isPlaying) {
          final newHour = 6.0 + (_playController.value * 12.0);
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
        final currentFraction =
            ((widget.currentHour - 6.0) / 12.0).clamp(0.0, 1.0);
        _playController.forward(
            from: currentFraction >= 0.98 ? 0.0 : currentFraction);
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

  /// Retorna o preset ativo com base no dayOfYear atual (ou null se personalizado)
  _SeasonPreset? get _activePreset {
    for (final p in _kSeasonPresets) {
      if ((p.dayOfYear - widget.dayOfYear).abs() <= 5) return p;
    }
    return null;
  }

  /// Cor da estação atual para destaque visual
  Color get _seasonColor {
    return _activePreset?.color ?? const Color(0xFF94A3B8);
  }

  @override
  Widget build(BuildContext context) {
    final sun = SolarShadingEngine.calculateSunPosition(
      hourOfDay: widget.currentHour,
      latitude: widget.latitude,
      dayOfYear: widget.dayOfYear,
    );

    final simulation = SolarShadingEngine.simulateFullDay(
      sections: widget.sections,
      currentHour: widget.currentHour,
      latitude: widget.latitude,
      northRotationRadians: widget.northRotationRadians,
      dayOfYear: widget.dayOfYear,
    );

    final totalActive = simulation.totalModulesCount;
    final shadedCount = simulation.shadedAtCurrentHourCount;
    final sunCount = totalActive - shadedCount;
    final currentSunRatio = totalActive > 0 ? (sunCount / totalActive) : 1.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── PAINEL SELETOR DE ESTAÇÃO / DATA (expansível) ─────────────────
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: (!_isCollapsed && _showDatePicker)
              ? _buildSeasonPicker()
              : const SizedBox.shrink(),
        ),

        // ── BARRA PRINCIPAL (minimizável) ───────────────────────────────
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          alignment: Alignment.bottomCenter,
          child: _isCollapsed
              ? _buildCollapsedPill(sun)
              : _buildExpandedBar(
                  sun: sun,
                  simulation: simulation,
                  shadedCount: shadedCount,
                  currentSunRatio: currentSunRatio,
                ),
        ),
      ],
    );
  }

  // ── PÍLULA MINIMIZADA (clique para reabrir) ──────────────────────────────
  Widget _buildCollapsedPill(SolarSunPosition sun) {
    return GestureDetector(
      onTap: () => setState(() => _isCollapsed = false),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: const Color(0xFF334155), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wb_sunny_rounded,
              size: 15,
              color: sun.isSunUp
                  ? const Color(0xFFF59E0B)
                  : const Color(0xFF64748B),
            ),
            const SizedBox(width: 8),
            Text(
              _formatHour(widget.currentHour),
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: _seasonColor.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.keyboard_arrow_up_rounded,
                  size: 16, color: _seasonColor),
            ),
          ],
        ),
      ),
    );
  }

  // ── BARRA PRINCIPAL EXPANDIDA ────────────────────────────────────────────
  Widget _buildExpandedBar({
    required SolarSunPosition sun,
    required DailyShadingSimulationResult simulation,
    required int shadedCount,
    required double currentSunRatio,
  }) {
    return Container(
      width: 860,
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
            color: _seasonColor.withValues(alpha: 0.10),
            blurRadius: 32,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── CABEÇALHO COM CONTROLE E KPIs ───────────────────────────
          Row(
            children: [
              // Botão Play / Pause
              InkWell(
                onTap: _togglePlay,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _isPlaying
                        ? const Color(0xFFEF4444).withValues(alpha: 0.2)
                        : const Color(0xFFF59E0B).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _isPlaying
                          ? const Color(0xFFEF4444)
                          : const Color(0xFFF59E0B),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: _isPlaying
                            ? const Color(0xFFEF4444)
                            : const Color(0xFFF59E0B),
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isPlaying ? 'PAUSAR' : 'SIMULAR',
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
              const SizedBox(width: 10),

              // Indicador da Hora Atual
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF475569)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.access_time_rounded,
                        size: 15, color: Color(0xFF38BDF8)),
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
              const SizedBox(width: 10),

              // Sol: Elevação e Azimute
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.wb_sunny_rounded,
                    size: 16,
                    color: sun.isSunUp
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFF64748B),
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
              const SizedBox(width: 10),

              // ── BOTÃO SELETOR DE DATA/ESTAÇÃO ─────────────────────
              GestureDetector(
                onTap: () => setState(() => _showDatePicker = !_showDatePicker),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _showDatePicker
                        ? _seasonColor.withValues(alpha: 0.25)
                        : _seasonColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _showDatePicker
                          ? _seasonColor
                          : _seasonColor.withValues(alpha: 0.5),
                      width: _showDatePicker ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _activePreset?.emoji ?? '📅',
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(width: 5),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _activePreset?.label ??
                                _dayOfYearToLabel(widget.dayOfYear),
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _seasonColor,
                            ),
                          ),
                          Text(
                            'Dia ${widget.dayOfYear}',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              color: _seasonColor.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _showDatePicker
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 14,
                        color: _seasonColor,
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // Badge: Placas ao Sol vs Sombra
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (shadedCount > 0)
                      ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                      : const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (shadedCount > 0)
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF10B981),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      (shadedCount > 0)
                          ? Icons.cloud_outlined
                          : Icons.check_circle_outline_rounded,
                      size: 14,
                      color: (shadedCount > 0)
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF10B981),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      shadedCount > 0
                          ? '$shadedCount placas sombreadas (${(currentSunRatio * 100).toStringAsFixed(0)}% sol)'
                          : '100% ao sol',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: (shadedCount > 0)
                            ? const Color(0xFFFCA5A5)
                            : const Color(0xFF6EE7B7),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // KPI de Aproveitamento Diário
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Text(
                      'Dia: ',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: const Color(0xFF94A3B8)),
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
              const SizedBox(width: 8),

              // Botão Ocultar Sol (esconde o mostrador/trajetória no mapa)
              Tooltip(
                message: widget.hideSunPath
                    ? 'Mostrar trajetória do sol no mapa'
                    : 'Ocultar trajetória do sol no mapa',
                child: InkWell(
                  onTap: () => widget.onHideSunPathChanged(!widget.hideSunPath),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: widget.hideSunPath
                          ? const Color(0xFF334155).withValues(alpha: 0.5)
                          : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: widget.hideSunPath
                            ? const Color(0xFF475569)
                            : const Color(0xFFF59E0B).withValues(alpha: 0.5),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.hideSunPath
                              ? Icons.wb_sunny_outlined
                              : Icons.wb_sunny_rounded,
                          size: 15,
                          color: widget.hideSunPath
                              ? const Color(0xFF64748B)
                              : const Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          widget.hideSunPath ? 'Sol' : 'Sol',
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: widget.hideSunPath
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFFFBBF24),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Botão Minimizar
              InkWell(
                onTap: () => setState(() => _isCollapsed = true),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: const Icon(Icons.keyboard_arrow_down_rounded,
                      size: 16, color: Color(0xFF94A3B8)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // ── SLIDER DE HORÁRIOS (06:00 às 18:00) ─────────────────────
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 6,
              activeTrackColor: _seasonColor,
              inactiveTrackColor: const Color(0xFF334155),
              thumbColor: Colors.white,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
              overlayColor: _seasonColor.withValues(alpha: 0.25),
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
              divisions: 48,
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

          // ── RÓTULOS INFERIORES ────────────────────────────────────────
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

  // ── PAINEL EXPANSÍVEL DE SELEÇÃO DE ESTAÇÃO / DIA DO ANO ────────────────
  Widget _buildSeasonPicker() {
    return Container(
      width: 860,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título
          Row(
            children: [
              const Icon(Icons.calendar_month_rounded,
                  size: 16, color: Color(0xFF94A3B8)),
              const SizedBox(width: 8),
              Text(
                'ESTAÇÃO DO ANO  —  Hemisfério Sul (Brasil)',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF64748B),
                  letterSpacing: 0.6,
                ),
              ),
              const Spacer(),
              Text(
                'Sol mais baixo no inverno → sombra mais longa',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: const Color(0xFF475569),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Presets sazonais
          Row(
            children: _kSeasonPresets.map((preset) {
              final isActive = (preset.dayOfYear - widget.dayOfYear).abs() <= 5;

              // Dados do sol ao meio-dia para mostrar elevação desta estação
              final sunNoon = SolarShadingEngine.calculateSunPosition(
                hourOfDay: 12.0,
                latitude: widget.latitude,
                dayOfYear: preset.dayOfYear,
              );

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    widget.onDayOfYearChanged(preset.dayOfYear);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                      color: isActive
                          ? preset.color.withValues(alpha: 0.18)
                          : const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            isActive ? preset.color : const Color(0xFF334155),
                        width: isActive ? 1.8 : 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(preset.emoji,
                                style: const TextStyle(fontSize: 18)),
                            const SizedBox(width: 6),
                            Text(
                              preset.label,
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isActive ? preset.color : Colors.white,
                              ),
                            ),
                            const Spacer(),
                            if (isActive)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: preset.color.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'ATIVO',
                                  style: GoogleFonts.outfit(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: preset.color,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _presetDateRange(preset.dayOfYear),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Elevação solar ao meio-dia para esta estação
                        Row(
                          children: [
                            Icon(Icons.wb_sunny_outlined,
                                size: 11, color: preset.color),
                            const SizedBox(width: 4),
                            Text(
                              'Meio-dia: ${sunNoon.elevationDegrees.toStringAsFixed(0)}° altitude',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: isActive
                                    ? preset.color
                                    : const Color(0xFF94A3B8),
                                fontWeight: isActive
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        // Indicador visual da sombra (quanto maior o bar, mais longa)
                        Row(
                          children: [
                            Icon(Icons.straighten_rounded,
                                size: 11, color: const Color(0xFF475569)),
                            const SizedBox(width: 4),
                            Text(
                              'Sombra: ${_shadowDescription(sunNoon.elevationDegrees)}',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 12),

          // Slider fino de dia do ano para seleção precisa
          Row(
            children: [
              Text(
                '1 jan',
                style: GoogleFonts.inter(
                    fontSize: 10, color: const Color(0xFF475569)),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    activeTrackColor: _seasonColor,
                    inactiveTrackColor: const Color(0xFF1E293B),
                    thumbColor: _seasonColor,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayColor: _seasonColor.withValues(alpha: 0.2),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 12),
                  ),
                  child: Slider(
                    value: widget.dayOfYear.toDouble().clamp(1, 365),
                    min: 1,
                    max: 365,
                    divisions: 364,
                    label: _dayOfYearToLabel(widget.dayOfYear),
                    onChanged: (v) => widget.onDayOfYearChanged(v.round()),
                  ),
                ),
              ),
              Text(
                '31 dez',
                style: GoogleFonts.inter(
                    fontSize: 10, color: const Color(0xFF475569)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _presetDateRange(int doy) {
    const ranges = {
      355: 'Solstício de Verão • ~21 dez',
      80: 'Equinócio de Outono • ~21 mar',
      172: 'Solstício de Inverno • ~21 jun',
      264: 'Equinócio de Primavera • ~21 set',
    };
    return ranges[doy] ?? 'Dia $doy do ano';
  }

  String _shadowDescription(double elevDeg) {
    if (elevDeg >= 75) return 'Muito curta ☀️';
    if (elevDeg >= 60) return 'Curta';
    if (elevDeg >= 45) return 'Moderada';
    if (elevDeg >= 30) return 'Longa ⚠️';
    return 'Muito longa ❄️';
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
