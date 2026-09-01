import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../clients/domain/models/client_model.dart';
import '../../../proposals/domain/models/proposal_model.dart';
import '../../../settings/domain/models/company_model.dart';
import '../../data/services/contract_pdf_service.dart';
import '../../data/services/contract_template_engine.dart';
import '../../domain/models/contract_model.dart';

enum ContractEditorViewMode {
  editorOnly,
  sideBySide,
  previewOnly,
}

/// Editor Visual de Contratos no estilo Word / WYSIWYG em Folha A4
/// Com Lupa Flutuante de Pré-visualização Rápida que acompanha a rolagem
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
  ContractEditorViewMode _viewMode = ContractEditorViewMode.editorOnly;
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
      initialContent = _sanitizeContent(widget.initialContract!.content);
      initialNumber = widget.initialContract!.contractNumber;
      initialTitle = widget.initialContract!.title;
      _status = widget.initialContract!.status;
    } else if (widget.proposal != null) {
      initialNumber = 'CTR-${DateTime.now().year}-${(100 + DateTime.now().millisecondsSinceEpoch % 900)}';
      initialContent = _sanitizeContent(
        ContractTemplateEngine.generateContractText(
          proposal: widget.proposal!,
          client: widget.client,
          company: widget.company,
          contractNumber: initialNumber,
        ),
      );
      initialTitle = 'Contrato de Prestação de Serviços - ${widget.client?.name ?? widget.proposal!.clientName}';
    }

    _contentCtrl = TextEditingController(text: initialContent);
    _titleCtrl = TextEditingController(text: initialTitle);
    _contractNumberCtrl = TextEditingController(text: initialNumber);

    _contentCtrl.addListener(() {
      if (_viewMode == ContractEditorViewMode.sideBySide) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    _titleCtrl.dispose();
    _contractNumberCtrl.dispose();
    super.dispose();
  }

  /// Remove tags <br> e formatações indesejadas
  String _sanitizeContent(String text) {
    return text.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
  }

  /// Insere texto / tag na posição atual do cursor
  void _insertTextAtCursor(String textToInsert) {
    final cleanInsert = _sanitizeContent(textToInsert);
    final text = _contentCtrl.text;
    final selection = _contentCtrl.selection;
    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;

    final newText = text.replaceRange(start, end, cleanInsert);
    _contentCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + cleanInsert.length),
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
                final regenerated = _sanitizeContent(
                  ContractTemplateEngine.generateContractText(
                    proposal: widget.proposal!,
                    client: widget.client,
                    company: widget.company,
                    contractNumber: _contractNumberCtrl.text,
                  ),
                );
                setState(() {
                  _contentCtrl.text = regenerated;
                });
              } else {
                setState(() {
                  _contentCtrl.text = _sanitizeContent(ContractTemplateEngine.defaultContractTemplate);
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

  /// Abre a Lupa de Visualização Rápida em Modal Tela Cheia
  void _openQuickPreviewModal() {
    final contract = _buildCurrentContractModel();
    showDialog(
      context: context,
      builder: (ctx) => _ContractQuickPreviewModal(
        contract: contract,
        company: widget.company,
        onPrint: _handlePrintPdf,
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

    final cleanContent = _sanitizeContent(_contentCtrl.text);

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
      content: cleanContent,
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

                // Botão Lupa Rápida na Barra Superior
                ElevatedButton.icon(
                  onPressed: _openQuickPreviewModal,
                  icon: const Icon(Icons.search_rounded, size: 18, color: Colors.white),
                  label: const Text('PRÉVIA RÁPIDA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7), // Sky 600
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 10),

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

                  // Alternador de Visualização (Editor | Lado a Lado | Prévia)
                  _ViewModeToggle(
                    mode: _viewMode,
                    onChanged: (mode) => setState(() => _viewMode = mode),
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

          // ── CORPO PRINCIPAL COM STACK E LUPA FLUTUANTE QUE ACOMPANHA A ROLAGEM ──
          Expanded(
            child: Stack(
              children: [
                // CONTEÚDO PRINCIPAL (EDITOR, LADO A LADO OU PRÉVIA)
                Container(
                  color: const Color(0xFF090D16),
                  child: _buildMainBody(),
                ),

                // 🔍 LUPA FLUTUANTE DE PRÉ-VISUALIZAÇÃO RÁPIDA (SEMPRE VISÍVEL DURANTE A ROLAGEM)
                Positioned(
                  bottom: 24,
                  right: 28,
                  child: Material(
                    color: Colors.transparent,
                    elevation: 12,
                    borderRadius: BorderRadius.circular(30),
                    child: InkWell(
                      onTap: _openQuickPreviewModal,
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0284C7), Color(0xFF6366F1)], // Sky to Indigo
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6366F1).withOpacity(0.45),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                          border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.2),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.search_rounded, color: Colors.white, size: 22),
                            const SizedBox(width: 8),
                            Text(
                              'LUPA DE PRÉVIA RÁPIDA',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainBody() {
    if (_viewMode == ContractEditorViewMode.previewOnly) {
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
        child: Center(
          child: _ContractFormattedPage(
            contract: _buildCurrentContractModel(),
            company: widget.company,
            zoomLevel: _zoomLevel,
          ),
        ),
      );
    }

    if (_viewMode == ContractEditorViewMode.sideBySide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Lado Esquerdo: Editor
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Center(
                child: _buildA4EditorCanvas(),
              ),
            ),
          ),
          Container(width: 1, color: const Color(0xFF334155)),
          // Lado Direito: Prévia Renderizada ao Vivo
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Center(
                child: _ContractFormattedPage(
                  contract: _buildCurrentContractModel(),
                  company: widget.company,
                  zoomLevel: _zoomLevel * 0.9,
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Modo Padrão: Editor A4
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      child: Center(
        child: _buildA4EditorCanvas(),
      ),
    );
  }

  Widget _buildA4EditorCanvas() {
    return Container(
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MODAL DE PRÉ-VISUALIZAÇÃO RÁPIDA (LUPA TELA CHEIA)
// ─────────────────────────────────────────────────────────────────────────────
class _ContractQuickPreviewModal extends StatefulWidget {
  final ContractModel contract;
  final CompanyModel? company;
  final VoidCallback onPrint;

  const _ContractQuickPreviewModal({
    required this.contract,
    this.company,
    required this.onPrint,
  });

  @override
  State<_ContractQuickPreviewModal> createState() => _ContractQuickPreviewModalState();
}

class _ContractQuickPreviewModalState extends State<_ContractQuickPreviewModal> {
  double _previewZoom = 1.0;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0F172A),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 1000,
        height: 850,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Cabeçalho da Lupa
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.search_rounded, color: Color(0xFF38BDF8), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lupa de Pré-visualização do Contrato',
                          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        Text(
                          '${widget.contract.contractNumber} • ${widget.contract.clientName}',
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    // Zoom
                    Text('Zoom:', style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 12)),
                    const SizedBox(width: 6),
                    _ZoomButton(label: '85%', isSelected: _previewZoom == 0.85, onTap: () => setState(() => _previewZoom = 0.85)),
                    _ZoomButton(label: '100%', isSelected: _previewZoom == 1.0, onTap: () => setState(() => _previewZoom = 1.0)),
                    _ZoomButton(label: '115%', isSelected: _previewZoom == 1.15, onTap: () => setState(() => _previewZoom = 1.15)),
                    const SizedBox(width: 14),

                    // Botão Imprimir
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onPrint();
                      },
                      icon: const Icon(Icons.print_outlined, size: 16),
                      label: const Text('IMPRIMIR / PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Fechar
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(color: Color(0xFF334155), height: 1),
            const SizedBox(height: 14),

            // Conteúdo Renderizado da Folha
            Expanded(
              child: Container(
                color: const Color(0xFF090D16),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: _ContractFormattedPage(
                      contract: widget.contract,
                      company: widget.company,
                      zoomLevel: _previewZoom,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PÁGINA RENDERIZADA FORMATADA (DOCUMENTO OFICIAL LIMPO SEM <BR>)
// ─────────────────────────────────────────────────────────────────────────────
class _ContractFormattedPage extends StatelessWidget {
  final ContractModel contract;
  final CompanyModel? company;
  final double zoomLevel;

  const _ContractFormattedPage({
    required this.contract,
    this.company,
    this.zoomLevel = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final blocks = _parseTextToWidgets(contract.content, zoomLevel);

    return Container(
      width: 794 * zoomLevel,
      constraints: const BoxConstraints(minHeight: 1123),
      padding: EdgeInsets.symmetric(
        horizontal: 50 * zoomLevel,
        vertical: 48 * zoomLevel,
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
          // Cabeçalho da Empresa
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                company?.name.toUpperCase() ?? 'CONTRATO DE PRESTAÇÃO DE SERVIÇOS',
                style: GoogleFonts.inter(
                  fontSize: 9.5 * zoomLevel,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF475569),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8 * zoomLevel, vertical: 3 * zoomLevel),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Text(
                  contract.contractNumber,
                  style: GoogleFonts.inter(
                    fontSize: 9.0 * zoomLevel,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF334155),
                  ),
                ),
              ),
            ],
          ),
          Divider(color: const Color(0xFFCBD5E1), thickness: 0.8, height: 20 * zoomLevel),
          SizedBox(height: 10 * zoomLevel),

          // Blocos Formatados
          ...blocks,

          SizedBox(height: 32 * zoomLevel),
          Divider(color: const Color(0xFFCBD5E1), thickness: 0.8, height: 20 * zoomLevel),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Documento emitido via Mavis CRM • ${contract.title}',
                style: GoogleFonts.inter(fontSize: 8.5 * zoomLevel, color: const Color(0xFF94A3B8)),
              ),
              Text(
                'Página 1 de 1',
                style: GoogleFonts.inter(fontSize: 8.5 * zoomLevel, color: const Color(0xFF94A3B8)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _parseTextToWidgets(String rawText, double zoom) {
    final cleanText = rawText.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    final lines = cleanText.split('\n');
    final widgets = <Widget>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      if (line.isEmpty) {
        widgets.add(SizedBox(height: 6 * zoom));
      } else if (line.startsWith('# ')) {
        widgets.add(
          Padding(
            padding: EdgeInsets.only(top: 14 * zoom, bottom: 10 * zoom),
            child: Center(
              child: Text(
                line.substring(2).trim(),
                textAlign: TextAlign.center,
                style: GoogleFonts.merriweather(
                  fontSize: 15 * zoom,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        );
      } else if (line.startsWith('## ')) {
        widgets.add(
          Padding(
            padding: EdgeInsets.only(top: 12 * zoom, bottom: 8 * zoom),
            child: Text(
              line.substring(3).trim(),
              style: GoogleFonts.inter(
                fontSize: 12.5 * zoom,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E293B),
              ),
            ),
          ),
        );
      } else if (line.startsWith('### ')) {
        widgets.add(
          Padding(
            padding: EdgeInsets.only(top: 10 * zoom, bottom: 6 * zoom),
            child: Text(
              line.substring(4).trim(),
              style: GoogleFonts.inter(
                fontSize: 11 * zoom,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF334155),
              ),
            ),
          ),
        );
      } else if (line == '---' || line == '***') {
        widgets.add(
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8 * zoom),
            child: Divider(color: const Color(0xFFCBD5E1), thickness: 0.8),
          ),
        );
      } else if (line.startsWith('- ') || line.startsWith('• ') || line.startsWith('* ')) {
        widgets.add(
          Padding(
            padding: EdgeInsets.only(left: 14 * zoom, bottom: 4 * zoom),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: TextStyle(fontSize: 10 * zoom, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                Expanded(child: _buildRichSpan(line.substring(2).trim(), zoom)),
              ],
            ),
          ),
        );
      } else if (line.startsWith('_____')) {
        widgets.add(
          Padding(
            padding: EdgeInsets.only(top: 20 * zoom, bottom: 6 * zoom),
            child: Container(
              width: 260 * zoom,
              height: 1.0,
              color: const Color(0xFF0F172A),
            ),
          ),
        );
      } else {
        widgets.add(
          Padding(
            padding: EdgeInsets.only(bottom: 6 * zoom),
            child: _buildRichSpan(line, zoom),
          ),
        );
      }
    }

    return widgets;
  }

  Widget _buildRichSpan(String text, double zoom) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'(\*\*.*?\*\*|\*.*?\*)');
    int lastEnd = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }

      final matchedText = match.group(0)!;
      if (matchedText.startsWith('**') && matchedText.endsWith('**')) {
        spans.add(
          TextSpan(
            text: matchedText.substring(2, matchedText.length - 2),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        );
      } else if (matchedText.startsWith('*') && matchedText.endsWith('*')) {
        spans.add(
          TextSpan(
            text: matchedText.substring(1, matchedText.length - 1),
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
        );
      }
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    return RichText(
      textAlign: TextAlign.justify,
      text: TextSpan(
        style: GoogleFonts.merriweather(
          fontSize: 10.5 * zoom,
          color: const Color(0xFF1E293B),
          height: 1.6,
        ),
        children: spans.isEmpty ? [TextSpan(text: text)] : spans,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPONENTES AUXILIARES DE TOOLBAR
// ─────────────────────────────────────────────────────────────────────────────
class _ViewModeToggle extends StatelessWidget {
  final ContractEditorViewMode mode;
  final ValueChanged<ContractEditorViewMode> onChanged;

  const _ViewModeToggle({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildItem(
            icon: Icons.edit_note_rounded,
            label: 'Editor',
            isSelected: mode == ContractEditorViewMode.editorOnly,
            onTap: () => onChanged(ContractEditorViewMode.editorOnly),
          ),
          _buildItem(
            icon: Icons.vertical_split_rounded,
            label: 'Lado a Lado',
            isSelected: mode == ContractEditorViewMode.sideBySide,
            onTap: () => onChanged(ContractEditorViewMode.sideBySide),
          ),
          _buildItem(
            icon: Icons.visibility_rounded,
            label: 'Prévia',
            isSelected: mode == ContractEditorViewMode.previewOnly,
            onTap: () => onChanged(ContractEditorViewMode.previewOnly),
          ),
        ],
      ),
    );
  }

  Widget _buildItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: isSelected ? Colors.white : const Color(0xFF94A3B8)),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
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
