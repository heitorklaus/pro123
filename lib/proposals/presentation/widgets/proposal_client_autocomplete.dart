import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/theme/app_colors.dart';
import '../../../clients/domain/models/client_model.dart';

/// Componente de Autocomplete Seguro e Limpo para Seleção de Clientes em Propostas
class ProposalClientAutocomplete extends StatefulWidget {
  final List<ClientModel> clients;
  final String? selectedClientId;
  final String? initialClientName;
  final ValueChanged<ClientModel> onClientSelected;
  final VoidCallback onClearClient;
  final VoidCallback onAddNewClient;
  final bool canCreateClient;

  const ProposalClientAutocomplete({
    super.key,
    required this.clients,
    required this.selectedClientId,
    this.initialClientName,
    required this.onClientSelected,
    required this.onClearClient,
    required this.onAddNewClient,
    this.canCreateClient = true,
  });

  @override
  State<ProposalClientAutocomplete> createState() => _ProposalClientAutocompleteState();
}

class _ProposalClientAutocompleteState extends State<ProposalClientAutocomplete> {
  late TextEditingController _textCtrl;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    String initialText = widget.initialClientName ?? '';
    if (initialText.isEmpty && widget.selectedClientId != null) {
      try {
        final match = widget.clients.firstWhere((c) => c.id == widget.selectedClientId);
        initialText = match.name;
      } catch (_) {}
    }
    _textCtrl = TextEditingController(text: initialText);
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant ProposalClientAutocomplete oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedClientId != oldWidget.selectedClientId ||
        widget.initialClientName != oldWidget.initialClientName) {
      String newText = widget.initialClientName ?? '';
      if (newText.isEmpty && widget.selectedClientId != null) {
        try {
          final match = widget.clients.firstWhere((c) => c.id == widget.selectedClientId);
          newText = match.name;
        } catch (_) {}
      }
      if (newText.isNotEmpty && _textCtrl.text != newText) {
        _textCtrl.text = newText;
      } else if (widget.selectedClientId == null && (widget.initialClientName == null || widget.initialClientName!.isEmpty)) {
        if (_textCtrl.text.isNotEmpty) {
          _textCtrl.clear();
        }
      }
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<ClientModel>(
      textEditingController: _textCtrl,
      focusNode: _focusNode,
      displayStringForOption: (ClientModel option) => option.name,
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return widget.clients.take(10);
        }
        final q = textEditingValue.text.trim().toLowerCase();
        return widget.clients.where((c) {
          final nameMatch = c.name.toLowerCase().contains(q);
          final emailMatch = c.email.toLowerCase().contains(q);
          final docMatch = c.document != null && c.document!.toLowerCase().contains(q);
          final compMatch = c.company != null && c.company!.toLowerCase().contains(q);
          final phoneMatch = c.phone != null && c.phone!.toLowerCase().contains(q);
          final cityMatch = c.city != null && c.city!.toLowerCase().contains(q);
          return nameMatch || emailMatch || docMatch || compMatch || phoneMatch || cityMatch;
        }).take(15);
      },
      onSelected: (ClientModel selection) {
        widget.onClientSelected(selection);
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        final isSelected = widget.selectedClientId != null && controller.text.isNotEmpty;

        return Row(
          children: [
            // Campo de Input Text com Nome Completo
            Expanded(
              child: TextFormField(
                controller: controller,
                focusNode: focusNode,
                decoration: InputDecoration(
                  hintText: 'Digite o nome, CNPJ/CPF ou clique para ver clientes recentes...',
                  hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
                  prefixIcon: Icon(
                    isSelected ? Icons.check_circle_rounded : Icons.person_search_rounded,
                    color: isSelected ? const Color(0xFF10B981) : const Color(0xFF6366F1),
                    size: 20,
                  ),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (controller.text.isNotEmpty)
                        IconButton(
                          tooltip: 'Limpar cliente',
                          icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF64748B)),
                          onPressed: () {
                            controller.clear();
                            widget.onClearClient();
                          },
                        ),
                      IconButton(
                        tooltip: 'Ver clientes',
                        icon: const Icon(Icons.arrow_drop_down_rounded, size: 24, color: Color(0xFF64748B)),
                        onPressed: () {
                          if (focusNode.hasFocus) {
                            focusNode.unfocus();
                          } else {
                            focusNode.requestFocus();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (widget.canCreateClient) ...[
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
          ],
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 12,
            borderRadius: BorderRadius.circular(14),
            color: Colors.white,
            shadowColor: Colors.black.withValues(alpha: 0.25),
            child: Container(
              width: MediaQuery.of(context).size.width > 700 ? 580 : 340,
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
                  // Cabeçalho
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
                            const Icon(Icons.people_outline_rounded, size: 14, color: Color(0xFF64748B)),
                            const SizedBox(width: 6),
                            Text(
                              'CLIENTES ENCONTRADOS (${options.length})',
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
                          'Clique para selecionar',
                          style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ),

                  // Lista
                  Flexible(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      shrinkWrap: true,
                      itemCount: options.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.divider),
                      itemBuilder: (ctx, idx) {
                        final client = options.elementAt(idx);
                        final isCompany = client.type == ClientType.company;

                        return InkWell(
                          onTap: () => onSelected(client),
                          hoverColor: const Color(0xFFEEF2FF),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Row(
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: isCompany ? const Color(0xFFE0F2FE) : const Color(0xFFEEF2FF),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isCompany ? const Color(0xFF7DD3FC) : const Color(0xFFC7D2FE),
                                    ),
                                  ),
                                  child: Center(
                                    child: isCompany
                                        ? const Icon(Icons.business_rounded, size: 17, color: Color(0xFF0284C7))
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
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: isCompany ? const Color(0xFFE0F2FE) : const Color(0xFFEEF2FF),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              isCompany ? 'PJ' : 'PF',
                                              style: GoogleFonts.inter(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: isCompany ? const Color(0xFF0284C7) : const Color(0xFF4F46E5),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${client.document != null && client.document!.isNotEmpty ? "${client.document!} • " : ""}${client.email}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
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

                  // Rodapé
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
                          'Não encontrou o cliente?',
                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          ),
                          onPressed: () {
                            _focusNode.unfocus();
                            widget.onAddNewClient();
                          },
                          icon: const Icon(Icons.person_add_rounded, size: 14),
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
        );
      },
    );
  }
}
