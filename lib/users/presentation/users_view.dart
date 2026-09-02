import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app/theme/app_colors.dart';
import '../../auth/data/repositories/auth_repository.dart';
import '../../auth/domain/models/user_model.dart';
import '../../auth/presentation/register/register_store.dart';
import '../../settings/data/services/system_settings_service.dart';
import 'widgets/ai_usage_badge.dart';
import 'widgets/user_permissions_dialog.dart';
import 'widgets/user_dossier_dialog.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ENTRY POINT: inserido diretamente no miolo do DashboardPage (sem Scaffold)
// ─────────────────────────────────────────────────────────────────────────────
class UsersView extends StatefulWidget {
  final UserModel? currentUser;

  const UsersView({super.key, this.currentUser});

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
      currentUser: widget.currentUser,
      onAddNewUser: () => setState(() => _showForm = true),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TABELA: ocupa TODO o espaço disponível do miolo usando LayoutBuilder
// ─────────────────────────────────────────────────────────────────────────────
class _TableView extends StatefulWidget {
  final UserModel? currentUser;
  final VoidCallback onAddNewUser;

  const _TableView({this.currentUser, required this.onAddNewUser});

  @override
  State<_TableView> createState() => _TableViewState();
}

class _TableViewState extends State<_TableView> {
  late final AuthRepository _repo;
  StreamSubscription<UserModel?>? _userSub;
  final _searchCtrl = TextEditingController();
  String _query = '';
  String? _companyId;
  UserModel? _currentUser;
  final Set<String> _expandedAdminUids = {};
  List<UserModel> _cachedUsersList = [];

  @override
  void initState() {
    super.initState();
    try {
      _repo = Modular.get<AuthRepository>();
    } catch (_) {
      _repo = AuthRepository();
    }
    _currentUser = widget.currentUser;
    _userSub = _repo.getCurrentUserStream().listen((user) {
      if (mounted) {
        setState(() {
          _currentUser = user;
          _companyId = user?.effectiveCompanyId ?? _companyId;
        });
      }
    });
    _loadCompanyId();
  }

  Future<void> _loadCompanyId() async {
    try {
      final user = await _repo.getCurrentUser();
      final cid = user?.effectiveCompanyId ?? await _repo.getCurrentCompanyId();
      if (mounted) {
        setState(() {
          _currentUser = user;
          _companyId = cid;
        });
      }
    } catch (_) {}
  }

  Future<void> _handleAddNewUser(List<UserModel> currentUsers) async {
    final user = widget.currentUser ?? _currentUser;
    if (user == null || user.isSuperAdmin) {
      widget.onAddNewUser();
      return;
    }

    final cid = user.effectiveCompanyId;
    final maxSellers = await SystemSettingsService.getCompanyMaxSellers(cid);
    final sellersCount = currentUsers.where((u) => !u.isAdmin && !u.isSuperAdmin).length;

    if (sellersCount >= maxSellers) {
      if (mounted) {
        SystemSettingsService.showSellerLimitExceededDialog(
          context,
          limit: maxSellers,
          companyName: user.name,
        );
      }
      return;
    }

    widget.onAddNewUser();
  }

