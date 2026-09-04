import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../auth/domain/models/user_model.dart';
import '../../../clients/data/repositories/client_repository.dart';
import '../../../clients/domain/models/client_model.dart';
import '../../../clients/presentation/widgets/client_form_dialog.dart';
import '../../../proposals/data/repositories/proposal_repository.dart';
import '../../../proposals/domain/models/proposal_model.dart';
import '../../domain/models/roof_study_model.dart';

/// Dados resultantes da configuração/vínculo inicial do estudo de telhado
class RoofStudySetupResult {
  final String studyName;
  final ClientModel? client;
  final ProposalModel? proposal;

  const RoofStudySetupResult({
    required this.studyName,
    this.client,
    this.proposal,
  });

  ClientModel? get selectedClient => client;
  ProposalModel? get selectedProposal => proposal;
}

/// Diálogo modal moderno para configurar o Estudo de Telhado antes de abrir o satélite
/// ou para editar os vínculos (Cliente e Proposta) de um estudo existente.
class RoofStudySetupDialog extends StatefulWidget {
  final UserModel? currentUser;
  final RoofStudyModel? existingStudy;
  final bool isEditingLinksOnly;

  const RoofStudySetupDialog({
    super.key,
    this.currentUser,
    this.existingStudy,
    this.isEditingLinksOnly = false,
  });

  /// Exibe o diálogo modal e retorna a configuração escolhida pelo usuário
  static Future<RoofStudySetupResult?> show(
    BuildContext context, {
    UserModel? currentUser,
    RoofStudyModel? existingStudy,
    bool isEditingLinksOnly = false,
  }) {
    return showDialog<RoofStudySetupResult>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => RoofStudySetupDialog(
        currentUser: currentUser,
        existingStudy: existingStudy,
        isEditingLinksOnly: isEditingLinksOnly,
      ),
    );
  }

  @override
  State<RoofStudySetupDialog> createState() => _RoofStudySetupDialogState();
}

class _RoofStudySetupDialogState extends State<RoofStudySetupDialog> {
  late final TextEditingController _nameController;
  final ClientRepository _clientRepo = ClientRepository();
  final ProposalRepository _proposalRepo = ProposalRepository();

  ClientModel? _selectedClient;
  ProposalModel? _selectedProposal;
  bool _isStandalone = false; // Estudo avulso sem cliente/proposta

