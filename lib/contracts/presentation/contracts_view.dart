import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../auth/domain/models/user_model.dart';
import '../../../clients/domain/models/client_model.dart';
import '../../../proposals/domain/models/proposal_model.dart';
import '../../../settings/data/services/company_service.dart';
import '../../../settings/domain/models/company_model.dart';
import '../data/repositories/contract_repository.dart';
import '../data/services/contract_pdf_service.dart';
import '../domain/models/contract_model.dart';
import 'widgets/contract_proposal_picker_dialog.dart';
import 'widgets/contract_rich_editor.dart';

/// View Principal do Módulo de Contratos integrada ao SPA do DashboardPage
class ContractsView extends StatefulWidget {
  final UserModel? currentUser;

  const ContractsView({super.key, this.currentUser});

  @override
  State<ContractsView> createState() => _ContractsViewState();
}

class _ContractsViewState extends State<ContractsView> {
  late final ContractRepository _contractRepo;
  final TextEditingController _searchCtrl = TextEditingController();

  ContractStatus? _selectedStatusFilter;
  String _searchQuery = '';

  // Estado do Editor WYSIWYG
  bool _isEditing = false;
  ContractModel? _editingContract;
  ProposalModel? _newContractProposal;
  ClientModel? _newContractClient;
  CompanyModel? _currentCompany;

  @override
  void initState() {
    super.initState();
    _contractRepo = Modular.get<ContractRepository>();
    _loadCompanyData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCompanyData() async {
    final companyId = widget.currentUser?.effectiveCompanyId;
    if (companyId != null && companyId.isNotEmpty) {
      try {
        final comp = await CompanyService.getCompany(companyId: companyId);
        if (mounted) {
          setState(() {
            _currentCompany = comp;
          });
        }
      } catch (e) {
        debugPrint('Erro ao carregar dados da empresa para contratos: $e');
      }
    }
  }

  /// Abre o assistente para criar novo contrato a partir de uma proposta
  Future<void> _openNewContractWizard() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ContractProposalPickerDialog(currentUser: widget.currentUser),
    );