  @override
  void dispose() {
    _userSub?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Controle de operadores e permissões',
                        style: GoogleFonts.inter(
                            fontSize: isMobile ? 12 : 14,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                if (widget.currentUser?.canManageUsers ?? _currentUser?.canManageUsers ?? false) ...[
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _handleAddNewUser(_cachedUsersList),
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
                  color: isMobile ? Colors.transparent : (isDark ? AppColors.darkSurface : Colors.white),
                  borderRadius: BorderRadius.circular(16),
                  border: isMobile ? null : Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
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
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        child: Row(
                          children: [
                            const Icon(Icons.account_tree_rounded, size: 16, color: Color(0xFF6366F1)),
                            const SizedBox(width: 8),
                            Text(
                              'HIERARQUIA DE CONTAS & OPERADORES',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: const Color(0xFF475569),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'Clique no [+] para ver os operadores',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: AppColors.divider),
                      Expanded(
                        child: StreamBuilder<List<UserModel>>(
                          stream: _repo.getUsersStream(
                            companyId: _companyId,
                            isSuperAdmin: widget.currentUser?.isSuperAdmin ?? _currentUser?.isSuperAdmin ?? false,
                          ),
                          builder: (ctx, snap) {
                            final isSuper = widget.currentUser?.isSuperAdmin ?? _currentUser?.isSuperAdmin ?? false;
                            if ((_companyId == null && !isSuper) ||
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
                            _cachedUsersList = all;
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
                                canAdd: widget.currentUser?.canManageUsers ?? _currentUser?.canManageUsers ?? false,
                                onAdd: widget.onAddNewUser,
                              );
                            }

                            // ── Organização Hierárquica: Admins no Topo com Sanfona (+) para Subordinados ──
                            final admins = filtered.where((u) => u.isAdmin || u.isSuperAdmin).toList();
                            final Map<String, List<UserModel>> subordinatesByAdmin = {};
                            for (final a in admins) {
                              subordinatesByAdmin[a.uid] = filtered.where((u) =>
                                  u.uid != a.uid &&
                                  (u.companyId == a.uid || u.companyId == a.companyId || (u.companyId == null && !u.isAdmin && !u.isSuperAdmin))).toList();
                            }
                            final assignedUids = {
                              ...admins.map((a) => a.uid),
                              ...subordinatesByAdmin.values.expand((list) => list.map((u) => u.uid)),
                            };
                            final orphans = filtered.where((u) => !assignedUids.contains(u.uid)).toList();

                            // Se não houver nenhum admin identificado (todos forem operators), exibe lista direta
                            if (admins.isEmpty) {
                              return ListView.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.divider),
                                itemBuilder: (_, i) => _UserRow(
                                  user: filtered[i],
                                  onViewDossier: () => _openUserDossierDialog(filtered[i]),
                                  onEdit: () => _openEditUserDialog(filtered[i]),
                                  onEditPermissions: () => _openPermissionsDialog(filtered[i]),
                                  onDelete: () => _showDeleteDialog(filtered[i]),
                                ),
                              );
                            }

                            return ListView(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              children: [
                                ...admins.map((admin) {
                                  final subs = subordinatesByAdmin[admin.uid] ?? [];
                                  final isExpanded = _expandedAdminUids.contains(admin.uid) || _query.isNotEmpty;
                                  return _AdminTreeGroup(
                                    admin: admin,
                                    subordinates: subs,
                                    isExpanded: isExpanded,
                                    isMobile: isMobile,
                                    onToggleExpand: () {
                                      setState(() {
                                        if (_expandedAdminUids.contains(admin.uid)) {
                                          _expandedAdminUids.remove(admin.uid);
                                        } else {
                                          _expandedAdminUids.add(admin.uid);
                                        }
                                      });
                                    },
                                    onViewDossier: _openUserDossierDialog,
                                    onEditUser: _openEditUserDialog,
                                    onEditPermissions: _openPermissionsDialog,
                                    onDeleteUser: _showDeleteDialog,
                                  );
                                }),
                                if (orphans.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  _OrphansGroup(
                                    orphans: orphans,
                                    isMobile: isMobile,
                                    isExpanded: _expandedAdminUids.contains('__orphans__') || _query.isNotEmpty,
                                    onToggleExpand: () {
                                      setState(() {
                                        if (_expandedAdminUids.contains('__orphans__')) {
                                          _expandedAdminUids.remove('__orphans__');
                                        } else {
                                          _expandedAdminUids.add('__orphans__');
                                        }
                                      });
                                    },
                                    onViewDossier: _openUserDossierDialog,
                                    onEditUser: _openEditUserDialog,
                                    onEditPermissions: _openPermissionsDialog,
                                    onDeleteUser: _showDeleteDialog,
                                  ),
                                ],
                              ],
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

  void _openUserDossierDialog(UserModel user) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => UserDossierDialog(
        user: user,
        currentUser: widget.currentUser ?? _currentUser,
      ),
    );
  }

  void _openEditUserDialog(UserModel user) {
    showDialog(
      context: context,
      builder: (ctx) => _EditUserDialog(
        user: user,
        authRepository: _repo,
      ),
    );
  }

  void _openPermissionsDialog(UserModel user) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => UserPermissionsDialog(
        user: user,
        authRepository: _repo,
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
// GRUPO DE ADMINISTRADOR COM SANFONA (+) / (-) PARA OPERADORES SUBORDINADOS
// ─────────────────────────────────────────────────────────────────────────────
class _AdminTreeGroup extends StatelessWidget {
  final UserModel admin;
  final List<UserModel> subordinates;
  final bool isExpanded;
  final bool isMobile;
  final VoidCallback onToggleExpand;
  final void Function(UserModel) onViewDossier;
  final void Function(UserModel) onEditUser;
  final void Function(UserModel) onEditPermissions;
  final void Function(UserModel) onDeleteUser;

  const _AdminTreeGroup({
    required this.admin,
    required this.subordinates,
    required this.isExpanded,
    required this.isMobile,
    required this.onToggleExpand,
    required this.onViewDossier,
    required this.onEditUser,
    required this.onEditPermissions,
    required this.onDeleteUser,
  });

  @override
  Widget build(BuildContext context) {
    final isSuper = admin.isSuperAdmin;
    final cardBgColor = isSuper
        ? const Color(0xFFFAF5FF)
        : const Color(0xFFFFFBEB);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isExpanded ? (isSuper ? const Color(0xFFA855F7) : const Color(0xFFF59E0B)) : AppColors.border,
          width: isExpanded ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isExpanded ? 0.04 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Linha Principal do Administrador / Líder da Conta ──
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: onToggleExpand,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: 12),
                decoration: BoxDecoration(
                  color: isExpanded ? cardBgColor : Colors.white,
                  borderRadius: isExpanded
                      ? const BorderRadius.vertical(top: Radius.circular(13))
                      : BorderRadius.circular(13),
                ),
                child: Row(
                  children: [
                    // Botão de Sanfona (+) / (-)
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isExpanded
                            ? (isSuper ? const Color(0xFF9333EA) : const Color(0xFFD97706))
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isExpanded
                              ? Colors.transparent
                              : const Color(0xFFCBD5E1),
                        ),
                      ),
                      child: Icon(
                        isExpanded ? Icons.remove_rounded : Icons.add_rounded,
                        size: 18,
                        color: isExpanded ? Colors.white : const Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Avatar
                    CircleAvatar(
                      radius: 17,
                      backgroundColor: isSuper
                          ? const Color(0xFF7E22CE)
                          : const Color(0xFFD97706),
                      child: Text(
                        admin.name.isNotEmpty ? admin.name[0].toUpperCase() : 'A',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Nome e Detalhes
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  admin.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                     fontWeight: FontWeight.bold,
                                     fontSize: 13.5,
                                     color: Theme.of(context).brightness == Brightness.dark
                                         ? AppColors.darkTextPrimary
                                         : const Color(0xFF0F172A),
                                   ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _RoleBadge(role: admin.role),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            admin.email,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          if (admin.phone?.isNotEmpty == true)
                            Row(
                              children: [
                                const Icon(Icons.phone_android_rounded, size: 11, color: Color(0xFF10B981)),
                                const SizedBox(width: 3),
                                Text(
                                  admin.phone!,
                                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF10B981), fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),

                    LayoutBuilder(
                      builder: (context, constraints) {
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!isMobile) ...[
                              // Contador de Subordinados (somente em telas mais largas)
                              if (MediaQuery.of(context).size.width >= 992) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: subordinates.isNotEmpty
                                        ? const Color(0xFFEEF2FF)
                                        : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: subordinates.isNotEmpty
                                          ? const Color(0xFFC7D2FE)
                                          : const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.group_rounded,
                                        size: 14,
                                        color: subordinates.isNotEmpty
                                            ? const Color(0xFF4F46E5)
                                            : const Color(0xFF64748B),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        subordinates.isNotEmpty
                                            ? '${subordinates.length} ${subordinates.length == 1 ? 'operador' : 'operadores'}'
                                            : 'Nenhum operador',
                                        style: GoogleFonts.inter(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: subordinates.isNotEmpty
                                              ? const Color(0xFF4338CA)
                                              : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                              ],

                              // Consumo de IA Hoje
                              AiUsageBadge(user: admin, compact: MediaQuery.of(context).size.width < 1100),
                              const SizedBox(width: 10),

                              // Status Badge
                              _StatusBadge(status: admin.status),
                              const SizedBox(width: 10),
                            ],
                          ],
                        );
                      },
                    ),

                    // Ações do Admin
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Dossiê 360º de Desempenho',
                          icon: const Icon(Icons.analytics_outlined, color: Color(0xFF10B981), size: 19),
                          onPressed: () => onViewDossier(admin),
                        ),
                        IconButton(
                          tooltip: 'Editar Dados e WhatsApp',
                          icon: const Icon(Icons.edit_outlined, color: Color(0xFF0284C7), size: 19),
                          onPressed: () => onEditUser(admin),
                        ),
                        IconButton(
                          tooltip: 'Configurar Permissões',
                          icon: const Icon(Icons.settings_suggest_rounded, color: Color(0xFF6366F1), size: 20),
                          onPressed: () => onEditPermissions(admin),
                        ),
                        IconButton(
                          tooltip: 'Excluir Administrador',
                          icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 18),
                          onPressed: () => onDeleteUser(admin),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Painel Sanfona: Subordinados deste Administrador ──
          if (isExpanded) ...[
            const Divider(height: 1, color: AppColors.divider),
            Container(
              padding: const EdgeInsets.only(left: 32, right: 16, top: 12, bottom: 14),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(13)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.subdirectory_arrow_right_rounded, size: 16, color: Color(0xFF6366F1)),
                      const SizedBox(width: 6),
                      Text(
                        'EQUIPE & OPERADORES VINCULADOS (${subordinates.length})',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.6,
                          color: const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (subordinates.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Nenhum operador cadastrado sob a gestão deste administrador.',
                              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...subordinates.map((sub) => _SubordinateRow(
                      sub: sub,
                      isMobile: isMobile,
                      onViewDossier: () => onViewDossier(sub),
                      onEdit: () => onEditUser(sub),
                      onEditPermissions: () => onEditPermissions(sub),
                      onDelete: () => onDeleteUser(sub),
                    )),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LINHA DE OPERADOR SUBORDINADO
// ─────────────────────────────────────────────────────────────────────────────
class _SubordinateRow extends StatelessWidget {
  final UserModel sub;
  final bool isMobile;
  final VoidCallback onViewDossier;
  final VoidCallback onEdit;
  final VoidCallback onEditPermissions;
  final VoidCallback onDelete;

  const _SubordinateRow({
    required this.sub,
    required this.isMobile,
    required this.onViewDossier,
    required this.onEdit,
    required this.onEditPermissions,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: const Color(0xFFEEF2FF),
            child: Text(
              sub.name.isNotEmpty ? sub.name[0].toUpperCase() : 'U',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
                fontSize: 11.5,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  sub.name,
                  overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.darkTextPrimary
                          : const Color(0xFF0F172A),
                    ),
                ),
                if (sub.phone?.isNotEmpty == true)
                  Text(
                    sub.phone!,
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF10B981), fontWeight: FontWeight.w500),
                  ),
              ],
            ),
          ),
          if (!isMobile) ...[
            Expanded(
              flex: 3,
              child: Text(
                sub.email,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF475569)),
              ),
            ),
            _RoleBadge(role: sub.role),
            const SizedBox(width: 8),
            AiUsageBadge(user: sub, compact: true),
            const SizedBox(width: 8),
            _StatusBadge(status: sub.status),
            if (MediaQuery.of(context).size.width >= 1050) ...[
              const SizedBox(width: 8),
              Text(
                '${sub.createdAt.day.toString().padLeft(2, '0')}/${sub.createdAt.month.toString().padLeft(2, '0')}/${sub.createdAt.year}',
                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
              ),
            ],
            const SizedBox(width: 8),
          ],
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Dossiê 360º de Desempenho',
                icon: const Icon(Icons.analytics_outlined, color: Color(0xFF10B981), size: 17),
                onPressed: onViewDossier,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
              IconButton(
                tooltip: 'Editar Dados e WhatsApp',
                icon: const Icon(Icons.edit_outlined, color: Color(0xFF0284C7), size: 17),
                onPressed: onEdit,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
              IconButton(
                tooltip: 'Permissões de Acesso',
                icon: const Icon(Icons.settings_suggest_rounded, color: Color(0xFF6366F1), size: 18),
                onPressed: onEditPermissions,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
              IconButton(
                tooltip: 'Excluir Operador',
                icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 16),
                onPressed: onDelete,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GRUPO DE OPERADORES ÓRFÃOS / DIRETOS
// ─────────────────────────────────────────────────────────────────────────────
class _OrphansGroup extends StatelessWidget {
  final List<UserModel> orphans;
  final bool isMobile;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final void Function(UserModel) onViewDossier;
  final void Function(UserModel) onEditUser;
  final void Function(UserModel) onEditPermissions;
  final void Function(UserModel) onDeleteUser;

  const _OrphansGroup({
    required this.orphans,
    required this.isMobile,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.onViewDossier,
    required this.onEditUser,
    required this.onEditPermissions,
    required this.onDeleteUser,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onToggleExpand,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Icon(
                        isExpanded ? Icons.remove_rounded : Icons.add_rounded,
                        size: 18,
                        color: const Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.people_outline_rounded, size: 20, color: Color(0xFF64748B)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Outros Operadores / Cadastros Diretos (${orphans.length})',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFF334155)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1, color: AppColors.divider),
            Container(
              padding: const EdgeInsets.all(16),
              color: const Color(0xFFF8FAFC),
              child: Column(
                children: orphans.map((sub) => _SubordinateRow(
                  sub: sub,
                  isMobile: isMobile,
                  onViewDossier: () => onViewDossier(sub),
                  onEdit: () => onEditUser(sub),
                  onEditPermissions: () => onEditPermissions(sub),
                  onDelete: () => onDeleteUser(sub),
                )).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Linha de usuário
// ─────────────────────────────────────────────────────────────────────────────
class _UserRow extends StatelessWidget {
  final UserModel user;
  final VoidCallback onViewDossier;
  final VoidCallback onEdit;
  final VoidCallback onEditPermissions;
  final VoidCallback onDelete;

  const _UserRow({
    required this.user,
    required this.onViewDossier,
    required this.onEdit,
    required this.onEditPermissions,
    required this.onDelete,
  });

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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        user.name,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? AppColors.darkTextPrimary
                                : const Color(0xFF0F172A)),
                      ),
                      if (user.phone?.isNotEmpty == true)
                        Row(
                          children: [
                            const Icon(Icons.phone_android_rounded, size: 11, color: Color(0xFF10B981)),
                            const SizedBox(width: 3),
                            Text(
                              user.phone!,
                              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF10B981), fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                    ],
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
          // Consumo de IA
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: AiUsageBadge(user: user, compact: true),
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
          // Ações (Dossiê + Editar Dados/Telefone + Engrenagem de Permissões + Excluir)
          SizedBox(
            width: 155,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Dossiê 360º de Desempenho',
                  icon: const Icon(
                    Icons.analytics_outlined,
                    color: Color(0xFF10B981),
                    size: 19,
                  ),
                  onPressed: onViewDossier,
                ),
                IconButton(
                  tooltip: 'Editar Dados e WhatsApp',
                  icon: const Icon(
                    Icons.edit_outlined,
                    color: Color(0xFF0284C7),
                    size: 19,
                  ),
                  onPressed: onEdit,
                ),
                IconButton(
                  tooltip: 'Configurar Permissões de Acesso',
                  icon: const Icon(
                    Icons.settings_suggest_rounded,
                    color: Color(0xFF6366F1),
                    size: 20,
                  ),
                  onPressed: onEditPermissions,
                ),
                IconButton(
                  tooltip: 'Excluir Usuário',
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Color(0xFFEF4444),
                    size: 18,
                  ),
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Estado vazio
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final bool isEmpty;
  final bool canAdd;
  final VoidCallback onAdd;

  const _EmptyState({
    required this.isEmpty,
    this.canAdd = true,
    required this.onAdd,
  });

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
          if (isEmpty && canAdd) ...[
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
  final _phoneCtrl = TextEditingController();
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
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _clear() {
    _nameCtrl.clear();
    _emailCtrl.clear();
    _phoneCtrl.clear();
    _passCtrl.clear();
    _confirmCtrl.clear();
    _store.setName('');
    _store.setEmail('');
    _store.setPhone('');
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

          _label('WhatsApp / Telefone (para IA do WhatsApp)'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _phoneCtrl,
            onChanged: _store.setPhone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              hintText: '(65) 99349-3626',
              prefixIcon: Icon(Icons.phone_outlined, color: Color(0xFF64748B)),
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
      'superadmin' || 'master' => (
          const Color(0xFFF3E8FF),
          const Color(0xFF7E22CE),
          '👑 Super Admin'
        ),
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

// ─────────────────────────────────────────────────────────────────────────────
// DIÁLOGO DE EDIÇÃO DE USUÁRIO (NOME, WHATSAPP, CARGO, STATUS)
// ─────────────────────────────────────────────────────────────────────────────
class _EditUserDialog extends StatefulWidget {
  final UserModel user;
  final AuthRepository authRepository;

  const _EditUserDialog({
    required this.user,
    required this.authRepository,
  });

  @override
  State<_EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<_EditUserDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late String _selectedRole;
  late String _selectedStatus;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.user.name);
    _phoneCtrl = TextEditingController(text: widget.user.phone ?? '');
    _selectedRole = widget.user.role;
    _selectedStatus = widget.user.status;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, informe o nome do usuário.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await widget.authRepository.updateUser(
        uid: widget.user.uid,
        name: name,
        phone: _phoneCtrl.text.trim(),
        role: _selectedRole,
        status: _selectedStatus,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dados do usuário e WhatsApp atualizados com sucesso!'),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao salvar: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabeçalho
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.edit_note_rounded,
                      color: Color(0xFF0284C7), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Editar Operador / Usuário',
                          style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0F172A))),
                      Text(widget.user.email,
                          style: GoogleFonts.inter(
                              fontSize: 12, color: const Color(0xFF64748B))),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF94A3B8), size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 16),

            // Nome
            Text(
              'Nome Completo',
              style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF334155)),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                hintText: 'Nome do usuário',
                prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF64748B), size: 20),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 14),

            // Telefone / WhatsApp com destaque
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.phone_android_rounded, size: 16, color: Color(0xFF16A34A)),
                      const SizedBox(width: 6),
                      Text(
                        'WhatsApp / Celular (IA Copiloto)',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF166534),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Utilizado pela Inteligência Artificial do WhatsApp para identificar o operador e autorizar a emissão de propostas.',
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF15803D)),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      hintText: '(65) 99349-3626',
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: const Icon(Icons.phone_outlined, color: Color(0xFF16A34A), size: 20),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF86EFAC)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF86EFAC)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Cargo / Nível de Acesso
            Text(
              'Cargo / Nível de Acesso',
              style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF334155)),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _selectedRole,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.badge_outlined, color: Color(0xFF64748B), size: 20),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
            const SizedBox(height: 14),

            // Status
            Text(
              'Status da Conta',
              style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF334155)),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _selectedStatus,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.toggle_on_outlined, color: Color(0xFF64748B), size: 20),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              items: const [
                DropdownMenuItem(value: 'active', child: Text('Ativo (Acesso Liberado)')),
                DropdownMenuItem(value: 'blocked', child: Text('Bloqueado (Acesso Suspenso)')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedStatus = val);
              },
            ),
            const SizedBox(height: 22),

            // Botões de Ação
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                  child: Text('CANCELAR',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B))),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : Text('SALVAR ALTERAÇÕES',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
