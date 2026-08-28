import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import 'app_sidebar.dart';

class AppLayout extends StatelessWidget {
  final AppSidebarItem activeItem;
  final Widget child;

  const AppLayout({
    super.key,
    required this.activeItem,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
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
          // Menu Lateral Reutilizável
          AppSidebar(
            activeItem: activeItem,
            onItemSelected: (item) {
              if (item == AppSidebarItem.dashboard) {
                Modular.to.navigate('/dashboard/');
              } else if (item == AppSidebarItem.users) {
                Modular.to.navigate('/users/');
              }
            },
          ),

          // Miolo / Conteúdo do Módulo Atual
          Expanded(
            child: child,
          ),
        ],
      ),
    );
  }
}