    if (result != null && mounted) {
      final proposal = result['proposal'] as ProposalModel;
      final client = result['client'] as ClientModel?;

      setState(() {
        _isEditing = true;
        _editingContract = null;
        _newContractProposal = proposal;
        _newContractClient = client;
      });
    }
  }

  /// Abre um contrato existente para edição no editor WYSIWYG
  void _openEditContract(ContractModel contract) {
    setState(() {
      _isEditing = true;
      _editingContract = contract;
      _newContractProposal = null;
      _newContractClient = null;
    });
  }

  /// Salva o contrato vindo do editor
  Future<void> _handleSaveContract(ContractModel contract) async {
    await _contractRepo.saveContract(contract);
    if (mounted) {
      setState(() {
        _isEditing = false;
        _editingContract = null;
        _newContractProposal = null;
        _newContractClient = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Contrato ${contract.contractNumber} salvo com sucesso!'),
          backgroundColor: const Color(0xFF059669),
        ),
      );
    }
  }

  /// Exclui um contrato com confirmação
  Future<void> _handleDeleteContract(ContractModel contract) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('Excluir Contrato?', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'Deseja realmente excluir o contrato "${contract.contractNumber}" de ${contract.clientName}? Esta ação não pode ser desfeita.',
          style: GoogleFonts.inter(color: const Color(0xFFCBD5E1), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCELAR', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
            child: const Text('EXCLUIR'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _contractRepo.deleteContract(contract.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contrato excluído com sucesso.'), backgroundColor: Color(0xFF0F172A)),
        );
      }
    }
  }

  /// Altera o status do contrato diretamente pela linha da tabela
  Future<void> _handleChangeStatus(ContractModel contract, ContractStatus newStatus) async {
    await _contractRepo.updateStatus(contract.id, newStatus);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Status do contrato ${contract.contractNumber} alterado para "${newStatus.label}".'),
          backgroundColor: const Color(0xFF059669),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing) {
      return ContractRichEditor(
        initialContract: _editingContract,
        proposal: _newContractProposal,
        client: _newContractClient,
        company: _currentCompany,
        currentUser: widget.currentUser,
        onSave: _handleSaveContract,
        onCancel: () => setState(() {
          _isEditing = false;
          _editingContract = null;
          _newContractProposal = null;
          _newContractClient = null;
        }),
      );
    }

    final currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          color: const Color(0xFF0F172A),
          padding: const EdgeInsets.all(24),
          child: StreamBuilder<List<ContractModel>>(
            stream: _contractRepo.getContractsStream(currentUser: widget.currentUser),
            builder: (context, snapshot) {
              final allContracts = snapshot.data ?? [];

              // KPIs
              final totalCount = allContracts.length;
              final totalValue = allContracts.fold<double>(0.0, (sum, c) => sum + c.totalAmount);
              final pendingCount = allContracts.where((c) => c.status == ContractStatus.pendingSignature).length;
              final signedCount = allContracts.where((c) => c.status == ContractStatus.signed).length;

              // Filtragem
              final filtered = allContracts.where((c) {
                if (_selectedStatusFilter != null && c.status != _selectedStatusFilter) {
                  return false;
                }
                final q = _searchQuery.toLowerCase().trim();
                if (q.isEmpty) return true;
                return c.contractNumber.toLowerCase().contains(q) ||
                    c.clientName.toLowerCase().contains(q) ||
                    (c.clientDocument?.contains(q) ?? false) ||
                    c.proposalNumber.toLowerCase().contains(q) ||
                    c.title.toLowerCase().contains(q);
              }).toList();

              final canCreateContracts = widget.currentUser?.canCreateContracts ?? true;
              final canDeleteContracts = widget.currentUser?.canDeleteContracts ?? true;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── CABEÇALHO DO MÓDULO ──────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Contratos de Prestação de Serviços',
                                style: GoogleFonts.outfit(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6366F1).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.5)),
                                ),
                                child: Text(
                                  '$totalCount emitidos',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF818CF8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Gere, edite e imprima contratos jurídicos fotovoltaicos a partir de propostas comerciais',
                            style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
                          ),
                        ],
                      ),

                      // Botão Novo Contrato (se tiver permissão)
                      if (canCreateContracts)
                        ElevatedButton.icon(
                          onPressed: _openNewContractWizard,
                          icon: const Icon(Icons.add_rounded, size: 20),
                          label: Text(
                            'NOVO CONTRATO',
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 4,
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── CARDS DE KPIS RESUMO ─────────────────────────────────
                  Row(
                    children: [
                      _buildKpiCard(
                        title: 'VALOR TOTAL CONTRATADO',
                        value: currency.format(totalValue),
                        icon: Icons.account_balance_wallet_outlined,
                        color: const Color(0xFF10B981),
                      ),
                      const SizedBox(width: 14),
                      _buildKpiCard(
                        title: 'CONTRATOS ASSINADOS',
                        value: '$signedCount',
                        icon: Icons.verified_rounded,
                        color: const Color(0xFF059669),
                      ),
                      const SizedBox(width: 14),
                      _buildKpiCard(
                        title: 'AGUARDANDO ASSINATURA',
                        value: '$pendingCount',
                        icon: Icons.draw_rounded,
                        color: const Color(0xFFF59E0B),
                      ),
                      const SizedBox(width: 14),
                      _buildKpiCard(
                        title: 'TOTAL DE CONTRATOS',
                        value: '$totalCount',
                        icon: Icons.history_edu_rounded,
                        color: const Color(0xFF6366F1),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── BARRA DE PESQUISA E FILTROS ──────────────────────────
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Row(
                      children: [
                        // Campo de Busca
                        Expanded(
                          flex: 4,
                          child: TextField(
                            controller: _searchCtrl,
                            onChanged: (val) => setState(() => _searchQuery = val),
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Buscar por nº do contrato, cliente, CPF ou proposta...',
                              hintStyle: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 13),
                              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 20),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded, color: Color(0xFF94A3B8), size: 18),
                                      onPressed: () {
                                        _searchCtrl.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                    )
                                  : null,
                              filled: true,
                              fillColor: const Color(0xFF0F172A),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Chips de Filtro de Status
                        _buildFilterChip(label: 'Todos', isSelected: _selectedStatusFilter == null, onTap: () => setState(() => _selectedStatusFilter = null)),
                        const SizedBox(width: 6),
                        ...ContractStatus.values.map((st) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: _buildFilterChip(
                              label: st.label,
                              isSelected: _selectedStatusFilter == st,
                              color: st.textColor,
                              onTap: () => setState(() => _selectedStatusFilter = st),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── TABELA DE CONTRATOS EM TEMPO REAL ─────────────────────
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.history_edu_rounded, size: 54, color: const Color(0xFF475569)),
                                  const SizedBox(height: 14),
                                  Text(
                                    'Nenhum contrato encontrado',
                                    style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Clique em "NOVO CONTRATO" para emitir seu primeiro contrato fotovoltaico.',
                                    style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13),
                                  ),
                                ],
                              ),
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.vertical,
                                child: DataTable(
                                  headingRowColor: WidgetStateProperty.all(const Color(0xFF0F172A)),
                                  dataRowColor: WidgetStateProperty.resolveWith((states) {
                                    if (states.contains(WidgetState.hovered)) {
                                      return const Color(0xFF334155).withOpacity(0.5);
                                    }
                                    return Colors.transparent;
                                  }),
                                  columnSpacing: 24,
                                  horizontalMargin: 20,
                                  columns: [
                                    DataColumn(
                                      label: Text(
                                        'CONTRATO',
                                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8)),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'CLIENTE / CONTRATANTE',
                                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8)),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'PROPOSTA',
                                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8)),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'POTÊNCIA',
                                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8)),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'VALOR TOTAL',
                                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8)),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'STATUS',
                                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8)),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'DATA',
                                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8)),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'AÇÕES',
                                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8)),
                                      ),
                                    ),
                                  ],
                                  rows: filtered.map((c) {
                                    return DataRow(
                                      cells: [
                                        // Número do Contrato
                                        DataCell(
                                          Text(
                                            c.contractNumber,
                                            style: GoogleFonts.inter(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: const Color(0xFF818CF8),
                                            ),
                                          ),
                                        ),

                                        // Cliente
                                        DataCell(
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                c.clientName,
                                                style: GoogleFonts.inter(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              if (c.clientDocument != null && c.clientDocument!.isNotEmpty)
                                                Text(
                                                  c.clientDocument!,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 11.5,
                                                    color: const Color(0xFF94A3B8),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),

                                        // Proposta
                                        DataCell(
                                          Text(
                                            c.proposalNumber.isNotEmpty ? c.proposalNumber : '—',
                                            style: GoogleFonts.inter(
                                              fontSize: 12.5,
                                              color: const Color(0xFFCBD5E1),
                                            ),
                                          ),
                                        ),

                                        // Potência
                                        DataCell(
                                          Text(
                                            c.systemKwp > 0 ? '${c.systemKwp.toStringAsFixed(2)} kWp' : '—',
                                            style: GoogleFonts.inter(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12.5,
                                              color: const Color(0xFFF59E0B),
                                            ),
                                          ),
                                        ),

                                        // Valor Total
                                        DataCell(
                                          Text(
                                            currency.format(c.totalAmount),
                                            style: GoogleFonts.outfit(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13.5,
                                              color: const Color(0xFF10B981),
                                            ),
                                          ),
                                        ),

                                        // Status com Popup para troca rápida
                                        DataCell(
                                          PopupMenuButton<ContractStatus>(
                                            tooltip: 'Alterar Status',
                                            color: const Color(0xFF1E293B),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            onSelected: (st) => _handleChangeStatus(c, st),
                                            itemBuilder: (_) => ContractStatus.values.map((st) {
                                              return PopupMenuItem(
                                                value: st,
                                                child: Row(
                                                  children: [
                                                    Icon(st.icon, size: 16, color: st.textColor),
                                                    const SizedBox(width: 8),
                                                    Text(st.label, style: GoogleFonts.inter(color: Colors.white, fontSize: 12.5)),
                                                  ],
                                                ),
                                              );
                                            }).toList(),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: c.status.bgColor,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(c.status.icon, size: 14, color: c.status.textColor),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    c.status.label,
                                                    style: GoogleFonts.inter(
                                                      fontSize: 11.5,
                                                      fontWeight: FontWeight.bold,
                                                      color: c.status.textColor,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Icon(Icons.arrow_drop_down_rounded, size: 14, color: c.status.textColor),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),

                                        // Data
                                        DataCell(
                                          Text(
                                            DateFormat('dd/MM/yyyy').format(c.createdAt),
                                            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                                          ),
                                        ),

                                        // Ações
                                        DataCell(
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.edit_note_rounded, color: Color(0xFF818CF8), size: 20),
                                                tooltip: 'Editar Contrato no Editor Word',
                                                onPressed: () => _openEditContract(c),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.print_outlined, color: Color(0xFF10B981), size: 19),
                                                tooltip: 'Imprimir / Baixar PDF',
                                                onPressed: () => ContractPdfService.printContract(contract: c, company: _currentCompany),
                                              ),
                                              if (canDeleteContracts)
                                                IconButton(
                                                  icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 19),
                                                  tooltip: 'Excluir Contrato',
                                                  onPressed: () => _handleDeleteContract(c),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    Color? color,
    required VoidCallback onTap,
  }) {
    final activeColor = color ?? const Color(0xFF6366F1);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withOpacity(0.2) : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? activeColor : const Color(0xFF334155),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? (color ?? Colors.white) : const Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }
}
