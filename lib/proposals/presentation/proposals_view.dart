import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../app/theme/app_colors.dart';
import '../../auth/data/repositories/auth_repository.dart';
import '../../clients/data/repositories/client_repository.dart';
import '../../clients/domain/models/client_model.dart';
import '../data/repositories/proposal_repository.dart';
import '../domain/models/proposal_item_model.dart';
import '../domain/models/proposal_model.dart';
import '../../products/domain/models/category_model.dart';
import '../../products/domain/models/product_model.dart';
import '../../products/presentation/solar_plant_form_card.dart';
import '../../clients/presentation/widgets/client_form_dialog.dart';
import 'widgets/proposal_client_autocomplete.dart';
import 'widgets/proposal_pdf_preview_dialog.dart';
import 'widgets/proposal_product_picker_dialog.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ENTRY POINT: Inserido diretamente no miolo do DashboardPage (SPA Container)
// ─────────────────────────────────────────────────────────────────────────────
class ProposalsView extends StatefulWidget {
  final ProposalItemModel? initialItem;
  final VoidCallback? onClearInitialItem;

  const ProposalsView({
    super.key,
    this.initialItem,
    this.onClearInitialItem,
  });

  @override
  State<ProposalsView> createState() => _ProposalsViewState();
}

class _ProposalsViewState extends State<ProposalsView> {
  bool _isCreatingOrEditing = false;
  ProposalModel? _proposalToEdit;
  ProposalItemModel? _activeInitialItem;

  @override
  void initState() {
    super.initState();
    if (widget.initialItem != null) {
      _isCreatingOrEditing = true;
      _proposalToEdit = null;
      _activeInitialItem = widget.initialItem;
    }
  }

