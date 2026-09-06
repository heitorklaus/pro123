import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/models/solar_designer_models.dart';

/// Diálogo Modal de Configuração de Altura e Tipo de Telhado
/// Acionado automaticamente ao fechar o polígono ou via botão de edição de propriedades
class RoofHeightDialog extends StatefulWidget {
  final String sectionName;
  final RoofStructureType initialType;
  final double initialBaseHeight;
  final double initialPeakHeight;
  final double initialTiltDegrees;

  const RoofHeightDialog({
    super.key,
    required this.sectionName,
    this.initialType = RoofStructureType.flatPlatibanda,
    this.initialBaseHeight = 3.50,
    double? initialPeakHeight,
    this.initialTiltDegrees = 12.0,
  }) : initialPeakHeight = initialPeakHeight ?? initialBaseHeight;

  static Future<RoofHeightResult?> show(
    BuildContext context, {
    required String sectionName,
    RoofStructureType initialType = RoofStructureType.flatPlatibanda,
    double initialBaseHeight = 3.50,
    double? initialPeakHeight,
    double initialTiltDegrees = 12.0,
  }) {
    return showDialog<RoofHeightResult>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => RoofHeightDialog(
        sectionName: sectionName,
        initialType: initialType,
        initialBaseHeight: initialBaseHeight,
        initialPeakHeight: initialPeakHeight,
        initialTiltDegrees: initialTiltDegrees,
      ),
    );
  }

  @override
  State<RoofHeightDialog> createState() => _RoofHeightDialogState();
}

class RoofHeightResult {
  final RoofStructureType roofType;
  final double baseHeightMeters;
  final double peakHeightMeters;
  final double tiltDegrees;

  const RoofHeightResult({
    required this.roofType,
    required this.baseHeightMeters,
    required this.peakHeightMeters,
    required this.tiltDegrees,
  });
}

class _RoofHeightDialogState extends State<RoofHeightDialog> {
  late RoofStructureType _selectedType;
  late final TextEditingController _baseHeightCtrl;
  late final TextEditingController _peakHeightCtrl;
  late final TextEditingController _tiltCtrl;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
    _baseHeightCtrl = TextEditingController(
      text: widget.initialBaseHeight.toStringAsFixed(2),
    );
    _peakHeightCtrl = TextEditingController(
      text: widget.initialPeakHeight.toStringAsFixed(2),
    );
    _tiltCtrl = TextEditingController(
      text: widget.initialTiltDegrees.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _baseHeightCtrl.dispose();
    _peakHeightCtrl.dispose();
    _tiltCtrl.dispose();
    super.dispose();
  }

