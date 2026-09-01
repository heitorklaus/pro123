import 'package:flutter_modular/flutter_modular.dart';
import '../auth/data/repositories/auth_repository.dart';
import '../auth/presentation/register/register_store.dart';
import '../clients/data/repositories/client_repository.dart';
import '../contracts/data/repositories/contract_repository.dart';
import '../products/data/repositories/product_repository.dart';
import '../proposals/data/repositories/proposal_repository.dart';
import '../suppliers/data/repositories/supplier_repository.dart';
import 'presentation/dashboard_page.dart';

class DashboardModule extends Module {
  @override
  List<Bind> get binds => [
        Bind.lazySingleton((i) => AuthRepository()),
        Bind.lazySingleton((i) => RegisterStore(authRepository: i())),
        Bind.lazySingleton((i) => ClientRepository()),
        Bind.lazySingleton((i) => ProductRepository()),
        Bind.lazySingleton((i) => SupplierRepository()),
        Bind.lazySingleton((i) => ProposalRepository()),
        Bind.lazySingleton((i) => ContractRepository()),
      ];

  @override
  List<ModularRoute> get routes => [
        ChildRoute(Modular.initialRoute, child: (_, __) => const DashboardPage()),
      ];
}
