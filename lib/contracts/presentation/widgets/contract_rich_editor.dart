import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../auth/domain/models/user_model.dart';
import '../../../clients/domain/models/client_model.dart';
import '../../../proposals/domain/models/proposal_model.dart';
import '../../../settings/domain/models/company_model.dart';
import '../../data/services/contract_pdf_service.dart';
import '../../data/services/contract_settings_service.dart';
import '../../data/services/contract_template_engine.dart';
import '../../domain/models/contract_model.dart';

enum ContractEditorViewMode {
  editorOnly,
  sideBySide,
  previewOnly,
}

enum ContractCanvasTheme {
  dark,
  light,
}

/// Editor Visual de Contratos no estilo Word / WYSIWYG
/// Com Persistência do Modelo Personalizado por Integrador, Reversão ao Padrão do Sistema e Lupa Flutuante
class ContractRichEditor extends StatefulWidget {
  final ContractModel? initialContract;
  final ProposalModel? proposal;
  final ClientModel? client;
  final CompanyModel? company;
  final UserModel? currentUser;
  final Future<void> Function(ContractModel contract) onSave;
  final VoidCallback onCancel;

  const ContractRichEditor({
    super.key,
    this.initialContract,
    this.proposal,
    this.client,
    this.company,
    this.currentUser,
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
  ContractCanvasTheme _canvasTheme = ContractCanvasTheme.dark; // Padrão Dark Mode com texto branco
  bool _isSaving = false;
  bool _isGeneratingPdf = false;
  bool _isSavingTemplate = false;
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

    // Se for novo contrato, verifica se existe template customizado salvo para esta empresa
    if (widget.initialContract == null && widget.company != null) {
      _loadCustomCompanyTemplate();
    }
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    _titleCtrl.dispose();
    _contractNumberCtrl.dispose();
    super.dispose();
  }

  /// Carrega o modelo salvo da empresa se existir
  Future<void> _loadCustomCompanyTemplate() async {
    final companyId = widget.company?.id;
    if (companyId == null || companyId.isEmpty) return;

    try {
      final customTpl = await ContractSettingsService.getCompanyCustomTemplate(companyId);
      final customTitle = await ContractSettingsService.getCompanyCustomTitle(companyId);

      if (customTpl != null && customTpl.trim().isNotEmpty && mounted) {
        final generated = ContractTemplateEngine.generateContractText(
          proposal: widget.proposal!,
          client: widget.client,
          company: widget.company,
          customTemplate: customTpl,
          contractNumber: _contractNumberCtrl.text,
        );
        setState(() {
          _contentCtrl.text = _sanitizeContent(generated);
          if (customTitle != null && customTitle.isNotEmpty) {
            _titleCtrl.text = customTitle;
          }
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar modelo customizado da empresa: $e');
    }
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

  /// Salva as alterações feitas no texto atual como o NOVO MODELO PADRÃO DA EMPRESA
  Future<void> _saveAsCompanyDefaultTemplate() async {
    final companyId = widget.company?.id;
    if (companyId == null || companyId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível identificar a empresa vinculada para salvar o modelo.')),
      );
      return;
    }

    setState(() => _isSavingTemplate = true);
    try {
      final currentContent = _sanitizeContent(_contentCtrl.text);
      final currentTitle = _titleCtrl.text.trim();

      await ContractSettingsService.saveCompanyCustomTemplate(
        companyId: companyId,
        templateContent: currentContent,
        customTitle: currentTitle,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ As alterações foram salvas como MODELO PADRÃO da sua empresa para os próximos contratos!'),
            backgroundColor: Color(0xFF059669),
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar modelo: $e'), backgroundColor: const Color(0xFFDC2626)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingTemplate = false);
    }
  }

  /// Reverte e restaura para o modelo padrão oficial do sistema com diálogo de aviso
  Future<void> _restoreSystemDefaultWithWarning() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFF87171), size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Restaurar Padrão do Sistema?',
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '⚠️ ATENÇÃO:',
              style: GoogleFonts.inter(color: const Color(0xFFF87171), fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Text(
              'Ao restaurar o padrão do sistema, todas as personalizações salvas para a sua empresa (como títulos customizados, cláusulas modificadas e alterações feitas por você) SERÃO RESETADAS.',
              style: GoogleFonts.inter(color: const Color(0xFFE2E8F0), fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 10),
            Text(
              'Os novos contratos voltarão a ser gerados utilizando o modelo oficial padrão de 5 páginas do Mavis CRM.',
              style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 12.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('CANCELAR', style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.restart_alt_rounded, size: 18),
            label: const Text('RESETAR & RESTAURAR PADRÃO', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // 1. Limpa o modelo customizado no Firestore
      if (widget.company?.id != null) {
        await ContractSettingsService.resetCompanyTemplateToDefault(companyId: widget.company!.id);
      }

      // 2. Regenera o texto na tela usando o template oficial original
      if (widget.proposal != null) {
        final defaultGenerated = ContractTemplateEngine.generateContractText(
          proposal: widget.proposal!,
          client: widget.client,
          company: widget.company,
          customTemplate: null, // Força o padrão oficial
          contractNumber: _contractNumberCtrl.text,
        );
        setState(() {
          _contentCtrl.text = _sanitizeContent(defaultGenerated);
          _titleCtrl.text = 'Contrato de Prestação de Serviços - ${widget.client?.name ?? widget.proposal!.clientName}';
        });
      } else {
        setState(() {
          _contentCtrl.text = _sanitizeContent(ContractTemplateEngine.defaultContractTemplate);
          _titleCtrl.text = 'Contrato de Prestação de Serviços Fotovoltaicos';
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ O contrato foi resetado para o modelo padrão oficial do sistema com sucesso.'),
            backgroundColor: Color(0xFF059669),
          ),
        );
      }
    }
  }

  /// Abre a Lupa de Visualização Rápida em Modal Tela Cheia
  void _openQuickPreviewModal() {
    final contract = _buildCurrentContractModel();
    showDialog(
      context: context,
      builder: (ctx) => _ContractQuickPreviewModal(
        contract: contract,
        company: widget.company,
        canvasTheme: _canvasTheme,
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

    final effectiveCompanyId = widget.initialContract?.companyId ??
        comp?.id ??
        prop?.companyId ??
        widget.currentUser?.effectiveCompanyId ??
        widget.currentUser?.companyId;

    final effectiveCompanyName = comp?.name ??
        widget.initialContract?.companyName ??
        'Integrador Solar';

    final effectiveCompanyDoc = comp?.document ??
        widget.initialContract?.companyDocument;

    final effectiveCreatedByUserId = widget.initialContract?.createdByUserId ??
        prop?.createdByUserId ??
        widget.currentUser?.uid;

    final effectiveCreatedByUserName = widget.initialContract?.createdByUserName ??
        prop?.createdByUserName ??
        widget.currentUser?.name;

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
      companyId: effectiveCompanyId,
      companyName: effectiveCompanyName,
      companyDocument: effectiveCompanyDoc,
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
      createdByUserId: effectiveCreatedByUserId,
      createdByUserName: effectiveCreatedByUserName,
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

      // Salva automaticamente as alterações estruturais como o modelo padrão do integrador
      if (widget.company?.id != null && widget.company!.id.isNotEmpty) {
        ContractSettingsService.saveCompanyCustomTemplate(
          companyId: widget.company!.id,
          templateContent: contract.content,
          customTitle: contract.title,
        ).catchError((_) {});
      }

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
                                    Text(tag.label, style: const TextStyle(fontFamily: 'Arial', color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
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

                  // 💾 Botão Salvar como Padrão da Minha Empresa
                  Tooltip(
                    message: 'Salva as alterações deste contrato como o modelo padrão para os próximos contratos da sua empresa',
                    child: TextButton.icon(
                      onPressed: _isSavingTemplate ? null : _saveAsCompanyDefaultTemplate,
                      icon: _isSavingTemplate
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981)))
                          : const Icon(Icons.bookmark_add_outlined, size: 16, color: Color(0xFF10B981)),
                      label: Text(
                        'Salvar Padrão da Empresa',
                        style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
                      ),
                    ),
                  ),

                  const SizedBox(width: 6),

                  // 🔄 Botão Restaurar Padrão do Sistema (Com Diálogo de Aviso)
                  Tooltip(
                    message: 'Reseta todas as alterações da sua empresa e volta para o contrato oficial do sistema',
                    child: TextButton.icon(
                      onPressed: _restoreSystemDefaultWithWarning,
                      icon: const Icon(Icons.restart_alt_rounded, size: 16, color: Color(0xFFF87171)),
                      label: Text(
                        'Restaurar Padrão do Sistema',
                        style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFFF87171)),
                      ),
                    ),
                  ),

                  const VerticalDivider(color: Color(0xFF334155), width: 24, thickness: 1),

                  // Alternador de Modo de Visualização (Editor | Lado a Lado | Prévia)
                  _ViewModeToggle(
                    mode: _viewMode,
                    onChanged: (mode) => setState(() => _viewMode = mode),
                  ),

                  const VerticalDivider(color: Color(0xFF334155), width: 24, thickness: 1),

                  // Alternador de Cor da Folha (Dark Mode vs Light Mode)
                  _ThemeToggle(
                    theme: _canvasTheme,
                    onChanged: (th) => setState(() => _canvasTheme = th),
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
            canvasTheme: _canvasTheme,
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
                  canvasTheme: _canvasTheme,
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
    final isDark = _canvasTheme == ContractCanvasTheme.dark;
    final bgColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFFFF);
    final headerColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    final dividerColor = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
    final textColor = isDark ? const Color(0xFFFFFFFF) : const Color(0xFF0F172A);
    final cursorColor = isDark ? const Color(0xFF38BDF8) : const Color(0xFF2563EB);

    return Theme(
      data: (isDark ? ThemeData.dark() : ThemeData.light()).copyWith(
        textTheme: TextTheme(
          bodyMedium: TextStyle(
            fontFamily: 'Arial',
            fontSize: 13.0 * _zoomLevel,
            color: textColor,
            height: 1.65,
          ),
        ),
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: cursorColor,
          selectionColor: (isDark ? const Color(0xFF6366F1) : const Color(0xFF93C5FD)).withOpacity(0.4),
          selectionHandleColor: cursorColor,
        ),
      ),
      child: Container(
        width: 794 * _zoomLevel, // Proporção da folha A4 em pixels
        constraints: const BoxConstraints(minHeight: 1123), // Altura mínima A4
        padding: EdgeInsets.symmetric(
          horizontal: 50 * _zoomLevel,
          vertical: 48 * _zoomLevel,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.6 : 0.18),
              blurRadius: 24,
              offset: const Offset(0, 10),
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
                  style: TextStyle(
                    fontFamily: 'Arial',
                    fontSize: 9.5 * _zoomLevel,
                    fontWeight: FontWeight.bold,
                    color: headerColor,
                    letterSpacing: 0.5,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8 * _zoomLevel, vertical: 3 * _zoomLevel),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: dividerColor),
                  ),
                  child: Text(
                    _contractNumberCtrl.text,
                    style: TextStyle(
                      fontFamily: 'Arial',
                      fontSize: 9.0 * _zoomLevel,
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFF818CF8) : const Color(0xFF334155),
                    ),
                  ),
                ),
              ],
            ),
            Divider(color: dividerColor, thickness: 0.8, height: 18 * _zoomLevel),
            SizedBox(height: 12 * _zoomLevel),

            // Campo de Texto Editável em Tempo Real com Fonte Arial e Contraste Adaptativo
            TextField(
              controller: _contentCtrl,
              maxLines: null,
              style: TextStyle(
                fontFamily: 'Arial',
                fontSize: 13.0 * _zoomLevel,
                color: textColor,
                fontWeight: FontWeight.w400,
                height: 1.65,
                letterSpacing: 0.15,
              ),
              cursorColor: cursorColor,
              cursorWidth: 2.2,
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                hintStyle: TextStyle(
                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                  fontFamily: 'Arial',
                ),
              ),
            ),

