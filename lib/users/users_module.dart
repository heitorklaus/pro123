import 'package:flutter_modular/flutter_modular.dart';
import 'presentation/users_page.dart';

class UsersModule extends Module {
  @override
  List<Bind> get binds => [];

  @override
  List<ModularRoute> get routes => [
        ChildRoute(Modular.initialRoute, child: (_, __) => const UsersPage()),
        ChildRoute('/', child: (_, __) => const UsersPage()),
      ];
}