  @override
  void didUpdateWidget(covariant ProposalsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialItem != null &&
        widget.initialItem != oldWidget.initialItem) {
      setState(() {
        _isCreatingOrEditing = true;
        _proposalToEdit = null;
        _activeInitialItem = widget.initialItem;
      });
    }
  }

  void _openCreateForm() {
    setState(() {
      _proposalToEdit = null;
      _activeInitialItem = null;
      _isCreatingOrEditing = true;
    });
  }

  void _openEditForm(ProposalModel proposal) {
    setState(() {
      _proposalToEdit = proposal;
      _activeInitialItem = null;
      _isCreatingOrEditing = true;
    });
  }

  void _closeForm() {
    setState(() {
      _proposalToEdit = null;
      _activeInitialItem = null;
      _isCreatingOrEditing = false;
    });
    widget.onClearInitialItem?.call();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: _isCreatingOrEditing
              ? _ProposalFormCard(
                  proposal: _proposalToEdit,
                  initialItem: _activeInitialItem,
                  onCancel: _closeForm,
                  onSaved: _closeForm,
                )
              : _ProposalTableView(
                  onAddNew: _openCreateForm,
                  onEdit: _openEditForm,
                ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TABELA DE PROPOSTAS COMERCIAIS EM TEMPO REAL
// ─────────────────────────────────────────────────────────────────────────────
class _ProposalTableView extends StatefulWidget {
  final VoidCallback onAddNew;
  final ValueChanged<ProposalModel> onEdit;

  const _ProposalTableView({
    required this.onAddNew,
    required this.onEdit,
  });

  @override
  State<_ProposalTableView> createState() => _ProposalTableViewState();
}

class _ProposalTableViewState extends State<_ProposalTableView> {
  late final ProposalRepository _repo;
  final _searchCtrl = TextEditingController();
  String _query = '';
  ProposalStatus? _filterStatus;
  String? _companyId;

  @override
  void initState() {
    super.initState();
    try {
      _repo = Modular.get<ProposalRepository>();
    } catch (_) {
      _repo = ProposalRepository();
    }
    _loadCompanyId();
  }

  Future<void> _loadCompanyId() async {
    try {
      AuthRepository auth;
      try {
        auth = Modular.get<AuthRepository>();
      } catch (_) {
        auth = AuthRepository();
      }
      final cid = await auth.getCurrentCompanyId();
      if (mounted) setState(() => _companyId = cid);
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showPdfPreview(ProposalModel proposal) {
    showDialog(
      context: context,
      builder: (ctx) => ProposalPdfPreviewDialog(proposal: proposal),
    );
  }

  void _confirmDelete(ProposalModel proposal) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Color(0xFFEF4444), size: 24),
            const SizedBox(width: 8),
            Text('Excluir Proposta',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Deseja excluir a proposta "${proposal.proposalNumber} - ${proposal.clientName}"?\nEssa ação não poderá ser desfeita.',
          style:
              GoogleFonts.inter(fontSize: 14, color: const Color(0xFF475569)),
        ),
        actions: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.pop(ctx),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Text('CANCELAR',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B))),
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                Navigator.pop(ctx);
                await _repo.deleteProposal(proposal.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Proposta excluída com sucesso!'),
                    backgroundColor: Color(0xFF10B981),
                    behavior: SnackBarBehavior.floating,
                  ));
                }
              },
              borderRadius: BorderRadius.circular(10),
              child: Ink(
                decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(10)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Text('EXCLUIR',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _changeStatus(ProposalModel proposal, ProposalStatus newStatus) async {
    await _repo.updateStatus(proposal.id, newStatus);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Status da proposta alterado para "${newStatus.label}"'),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Cabeçalho Principal ──────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Propostas Comerciais & Orçamentos',
                    style: GoogleFonts.outfit(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Emissão inteligente de orçamentos com múltiplos itens e geração de PDF profissional',
                    style: GoogleFonts.inter(
                        fontSize: 14, color: const Color(0xFF64748B)),
                  ),
                ],
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onAddNew,
                  borderRadius: BorderRadius.circular(12),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.note_add_rounded,
                            size: 18, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          'NOVA PROPOSTA',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Barra de Busca & Filtros ─────────────────────────────────────
          Row(
            children: [
              // Campo de busca
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) =>
                      setState(() => _query = v.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText:
                        'Buscar por número da proposta, cliente ou título...',
                    hintStyle: GoogleFonts.inter(
                        fontSize: 13, color: const Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: Color(0xFF64748B), size: 20),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.border)),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Filtro por Status
              Expanded(
                flex: 2,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<ProposalStatus?>(
                      value: _filterStatus,
                      hint: Text('Todos os Status',
                          style: GoogleFonts.inter(
                              fontSize: 13, color: const Color(0xFF64748B))),
                      isExpanded: true,
                      icon: const Icon(Icons.filter_list_rounded,
                          size: 18, color: Color(0xFF64748B)),
                      items: [
                        DropdownMenuItem<ProposalStatus?>(
                          value: null,
                          child: Text('Todos os Status',
                              style: GoogleFonts.inter(
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                        ...ProposalStatus.values
                            .map((s) => DropdownMenuItem<ProposalStatus?>(
                                  value: s,
                                  child: Text(s.label,
                                      style: GoogleFonts.inter(fontSize: 13)),
                                )),
                      ],
                      onChanged: (val) => setState(() => _filterStatus = val),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Conteúdo da Tabela ───────────────────────────────────────────
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  children: [
                    _ProposalTableHeader(),
                    const Divider(height: 1, color: AppColors.divider),
                    Expanded(
                      child: StreamBuilder<List<ProposalModel>>(
                        stream: _repo.getProposalsStream(companyId: _companyId),
                        builder: (ctx, snap) {
                          if (_companyId == null ||
                              snap.connectionState == ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator(
                                    color: AppColors.primary));
                          }
                          if (snap.hasError) {
                            return Center(
                              child: Text(
                                  'Erro ao carregar propostas:\n${snap.error}',
                                  textAlign: TextAlign.center),
                            );
                          }

                          final all = snap.data ?? [];
                          final filtered = all.where((p) {
                            final matchesQuery = _query.isEmpty ||
                                p.proposalNumber
                                    .toLowerCase()
                                    .contains(_query) ||
                                p.clientName.toLowerCase().contains(_query) ||
                                p.title.toLowerCase().contains(_query);

                            final matchesStatus = _filterStatus == null ||
                                p.status == _filterStatus;
                            return matchesQuery && matchesStatus;
                          }).toList();

                          if (filtered.isEmpty) {
                            return _ProposalEmptyState(
                              isEmpty: all.isEmpty,
                              onAdd: widget.onAddNew,
                            );
                          }

                          return ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const Divider(
                                height: 1, color: AppColors.divider),
                            itemBuilder: (_, i) {
                              final proposal = filtered[i];
                              return _ProposalRow(
                                proposal: proposal,
                                onPreviewPdf: () => _showPdfPreview(proposal),
                                onEdit: () => widget.onEdit(proposal),
                                onDelete: () => _confirmDelete(proposal),
                                onStatusChange: (s) =>
                                    _changeStatus(proposal, s),
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
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CABEÇALHO DA TABELA DE PROPOSTAS
// ─────────────────────────────────────────────────────────────────────────────
class _ProposalTableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      color: const Color(0xFFF8FAFC),
      child: Row(
        children: [
          _col('PROPOSTA & CLIENTE', flex: 4),
          _col('VALOR TOTAL', flex: 2),
          _col('CONDIÇÃO / VALIDADE', flex: 3),
          _col('STATUS', flex: 2),
          const SizedBox(width: 160), // Coluna de Ações
        ],
      ),
    );
  }

  Widget _col(String label, {required int flex}) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontWeight: FontWeight.bold,
          fontSize: 11,
          color: const Color(0xFF64748B),
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LINHA DA PROPOSTA NA TABELA
// ─────────────────────────────────────────────────────────────────────────────
class _ProposalRow extends StatelessWidget {
  final ProposalModel proposal;
  final VoidCallback onPreviewPdf;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<ProposalStatus> onStatusChange;

  const _ProposalRow({
    required this.proposal,
    required this.onPreviewPdf,
    required this.onEdit,
    required this.onDelete,
    required this.onStatusChange,
  });

  @override
  Widget build(BuildContext context) {
    final themeColor = Color(proposal.themeColorValue);
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          // 1. Proposta & Cliente
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: themeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: themeColor.withValues(alpha: 0.3)),
                  ),
                  child: Center(
                    child: Icon(Icons.description_outlined,
                        color: themeColor, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              proposal.proposalNumber,
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF334155),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              proposal.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0F172A),
                                  fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Cliente: ${proposal.clientName}${proposal.isClientLinked ? ' (Cadastrado)' : ' (Avulso)'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                            fontSize: 11.5, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. Valor Total & Quantidade de Itens
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'R\$ ${proposal.totalAmount.toStringAsFixed(2).replaceAll('.', ',')}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF059669),
                  ),
                ),
                Text(
                  '${proposal.items.length} ${proposal.items.length == 1 ? 'item' : 'itens'}',
                  style: GoogleFonts.inter(
                      fontSize: 11, color: const Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),

          // 3. Condição & Validade
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  proposal.paymentTerms,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF334155)),
                ),
                Text(
                  'Validade: ${dateFormat.format(proposal.expirationDate)} (${proposal.validityDays}d)',
                  style: GoogleFonts.inter(
                      fontSize: 11, color: const Color(0xFF64748B)),
                ),
              ],
            ),
          ),

          // 4. Status
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: proposal.status.bgColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  proposal.status.label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: proposal.status.textColor,
                  ),
                ),
              ),
            ),
          ),

          // 5. Ações (PDF, Editar, Mudar Status, Excluir)
          SizedBox(
            width: 160,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Visualizar / Baixar PDF',
                  icon: const Icon(Icons.picture_as_pdf_outlined,
                      color: Color(0xFFDC2626), size: 18),
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  visualDensity: VisualDensity.compact,
                  onPressed: onPreviewPdf,
                ),
                IconButton(
                  tooltip: 'Editar Proposta',
                  icon: const Icon(Icons.edit_outlined,
                      color: Color(0xFF6366F1), size: 18),
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  visualDensity: VisualDensity.compact,
                  onPressed: onEdit,
                ),
                PopupMenuButton<ProposalStatus>(
                  tooltip: 'Alterar Status',
                  icon: const Icon(Icons.swap_horiz_rounded,
                      color: Color(0xFF64748B), size: 19),
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onSelected: onStatusChange,
                  itemBuilder: (ctx) => ProposalStatus.values.map((s) {
                    return PopupMenuItem(
                      value: s,
                      child: Row(
                        children: [
                          Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                  color: s.textColor, shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Text(s.label,
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: const Color(0xFF0F172A))),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                IconButton(
                  tooltip: 'Excluir',
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: Color(0xFFEF4444), size: 18),
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  visualDensity: VisualDensity.compact,
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProposalEmptyState extends StatelessWidget {
  final bool isEmpty;
  final VoidCallback onAdd;

  const _ProposalEmptyState({required this.isEmpty, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
                color: Color(0xFFEEF2FF), shape: BoxShape.circle),
            child: const Icon(Icons.description_outlined,
                color: AppColors.primary, size: 40),
          ),
          const SizedBox(height: 16),
          Text(
            isEmpty
                ? 'Nenhuma proposta emitida ainda'
                : 'Nenhuma proposta encontrada',
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: const Color(0xFF1E293B)),
          ),
          const SizedBox(height: 6),
          Text(
            isEmpty
                ? 'Crie orçamentos profissionais e gere documentos PDF para seus clientes.'
                : 'Tente buscar por outro termo ou status.',
            style:
                GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 13),
          ),
          if (isEmpty) ...[
            const SizedBox(height: 20),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onAdd,
                borderRadius: BorderRadius.circular(12),
                child: Ink(
                  decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(12)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.note_add_rounded,
                          size: 18, color: Colors.white),
                      const SizedBox(width: 8),
                      Text('Criar Primeira Proposta',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FORMULÁRIO DINÂMICO & INTELIGENTE DE PROPOSTAS COMERCIAIS
// ─────────────────────────────────────────────────────────────────────────────
class _ProposalFormCard extends StatefulWidget {
  final ProposalModel? proposal;
  final ProposalItemModel? initialItem;
  final VoidCallback onCancel;
  final VoidCallback onSaved;

  const _ProposalFormCard({
    this.proposal,
    this.initialItem,
    required this.onCancel,
    required this.onSaved,
  });

  @override
  State<_ProposalFormCard> createState() => _ProposalFormCardState();
}

class _ProposalFormCardState extends State<_ProposalFormCard> {
  late final ProposalRepository _proposalRepo;
  late final ClientRepository _clientRepo;

  // Controllers de Cabeçalho & Cliente
  final _titleCtrl =
      TextEditingController(text: 'Proposta Comercial de Fornecimento');
  final _clientNameCtrl = TextEditingController();
  final _clientEmailCtrl = TextEditingController();
  final _clientPhoneCtrl = TextEditingController();
  final _clientDocCtrl = TextEditingController();
  final _clientAddrCtrl = TextEditingController();

  bool _isClientLinked = true;
  String? _selectedClientId;

  // Lista de Itens da Proposta
  final List<ProposalItemModel> _items = [];

  // Condições Comerciais & Financeiras
  final _paymentTermsCtrl =
      TextEditingController(text: 'À vista via PIX (5% desc) ou Boleto 30DD');
  final _validityDaysCtrl = TextEditingController(text: '15');
  final _deliveryTimeCtrl =
      TextEditingController(text: 'Imediata / 3 a 5 dias úteis');
  final _discountCtrl = TextEditingController(text: '0');
  final _shippingCtrl = TextEditingController(text: '0');
  final _notesCtrl = TextEditingController();

  // Tema de Cor do PDF
  int _themeColorValue = 0xFF4F46E5;

  bool _isLoading = false;
  String? _errorMessage;
  String? _companyId;

  bool get _isEditing => widget.proposal != null;

  @override
  void initState() {
    super.initState();
    try {
      _proposalRepo = Modular.get<ProposalRepository>();
    } catch (_) {
      _proposalRepo = ProposalRepository();
    }
    try {
      _clientRepo = Modular.get<ClientRepository>();
    } catch (_) {
      _clientRepo = ClientRepository();
    }
    _loadCompanyId();

    if (_isEditing) {
      final p = widget.proposal!;
      _titleCtrl.text = p.title;
      _isClientLinked = p.isClientLinked;
      _selectedClientId = p.clientId;
      _clientNameCtrl.text = p.clientName;
      _clientEmailCtrl.text = p.clientEmail ?? '';
      _clientPhoneCtrl.text = p.clientPhone ?? '';
      _clientDocCtrl.text = p.clientDocument ?? '';
      _clientAddrCtrl.text = p.clientAddress ?? '';
      _items.addAll(p.items);
      _paymentTermsCtrl.text = p.paymentTerms;
      _validityDaysCtrl.text = p.validityDays.toString();
      _deliveryTimeCtrl.text = p.deliveryTime ?? '';
      _discountCtrl.text = p.discount.toStringAsFixed(2);
      _shippingCtrl.text = p.shippingFee.toStringAsFixed(2);
      _notesCtrl.text = p.notes ?? '';
      _themeColorValue = p.themeColorValue;
    } else if (widget.initialItem != null) {
      _items.add(widget.initialItem!);
      if (widget.initialItem!.isSolarPlant) {
        _titleCtrl.text = 'Proposta Comercial - ${widget.initialItem!.name}';
      }
    }
  }

  Future<void> _loadCompanyId() async {
    try {
      AuthRepository auth;
      try {
        auth = Modular.get<AuthRepository>();
      } catch (_) {
        auth = AuthRepository();
      }
      final cid = await auth.getCurrentCompanyId();
      if (mounted) setState(() => _companyId = cid);
    } catch (_) {}
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _clientNameCtrl.dispose();
    _clientEmailCtrl.dispose();
    _clientPhoneCtrl.dispose();
    _clientDocCtrl.dispose();
    _clientAddrCtrl.dispose();
    _paymentTermsCtrl.dispose();
    _validityDaysCtrl.dispose();
    _deliveryTimeCtrl.dispose();
    _discountCtrl.dispose();
    _shippingCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  // Cálculos Financeiros Dinâmicos
  double get _subtotal =>
      _items.fold(0.0, (acc, item) => acc + item.totalPrice);
  double get _discount =>
      double.tryParse(_discountCtrl.text.replaceAll(',', '.')) ?? 0.0;
  double get _shipping =>
      double.tryParse(_shippingCtrl.text.replaceAll(',', '.')) ?? 0.0;
  double get _totalAmount =>
      (_subtotal - _discount + _shipping).clamp(0.0, double.infinity);

  void _onClientSelected(ClientModel client) {
    setState(() {
      _selectedClientId = client.id;
      _clientNameCtrl.text = client.name;
      _clientEmailCtrl.text = client.email;
      _clientPhoneCtrl.text = client.phone ?? '';
      _clientDocCtrl.text = client.document ?? '';
      
      final addrParts = <String>[];
      if (client.street != null && client.street!.isNotEmpty) {
        addrParts.add(client.street!);
      }
      if (client.addressNumber != null && client.addressNumber!.isNotEmpty) {
        addrParts.add('nº ${client.addressNumber!}');
      }
      if (client.neighborhood != null && client.neighborhood!.isNotEmpty) {
        addrParts.add(client.neighborhood!);
      }
      if (client.city != null && client.city!.isNotEmpty) {
        addrParts.add('${client.city!}${client.state != null ? "/${client.state}" : ""}');
      }
      _clientAddrCtrl.text = addrParts.join(', ');
    });
  }

  void _openNewClientDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ClientFormDialog(
        onClientSaved: (newClient) {
          _onClientSelected(newClient);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cliente "${newClient.name}" cadastrado e selecionado com sucesso!'),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }

  void _openProductPicker() {
    showDialog(
      context: context,
      builder: (ctx) => ProposalProductPickerDialog(
        onItemSelected: (newItem) {
          setState(() {
            _items.add(newItem);
          });
        },
      ),
    );
  }

  void _openSolarPlantDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 1080,
            maxHeight: MediaQuery.of(context).size.height * 0.92,
          ),
          child: SingleChildScrollView(
            child: SolarPlantFormCard(
              category: CategoryModel.fromSector(ProductSector.solarPlant),
              product: null,
              onBack: () => Navigator.pop(dialogCtx),
              onSuccess: () => Navigator.pop(dialogCtx),
              customProceedDescription:
                  'Deseja adicionar esta Usina Solar à sua proposta comercial atual?',
              customProceedActionLabel: 'ADICIONAR À PROPOSTA',
              onProceedToProposal: (solarItem) {
                Navigator.pop(dialogCtx);
                setState(() {
                  _items.add(solarItem);
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Usina "${solarItem.name}" adicionada à proposta com sucesso!'),
                    backgroundColor: const Color(0xFF10B981),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _updateItemQuantity(int index, double newQty) {
    if (newQty <= 0) return;
    setState(() {
      final item = _items[index];
      _items[index] = item.copyWith(quantity: newQty);
    });
  }

  void _updateItemPrice(int index, double newPrice) {
    if (newPrice < 0) return;
    setState(() {
      final item = _items[index];
      _items[index] = item.copyWith(unitPrice: newPrice);
    });
  }

  void _updateItemDiscount(int index, double newDiscountPct) {
    setState(() {
      final item = _items[index];
      _items[index] = item.copyWith(discountPercent: newDiscountPct);
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  ProposalModel _buildCurrentProposalModel() {
    final title = _titleCtrl.text.trim();
    final clientName = _clientNameCtrl.text.trim().isNotEmpty
        ? _clientNameCtrl.text.trim()
        : (_isClientLinked ? 'Cliente Selecionado' : 'Consumidor Final');

    final validity = int.tryParse(_validityDaysCtrl.text) ?? 15;

    return ProposalModel(
      id: widget.proposal?.id ?? 'preview_id',
      proposalNumber: widget.proposal?.proposalNumber ?? 'PROP-2026-PREVIEW',
      title: title.isNotEmpty ? title : 'Proposta Comercial',
      clientId: _isClientLinked ? _selectedClientId : null,
      clientName: clientName,
      clientEmail: _clientEmailCtrl.text.trim(),
      clientPhone: _clientPhoneCtrl.text.trim(),
      clientDocument: _clientDocCtrl.text.trim(),
      clientAddress: _clientAddrCtrl.text.trim(),
      items: _items,
      subtotal: _subtotal,
      discount: _discount,
      shippingFee: _shipping,
      totalAmount: _totalAmount,
      paymentTerms: _paymentTermsCtrl.text.trim(),
      validityDays: validity,
      deliveryTime: _deliveryTimeCtrl.text.trim(),
      notes: _notesCtrl.text.trim(),
      themeColorValue: _themeColorValue,
      status: widget.proposal?.status ?? ProposalStatus.draft,
      createdAt: widget.proposal?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  void _previewPdf() {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Adicione pelo menos um produto ou serviço à proposta.'),
        backgroundColor: Color(0xFFEF4444),
      ));
      return;
    }

    final proposal = _buildCurrentProposalModel();
    showDialog(
      context: context,
      builder: (ctx) => ProposalPdfPreviewDialog(proposal: proposal),
    );
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    final clientName = _clientNameCtrl.text.trim();

    if (title.isEmpty) {
      setState(() => _errorMessage = 'Informe o título da proposta.');
      return;
    }

    if (!_isClientLinked && clientName.isEmpty) {
      setState(
          () => _errorMessage = 'Informe o nome do cliente / destinatário.');
      return;
    }

    if (_isClientLinked && _selectedClientId == null && clientName.isEmpty) {
      setState(() => _errorMessage =
          'Selecione um cliente cadastrado ou preencha o nome.');
      return;
    }

    if (_items.isEmpty) {
      setState(() =>
          _errorMessage = 'Adicione ao menos um produto ou item à proposta.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final validity = int.tryParse(_validityDaysCtrl.text) ?? 15;

      if (_isEditing) {
        final updated = widget.proposal!.copyWith(
          title: title,
          clientId: _isClientLinked ? _selectedClientId : null,
          clientName: clientName.isNotEmpty ? clientName : 'Consumidor Final',
          clientEmail: _clientEmailCtrl.text.trim(),
          clientPhone: _clientPhoneCtrl.text.trim(),
          clientDocument: _clientDocCtrl.text.trim(),
          clientAddress: _clientAddrCtrl.text.trim(),
          items: _items,
          subtotal: _subtotal,
          discount: _discount,
          shippingFee: _shipping,
          totalAmount: _totalAmount,
          paymentTerms: _paymentTermsCtrl.text.trim(),
          validityDays: validity,
          deliveryTime: _deliveryTimeCtrl.text.trim(),
          notes: _notesCtrl.text.trim(),
          themeColorValue: _themeColorValue,
        );
        await _proposalRepo.updateProposal(updated);
      } else {
        await _proposalRepo.createProposal(
          title: title,
          clientId: _isClientLinked ? _selectedClientId : null,
          clientName: clientName.isNotEmpty ? clientName : 'Consumidor Final',
          clientEmail: _clientEmailCtrl.text.trim(),
          clientPhone: _clientPhoneCtrl.text.trim(),
          clientDocument: _clientDocCtrl.text.trim(),
          clientAddress: _clientAddrCtrl.text.trim(),
          items: _items,
          subtotal: _subtotal,
          discount: _discount,
          shippingFee: _shipping,
          totalAmount: _totalAmount,
          paymentTerms: _paymentTermsCtrl.text.trim(),
          validityDays: validity,
          deliveryTime: _deliveryTimeCtrl.text.trim(),
          notes: _notesCtrl.text.trim(),
          themeColorValue: _themeColorValue,
          companyId: _companyId,
        );
      }

      if (mounted) {
        widget.onSaved();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isEditing
              ? 'Proposta atualizada com sucesso!'
              : 'Proposta cadastrada com sucesso!'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Erro ao salvar proposta: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat =
        NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1040),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Cabeçalho do Formulário ────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.note_add_rounded,
                            color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isEditing
                                ? 'Editar Proposta Comercial'
                                : 'Cadastrar Nova Proposta Comercial',
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'Preencha os dados do cliente, itens do orçamento e gere o PDF executivo',
                            style: GoogleFonts.inter(
                                fontSize: 13, color: const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: widget.onCancel,
                      borderRadius: BorderRadius.circular(10),
                      child: Ink(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.arrow_back_rounded,
                                size: 18, color: Color(0xFF64748B)),
                            const SizedBox(width: 8),
                            Text(
                              'Voltar à Tabela',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
              const Divider(color: AppColors.divider),
              const SizedBox(height: 16),

              if (_errorMessage != null) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: Color(0xFFEF4444), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: GoogleFonts.inter(
                              color: const Color(0xFF991B1B),
                              fontSize: 13,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── SEÇÃO 1: IDENTIFICAÇÃO & DESTINATÁRIO ──────────────────────
              _sectionHeader(
                  Icons.business_center_rounded,
                  'Identificação & Cliente',
                  'Vincule a um cliente cadastrado ou emita para cliente avulso'),
              const SizedBox(height: 14),

              // Título da Proposta
              _label('Título / Objeto da Proposta *'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  hintText:
                      'Ex: Fornecimento de Materiais de Limpeza, Prestação de Serviços de TI...',
                  prefixIcon:
                      Icon(Icons.title_rounded, color: Color(0xFF64748B)),
                ),
              ),
              const SizedBox(height: 14),

              // Switch Cliente Cadastrado vs Avulso
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _isClientLinked = true),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: _isClientLinked
                              ? AppColors.primary.withValues(alpha: 0.08)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _isClientLinked
                                ? AppColors.primary
                                : AppColors.border,
                            width: _isClientLinked ? 1.8 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isClientLinked
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              color: _isClientLinked
                                  ? AppColors.primary
                                  : const Color(0xFF94A3B8),
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Vincular a Cliente Cadastrado',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: _isClientLinked
                                          ? AppColors.primary
                                          : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  Text(
                                    'Carrega dados cadastrais automaticamente',
                                    style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: const Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _isClientLinked = false),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: !_isClientLinked
                              ? AppColors.primary.withValues(alpha: 0.08)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: !_isClientLinked
                                ? AppColors.primary
                                : AppColors.border,
                            width: !_isClientLinked ? 1.8 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              !_isClientLinked
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              color: !_isClientLinked
                                  ? AppColors.primary
                                  : const Color(0xFF94A3B8),
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Proposta sem Cliente / Consumidor Avulso',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: !_isClientLinked
                                          ? AppColors.primary
                                          : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  Text(
                                    'Emita rapidamente digitando dados avulsos',
                                    style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: const Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              if (_isClientLinked) ...[
                // Autocomplete Inteligente de Clientes Cadastrados
                _label('Selecione ou Busque o Cliente Cadastrado *'),
                const SizedBox(height: 6),
                StreamBuilder<List<ClientModel>>(
                  stream: _clientRepo.getClientsStream(companyId: _companyId),
                  builder: (ctx, snap) {
                    final clients = snap.data ?? [];
                    return ProposalClientAutocomplete(
                      clients: clients,
                      selectedClientId: _selectedClientId,
                      initialClientName: _clientNameCtrl.text,
                      onClientSelected: _onClientSelected,
                      onClearClient: () {
                        setState(() {
                          _selectedClientId = null;
                          _clientNameCtrl.clear();
                          _clientEmailCtrl.clear();
                          _clientPhoneCtrl.clear();
                          _clientDocCtrl.clear();
                          _clientAddrCtrl.clear();
                        });
                      },
                      onAddNewClient: _openNewClientDialog,
                    );
                  },
                ),
                const SizedBox(height: 14),
              ],

              // Dados do Cliente (Nome, E-mail, Telefone, Doc, Endereço)
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Nome do Cliente / Empresa *'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _clientNameCtrl,
                          decoration: const InputDecoration(
                            hintText: 'Ex: Supermercados Estrela Ltda',
                            prefixIcon: Icon(Icons.person_outline,
                                color: Color(0xFF64748B)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('CPF ou CNPJ'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _clientDocCtrl,
                          decoration: const InputDecoration(
                            hintText: '00.000.000/0001-00',
                            prefixIcon: Icon(Icons.badge_outlined,
                                color: Color(0xFF64748B)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('E-mail para Envio'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _clientEmailCtrl,
                          decoration: const InputDecoration(
                            hintText: 'contato@cliente.com.br',
                            prefixIcon: Icon(Icons.email_outlined,
                                color: Color(0xFF64748B)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Telefone / WhatsApp'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _clientPhoneCtrl,
                          decoration: const InputDecoration(
                            hintText: '(11) 98765-4321',
                            prefixIcon: Icon(Icons.phone_outlined,
                                color: Color(0xFF64748B)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // ── SEÇÃO 2: ITENS DA PROPOSTA ─────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _sectionHeader(
                      Icons.inventory_2_outlined,
                      'Itens & Produtos da Proposta',
                      'Adicione quantos produtos do catálogo desejar ou crie sob medida'),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Botão Criar Usina Solar
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _openSolarPlantDialog,
                          borderRadius: BorderRadius.circular(10),
                          child: Ink(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFF59E0B), Color(0xFFEA580C)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFEA580C)
                                      .withValues(alpha: 0.25),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.solar_power_rounded,
                                    color: Colors.white, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  'MONTAR USINA SOLAR',
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Botão Adicionar Item / Produto
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _openProductPicker,
                          borderRadius: BorderRadius.circular(10),
                          child: Ink(
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.add_shopping_cart_rounded,
                                    color: Colors.white, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  'ADICIONAR USINA EXISTENTE / PRODUTO',
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Tabela Dinâmica de Itens
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    children: [
                      // Cabeçalho da Tabela de Itens
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        color: const Color(0xFFF8FAFC),
                        child: Row(
                          children: [
                            const SizedBox(
                                width: 28,
                                child: Text('#',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                        color: Color(0xFF64748B)))),
                            const Expanded(
                                flex: 5,
                                child: Text('ITEM / DESCRIÇÃO',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                        color: Color(0xFF64748B)))),
                            const SizedBox(
                                width: 70,
                                child: Center(
                                    child: Text('QTD',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                            color: Color(0xFF64748B))))),
                            const SizedBox(
                                width: 45,
                                child: Center(
                                    child: Text('UNID',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                            color: Color(0xFF64748B))))),
                            const SizedBox(
                                width: 110,
                                child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Text('UNITÁRIO (R\$)',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                            color: Color(0xFF64748B))))),
                            const SizedBox(
                                width: 80,
                                child: Center(
                                    child: Text('DESC %',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                            color: Color(0xFF64748B))))),
                            const SizedBox(
                                width: 110,
                                child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Text('TOTAL (R\$)',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                            color: Color(0xFF64748B))))),
                            const SizedBox(width: 45), // Botão de Remover
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: AppColors.divider),

                      if (_items.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              const Icon(Icons.add_shopping_cart_rounded,
                                  size: 36, color: Color(0xFF94A3B8)),
                              const SizedBox(height: 8),
                              Text('Nenhum item adicionado à proposta',
                                  style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF64748B))),
                              const SizedBox(height: 4),
                              Text(
                                  'Clique no botão acima para escolher itens do catálogo ou sob medida.',
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: const Color(0xFF94A3B8))),
                            ],
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _items.length,
                          separatorBuilder: (_, __) => const Divider(
                              height: 1, color: AppColors.divider),
                          itemBuilder: (ctx, idx) {
                            final item = _items[idx];
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 28,
                                    child: Text('${idx + 1}',
                                        style: GoogleFonts.inter(
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF64748B),
                                            fontSize: 12)),
                                  ),
                                  // Descrição
                                  Expanded(
                                    flex: 5,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (item.isSolarPlant) ...[
                                          Row(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 7,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xFFFEF3C7),
                                                  borderRadius:
                                                      BorderRadius.circular(5),
                                                  border: Border.all(
                                                      color: const Color(
                                                          0xFFFCD34D)),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: const [
                                                    Icon(
                                                        Icons
                                                            .solar_power_rounded,
                                                        size: 13,
                                                        color:
                                                            Color(0xFFD97706)),
                                                    SizedBox(width: 4),
                                                    Text(
                                                      'USINA SOLAR FOTOVOLTAICA',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color:
                                                            Color(0xFF92400E),
                                                        letterSpacing: 0.3,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              if (item.solarKilowatts != null &&
                                                  item.solarKilowatts! > 0) ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        const Color(0xFFF1F5F9),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            5),
                                                  ),
                                                  child: Text(
                                                    '${item.solarKilowatts!.toStringAsFixed(1)} kWp',
                                                    style: GoogleFonts.inter(
                                                        fontSize: 10.5,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: const Color(
                                                            0xFF334155)),
                                                  ),
                                                ),
                                              ],
                                              if (item.solarRoofType != null &&
                                                  item.solarRoofType!
                                                      .isNotEmpty) ...[
                                                const SizedBox(width: 6),
                                                Text(
                                                  '|  Telhado ${item.solarRoofType}',
                                                  style: GoogleFonts.inter(
                                                      fontSize: 11,
                                                      color: const Color(
                                                          0xFF64748B),
                                                      fontWeight:
                                                          FontWeight.w500),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                        ],
                                        Text(
                                          item.name,
                                          style: GoogleFonts.inter(
                                            fontWeight: item.isSolarPlant
                                                ? FontWeight.bold
                                                : FontWeight.w600,
                                            fontSize:
                                                item.isSolarPlant ? 13.5 : 13,
                                            color: const Color(0xFF0F172A),
                                          ),
                                        ),
                                        if (item.sku != null &&
                                            item.sku!.isNotEmpty)
                                          Text('SKU: ${item.sku}',
                                              style: GoogleFonts.inter(
                                                  fontSize: 11,
                                                  color:
                                                      const Color(0xFF64748B))),

                                        // Lista dos equipamentos/produtos inclusos na Usina Solar
                                        if (item.isSolarPlant &&
                                            item.solarComponents != null &&
                                            item.solarComponents!
                                                .isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFFFBEB),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                  color:
                                                      const Color(0xFFFDE68A)),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: const [
                                                    Icon(
                                                        Icons
                                                            .inventory_2_outlined,
                                                        size: 13,
                                                        color:
                                                            Color(0xFFD97706)),
                                                    SizedBox(width: 5),
                                                    Text(
                                                      'Composição do Conjunto da Usina:',
                                                      style: TextStyle(
                                                          fontSize: 10.5,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Color(
                                                              0xFF92400E)),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                ...item.solarComponents!.map(
                                                  (comp) => Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            left: 2, bottom: 3),
                                                    child: Row(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .center,
                                                      children: [
                                                        const Icon(
                                                            Icons
                                                                .check_circle_outline_rounded,
                                                            size: 12,
                                                            color: Color(
                                                                0xFFD97706)),
                                                        const SizedBox(
                                                            width: 6),
                                                        Expanded(
                                                          child: Text(
                                                            comp,
                                                            style: GoogleFonts.inter(
                                                                fontSize: 11.5,
                                                                color: const Color(
                                                                    0xFF451A03),
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  // Quantidade
                                  SizedBox(
                                    width: 70,
                                    child: TextFormField(
                                      initialValue: item.quantity % 1 == 0
                                          ? item.quantity.toInt().toString()
                                          : item.quantity.toString(),
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.inter(fontSize: 12.5),
                                      decoration: const InputDecoration(
                                          contentPadding: EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 8)),
                                      onChanged: (val) {
                                        final q = double.tryParse(
                                                val.replaceAll(',', '.')) ??
                                            1.0;
                                        _updateItemQuantity(idx, q);
                                      },
                                    ),
                                  ),
                                  // Unidade
                                  SizedBox(
                                    width: 45,
                                    child: Center(
                                      child: Text(item.unit,
                                          style: GoogleFonts.inter(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              color: const Color(0xFF64748B))),
                                    ),
                                  ),
                                  // Preço Unitário
                                  SizedBox(
                                    width: 110,
                                    child: TextFormField(
                                      initialValue:
                                          item.unitPrice.toStringAsFixed(2),
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      textAlign: TextAlign.right,
                                      style: GoogleFonts.inter(fontSize: 12.5),
                                      decoration: const InputDecoration(
                                          contentPadding: EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 8)),
                                      onChanged: (val) {
                                        final p = double.tryParse(
                                                val.replaceAll(',', '.')) ??
                                            0.0;
                                        _updateItemPrice(idx, p);
                                      },
                                    ),
                                  ),
                                  // Desconto (%)
                                  SizedBox(
                                    width: 80,
                                    child: TextFormField(
                                      initialValue: item.discountPercent
                                          .toStringAsFixed(0),
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.inter(fontSize: 12.5),
                                      decoration: const InputDecoration(
                                          contentPadding: EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 8),
                                          suffixText: '%'),
                                      onChanged: (val) {
                                        final d = double.tryParse(
                                                val.replaceAll(',', '.')) ??
                                            0.0;
                                        _updateItemDiscount(idx, d);
                                      },
                                    ),
                                  ),
                                  // Total do Item
                                  SizedBox(
                                    width: 110,
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        currencyFormat.format(item.totalPrice),
                                        style: GoogleFonts.inter(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: const Color(0xFF0F172A)),
                                      ),
                                    ),
                                  ),
                                  // Ação Remover
                                  SizedBox(
                                    width: 45,
                                    child: IconButton(
                                      tooltip: 'Remover Item',
                                      icon: const Icon(
                                          Icons.delete_outline_rounded,
                                          color: Color(0xFFEF4444),
                                          size: 18),
                                      onPressed: () => _removeItem(idx),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // ── SEÇÃO 3: CONDIÇÕES COMERCIAIS & FINANCEIRO ─────────────────
              _sectionHeader(
                  Icons.payments_outlined,
                  'Condições Comerciais & Pagamento',
                  'Defina os termos de pagamento, prazos de entrega e validade'),
              const SizedBox(height: 14),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Coluna Esquerda: Formas de Pagamento & Prazos
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Forma / Condição de Pagamento *'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _paymentTermsCtrl,
                          decoration: const InputDecoration(
                            hintText:
                                'Ex: À vista via PIX com 5% de desconto, Boleto 30/60DD...',
                            prefixIcon: Icon(Icons.credit_card_rounded,
                                color: Color(0xFF64748B)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _label('Validade da Proposta (Dias)'),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _validityDaysCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      hintText: '15',
                                      prefixIcon: Icon(
                                          Icons.event_available_rounded,
                                          color: Color(0xFF64748B)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _label('Prazo de Entrega'),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _deliveryTimeCtrl,
                                    decoration: const InputDecoration(
                                      hintText:
                                          'Ex: Imediata ou 3 a 5 dias úteis',
                                      prefixIcon: Icon(
                                          Icons.local_shipping_outlined,
                                          color: Color(0xFF64748B)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _label('Observações & Termos Gerais da Proposta'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _notesCtrl,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            hintText:
                                'Ex: Frete CIF incluso para Grande SP. Garantia de 90 dias contra defeitos de fabricação.',
                            prefixIcon: Icon(Icons.notes_rounded,
                                color: Color(0xFF64748B)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 24),

                  // Coluna Direita: Quadro Financeiro com Resumo
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'RESUMO FINANCEIRO',
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF475569),
                                letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 12),

                          _financeRow('Subtotal dos Itens:',
                              currencyFormat.format(_subtotal)),
                          const SizedBox(height: 8),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Desconto Geral (R\$):',
                                  style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: const Color(0xFF64748B))),
                              SizedBox(
                                width: 100,
                                child: TextFormField(
                                  controller: _discountCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  textAlign: TextAlign.right,
                                  style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF059669)),
                                  decoration: const InputDecoration(
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 6)),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Frete / Entrega (R\$):',
                                  style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: const Color(0xFF64748B))),
                              SizedBox(
                                width: 100,
                                child: TextFormField(
                                  controller: _shippingCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  textAlign: TextAlign.right,
                                  style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold),
                                  decoration: const InputDecoration(
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 6)),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(color: AppColors.divider),
                          const SizedBox(height: 8),

                          // Card de Total Geral em Destaque
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.25),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('TOTAL DA PROPOSTA',
                                    style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white70)),
                                const SizedBox(height: 2),
                                Text(
                                  currencyFormat.format(_totalAmount),
                                  style: GoogleFonts.outfit(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // ── SEÇÃO 4: PERSONALIZAÇÃO DE CORES DO PDF ───────────────────
              _sectionHeader(Icons.palette_outlined, 'Padrão Visual do PDF',
                  'Escolha a cor do tema para o cabeçalho e destaques do documento'),
              const SizedBox(height: 12),

              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: ProposalPdfThemeOption.allThemes.map((t) {
                  final isSelected = t.primaryColorValue == _themeColorValue;
                  return InkWell(
                    onTap: () =>
                        setState(() => _themeColorValue = t.primaryColorValue),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? t.primaryColor.withValues(alpha: 0.1)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? t.primaryColor : AppColors.border,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: t.primaryColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            t.label,
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: isSelected
                                  ? t.primaryColor
                                  : const Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 32),
              const Divider(color: AppColors.divider),
              const SizedBox(height: 20),

              // ── BOTÕES DE AÇÃO NO RODAPÉ ───────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: widget.onCancel,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 12),
                        child: Text(
                          'CANCELAR',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF64748B)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Botão Pré-visualizar PDF
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _previewPdf,
                      borderRadius: BorderRadius.circular(12),
                      child: Ink(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFF0F172A), width: 1.2),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 13),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.picture_as_pdf_outlined,
                                size: 18, color: Color(0xFF0F172A)),
                            const SizedBox(width: 8),
                            Text(
                              'PRÉ-VISUALIZAR PDF',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Botão Salvar e Gerar Proposta
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _isLoading ? null : _submit,
                      borderRadius: BorderRadius.circular(12),
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 28, vertical: 14),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_circle_outline_rounded,
                                      color: Colors.white, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    _isEditing
                                        ? 'SALVAR ALTERAÇÕES'
                                        : 'SALVAR E GERAR PROPOSTA',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A))),
            Text(subtitle,
                style: GoogleFonts.inter(
                    fontSize: 12, color: const Color(0xFF64748B))),
          ],
        ),
      ],
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF334155)),
    );
  }

  Widget _financeRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 13, color: const Color(0xFF64748B))),
        Text(value,
            style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A))),
      ],
    );
  }
}
