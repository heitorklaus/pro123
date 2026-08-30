import 'package:flutter_modular/flutter_modular.dart';
import '../auth/auth_module.dart';
import '../dashboard/dashboard_module.dart';
import '../proposals/presentation/web_proposal_page.dart';

class AppModule extends Module {
  @override
  List<Bind> get binds => [];

  @override
  List<ModularRoute> get routes => [
        ModuleRoute(Modular.initialRoute, module: AuthModule()),
        ModuleRoute('/auth', module: AuthModule()),
        ModuleRoute('/dashboard', module: DashboardModule()),
        // Rotas Públicas da Proposta Web (Acesso Livre sem Exigir Login)
        ChildRoute(
          '/proposta/:id',
          child: (context, args) => WebProposalPage(proposalId: args.params['id'] ?? ''),
        ),
        ChildRoute(
          '/p/:id',
          child: (context, args) => WebProposalPage(proposalId: args.params['id'] ?? ''),
        ),
        ChildRoute(
          '/web_proposal/:id',
          child: (context, args) => WebProposalPage(proposalId: args.params['id'] ?? ''),
        ),
      ];
}