            SizedBox(height: 36 * _zoomLevel),
            Divider(color: dividerColor, thickness: 0.8, height: 18 * _zoomLevel),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Documento emitido via Mavis CRM • ${widget.client?.name ?? "Cliente"}',
                  style: TextStyle(fontFamily: 'Arial', fontSize: 8.5 * _zoomLevel, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
                Text(
                  'Página 1 de 1',
                  style: TextStyle(fontFamily: 'Arial', fontSize: 8.5 * _zoomLevel, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ],
            ),
          ],
        ),
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
  final ContractCanvasTheme canvasTheme;
  final VoidCallback onPrint;

  const _ContractQuickPreviewModal({
    required this.contract,
    this.company,
    required this.canvasTheme,
    required this.onPrint,
  });

  @override
  State<_ContractQuickPreviewModal> createState() => _ContractQuickPreviewModalState();
}

class _ContractQuickPreviewModalState extends State<_ContractQuickPreviewModal> {
  double _previewZoom = 1.0;
  late ContractCanvasTheme _theme;

  @override
  void initState() {
    super.initState();
    _theme = widget.canvasTheme;
  }

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
                          'Lupa de Pré-visualização do Contrato (Arial)',
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
                    // Alternador de tema no modal
                    _ThemeToggle(theme: _theme, onChanged: (th) => setState(() => _theme = th)),
                    const SizedBox(width: 14),

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
                      canvasTheme: _theme,
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
// PÁGINA RENDERIZADA FORMATADA (FONTE ARIAL E SUPORTE A TEXTO BRANCO EM DARK)
// ─────────────────────────────────────────────────────────────────────────────
class _ContractFormattedPage extends StatelessWidget {
  final ContractModel contract;
  final CompanyModel? company;
  final ContractCanvasTheme canvasTheme;
  final double zoomLevel;