  @override
  void initState() {
    super.initState();
    final defaultName = widget.existingStudy?.name ??
        'Estudo Solar ${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}';
    _nameController = TextEditingController(text: defaultName);

    if (widget.existingStudy != null) {
      if (!widget.existingStudy!.hasClient && !widget.existingStudy!.hasProposal) {
        _isStandalone = true;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _openCreateClientDialog() {
    showDialog(
      context: context,
      builder: (ctx) => ClientFormDialog(
        currentUser: widget.currentUser,
        onClientSaved: (newClient) {
          setState(() {
            _selectedClient = newClient;
            _isStandalone = false;
            // Se o nome do estudo for padrão, sugere o nome do cliente
            if (_nameController.text.startsWith('Estudo Solar')) {
              _nameController.text = 'Estudo - ${newClient.name}';
            }
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final companyId = widget.currentUser?.effectiveCompanyId ?? widget.currentUser?.companyId;

    return Dialog(
      backgroundColor: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── CABEÇALHO DO MODAL ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B),
                borderRadius: BorderRadius.vertical(top: Radius.circular(19)),
                border: Border(bottom: BorderSide(color: Color(0xFF334155))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.satellite_alt_rounded,
                      color: Color(0xFF38BDF8),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isEditingLinksOnly
                              ? 'Alterar Vínculos do Estudo'
                              : 'Novo Estudo de Telhado',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Vincule um cliente, atribua a uma proposta ou crie um estudo avulso.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                    tooltip: 'Cancelar',
                  ),
                ],
              ),
            ),

            // ── MIOLO COM CAMPOS ───────────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Nome do Estudo
                    Text(
                      'Nome do Estudo *',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nameController,
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Ex: Residência Alphaville, Galpão Logístico Sul...',
                        hintStyle: GoogleFonts.inter(color: const Color(0xFF64748B)),
                        prefixIcon: const Icon(Icons.edit_note_rounded, color: Color(0xFF38BDF8)),
                        filled: true,
                        fillColor: const Color(0xFF1E293B),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF334155)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF334155)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Opção de Estudo Avulso
                    InkWell(
                      onTap: () {
                        setState(() {
                          _isStandalone = !_isStandalone;
                          if (_isStandalone) {
                            _selectedClient = null;
                            _selectedProposal = null;
                          }
                        });
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _isStandalone
                              ? const Color(0xFF6366F1).withValues(alpha: 0.12)
                              : const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _isStandalone
                                ? const Color(0xFF6366F1)
                                : const Color(0xFF334155),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isStandalone
                                  ? Icons.check_box_rounded
                                  : Icons.check_box_outline_blank_rounded,
                              color: _isStandalone
                                  ? const Color(0xFF6366F1)
                                  : const Color(0xFF94A3B8),
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Estudo Avulso (Sem Cliente / Sem Proposta)',
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    'Faça a demarcação livremente e atribua a um cliente ou proposta depois.',
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF94A3B8),
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 2. Seção de Seleção de Cliente
                    if (!_isStandalone) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Cliente (Opcional)',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _openCreateClientDialog,
                            icon: const Icon(Icons.person_add_rounded, size: 15, color: Color(0xFF10B981)),
                            label: Text(
                              '+ NOVO CLIENTE',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF10B981),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // StreamBuilder de Clientes
                      StreamBuilder<List<ClientModel>>(
                        stream: _clientRepo.getClientsStream(companyId: companyId),
                        builder: (context, snapshot) {
                          final clients = snapshot.data ?? [];

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF334155)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<ClientModel?>(
                                value: _selectedClient != null &&
                                        clients.any((c) => c.id == _selectedClient!.id)
                                    ? clients.firstWhere((c) => c.id == _selectedClient!.id)
                                    : null,
                                isExpanded: true,
                                dropdownColor: const Color(0xFF0F172A),
                                hint: Text(
                                  'Selecione um cliente cadastrado (ou deixe vazio)',
                                  style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 13),
                                ),
                                icon: const Icon(Icons.arrow_drop_down_rounded, color: Colors.white70),
                                items: [
                                  DropdownMenuItem<ClientModel?>(
                                    value: null,
                                    child: Text(
                                      '-- Nenhum (Sem cliente vinculado) --',
                                      style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13),
                                    ),
                                  ),
                                  ...clients.map((c) {
                                    final doc = c.document != null && c.document!.isNotEmpty
                                        ? ' • ${c.document}'
                                        : '';
                                    return DropdownMenuItem<ClientModel?>(
                                      value: c,
                                      child: Text(
                                        '${c.name}$doc',
                                        style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }),
                                ],
                                onChanged: (client) {
                                  setState(() {
                                    _selectedClient = client;
                                    if (client != null && _nameController.text.startsWith('Estudo Solar')) {
                                      _nameController.text = 'Estudo - ${client.name}';
                                    }
                                  });
                                },
                              ),
                            ),
                          );
                        },
                      ),

                      // Alerta de Endereço Automático do Cliente
                      if (_selectedClient != null &&
                          _selectedClient!.fullAddress.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.location_on_rounded, size: 14, color: Color(0xFF10B981)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Endereço: ${_selectedClient!.fullAddress}',
                                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF6EE7B7)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),

                      // 3. Seção de Seleção de Proposta
                      Text(
                        'Atribuir à Proposta (Opcional)',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // StreamBuilder de Propostas
                      StreamBuilder<List<ProposalModel>>(
                        stream: _proposalRepo.getProposalsStream(
                          companyId: companyId,
                          currentUserId: widget.currentUser?.uid,
                          isSuperAdmin: widget.currentUser?.isSuperAdmin == true,
                        ),
                        builder: (context, snapshot) {
                          final proposals = snapshot.data ?? [];

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF334155)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<ProposalModel?>(
                                value: _selectedProposal != null &&
                                        proposals.any((p) => p.id == _selectedProposal!.id)
                                    ? proposals.firstWhere((p) => p.id == _selectedProposal!.id)
                                    : null,
                                isExpanded: true,
                                dropdownColor: const Color(0xFF0F172A),
                                hint: Text(
                                  'Selecione uma proposta comercial (ou deixe vazio)',
                                  style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 13),
                                ),
                                icon: const Icon(Icons.arrow_drop_down_rounded, color: Colors.white70),
                                items: [
                                  DropdownMenuItem<ProposalModel?>(
                                    value: null,
                                    child: Text(
                                      '-- Nenhuma (Sem proposta vinculada) --',
                                      style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13),
                                    ),
                                  ),
                                  ...proposals.map((p) {
                                    final clientPart = p.clientName.isNotEmpty ? ' • ${p.clientName}' : '';
                                    return DropdownMenuItem<ProposalModel?>(
                                      value: p,
                                      child: Text(
                                        '#${p.proposalNumber}$clientPart',
                                        style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }),
                                ],
                                onChanged: (proposal) {
                                  setState(() {
                                    _selectedProposal = proposal;
                                  });
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ── RODAPÉ COM BOTÕES ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(19)),
                border: Border(top: BorderSide(color: Color(0xFF334155))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF475569)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                        'Cancelar',
                        style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final name = _nameController.text.trim();
                        if (name.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Por favor, digite um nome para o estudo.'),
                              backgroundColor: Color(0xFFEF4444),
                            ),
                          );
                          return;
                        }

                        Navigator.of(context).pop(
                          RoofStudySetupResult(
                            studyName: name,
                            client: _selectedClient,
                            proposal: _selectedProposal,
                          ),
                        );
                      },
                      icon: Icon(
                        widget.isEditingLinksOnly
                            ? Icons.check_circle_rounded
                            : Icons.satellite_alt_rounded,
                        size: 18,
                      ),
                      label: Text(
                        widget.isEditingLinksOnly
                            ? 'SALVAR VÍNCULOS'
                            : 'ABRIR NO SATÉLITE 🛰️',
                        style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF38BDF8),
                        foregroundColor: const Color(0xFF0F172A),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
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
}
