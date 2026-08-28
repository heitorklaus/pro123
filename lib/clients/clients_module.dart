import 'package:flutter_modular/flutter_modular.dart';
import 'data/repositories/client_repository.dart';

class ClientsModule extends Module {
  @override
  List<Bind> get binds => [
        Bind.lazySingleton((i) => ClientRepository()),
      ];

  @override
  List<ModularRoute> get routes => [];
}
