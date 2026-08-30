import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../auth/domain/models/user_model.dart';

enum AppSidebarItem {
  dashboard,
  clients,
  products,
  suppliers,
  proposals,
  users,
  settings,
}

class AppSidebar extends StatelessWidget {
  final AppSidebarItem activeItem;
  final ValueChanged<AppSidebarItem> onItemSelected;
  final bool isCollapsed;
  final VoidCallback? onToggleCollapse;
  final String productsTitle;
  final IconData productsIcon;
  final UserModel? currentUser;

  const AppSidebar({
    super.key,
    required this.activeItem,
    required this.onItemSelected,
    this.isCollapsed = false,
    this.onToggleCollapse,
    this.productsTitle = 'Produtos',
    this.productsIcon = Icons.inventory_2_outlined,
    this.currentUser,
  });

  @override
  Widget build(BuildContext context) {
    final canViewClients = currentUser?.canViewClients ?? true;
    final canViewProducts = currentUser?.canViewProducts ?? true;
    final canViewSuppliers = currentUser?.canViewSuppliers ?? true;
    final canViewProposals = currentUser?.canViewProposals ?? true;
    final canManageUsers = currentUser?.canManageUsers ?? true;
    final canManageSettings = currentUser?.canManageSettings ?? true;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOutCubic,
      width: isCollapsed ? 76 : 250,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(
          right: BorderSide(color: Color(0xFF1E293B), width: 1),
        ),
      ),
      child: Column(
        children: [
          // ── CABEÇALHO DO MENU / BOTÃO DE TOGGLE ────────────────────────────
          Container(
            height: 60,
            padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 12 : 16),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFF1E293B), width: 1),
              ),
            ),
            child: Row(
              mainAxisAlignment: isCollapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.spaceBetween,
              children: [
                if (!isCollapsed)
                  Text(
                    'NAVEGAÇÃO',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onToggleCollapse,
                    borderRadius: BorderRadius.circular(8),
                    hoverColor: const Color(0xFF1E293B),
                    child: Tooltip(
                      message: isCollapsed ? 'Expandir menu lateral' : 'Recolher menu lateral',
                      waitDuration: const Duration(milliseconds: 300),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          isCollapsed
                              ? Icons.keyboard_double_arrow_right_rounded
                              : Icons.keyboard_double_arrow_left_rounded,
                          color: const Color(0xFF94A3B8),
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── LISTA DE ITENS DO MENU ─────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
              children: [
                _SidebarMenuItem(
                  icon: Icons.dashboard_outlined,
                  title: 'Início',
                  isCollapsed: isCollapsed,
                  isSelected: activeItem == AppSidebarItem.dashboard,
                  onTap: () => onItemSelected(AppSidebarItem.dashboard),
                ),
                if (canViewClients) ...[
                  const SizedBox(height: 6),
                  _SidebarMenuItem(
                    icon: Icons.people_alt_rounded,
                    title: 'Clientes',
                    isCollapsed: isCollapsed,
                    isSelected: activeItem == AppSidebarItem.clients,
                    onTap: () => onItemSelected(AppSidebarItem.clients),
                  ),
                ],
                if (canViewProducts) ...[
                  const SizedBox(height: 6),
                  _SidebarMenuItem(
                    icon: productsIcon,
                    title: productsTitle,
                    isCollapsed: isCollapsed,
                    isSelected: activeItem == AppSidebarItem.products,
                    onTap: () => onItemSelected(AppSidebarItem.products),
                  ),
                ],
                if (canViewSuppliers) ...[
                  const SizedBox(height: 6),
                  _SidebarMenuItem(
                    icon: Icons.local_shipping_outlined,
                    title: 'Fornecedores',
                    isCollapsed: isCollapsed,
                    isSelected: activeItem == AppSidebarItem.suppliers,
                    onTap: () => onItemSelected(AppSidebarItem.suppliers),
                  ),
                ],
                if (canViewProposals) ...[
                  const SizedBox(height: 6),
                  _SidebarMenuItem(
                    icon: Icons.description_outlined,
                    title: 'Propostas',
                    isCollapsed: isCollapsed,
                    isSelected: activeItem == AppSidebarItem.proposals,
                    onTap: () => onItemSelected(AppSidebarItem.proposals),
                  ),
                ],
                if (canManageUsers) ...[
                  const SizedBox(height: 6),
                  _SidebarMenuItem(
                    icon: Icons.manage_accounts_rounded,
                    title: 'Usuários',
                    isCollapsed: isCollapsed,
                    isSelected: activeItem == AppSidebarItem.users,
                    onTap: () => onItemSelected(AppSidebarItem.users),
                  ),
                ],
                if (canManageSettings) ...[
                  const SizedBox(height: 6),
                  _SidebarMenuItem(
                    icon: Icons.tune_rounded,
                    title: 'Configurações',
                    isCollapsed: isCollapsed,
                    isSelected: activeItem == AppSidebarItem.settings,
                    onTap: () => onItemSelected(AppSidebarItem.settings),
                  ),
                ],
              ],
            ),
          ),

          // ── RODAPÉ SUTIL DA SIDEBAR ─────────────────────────────────────────
          Container(
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: isCollapsed ? 6 : 14),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0xFF1E293B), width: 1),
              ),
            ),
            child: isCollapsed
                ? Center(
                    child: Tooltip(
                      message: 'Mavis CRM v1.0',
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  )
                : Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Mavis CRM Online',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF64748B),
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
// ITEM INDIVIDUAL DO MENU LATERAL (ADAPTÁVEL: EXPANDIDO / COLAPSADO)
// ─────────────────────────────────────────────────────────────────────────────
class _SidebarMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isSelected;
  final bool isCollapsed;
  final VoidCallback onTap;

  const _SidebarMenuItem({
    required this.icon,
    required this.title,
    required this.isSelected,
    required this.isCollapsed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeBgColor = const Color(0xFF6366F1).withValues(alpha: 0.18);
    final activeBorderColor = const Color(0xFF6366F1).withValues(alpha: 0.45);
    final activeIconColor = const Color(0xFF818CF8);
    final inactiveIconColor = const Color(0xFF94A3B8);

    if (isCollapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Tooltip(
          message: title,
          waitDuration: const Duration(milliseconds: 200),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              hoverColor: const Color(0xFF1E293B),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 48,
                decoration: BoxDecoration(
                  color: isSelected ? activeBgColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: isSelected
                      ? Border.all(color: activeBorderColor, width: 1.2)
                      : null,
                ),
                child: Center(
                  child: Icon(
                    icon,
                    color: isSelected ? activeIconColor : inactiveIconColor,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          hoverColor: const Color(0xFF1E293B),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: isSelected ? activeBgColor : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? Border.all(color: activeBorderColor, width: 1.2)
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected ? activeIconColor : inactiveIconColor,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                    ),
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: Color(0xFF818CF8),
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
