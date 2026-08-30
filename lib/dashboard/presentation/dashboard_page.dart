import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app/layout/app_sidebar.dart';
import '../../app/theme/app_colors.dart';
import '../../auth/data/repositories/auth_repository.dart';
import '../../auth/domain/models/user_model.dart';
import '../../clients/presentation/clients_view.dart';
import '../../products/domain/models/product_model.dart';
import '../../products/presentation/products_view.dart';
import '../../proposals/domain/models/proposal_item_model.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkFirstLoginOnboarding());
  }

  void _listenCurrentUser() {
    _userSub = _authRepo.getCurrentUserStream().listen((user) {
      if (mounted) {
        setState(() {
          _currentUser = user;
        });
      }
    });
  }

  @override
  void dispose() {
    _userSub?.cancel();
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
    final productsIcon = isSolar ? Icons.solar_power_rounded : Icons.inventory_2_outlined;

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
                : (_isSidebarCollapsed ? 'Expandir Menu Lateral' : 'Recolher Menu Lateral'),
            icon: Icon(
              isMobile
                  ? Icons.menu_rounded
                  : (_isSidebarCollapsed ? Icons.menu_rounded : Icons.menu_open_rounded),
              color: Colors.white,
              size: 22,
            ),
            onPressed: isMobile ? () => Scaffold.of(appBarCtx).openDrawer() : _toggleSidebar,
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.grid_view_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Mavis CRM',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: isMobile ? 18 : 20,
              ),
            ),
          ],
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
    final canViewClients = _currentUser?.canViewClients ?? true;
    final canViewProducts = _currentUser?.canViewProducts ?? true;
    final canViewSuppliers = _currentUser?.canViewSuppliers ?? true;
    final canViewProposals = _currentUser?.canViewProposals ?? true;
    final canManageUsers = _currentUser?.canManageUsers ?? true;
    final canManageSettings = _currentUser?.canManageSettings ?? true;

    switch (_activeItem) {
      case AppSidebarItem.dashboard:
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
        return const UsersView();
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
            'Boas-vindas ao Mavis CRM!',
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
