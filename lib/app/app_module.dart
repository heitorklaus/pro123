import 'package:flutter_modular/flutter_modular.dart';
import '../auth/auth_module.dart';
import '../dashboard/dashboard_module.dart';
import '../products/presentation/automation_web_proposal_page.dart';
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
        // Rotas Públicas da Proposta Web de Automação Residencial (_blank)
        ChildRoute(
          '/automacao-proposta/:id',
          child: (context, args) => AutomationWebProposalPage(studyId: args.params['id'] ?? ''),
        ),
        ChildRoute(
          '/preview-automacao',
          child: (context, args) => const AutomationWebProposalPage(studyId: 'preview'),
        ),
      ];
}

