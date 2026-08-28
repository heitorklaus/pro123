import 'package:flutter_modular/flutter_modular.dart';
import '../auth/auth_module.dart';
import '../dashboard/dashboard_module.dart';

class AppModule extends Module {
  @override
  List<Bind> get binds => [];

  @override
  List<ModularRoute> get routes => [
        ModuleRoute(Modular.initialRoute, module: AuthModule()),
        ModuleRoute('/auth', module: AuthModule()),
        ModuleRoute('/dashboard', module: DashboardModule()),
      ];
}
