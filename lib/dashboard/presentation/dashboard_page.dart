import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app/layout/app_sidebar.dart';
import '../../app/theme/app_colors.dart';
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
  AppSidebarItem _activeItem = AppSidebarItem.dashboard;
  bool _isSidebarCollapsed = false;
  ProposalItemModel? _pendingProposalItem;
  ProductSector? _preferredSector;

  @override
  void initState() {
    super.initState();
    _loadPreferredSector();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkFirstLoginOnboarding());
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          tooltip: _isSidebarCollapsed ? 'Expandir Menu Lateral' : 'Recolher Menu Lateral',
          icon: Icon(
            _isSidebarCollapsed ? Icons.menu_rounded : Icons.menu_open_rounded,
            color: Colors.white,
            size: 22,
          ),
          onPressed: _toggleSidebar,
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
                fontSize: 20,
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
          const SizedBox(width: 16),
        ],
      ),
      body: Row(
        children: [
          // Sidebar / Menu Lateral com troca dinâmica de módulo e recolhimento suave
          Builder(builder: (context) {
            final isSolar = _preferredSector == ProductSector.solarPlant;
            final productsTitle = isSolar ? 'Usinas Solares' : 'Produtos';
            final productsIcon = isSolar ? Icons.solar_power_rounded : Icons.inventory_2_outlined;

            return AppSidebar(
              activeItem: _activeItem,
              isCollapsed: _isSidebarCollapsed,
              onToggleCollapse: _toggleSidebar,
              productsTitle: productsTitle,
              productsIcon: productsIcon,
              onItemSelected: (item) {
                setState(() {
                  _activeItem = item;
                });
              },
            );
          }),

          // Miolo Central Dinâmico — LayoutBuilder garante bounds finitos
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
    switch (_activeItem) {
      case AppSidebarItem.dashboard:
        return const Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(32.0),
            child: _WelcomeCard(),
          ),
        );
      case AppSidebarItem.clients:
        return const ClientsView();
      case AppSidebarItem.products:
        return ProductsView(
          onProceedToProposal: _navigateToProposalWithItem,
        );
      case AppSidebarItem.suppliers:
        return const SuppliersView();
      case AppSidebarItem.proposals:
        return ProposalsView(
          initialItem: _pendingProposalItem,
          onClearInitialItem: () => setState(() => _pendingProposalItem = null),
        );
      case AppSidebarItem.users:
        return const UsersView();
      case AppSidebarItem.settings:
        return SettingsView(onSectorChanged: _loadPreferredSector);
    }
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 600),
      padding: const EdgeInsets.all(40.0),
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
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFFEEF2FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.waving_hand_rounded,
              color: AppColors.primary,
              size: 48,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Boas-vindas ao Mavis CRM!',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Você está autenticado no painel principal. Utilize o menu lateral para navegar entre as seções do sistema.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 16,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  'Sistema Online & Conectado',
                  style: GoogleFonts.inter(
                    fontSize: 14,
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
