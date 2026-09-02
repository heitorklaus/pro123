import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../../clients/data/repositories/client_repository.dart';
import '../../../clients/domain/models/client_model.dart';
import '../../../products/data/services/gemini_solar_vision_service.dart';
import '../../../settings/data/services/system_settings_service.dart';
import '../../data/services/gemini_proposal_assistant_service.dart';
import '../../domain/models/proposal_item_model.dart';

/// Formatter simples de moeda BRL para inputs
class _CurrencyPtBrFormatter {
  static String format(double value) {
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$ ', decimalDigits: 2);
    return fmt.format(value);
  }

  static double parse(String text) {
    final clean = text
        .replaceAll('R\$', '')
        .replaceAll('.', '')
        .replaceAll(',', '.')
        .trim();
    return double.tryParse(clean) ?? 0.0;
  }
}

/// Modal Interativo Completo com IA para Análise Multi-Arquivos & Criação de Proposta por Texto Livre
class ProposalAiAssistantDialog extends StatefulWidget {
  final Function(ParsedUnifiedProposal parsedProposal, ClientModel? linkedClient, ProposalItemModel solarPlantItem) onProposalReady;

  const ProposalAiAssistantDialog({
    super.key,
    required this.onProposalReady,
  });

  @override
  State<ProposalAiAssistantDialog> createState() => _ProposalAiAssistantDialogState();
}

