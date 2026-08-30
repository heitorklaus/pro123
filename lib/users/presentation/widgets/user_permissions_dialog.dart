import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/theme/app_colors.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../../auth/domain/models/user_model.dart';

/// Modal de Configuração de Permissões e Controle de Acesso (RBAC)
class UserPermissionsDialog extends StatefulWidget {
  final UserModel user;
  final AuthRepository authRepository;

  const UserPermissionsDialog({
    super.key,
    required this.user,
    required this.authRepository,
  });

  @override
  State<UserPermissionsDialog> createState() => _UserPermissionsDialogState();
}

class _UserPermissionsDialogState extends State<UserPermissionsDialog> {
  late String _role;
  late bool _viewClients;
  late bool _createClients;
  late bool _viewProducts;
  late bool _createProducts;
  late bool _viewProposals;
  late bool _createProposals;
  late bool _viewAllProposals;
  late bool _viewSuppliers;
  late bool _createSuppliers;
  late bool _manageSettings;
  late bool _manageUsers;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _role = widget.user.role;
    final p = widget.user.permissions;
    _viewClients = p.viewClients;
    _createClients = p.createClients;
    _viewProducts = p.viewProducts;
    _createProducts = p.createProducts;
    _viewProposals = p.viewProposals;
    _createProposals = p.createProposals;
    _viewAllProposals = p.viewAllProposals;
    _viewSuppliers = p.viewSuppliers;
    _createSuppliers = p.createSuppliers;
    _manageSettings = p.manageSettings;
    _manageUsers = p.manageUsers;
  }

  void _applyPreset(UserPermissions preset, String role) {
    setState(() {
      _role = role;
      _viewClients = preset.viewClients;
      _createClients = preset.createClients;
      _viewProducts = preset.viewProducts;
      _createProducts = preset.createProducts;
      _viewProposals = preset.viewProposals;
      _createProposals = preset.createProposals;
      _viewAllProposals = preset.viewAllProposals;
      _viewSuppliers = preset.viewSuppliers;
      _createSuppliers = preset.createSuppliers;
      _manageSettings = preset.manageSettings;
      _manageUsers = preset.manageUsers;
    });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final updatedPermissions = UserPermissions(
        viewClients: _viewClients,
        createClients: _createClients,
        viewProducts: _viewProducts,
        createProducts: _createProducts,
        viewProposals: _viewProposals,
        createProposals: _createProposals,
        viewAllProposals: _viewAllProposals,
        viewSuppliers: _viewSuppliers,
        createSuppliers: _createSuppliers,
        manageSettings: _manageSettings,
        manageUsers: _manageUsers,
      );

      await widget.authRepository.updateUserRole(
        widget.user.uid,
        _role,
        permissions: updatedPermissions,
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Permissões de "${widget.user.name}" atualizadas com sucesso!'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar permissões: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 640;
    final dialogWidth = (screenSize.width * 0.95).clamp(320.0, 720.0);
    final dialogHeight = (screenSize.height * 0.92).clamp(480.0, 760.0);

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 10 : 24,
        vertical: isMobile ? 12 : 24,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Cabeçalho do Diálogo ─────────────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Permissões & Controle de Acesso',
                        style: GoogleFonts.outfit(
                          fontSize: isMobile ? 17 : 19,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Defina o que o operador ou gerente pode visualizar e executar',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Fechar',
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Card de Identificação do Usuário & Função ────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFFEEF2FF),
                    child: Text(
                      widget.user.name.isNotEmpty
                          ? widget.user.name[0].toUpperCase()
                          : 'U',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.user.name,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          widget.user.email,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Dropdown de Papel / Função
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _role.toLowerCase(),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'user',
                            child: Text('👤 Operador'),
                          ),
                          DropdownMenuItem(
                            value: 'manager',
                            child: Text('👔 Gerente'),
                          ),
                          DropdownMenuItem(
                            value: 'admin',
                            child: Text('⚡ Administrador'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            _applyPreset(UserPermissions.defaultForRole(val), val);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Barra de Predefinições Rápidas (Presets) ─────────────────────
            Row(
              children: [
                Text(
                  'PREDEFINIÇÕES:',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF94A3B8),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _presetChip(
                          '⚡ Acesso Total',
                          () => _applyPreset(UserPermissions.defaultForRole('admin'), 'admin'),
                        ),
                        const SizedBox(width: 6),
                        _presetChip(
                          '👔 Padrão Gerente',
                          () => _applyPreset(UserPermissions.defaultForRole('manager'), 'manager'),
                        ),
                        const SizedBox(width: 6),
                        _presetChip(
                          '👤 Padrão Operador',
                          () => _applyPreset(UserPermissions.defaultForRole('user'), 'user'),
                        ),
                        const SizedBox(width: 6),
                        _presetChip(
                          '🔒 Somente Leitura',
                          () => setState(() {
                            _createClients = false;
                            _createProducts = false;
                            _createProposals = false;
                            _createSuppliers = false;
                            _manageSettings = false;
                            _manageUsers = false;
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 8),

            // ── Lista de Permissões Granuladas ───────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 6),
                children: [
                  // 1. Clientes & Contatos
                  _categoryGroup(
                    icon: Icons.people_alt_rounded,
                    title: 'Clientes & Contatos',
                    subtitle: 'Visualização, pesquisa e cadastro de clientes',
                    color: const Color(0xFF6366F1),
                    children: [
                      _permissionSwitch(
                        title: 'Visualizar Clientes',
                        subtitle: 'Acesso ao módulo e lista de clientes no menu principal',
                        value: _viewClients,
                        onChanged: (val) => setState(() => _viewClients = val),
                      ),
                      _permissionSwitch(
                        title: 'Cadastrar & Editar Clientes',
                        subtitle: 'Permite criar novos clientes (formulário e ViaCEP) e editar dados',
                        value: _createClients,
                        onChanged: (val) => setState(() => _createClients = val),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // 2. Produtos & Usinas Solares
                  _categoryGroup(
                    icon: Icons.solar_power_rounded,
                    title: 'Produtos & Usinas Solares',
                    subtitle: 'Catálogo de itens, kits e montador de usinas',
                    color: const Color(0xFFD97706),
                    children: [
                      _permissionSwitch(
                        title: 'Visualizar Catálogo de Produtos & Usinas',
                        subtitle: 'Acesso à tabela e visualização dos produtos/kits no menu',
                        value: _viewProducts,
                        onChanged: (val) => setState(() => _viewProducts = val),
                      ),
                      _permissionSwitch(
                        title: 'Cadastrar Produtos & Montar Usinas Solares',
                        subtitle: 'Habilita os botões "Montar Usina Solar" (com IA OCR), "Novo Produto" e inclusão de itens no catálogo',
                        value: _createProducts,
                        onChanged: (val) => setState(() => _createProducts = val),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // 3. Propostas Comerciais & Orçamentos
                  _categoryGroup(
                    icon: Icons.description_rounded,
                    title: 'Propostas Comerciais & Orçamentos',
                    subtitle: 'Funil Kanban, emissão de PDFs e propostas digitais',
                    color: const Color(0xFF0284C7),
                    children: [
                      _permissionSwitch(
                        title: 'Visualizar Módulo de Propostas',
                        subtitle: 'Acesso à lista e ao funil Kanban de propostas no menu',
                        value: _viewProposals,
                        onChanged: (val) => setState(() => _viewProposals = val),
                      ),
                      _permissionSwitch(
                        title: 'Gerar / Criar Novas Propostas',
                        subtitle: 'Habilita o botão "Nova Proposta", editor e exportação de PDF',
                        value: _createProposals,
                        onChanged: (val) => setState(() => _createProposals = val),
                      ),
                      _permissionSwitch(
                        title: 'Ver Propostas de Todos os Usuários',
                        subtitle: 'Se desmarcado, o operador poderá visualizar apenas as propostas criadas por ele mesmo',
                        value: _viewAllProposals,
                        onChanged: (val) => setState(() => _viewAllProposals = val),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // 4. Fornecedores & Parceiros
                  _categoryGroup(
                    icon: Icons.local_shipping_rounded,
                    title: 'Fornecedores & Parceiros',
                    subtitle: 'Cadastro e consulta de distribuidores comerciais',
                    color: const Color(0xFF059669),
                    children: [
                      _permissionSwitch(
                        title: 'Visualizar Fornecedores',
                        subtitle: 'Acesso à lista de fornecedores no menu principal',
                        value: _viewSuppliers,
                        onChanged: (val) => setState(() => _viewSuppliers = val),
                      ),
                      _permissionSwitch(
                        title: 'Cadastrar / Editar Fornecedores',
                        subtitle: 'Permite registrar novos fornecedores e prazos de pagamento',
                        value: _createSuppliers,
                        onChanged: (val) => setState(() => _createSuppliers = val),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // 5. Configurações & Gestão de Usuários
                  _categoryGroup(
                    icon: Icons.settings_rounded,
                    title: 'Sistema & Administração',
                    subtitle: 'Configurações de nicho, proposta web e usuários',
                    color: const Color(0xFF7C3AED),
                    children: [
                      _permissionSwitch(
                        title: 'Acesso às Configurações do Sistema',
                        subtitle: 'Permite alterar nicho de atuação, paleta de cores e papéis de parede da proposta web',
                        value: _manageSettings,
                        onChanged: (val) => setState(() => _manageSettings = val),
                      ),
                      _permissionSwitch(
                        title: 'Gerenciar Usuários & Permissões',
                        subtitle: 'Permite cadastrar novos operadores e alterar permissões de acesso',
                        value: _manageUsers,
                        onChanged: (val) => setState(() => _manageUsers = val),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 14),

            // ── Rodapé / Botões de Ação ──────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isSaving ? null : () => Navigator.pop(context),
                  child: Text(
                    'CANCELAR',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isSaving ? null : _save,
                    borderRadius: BorderRadius.circular(10),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check_circle_outline_rounded,
                                    color: Colors.white, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'SALVAR PERMISSÕES',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
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

  Widget _presetChip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF334155),
          ),
        ),
      ),
    );
  }

  Widget _categoryGroup({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header do Grupo
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              border: Border(bottom: BorderSide(color: color.withValues(alpha: 0.15))),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Itens de Switch
          ...children,
        ],
      ),
    );
  }

  Widget _permissionSwitch({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: value ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeTrackColor: AppColors.primary,
              activeThumbColor: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}
