import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../data/repositories/product_repository.dart';
import '../../domain/models/automation_study_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// OPÇÕES DE ÍCONES PARA AUTOMAÇÃO RESIDENCIAL & COMERCIAL
// ─────────────────────────────────────────────────────────────────────────────
class AutomationIconOption {
  final String label;
  final IconData icon;

  const AutomationIconOption(this.label, this.icon);

  static const List<AutomationIconOption> allIcons = [
    // Smart Home & Controle Central
    AutomationIconOption('Smart Home', Icons.home_rounded),
    AutomationIconOption('Sensores', Icons.sensors_rounded),
    AutomationIconOption('Hub / Central', Icons.hub_rounded),
    AutomationIconOption('Gateway / Roteador', Icons.router_rounded),
    AutomationIconOption('Touch / Painel', Icons.touch_app_rounded),
    AutomationIconOption('Controle Remoto', Icons.settings_remote_rounded),
    AutomationIconOption('Assistente de Voz', Icons.mic_rounded),
    AutomationIconOption('Tomada Inteligente', Icons.power_rounded),
    AutomationIconOption('Interruptor', Icons.toggle_on_rounded),
    AutomationIconOption('Módulo / Relé', Icons.memory_rounded),
    AutomationIconOption('Disjuntor / Elétrica', Icons.electric_bolt_rounded),

    // Iluminação & Cenas
    AutomationIconOption('Lâmpada / Iluminação', Icons.lightbulb_outline_rounded),
    AutomationIconOption('Lustre / Pendente', Icons.light_rounded),
    AutomationIconOption('Fita LED', Icons.linear_scale_rounded),
    AutomationIconOption('Dimerização', Icons.tune_rounded),
    AutomationIconOption('Refletor / Spot', Icons.highlight_rounded),
    AutomationIconOption('Abajur / Luminária', Icons.wb_incandescent_rounded),

    // Persianas, Cortinas & Motores
    AutomationIconOption('Persianas', Icons.blinds_rounded),
    AutomationIconOption('Cortinas', Icons.curtains_rounded),
    AutomationIconOption('Toldo / Cobertura', Icons.roller_shades_rounded),
    AutomationIconOption('Motor Tubular', Icons.settings_power_rounded),
    AutomationIconOption('Janela Automática', Icons.window_rounded),

    // Áudio, Vídeo & Cinema
    AutomationIconOption('Caixa de Som', Icons.speaker_rounded),
    AutomationIconOption('Som Embutido / Arandela', Icons.speaker_group_rounded),
    AutomationIconOption('TV / Smart TV', Icons.tv_rounded),
    AutomationIconOption('Projetor', Icons.videocam_rounded),
    AutomationIconOption('Tela Retrátil', Icons.smart_display_rounded),
    AutomationIconOption('Home Theater', Icons.theater_comedy_rounded),
    AutomationIconOption('Cinema / Filmes', Icons.movie_rounded),
    AutomationIconOption('Música / Streaming', Icons.music_note_rounded),
    AutomationIconOption('Fone / Headset', Icons.headphones_rounded),
    AutomationIconOption('Receiver / Amplificador', Icons.surround_sound_rounded),

    // Climatização & Conforto
    AutomationIconOption('Ar-Condicionado', Icons.ac_unit_rounded),
    AutomationIconOption('Termostato', Icons.thermostat_rounded),
    AutomationIconOption('Ventilador', Icons.air_rounded),
    AutomationIconOption('Piso Aquecido', Icons.hot_tub_rounded),
    AutomationIconOption('Lareira Ecológica', Icons.local_fire_department_rounded),

    // Segurança & Acesso
    AutomationIconOption('Fechadura Digital', Icons.lock_outline_rounded),
    AutomationIconOption('Biometria / Facial', Icons.fingerprint_rounded),
    AutomationIconOption('Câmera de Segurança', Icons.videocam_outlined),
    AutomationIconOption('Câmera 360 / Dome', Icons.camera_alt_rounded),
    AutomationIconOption('Videoporteiro', Icons.doorbell_rounded),
    AutomationIconOption('Alarme', Icons.add_alert_rounded),
    AutomationIconOption('Sirene', Icons.notifications_active_rounded),
    AutomationIconOption('Portão Automático', Icons.garage_rounded),
    AutomationIconOption('Detector de Fumaça', Icons.smoke_free_rounded),
    AutomationIconOption('Escudo / Proteção', Icons.shield_rounded),

    // Redes & Conectividade
    AutomationIconOption('Wi-Fi / Access Point', Icons.wifi_rounded),
    AutomationIconOption('Cabo de Rede', Icons.cable_rounded),
    AutomationIconOption('Servidor / Rack', Icons.dns_rounded),
    AutomationIconOption('Antena', Icons.cell_tower_rounded),

    // Ambientes Externos & Especiais
    AutomationIconOption('Piscina / SPA', Icons.pool_rounded),
    AutomationIconOption('Irrigação', Icons.water_drop_rounded),
    AutomationIconOption('Jardim', Icons.yard_rounded),
    AutomationIconOption('Energia Solar', Icons.solar_power_rounded),
    AutomationIconOption('Carregador Veicular', Icons.electric_car_rounded),
    AutomationIconOption('Aspiração Central', Icons.cleaning_services_rounded),
    AutomationIconOption('Outros / Genérico', Icons.category_rounded),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// OPÇÕES DE CORES
// ─────────────────────────────────────────────────────────────────────────────
class AutomationColorOption {
  final String label;
  final Color color;

  const AutomationColorOption(this.label, this.color);

  static const List<AutomationColorOption> allColors = [
    AutomationColorOption('Índigo', Color(0xFF6366F1)),
    AutomationColorOption('Âmbar', Color(0xFFF59E0B)),
    AutomationColorOption('Ciano', Color(0xFF06B6D4)),
    AutomationColorOption('Azul', Color(0xFF0284C7)),
    AutomationColorOption('Violeta', Color(0xFF8B5CF6)),
    AutomationColorOption('Esmeralda', Color(0xFF10B981)),
    AutomationColorOption('Rosa Neon', Color(0xFFEC4899)),
    AutomationColorOption('Rubi', Color(0xFFEF4444)),
    AutomationColorOption('Laranja', Color(0xFFF97316)),
    AutomationColorOption('Verde Lima', Color(0xFF84CC16)),
    AutomationColorOption('Púrpura', Color(0xFFA855F7)),
    AutomationColorOption('Slate', Color(0xFF64748B)),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// DIÁLOGO DE GERENCIAMENTO & SELEÇÃO DE CATEGORIAS DE AUTOMAÇÃO
// ─────────────────────────────────────────────────────────────────────────────
class AutomationCategoryManagerDialog extends StatefulWidget {
  final ValueChanged<AutomationCategoryModel>? onCategorySelected;
  final String? companyId;

  const AutomationCategoryManagerDialog({
    super.key,
    this.onCategorySelected,
    this.companyId,
  });

  @override
  State<AutomationCategoryManagerDialog> createState() =>
      _AutomationCategoryManagerDialogState();
}

class _AutomationCategoryManagerDialogState
    extends State<AutomationCategoryManagerDialog> {
  late final ProductRepository _repo;
  final _searchCtrl = TextEditingController();
  String _filter = '';
  String? _companyId;

  @override
  void initState() {
    super.initState();
    _companyId = widget.companyId;
    try {
      _repo = Modular.get<ProductRepository>();
    } catch (_) {
      _repo = ProductRepository();
    }
    if (_companyId == null) {
      _loadCompanyId();
    }
  }

  Future<void> _loadCompanyId() async {
    try {
      AuthRepository auth;
      try {
        auth = Modular.get<AuthRepository>();
      } catch (_) {
        auth = AuthRepository();
      }
      final cid = await auth.getCurrentCompanyId();
      if (mounted) setState(() => _companyId = cid);
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openCategoryFormDialog([AutomationCategoryModel? categoryToEdit]) {
    showDialog(
      context: context,
      builder: (ctx) => AutomationCategoryFormDialog(
        categoryToEdit: categoryToEdit,
        companyId: _companyId,
        onCategorySaved: (savedCat) {
          if (widget.onCategorySelected != null && categoryToEdit == null) {
            widget.onCategorySelected!(savedCat);
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  void _confirmDeleteCategory(AutomationCategoryModel category) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Color(0xFFEF4444), size: 24),
            const SizedBox(width: 10),
            Text(
              'Excluir Categoria',
              style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
        content: Text(
          'Deseja realmente excluir a categoria "${category.title}"?\nOs equipamentos já cadastrados que a utilizam não serão apagados.',
          style:
              GoogleFonts.inter(fontSize: 13.5, color: const Color(0xFFCBD5E1)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'CANCELAR',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600, color: const Color(0xFF94A3B8)),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                Navigator.pop(ctx);
                await _repo.deleteAutomationCategory(category.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Categoria "${category.title}" excluída com sucesso!'),
                      backgroundColor: const Color(0xFFEF4444),
                    ),
                  );
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'EXCLUIR',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                      color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 700;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 32,
        vertical: isMobile ? 16 : 32,
      ),
      child: Container(
        width: 860,
        height: 640,
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header do Diálogo
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.hub_rounded,
                      size: 22, color: Color(0xFF818CF8)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Catálogo de Categorias de Automação',
                        style: GoogleFonts.outfit(
                          fontSize: isMobile ? 16 : 19,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Selecione uma categoria, edite ou cadastre novas opções com ícones e cores personalizados.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Barra de Busca e Botão Nova Categoria
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _filter = v.trim().toLowerCase()),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Pesquisar categoria (ex: Som, Iluminação, Portão)...',
                      hintStyle: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: const Color(0xFF64748B),
                      ),
                      prefixIcon: const Icon(Icons.search_rounded,
                          size: 18, color: Color(0xFF64748B)),
                      suffixIcon: _filter.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 16),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _filter = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _openCategoryFormDialog(),
                    borderRadius: BorderRadius.circular(10),
                    child: Ink(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(
                            'NOVA CATEGORIA',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Conteúdo: Stream das Categorias
            Expanded(
              child: StreamBuilder<List<AutomationCategoryModel>>(
                stream: _repo.getAutomationCategoriesStream(companyId: _companyId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    );
                  }

                  final allCategories = snapshot.data ?? AutomationCategoryModel.defaultCategories;
                  final filtered = _filter.isEmpty
                      ? allCategories
                      : allCategories
                          .where((c) => c.title.toLowerCase().contains(_filter))
                          .toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.category_outlined,
                                size: 48, color: Color(0xFF64748B)),
                            const SizedBox(height: 12),
                            Text(
                              'Nenhuma categoria encontrada com o termo "$_filter"',
                              style: GoogleFonts.inter(
                                  fontSize: 13.5, color: const Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 14),
                            TextButton.icon(
                              onPressed: () => _openCategoryFormDialog(),
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: const Text('Cadastrar categoria agora'),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF6366F1),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isMobile ? 1 : 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: isMobile ? 3.8 : 3.2,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, idx) {
                      final cat = filtered[idx];
                      return _AutomationCategoryCard(
                        category: cat,
                        onTap: () {
                          if (widget.onCategorySelected != null) {
                            widget.onCategorySelected!(cat);
                          }
                          Navigator.pop(context, cat);
                        },
                        onEdit: cat.isCustom ? () => _openCategoryFormDialog(cat) : null,
                        onDelete: cat.isCustom ? () => _confirmDeleteCategory(cat) : null,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD INDIVIDUAL DE CATEGORIA DE AUTOMAÇÃO
// ─────────────────────────────────────────────────────────────────────────────
class _AutomationCategoryCard extends StatelessWidget {
  final AutomationCategoryModel category;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _AutomationCategoryCard({
    required this.category,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: category.isCustom
                  ? category.color.withValues(alpha: 0.4)
                  : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              width: category.isCustom ? 1.4 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: category.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: category.color.withValues(alpha: 0.35),
                  ),
                ),
                child: Icon(category.icon, size: 20, color: category.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            category.title,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (category.isCustom) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: category.color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'CUSTOM',
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: category.color,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      category.isCustom
                          ? 'Personalizada pela sua empresa'
                          : 'Categoria nativa do sistema',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              if (category.isCustom) ...[
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF818CF8)),
                  tooltip: 'Editar',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      size: 16, color: Color(0xFFEF4444)),
                  tooltip: 'Excluir',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: onDelete,
                ),
              ] else ...[
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 12,
                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DIÁLOGO DE FORMULÁRIO: CADASTRO OU EDIÇÃO COM SELETOR DE ÍCONES E CORES
// ─────────────────────────────────────────────────────────────────────────────
class AutomationCategoryFormDialog extends StatefulWidget {
  final AutomationCategoryModel? categoryToEdit;
  final String? companyId;
  final ValueChanged<AutomationCategoryModel>? onCategorySaved;

  const AutomationCategoryFormDialog({
    super.key,
    this.categoryToEdit,
    this.companyId,
    this.onCategorySaved,
  });

  @override
  State<AutomationCategoryFormDialog> createState() =>
      _AutomationCategoryFormDialogState();
}

class _AutomationCategoryFormDialogState
    extends State<AutomationCategoryFormDialog> {
  late final ProductRepository _repo;
  final _titleCtrl = TextEditingController();
  final _iconSearchCtrl = TextEditingController();

  late IconData _selectedIcon;
  late Color _selectedColor;
  String _iconFilter = '';
  bool _isLoading = false;
  String? _errorMessage;

  bool get _isEditing => widget.categoryToEdit != null;

  @override
  void initState() {
    super.initState();
    try {
      _repo = Modular.get<ProductRepository>();
    } catch (_) {
      _repo = ProductRepository();
    }

    if (_isEditing) {
      _titleCtrl.text = widget.categoryToEdit!.title;
      _selectedIcon = widget.categoryToEdit!.icon;
      _selectedColor = widget.categoryToEdit!.color;
    } else {
      _selectedIcon = AutomationIconOption.allIcons.first.icon;
      _selectedColor = AutomationColorOption.allColors.first.color;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _iconSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _errorMessage = 'Informe o nome da categoria.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      AutomationCategoryModel result;
      if (_isEditing) {
        final updated = widget.categoryToEdit!.copyWith(
          title: title,
          icon: _selectedIcon,
          color: _selectedColor,
        );
        await _repo.updateAutomationCategory(updated);
        result = updated;
      } else {
        result = await _repo.createAutomationCategory(
          title: title,
          icon: _selectedIcon,
          color: _selectedColor,
          companyId: widget.companyId,
        );
      }

      if (mounted) {
        widget.onCategorySaved?.call(result);
        Navigator.pop(context, result);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing
                ? 'Categoria "$title" atualizada!'
                : 'Categoria "$title" criada com sucesso!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Erro ao salvar categoria: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 700;

    final filteredIcons = _iconFilter.isEmpty
        ? AutomationIconOption.allIcons
        : AutomationIconOption.allIcons
            .where((i) => i.label.toLowerCase().contains(_iconFilter))
            .toList();

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 32,
        vertical: isMobile ? 16 : 24,
      ),
      child: Container(
        width: 680,
        height: 600,
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _selectedColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _selectedColor.withValues(alpha: 0.3)),
                  ),
                  child: Icon(_selectedIcon, size: 22, color: _selectedColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isEditing
                            ? 'Editar Categoria de Automação'
                            : 'Nova Categoria de Automação',
                        style: GoogleFonts.outfit(
                          fontSize: isMobile ? 16 : 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Defina o nome, escolha a cor temática e o ícone representativo.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        size: 16, color: Color(0xFFEF4444)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: GoogleFonts.inter(
                            fontSize: 12, color: const Color(0xFFEF4444)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Campo Nome da Categoria
            Text(
              'Nome da Categoria *',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _titleCtrl,
              onChanged: (_) => setState(() {}),
              style: GoogleFonts.inter(
                fontSize: 13,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                hintText: 'Ex: Fechaduras Digitais, Telas Retráteis, Home Theater 7.1...',
                hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                filled: true,
                fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Seletor de Cores
            Text(
              'Cor Temática',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: AutomationColorOption.allColors.map((opt) {
                  final isSelected = _selectedColor == opt.color;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: () => setState(() => _selectedColor = opt.color),
                      borderRadius: BorderRadius.circular(20),
                      child: Tooltip(
                        message: opt.label,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: opt.color,
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(color: Colors.white, width: 2.5)
                                : null,
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: opt.color.withValues(alpha: 0.5),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: isSelected
                              ? const Icon(Icons.check_rounded,
                                  size: 16, color: Colors.white)
                              : null,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),

            // Barra de busca de ícones
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Escolha o Ícone (${filteredIcons.length} disponíveis)',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _iconSearchCtrl,
              onChanged: (v) => setState(() => _iconFilter = v.trim().toLowerCase()),
              style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                hintText: 'Filtrar ícones (ex: som, câmera, luz, cortina)...',
                hintStyle: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFF64748B)),
                isDense: true,
                filled: true,
                fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Grade de Ícones
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.1,
                  ),
                  itemCount: filteredIcons.length,
                  itemBuilder: (ctx, idx) {
                    final item = filteredIcons[idx];
                    final isSelected = _selectedIcon == item.icon;
                    return InkWell(
                      onTap: () => setState(() => _selectedIcon = item.icon),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? _selectedColor.withValues(alpha: 0.2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? _selectedColor
                                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            width: isSelected ? 1.8 : 1.0,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              item.icon,
                              size: 20,
                              color: isSelected
                                  ? _selectedColor
                                  : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.label,
                              style: GoogleFonts.inter(
                                fontSize: 8.5,
                                color: isSelected
                                    ? _selectedColor
                                    : const Color(0xFF64748B),
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Rodapé com Botões
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'CANCELAR',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isLoading ? null : _submit,
                    borderRadius: BorderRadius.circular(10),
                    child: Ink(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_selectedColor, _selectedColor.withValues(alpha: 0.85)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: _selectedColor.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check_rounded,
                                    size: 16, color: Colors.white),
                                const SizedBox(width: 6),
                                Text(
                                  _isEditing ? 'SALVAR ALTERAÇÕES' : 'SALVAR CATEGORIA',
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.3,
                                  ),
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
    );
  }
}
