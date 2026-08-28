import 'package:flutter_modular/flutter_modular.dart';
import 'data/repositories/auth_repository.dart';
import 'presentation/login/login_page.dart';
import 'presentation/login/login_store.dart';
import 'presentation/register/register_page.dart';
import 'presentation/register/register_store.dart';

class AuthModule extends Module {
  @override
  List<Bind> get binds => [
        Bind.lazySingleton((i) => AuthRepository()),
        Bind.singleton((i) => LoginStore(authRepository: i())),
        Bind.singleton((i) => RegisterStore(authRepository: i())),
      ];

  @override
  List<ModularRoute> get routes => [
        ChildRoute(Modular.initialRoute, child: (_, __) => const LoginPage()),
        ChildRoute('/login', child: (_, __) => const LoginPage()),
        ChildRoute('/register', child: (_, __) => const RegisterPage()),
      ];
}
