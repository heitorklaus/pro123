import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/theme/app_colors.dart';
import '../../../clients/domain/models/client_model.dart';

/// Componente de Autocomplete e Seleção Inteligente de Clientes para Propostas Comerciais
class ProposalClientAutocomplete extends StatefulWidget {
  final List<ClientModel> clients;
  final String? selectedClientId;
  final ValueChanged<ClientModel> onClientSelected;
  final VoidCallback onClearClient;
  final VoidCallback onAddNewClient;

  const ProposalClientAutocomplete({
    super.key,
    required this.clients,
    required this.selectedClientId,
    required this.onClientSelected,
    required this.onClearClient,
    required this.onAddNewClient,
  });

  @override
  State<ProposalClientAutocomplete> createState() => _ProposalClientAutocompleteState();
}

class _ProposalClientAutocompleteState extends State<ProposalClientAutocomplete> {
  final _focusNode = FocusNode();
  final _searchCtrl = TextEditingController();
  final _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant ProposalClientAutocomplete oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_overlayEntry != null) {
      _overlayEntry!.markNeedsBuild();
    }
  }

  @override
  void dispose() {
    _removeOverlay();
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      _showOverlay();
    } else {
      // Pequeno delay para permitir o clique nos itens do overlay
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && !_focusNode.hasFocus) {
          _removeOverlay();
        }
      });
    }
  }

  void _showOverlay() {
    _removeOverlay();
    final overlay = Overlay.of(context);

    _overlayEntry = OverlayEntry(
      builder: (context) {
        final renderBox = this.context.findRenderObject() as RenderBox?;
        final size = renderBox?.size ?? const Size(400, 48);

        final filtered = _getFilteredClients();

        return Positioned(
          width: size.width,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: Offset(0, size.height + 6),
            child: Material(
              elevation: 12,
              borderRadius: BorderRadius.circular(14),
              color: Colors.white,
              shadowColor: Colors.black.withValues(alpha: 0.25),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 340),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Cabeçalho da Lista
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
                        border: Border(bottom: BorderSide(color: AppColors.border)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _query.isEmpty ? Icons.history_rounded : Icons.search_rounded,
                                size: 14,
                                color: const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _query.isEmpty
                                    ? 'CLIENTES RECENTES (${filtered.length})'
                                    : 'RESULTADOS DA BUSCA (${filtered.length})',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF64748B),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            _query.isEmpty ? 'Mais recentes primeiro' : 'Filtrando por "$_query"',
                            style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ),

                    // Lista de Clientes
                    if (filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                        child: Column(
                          children: [
                            const Icon(Icons.person_search_outlined, size: 36, color: Color(0xFF94A3B8)),
                            const SizedBox(height: 8),
                            Text(
                              'Nenhum cliente encontrado',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: const Color(0xFF334155),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Não encontramos clientes para "$_query".',
                              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () {
                                _removeOverlay();
                                _focusNode.unfocus();
                                widget.onAddNewClient();
                              },
                              icon: const Icon(Icons.person_add_rounded, size: 15),
                              label: const Text('Cadastrar este cliente agora', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          shrinkWrap: true,
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.divider),
                          itemBuilder: (ctx, i) {
                            final client = filtered[i];
                            final isCompany = client.type == ClientType.company;

                            return InkWell(
                              onTap: () {
                                _removeOverlay();
                                _focusNode.unfocus();
                                _searchCtrl.clear();
                                _query = '';
                                widget.onClientSelected(client);
                              },
                              hoverColor: const Color(0xFFEEF2FF),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                child: Row(
                                  children: [
                                    // Avatar com Inicial
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: isCompany ? const Color(0xFFE0F2FE) : const Color(0xFFEEF2FF),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isCompany ? const Color(0xFF7DD3FC) : const Color(0xFFC7D2FE),
                                        ),
                                      ),
                                      child: Center(
                                        child: isCompany
                                            ? const Icon(Icons.business_rounded, size: 18, color: Color(0xFF0284C7))
                                            : Text(
                                                client.name.isNotEmpty ? client.name[0].toUpperCase() : 'C',
                                                style: GoogleFonts.outfit(
                                                  fontWeight: FontWeight.bold,
                                                  color: const Color(0xFF4F46E5),
                                                  fontSize: 14,
                                                ),
                                              ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),

                                    // Dados do Cliente
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  client.name,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: GoogleFonts.inter(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                    color: const Color(0xFF0F172A),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              _badge(
                                                label: isCompany ? 'PJ' : 'PF',
                                                bg: isCompany ? const Color(0xFFE0F2FE) : const Color(0xFFEEF2FF),
                                                color: isCompany ? const Color(0xFF0284C7) : const Color(0xFF4F46E5),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              if (client.document != null && client.document!.isNotEmpty) ...[
                                                Text(
                                                  client.document!,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.w500,
                                                    color: const Color(0xFF475569),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                const Text('•', style: TextStyle(color: Color(0xFFCBD5E1))),
                                                const SizedBox(width: 8),
                                              ],
                                              Expanded(
                                                child: Text(
                                                  client.email,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 11.5,
                                                    color: const Color(0xFF64748B),
                                                  ),
                                                ),
                                              ),
                                              if (client.city != null && client.city!.isNotEmpty) ...[
                                                const SizedBox(width: 8),
                                                Text(
                                                  '${client.city}${client.state != null ? "/${client.state}" : ""}',
                                                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFF94A3B8)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                    // Rodapé Fixo com Botão Cadastrar Novo Cliente
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(13)),
                        border: Border(top: BorderSide(color: AppColors.divider)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Clique em um cliente para selecioná-lo',
                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            ),
                            onPressed: () {
                              _removeOverlay();
                              _focusNode.unfocus();
                              widget.onAddNewClient();
                            },
                            icon: const Icon(Icons.add_circle_outline_rounded, size: 15),
                            label: Text(
                              'CADASTRAR NOVO CLIENTE',
                              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  List<ClientModel> _getFilteredClients() {
    if (_query.isEmpty) {
      return widget.clients.take(10).toList();
    }

    final q = _query.toLowerCase();
    return widget.clients.where((c) {
      final nameMatch = c.name.toLowerCase().contains(q);
      final emailMatch = c.email.toLowerCase().contains(q);
      final docMatch = c.document != null && c.document!.toLowerCase().contains(q);
      final companyMatch = c.company != null && c.company!.toLowerCase().contains(q);
      final phoneMatch = c.phone != null && c.phone!.toLowerCase().contains(q);
      final cityMatch = c.city != null && c.city!.toLowerCase().contains(q);

      return nameMatch || emailMatch || docMatch || companyMatch || phoneMatch || cityMatch;
    }).take(15).toList();
  }

  Widget _badge({required String label, required Color bg, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ClientModel? selectedClient;
    if (widget.selectedClientId != null) {
      try {
        selectedClient = widget.clients.firstWhere((c) => c.id == widget.selectedClientId);
      } catch (_) {
        selectedClient = null;
      }
    }

    // Se um cliente já estiver selecionado, exibe o card de cliente selecionado com opção de trocar
    if (selectedClient != null) {
      final isCompany = selectedClient.type == ClientType.company;

      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Ícone do Cliente
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: isCompany
                    ? const LinearGradient(
                        colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: isCompany
                    ? const Icon(Icons.business_rounded, color: Colors.white, size: 22)
                    : Text(
                        selectedClient.name.isNotEmpty ? selectedClient.name[0].toUpperCase() : 'C',
                        style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                      ),
              ),
            ),
            const SizedBox(width: 14),

            // Informações do Cliente
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          selectedClient.name,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 14.5,
                            color: const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _badge(
                        label: isCompany ? 'PESSOA JURÍDICA' : 'PESSOA FÍSICA',
                        bg: isCompany ? const Color(0xFFE0F2FE) : const Color(0xFFEEF2FF),
                        color: isCompany ? const Color(0xFF0284C7) : const Color(0xFF4F46E5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (selectedClient.document != null && selectedClient.document!.isNotEmpty) ...[
                        Text(
                          selectedClient.document!,
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF475569), fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 8),
                        const Text('•', style: TextStyle(color: Color(0xFFCBD5E1))),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        selectedClient.email,
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                      ),
                      if (selectedClient.phone != null && selectedClient.phone!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        const Text('•', style: TextStyle(color: Color(0xFFCBD5E1))),
                        const SizedBox(width: 8),
                        Text(
                          selectedClient.phone!,
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Ações: Trocar / Novo
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF475569),
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: widget.onClearClient,
                  icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                  label: const Text('Trocar Cliente', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: widget.onAddNewClient,
                    borderRadius: BorderRadius.circular(8),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.add_rounded, color: Colors.white, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'NOVO CLIENTE',
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
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
      );
    }

    // Se nenhum cliente selecionado: exibe a barra de busca autocomplete com botão +
    return CompositedTransformTarget(
      link: _layerLink,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Campo de Busca Autocomplete
          Expanded(
            child: TextFormField(
              controller: _searchCtrl,
              focusNode: _focusNode,
              onTap: () {
                if (!_focusNode.hasFocus) {
                  _focusNode.requestFocus();
                } else {
                  _showOverlay();
                }
              },
              onChanged: (v) {
                setState(() {
                  _query = v.trim();
                });
                if (_overlayEntry == null) {
                  _showOverlay();
                } else {
                  _overlayEntry!.markNeedsBuild();
                }
              },
              decoration: InputDecoration(
                hintText: 'Buscar cliente por nome, CNPJ/CPF, e-mail ou empresa...',
                hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.person_search_rounded, color: Color(0xFF6366F1), size: 20),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_searchCtrl.text.isNotEmpty)
                      IconButton(
                        tooltip: 'Limpar busca',
                        icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF64748B)),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                          if (_overlayEntry != null) {
                            _overlayEntry!.markNeedsBuild();
                          }
                        },
                      ),
                    IconButton(
                      tooltip: 'Ver clientes',
                      icon: const Icon(Icons.arrow_drop_down_rounded, size: 24, color: Color(0xFF64748B)),
                      onPressed: () {
                        if (_focusNode.hasFocus) {
                          _focusNode.unfocus();
                        } else {
                          _focusNode.requestFocus();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Botão + NOVO CLIENTE
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onAddNewClient,
              borderRadius: BorderRadius.circular(10),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'NOVO CLIENTE',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.3,
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
