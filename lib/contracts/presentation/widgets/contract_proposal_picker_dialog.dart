import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../auth/domain/models/user_model.dart';
import '../../../clients/data/repositories/client_repository.dart';
import '../../../clients/domain/models/client_model.dart';
import '../../../clients/presentation/widgets/client_form_dialog.dart';
import '../../../proposals/data/repositories/proposal_repository.dart';
import '../../../proposals/domain/models/proposal_model.dart';

/// Diálogo para seleção de Proposta Comercial e Resolução/Cadastro de Cliente para o Contrato
class ContractProposalPickerDialog extends StatefulWidget {
  final UserModel? currentUser;

  const ContractProposalPickerDialog({super.key, this.currentUser});

  @override
  State<ContractProposalPickerDialog> createState() => _ContractProposalPickerDialogState();
}

class _ContractProposalPickerDialogState extends State<ContractProposalPickerDialog> {
  late final ProposalRepository _proposalRepo;
  late final ClientRepository _clientRepo;

  final TextEditingController _searchCtrl = TextEditingController();
  ProposalModel? _selectedProposal;
  ClientModel? _resolvedClient;
  bool _isLoadingClient = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _proposalRepo = Modular.get<ProposalRepository>();
    _clientRepo = Modular.get<ClientRepository>();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSelectProposal(ProposalModel proposal) async {
    setState(() {
      _selectedProposal = proposal;
      _isLoadingClient = true;
      _resolvedClient = null;
    });

    if (proposal.clientId != null && proposal.clientId!.isNotEmpty) {
      try {
        final client = await _clientRepo.getClientById(proposal.clientId!);
        if (mounted) {
          setState(() {
            _resolvedClient = client;
            _isLoadingClient = false;
          });
        }
        return;
      } catch (e) {
        debugPrint('Erro ao buscar cliente da proposta: $e');
      }
    }

    // Se a proposta tiver CPF ou nome gravado, tenta buscar cliente correspondente
    if (proposal.clientDocument != null && proposal.clientDocument!.isNotEmpty) {
      try {
        final cleanDoc = proposal.clientDocument!.replaceAll(RegExp(r'\D'), '');
        final snap = await _clientRepo.getClientsStream(
          companyId: widget.currentUser?.effectiveCompanyId,
          isSuperAdmin: widget.currentUser?.isSuperAdmin == true,
        ).first;
        final match = snap.cast<ClientModel?>().firstWhere(
              (c) => c?.document != null && c!.document!.replaceAll(RegExp(r'\D'), '') == cleanDoc,
              orElse: () => null,
            );
        if (match != null && mounted) {
          setState(() {
            _resolvedClient = match;
            _isLoadingClient = false;
          });
          return;
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _isLoadingClient = false;
      });
    }
  }

  /// Abre diálogo para cadastrar novo cliente
  Future<void> _openCreateNewClient() async {
    final clientToCreate = ClientModel(
      id: '',
      name: _selectedProposal?.clientName ?? '',
      email: _selectedProposal?.clientEmail ?? '',
      phone: _selectedProposal?.clientPhone,
      document: _selectedProposal?.clientDocument,
      type: ClientType.person,
      status: ClientStatus.active,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ClientFormDialog(
        client: clientToCreate,
        onClientSaved: (saved) {
          if (mounted) {
            setState(() {
              _resolvedClient = saved;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ Cliente "${saved.name}" cadastrado e vinculado ao contrato!'),
                backgroundColor: const Color(0xFF059669),
              ),
            );
          }
        },
      ),
    );
  }

