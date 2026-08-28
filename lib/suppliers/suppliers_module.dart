import 'package:flutter_modular/flutter_modular.dart';
import 'data/repositories/supplier_repository.dart';
import 'presentation/suppliers_view.dart';

class SuppliersModule extends Module {
  @override
  List<Bind> get binds => [
        Bind.lazySingleton((i) => SupplierRepository()),
      ];

  @override
  List<ModularRoute> get routes => [
        ChildRoute(Modular.initialRoute, child: (_, __) => const SuppliersView()),
      ];
}
