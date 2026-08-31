import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app/layout/app_sidebar.dart';
import '../../app/theme/app_colors.dart';
import '../../app/widgets/taos_logo.dart';
import '../../auth/data/repositories/auth_repository.dart';
import '../../auth/domain/models/user_model.dart';
import '../../clients/data/repositories/client_repository.dart';
import '../../clients/domain/models/client_model.dart';
import '../../clients/presentation/clients_view.dart';
import '../../products/data/repositories/product_repository.dart';
import '../../products/domain/models/product_model.dart';
import '../../products/presentation/products_view.dart';
import '../../proposals/data/repositories/proposal_repository.dart';
import '../../proposals/data/services/proposal_auto_pdf_sync_service.dart';
import '../../proposals/domain/models/proposal_item_model.dart';
import '../../proposals/domain/models/proposal_model.dart';
import '../../proposals/presentation/proposals_view.dart';
import '../../suppliers/presentation/suppliers_view.dart';
import '../../users/presentation/users_view.dart';
import '../../settings/data/services/settings_service.dart';
import '../../settings/presentation/settings_view.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late final AuthRepository _authRepo;
  StreamSubscription<UserModel?>? _userSub;
  UserModel? _currentUser;

  AppSidebarItem _activeItem = AppSidebarItem.dashboard;
  bool _isSidebarCollapsed = false;
  ProposalItemModel? _pendingProposalItem;
  ProductSector? _preferredSector;

  @override
  void initState() {
    super.initState();
    try {
      _authRepo = Modular.get<AuthRepository>();
    } catch (_) {
      _authRepo = AuthRepository();
    }

    _listenCurrentUser();
    _loadPreferredSector();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _checkFirstLoginOnboarding());
  }

  void _listenCurrentUser() {
    _userSub = _authRepo.getCurrentUserStream().listen((user) {
      if (mounted) {
        setState(() {
          _currentUser = user;
        });

        // Inicia o ouvinte em segundo plano para compilar PDFs de propostas criadas externamente
        if (user != null) {
          ProposalAutoPdfSyncService.startSync(
              companyId: user.effectiveCompanyId);
        }
      }
    });
  }

  @override
  void dispose() {
    _userSub?.cancel();
    ProposalAutoPdfSyncService.stopSync();
    super.dispose();
  }

  Future<void> _loadPreferredSector() async {
    final sector = await SettingsService.getPreferredSector();
    if (mounted) {
      setState(() {
        _preferredSector = sector;
      });
    }
  }

  Future<void> _checkFirstLoginOnboarding() async {
    final completed = await SettingsService.hasCompletedOnboarding();
    if (!completed && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withValues(alpha: 0.96),
        builder: (ctx) => SectorOnboardingDialog(
          onSectorSelected: (sector) {
            _loadPreferredSector();
          },
        ),
      );
    }
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarCollapsed = !_isSidebarCollapsed;
    });
  }

  void _navigateToProposalWithItem(ProposalItemModel item) {
    setState(() {
      _pendingProposalItem = item;
      _activeItem = AppSidebarItem.proposals;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final isSolar = _preferredSector == ProductSector.solarPlant;
    final productsTitle = isSolar ? 'Usinas Solares' : 'Produtos';
    final productsIcon =
        isSolar ? Icons.solar_power_rounded : Icons.inventory_2_outlined;

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: isMobile
          ? Drawer(
              backgroundColor: const Color(0xFF0F172A),
              child: SafeArea(
                child: AppSidebar(
                  activeItem: _activeItem,
                  isCollapsed: false,
                  productsTitle: productsTitle,
                  productsIcon: productsIcon,
                  currentUser: _currentUser,
                  onItemSelected: (item) {
                    setState(() {
                      _activeItem = item;
                    });
                    Navigator.pop(context);
                  },
                ),
              ),
            )
          : null,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: Builder(
          builder: (appBarCtx) => IconButton(
            tooltip: isMobile
                ? 'Abrir Menu'
                : (_isSidebarCollapsed
                    ? 'Expandir Menu Lateral'
                    : 'Recolher Menu Lateral'),
            icon: Icon(
              isMobile
                  ? Icons.menu_rounded
                  : (_isSidebarCollapsed
                      ? Icons.menu_rounded
                      : Icons.menu_open_rounded),
              color: Colors.white,
              size: 22,
            ),
            onPressed: isMobile
                ? () => Scaffold.of(appBarCtx).openDrawer()
                : _toggleSidebar,
          ),
        ),
        title: TaosLogo(
          iconSize: isMobile ? 32 : 36,
          fontSize: isMobile ? 18 : 20,
        ),
        actions: [
          IconButton(
            tooltip: 'Sair do Sistema',
            icon: const Icon(Icons.logout_rounded, color: Color(0xFFF87171)),
            onPressed: () {
              Modular.to.navigate('/auth/login');
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: isMobile
          ? LayoutBuilder(
              builder: (context, constraints) {
                return SizedBox(
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  child: _buildMiolo(),
                );
              },
            )
          : Row(
              children: [
                AppSidebar(
                  activeItem: _activeItem,
                  isCollapsed: _isSidebarCollapsed,
                  onToggleCollapse: _toggleSidebar,
                  productsTitle: productsTitle,
                  productsIcon: productsIcon,
                  currentUser: _currentUser,
                  onItemSelected: (item) {
                    setState(() {
                      _activeItem = item;
                    });
                  },
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SizedBox(
                        width: constraints.maxWidth,
                        height: constraints.maxHeight,
                        child: _buildMiolo(),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildMiolo() {
    final canViewClients = _currentUser?.canViewClients ?? false;
    final canViewProducts = _currentUser?.canViewProducts ?? false;
    final canViewSuppliers = _currentUser?.canViewSuppliers ?? false;
    final canViewProposals = _currentUser?.canViewProposals ?? false;
    final canManageUsers = _currentUser?.canManageUsers ?? false;
    final canManageSettings = _currentUser?.canManageSettings ?? false;

    switch (_activeItem) {
      case AppSidebarItem.dashboard:
        if (_currentUser?.isSuperAdmin == true) {
          return _SuperAdminMasterDashboard(
            currentUser: _currentUser!,
            onNavigate: (item) => setState(() => _activeItem = item),
          );
        }
        return const Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(32.0),
            child: _WelcomeCard(),
          ),
        );
      case AppSidebarItem.clients:
        if (!canViewClients) {
          return const Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(32.0),
              child: _WelcomeCard(),
            ),
          );
        }
        return ClientsView(currentUser: _currentUser);
      case AppSidebarItem.products:
        if (!canViewProducts) {
          return const Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(32.0),
              child: _WelcomeCard(),
            ),
          );
        }
        return ProductsView(
          currentUser: _currentUser,
          onProceedToProposal: _navigateToProposalWithItem,
        );
      case AppSidebarItem.suppliers:
        if (!canViewSuppliers) {
          return const Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(32.0),
              child: _WelcomeCard(),
            ),
          );
        }
        return SuppliersView(currentUser: _currentUser);
      case AppSidebarItem.proposals:
        if (!canViewProposals) {
          return const Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(32.0),
              child: _WelcomeCard(),
            ),
          );
        }
        return ProposalsView(
          currentUser: _currentUser,
          initialItem: _pendingProposalItem,
          onClearInitialItem: () => setState(() => _pendingProposalItem = null),
        );
      case AppSidebarItem.users:
        if (!canManageUsers) {
          return const Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(32.0),
              child: _WelcomeCard(),
            ),
          );
        }
        return UsersView(currentUser: _currentUser);
      case AppSidebarItem.settings:
        if (!canManageSettings) {
          return const Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(32.0),
              child: _WelcomeCard(),
            ),
          );
        }
        return SettingsView(onSectorChanged: _loadPreferredSector);
    }
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard();

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      constraints: const BoxConstraints(maxWidth: 600),
      padding: EdgeInsets.all(isMobile ? 24.0 : 40.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(isMobile ? 16 : 20),
            decoration: const BoxDecoration(
              color: Color(0xFFEEF2FF),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.waving_hand_rounded,
              color: AppColors.primary,
              size: isMobile ? 36 : 48,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Boas-vindas ao TAOS CRM!',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: isMobile ? 22 : 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Você está autenticado no painel principal. Utilize o menu lateral para navegar entre as seções do sistema.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: isMobile ? 14 : 16,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Sistema Online & Conectado',
                  style: GoogleFonts.inter(
                    fontSize: isMobile ? 12.5 : 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF334155),
                  ),
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
// PAINEL DE CONTROLE GERAL / MASTER AUDIT DASHBOARD (SUPER ADMIN)
// ─────────────────────────────────────────────────────────────────────────────
class _SuperAdminMasterDashboard extends StatefulWidget {
  final UserModel currentUser;
  final void Function(AppSidebarItem) onNavigate;

  const _SuperAdminMasterDashboard({
    required this.currentUser,
    required this.onNavigate,
  });

  @override
  State<_SuperAdminMasterDashboard> createState() =>
      _SuperAdminMasterDashboardState();
}

class _SuperAdminMasterDashboardState extends State<_SuperAdminMasterDashboard> {
  late final AuthRepository _authRepo;
  late final ProposalRepository _proposalRepo;
  late final ProductRepository _productRepo;
  late final ClientRepository _clientRepo;

  @override
  void initState() {
    super.initState();
    try {
      _authRepo = Modular.get<AuthRepository>();
    } catch (_) {
      _authRepo = AuthRepository();
    }
    try {
      _proposalRepo = Modular.get<ProposalRepository>();
    } catch (_) {
      _proposalRepo = ProposalRepository();
    }
    try {
      _productRepo = Modular.get<ProductRepository>();
    } catch (_) {
      _productRepo = ProductRepository();
    }
    try {
      _clientRepo = Modular.get<ClientRepository>();
    } catch (_) {
      _clientRepo = ClientRepository();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return StreamBuilder<List<UserModel>>(
      stream: _authRepo.getUsersStream(isSuperAdmin: true),
      builder: (context, userSnap) {
        return StreamBuilder<List<ProposalModel>>(
          stream: _proposalRepo.getProposalsStream(isSuperAdmin: true),
          builder: (context, propSnap) {
            return StreamBuilder<List<ProductModel>>(
              stream: _productRepo.getProductsStream(isSuperAdmin: true),
              builder: (context, prodSnap) {
                return StreamBuilder<List<ClientModel>>(
                  stream: _clientRepo.getClientsStream(isSuperAdmin: true),
                  builder: (context, clientSnap) {
                    final users = userSnap.data ?? [];
                    final proposals = propSnap.data ?? [];
                    final products = prodSnap.data ?? [];
                    final clients = clientSnap.data ?? [];

                    final adminsCount = users.where((u) => u.isAdmin || u.isSuperAdmin).length;
                    final totalRevenue = proposals.fold<double>(
                      0.0,
                      (acc, p) => acc + p.totalAmount,
                    );

                    return SingleChildScrollView(
                      padding: EdgeInsets.all(isMobile ? 16 : 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Header Master ───────────────────────────
                          Container(
                            padding: EdgeInsets.all(isMobile ? 18 : 24),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF312E81)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFF818CF8).withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.admin_panel_settings_rounded,
                                    color: Color(0xFFA5B4FC),
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            'Painel de Controle Geral',
                                            style: GoogleFonts.outfit(
                                              fontSize: isMobile ? 18 : 22,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF7E22CE),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              'SUPER ADMIN',
                                              style: GoogleFonts.inter(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Visão global consolidada de todos os usuários, propostas e movimentações do sistema em tempo real.',
                                        style: GoogleFonts.inter(
                                          fontSize: isMobile ? 12 : 13.5,
                                          color: const Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // ── KPIs Globais em Grade ─────────────────────
                          Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: [
                              _KpiCard(
                                title: 'ADMINISTRADORES',
                                value: '$adminsCount',
                                subtitle: 'Contas & Empresas Ativas',
                                icon: Icons.shield_rounded,
                                color: const Color(0xFFF59E0B),
                                isMobile: isMobile,
                                onTap: () => widget.onNavigate(AppSidebarItem.users),
                              ),
                              _KpiCard(
                                title: 'TOTAL DE USUÁRIOS',
                                value: '${users.length}',
                                subtitle: '${users.length - adminsCount} operadores vinculados',
                                icon: Icons.people_alt_rounded,
                                color: const Color(0xFF6366F1),
                                isMobile: isMobile,
                                onTap: () => widget.onNavigate(AppSidebarItem.users),
                              ),
                              _KpiCard(
                                title: 'PROPOSTAS EMITIDAS',
                                value: '${proposals.length}',
                                subtitle: 'No funil e relatórios',
                                icon: Icons.description_rounded,
                                color: const Color(0xFF0284C7),
                                isMobile: isMobile,
                                onTap: () => widget.onNavigate(AppSidebarItem.proposals),
                              ),
                              _KpiCard(
                                title: 'VOLUME DE NEGÓCIOS',
                                value: 'R\$ ${_formatCurrency(totalRevenue)}',
                                subtitle: 'Em propostas geradas',
                                icon: Icons.payments_rounded,
                                color: const Color(0xFF10B981),
                                isMobile: isMobile,
                                onTap: () => widget.onNavigate(AppSidebarItem.proposals),
                              ),
                              _KpiCard(
                                title: 'CLIENTES CADASTRADOS',
                                value: '${clients.length}',
                                subtitle: 'Pessoas Físicas e Jurídicas',
                                icon: Icons.person_pin_circle_rounded,
                                color: const Color(0xFF8B5CF6),
                                isMobile: isMobile,
                                onTap: () => widget.onNavigate(AppSidebarItem.clients),
                              ),
                              _KpiCard(
                                title: 'CATÁLOGO & USINAS',
                                value: '${products.length}',
                                subtitle: 'Equipamentos e kits',
                                icon: Icons.solar_power_rounded,
                                color: const Color(0xFFEA580C),
                                isMobile: isMobile,
                                onTap: () => widget.onNavigate(AppSidebarItem.products),
                              ),
                            ],
                          ),

                          const SizedBox(height: 28),

                          // ── Feed de Auditoria em Tempo Real ────────────
                          if (isMobile) ...[
                            _RecentProposalsAuditCard(
                              proposals: proposals,
                              onViewAll: () => widget.onNavigate(AppSidebarItem.proposals),
                            ),
                            const SizedBox(height: 16),
                            _RecentClientsAuditCard(
                              clients: clients,
                              onViewAll: () => widget.onNavigate(AppSidebarItem.clients),
                            ),
                          ] else ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: _RecentProposalsAuditCard(
                                    proposals: proposals,
                                    onViewAll: () => widget.onNavigate(AppSidebarItem.proposals),
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  flex: 2,
                                  child: _RecentClientsAuditCard(
                                    clients: clients,
                                    onViewAll: () => widget.onNavigate(AppSidebarItem.clients),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  String _formatCurrency(double val) {
    if (val >= 1000000) {
      return '${(val / 1000000).toStringAsFixed(2).replaceAll('.', ',')}M';
    }
    if (val >= 1000) {
      return '${(val / 1000).toStringAsFixed(1).replaceAll('.', ',')}k';
    }
    return val.toStringAsFixed(2).replaceAll('.', ',');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD DE KPI INDIVIDUAL
// ─────────────────────────────────────────────────────────────────────────────
class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isMobile;
  final VoidCallback onTap;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.isMobile,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: isMobile ? double.infinity : 260,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.6,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD DE AUDITORIA DE PROPOSTAS RECENTES
// ─────────────────────────────────────────────────────────────────────────────
class _RecentProposalsAuditCard extends StatelessWidget {
  final List<ProposalModel> proposals;
  final VoidCallback onViewAll;

  const _RecentProposalsAuditCard({
    required this.proposals,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final recent = proposals.take(6).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.history_rounded, size: 20, color: Color(0xFF6366F1)),
                  const SizedBox(width: 8),
                  Text(
                    'Últimas Propostas Emitidas no Sistema',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: onViewAll,
                child: Text(
                  'Ver todas ↗',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (recent.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Nenhuma proposta registrada no momento.',
                  style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recent.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.divider),
              itemBuilder: (_, i) {
                final p = recent[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.insert_drive_file_outlined, size: 18, color: Color(0xFF475569)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  p.proposalNumber,
                                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFF0F172A)),
                                ),
                                const SizedBox(width: 8),
                                if (p.createdByUserName?.isNotEmpty == true)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEEF2FF),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Por: ${p.createdByUserName}',
                                      style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF4F46E5), fontWeight: FontWeight.w600),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              p.clientName,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'R\$ ${p.totalAmount.toStringAsFixed(2).replaceAll('.', ',')}',
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFF10B981)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            p.status.label,
                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD DE AUDITORIA DE CLIENTES RECENTES
// ─────────────────────────────────────────────────────────────────────────────
class _RecentClientsAuditCard extends StatelessWidget {
  final List<ClientModel> clients;
  final VoidCallback onViewAll;

  const _RecentClientsAuditCard({
    required this.clients,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final recent = clients.take(6).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.people_alt_outlined, size: 20, color: Color(0xFF8B5CF6)),
                  const SizedBox(width: 8),
                  Text(
                    'Últimos Clientes',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: onViewAll,
                child: Text(
                  'Ver todos ↗',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (recent.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Nenhum cliente cadastrado.',
                  style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recent.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.divider),
              itemBuilder: (_, i) {
                final c = recent[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: const Color(0xFFF3E8FF),
                        child: Text(
                          c.name.isNotEmpty ? c.name[0].toUpperCase() : 'C',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: const Color(0xFF7E22CE),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.name,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: const Color(0xFF0F172A)),
                            ),
                            Text(
                              c.email.isNotEmpty ? c.email : (c.phone ?? ''),
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          c.type == ClientType.company ? 'PJ' : 'PF',
                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF475569)),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