  /// Abre diálogo para editar cliente atual
  Future<void> _openEditClient() async {
    if (_resolvedClient == null) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ClientFormDialog(
        client: _resolvedClient,
        onClientSaved: (saved) {
          if (mounted) {
            setState(() {
              _resolvedClient = saved;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ Dados de "${saved.name}" atualizados com sucesso!'),
                backgroundColor: const Color(0xFF059669),
              ),
            );
          }
        },
      ),
    );
  }

  /// Abre diálogo para selecionar um cliente existente da lista
  Future<void> _openSelectExistingClient() async {
    final clients = await _clientRepo.getClientsStream(
      companyId: widget.currentUser?.effectiveCompanyId,
      isSuperAdmin: widget.currentUser?.isSuperAdmin == true,
    ).first;

    if (!mounted) return;

    final selected = await showDialog<ClientModel>(
      context: context,
      builder: (ctx) {
        String filter = '';
        return StatefulBuilder(
          builder: (context, setDlgState) {
            final filtered = clients.where((c) {
              final q = filter.toLowerCase().trim();
              if (q.isEmpty) return true;
              return c.name.toLowerCase().contains(q) ||
                  (c.document?.contains(q) ?? false) ||
                  (c.phone?.contains(q) ?? false);
            }).toList();

            return Dialog(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                width: 520,
                height: 580,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Selecionar Cliente Existente',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      onChanged: (val) => setDlgState(() => filter = val),
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Buscar por nome, CPF/CNPJ ou telefone...',
                        hintStyle: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 13),
                        prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 20),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                'Nenhum cliente encontrado',
                                style: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
                              ),
                            )
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const Divider(color: Color(0xFF334155), height: 1),
                              itemBuilder: (context, index) {
                                final c = filtered[index];
                                return ListTile(
                                  onTap: () => Navigator.pop(ctx, c),
                                  leading: CircleAvatar(
                                    backgroundColor: const Color(0xFF6366F1).withOpacity(0.2),
                                    child: const Icon(Icons.person_rounded, color: Color(0xFF818CF8)),
                                  ),
                                  title: Text(
                                    c.name,
                                    style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13.5),
                                  ),
                                  subtitle: Text(
                                    '${c.document ?? "Sem documento"} • ${c.city ?? "Cidade não inf."}/${c.state ?? ""}',
                                    style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 12),
                                  ),
                                  trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF64748B), size: 14),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (selected != null && mounted) {
      setState(() {
        _resolvedClient = selected;
      });
    }
  }

  bool get _isClientComplete {
    if (_resolvedClient == null) return false;
    final hasDoc = _resolvedClient!.document != null && _resolvedClient!.document!.trim().isNotEmpty;
    final hasStreet = _resolvedClient!.street != null && _resolvedClient!.street!.trim().isNotEmpty;
    return hasDoc && hasStreet;
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Dialog(
      backgroundColor: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 880,
        height: 680,
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── CABEÇALHO DO DIÁLOGO ─────────────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.history_edu_rounded, color: Color(0xFF818CF8), size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Novo Contrato de Prestação de Serviços',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Passo 1: Selecione a Proposta Comercial base para herdar usina, valores e cliente',
                        style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── CONTEÚDO DIVIDIDO EM 2 COLUNAS ──────────────────────────────
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Coluna 1: Lista de Propostas Comerciais
                  Expanded(
                    flex: 5,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SELECIONE UMA PROPOSTA:',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _searchCtrl,
                            onChanged: (val) => setState(() => _searchQuery = val),
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 12.5),
                            decoration: InputDecoration(
                              hintText: 'Buscar proposta por nº ou cliente...',
                              hintStyle: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 12.5),
                              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 18),
                              filled: true,
                              fillColor: const Color(0xFF0F172A),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: StreamBuilder<List<ProposalModel>>(
                              stream: _proposalRepo.getProposalsStream(
                                companyId: widget.currentUser?.effectiveCompanyId,
                                isSuperAdmin: widget.currentUser?.isSuperAdmin == true,
                              ),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const Center(child: CircularProgressIndicator());
                                }

                                final allProposals = snapshot.data ?? [];
                                final filtered = allProposals.where((p) {
                                  final q = _searchQuery.toLowerCase().trim();
                                  if (q.isEmpty) return true;
                                  return p.proposalNumber.toLowerCase().contains(q) ||
                                      p.clientName.toLowerCase().contains(q) ||
                                      (p.clientDocument?.contains(q) ?? false) ||
                                      p.title.toLowerCase().contains(q);
                                }).toList();

                                if (filtered.isEmpty) {
                                  return Center(
                                    child: Text(
                                      'Nenhuma proposta encontrada.',
                                      style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 13),
                                    ),
                                  );
                                }

                                return ListView.separated(
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                                  itemBuilder: (context, index) {
                                    final p = filtered[index];
                                    final isSelected = _selectedProposal?.id == p.id;

                                    return InkWell(
                                      onTap: () => _onSelectProposal(p),
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: isSelected ? const Color(0xFF6366F1).withOpacity(0.15) : const Color(0xFF0F172A),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: isSelected ? const Color(0xFF6366F1) : const Color(0xFF334155),
                                            width: isSelected ? 1.5 : 1,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  p.proposalNumber,
                                                  style: GoogleFonts.inter(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12.5,
                                                    color: isSelected ? const Color(0xFF818CF8) : const Color(0xFFE2E8F0),
                                                  ),
                                                ),
                                                Text(
                                                  currency.format(p.totalAmount),
                                                  style: GoogleFonts.outfit(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13.5,
                                                    color: const Color(0xFF10B981),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              p.clientName.isNotEmpty ? p.clientName : 'Cliente não associado',
                                              style: GoogleFonts.inter(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              p.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.inter(
                                                fontSize: 11.5,
                                                color: const Color(0xFF94A3B8),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),

                  // Coluna 2: Detalhes da Proposta e Resolução de Cliente
                  Expanded(
                    flex: 5,
                    child: _selectedProposal == null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.arrow_back_rounded, color: Color(0xFF64748B), size: 36),
                                const SizedBox(height: 10),
                                Text(
                                  'Selecione uma proposta ao lado para visualizar os dados e avançar.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 13),
                                ),
                              ],
                            ),
                          )
                        : SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Card Resumo da Usina / Proposta
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E293B),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: const Color(0xFF334155)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'DADOS DA PROPOSTA',
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1.1,
                                              color: const Color(0xFF94A3B8),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: _selectedProposal!.status.bgColor,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              _selectedProposal!.status.label,
                                              style: GoogleFonts.inter(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: _selectedProposal!.status.textColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        _selectedProposal!.title,
                                        style: GoogleFonts.inter(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          const Icon(Icons.payments_outlined, color: Color(0xFF10B981), size: 16),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Total do Projeto: ${currency.format(_selectedProposal!.totalAmount)}',
                                            style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFFE2E8F0)),
                                          ),
                                        ],
                                      ),
                                      if (_selectedProposal!.paymentTerms.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(Icons.credit_card_rounded, color: Color(0xFF6366F1), size: 16),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                'Condições: ${_selectedProposal!.paymentTerms}',
                                                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Card de Resolução e Verificação de Cliente
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E293B),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: _isClientComplete ? const Color(0xFF059669) : const Color(0xFFD97706),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            _isClientComplete ? Icons.verified_user_rounded : Icons.warning_amber_rounded,
                                            color: _isClientComplete ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'QUALIFICAÇÃO DO CONTRATANTE (CLIENTE)',
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1.1,
                                              color: _isClientComplete ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),

                                      if (_isLoadingClient)
                                        const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
                                      else if (_resolvedClient == null) ...[
                                        Text(
                                          '⚠️ Esta proposta não possui um cliente completo associado na base.',
                                          style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFFCBD5E1)),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Para emitir o contrato oficial com validade jurídica, selecione um cliente cadastrado ou adicione um novo agora.',
                                          style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF94A3B8)),
                                        ),
                                        const SizedBox(height: 14),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: OutlinedButton.icon(
                                                onPressed: _openSelectExistingClient,
                                                icon: const Icon(Icons.people_outline_rounded, size: 16),
                                                label: const Text('VINCULAR EXISTENTE', style: TextStyle(fontSize: 11.5)),
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: Colors.white,
                                                  side: const BorderSide(color: Color(0xFF6366F1)),
                                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: ElevatedButton.icon(
                                                onPressed: _openCreateNewClient,
                                                icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                                                label: const Text('+ NOVO CLIENTE', style: TextStyle(fontSize: 11.5)),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFF6366F1),
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ] else ...[
                                        // Cliente Selecionado / Resolvido
                                        Text(
                                          _resolvedClient!.name,
                                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${_resolvedClient!.type == ClientType.company ? "CNPJ" : "CPF"}: ${_resolvedClient!.document ?? "Não informado"}',
                                          style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFFE2E8F0)),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Endereço: ${_resolvedClient!.street ?? ""}${_resolvedClient!.addressNumber != null ? ", ${_resolvedClient!.addressNumber}" : ""} - ${_resolvedClient!.city ?? ""}/${_resolvedClient!.state ?? ""}',
                                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            TextButton.icon(
                                              onPressed: _openEditClient,
                                              icon: const Icon(Icons.edit_outlined, size: 16),
                                              label: const Text('Completar / Editar Dados'),
                                              style: TextButton.styleFrom(foregroundColor: const Color(0xFF818CF8)),
                                            ),
                                            const Spacer(),
                                            TextButton(
                                              onPressed: _openSelectExistingClient,
                                              child: const Text('Trocar Cliente', style: TextStyle(color: Color(0xFF94A3B8))),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── RODAPÉ DE AÇÕES ──────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('CANCELAR', style: GoogleFonts.inter(color: const Color(0xFF94A3B8))),
                ),
                const SizedBox(width: 14),
                ElevatedButton.icon(
                  onPressed: _selectedProposal == null
                      ? null
                      : () {
                          Navigator.pop(context, {
                            'proposal': _selectedProposal,
                            'client': _resolvedClient,
                          });
                        },
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: Text('AVANÇAR PARA O EDITOR WYSIWYG', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFF334155),
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
