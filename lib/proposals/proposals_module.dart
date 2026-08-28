import 'package:flutter_modular/flutter_modular.dart';
import 'data/repositories/proposal_repository.dart';
import 'presentation/proposals_view.dart';

class ProposalsModule extends Module {
  @override
  final List<Bind> binds = [
    Bind.lazySingleton((i) => ProposalRepository()),
  ];

  @override
  final List<ModularRoute> routes = [
    ChildRoute('/', child: (_, __) => const ProposalsView()),
  ];
}
