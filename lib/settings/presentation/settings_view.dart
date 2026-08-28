import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/theme/app_colors.dart';
import '../../../products/domain/models/product_model.dart';
import '../data/services/settings_service.dart';

/// View completa de Configurações do CRM e Gestão do Ramo / Segmento de Atuação
class SettingsView extends StatefulWidget {
  final VoidCallback? onSectorChanged;

  const SettingsView({
    super.key,
    this.onSectorChanged,
  });

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  ProductSector? _currentSector = ProductSector.solarPlant;
  bool _isFixedMode = true;
  bool _isLoading = true;
  String _searchFilter = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final sector = await SettingsService.getPreferredSector();
    final fixed = await SettingsService.isFixedSectorMode();
    if (mounted) {
      setState(() {
        _currentSector = sector ?? ProductSector.solarPlant;
        _isFixedMode = fixed;
        _isLoading = false;
      });
    }
  }

  Future<void> _selectSector(ProductSector? sector) async {
    setState(() => _currentSector = sector);
    await SettingsService.savePreferredSector(sector, isFixed: _isFixedMode);
    widget.onSectorChanged?.call();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(
              sector != null
                  ? 'Ramo de atuação alterado para "${sector.title}" com sucesso!'
                  : 'Modo Geral / Múltiplos Segmentos ativado!',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _toggleFixedMode(bool val) async {
    setState(() => _isFixedMode = val);
    await SettingsService.savePreferredSector(_currentSector, isFixed: val);
    widget.onSectorChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    final activeSector = _currentSector ?? ProductSector.solarPlant;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Cabeçalho da Página ──────────────────────────────────────
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.tune_rounded, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Configurações do Sistema & Ramo de Atuação',
                          style: GoogleFonts.outfit(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Personalize o comportamento do CRM conforme o nicho da sua empresa',
                          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              const Divider(color: AppColors.divider),
              const SizedBox(height: 24),

              // ── Card de Ramo de Atuação Ativo ────────────────────────────
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: activeSector.themeColor.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: activeSector.themeColor.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: activeSector.themeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: activeSector.themeColor.withValues(alpha: 0.3)),
                      ),
                      child: Icon(activeSector.icon, color: activeSector.themeColor, size: 32),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                activeSector.title,
                                style: GoogleFonts.outfit(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'RAMO ATIVO NO CRM',
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF166534),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            activeSector.description,
                            style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Toggle Modo Focado
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Modo Focado no Nicho',
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
                              ),
                              Text(
                                _isFixedMode ? 'Oculta dropdown de outros nichos' : 'Mostra todos os nichos',
                                style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B)),
                              ),
                            ],
                          ),
                          const SizedBox(width: 10),
                          Switch.adaptive(
                            value: _isFixedMode,
                            activeTrackColor: AppColors.primary,
                            onChanged: _toggleFixedMode,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // ── Seleção de Outro Ramo de Atuação ─────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Selecione a Área de Atuação da sua Empresa',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Clique no card desejado para fixar o CRM naquele nicho ou escolha o modo geral',
                        style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  SizedBox(
                    width: 280,
                    child: TextField(
                      onChanged: (v) => setState(() => _searchFilter = v.trim().toLowerCase()),
                      decoration: InputDecoration(
                        hintText: 'Buscar nicho (ex: solar, moda, pet...)',
                        hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 18),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // Grade de Cards dos 20 Nichos + Usina Solar
              _buildSectorGrid(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectorGrid() {
    final allSectors = ProductSector.values;
    final filtered = allSectors.where((s) {
      if (_searchFilter.isEmpty) return true;
      return s.title.toLowerCase().contains(_searchFilter) || s.description.toLowerCase().contains(_searchFilter);
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth > 800 ? 3 : 2;
        final cardWidth = (constraints.maxWidth - ((crossCount - 1) * 16)) / crossCount;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: filtered.map((sector) {
            final isSelected = _currentSector == sector;

            return SizedBox(
              width: cardWidth,
              height: 140,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _selectSector(sector),
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected ? sector.themeColor.withValues(alpha: 0.06) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? sector.themeColor : AppColors.border,
                        width: isSelected ? 2.0 : 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isSelected
                              ? sector.themeColor.withValues(alpha: 0.15)
                              : Colors.black.withValues(alpha: 0.02),
                          blurRadius: isSelected ? 12 : 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: sector.themeColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(sector.icon, color: sector.themeColor, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                sector.title,
                                style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? sector.themeColor : const Color(0xFF0F172A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isSelected)
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: sector.themeColor,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check, size: 12, color: Colors.white),
                              ),
                          ],
                        ),
                        Text(
                          sector.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B), height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

/// Diálogo Modal de Onboarding Inicial no Primeiro Acesso
class SectorOnboardingDialog extends StatefulWidget {
  final ValueChanged<ProductSector> onSectorSelected;

  const SectorOnboardingDialog({
    super.key,
    required this.onSectorSelected,
  });

  @override
  State<SectorOnboardingDialog> createState() => _SectorOnboardingDialogState();
}

class _SectorOnboardingDialogState extends State<SectorOnboardingDialog> {
  ProductSector? _selected = ProductSector.solarPlant;
  String _searchFilter = '';

  @override
  Widget build(BuildContext context) {
    final allSectors = ProductSector.values;
    final filtered = allSectors.where((s) {
      if (_searchFilter.isEmpty) return true;
      return s.title.toLowerCase().contains(_searchFilter) || s.description.toLowerCase().contains(_searchFilter);
    }).toList();

    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = (screenSize.width * 0.90).clamp(380.0, 960.0);
    final dialogHeight = (screenSize.height * 0.88).clamp(480.0, 720.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          color: Color(0xFF030712),
          image: DecorationImage(
            image: NetworkImage(
              'https://images.unsplash.com/photo-1518770660439-4636190af475?q=80&w=2070&auto=format&fit=crop',
            ),
            fit: BoxFit.cover,
            opacity: 0.18,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF030712).withValues(alpha: 0.88),
                const Color(0xFF0B1120).withValues(alpha: 0.95),
              ],
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Container(
                width: dialogWidth,
                height: dialogHeight,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: 50,
                      offset: const Offset(0, 20),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
              // Cabeçalho de Boas-vindas
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bem-vindo ao Mavis CRM! 🚀',
                          style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                        ),
                        Text(
                          'Qual é o ramo de atuação principal da sua empresa? Vamos configurar o CRM para você:',
                          style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),
              const Divider(color: AppColors.divider),
              const SizedBox(height: 12),

              // Barra de busca
              TextField(
                onChanged: (v) => setState(() => _searchFilter = v.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Buscar nicho (ex: Usina Solar, Moda, Farmácia...)',
                  hintStyle: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 18),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                ),
              ),

              const SizedBox(height: 14),

              // Grade de Nichos
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final crossCount = constraints.maxWidth > 650 ? 3 : (constraints.maxWidth > 420 ? 2 : 1);
                    final cardWidth = (constraints.maxWidth - ((crossCount - 1) * 12)) / crossCount;

                    return SingleChildScrollView(
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: filtered.map((sector) {
                          final isSel = _selected == sector;

                          return SizedBox(
                            width: cardWidth,
                            height: 120,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => setState(() => _selected = sector),
                                borderRadius: BorderRadius.circular(14),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isSel ? sector.themeColor.withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isSel ? sector.themeColor : AppColors.border,
                                      width: isSel ? 2 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(sector.icon, size: 20, color: sector.themeColor),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              sector.title,
                                              style: GoogleFonts.outfit(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: isSel ? sector.themeColor : const Color(0xFF0F172A),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (isSel) Icon(Icons.check_circle_rounded, color: sector.themeColor, size: 16),
                                        ],
                                      ),
                                      Text(
                                        sector.description,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B), height: 1.25),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 14),
              const Divider(color: AppColors.divider),
              const SizedBox(height: 12),

              // Botão Confirmar (Custom Material + InkWell de acordo com os padrões)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _selected == null
                          ? null
                          : () async {
                              final nav = Navigator.of(context);
                              await SettingsService.savePreferredSector(_selected!, isFixed: true);
                              widget.onSectorSelected(_selected!);
                              if (mounted) nav.pop();
                            },
                      borderRadius: BorderRadius.circular(12),
                      child: Ink(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        decoration: BoxDecoration(
                          color: _selected?.themeColor ?? AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: (_selected?.themeColor ?? AppColors.primary).withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_outline_rounded, size: 18, color: Colors.white),
                            const SizedBox(width: 8),
                            Text(
                              'DEFINIR "${_selected?.title.toUpperCase() ?? ''}" E ENTRAR NO CRM',
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.4, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  ),
),
    );
  }
}