class _ProposalAiAssistantDialogState extends State<ProposalAiAssistantDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final ClientRepository _clientRepo;
  late final AuthRepository _authRepo;

  // Controllers de Texto
  final _promptController = TextEditingController();
  final _additionalNotesController = TextEditingController();

  // Controllers do Step Final de Ajuste
  final _servicePriceCtrl = TextEditingController(text: 'R\$ 0,00');
  final _productsPriceCtrl = TextEditingController(text: 'R\$ 0,00');
  final _generationKwhCtrl = TextEditingController(text: '0');
  final _roofTypeCtrl = TextEditingController(text: 'Cerâmico');

  // Estado dos Arquivos
  final List<ProposalFilePayload> _selectedFiles = [];
  bool _isAnalyzing = false;
  String? _errorMessage;
  String? _savedApiKey;

  // Resultado da Análise da IA
  ParsedUnifiedProposal? _analyzedResult;
  ClientModel? _existingClientFound;
  final bool _autoCreateOrLinkClient = true;

  final List<String> _roofOptions = [
    'Cerâmico',
    'Metálico',
    'Fibrocimento',
    'Isotérmico',
    'Solo',
    'Laje',
    'Sem Estrutura',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
    _loadApiKey();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _promptController.dispose();
    _additionalNotesController.dispose();
    _servicePriceCtrl.dispose();
    _productsPriceCtrl.dispose();
    _generationKwhCtrl.dispose();
    _roofTypeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadApiKey() async {
    final key = await GeminiSolarVisionService.getSavedApiKey();
    if (mounted) {
      setState(() {
        _savedApiKey = key.isNotEmpty ? key : null;
      });
    }
  }

  /// Seleciona um ou múltiplos arquivos simultaneamente (Cotação + Documento do Cliente)
  Future<void> _pickFiles() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'webp', 'txt'],
      );

      if (files.isEmpty) return;

      for (final file in files) {
        final bytes = await file.readAsBytes();

        if (bytes.isNotEmpty) {
          final ext = file.extension?.toLowerCase() ?? (file.name.split('.').last.toLowerCase());
          setState(() {
            _selectedFiles.add(
              ProposalFilePayload(
                name: file.name,
                extension: ext,
                bytes: bytes,
              ),
            );
          });
        }
      }
      setState(() => _errorMessage = null);
    } catch (e) {
      setState(() => _errorMessage = 'Erro ao carregar arquivos: $e');
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  /// Executa o processamento com IA Gemini
  Future<void> _runAnalysis({bool fromPromptTab = false}) async {
    final filesToProcess = fromPromptTab ? <ProposalFilePayload>[] : _selectedFiles;
    final promptText = fromPromptTab
        ? _promptController.text.trim()
        : _additionalNotesController.text.trim();

    if (filesToProcess.isEmpty && promptText.isEmpty) {
      setState(() => _errorMessage = 'Selecione ao menos um arquivo ou digite as instruções da proposta.');
      return;
    }

    if (!mounted) return;

    // Valida permissão e cota diária de IA
    final canProceed = await SystemSettingsService.checkAndConsumeAiQuota(context);
    if (!canProceed) return;

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
      _analyzedResult = null;
      _existingClientFound = null;
    });

    try {
      final activeKey = (_savedApiKey != null && _savedApiKey!.isNotEmpty)
          ? _savedApiKey
          : await GeminiSolarVisionService.getSavedApiKey();

      final result = await GeminiProposalAssistantService.analyzeProposal(
        files: filesToProcess.isNotEmpty ? filesToProcess : null,
        textPrompt: promptText.isNotEmpty ? promptText : null,
        customApiKey: activeKey,
      );

      // Preenche os campos do passo final
      _productsPriceCtrl.text = _CurrencyPtBrFormatter.format(result.productsPrice);
      _servicePriceCtrl.text = _CurrencyPtBrFormatter.format(result.servicePrice);
      _generationKwhCtrl.text = result.generationKwh != null
          ? result.generationKwh!.toStringAsFixed(0)
          : (result.kilowatts > 0 ? (result.kilowatts * 125).toStringAsFixed(0) : '0');
      _roofTypeCtrl.text = result.roofType;

      // Verifica se o cliente já existe no Firestore da empresa
      if (result.hasClientData) {
        await _checkIfClientExists(result);
      }

      if (mounted) {
        setState(() {
          _analyzedResult = result;
          _isAnalyzing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _errorMessage = 'Erro no processamento da IA: $e';
        });
      }
    }
  }

  /// Busca se o cliente já está cadastrado no CRM
  Future<void> _checkIfClientExists(ParsedUnifiedProposal result) async {
    try {
      final user = await _authRepo.getCurrentUser();
      final companyId = user?.effectiveCompanyId ?? await _authRepo.getCurrentCompanyId();
      final clients = await _clientRepo.getClientsStream(companyId: companyId).first;

      ClientModel? match;
      if (result.clientDocument != null && result.clientDocument!.trim().isNotEmpty) {
        final cleanDoc = result.clientDocument!.replaceAll(RegExp(r'[^\d]'), '');
        match = clients.cast<ClientModel?>().firstWhere(
              (c) => c?.document != null && c!.document!.replaceAll(RegExp(r'[^\d]'), '') == cleanDoc,
              orElse: () => null,
            );
      }

      if (match == null && result.clientName != null && result.clientName!.trim().isNotEmpty) {
        final lowerName = result.clientName!.toLowerCase().trim();
        match = clients.cast<ClientModel?>().firstWhere(
              (c) => c?.name.toLowerCase().trim() == lowerName,
              orElse: () => null,
            );
      }

      if (match != null && mounted) {
        setState(() {
          _existingClientFound = match;
        });
      }
    } catch (_) {}
  }

  /// Conclui o processo, salva/vincula cliente, cria usina e despacha para a proposta
  Future<void> _confirmAndGenerateProposal() async {
    if (_analyzedResult == null) return;

    setState(() => _isAnalyzing = true);

    try {
      final user = await _authRepo.getCurrentUser();
      final companyId = user?.effectiveCompanyId ?? await _authRepo.getCurrentCompanyId();

      final parsedProdPrice = _CurrencyPtBrFormatter.parse(_productsPriceCtrl.text);
      final parsedServPrice = _CurrencyPtBrFormatter.parse(_servicePriceCtrl.text);
      final parsedGenKwh = double.tryParse(_generationKwhCtrl.text.trim()) ??
          _analyzedResult!.generationKwh ??
          0.0;
      final selectedRoof = _roofTypeCtrl.text.trim();

      // 1. Vinculação ou Criação do Cliente
      ClientModel? finalClient = _existingClientFound;
      if (_autoCreateOrLinkClient && finalClient == null && _analyzedResult!.hasClientData) {
        // Cria o cliente no banco
        finalClient = await _clientRepo.createClient(
          name: _analyzedResult!.clientName ?? 'Cliente Identificado IA',
          email: _analyzedResult!.clientEmail ?? 'cliente@mavis.com',
          phone: _analyzedResult!.clientPhone,
          document: _analyzedResult!.clientDocument,
          type: (_analyzedResult!.clientType?.toLowerCase() == 'company' ||
                  (_analyzedResult!.clientDocument != null && _analyzedResult!.clientDocument!.length > 14))
              ? ClientType.company
              : ClientType.person,
          street: _analyzedResult!.street,
          addressNumber: _analyzedResult!.addressNumber,
          complement: _analyzedResult!.complement,
          neighborhood: _analyzedResult!.neighborhood,
          city: _analyzedResult!.city,
          state: _analyzedResult!.state,
          zipCode: _analyzedResult!.zipCode,
          notes: 'Cadastrado automaticamente via Assistente de IA.${_analyzedResult!.ucNumber != null ? " UC: ${_analyzedResult!.ucNumber}" : ""}',
          companyId: companyId,
        );
      }

      // 2. Atualiza os dados consolidados da proposta
      final updatedProposal = _analyzedResult!.copyWith(
        clientId: finalClient?.id,
        clientName: finalClient?.name ?? _analyzedResult!.clientName,
        clientDocument: finalClient?.document ?? _analyzedResult!.clientDocument,
        clientEmail: finalClient?.email ?? _analyzedResult!.clientEmail,
        clientPhone: finalClient?.phone ?? _analyzedResult!.clientPhone,
        street: finalClient?.street ?? _analyzedResult!.street,
        addressNumber: finalClient?.addressNumber ?? _analyzedResult!.addressNumber,
        neighborhood: finalClient?.neighborhood ?? _analyzedResult!.neighborhood,
        city: finalClient?.city ?? _analyzedResult!.city,
        state: finalClient?.state ?? _analyzedResult!.state,
        zipCode: finalClient?.zipCode ?? _analyzedResult!.zipCode,
        productsPrice: parsedProdPrice,
        servicePrice: parsedServPrice,
        generationKwh: parsedGenKwh,
        roofType: selectedRoof,
        totalAmount: parsedProdPrice + parsedServPrice,
      );

      // 3. Converte a Usina Solar em Item de Proposta
      final solarPlantItem = updatedProposal.toSolarPlantProposalItem();

      // 4. Notifica o callback e fecha o modal
      widget.onProposalReady(updatedProposal, finalClient, solarPlantItem);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _errorMessage = 'Erro ao consolidar proposta: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24, vertical: 20),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 960, maxHeight: 850),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 40,
              offset: const Offset(0, 16),
            ),
            BoxShadow(
              color: const Color(0xFF6366F1).withValues(alpha: 0.15),
              blurRadius: 25,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            children: [
              // ── Header Gradiente Futurista ────────────────────────────────
              _buildHeader(isMobile),

              // ── Corpo do Dialog ──────────────────────────────────────────
              Expanded(
                child: _isAnalyzing
                    ? _buildLoadingState()
                    : (_analyzedResult != null
                        ? _buildReviewAndConfirmationStep(isMobile)
                        : _buildInputTabs(isMobile)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E1B4B), Color(0xFF312E81)],
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'Assistente IA de Propostas',
                      style: GoogleFonts.outfit(
                        fontSize: isMobile ? 17 : 19,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF10B981), width: 1),
                      ),
                      child: Text(
                        'MULTIMODAL',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF34D399),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Analise cotações e documentos juntos, ou monte propostas direto por texto.',
                  style: GoogleFonts.inter(
                    fontSize: isMobile ? 11.5 : 12.5,
                    color: const Color(0xFFCBD5E1),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, color: Colors.white70),
            tooltip: 'Fechar',
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                    blurRadius: 30,
                    spreadRadius: 8,
                  ),
                ],
              ),
              child: const CircularProgressIndicator(
                color: Color(0xFF6366F1),
                strokeWidth: 3.5,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Inteligência Artificial Processando...',
              style: GoogleFonts.outfit(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Identificando cotação vs documento do cliente, dimensionando kit e associando dados.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13.5,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputTabs(bool isMobile) {
    return Column(
      children: [
        // Tabs
        Container(
          color: const Color(0xFFF8FAFC),
          child: TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF6366F1),
            unselectedLabelColor: const Color(0xFF64748B),
            indicatorColor: const Color(0xFF6366F1),
            indicatorWeight: 3,
            labelStyle: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.bold),
            tabs: const [
              Tab(
                icon: Icon(Icons.drive_folder_upload_rounded, size: 20),
                text: 'Upload de Arquivos (Cotação + Documento)',
              ),
              Tab(
                icon: Icon(Icons.chat_bubble_outline_rounded, size: 20),
                text: 'Digitar Texto Livre / Chat',
              ),
            ],
          ),
        ),

        // Error message if any
        if (_errorMessage != null)
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: GoogleFonts.inter(color: const Color(0xFF991B1B), fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

        // Tab Views
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildFilesUploadTab(isMobile),
              _buildTextPromptTab(isMobile),
            ],
          ),
        ),
      ],
    );
  }

  // ── ABA 1: UPLOAD DE ARQUIVOS (COTAÇÃO + DOCUMENTO DO CLIENTE) ──────────────
  Widget _buildFilesUploadTab(bool isMobile) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Dropzone / File Picker Card
          InkWell(
            onTap: _pickFiles,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFCBD5E1),
                  width: 1.8,
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEEF2FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.cloud_upload_rounded,
                      color: Color(0xFF6366F1),
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Clique para selecionar os arquivos',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Envie a COTAÇÃO FOTOVOLTAICA e o DOCUMENTO DO CLIENTE (CNH, RG ou Conta de Energia) juntos.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Formatos suportados: PDF, JPG, PNG, WEBP ou TXT (Permite múltiplos)',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Lista de Arquivos Selecionados
          if (_selectedFiles.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              'Arquivos Selecionados (${_selectedFiles.length})',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 8),
            ...List.generate(_selectedFiles.length, (index) {
              final file = _selectedFiles[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      file.extension == 'pdf'
                          ? Icons.picture_as_pdf_rounded
                          : Icons.image_rounded,
                      color: file.extension == 'pdf'
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF3B82F6),
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            file.name,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Arquivo ${index + 1} • ${(file.bytes.length / 1024).toStringAsFixed(1)} KB',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: Color(0xFFEF4444), size: 20),
                      onPressed: () => _removeFile(index),
                      tooltip: 'Remover',
                    ),
                  ],
                ),
              );
            }),
          ],

          const SizedBox(height: 16),

          // Instruções Adicionais Opcionais
          Text(
            'Instruções ou Observações Adicionais (Opcional)',
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _additionalNotesController,
            maxLines: 2,
            style: GoogleFonts.inter(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Ex: Valor do serviço R\$ 8.000, telhado fibrocimento, validade 10 dias...',
              hintStyle: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF94A3B8)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Botão Analisar Arquivos
          Container(
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
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
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _runAnalysis(fromPromptTab: false),
              icon: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
              label: Text(
                'ANALISAR ARQUIVOS COM IA',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── ABA 2: PROMPT EM TEXTO LIVRE / CHAT ─────────────────────────────────────
  Widget _buildTextPromptTab(bool isMobile) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Descreva a Proposta ou Cole o Texto da Cotação / WhatsApp',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _promptController,
            maxLines: 6,
            style: GoogleFonts.inter(fontSize: 13.5, color: const Color(0xFF0F172A)),
            decoration: InputDecoration(
              hintText: 'Exemplo:\n"Monte uma proposta pra mim com 15 placas de 615W e 1 inversor AUXSOL de 8kw, com geração de 1000kwh mes e valor de servico R\$ 10.000 para o cliente João Silva em Cuiabá MT"',
              hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.all(16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.8),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Chips com Exemplos Rápidos
          Text(
            '💡 Exemplos e Sugestões Rápidas (Clique para testar):',
            style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildSuggestionChip(
                '15 placas 615W + Inversor AUXSOL 8kW + 1000 kWh + Serviço R\$ 10.000',
                'Monte uma proposta pra mim com 15 placas de 615W e 1 inversor AUXSOL de 8kw, com geração de 1000kwh mes e valor de servico R\$ 10.000',
              ),
              _buildSuggestionChip(
                'Kit 24 placas 580W + Deye 12kW + Telhado Metálico + Serviço R\$ 12.000',
                'Proposta comercial: Kit com 24 placas solares 580W Canadian, 1 Inversor Deye 12kW, telhado metálico, geração de 1800 kWh/mês e valor de serviço R\$ 12.000',
              ),
              _buildSuggestionChip(
                'Cliente Supermercado Alvorada CNPJ + Usina 25kWp + Serviço R\$ 15.000',
                'Cliente: Supermercado Alvorada Ltda, CNPJ 12.345.678/0001-90, Cuiabá MT. Kit de 42 módulos 615W TCL e 1 Inversor 25kW, geração de 3200 kWh/mês, serviço de R\$ 15.000',
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Botão Processar Prompt
          Container(
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
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
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _runAnalysis(fromPromptTab: true),
              icon: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
              label: Text(
                'PROCESSAR INSTRUÇÕES COM IA',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String label, String textToInsert) {
    return InkWell(
      onTap: () {
        setState(() {
          _promptController.text = textToInsert;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFEEF2FF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFC7D2FE)),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF4338CA), fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  // ── PASSO FINAL: REVISÃO, AJUSTE DE GERAÇÃO & VALOR DE SERVIÇO ──────────────
  Widget _buildReviewAndConfirmationStep(bool isMobile) {
    final result = _analyzedResult!;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Banner de Sucesso
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Análise Concluída com Sucesso!',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF065F46),
                              ),
                            ),
                            Text(
                              result.aiSummary ?? 'Dados estruturados prontos para emissão da proposta comercial.',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: const Color(0xFF047857),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Card 1: Cliente Identificado ─────────────────────────────
                if (result.hasClientData) ...[
                  _buildClientCard(result),
                  const SizedBox(height: 16),
                ],

                // ── Card 2: Usina Fotovoltaica & Equipamentos ─────────────────
                _buildPlantCard(result),

                const SizedBox(height: 16),

                // ── Card 3: Ajustes Finais (Geração em kWh e Valor do Serviço)
                _buildFinalAdjustmentsCard(result),
              ],
            ),
          ),
        ),

        // Barra Inferior de Ações
        Container(
          padding: EdgeInsets.all(isMobile ? 16 : 20),
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  setState(() {
                    _analyzedResult = null;
                  });
                },
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: Text('Nova Análise', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              ),
              const Spacer(),
              Container(
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                  ),
                  onPressed: _confirmAndGenerateProposal,
                  icon: const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 20),
                  label: Text(
                    'GERAR PROPOSTA COMERCIAL',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildClientCard(ParsedUnifiedProposal result) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFEEF2FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_rounded, color: Color(0xFF6366F1), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.clientName ?? 'Cliente Identificado',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    if (result.clientDocument != null)
                      Text(
                        'Documento: ${result.clientDocument!}',
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                      ),
                  ],
                ),
              ),
              if (_existingClientFound != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Text(
                    'CLIENTE JÁ CADASTRADO',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF166534),
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFCD34D)),
                  ),
                  child: Text(
                    'NOVO CLIENTE',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF92400E),
                    ),
                  ),
                ),
            ],
          ),
          const Divider(height: 24),
          Wrap(
            spacing: 20,
            runSpacing: 8,
            children: [
              if (result.city != null)
                _infoBadge(Icons.location_city_rounded, '${result.city}${result.state != null ? "/${result.state}" : ""}'),
              if (result.street != null)
                _infoBadge(Icons.home_rounded, '${result.street}${result.addressNumber != null ? ", nº ${result.addressNumber}" : ""}'),
              if (result.ucNumber != null)
                _infoBadge(Icons.electric_meter_rounded, 'UC: ${result.ucNumber}'),
              if (result.utilityCompany != null)
                _infoBadge(Icons.bolt_rounded, result.utilityCompany!),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlantCard(ParsedUnifiedProposal result) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFFEF3C7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.solar_power_rounded, color: Color(0xFFD97706), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.plantName,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Potência: ${result.kilowatts.toStringAsFixed(2)} kWp • Estrutura: ${result.roofType}',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Text(
            'Equipamentos & Componentes Identificados (${result.items.length})',
            style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF334155)),
          ),
          const SizedBox(height: 8),
          ...result.items.map((it) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(it.componentType.icon, size: 16, color: it.componentType.color),
                  const SizedBox(width: 8),
                  Text(
                    '${it.quantity.toStringAsFixed(0)}x',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12.5),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      it.name,
                      style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF1E293B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (it.moduleWatts != null && it.moduleWatts! > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${it.moduleWatts!.toStringAsFixed(0)}W',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFB45309)),
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFinalAdjustmentsCard(ParsedUnifiedProposal result) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune_rounded, color: Color(0xFF6366F1), size: 20),
              const SizedBox(width: 8),
              Text(
                'Ajustes Finais da Proposta (Geração & Valores)',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Geração em kWh/mês
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '⚡ Geração Estimada (kWh/mês)',
                      style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _generationKwhCtrl,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        suffixText: 'kWh/mês',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Tipo de Telhado
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🏠 Tipo de Cobertura / Telhado',
                      style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: _roofOptions.contains(_roofTypeCtrl.text) ? _roofTypeCtrl.text : 'Cerâmico',
                      items: _roofOptions.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _roofTypeCtrl.text = val);
                      },
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              // Preço dos Produtos
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📦 Preço dos Produtos / Kit (R\$)',
                      style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _productsPriceCtrl,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Preço do Serviço
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🛠️ Valor do Serviço / Instalação (R\$)',
                      style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _servicePriceCtrl,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoBadge(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: const Color(0xFF64748B)),
        const SizedBox(width: 6),
        Text(
          text,
          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF475569)),
        ),
      ],
    );
  }
}