  void _confirm() {
    final baseH = double.tryParse(_baseHeightCtrl.text.replaceAll(',', '.')) ?? 3.50;
    double peakH = double.tryParse(_peakHeightCtrl.text.replaceAll(',', '.')) ?? baseH;
    final tilt = double.tryParse(_tiltCtrl.text.replaceAll(',', '.')) ?? 12.0;

    // Para platibanda/plano, o topo é igual à base da platibanda
    if (_selectedType == RoofStructureType.flatPlatibanda) {
      peakH = baseH;
    } else if (peakH < baseH) {
      peakH = baseH + 1.20; // Fallback coerente se cumeeira for menor que beiral
    }

    Navigator.of(context).pop(
      RoofHeightResult(
        roofType: _selectedType,
        baseHeightMeters: baseH,
        peakHeightMeters: peakH,
        tiltDegrees: tilt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isFlat = _selectedType == RoofStructureType.flatPlatibanda;
    final isCeramic = _selectedType == RoofStructureType.gabledCeramic;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: 520,
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.35), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.60),
              blurRadius: 36,
              offset: const Offset(0, 16),
            ),
            BoxShadow(
              color: const Color(0xFF0284C7).withValues(alpha: 0.15),
              blurRadius: 48,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── CABEÇALHO DO DIÁLOGO ─────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
                gradient: LinearGradient(
                  colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
                    ),
                    child: const Icon(Icons.height_rounded, color: Color(0xFF38BDF8), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Altura & Perfil do Telhado',
                          style: GoogleFonts.outfit(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Polígono delimitado • ${widget.sectionName}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── CORPO DO FORMULÁRIO ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'QUAL É A TIPOLOGIA DESTE TELHADO?',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF94A3B8),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── SELETOR DE TIPO (Platibanda vs Cerâmico) ────────────────
                  Row(
                    children: [
                      Expanded(
                        child: _buildTypeCard(
                          type: RoofStructureType.flatPlatibanda,
                          title: 'Casa Quadrada / Platibanda',
                          subtitle: 'Laje plana com paredes verticais',
                          icon: Icons.crop_square_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTypeCard(
                          type: RoofStructureType.gabledCeramic,
                          title: 'Telhado Cerâmico / Águas',
                          subtitle: 'Com desnível e cumeeira',
                          icon: Icons.roofing_rounded,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  // ── CAMPOS DE ALTURA CONFORME O TIPO SELECIONADO ───────────
                  if (isFlat) ...[
                    // MODO PLATIBANDA / CASA QUADRADA
                    _buildInputField(
                      controller: _baseHeightCtrl,
                      label: 'Altura da Platibanda / Pé-direito (m)',
                      helperText: 'Distância do solo até o topo da laje/parede (ex: 3.50m, 6.00m)',
                      icon: Icons.straighten_rounded,
                      accentColor: const Color(0xFF38BDF8),
                    ),
                  ] else if (isCeramic) ...[
                    // MODO CERÂMICO / ÁGUAS
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildInputField(
                            controller: _baseHeightCtrl,
                            label: 'Altura Base / Beiral (m)',
                            helperText: 'Apoio inferior do telhado',
                            icon: Icons.vertical_align_bottom_rounded,
                            accentColor: const Color(0xFF38BDF8),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _buildInputField(
                            controller: _peakHeightCtrl,
                            label: 'Altura Cumeeira (Topo) (m)',
                            helperText: 'Ponto mais alto da água',
                            icon: Icons.vertical_align_top_rounded,
                            accentColor: const Color(0xFFF59E0B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildInputField(
                      controller: _tiltCtrl,
                      label: 'Inclinação Estimada (°)',
                      helperText: 'Inclinação da telha cerâmica (padrão 15° a 30°)',
                      icon: Icons.change_history_rounded,
                      accentColor: const Color(0xFF10B981),
                    ),
                  ] else ...[
                    // MODO INCLINADO / MEIA ÁGUA
                    Row(
                      children: [
                        Expanded(
                          child: _buildInputField(
                            controller: _baseHeightCtrl,
                            label: 'Altura Menor (m)',
                            helperText: 'Pé-direito inferior',
                            icon: Icons.vertical_align_bottom_rounded,
                            accentColor: const Color(0xFF38BDF8),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _buildInputField(
                            controller: _peakHeightCtrl,
                            label: 'Altura Maior (m)',
                            helperText: 'Pé-direito superior',
                            icon: Icons.vertical_align_top_rounded,
                            accentColor: const Color(0xFFF59E0B),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B).withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.wb_sunny_outlined, color: Color(0xFFF59E0B), size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Estas alturas serão usadas para calcular o sombreamento tridimensional do sol sobre os outros telhados e para construir o modelo 3D da casa.',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFFCBD5E1),
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── BOTÕES DE AÇÃO ───────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFF1E293B))),
                color: Color(0xFF0B1120),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF94A3B8),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    ),
                    child: Text(
                      'Pular Altura',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _confirm,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: Text(
                      'APLICAR & PREENCHER PLACAS',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeCard({
    required RoofStructureType type,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _selectedType == type;

    return InkWell(
      onTap: () => setState(() => _selectedType = type),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF0284C7).withValues(alpha: 0.15)
              : const Color(0xFF1E293B).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF334155),
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF94A3B8),
                ),
                const Spacer(),
                if (isSelected)
                  const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF38BDF8)),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : const Color(0xFFE2E8F0),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: isSelected ? const Color(0xFFBAE6FD) : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String helperText,
    required IconData icon,
    required Color accentColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 15, color: accentColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFCBD5E1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: const Color(0xFF1E293B),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            suffixText: 'm',
            suffixStyle: GoogleFonts.inter(
              color: const Color(0xFF94A3B8),
              fontWeight: FontWeight.bold,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF334155)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF334155)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: accentColor, width: 1.8),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          helperText,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }
}
