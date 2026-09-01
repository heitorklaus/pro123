import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../clients/domain/models/client_model.dart';
import '../../../proposals/domain/models/proposal_model.dart';
import '../../../settings/domain/models/company_model.dart';
import '../../data/services/contract_pdf_service.dart';
import '../../data/services/contract_template_engine.dart';
import '../../domain/models/contract_model.dart';

/// Editor Visual de Contratos no estilo Word / WYSIWYG em Folha A4
class ContractRichEditor extends StatefulWidget {
  final ContractModel? initialContract;
  final ProposalModel? proposal;
  final ClientModel? client;
  final CompanyModel? company;
  final Future<void> Function(ContractModel contract) onSave;
  final VoidCallback onCancel;

  const ContractRichEditor({
    super.key,
    this.initialContract,
    this.proposal,
    this.client,
    this.company,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<ContractRichEditor> createState() => _ContractRichEditorState();
}

class _ContractRichEditorState extends State<ContractRichEditor> {
  late final TextEditingController _contentCtrl;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _contractNumberCtrl;

  ContractStatus _status = ContractStatus.draft;
  bool _isSaving = false;
  bool _isGeneratingPdf = false;
  double _zoomLevel = 1.0; // 80%, 100%, 120%

  @override
  void initState() {
    super.initState();

    String initialContent = '';
    String initialNumber = '';
    String initialTitle = 'Contrato de Prestação de Serviços Fotovoltaicos';

    if (widget.initialContract != null) {
      initialContent = widget.initialContract!.content;
      initialNumber = widget.initialContract!.contractNumber;
      initialTitle = widget.initialContract!.title;
      _status = widget.initialContract!.status;
    } else if (widget.proposal != null) {
      initialNumber = 'CTR-${DateTime.now().year}-${(100 + DateTime.now().millisecondsSinceEpoch % 900)}';
      initialContent = ContractTemplateEngine.generateContractText(
        proposal: widget.proposal!,
        client: widget.client,
        company: widget.company,
        contractNumber: initialNumber,
      );
      initialTitle = 'Contrato de Prestação de Serviços - ${widget.client?.name ?? widget.proposal!.clientName}';
    }

    _contentCtrl = TextEditingController(text: initialContent);
    _titleCtrl = TextEditingController(text: initialTitle);
    _contractNumberCtrl = TextEditingController(text: initialNumber);
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    _titleCtrl.dispose();
    _contractNumberCtrl.dispose();
    super.dispose();
  }

  /// Insere texto / tag na posição atual do cursor
  void _insertTextAtCursor(String textToInsert) {
    final text = _contentCtrl.text;
    final selection = _contentCtrl.selection;
    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;

    final newText = text.replaceRange(start, end, textToInsert);
    _contentCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + textToInsert.length),
    );
  }

