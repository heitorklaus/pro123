import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/theme/app_colors.dart';
import '../../auth/data/repositories/auth_repository.dart';
import '../../auth/domain/models/user_model.dart';
import '../../clients/data/repositories/client_repository.dart';
import '../../clients/domain/models/client_model.dart';
import '../data/repositories/proposal_repository.dart';
import '../data/services/gemini_proposal_assistant_service.dart';
import '../domain/models/proposal_item_model.dart';
import '../domain/models/proposal_model.dart';
import '../../products/domain/models/category_model.dart';
import '../../products/domain/models/product_model.dart';
import '../../products/presentation/solar_plant_form_card.dart';
import '../../clients/presentation/widgets/client_form_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'web_proposal_page.dart';
import 'widgets/proposal_ai_assistant_dialog.dart';
import 'widgets/proposal_client_autocomplete.dart';
import 'widgets/proposal_pdf_preview_dialog.dart';
import 'widgets/proposal_product_picker_dialog.dart';
import 'widgets/proposal_kanban_view.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ENTRY POINT: Inserido diretamente no miolo do DashboardPage (SPA Container)
// ─────────────────────────────────────────────────────────────────────────────
class ProposalsView extends StatefulWidget {
  final UserModel? currentUser;
  final ProposalItemModel? initialItem;
  final VoidCallback? onClearInitialItem;