  const _ContractFormattedPage({
    required this.contract,
    this.company,
    this.canvasTheme = ContractCanvasTheme.dark,
    this.zoomLevel = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = canvasTheme == ContractCanvasTheme.dark;
    final bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final headerColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    final dividerColor = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);

    final blocks = _parseTextToWidgets(contract.content, zoomLevel, isDark);

    return Container(
      width: 794 * zoomLevel,
      constraints: const BoxConstraints(minHeight: 1123),
      padding: EdgeInsets.symmetric(
        horizontal: 50 * zoomLevel,
        vertical: 48 * zoomLevel,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.6 : 0.25),
            blurRadius: 24,
            offset: const Offset(0, 10),
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
                style: TextStyle(
                  fontFamily: 'Arial',
                  fontSize: 9.5 * zoomLevel,
                  fontWeight: FontWeight.bold,
                  color: headerColor,
                  letterSpacing: 0.5,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8 * zoomLevel, vertical: 3 * zoomLevel),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: dividerColor),
                ),
                child: Text(
                  contract.contractNumber,
                  style: TextStyle(
                    fontFamily: 'Arial',
                    fontSize: 9.0 * zoomLevel,
                    fontWeight: FontWeight.bold,
                    color: isDark ? const Color(0xFF818CF8) : const Color(0xFF334155),
                  ),
                ),
              ),
            ],
          ),
          Divider(color: dividerColor, thickness: 0.8, height: 20 * zoomLevel),
          SizedBox(height: 10 * zoomLevel),

          // Blocos Formatados
          ...blocks,

          SizedBox(height: 36 * zoomLevel),
          Divider(color: dividerColor, thickness: 0.8, height: 20 * zoomLevel),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Documento emitido via Mavis CRM • ${contract.title}',
                style: TextStyle(fontFamily: 'Arial', fontSize: 8.5 * zoomLevel, color: const Color(0xFF94A3B8)),
              ),
              Text(
                'Página 1 de 1',
                style: TextStyle(fontFamily: 'Arial', fontSize: 8.5 * zoomLevel, color: const Color(0xFF94A3B8)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _parseTextToWidgets(String rawText, double zoom, bool isDark) {
    final cleanText = rawText.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    final lines = cleanText.split('\n');
    final widgets = <Widget>[];

    final h1Color = isDark ? Colors.white : const Color(0xFF0F172A);
    final h2Color = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B);
    final h3Color = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155);
    final dividerColor = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);

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
                style: TextStyle(
                  fontFamily: 'Arial',
                  fontSize: 15 * zoom,
                  fontWeight: FontWeight.bold,
                  color: h1Color,
                  decoration: TextDecoration.underline,
                  letterSpacing: 0.5,
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
              style: TextStyle(
                fontFamily: 'Arial',
                fontSize: 12.5 * zoom,
                fontWeight: FontWeight.bold,
                color: h2Color,
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
              style: TextStyle(
                fontFamily: 'Arial',
                fontSize: 11.5 * zoom,
                fontWeight: FontWeight.bold,
                color: h3Color,
              ),
            ),
          ),
        );
      } else if (line == '---' || line == '***') {
        widgets.add(
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8 * zoom),
            child: Divider(color: dividerColor, thickness: 0.8),
          ),
        );
      } else if (line.startsWith('- ') || line.startsWith('• ') || line.startsWith('* ')) {
        widgets.add(
          Padding(
            padding: EdgeInsets.only(left: 14 * zoom, bottom: 4 * zoom),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: TextStyle(fontFamily: 'Arial', fontSize: 11 * zoom, fontWeight: FontWeight.bold, color: h1Color)),
                Expanded(child: _buildRichSpan(line.substring(2).trim(), zoom, isDark)),
              ],
            ),
          ),
        );
      } else if (line.startsWith('_____')) {
        widgets.add(
          Padding(
            padding: EdgeInsets.only(top: 22 * zoom, bottom: 6 * zoom),
            child: Container(
              width: 260 * zoom,
              height: 1.2,
              color: h1Color,
            ),
          ),
        );
      } else {
        widgets.add(
          Padding(
            padding: EdgeInsets.only(bottom: 6 * zoom),
            child: _buildRichSpan(line, zoom, isDark),
          ),
        );
      }
    }

    return widgets;
  }

  Widget _buildRichSpan(String text, double zoom, bool isDark) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'(\*\*.*?\*\*|\*.*?\*)');
    int lastEnd = 0;

    final defaultTextColor = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);

    for (final match in regex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }

      final matchedText = match.group(0)!;
      if (matchedText.startsWith('**') && matchedText.endsWith('**')) {
        spans.add(
          TextSpan(
            text: matchedText.substring(2, matchedText.length - 2),
            style: TextStyle(
              fontFamily: 'Arial',
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
        );
      } else if (matchedText.startsWith('*') && matchedText.endsWith('*')) {
        spans.add(
          TextSpan(
            text: matchedText.substring(1, matchedText.length - 1),
            style: const TextStyle(
              fontFamily: 'Arial',
              fontStyle: FontStyle.italic,
            ),
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
        style: TextStyle(
          fontFamily: 'Arial',
          fontSize: 11.0 * zoom,
          color: defaultTextColor,
          height: 1.65,
          letterSpacing: 0.1,
        ),
        children: spans.isEmpty ? [TextSpan(text: text)] : spans,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPONENTES AUXILIARES DE TOOLBAR
// ─────────────────────────────────────────────────────────────────────────────
class _ThemeToggle extends StatelessWidget {
  final ContractCanvasTheme theme;
  final ValueChanged<ContractCanvasTheme> onChanged;

  const _ThemeToggle({required this.theme, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = theme == ContractCanvasTheme.dark;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => onChanged(ContractCanvasTheme.dark),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF6366F1) : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(Icons.dark_mode_rounded, size: 14, color: isDark ? Colors.white : const Color(0xFF94A3B8)),
                  const SizedBox(width: 4),
                  Text('Dark', style: GoogleFonts.inter(fontSize: 11, fontWeight: isDark ? FontWeight.bold : FontWeight.normal, color: isDark ? Colors.white : const Color(0xFF94A3B8))),
                ],
              ),
            ),
          ),
          InkWell(
            onTap: () => onChanged(ContractCanvasTheme.light),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: !isDark ? const Color(0xFF6366F1) : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(Icons.light_mode_rounded, size: 14, color: !isDark ? Colors.white : const Color(0xFF94A3B8)),
                  const SizedBox(width: 4),
                  Text('Claro', style: GoogleFonts.inter(fontSize: 11, fontWeight: !isDark ? FontWeight.bold : FontWeight.normal, color: !isDark ? Colors.white : const Color(0xFF94A3B8))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
