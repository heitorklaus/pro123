import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app/theme/app_colors.dart';
import '../../auth/data/repositories/auth_repository.dart';
import '../../auth/domain/models/user_model.dart';
import '../../auth/presentation/register/register_store.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ENTRY POINT: inserido diretamente no miolo do DashboardPage (sem Scaffold)
// ─────────────────────────────────────────────────────────────────────────────
class UsersView extends StatefulWidget {
  const UsersView({super.key});

  @override
  State<UsersView> createState() => _UsersViewState();
}

class _UsersViewState extends State<UsersView> {
  bool _showForm = false;

  @override
  Widget build(BuildContext context) {
    if (_showForm) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: SizedBox(
            width: 540,
            child: _RegisterCard(
              onBack: () => setState(() => _showForm = false),
              onSuccess: () => setState(() => _showForm = false),
            ),
          ),
        ),
      );
    }

    return _TableView(
      onAddNewUser: () => setState(() => _showForm = true),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TABELA: ocupa TODO o espaço disponível do miolo usando LayoutBuilder
// ─────────────────────────────────────────────────────────────────────────────
class _TableView extends StatefulWidget {
  final VoidCallback onAddNewUser;

  const _TableView({required this.onAddNewUser});

  @override
  State<_TableView> createState() => _TableViewState();
}

class _TableViewState extends State<_TableView> {
  late final AuthRepository _repo;
  final _searchCtrl = TextEditingController();
  String _query = '';
  String? _companyId;

  @override
  void initState() {
    super.initState();
    try {
      _repo = Modular.get<AuthRepository>();
    } catch (_) {
      _repo = AuthRepository();
    }
    _loadCompanyId();
  }

  Future<void> _loadCompanyId() async {
    try {
      final cid = await _repo.getCurrentCompanyId();
      if (mounted) setState(() => _companyId = cid);
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return SizedBox.expand(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 14 : 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cabeçalho ─────────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Gestão de Usuários',
                        style: GoogleFonts.outfit(
                          fontSize: isMobile ? 20 : 26,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Controle de operadores e permissões',
                        style: GoogleFonts.inter(
                            fontSize: isMobile ? 12 : 14, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: widget.onAddNewUser,
                    borderRadius: BorderRadius.circular(12),
                    child: Ink(
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 14 : 20, vertical: isMobile ? 8 : 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.add_rounded,
                                size: 18, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(
                              isMobile ? 'NOVO' : 'NOVO USUÁRIO',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                fontSize: isMobile ? 12 : 13,
                                letterSpacing: 0.5,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: isMobile ? 14 : 20),

            // ── Busca ─────────────────────────────────────────────────────────
            SizedBox(
              width: isMobile ? double.infinity : 380,
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) =>
                    setState(() => _query = v.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: isMobile ? 'Buscar usuário...' : 'Buscar por nome ou e-mail...',
                  hintStyle: GoogleFonts.inter(
                      fontSize: 13, color: const Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: Color(0xFF64748B), size: 20),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
              ),
            ),
            SizedBox(height: isMobile ? 12 : 16),

            // ── Tabela / Mobile Cards ─────────────────────────────────────────
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isMobile ? Colors.transparent : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: isMobile ? null : Border.all(color: AppColors.border),
                  boxShadow: isMobile
                      ? null
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    children: [
                      if (!isMobile) ...[
                        _TableHeader(),
                        const Divider(height: 1, color: AppColors.divider),
                      ],
                      Expanded(
                        child: StreamBuilder<List<UserModel>>(
                          stream: _repo.getUsersStream(companyId: _companyId),
                          builder: (ctx, snap) {
                            if (_companyId == null ||
                                snap.connectionState ==
                                    ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(
                                    color: AppColors.primary),
                              );
                            }
                            if (snap.hasError) {
                              return Center(
                                child: Text(
                                  'Erro ao carregar usuários:\n${snap.error}',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                      color: const Color(0xFF64748B)),
                                ),
                              );
                            }

                            final all = snap.data ?? [];
                            final filtered = _query.isEmpty
                                ? all
                                : all
                                    .where((u) =>
                                        u.name.toLowerCase().contains(_query) ||
                                        u.email.toLowerCase().contains(_query))
                                    .toList();

                            if (filtered.isEmpty) {
                              return _EmptyState(
                                isEmpty: all.isEmpty,
                                onAdd: widget.onAddNewUser,
                              );
                            }

                            if (isMobile) {
                              return ListView.builder(
                                itemCount: filtered.length,
                                padding: EdgeInsets.zero,
                                itemBuilder: (_, i) => _UserMobileCard(
                                  user: filtered[i],
                                  onDelete: () => _showDeleteDialog(filtered[i]),
                                ),
                              );
                            }

                            return ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const Divider(
                                  height: 1, color: AppColors.divider),
                              itemBuilder: (_, i) => _UserRow(
                                user: filtered[i],
                                onDelete: () => _showDeleteDialog(filtered[i]),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(UserModel user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Color(0xFFEF4444), size: 26),
            const SizedBox(width: 10),
            Text('Excluir Usuário',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Remover "${user.name}"? Essa ação não pode ser desfeita.',
          style:
              GoogleFonts.inter(fontSize: 14, color: const Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CANCELAR',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _repo.deleteUser(user.uid);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Usuário removido.'),
                    backgroundColor: Color(0xFFEF4444),
                  ));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Erro: $e'),
                    backgroundColor: const Color(0xFFEF4444),
                  ));
                }
              }
            },
            child: const Text('EXCLUIR'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cabeçalho da tabela
// ─────────────────────────────────────────────────────────────────────────────
class _TableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      color: const Color(0xFFF8FAFC),
      child: Row(
        children: [
          _col('USUÁRIO', flex: 3),
          _col('E-MAIL', flex: 3),
          _col('PAPEL', flex: 2),
          _col('STATUS', flex: 2),
          _col('CADASTRO', flex: 2),
          const SizedBox(width: 52),
        ],
      ),
    );
  }

  Widget _col(String label, {required int flex}) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontWeight: FontWeight.bold,
          fontSize: 11,
          color: const Color(0xFF64748B),
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Linha de usuário
// ─────────────────────────────────────────────────────────────────────────────
class _UserRow extends StatelessWidget {
  final UserModel user;
  final VoidCallback onDelete;

  const _UserRow({required this.user, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Row(
        children: [
          // Avatar + Nome
          Expanded(
            flex: 3,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor: const Color(0xFFEEF2FF),
                  child: Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                    style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        fontSize: 13),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    user.name,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0F172A)),
                  ),
                ),
              ],
            ),
          ),
          // Email
          Expanded(
            flex: 3,
            child: Text(
              user.email,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                  fontSize: 13, color: const Color(0xFF334155)),
            ),
          ),
          // Papel
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _RoleBadge(role: user.role),
            ),
          ),
          // Status
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _StatusBadge(status: user.status),
            ),
          ),
          // Data
          Expanded(
            flex: 2,
            child: Text(
              '${user.createdAt.day.toString().padLeft(2, '0')}/'
              '${user.createdAt.month.toString().padLeft(2, '0')}/'
              '${user.createdAt.year}',
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                  fontSize: 12, color: const Color(0xFF64748B)),
            ),
          ),
          // Ação
          SizedBox(
            width: 52,
            child: IconButton(
              tooltip: 'Excluir',
              icon: const Icon(Icons.delete_outline_rounded,
                  color: Color(0xFFEF4444), size: 18),
              onPressed: onDelete,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card Mobile de Usuário
// ─────────────────────────────────────────────────────────────────────────────
class _UserMobileCard extends StatelessWidget {
  final UserModel user;
  final VoidCallback onDelete;

  const _UserMobileCard({
    required this.user,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final initials = user.name.isNotEmpty
        ? user.name.trim().split(' ').take(2).map((e) => e.isNotEmpty ? e[0].toUpperCase() : '').join()
        : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  child: Text(
                    initials,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        user.email,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: const Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                  onPressed: onDelete,
                  tooltip: 'Excluir',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 8),
            Row(
              children: [
                _RoleBadge(role: user.role),
                const SizedBox(width: 8),
                _StatusBadge(status: user.status),
                const Spacer(),
                Text(
                  '${user.createdAt.day.toString().padLeft(2, '0')}/${user.createdAt.month.toString().padLeft(2, '0')}/${user.createdAt.year}',
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Estado vazio
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final bool isEmpty;
  final VoidCallback onAdd;

  const _EmptyState({required this.isEmpty, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9), shape: BoxShape.circle),
            child: const Icon(Icons.people_outline_rounded,
                color: Color(0xFF64748B), size: 36),
          ),
          const SizedBox(height: 16),
          Text(
            isEmpty ? 'Nenhum usuário cadastrado' : 'Nenhum resultado',
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: const Color(0xFF1E293B)),
          ),
          const SizedBox(height: 6),
          Text(
            isEmpty
                ? 'Clique em "+ NOVO USUÁRIO" para começar.'
                : 'Tente outro termo de busca.',
            style:
                GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 13),
          ),
          if (isEmpty) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Cadastrar Primeiro Usuário'),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FORMULÁRIO DE CADASTRO
// ─────────────────────────────────────────────────────────────────────────────
class _RegisterCard extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onSuccess;

  const _RegisterCard({required this.onBack, required this.onSuccess});

  @override
  State<_RegisterCard> createState() => _RegisterCardState();
}

class _RegisterCardState extends State<_RegisterCard> {
  late final RegisterStore _store;
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  String _selectedRole = 'user';
  String? _companyId;

  @override
  void initState() {
    super.initState();
    try {
      _store = Modular.get<RegisterStore>();
    } catch (_) {
      _store = RegisterStore();
    }
    _loadCompanyId();
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
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _clear() {
    _nameCtrl.clear();
    _emailCtrl.clear();
    _passCtrl.clear();
    _confirmCtrl.clear();
    _store.setName('');
    _store.setEmail('');
    _store.setPassword('');
    _store.setConfirmPassword('');
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Botão Voltar
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF64748B),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              ),
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: Text('Voltar para a Lista',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ),
          const SizedBox(height: 12),

          // Cabeçalho
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.person_add_alt_1_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cadastrar Novo Usuário',
                        style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary)),
                    Text('Adicione operadores ou administradores',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: AppColors.divider),
          const SizedBox(height: 16),

          // Erro
          Observer(builder: (_) {
            final err = _store.errorMessage;
            if (err == null) return const SizedBox.shrink();
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: Color(0xFFEF4444), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(err,
                        style: GoogleFonts.inter(
                            color: const Color(0xFF991B1B),
                            fontSize: 13,
                            fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
            );
          }),

          _label('Nome Completo'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _nameCtrl,
            onChanged: _store.setName,
            decoration: const InputDecoration(
              hintText: 'Digite o nome do usuário',
              prefixIcon: Icon(Icons.person_outline, color: Color(0xFF64748B)),
            ),
          ),
          const SizedBox(height: 14),

          _label('E-mail'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _emailCtrl,
            onChanged: _store.setEmail,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              hintText: 'exemplo@mavis.com',
              prefixIcon: Icon(Icons.email_outlined, color: Color(0xFF64748B)),
            ),
          ),
          const SizedBox(height: 14),

          _label('Senha Provisória'),
          const SizedBox(height: 6),
          Observer(
            builder: (_) => TextFormField(
              controller: _passCtrl,
              onChanged: _store.setPassword,
              obscureText: _store.obscurePassword,
              decoration: InputDecoration(
                hintText: 'Mínimo de 6 caracteres',
                prefixIcon:
                    const Icon(Icons.lock_outline, color: Color(0xFF64748B)),
                suffixIcon: IconButton(
                  icon: Icon(
                    _store.obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: const Color(0xFF64748B),
                  ),
                  onPressed: _store.toggleObscurePassword,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          _label('Confirmar Senha'),
          const SizedBox(height: 6),
          Observer(
            builder: (_) => TextFormField(
              controller: _confirmCtrl,
              onChanged: _store.setConfirmPassword,
              obscureText: _store.obscureConfirmPassword,
              decoration: InputDecoration(
                hintText: 'Repita a senha',
                prefixIcon: const Icon(Icons.lock_reset_outlined,
                    color: Color(0xFF64748B)),
                suffixIcon: IconButton(
                  icon: Icon(
                    _store.obscureConfirmPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: const Color(0xFF64748B),
                  ),
                  onPressed: _store.toggleObscureConfirmPassword,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Nível de Acesso (Cargo)
          _label('Nível de Acesso *'),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _selectedRole,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.badge_outlined, color: Color(0xFF64748B)),
            ),
            items: const [
              DropdownMenuItem(value: 'user', child: Text('Operador (Acesso Padrão)')),
              DropdownMenuItem(value: 'manager', child: Text('Gerente (Relatórios e Leads)')),
              DropdownMenuItem(value: 'admin', child: Text('Administrador (Acesso Total)')),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _selectedRole = val);
            },
          ),
          const SizedBox(height: 24),

          // Botão Cadastrar
          Observer(
            builder: (_) => ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 2,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _store.isLoading
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final ok = await _store.register(
                        companyId: _companyId,
                        role: _selectedRole,
                      );
                      if (!mounted) return;
                      if (ok) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Usuário cadastrado com sucesso!'),
                            backgroundColor: Color(0xFF10B981),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        _clear();
                        widget.onSuccess();
                      }
                    },
              child: _store.isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5),
                    )
                  : Text(
                      'CADASTRAR USUÁRIO',
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF334155),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// BADGES
// ─────────────────────────────────────────────────────────────────────────────
class _RoleBadge extends StatelessWidget {
  final String role;

  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, String label) = switch (role.toLowerCase()) {
      'admin' => (const Color(0xFFFEF3C7), const Color(0xFFD97706), 'Admin'),
      'manager' => (
          const Color(0xFFE0E7FF),
          const Color(0xFF4F46E5),
          'Gerente'
        ),
      _ => (const Color(0xFFF1F5F9), const Color(0xFF475569), 'Operador'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final bool active = status == 'active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: active ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            active ? 'Ativo' : 'Inativo',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: active ? const Color(0xFF047857) : const Color(0xFFB91C1C),
            ),
          ),
        ],
      ),
    );
  }
}