  const ProposalsView({
    super.key,
    this.currentUser,
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
  ClientModel? _aiLinkedClient;
  ParsedUnifiedProposal? _aiParsedProposal;

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
      _aiLinkedClient = null;
      _aiParsedProposal = null;
      _isCreatingOrEditing = true;
    });
  }

  void _openCreateFromAi(ParsedUnifiedProposal parsed, ClientModel? linkedClient, ProposalItemModel solarItem) {
    setState(() {
      _proposalToEdit = null;
      _activeInitialItem = solarItem;
      _aiLinkedClient = linkedClient;
      _aiParsedProposal = parsed;
      _isCreatingOrEditing = true;
    });
  }

  void _openEditForm(ProposalModel proposal) {
    setState(() {
      _proposalToEdit = proposal;
      _activeInitialItem = null;
      _aiLinkedClient = null;
      _aiParsedProposal = null;
      _isCreatingOrEditing = true;
    });
  }

  void _closeForm() {
    setState(() {
      _proposalToEdit = null;
      _activeInitialItem = null;
      _aiLinkedClient = null;
      _aiParsedProposal = null;
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
                  currentUser: widget.currentUser,
                  proposal: _proposalToEdit,
                  initialItem: _activeInitialItem,
                  initialClient: _aiLinkedClient,
                  initialParsedProposal: _aiParsedProposal,
                  onCancel: _closeForm,
                  onSaved: _closeForm,
                )
              : _ProposalTableView(
                  currentUser: widget.currentUser,
                  onAddNew: _openCreateForm,
                  onAiCreate: _openCreateFromAi,
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
  final UserModel? currentUser;
  final VoidCallback onAddNew;
  final Function(ParsedUnifiedProposal, ClientModel?, ProposalItemModel) onAiCreate;
  final ValueChanged<ProposalModel> onEdit;

  const _ProposalTableView({
    this.currentUser,
    required this.onAddNew,
    required this.onAiCreate,
    required this.onEdit,
  });

  @override
  State<_ProposalTableView> createState() => _ProposalTableViewState();
}

class _ProposalTableViewState extends State<_ProposalTableView> {
  static const _kanbanModeKey = 'mavis_proposals_kanban_view_mode';

  late final ProposalRepository _repo;
  late final AuthRepository _authRepo;
  StreamSubscription<UserModel?>? _userSub;
  StreamSubscription<List<UserModel>>? _sellersSub;
  final _searchCtrl = TextEditingController();
  String _query = '';
  ProposalStatus? _filterStatus;
  String? _filterSellerId;
  List<UserModel> _sellersList = [];
  String? _companyId;
  UserModel? _currentUser;
  bool _isKanbanMode = false;

  @override
  void initState() {
    super.initState();
    try {
      _repo = Modular.get<ProposalRepository>();
    } catch (_) {
      _repo = ProposalRepository();
    }
    try {
      _authRepo = Modular.get<AuthRepository>();
    } catch (_) {
      _authRepo = AuthRepository();
    }
    _currentUser = widget.currentUser;
    _userSub = _authRepo.getCurrentUserStream().listen((user) {
      if (mounted) {
        setState(() {
          _currentUser = user;
          _companyId = user?.effectiveCompanyId ?? _companyId;
        });
        _listenSellers();
      }
    });
    _loadCompanyId();
    _loadKanbanPreference();
  }

  void _listenSellers() {
    _sellersSub?.cancel();
    final isSuper = widget.currentUser?.isSuperAdmin ?? _currentUser?.isSuperAdmin ?? false;
    final cid = _companyId ?? widget.currentUser?.effectiveCompanyId;
    _sellersSub = _authRepo.getUsersStream(
      companyId: cid,
      isSuperAdmin: isSuper,
    ).listen((users) {
      if (mounted) {
        setState(() => _sellersList = users);
      }
    });
  }

  void _openAiAssistantDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ProposalAiAssistantDialog(
        onProposalReady: (parsed, linkedClient, solarItem) {
          widget.onAiCreate(parsed, linkedClient, solarItem);
        },
      ),
    );
  }

  Future<void> _loadKanbanPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool(_kanbanModeKey);
      if (saved != null && mounted) {
        setState(() => _isKanbanMode = saved);
      }
    } catch (_) {}
  }

  void _setKanbanMode(bool isKanban) async {
    setState(() => _isKanbanMode = isKanban);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kanbanModeKey, isKanban);
    } catch (_) {}
  }

  Future<void> _loadCompanyId() async {
    try {
      final user = await _authRepo.getCurrentUser();
      final cid = user?.effectiveCompanyId ?? await _authRepo.getCurrentCompanyId();
      if (mounted) {
        setState(() {
          _currentUser = user;
          _companyId = cid;
        });
        _listenSellers();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _userSub?.cancel();
    _sellersSub?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showPdfPreview(ProposalModel proposal) {
    showDialog(
      context: context,
      builder: (ctx) => ProposalPdfPreviewDialog(proposal: proposal),
    );
  }

  void _showWebPreview(ProposalModel proposal) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            width: 1200,
            height: 900,
            child: WebProposalPage(
              proposalId: proposal.id,
              initialProposal: proposal,
            ),
          ),
        ),
      ),
    );
  }

  void _copyWebLink(ProposalModel proposal) {
    final baseUri = Uri.base.origin;
    final link = '$baseUri/#/proposta/${proposal.id}';
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text('Link copiado para a área de transferência:\n$link')),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _shareOnWhatsApp(ProposalModel proposal) async {
    final baseUri = Uri.base.origin;
    final link = '$baseUri/#/proposta/${proposal.id}';
    final phone = proposal.clientPhone?.replaceAll(RegExp(r'\D'), '') ?? '';
    final text = Uri.encodeComponent(
      'Olá ${proposal.clientName}! Segue o link da sua proposta comercial de energia solar ${proposal.proposalNumber}:\n\n$link\n\nAbra o link para conferir a simulação completa da usina e opções de financiamento.',
    );
    final url = Uri.parse('https://wa.me/${phone.isNotEmpty ? "55$phone" : ""}?text=$text');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
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
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Proposta "${proposal.proposalNumber}" movida para "${newStatus.label}"',
                style: GoogleFonts.inter(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ));
    }
  }

  Widget _buildViewModeToggle(bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _viewModeButton(
            label: isMobile ? '' : 'Tabela',
            icon: Icons.table_rows_rounded,
            isSelected: !_isKanbanMode,
            onTap: () => _setKanbanMode(false),
          ),
          const SizedBox(width: 2),
          _viewModeButton(
            label: isMobile ? '' : 'Kanban',
            icon: Icons.view_kanban_rounded,
            isSelected: _isKanbanMode,
            onTap: () => _setKanbanMode(true),
          ),
        ],
      ),
    );
  }

  Widget _viewModeButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(
            horizontal: label.isNotEmpty ? 12 : 8,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? AppColors.primary : const Color(0xFF64748B),
              ),
              if (label.isNotEmpty) ...[
                const SizedBox(width: 6),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? AppColors.primary : const Color(0xFF64748B),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.all(isMobile ? 14 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Cabeçalho Principal ──────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isMobile ? 'Propostas Comerciais' : 'Propostas Comerciais & Orçamentos',
                      style: GoogleFonts.outfit(
                          fontSize: isMobile ? 20 : 26,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Emissão inteligente de orçamentos, PDF e funil Kanban',
                      style: GoogleFonts.inter(
                          fontSize: isMobile ? 12 : 14,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Toggle Switcher Modo Tabela / Modo Kanban
                  _buildViewModeToggle(isMobile),

                  // Botão CRIAR COM IA & Botão NOVA PROPOSTA (Apenas se tiver permissão)
                  if (widget.currentUser?.canCreateProposals ?? _currentUser?.canCreateProposals ?? false) ...[
                    const SizedBox(width: 10),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _openAiAssistantDialog,
                        borderRadius: BorderRadius.circular(12),
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          padding: EdgeInsets.symmetric(
                              horizontal: isMobile ? 12 : 18, vertical: isMobile ? 10 : 12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.auto_awesome_rounded,
                                  size: 18, color: Colors.white),
                              const SizedBox(width: 6),
                              Text(
                                isMobile ? 'IA' : 'CRIAR COM IA',
                                style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontSize: isMobile ? 12 : 13,
                                    letterSpacing: 0.5),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
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
                          padding: EdgeInsets.symmetric(
                              horizontal: isMobile ? 14 : 20, vertical: isMobile ? 10 : 12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.note_add_rounded,
                                  size: 18, color: Colors.white),
                              const SizedBox(width: 6),
                              Text(
                                isMobile ? 'NOVA' : 'NOVA PROPOSTA',
                                style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontSize: isMobile ? 12 : 13,
                                    letterSpacing: 0.5),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ── Barra de Busca & Filtros ─────────────────────────────────────
          if (isMobile) ...[
            TextField(
              controller: _searchCtrl,
              onChanged: (v) =>
                  setState(() => _query = v.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Buscar por proposta, cliente...',
                hintStyle: GoogleFonts.inter(
                    fontSize: 12.5, color: const Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: Color(0xFF64748B), size: 18),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border)),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (!_isKanbanMode)
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<ProposalStatus?>(
                          dropdownColor: isDark ? AppColors.darkSurface : Colors.white,
                          value: _filterStatus,
                          hint: Text('Status',
                              style: GoogleFonts.inter(
                                  fontSize: 12, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B))),
                          isExpanded: true,
                          icon: Icon(Icons.filter_list_rounded,
                              size: 16, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B)),
                          items: [
                            DropdownMenuItem<ProposalStatus?>(
                              value: null,
                              child: Text('Todos os Status',
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary)),
                            ),
                            ...ProposalStatus.values
                                .map((s) => DropdownMenuItem<ProposalStatus?>(
                                      value: s,
                                      child: Text(s.label,
                                          style: GoogleFonts.inter(
                                              fontSize: 12,
                                              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary)),
                                    )),
                          ],
                          onChanged: (val) => setState(() => _filterStatus = val),
                        ),
                      ),
                    ),
                  ),
                if ((widget.currentUser?.canViewAllProposals ?? _currentUser?.canViewAllProposals ?? false) && _sellersList.isNotEmpty) ...[
                  if (!_isKanbanMode) const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          dropdownColor: isDark ? AppColors.darkSurface : Colors.white,
                          value: _filterSellerId,
                          hint: Text('Vendedor',
                              style: GoogleFonts.inter(
                                  fontSize: 12, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B))),
                          isExpanded: true,
                          icon: Icon(Icons.person_outline_rounded,
                              size: 16, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B)),
                          items: [
                            DropdownMenuItem<String?>(
                              value: null,
                              child: Text('Todos Vendedores',
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary)),
                            ),
                            ..._sellersList.map((u) => DropdownMenuItem<String?>(
                                  value: u.uid,
                                  child: Text(u.name,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary)),
                                )),
                          ],
                          onChanged: (val) => setState(() => _filterSellerId = val),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ] else ...[
            Row(
              children: [
                // Campo de busca
                Expanded(
                  flex: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        Icon(Icons.search_rounded,
                            size: 20, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchCtrl,
                            onChanged: (v) =>
                                setState(() => _query = v.trim().toLowerCase()),
                            style: GoogleFonts.inter(
                                fontSize: 13.5, color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                            decoration: InputDecoration(
                              hintText: 'Buscar por número da proposta, cliente ou título...',
                              hintStyle: GoogleFonts.inter(
                                  fontSize: 13, color: isDark ? AppColors.darkTextMuted : const Color(0xFF94A3B8)),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (!_isKanbanMode) ...[
                  const SizedBox(width: 14),
                  // Filtro por Status na Tabela
                  Expanded(
                    flex: 2,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<ProposalStatus?>(
                          dropdownColor: isDark ? AppColors.darkSurface : Colors.white,
                          value: _filterStatus,
                          hint: Text('Todos os Status',
                              style: GoogleFonts.inter(
                                  fontSize: 13, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B))),
                          isExpanded: true,
                          icon: Icon(Icons.filter_list_rounded,
                              size: 18, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B)),
                          items: [
                            DropdownMenuItem<ProposalStatus?>(
                              value: null,
                              child: Text('Todos os Status',
                                  style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary)),
                            ),
                            ...ProposalStatus.values
                                .map((s) => DropdownMenuItem<ProposalStatus?>(
                                      value: s,
                                      child: Text(s.label,
                                          style: GoogleFonts.inter(
                                              fontSize: 13,
                                              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary)),
                                    )),
                          ],
                          onChanged: (val) => setState(() => _filterStatus = val),
                        ),
                      ),
                    ),
                  ),
                ],
                // Filtro por Vendedor (se tiver permissão)
                if ((widget.currentUser?.canViewAllProposals ?? _currentUser?.canViewAllProposals ?? false) && _sellersList.isNotEmpty) ...[
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 2,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          dropdownColor: isDark ? AppColors.darkSurface : Colors.white,
                          value: _filterSellerId,
                          hint: Text('Todos os Vendedores',
                              style: GoogleFonts.inter(
                                  fontSize: 13, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B))),
                          isExpanded: true,
                          icon: Icon(Icons.person_outline_rounded,
                              size: 18, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B)),
                          items: [
                            DropdownMenuItem<String?>(
                              value: null,
                              child: Text('👥 Todos os Vendedores',
                                  style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary)),
                            ),
                            ..._sellersList.map((u) => DropdownMenuItem<String?>(
                                  value: u.uid,
                                  child: Row(
                                    children: [
                                      const Icon(Icons.person_pin_rounded, size: 16, color: Color(0xFF6366F1)),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          u.name,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                          ],
                          onChanged: (val) => setState(() => _filterSellerId = val),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],

          const SizedBox(height: 14),

          // ── Conteúdo Principal: KANBAN vs TABELA ─────────────────────────
          Expanded(
            child: StreamBuilder<List<ProposalModel>>(
              stream: _repo.getProposalsStream(
                companyId: _companyId,
                currentUserId: widget.currentUser?.uid ?? _currentUser?.uid,
                isAllProposalsVisible: widget.currentUser?.canViewAllProposals ?? _currentUser?.canViewAllProposals ?? false,
                isSuperAdmin: widget.currentUser?.isSuperAdmin ?? _currentUser?.isSuperAdmin ?? false,
              ),
              builder: (ctx, snap) {
                final isSuper = widget.currentUser?.isSuperAdmin ?? _currentUser?.isSuperAdmin ?? false;
                if ((_companyId == null && !isSuper) ||
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
                      p.title.toLowerCase().contains(_query) ||
                      (p.createdByUserName ?? '').toLowerCase().contains(_query);

                  final matchesStatus = _filterStatus == null ||
                      p.status == _filterStatus;
                  final matchesSeller = _filterSellerId == null ||
                      p.createdByUserId == _filterSellerId;
                  return matchesQuery && matchesStatus && matchesSeller;
                }).toList();

                // ── MODO KANBAN ──
                if (_isKanbanMode) {
                  return ProposalKanbanView(
                    proposals: filtered,
                    onAddNew: widget.onAddNew,
                    onEdit: widget.onEdit,
                    onPreviewWeb: _showWebPreview,
                    onCopyLink: _copyWebLink,
                    onWhatsApp: _shareOnWhatsApp,
                    onPreviewPdf: _showPdfPreview,
                    onDelete: _confirmDelete,
                    onStatusChange: _changeStatus,
                  );
                }

                // ── MODO TABELA ──
                if (filtered.isEmpty) {
                  return Container(
                    decoration: BoxDecoration(
                      color: isMobile ? Colors.transparent : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: isMobile ? null : Border.all(color: AppColors.border),
                    ),
                    child: _ProposalEmptyState(
                      isEmpty: all.isEmpty,
                      canAdd: widget.currentUser?.canCreateProposals ?? _currentUser?.canCreateProposals ?? false,
                      onAdd: widget.onAddNew,
                    ),
                  );
                }

                return Container(
                  decoration: BoxDecoration(
                    color: isMobile ? Colors.transparent : (isDark ? AppColors.darkSurface : Colors.white),
                    borderRadius: BorderRadius.circular(16),
                    border: isMobile ? null : Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                    boxShadow: isMobile
                        ? null
                        : [
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
                        if (!isMobile) ...[
                          _ProposalTableHeader(),
                          const Divider(height: 1, color: AppColors.divider),
                        ],
                        Expanded(
                          child: isMobile
                              ? ListView.builder(
                                  itemCount: filtered.length,
                                  itemBuilder: (_, i) {
                                    final proposal = filtered[i];
                                    return _ProposalMobileCard(
                                      proposal: proposal,
                                      onPreviewWeb: () => _showWebPreview(proposal),
                                      onCopyLink: () => _copyWebLink(proposal),
                                      onWhatsApp: () => _shareOnWhatsApp(proposal),
                                      onPreviewPdf: () => _showPdfPreview(proposal),
                                      onEdit: () => widget.onEdit(proposal),
                                      onDelete: () => _confirmDelete(proposal),
                                      onStatusChange: (s) =>
                                          _changeStatus(proposal, s),
                                    );
                                  },
                                )
                              : ListView.separated(
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, __) => const Divider(
                                      height: 1, color: AppColors.divider),
                                  itemBuilder: (_, i) {
                                    final proposal = filtered[i];
                                    return _ProposalRow(
                                      proposal: proposal,
                                      onPreviewWeb: () => _showWebPreview(proposal),
                                      onCopyLink: () => _copyWebLink(proposal),
                                      onWhatsApp: () => _shareOnWhatsApp(proposal),
                                      onPreviewPdf: () => _showPdfPreview(proposal),
                                      onEdit: () => widget.onEdit(proposal),
                                      onDelete: () => _confirmDelete(proposal),
                                      onStatusChange: (s) =>
                                          _changeStatus(proposal, s),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD MOBILE DE PROPOSTA COMERCIAL
// ─────────────────────────────────────────────────────────────────────────────
class _ProposalMobileCard extends StatelessWidget {
  final ProposalModel proposal;
  final VoidCallback onPreviewWeb;
  final VoidCallback onCopyLink;
  final VoidCallback onWhatsApp;
  final VoidCallback onPreviewPdf;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<ProposalStatus> onStatusChange;

  const _ProposalMobileCard({
    required this.proposal,
    required this.onPreviewWeb,
    required this.onCopyLink,
    required this.onWhatsApp,
    required this.onPreviewPdf,
    required this.onEdit,
    required this.onDelete,
    required this.onStatusChange,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeColor = Color(proposal.themeColorValue);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: themeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Icon(Icons.description_outlined, color: themeColor, size: 18),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  proposal.proposalNumber,
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
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
                                    fontSize: 13,
                                    color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  proposal.clientName,
                                  style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (proposal.createdByUserName != null && proposal.createdByUserName!.isNotEmpty) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFFBFDBFE)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.person_pin_rounded, size: 9, color: Color(0xFF2563EB)),
                                      const SizedBox(width: 2),
                                      Text(
                                        proposal.createdByUserName!,
                                        style: GoogleFonts.inter(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF1D4ED8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'R\$ ${proposal.totalAmount.toStringAsFixed(2).replaceAll('.', ',')}',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF059669),
                          ),
                        ),
                        Text(
                          '${proposal.items.length} ${proposal.items.length == 1 ? 'item' : 'itens'}',
                          style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(height: 1, color: AppColors.divider),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
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
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.language_rounded, size: 18, color: Color(0xFF059669)),
                      onPressed: onPreviewWeb,
                      tooltip: 'Proposta Web',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                    ),
                    IconButton(
                      icon: const Icon(Icons.link_rounded, size: 18, color: Color(0xFF0284C7)),
                      onPressed: onCopyLink,
                      tooltip: 'Copiar Link',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18, color: Color(0xFF25D366)),
                      onPressed: onWhatsApp,
                      tooltip: 'WhatsApp',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                    ),
                    IconButton(
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 18, color: Color(0xFFDC2626)),
                      onPressed: onPreviewPdf,
                      tooltip: 'PDF',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF6366F1)),
                      onPressed: onEdit,
                      tooltip: 'Editar',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                      onPressed: onDelete,
                      tooltip: 'Excluir',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      child: Row(
        children: [
          _col('PROPOSTA & CLIENTE', flex: 4),
          _col('VALOR TOTAL', flex: 2),
          _col('CONDIÇÃO / VALIDADE', flex: 3),
          _col('STATUS', flex: 2),
          const SizedBox(width: 240), // Coluna de Ações (Web, Link, WhatsApp, PDF, Editar, Status, Excluir)
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
  final VoidCallback onPreviewWeb;
  final VoidCallback onCopyLink;
  final VoidCallback onWhatsApp;
  final VoidCallback onPreviewPdf;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<ProposalStatus> onStatusChange;

  const _ProposalRow({
    required this.proposal,
    required this.onPreviewWeb,
    required this.onCopyLink,
    required this.onWhatsApp,
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
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Cliente: ${proposal.clientName}${proposal.isClientLinked ? ' (Cadastrado)' : ' (Avulso)'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                  fontSize: 11.5, color: const Color(0xFF64748B)),
                            ),
                          ),
                          if (proposal.createdByUserName != null && proposal.createdByUserName!.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFFBFDBFE)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.person_pin_rounded, size: 10, color: Color(0xFF2563EB)),
                                  const SizedBox(width: 3),
                                  Text(
                                    proposal.createdByUserName!,
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF1D4ED8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
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

          // 5. Ações (Web, Link, WhatsApp, PDF, Editar, Mudar Status, Excluir)
          SizedBox(
            width: 240,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Abrir Versão Web Interativa',
                  icon: const Icon(Icons.language_rounded,
                      color: Color(0xFF059669), size: 18),
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  visualDensity: VisualDensity.compact,
                  onPressed: onPreviewWeb,
                ),
                IconButton(
                  tooltip: 'Copiar Link Público da Proposta',
                  icon: const Icon(Icons.link_rounded,
                      color: Color(0xFF0284C7), size: 18),
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  visualDensity: VisualDensity.compact,
                  onPressed: onCopyLink,
                ),
                IconButton(
                  tooltip: 'Enviar Proposta no WhatsApp',
                  icon: const Icon(Icons.chat_bubble_outline_rounded,
                      color: Color(0xFF25D366), size: 18),
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  visualDensity: VisualDensity.compact,
                  onPressed: onWhatsApp,
                ),
                IconButton(
                  tooltip: 'Visualizar / Baixar PDF',
                  icon: const Icon(Icons.picture_as_pdf_outlined,
                      color: Color(0xFFDC2626), size: 18),
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  visualDensity: VisualDensity.compact,
                  onPressed: onPreviewPdf,
                ),
                IconButton(
                  tooltip: 'Editar Proposta',
                  icon: const Icon(Icons.edit_outlined,
                      color: Color(0xFF6366F1), size: 18),
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  visualDensity: VisualDensity.compact,
                  onPressed: onEdit,
                ),
                PopupMenuButton<ProposalStatus>(
                  tooltip: 'Alterar Status',
                  icon: const Icon(Icons.swap_horiz_rounded,
                      color: Color(0xFF64748B), size: 19),
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
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
                  tooltip: 'Excluir Proposta',
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: Color(0xFFEF4444), size: 18),
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
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
  final bool canAdd;
  final VoidCallback onAdd;

  const _ProposalEmptyState({
    required this.isEmpty,
    this.canAdd = true,
    required this.onAdd,
  });

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
          if (isEmpty && canAdd) ...[
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
  final UserModel? currentUser;
  final ProposalModel? proposal;
  final ProposalItemModel? initialItem;
  final ClientModel? initialClient;
  final ParsedUnifiedProposal? initialParsedProposal;
  final VoidCallback onCancel;
  final VoidCallback onSaved;

  const _ProposalFormCard({
    this.currentUser,
    this.proposal,
    this.initialItem,
    this.initialClient,
    this.initialParsedProposal,
    required this.onCancel,
    required this.onSaved,
  });

  @override
  State<_ProposalFormCard> createState() => _ProposalFormCardState();
}

class _ProposalFormCardState extends State<_ProposalFormCard> {
  late final ProposalRepository _proposalRepo;
  late final ClientRepository _clientRepo;
  late final AuthRepository _authRepo;
  StreamSubscription<UserModel?>? _userSub;

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

  // Etapa no Funil Kanban / Status
  ProposalStatus _selectedStatus = ProposalStatus.inApproval;

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  String? _companyId;

  static const _cleanProposalStorageKey = 'mavis_proposal_clean_mode';

  // Switch para exibir apenas Inversor e Módulo na Composição da Usina Solar
  bool _showOnlyModulesAndInverters = false;

  bool _isModuleOrInverterComponent(String text) {
    final lower = text.toLowerCase();

    // 1. Identificação prioritária de Inversor / Microinversor
    final isInverter = lower.contains('inversor') ||
        lower.contains('microinversor') ||
        lower.contains('micro-inversor') ||
        lower.contains('invers.') ||
        lower.contains('auxsol') ||
        lower.contains('deye') ||
        lower.contains('growatt') ||
        lower.contains('solis') ||
        lower.contains('sungrow') ||
        lower.contains('fronius') ||
        lower.contains('goodwe') ||
        lower.contains('hoymiles') ||
        lower.contains('huawei') ||
        lower.contains('sofar') ||
        lower.contains('tsun') ||
        lower.contains('kehua') ||
        lower.contains('chint') ||
        lower.contains('livoltek') ||
        lower.contains('ap systems') ||
        lower.contains('apsystems') ||
        lower.contains('enphase');

    if (isInverter) return true;

    // 2. Identificação prioritária de Módulo / Painel / Placa Solar
    final isModule = lower.contains('módulo') ||
        lower.contains('modulo') ||
        lower.contains('painel') ||
        lower.contains('placa') ||
        lower.contains('bifacial') ||
        lower.contains('monofacial') ||
        lower.contains('n-type') ||
        lower.contains('n type') ||
        lower.contains('p-type') ||
        lower.contains('half-cell') ||
        lower.contains('half cell') ||
        lower.contains('cel.') ||
        lower.contains('celulas') ||
        lower.contains('células') ||
        lower.contains('monocristalino') ||
        lower.contains('policristalino') ||
        lower.contains('tcl solar') ||
        lower.contains('canadian') ||
        lower.contains('jinko') ||
        lower.contains('ja solar') ||
        lower.contains('longi') ||
        lower.contains('trina') ||
        lower.contains('risen') ||
        lower.contains('osda') ||
        lower.contains('znshine') ||
        lower.contains('astronergy') ||
        lower.contains('tw solar') ||
        lower.contains('sunova');

    return isInverter || isModule;
  }

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
    try {
      _authRepo = Modular.get<AuthRepository>();
    } catch (_) {
      _authRepo = AuthRepository();
    }
    _currentUser = widget.currentUser;
    _userSub = _authRepo.getCurrentUserStream().listen((user) {
      if (mounted) {
        setState(() {
          _currentUser = user;
          _companyId = user?.effectiveCompanyId ?? _companyId;
        });
      }
    });
    _loadCompanyId();
    _loadCleanModePreference();

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
      _selectedStatus = p.status;
    } else {
      if (widget.initialItem != null) {
        _items.add(widget.initialItem!);
        if (widget.initialItem!.isSolarPlant) {
          _titleCtrl.text = 'Proposta Comercial - ${widget.initialItem!.name}';
        }
      }
      if (widget.initialClient != null) {
        final c = widget.initialClient!;
        _isClientLinked = true;
        _selectedClientId = c.id;
        _clientNameCtrl.text = c.name;
        _clientEmailCtrl.text = c.email;
        _clientPhoneCtrl.text = c.phone ?? '';
        _clientDocCtrl.text = c.document ?? '';
        _clientAddrCtrl.text = c.fullAddress;
      }
      if (widget.initialParsedProposal != null) {
        final p = widget.initialParsedProposal!;
        if (p.plantName.isNotEmpty) {
          _titleCtrl.text = 'Proposta Comercial - ${p.plantName}';
        }
        if (p.paymentTerms != null && p.paymentTerms!.isNotEmpty) {
          _paymentTermsCtrl.text = p.paymentTerms!;
        }
        _validityDaysCtrl.text = p.validityDays.toString();
        if (p.deliveryTime != null && p.deliveryTime!.isNotEmpty) {
          _deliveryTimeCtrl.text = p.deliveryTime!;
        }
        if (p.notes != null && p.notes!.isNotEmpty) {
          _notesCtrl.text = p.notes!;
        }
        if (p.shippingFee > 0) {
          _shippingCtrl.text = p.shippingFee.toStringAsFixed(2);
        }
        if (widget.initialClient == null && p.clientName != null && p.clientName!.isNotEmpty) {
          _isClientLinked = false;
          _clientNameCtrl.text = p.clientName!;
          _clientEmailCtrl.text = p.clientEmail ?? '';
          _clientPhoneCtrl.text = p.clientPhone ?? '';
          _clientDocCtrl.text = p.clientDocument ?? '';
          _clientAddrCtrl.text = p.street != null
              ? '${p.street!}${p.addressNumber != null ? ", nº ${p.addressNumber!}" : ""}${p.city != null ? ", ${p.city!}" : ""}'
              : '';
        }
      }
    }
  }

  void _openAiAssistant() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ProposalAiAssistantDialog(
        onProposalReady: (parsed, linkedClient, solarItem) {
          setState(() {
            if (linkedClient != null) {
              _onClientSelected(linkedClient);
            } else if (parsed.clientName != null && parsed.clientName!.isNotEmpty) {
              _isClientLinked = false;
              _clientNameCtrl.text = parsed.clientName!;
              _clientEmailCtrl.text = parsed.clientEmail ?? '';
              _clientPhoneCtrl.text = parsed.clientPhone ?? '';
              _clientDocCtrl.text = parsed.clientDocument ?? '';
              _clientAddrCtrl.text = parsed.street != null
                  ? '${parsed.street!}${parsed.addressNumber != null ? ", nº ${parsed.addressNumber!}" : ""}${parsed.city != null ? ", ${parsed.city!}" : ""}'
                  : '';
            }
            if (parsed.plantName.isNotEmpty) {
              _titleCtrl.text = 'Proposta Comercial - ${parsed.plantName}';
            }
            if (parsed.paymentTerms != null && parsed.paymentTerms!.isNotEmpty) {
              _paymentTermsCtrl.text = parsed.paymentTerms!;
            }
            if (parsed.notes != null && parsed.notes!.isNotEmpty) {
              _notesCtrl.text = parsed.notes!;
            }
            _items.add(solarItem);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Dados da IA aplicados na proposta com sucesso!'),
              backgroundColor: Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }

  Future<void> _loadCompanyId() async {
    try {
      AuthRepository auth;
      try {
        auth = Modular.get<AuthRepository>();
      } catch (_) {
        auth = AuthRepository();
      }
      final user = await auth.getCurrentUser();
      final cid = user?.effectiveCompanyId ?? await auth.getCurrentCompanyId();
      if (mounted) {
        setState(() {
          _currentUser = user;
          _companyId = cid;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadCleanModePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool(_cleanProposalStorageKey);
      if (saved != null && mounted) {
        setState(() {
          _showOnlyModulesAndInverters = saved;
        });
      }
    } catch (_) {}
  }

  Future<void> _onCleanModeChanged(bool val) async {
    setState(() {
      _showOnlyModulesAndInverters = val;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_cleanProposalStorageKey, val);
    } catch (_) {}
  }

  @override
  void dispose() {
    _userSub?.cancel();
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
        canCreateProduct: widget.currentUser?.canCreateProducts ?? _currentUser?.canCreateProducts ?? false,
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

    final itemsToUse = _items.map((item) {
      if (item.isSolarPlant && item.solarComponents != null && _showOnlyModulesAndInverters) {
        final filtered = item.solarComponents!.where(_isModuleOrInverterComponent).toList();
        if (filtered.isNotEmpty) {
          return item.copyWith(solarComponents: filtered);
        }
      }
      return item;
    }).toList();

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
      items: itemsToUse,
      subtotal: _subtotal,
      discount: _discount,
      shippingFee: _shipping,
      totalAmount: _totalAmount,
      paymentTerms: _paymentTermsCtrl.text.trim(),
      validityDays: validity,
      deliveryTime: _deliveryTimeCtrl.text.trim(),
      notes: _notesCtrl.text.trim(),
      themeColorValue: _themeColorValue,
      status: _selectedStatus,
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

      final itemsToSave = _items.map((item) {
        if (item.isSolarPlant && item.solarComponents != null && _showOnlyModulesAndInverters) {
          final filtered = item.solarComponents!.where(_isModuleOrInverterComponent).toList();
          if (filtered.isNotEmpty) {
            return item.copyWith(solarComponents: filtered);
          }
        }
        return item;
      }).toList();

      if (_isEditing) {
        final updated = widget.proposal!.copyWith(
          title: title,
          clientId: _isClientLinked ? _selectedClientId : null,
          clientName: clientName.isNotEmpty ? clientName : 'Consumidor Final',
          clientEmail: _clientEmailCtrl.text.trim(),
          clientPhone: _clientPhoneCtrl.text.trim(),
          clientDocument: _clientDocCtrl.text.trim(),
          clientAddress: _clientAddrCtrl.text.trim(),
          items: itemsToSave,
          subtotal: _subtotal,
          discount: _discount,
          shippingFee: _shipping,
          totalAmount: _totalAmount,
          paymentTerms: _paymentTermsCtrl.text.trim(),
          validityDays: validity,
          deliveryTime: _deliveryTimeCtrl.text.trim(),
          notes: _notesCtrl.text.trim(),
          themeColorValue: _themeColorValue,
          status: _selectedStatus,
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
          items: itemsToSave,
          subtotal: _subtotal,
          discount: _discount,
          shippingFee: _shipping,
          totalAmount: _totalAmount,
          paymentTerms: _paymentTermsCtrl.text.trim(),
          validityDays: validity,
          deliveryTime: _deliveryTimeCtrl.text.trim(),
          notes: _notesCtrl.text.trim(),
          themeColorValue: _themeColorValue,
          status: _selectedStatus,
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
    final isMobile = MediaQuery.of(context).size.width < 768;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 12 : 32),
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
          padding: EdgeInsets.all(isMobile ? 14 : 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Cabeçalho do Formulário ────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(isMobile ? 10 : 12),
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(Icons.note_add_rounded,
                              color: Colors.white, size: isMobile ? 20 : 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isEditing
                                    ? (isMobile ? 'Editar Proposta' : 'Editar Proposta Comercial')
                                    : (isMobile ? 'Nova Proposta' : 'Cadastrar Nova Proposta Comercial'),
                                style: GoogleFonts.outfit(
                                  fontSize: isMobile ? 18 : 22,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                isMobile ? 'Preencha os dados e gere o PDF' : 'Preencha os dados do cliente, itens do orçamento e gere o PDF executivo',
                                style: GoogleFonts.inter(
                                    fontSize: 12, color: const Color(0xFF64748B)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Botão Assistente IA dentro do Formulário
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _openAiAssistant,
                      borderRadius: BorderRadius.circular(10),
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 10 : 14, vertical: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.auto_awesome_rounded,
                                size: 16, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(
                              isMobile ? 'IA' : 'ASSISTENTE IA',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
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
                        padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 12 : 16, vertical: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.arrow_back_rounded,
                                size: 16, color: Color(0xFF64748B)),
                            if (!isMobile) ...[
                              const SizedBox(width: 8),
                              Text(
                                'Voltar',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(color: AppColors.divider),
              const SizedBox(height: 14),

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

              // Título da Proposta e Etapa / Status no Funil Kanban
              if (isMobile) ...[
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
                const SizedBox(height: 12),
                _label('Etapa no Funil Kanban / Status *'),
                const SizedBox(height: 6),
                _buildStatusDropdown(),
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Etapa no Funil Kanban / Status *'),
                          const SizedBox(height: 6),
                          _buildStatusDropdown(),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),

              // Switch Cliente Cadastrado vs Avulso
              if (isMobile) ...[
                Column(
                  children: [
                    InkWell(
                      onTap: () => setState(() => _isClientLinked = true),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
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
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Vincular a Cliente Cadastrado',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.5,
                                  color: _isClientLinked
                                      ? AppColors.primary
                                      : const Color(0xFF0F172A),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => setState(() => _isClientLinked = false),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
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
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Cliente Avulso / Consumidor Final',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.5,
                                  color: !_isClientLinked
                                      ? AppColors.primary
                                      : const Color(0xFF0F172A),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
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
              ],
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
                      canCreateClient: widget.currentUser?.canCreateClients ?? _currentUser?.canCreateClients ?? false,
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
              if (isMobile) ...[
                _label('Nome do Cliente / Empresa *'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _clientNameCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Ex: Supermercados Estrela Ltda',
                    prefixIcon: Icon(Icons.person_outline, color: Color(0xFF64748B)),
                  ),
                ),
                const SizedBox(height: 12),
                _label('CPF ou CNPJ'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _clientDocCtrl,
                  decoration: const InputDecoration(
                    hintText: '00.000.000/0001-00',
                    prefixIcon: Icon(Icons.badge_outlined, color: Color(0xFF64748B)),
                  ),
                ),
                const SizedBox(height: 12),
                _label('E-mail para Envio'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _clientEmailCtrl,
                  decoration: const InputDecoration(
                    hintText: 'contato@cliente.com.br',
                    prefixIcon: Icon(Icons.email_outlined, color: Color(0xFF64748B)),
                  ),
                ),
                const SizedBox(height: 12),
                _label('Telefone / WhatsApp'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _clientPhoneCtrl,
                  decoration: const InputDecoration(
                    hintText: '(11) 98765-4321',
                    prefixIcon: Icon(Icons.phone_outlined, color: Color(0xFF64748B)),
                  ),
                ),
                const SizedBox(height: 12),
                _label('Endereço Completo de Instalação / Faturamento'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _clientAddrCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Ex: Av. Paulista, 1000, Apto 501 - Bela Vista, São Paulo/SP',
                    prefixIcon: Icon(Icons.location_on_outlined, color: Color(0xFF64748B)),
                  ),
                ),
              ] else ...[
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
                const SizedBox(height: 12),
                _label('Endereço Completo de Instalação / Faturamento'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _clientAddrCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Ex: Av. Paulista, 1000, Apto 501 - Bela Vista, São Paulo/SP',
                    prefixIcon: Icon(Icons.location_on_outlined, color: Color(0xFF64748B)),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // ── SEÇÃO 2: ITENS DA PROPOSTA ─────────────────────────────────
              if (isMobile) ...[
                _sectionHeader(
                    Icons.inventory_2_outlined,
                    'Itens da Proposta',
                    'Adicione produtos ou monte usinas sob medida'),
                const SizedBox(height: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.currentUser?.canCreateProducts ?? _currentUser?.canCreateProducts ?? false) ...[
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _openSolarPlantDialog,
                          borderRadius: BorderRadius.circular(10),
                          child: Ink(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFF59E0B), Color(0xFFEA580C)],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.solar_power_rounded, color: Colors.white, size: 16),
                                SizedBox(width: 6),
                                Text('MONTAR USINA SOLAR', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
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
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.add_shopping_cart_rounded, color: Colors.white, size: 16),
                              SizedBox(width: 6),
                              Text('ADICIONAR PRODUTO / USINA', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
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
                        // Botão Criar Usina Solar (Apenas se tiver permissão)
                        if (widget.currentUser?.canCreateProducts ?? _currentUser?.canCreateProducts ?? false) ...[
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
                        ],

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
              ],
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
                      // Cabeçalho da Tabela de Itens (apenas Desktop)
                      if (!isMobile) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          color: const Color(0xFFF8FAFC),
                          child: Row(
                            children: const [
                              SizedBox(
                                  width: 28,
                                  child: Text('#',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                          color: Color(0xFF64748B)))),
                              Expanded(
                                  flex: 5,
                                  child: Text('ITEM / DESCRIÇÃO',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                          color: Color(0xFF64748B)))),
                              SizedBox(
                                  width: 70,
                                  child: Center(
                                      child: Text('QTD',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                              color: Color(0xFF64748B))))),
                              SizedBox(
                                  width: 45,
                                  child: Center(
                                      child: Text('UNID',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                              color: Color(0xFF64748B))))),
                              SizedBox(
                                  width: 110,
                                  child: Align(
                                      alignment: Alignment.centerRight,
                                      child: Text('UNITÁRIO (R\$)',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                              color: Color(0xFF64748B))))),
                              SizedBox(
                                  width: 80,
                                  child: Center(
                                      child: Text('DESC %',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                              color: Color(0xFF64748B))))),
                              SizedBox(
                                  width: 110,
                                  child: Align(
                                      alignment: Alignment.centerRight,
                                      child: Text('TOTAL (R\$)',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                              color: Color(0xFF64748B))))),
                              SizedBox(width: 45), // Botão de Remover
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: AppColors.divider),
                      ],

                      if (_items.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(28),
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
                                  textAlign: TextAlign.center,
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

                            if (isMobile) {
                              return Padding(
                                key: ValueKey('proposal_item_mobile_${item.productId ?? ""}_${item.name}_$idx'),
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 22,
                                          height: 22,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Center(
                                            child: Text('${idx + 1}', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11, color: const Color(0xFF475569))),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              if (item.isSolarPlant) ...[
                                                Container(
                                                  margin: const EdgeInsets.only(bottom: 4),
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFFEF3C7),
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: const Color(0xFFFCD34D)),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      const Icon(Icons.solar_power_rounded, size: 12, color: Color(0xFFD97706)),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        'USINA SOLAR ${item.solarKilowatts != null ? "${item.solarKilowatts!.toStringAsFixed(1)} kWp" : ""}',
                                                        style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                              Text(item.name, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12.5, color: const Color(0xFF0F172A))),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Remover',
                                          icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 18),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                          onPressed: () => _removeItem(idx),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        SizedBox(
                                          width: 60,
                                          child: TextFormField(
                                            initialValue: item.quantity % 1 == 0 ? item.quantity.toInt().toString() : item.quantity.toString(),
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.inter(fontSize: 12),
                                            decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 6), labelText: 'Qtd'),
                                            onChanged: (val) {
                                              final q = double.tryParse(val.replaceAll(',', '.')) ?? 1.0;
                                              _updateItemQuantity(idx, q);
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: TextFormField(
                                            initialValue: item.unitPrice.toStringAsFixed(2),
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            textAlign: TextAlign.right,
                                            style: GoogleFonts.inter(fontSize: 12),
                                            decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6), labelText: 'Unitário (R\$)'),
                                            onChanged: (val) {
                                              final p = double.tryParse(val.replaceAll(',', '.')) ?? 0.0;
                                              _updateItemPrice(idx, p);
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        SizedBox(
                                          width: 55,
                                          child: TextFormField(
                                            initialValue: item.discountPercent.toStringAsFixed(0),
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.inter(fontSize: 12),
                                            decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 6), labelText: 'Desc %'),
                                            onChanged: (val) {
                                              final d = double.tryParse(val.replaceAll(',', '.')) ?? 0.0;
                                              _updateItemDiscount(idx, d);
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text('Total', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B))),
                                            Text(
                                              currencyFormat.format(item.totalPrice),
                                              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12.5, color: const Color(0xFF0F172A)),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }

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
                                                ...(() {
                                                  final rawComps = item.solarComponents!;
                                                  final filtered = _showOnlyModulesAndInverters
                                                      ? rawComps.where(_isModuleOrInverterComponent).toList()
                                                      : rawComps;
                                                  final displayList = filtered.isNotEmpty ? filtered : rawComps;
                                                  return displayList.map(
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
                                                  );
                                                })(),
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

              const SizedBox(height: 24),

              // ── SWITCH: MODO RESUMIDO DE USINA SOLAR (APENAS MÓDULOS E INVERSORES) ──
              if (_items.any((it) => it.isSolarPlant && it.solarComponents != null && it.solarComponents!.isNotEmpty)) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: EdgeInsets.all(isMobile ? 12 : 14),
                  decoration: BoxDecoration(
                    color: _showOnlyModulesAndInverters ? const Color(0xFFFFFBEB) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _showOnlyModulesAndInverters ? const Color(0xFFFDE68A) : AppColors.border,
                      width: _showOnlyModulesAndInverters ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _showOnlyModulesAndInverters ? const Color(0xFFFEF3C7) : const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.solar_power_rounded,
                          color: _showOnlyModulesAndInverters ? const Color(0xFFD97706) : const Color(0xFF6366F1),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Apenas Inversor e Módulo',
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: _showOnlyModulesAndInverters ? const Color(0xFF92400E) : const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'Oculta itens secundários no PDF.',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: _showOnlyModulesAndInverters ? const Color(0xFFB45309) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: _showOnlyModulesAndInverters,
                        onChanged: _onCleanModeChanged,
                        activeTrackColor: const Color(0xFFD97706),
                        activeThumbColor: Colors.white,
                      ),
                    ],
                  ),
                ),
              ],

              // ── SEÇÃO 3: CONDIÇÕES COMERCIAIS & FINANCEIRO ─────────────────
              _sectionHeader(
                  Icons.payments_outlined,
                  'Condições Comerciais & Pagamento',
                  'Defina os termos de pagamento, prazos de entrega e validade'),
              const SizedBox(height: 14),

              if (isMobile) ...[
                _label('Forma / Condição de Pagamento *'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _paymentTermsCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Ex: À vista via PIX com 5% de desconto',
                    prefixIcon: Icon(Icons.credit_card_rounded, color: Color(0xFF64748B)),
                  ),
                ),
                const SizedBox(height: 12),
                _label('Validade da Proposta (Dias)'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _validityDaysCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: '15',
                    prefixIcon: Icon(Icons.event_available_rounded, color: Color(0xFF64748B)),
                  ),
                ),
                const SizedBox(height: 12),
                _label('Prazo de Entrega'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _deliveryTimeCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Ex: Imediata ou 3 a 5 dias úteis',
                    prefixIcon: Icon(Icons.local_shipping_outlined, color: Color(0xFF64748B)),
                  ),
                ),
                const SizedBox(height: 12),
                _label('Observações & Termos Gerais da Proposta'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _notesCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Ex: Garantia de performance e homologação.',
                    prefixIcon: Icon(Icons.notes_rounded, color: Color(0xFF64748B)),
                  ),
                ),
                const SizedBox(height: 16),
                // Quadro financeiro mobile
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'RESUMO FINANCEIRO',
                        style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFF475569)),
                      ),
                      const SizedBox(height: 10),
                      _financeRow('Subtotal:', currencyFormat.format(_subtotal)),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Desconto (R\$):', style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF64748B))),
                          SizedBox(
                            width: 90,
                            child: TextFormField(
                              controller: _discountCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              textAlign: TextAlign.right,
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF059669)),
                              decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4)),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Frete (R\$):', style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF64748B))),
                          SizedBox(
                            width: 90,
                            child: TextFormField(
                              controller: _shippingCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              textAlign: TextAlign.right,
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                              decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4)),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                      const Divider(color: AppColors.divider, height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('TOTAL DA PROPOSTA', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white70)),
                            const SizedBox(height: 2),
                            Text(
                              currencyFormat.format(_totalAmount),
                              style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
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
              ],

              const SizedBox(height: 24),

              // ── SEÇÃO 4: PERSONALIZAÇÃO DE CORES DO PDF ───────────────────
              _sectionHeader(Icons.palette_outlined, 'Padrão Visual do PDF',
                  'Escolha a cor do tema para o cabeçalho e destaques do documento'),
              const SizedBox(height: 12),

              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: ProposalPdfThemeOption.allThemes.map((t) {
                  final isSelected = t.primaryColorValue == _themeColorValue;
                  return InkWell(
                    onTap: () =>
                        setState(() => _themeColorValue = t.primaryColorValue),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
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
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: t.primaryColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            t.label,
                            style: GoogleFonts.inter(
                              fontSize: 12,
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

              const SizedBox(height: 28),
              const Divider(color: AppColors.divider),
              const SizedBox(height: 16),

              // ── BOTÕES DE AÇÃO NO RODAPÉ ───────────────────────────────────
              if (isMobile) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _isLoading ? null : _submit,
                        borderRadius: BorderRadius.circular(12),
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: _isLoading
                              ? const Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      _isEditing ? 'SALVAR ALTERAÇÕES' : 'SALVAR PROPOSTA',
                                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _previewPdf,
                        borderRadius: BorderRadius.circular(12),
                        child: Ink(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF0F172A), width: 1.2),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.picture_as_pdf_outlined, size: 18, color: Color(0xFF0F172A)),
                              const SizedBox(width: 8),
                              Text('PRÉ-VISUALIZAR PDF', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12.5, color: const Color(0xFF0F172A))),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: widget.onCancel,
                      child: Text('CANCELAR', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
                    ),
                  ],
                ),
              ] else ...[
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

  Widget _buildStatusDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ProposalStatus>(
          value: _selectedStatus,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
          items: ProposalStatus.values.map((s) {
            return DropdownMenuItem<ProposalStatus>(
              value: s,
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: s.bgColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(s.icon, size: 13, color: s.textColor),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    s.label,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) setState(() => _selectedStatus = val);
          },
        ),
      ),
    );
  }
}
