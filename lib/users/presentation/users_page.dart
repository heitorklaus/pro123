import 'package:flutter/material.dart';
import '../../app/layout/app_layout.dart';
import '../../app/layout/app_sidebar.dart';
import 'users_view.dart';

class UsersPage extends StatelessWidget {
  const UsersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      activeItem: AppSidebarItem.users,
      child: const UsersView(),
    );
  }
}