  /// Aplica formatação de estilo (Negrito, Itálico, etc.) na seleção ou insere sintaxe
  void _applyFormat(String prefix, String suffix) {
    final text = _contentCtrl.text;
    final selection = _contentCtrl.selection;
    if (selection.start < 0 || selection.end < 0 || selection.start == selection.end) {
      _insertTextAtCursor('$prefix$suffix');
      return;
    }

    final selectedText = text.substring(selection.start, selection.end);
    final formatted = '$prefix$selectedText$suffix';
    final newText = text.replaceRange(selection.start, selection.end, formatted);

    _contentCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection(
        baseOffset: selection.start,
        extentOffset: selection.start + formatted.length,
      ),
    );
  }

  /// Insere Título (H1, H2, H3) ou Parágrafo
  void _applyHeading(String prefix) {
    _insertTextAtCursor('\n$prefix ');
  }

  /// Restaura o contrato para o modelo padrão original
  void _restoreDefaultContract() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('Restaurar Contrato Padrão?', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'Esta ação substituirá o texto atual pelo template oficial original preenchido com os dados da proposta e do cliente.',
          style: GoogleFonts.inter(color: const Color(0xFFCBD5E1), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCELAR', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (widget.proposal != null) {
                final regenerated = ContractTemplateEngine.generateContractText(
                  proposal: widget.proposal!,
                  client: widget.client,
                  company: widget.company,
                  contractNumber: _contractNumberCtrl.text,
                );
                setState(() {
                  _contentCtrl.text = regenerated;
                });
              } else {
                setState(() {
                  _contentCtrl.text = ContractTemplateEngine.defaultContractTemplate;
                });
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
            child: const Text('RESTAURAR'),
          ),
        ],
      ),
    );
  }

  /// Constrói o modelo de contrato para salvar
  ContractModel _buildCurrentContractModel() {
    final prop = widget.proposal;
    final cli = widget.client;
    final comp = widget.company;

    double kwp = widget.initialContract?.systemKwp ?? 0.0;
    double total = widget.initialContract?.totalAmount ?? (prop?.totalAmount ?? 0.0);
    double service = widget.initialContract?.servicePrice ?? (total * 0.35);
    double products = widget.initialContract?.productsPrice ?? (total - service);
    double gen = widget.initialContract?.generationKwh ?? (kwp * 130);
    String? roof = widget.initialContract?.roofType;
    String? supplier = widget.initialContract?.supplierName ?? 'FOTUS ENERGIA SOLAR';

    if (prop != null) {
      for (final item in prop.items) {
        if (item.isSolarPlant || item.solarKilowatts != null) {
          kwp = item.solarKilowatts ?? 6.84;
          roof = item.solarRoofType ?? 'Cerâmico';
          break;
        }
      }
      gen = (kwp * 130);
    }

    return ContractModel(
      id: widget.initialContract?.id ?? '',
      contractNumber: _contractNumberCtrl.text.trim(),
      proposalId: widget.initialContract?.proposalId ?? (prop?.id ?? ''),
      proposalNumber: widget.initialContract?.proposalNumber ?? (prop?.proposalNumber ?? ''),
      clientId: widget.initialContract?.clientId ?? (cli?.id ?? prop?.clientId ?? ''),
      clientName: cli?.name ?? (prop?.clientName ?? 'Cliente Solar'),
      clientDocument: cli?.document ?? prop?.clientDocument,
      clientEmail: cli?.email ?? prop?.clientEmail,
      clientPhone: cli?.phone ?? prop?.clientPhone,
      clientAddress: cli?.street != null ? '${cli!.street}, ${cli.addressNumber ?? ""} - ${cli.city ?? ""}/${cli.state ?? ""}' : prop?.clientAddress,
      companyId: widget.initialContract?.companyId ?? comp?.id,
      companyName: comp?.name,
      companyDocument: comp?.document,
      title: _titleCtrl.text.trim(),
      content: _contentCtrl.text,
      status: _status,
      totalAmount: total,
      servicePrice: service,
      productsPrice: products,
      systemKwp: kwp,
      generationKwh: gen,
      roofType: roof,
      supplierName: supplier,
      paymentTerms: prop?.paymentTerms,
      deliveryTime: prop?.deliveryTime,
      createdAt: widget.initialContract?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Future<void> _handleSave() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, informe um título para o contrato.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final contract = _buildCurrentContractModel();
      await widget.onSave(contract);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar contrato: $e'), backgroundColor: const Color(0xFFDC2626)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handlePrintPdf() async {
    setState(() => _isGeneratingPdf = true);
    try {
      final contract = _buildCurrentContractModel();
      await ContractPdfService.printContract(contract: contract, company: widget.company);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao gerar PDF: $e'), backgroundColor: const Color(0xFFDC2626)),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F172A),
      child: Column(
        children: [
          // ── BARRA SUPERIOR DO EDITOR (TÍTULO, STATUS E AÇÕES PRINCIPAIS) ───
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              border: Border(bottom: BorderSide(color: Color(0xFF334155), width: 1)),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: widget.onCancel,
                  icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF94A3B8)),
                  tooltip: 'Voltar para a lista de contratos',
                ),
                const SizedBox(width: 8),
                Container(
                  width: 140,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: TextField(
                    controller: _contractNumberCtrl,
                    style: GoogleFonts.inter(color: const Color(0xFF818CF8), fontWeight: FontWeight.bold, fontSize: 13),
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _titleCtrl,
                    style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Título do Contrato...',
                      hintStyle: GoogleFonts.outfit(color: const Color(0xFF64748B)),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Seletor de Status
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: _status.bgColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _status.textColor.withOpacity(0.3)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<ContractStatus>(
                      value: _status,
                      dropdownColor: const Color(0xFF1E293B),
                      icon: Icon(Icons.keyboard_arrow_down_rounded, color: _status.textColor),
                      onChanged: (val) {
                        if (val != null) setState(() => _status = val);
                      },
                      items: ContractStatus.values.map((st) {
                        return DropdownMenuItem(
                          value: st,
                          child: Row(
                            children: [
                              Icon(st.icon, size: 16, color: st.textColor),
                              const SizedBox(width: 8),
                              Text(st.label, style: GoogleFonts.inter(color: st.textColor, fontWeight: FontWeight.bold, fontSize: 12.5)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Botão Imprimir / PDF
                OutlinedButton.icon(
                  onPressed: _isGeneratingPdf ? null : _handlePrintPdf,
                  icon: _isGeneratingPdf
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.print_outlined, size: 18),
                  label: const Text('IMPRIMIR / PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF475569)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 10),

                // Botão Salvar Contrato
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _handleSave,
                  icon: _isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_outlined, size: 18),
                  label: const Text('SALVAR CONTRATO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),

          // ── BARRA DE FERRAMENTAS WYSIWYG ESTILO WORD ───────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              border: Border(bottom: BorderSide(color: Color(0xFF1E293B), width: 1)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Formatações Básicas
                  _ToolbarButton(
                    icon: Icons.format_bold_rounded,
                    tooltip: 'Negrito (**texto**)',
                    onTap: () => _applyFormat('**', '**'),
                  ),
                  _ToolbarButton(
                    icon: Icons.format_italic_rounded,
                    tooltip: 'Itálico (*texto*)',
                    onTap: () => _applyFormat('*', '*'),
                  ),
                  _ToolbarButton(
                    icon: Icons.format_underlined_rounded,
                    tooltip: 'Sublinhado',
                    onTap: () => _applyFormat('<u>', '</u>'),
                  ),
                  _ToolbarButton(
                    icon: Icons.format_list_bulleted_rounded,
                    tooltip: 'Lista de Marcadores (•)',
                    onTap: () => _insertTextAtCursor('\n- '),
                  ),
                  _ToolbarButton(
                    icon: Icons.horizontal_rule_rounded,
                    tooltip: 'Linha Divisória (---)',
                    onTap: () => _insertTextAtCursor('\n---\n'),
                  ),
                  const VerticalDivider(color: Color(0xFF334155), width: 24, thickness: 1),

                  // Títulos e Cabeçalhos
                  _ToolbarTextButton(
                    label: 'Título 1',
                    tooltip: 'Título Principal (#)',
                    onTap: () => _applyHeading('#'),
                  ),
                  _ToolbarTextButton(
                    label: 'Título 2',
                    tooltip: 'Seção do Contrato (##)',
                    onTap: () => _applyHeading('##'),
                  ),
                  _ToolbarTextButton(
                    label: 'Cláusula (H3)',
                    tooltip: 'Cláusula / Item (###)',
                    onTap: () => _applyHeading('###'),
                  ),
                  const VerticalDivider(color: Color(0xFF334155), width: 24, thickness: 1),

                  // Menu Inserir Variável Dinâmica
                  PopupMenuButton<ContractTagInfo>(
                    tooltip: 'Inserir Tag Dinâmica do Banco de Dados',
                    color: const Color(0xFF1E293B),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onSelected: (tag) => _insertTextAtCursor(tag.tag),
                    itemBuilder: (context) {
                      final categories = <String, List<ContractTagInfo>>{};
                      for (final t in ContractTemplateEngine.availableTags) {
                        categories.putIfAbsent(t.category, () => []).add(t);
                      }

                      final items = <PopupMenuEntry<ContractTagInfo>>[];
                      categories.forEach((cat, tags) {
                        items.add(
                          PopupMenuItem<ContractTagInfo>(
                            enabled: false,
                            child: Text(
                              cat.toUpperCase(),
                              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF818CF8)),
                            ),
                          ),
                        );
                        for (final tag in tags) {
                          items.add(
                            PopupMenuItem<ContractTagInfo>(
                              value: tag,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(tag.label, style: GoogleFonts.inter(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
                                    Text('Ex: ${tag.example}', style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 11)),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }
                      });
                      return items;
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF6366F1)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.add_link_rounded, color: Color(0xFF818CF8), size: 16),
                          const SizedBox(width: 6),
                          Text(
                            '+ INSERIR VARIÁVEL',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF818CF8),
                              fontWeight: FontWeight.bold,
                              fontSize: 11.5,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF818CF8), size: 18),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 14),

                  // Botão Restaurar Template Padrão
                  TextButton.icon(
                    onPressed: _restoreDefaultContract,
                    icon: const Icon(Icons.restore_page_outlined, size: 16, color: Color(0xFF94A3B8)),
                    label: Text('Restaurar Padrão', style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF94A3B8))),
                  ),

                  const VerticalDivider(color: Color(0xFF334155), width: 24, thickness: 1),

                  // Controle de Zoom Visual
                  Text('Zoom:', style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 11.5)),
                  const SizedBox(width: 6),
                  _ZoomButton(label: '80%', isSelected: _zoomLevel == 0.8, onTap: () => setState(() => _zoomLevel = 0.8)),
                  _ZoomButton(label: '100%', isSelected: _zoomLevel == 1.0, onTap: () => setState(() => _zoomLevel = 1.0)),
                  _ZoomButton(label: '120%', isSelected: _zoomLevel == 1.2, onTap: () => setState(() => _zoomLevel = 1.2)),
                ],
              ),
            ),
          ),

          // ── ÁREA DE EDIÇÃO EM FOLHA A4 VISUAL (WORD-LIKE CANVAS) ───────────
          Expanded(
            child: Container(
              color: const Color(0xFF090D16),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                child: Center(
                  child: Container(
                    width: 794 * _zoomLevel, // Proporção da folha A4 em pixels
                    constraints: const BoxConstraints(minHeight: 1123), // Altura mínima A4
                    padding: EdgeInsets.symmetric(
                      horizontal: 50 * _zoomLevel,
                      vertical: 48 * _zoomLevel,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Cabeçalho da Folha A4
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              widget.company?.name.toUpperCase() ?? 'CONTRATO DE PRESTAÇÃO DE SERVIÇOS',
                              style: GoogleFonts.inter(
                                fontSize: 9.5 * _zoomLevel,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                            Text(
                              _contractNumberCtrl.text,
                              style: GoogleFonts.inter(
                                fontSize: 9.5 * _zoomLevel,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                        Divider(color: const Color(0xFFCBD5E1), thickness: 0.8, height: 18 * _zoomLevel),
                        SizedBox(height: 12 * _zoomLevel),

                        // Campo de Texto Editável em Tempo Real
                        TextField(
                          controller: _contentCtrl,
                          maxLines: null,
                          style: GoogleFonts.merriweather(
                            fontSize: 12.5 * _zoomLevel,
                            color: const Color(0xFF0F172A),
                            height: 1.65,
                          ),
                          cursorColor: const Color(0xFF6366F1),
                          cursorWidth: 2.0,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),

                        SizedBox(height: 32 * _zoomLevel),
                        Divider(color: const Color(0xFFCBD5E1), thickness: 0.8, height: 18 * _zoomLevel),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Documento gerado eletronicamente via Mavis CRM',
                              style: GoogleFonts.inter(fontSize: 8.5 * _zoomLevel, color: const Color(0xFF94A3B8)),
                            ),
                            Text(
                              'Página 1 de 1',
                              style: GoogleFonts.inter(fontSize: 8.5 * _zoomLevel, color: const Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ToolbarButton({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(icon, color: const Color(0xFFE2E8F0), size: 18),
          ),
        ),
      ),
    );
  }
}

class _ToolbarTextButton extends StatelessWidget {
  final String label;
  final String tooltip;
  final VoidCallback onTap;

  const _ToolbarTextButton({required this.label, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFFCBD5E1)),
        ),
      ),
    );
  }
}

class _ZoomButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ZoomButton({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF334155) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : const Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }
}
