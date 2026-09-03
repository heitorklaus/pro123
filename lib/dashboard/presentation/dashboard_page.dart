import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../app/layout/app_sidebar.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
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
import '../../contracts/data/repositories/contract_repository.dart';
import '../../contracts/domain/models/contract_model.dart';
import '../../contracts/presentation/contracts_view.dart';
import '../../suppliers/presentation/suppliers_view.dart';
import '../../users/presentation/users_view.dart';
import '../../users/presentation/widgets/ai_usage_badge.dart';
import '../../users/presentation/widgets/user_dossier_dialog.dart';
import '../../settings/data/services/company_service.dart';
import '../../settings/data/services/settings_service.dart';
import '../../settings/presentation/settings_view.dart';
import 'widgets/master_system_config_card.dart';
import '../../solar_designer/presentation/solar_roof_designer_dialog.dart';

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
  ProductSector? _preferredSector = ProductSector.solarPlant;

  bool _isOnboardingOpen = false;

  @override
  void initState() {
    super.initState();
    _authRepo = Modular.get<AuthRepository>();

    final initialItem = Modular.args.data;
    if (initialItem is ProposalItemModel) {
      _pendingProposalItem = initialItem;
      _activeItem = AppSidebarItem.proposals;
    }

    _listenCurrentUser();
    _loadPreferredSector();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkFirstLoginOnboarding();
    });
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
          _checkFirstLoginOnboarding();
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
    final sector = await SettingsService.getPreferredSector(
      companyId: _currentUser?.effectiveCompanyId,
      userId: _currentUser?.uid,
    );
    if (mounted) {
      setState(() {
        _preferredSector = sector;
      });
    }
  }

  Future<void> _checkFirstLoginOnboarding() async {
    if (_isOnboardingOpen || !mounted) return;

    try {
      final user = _currentUser ?? await _authRepo.getCurrentUser();
      // Verifica se é administrador / dono da empresa
      final isAdmin = user == null || user.isAdmin || user.role == 'admin' || user.isSuperAdmin;
      if (!isAdmin) return;

      // 1. Verifica no Banco de Dados se o usuário ou a empresa já têm um nicho salvo
      final hasSectorInDb = await CompanyService.hasCompletedOnboarding(
        companyId: user?.effectiveCompanyId,
        userId: user?.uid,
      );

      if (hasSectorInDb) {
        // Nicho já está salvo no banco de dados! Garante sincronia local e NÃO abre a janela
        await _loadPreferredSector();
        await SettingsService.setCompletedOnboarding(true);
        return;
      }

      // 2. Se o usuário NÃO escolheu o nicho no banco de dados ainda, AI SIM abre a janela toda vez
      if (mounted && !_isOnboardingOpen) {
        _openOnboardingDialog();
      }
    } catch (e) {
      debugPrint('[DashboardPage] Erro ao verificar onboarding: $e');
    }
  }

  void _openOnboardingDialog() {
    if (_isOnboardingOpen || !mounted) return;
    _isOnboardingOpen = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.60),
      builder: (ctx) => SectorOnboardingDialog(
        onSectorSelected: (sector) {
          _loadPreferredSector();
        },
        onCompleted: () {
          _isOnboardingOpen = false;
          _loadPreferredSector();
          if (mounted) setState(() {});
        },
        openCompanyFormAfter: true,
      ),
    ).then((_) {
      _isOnboardingOpen = false;
    });
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
          if (isSolar) ...[
            TextButton.icon(
              onPressed: () => SolarRoofDesignerDialog.show(context),
              icon: const Icon(Icons.satellite_alt_rounded, color: Color(0xFF38BDF8), size: 17),
              label: Text(
                isMobile ? 'Satélite' : 'Estudo de Telhado 🛰️',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(width: 6),
          ],
          ValueListenableBuilder<ThemeMode>(
            valueListenable: AppTheme.themeModeNotifier,
            builder: (context, themeMode, _) {
              final isDark = themeMode == ThemeMode.dark;
              return IconButton(
                tooltip: isDark ? 'Mudar para Tema Claro' : 'Mudar para Tema Escuro',
                icon: Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  color: isDark ? const Color(0xFFFBBF24) : const Color(0xFF94A3B8),
                  size: 22,
                ),
                onPressed: () => AppTheme.toggleThemeMode(),
              );
            },
          ),
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
    final canViewContracts = _currentUser?.canViewContracts ?? false;
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
        if (_currentUser?.isAdmin == true || _currentUser?.isManager == true || _currentUser?.canViewAllProposals == true) {
          return _CompanyExecutiveDashboard(
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
      case AppSidebarItem.contracts:
        if (!canViewContracts) {
          return const Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(32.0),
              child: _WelcomeCard(),
            ),
          );
        }
        return ContractsView(currentUser: _currentUser);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: const BoxConstraints(maxWidth: 600),
      padding: EdgeInsets.all(isMobile ? 24.0 : 40.0),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(isMobile ? 16 : 20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFEEF2FF),
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
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Você está autenticado no painel principal. Utilize o menu lateral para navegar entre as seções do sistema.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: isMobile ? 14 : 16,
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0B1120) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? AppColors.darkBorder : Colors.transparent),
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
                    color: isDark ? AppColors.darkTextPrimary : const Color(0xFF334155),
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
  late final ContractRepository _contractRepo;
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
      _contractRepo = Modular.get<ContractRepository>();
    } catch (_) {
      _contractRepo = ContractRepository();
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
                return StreamBuilder<List<ContractModel>>(
                  stream: _contractRepo.getContractsStream(isSuperAdmin: true),
                  builder: (context, contSnap) {
                    return StreamBuilder<List<ClientModel>>(
                      stream: _clientRepo.getClientsStream(isSuperAdmin: true),
                      builder: (context, clientSnap) {
                        final users = userSnap.data ?? [];
                        final proposals = propSnap.data ?? [];
                        final products = prodSnap.data ?? [];
                        final contracts = contSnap.data ?? [];
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

                          // ── Painel Executivo Master: Cotas de IA & Limite de Vendedores ──
                          MasterSystemConfigCard(
                            currentUser: widget.currentUser,
                            allUsers: users,
                          ),

                          const SizedBox(height: 28),

                          // ── Ranking Geral de Vendedores & Operadores ───
                          _TeamPerformanceRankingCard(
                            users: users,
                            proposals: proposals,
                            products: products,
                            contracts: contracts,
                            currentUser: widget.currentUser,
                            onOpenDossier: (u) {
                              showDialog(
                                context: context,
                                builder: (ctx) => UserDossierDialog(
                                  user: u,
                                  currentUser: widget.currentUser,
                                ),
                              );
                            },
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

// ─────────────────────────────────────────────────────────────────────────────
// PAINEL EXECUTIVO DA EMPRESA / GESTÃO COMERCIAL DA EQUIPE (ADMIN / GERENTE)
// ─────────────────────────────────────────────────────────────────────────────
class _CompanyExecutiveDashboard extends StatefulWidget {
  final UserModel currentUser;
  final void Function(AppSidebarItem) onNavigate;

  const _CompanyExecutiveDashboard({
    required this.currentUser,
    required this.onNavigate,
  });

  @override
  State<_CompanyExecutiveDashboard> createState() => _CompanyExecutiveDashboardState();
}

class _CompanyExecutiveDashboardState extends State<_CompanyExecutiveDashboard> {
  late final AuthRepository _authRepo;
  late final ProposalRepository _proposalRepo;
  late final ProductRepository _productRepo;
  late final ContractRepository _contractRepo;
  late final ClientRepository _clientRepo;
  final _currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

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
      _contractRepo = Modular.get<ContractRepository>();
    } catch (_) {
      _contractRepo = ContractRepository();
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
    final cid = widget.currentUser.effectiveCompanyId;

    return StreamBuilder<List<UserModel>>(
      stream: _authRepo.getUsersStream(companyId: cid, isSuperAdmin: false),
      builder: (context, userSnap) {
        return StreamBuilder<List<ProposalModel>>(
          stream: _proposalRepo.getProposalsStream(
            companyId: cid,
            isSuperAdmin: false,
            isAllProposalsVisible: true,
          ),
          builder: (context, propSnap) {
            return StreamBuilder<List<ProductModel>>(
              stream: _productRepo.getProductsStream(
                companyId: cid,
                isSuperAdmin: false,
              ),
              builder: (context, prodSnap) {
                return StreamBuilder<List<ContractModel>>(
                  stream: _contractRepo.getContractsStream(
                    companyId: cid,
                    isSuperAdmin: false,
                  ),
                  builder: (context, contSnap) {
                    return StreamBuilder<List<ClientModel>>(
                      stream: _clientRepo.getClientsStream(
                        companyId: cid,
                        isSuperAdmin: false,
                      ),
                      builder: (context, clientSnap) {
                        final users = userSnap.data ?? [];
                        final proposals = propSnap.data ?? [];
                        final products = prodSnap.data ?? [];
                        final contracts = contSnap.data ?? [];
                        final clients = clientSnap.data ?? [];

                        final totalRevenue = proposals.fold<double>(0.0, (acc, p) => acc + p.totalAmount);
                        final closedProposals = proposals.where((p) => p.status == ProposalStatus.closed).toList();
                        final closedRevenue = closedProposals.fold<double>(0.0, (acc, p) => acc + p.totalAmount);
                        final conversionRate = proposals.isEmpty ? 0.0 : (closedProposals.length / proposals.length) * 100;
                        final solarPlants = products.where((p) => p.sector == ProductSector.solarPlant || p.isSolarPlantKit).toList();
                        final totalKwp = solarPlants.fold<double>(0.0, (acc, p) => acc + (p.solarKilowatts ?? 0.0));
                        final signedContracts = contracts.where((c) => c.status == ContractStatus.signed).toList();

                        return SingleChildScrollView(
                          padding: EdgeInsets.all(isMobile ? 16 : 32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ── Header Executivo da Empresa ────────────────
                              Container(
                                padding: EdgeInsets.all(isMobile ? 18 : 24),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF1E1B4B)],
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
                                        Icons.analytics_rounded,
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
                                              Flexible(
                                                child: Text(
                                                  'Painel Executivo da Empresa',
                                                  overflow: TextOverflow.ellipsis,
                                                  style: GoogleFonts.outfit(
                                                    fontSize: isMobile ? 18 : 22,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF6366F1),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  widget.currentUser.isAdmin ? 'ADMINISTRADOR' : 'GERENTE COMERCIAL',
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
                                            'Acompanhe o desempenho, faturamento e ranking de vendas de toda a sua equipe em tempo real.',
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

                              // ── KPIs da Empresa ────────────────────────────
                              Wrap(
                                spacing: 16,
                                runSpacing: 16,
                                children: [
                                  _KpiCard(
                                    title: 'VENDAS FECHADAS (GANHAS)',
                                    value: _formatCurrency(closedRevenue),
                                    subtitle: '${closedProposals.length} propostas ganhas',
                                    icon: Icons.verified_rounded,
                                    color: const Color(0xFF10B981),
                                    isMobile: isMobile,
                                    onTap: () => widget.onNavigate(AppSidebarItem.proposals),
                                  ),
                                  _KpiCard(
                                    title: 'TOTAL EM PROPOSTAS',
                                    value: _formatCurrency(totalRevenue),
                                    subtitle: '${proposals.length} orçamentos emitidos',
                                    icon: Icons.receipt_long_rounded,
                                    color: const Color(0xFF6366F1),
                                    isMobile: isMobile,
                                    onTap: () => widget.onNavigate(AppSidebarItem.proposals),
                                  ),
                                  _KpiCard(
                                    title: 'TAXA DE CONVERSÃO',
                                    value: '${conversionRate.toStringAsFixed(1)}%',
                                    subtitle: 'Aprovação geral da equipe',
                                    icon: Icons.trending_up_rounded,
                                    color: const Color(0xFF0284C7),
                                    isMobile: isMobile,
                                    onTap: () => widget.onNavigate(AppSidebarItem.proposals),
                                  ),
                                  _KpiCard(
                                    title: 'POTÊNCIA OFERTADA',
                                    value: '${totalKwp.toStringAsFixed(1)} kWp',
                                    subtitle: '${solarPlants.length} usinas solares no catálogo',
                                    icon: Icons.solar_power_rounded,
                                    color: const Color(0xFFF59E0B),
                                    isMobile: isMobile,
                                    onTap: () => widget.onNavigate(AppSidebarItem.products),
                                  ),
                                  _KpiCard(
                                    title: 'CONTRATOS GERADOS',
                                    value: '${contracts.length}',
                                    subtitle: '${signedContracts.length} assinados / fechados',
                                    icon: Icons.gavel_rounded,
                                    color: const Color(0xFF8B5CF6),
                                    isMobile: isMobile,
                                    onTap: () => widget.onNavigate(AppSidebarItem.contracts),
                                  ),
                                  _KpiCard(
                                    title: 'CLIENTES NA CARTEIRA',
                                    value: '${clients.length}',
                                    subtitle: 'Cadastrados pela equipe',
                                    icon: Icons.person_pin_circle_rounded,
                                    color: const Color(0xFFEC4899),
                                    isMobile: isMobile,
                                    onTap: () => widget.onNavigate(AppSidebarItem.clients),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 28),

                              // ── Ranking de Performance da Equipe de Vendas ─
                              _TeamPerformanceRankingCard(
                                users: users,
                                proposals: proposals,
                                products: products,
                                contracts: contracts,
                                currentUser: widget.currentUser,
                                onOpenDossier: (u) {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => UserDossierDialog(
                                      user: u,
                                      currentUser: widget.currentUser,
                                    ),
                                  );
                                },
                              ),

                              const SizedBox(height: 28),

                              // ── Feed de Propostas e Clientes Recentes ──────
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
      },
    );
  }

  String _formatCurrency(double val) {
    if (val >= 1000000) {
      return 'R\$ ${(val / 1000000).toStringAsFixed(2).replaceAll('.', ',')}M';
    }
    if (val >= 1000) {
      return 'R\$ ${(val / 1000).toStringAsFixed(1).replaceAll('.', ',')}k';
    }
    return _currency.format(val);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD DE RANKING & PERFORMANCE DA EQUIPE DE VENDAS
// ─────────────────────────────────────────────────────────────────────────────
class _TeamPerformanceRankingCard extends StatelessWidget {
  final List<UserModel> users;
  final List<ProposalModel> proposals;
  final List<ProductModel> products;
  final List<ContractModel> contracts;
  final UserModel currentUser;
  final void Function(UserModel) onOpenDossier;

  const _TeamPerformanceRankingCard({
    required this.users,
    required this.proposals,
    required this.products,
    required this.contracts,
    required this.currentUser,
    required this.onOpenDossier,
  });

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    // Estrutura de dados agregados por usuário
    final List<_UserSellerStats> statsList = users.map((u) {
      final userProps = proposals.where((p) => p.createdByUserId == u.uid || (p.createdByUserId == null && p.createdByUserName == u.name)).toList();
      final userClosed = userProps.where((p) => p.status == ProposalStatus.closed).toList();
      final userProducts = products.where((p) => p.createdByUserId == u.uid || (p.createdByUserId == null && p.createdByUserName == u.name)).toList();
      final userSolar = userProducts.where((p) => p.sector == ProductSector.solarPlant || p.isSolarPlantKit).toList();
      final userContracts = contracts.where((c) => c.createdByUserId == u.uid || (c.createdByUserId == null && c.createdByUserName == u.name)).toList();

      final totalPropsVal = userProps.fold<double>(0.0, (acc, p) => acc + p.totalAmount);
      final closedVal = userClosed.fold<double>(0.0, (acc, p) => acc + p.totalAmount);
      final totalKwp = userSolar.fold<double>(0.0, (acc, p) => acc + (p.solarKilowatts ?? 0.0));
      final conversion = userProps.isEmpty ? 0.0 : (userClosed.length / userProps.length) * 100;

      return _UserSellerStats(
        user: u,
        proposalsCount: userProps.length,
        proposalsTotalValue: totalPropsVal,
        closedCount: userClosed.length,
        closedTotalValue: closedVal,
        solarPlantsCount: userSolar.length,
        totalKwp: totalKwp,
        contractsCount: userContracts.length,
        conversionRate: conversion,
      );
    }).toList();

    // Ordenar por Faturamento Fechado (ou Total de Propostas)
    statsList.sort((a, b) {
      final cmp = b.closedTotalValue.compareTo(a.closedTotalValue);
      if (cmp != 0) return cmp;
      return b.proposalsTotalValue.compareTo(a.proposalsTotalValue);
    });

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
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
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.emoji_events_rounded, size: 22, color: Color(0xFFD97706)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Desempenho & Ranking da Equipe de Vendas',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Acompanhamento consolidado de propostas, usinas cadastradas, contratos e conversão por operador.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFC7D2FE)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.people_rounded, size: 14, color: Color(0xFF4F46E5)),
                    const SizedBox(width: 6),
                    Text(
                      '${statsList.length} ${statsList.length == 1 ? "vendedor" : "vendedores"}',
                      style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFF4338CA)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (statsList.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'Nenhum usuário cadastrado na equipe.',
                  style: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 800),
                child: DataTable(
                  horizontalMargin: 12,
                  columnSpacing: 20,
                  headingRowHeight: 40,
                  dataRowMinHeight: 52,
                  dataRowMaxHeight: 56,
                  headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                  columns: [
                    DataColumn(label: Text('RANK', style: _headerStyle())),
                    DataColumn(label: Text('VENDEDOR / OPERADOR', style: _headerStyle())),
                    DataColumn(label: Text('PROPOSTAS (R\$)', style: _headerStyle())),
                    DataColumn(label: Text('VENDAS GANHAS', style: _headerStyle())),
                    DataColumn(label: Text('POTÊNCIA', style: _headerStyle())),
                    DataColumn(label: Text('CONTRATOS', style: _headerStyle())),
                    DataColumn(label: Text('CONVERSÃO', style: _headerStyle())),
                    DataColumn(label: Text('IA HOJE', style: _headerStyle())),
                    DataColumn(label: Text('AÇÃO', style: _headerStyle())),
                  ],
                  rows: List.generate(statsList.length, (index) {
                    final s = statsList[index];
                    final rank = index + 1;

                    Widget rankBadge;
                    if (rank == 1) {
                      rankBadge = Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(6)),
                        child: const Text('🥇 1º', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFFB45309))),
                      );
                    } else if (rank == 2) {
                      rankBadge = Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                        child: const Text('🥈 2º', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569))),
                      );
                    } else if (rank == 3) {
                      rankBadge = Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: const Color(0xFFFFEDD5), borderRadius: BorderRadius.circular(6)),
                        child: const Text('🥉 3º', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFFC2410C))),
                      );
                    } else {
                      rankBadge = Text('$rankº', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8)));
                    }

                    return DataRow(
                      cells: [
                        DataCell(rankBadge),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: const Color(0xFFEEF2FF),
                                child: Text(
                                  s.user.name.isNotEmpty ? s.user.name[0].toUpperCase() : 'U',
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 11),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    s.user.name,
                                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12.5, color: const Color(0xFF0F172A)),
                                  ),
                                  Text(
                                    s.user.role.toUpperCase(),
                                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        DataCell(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(currency.format(s.proposalsTotalValue), style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12.5, color: const Color(0xFF0F172A))),
                              Text('${s.proposalsCount} orçamentos', style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B))),
                            ],
                          ),
                        ),
                        DataCell(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(currency.format(s.closedTotalValue), style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12.5, color: const Color(0xFF10B981))),
                              Text('${s.closedCount} ganhas', style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF059669))),
                            ],
                          ),
                        ),
                        DataCell(
                          Text(
                            '${s.totalKwp.toStringAsFixed(1)} kWp',
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: const Color(0xFFD97706)),
                          ),
                        ),
                        DataCell(
                          Text(
                            '${s.contractsCount}',
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: const Color(0xFF6366F1)),
                          ),
                        ),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: s.conversionRate > 0 ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${s.conversionRate.toStringAsFixed(1)}%',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: s.conversionRate > 0 ? const Color(0xFF15803D) : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          AiUsageBadge(user: s.user, compact: true),
                        ),
                        DataCell(
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => onOpenDossier(s.user),
                              borderRadius: BorderRadius.circular(8),
                              child: Ink(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.analytics_outlined, size: 14, color: Color(0xFF6366F1)),
                                    const SizedBox(width: 4),
                                    Text(
                                      'DOSSIÊ',
                                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF4F46E5)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
        ],
      ),
    );
  }

  TextStyle _headerStyle() => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
        color: const Color(0xFF64748B),
      );
}

class _UserSellerStats {
  final UserModel user;
  final int proposalsCount;
  final double proposalsTotalValue;
  final int closedCount;
  final double closedTotalValue;
  final int solarPlantsCount;
  final double totalKwp;
  final int contractsCount;
  final double conversionRate;

  _UserSellerStats({
    required this.user,
    required this.proposalsCount,
    required this.proposalsTotalValue,
    required this.closedCount,
    required this.closedTotalValue,
    required this.solarPlantsCount,
    required this.totalKwp,
    required this.contractsCount,
    required this.conversionRate,
  });
}

