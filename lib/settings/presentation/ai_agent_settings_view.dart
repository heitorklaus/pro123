import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../../proposals/data/services/gemini_proposal_assistant_service.dart';
import '../data/services/ai_agent_settings_service.dart';
import '../domain/models/ai_agent_settings_model.dart';

/// Painel Administrativo de Configurações e Treinamento do Agente de IA da Empresa
class AiAgentSettingsView extends StatefulWidget {
  final VoidCallback? onBack;

  const AiAgentSettingsView({super.key, this.onBack});

  @override
  State<AiAgentSettingsView> createState() => _AiAgentSettingsViewState();
}

class _AiAgentSettingsViewState extends State<AiAgentSettingsView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _companyId;

  late AiAgentSettingsModel _settings;

  // Controllers: Tab 1 (Prompt & Instruções)
  final _systemPromptCtrl = TextEditingController();
  final _agentNameCtrl = TextEditingController();

  // Controllers: Tab 2 (Políticas Comerciais)
  final _customRulesCtrl = TextEditingController();
  final _marginPercentCtrl = TextEditingController();
  final _generationFactorCtrl = TextEditingController();
  final _validityDaysCtrl = TextEditingController();
  final _paymentTermsCtrl = TextEditingController();
  String _selectedRoofType = 'Cerâmico';

  // Listas de Chips: Tab 2
  late List<String> _distributors;
  late List<String> _moduleBrands;
  late List<String> _inverterBrands;

  // Tab 3: Exemplos de Treinamento
  late List<AiTrainingExample> _examples;

  // Tab 4: Playground / Simulador
  final _testPromptCtrl = TextEditingController(
    text: 'Monte uma proposta com 16 placas de 615W e inversor Deye de 8kW em telhado cerâmico para o cliente Marina Lima, geração de 1200 kWh e serviço de R\$ 8.500',
  );
  bool _isTesting = false;
  ParsedUnifiedProposal? _testResult;
  String? _testError;

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
    _tabController = TabController(length: 4, vsync: this);
    _loadSettings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _systemPromptCtrl.dispose();
    _agentNameCtrl.dispose();
    _customRulesCtrl.dispose();
    _marginPercentCtrl.dispose();
    _generationFactorCtrl.dispose();
    _validityDaysCtrl.dispose();
    _paymentTermsCtrl.dispose();
    _testPromptCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final auth = AuthRepository();
      _companyId = await auth.getCurrentCompanyId();
      final loaded = await AiAgentSettingsService.getSettings(companyId: _companyId);

      if (mounted) {
        setState(() {
          _settings = loaded;
          _populateControllers(loaded);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        final def = AiAgentSettingsModel.defaultSettings(companyId: _companyId);
        setState(() {
          _settings = def;
          _populateControllers(def);
          _isLoading = false;
        });
      }
    }
  }

  void _populateControllers(AiAgentSettingsModel s) {
    _systemPromptCtrl.text = s.systemInstruction;
    _agentNameCtrl.text = s.agentName;
    _customRulesCtrl.text = s.customCommercialRules;
    _marginPercentCtrl.text = s.defaultServicePriceMarginPercent.toStringAsFixed(1);
    _generationFactorCtrl.text = s.defaultGenerationFactor.toStringAsFixed(1);
    _validityDaysCtrl.text = s.defaultValidityDays.toString();
    _paymentTermsCtrl.text = s.defaultPaymentTerms;
    _selectedRoofType = _roofOptions.contains(s.defaultRoofType) ? s.defaultRoofType : 'Cerâmico';
    _distributors = List<String>.from(s.preferredDistributors);
    _moduleBrands = List<String>.from(s.preferredModuleBrands);
    _inverterBrands = List<String>.from(s.preferredInverterBrands);
    _examples = List<AiTrainingExample>.from(s.trainingExamples);
  }

  AiAgentSettingsModel _buildCurrentModel() {
    return _settings.copyWith(
      companyId: _companyId,
      agentName: _agentNameCtrl.text.trim(),
      systemInstruction: _systemPromptCtrl.text.trim(),
      customCommercialRules: _customRulesCtrl.text.trim(),
      defaultServicePriceMarginPercent: double.tryParse(_marginPercentCtrl.text.replaceAll(',', '.')) ?? 20.0,
      defaultGenerationFactor: double.tryParse(_generationFactorCtrl.text.replaceAll(',', '.')) ?? 110.0,
      defaultValidityDays: int.tryParse(_validityDaysCtrl.text) ?? 15,
      defaultPaymentTerms: _paymentTermsCtrl.text.trim(),
      defaultRoofType: _selectedRoofType,
      preferredDistributors: _distributors,
      preferredModuleBrands: _moduleBrands,
      preferredInverterBrands: _inverterBrands,
      trainingExamples: _examples,
      updatedAt: DateTime.now(),
    );
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      final updated = _buildCurrentModel();
      await AiAgentSettingsService.saveSettings(updated, companyId: _companyId);
      setState(() {
        _settings = updated;
        _isSaving = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✨ Regras e Treinamento do Agente de IA salvos com sucesso!'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _restoreDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.restore_rounded, color: Color(0xFF6366F1)),
            const SizedBox(width: 10),
            Text('Restaurar Padrões?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Deseja restaurar as instruções do sistema, exemplos de treinamento e regras oficiais padrão da Mavis? As alterações personalizadas serão substituídas.',
          style: GoogleFonts.inter(fontSize: 13.5, color: const Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancelar', style: GoogleFonts.inter(color: const Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sim, Restaurar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      final def = await AiAgentSettingsService.restoreDefaults(companyId: _companyId);
      setState(() {
        _settings = def;
        _populateControllers(def);
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configurações oficiais padrão restauradas!'),
            backgroundColor: Color(0xFF6366F1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _addChipItem(String title, List<String> list) async {
    final ctrl = TextEditingController();
    final item = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Adicionar $title', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Ex: Nome da Marca ou Distribuidora',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              final val = ctrl.text.trim();
              if (val.isNotEmpty) Navigator.of(ctx).pop(val);
            },
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );

    if (item != null && item.isNotEmpty && !list.contains(item)) {
      setState(() {
        list.add(item);
      });
    }
  }

  void _addOrEditExample({AiTrainingExample? existing, int? index}) async {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final inputCtrl = TextEditingController(text: existing?.userInput ?? '');
    final outputCtrl = TextEditingController(text: existing?.expectedOutput ?? '');

    final result = await showDialog<AiTrainingExample>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          existing != null ? 'Editar Exemplo de Treinamento' : 'Novo Exemplo de Treinamento',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: 540,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Título / Identificação do Caso:', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(
                    hintText: 'Ex: Cotação sem frete, Kit Microinversor...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 14),
                Text('Entrada do Usuário (Prompt ou Arquivos):', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: inputCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Ex: Monte uma proposta com 10 placas de 550W...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 14),
                Text('Comportamento / Resposta Esperada da IA:', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: outputCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Ex: Cria usina de 5.5 kWp, sugere inversor de 5kW e aplica regra X...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              if (titleCtrl.text.trim().isNotEmpty && inputCtrl.text.trim().isNotEmpty) {
                Navigator.of(ctx).pop(AiTrainingExample(
                  id: existing?.id ?? 'ex_${DateTime.now().millisecondsSinceEpoch}',
                  title: titleCtrl.text.trim(),
                  userInput: inputCtrl.text.trim(),
                  expectedOutput: outputCtrl.text.trim(),
                  isActive: existing?.isActive ?? true,
                ));
              }
            },
            child: Text(existing != null ? 'Salvar' : 'Adicionar'),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() {
        if (index != null && index >= 0) {
          _examples[index] = result;
        } else {
          _examples.add(result);
        }
      });
    }
  }

  Future<void> _runPlaygroundTest() async {
    final text = _testPromptCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isTesting = true;
      _testResult = null;
      _testError = null;
    });

    try {
      final currentSettings = _buildCurrentModel();
      final res = await GeminiProposalAssistantService.analyzeProposal(
        textPrompt: text,
        customAiSettings: currentSettings,
      );
      if (mounted) {
        setState(() {
          _testResult = res;
          _isTesting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _testError = e.toString();
          _isTesting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 12 : 28),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Cabeçalho Principal ──────────────────────────────────────
                _buildHeader(isMobile),
                const SizedBox(height: 20),

                // ── Card Superior de Status & Temperatura ────────────────────
                _buildStatusBanner(isMobile),
                const SizedBox(height: 20),

                // ── Card de Abas ─────────────────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // TabBar
                      Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          isScrollable: isMobile,
                          labelColor: const Color(0xFF6366F1),
                          unselectedLabelColor: const Color(0xFF64748B),
                          indicatorColor: const Color(0xFF6366F1),
                          indicatorWeight: 3,
                          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13.5),
                          tabs: const [
                            Tab(icon: Icon(Icons.psychology_rounded, size: 20), text: 'Prompt & Instruções'),
                            Tab(icon: Icon(Icons.storefront_rounded, size: 20), text: 'Políticas & Marcas'),
                            Tab(icon: Icon(Icons.school_rounded, size: 20), text: 'Exemplos de Treinamento'),
                            Tab(icon: Icon(Icons.science_rounded, size: 20), text: 'Playground de Teste'),
                          ],
                        ),
                      ),

                      // Conteúdo das Abas
                      Padding(
                        padding: EdgeInsets.all(isMobile ? 16 : 28),
                        child: SizedBox(
                          height: 700,
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _buildTab1Prompt(),
                              _buildTab2CommercialRules(),
                              _buildTab3Examples(),
                              _buildTab4Playground(isMobile),
                            ],
                          ),
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
  }

  // ── CABEÇALHO ──────────────────────────────────────────────────────────────
  Widget _buildHeader(bool isMobile) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              if (widget.onBack != null) ...[
                IconButton(
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
                  tooltip: 'Voltar às Configurações',
                ),
                const SizedBox(width: 8),
              ],
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Agente de IA & Treinamento',
                      style: GoogleFonts.outfit(
                        fontSize: isMobile ? 20 : 26,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Personalize o comportamento, regras comerciais e inteligência do Gemini para sua empresa',
                      style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Botão Restaurar Padrões
            OutlinedButton.icon(
              onPressed: _restoreDefaults,
              icon: const Icon(Icons.restore_rounded, size: 16, color: Color(0xFF64748B)),
              label: Text(
                isMobile ? 'Padrões' : 'Restaurar Padrões',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: const Color(0xFF64748B)),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(width: 10),
            // Botão Salvar Alterações
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveSettings,
              icon: _isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save_rounded, size: 18, color: Colors.white),
              label: Text(
                _isSaving ? 'Salvando...' : (isMobile ? 'Salvar' : 'Salvar Regras'),
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 3,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── BANNER SUPERIOR DE STATUS & RIGOR ───────────────────────────────────────
  Widget _buildStatusBanner(bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Nome do Agente de IA', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12, color: const Color(0xFF64748B))),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _agentNameCtrl,
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Status do Agente', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12, color: const Color(0xFF64748B))),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Switch(
                        value: _settings.isAiActive,
                        activeThumbColor: const Color(0xFF10B981),
                        onChanged: (val) => setState(() => _settings = _settings.copyWith(isAiActive: val)),
                      ),
                      Text(
                        _settings.isAiActive ? 'Ativo para a Equipe' : 'Pausado',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          color: _settings.isAiActive ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFFF1F5F9)),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.tune_rounded, size: 18, color: Color(0xFF6366F1)),
              const SizedBox(width: 8),
              Text(
                'Nível de Rigor / Temperatura do Gemini (${_settings.temperature.toStringAsFixed(2)}):',
                style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Slider(
                  value: _settings.temperature,
                  min: 0.0,
                  max: 1.0,
                  divisions: 20,
                  activeColor: const Color(0xFF6366F1),
                  label: _settings.temperature.toStringAsFixed(2),
                  onChanged: (val) => setState(() => _settings = _settings.copyWith(temperature: val)),
                ),
              ),
              Text(
                _settings.temperature <= 0.3 ? '🎯 Máxima Precisão (Ideal)' : '🎨 Mais Criativo',
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── ABA 1: PROMPT DO SISTEMA & PERSONA ─────────────────────────────────────
  Widget _buildTab1Prompt() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Instruções Mestres do Sistema (System Instruction)', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFF0F172A))),
                  Text('Define a persona, as regras de classificação multi-documento e o formato JSON oficial retornado pela IA.', style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF64748B))),
                ],
              ),
              Text('${_systemPromptCtrl.text.length} caracteres', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8))),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _systemPromptCtrl,
              maxLines: 22,
              style: GoogleFonts.firaCode(fontSize: 12.5, color: const Color(0xFFE2E8F0), height: 1.45),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
      ),
    );
  }

  // ── ABA 2: POLÍTICAS COMERCIAIS & MARCAS PARCEIRAS ─────────────────────────
  Widget _buildTab2CommercialRules() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Políticas & Parâmetros Comerciais da Empresa', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFF0F172A))),
          Text('Essas regras são injetadas prioritariamente no Agente para direcionar cálculos e escolhas automáticas.', style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF64748B))),
          const SizedBox(height: 16),

          Row(
            children: [
              // Margem de Serviço
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Margem / Serviço Estimado (%):', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _marginPercentCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Ex: 20.0',
                        suffixText: '%',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Fator de Geração Médio
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Fator de Geração Regional (kWh/kWp):', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _generationFactorCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Ex: 110.0',
                        suffixText: 'kWh/kWp',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Tipo de Telhado Padrão
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tipo de Cobertura Padrão:', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedRoofType,
                      items: _roofOptions.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedRoofType = val);
                      },
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              // Validade em Dias
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Validade da Proposta (Dias):', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _validityDaysCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Ex: 15',
                        suffixText: 'dias',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              // Condições de Pagamento Padrão
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Condições de Pagamento Sugeridas:', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _paymentTermsCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Ex: À vista via PIX (5% desc) ou Boleto 30DD',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── CHIPS: DISTRIBUIDORAS PARCEIRAS ────────────────────────────────
          _buildChipSection(
            title: '🏢 Distribuidoras & Fornecedores Parceiros',
            subtitle: 'A IA prioriza o reconhecimento e cotações destas distribuidoras',
            items: _distributors,
            onAdd: () => _addChipItem('Distribuidora', _distributors),
            color: const Color(0xFF6366F1),
          ),
          const SizedBox(height: 16),

          // ── CHIPS: MÓDULOS PREFERENCIAIS ───────────────────────────────────
          _buildChipSection(
            title: '☀️ Marcas de Módulos / Placas Preferenciais',
            subtitle: 'Marcas homologadas pela engenharia da sua empresa',
            items: _moduleBrands,
            onAdd: () => _addChipItem('Marca de Módulo', _moduleBrands),
            color: const Color(0xFFF59E0B),
          ),
          const SizedBox(height: 16),

          // ── CHIPS: INVERSORES PREFERENCIAIS ────────────────────────────────
          _buildChipSection(
            title: '⚡ Marcas de Inversores & Microinversores Preferenciais',
            subtitle: 'Inversores homologados e recomendados pela sua empresa',
            items: _inverterBrands,
            onAdd: () => _addChipItem('Marca de Inversor', _inverterBrands),
            color: const Color(0xFF10B981),
          ),
          const SizedBox(height: 20),

          // Regras adicionais em texto livre
          Text('Diretrizes Comerciais Adicionais em Texto Livre:', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
          const SizedBox(height: 6),
          TextField(
            controller: _customRulesCtrl,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Ex: Para cotações no estado de SP, aplicar 5% de desconto à vista...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChipSection({
    required String title,
    required String subtitle,
    required List<String> items,
    required VoidCallback onAdd,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFF0F172A))),
                  Text(subtitle, style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B))),
                ],
              ),
              TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                label: const Text('Adicionar'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items.map((item) {
              return Chip(
                label: Text(item, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: color.withValues(alpha: 0.3)),
                ),
                deleteIcon: const Icon(Icons.close_rounded, size: 14, color: Color(0xFFEF4444)),
                onDeleted: () => setState(() => items.remove(item)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── ABA 3: EXEMPLOS DE TREINAMENTO (FEW-SHOT) ──────────────────────────────
  Widget _buildTab3Examples() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Exemplos de Treinamento (Few-Shot Learning)', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFF0F172A))),
                Text('Ensine a IA mostrando casos reais de como interpretar textos ou arquivos da sua rotina.', style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF64748B))),
              ],
            ),
            ElevatedButton.icon(
              onPressed: () => _addOrEditExample(),
              icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
              label: const Text('Novo Exemplo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        Expanded(
          child: _examples.isEmpty
              ? Center(
                  child: Text('Nenhum exemplo cadastrado.', style: GoogleFonts.inter(color: const Color(0xFF64748B))),
                )
              : ListView.separated(
                  itemCount: _examples.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final ex = _examples[index];
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: ex.isActive ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text('Exemplo ${index + 1}', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11, color: const Color(0xFF6366F1))),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(ex.title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14.5, color: const Color(0xFF0F172A))),
                                ],
                              ),
                              Row(
                                children: [
                                  Switch(
                                    value: ex.isActive,
                                    activeThumbColor: const Color(0xFF10B981),
                                    onChanged: (val) => setState(() => _examples[index] = ex.copyWith(isActive: val)),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF64748B)),
                                    onPressed: () => _addOrEditExample(existing: ex, index: index),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                                    onPressed: () => setState(() => _examples.removeAt(index)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('📥 Entrada do Usuário / Vendedor:', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11.5, color: const Color(0xFF475569))),
                                const SizedBox(height: 2),
                                Text(ex.userInput, style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF1E293B))),
                                const SizedBox(height: 8),
                                Text('✨ Ação / Resposta Esperada da IA:', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11.5, color: const Color(0xFF10B981))),
                                const SizedBox(height: 2),
                                Text(ex.expectedOutput, style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF1E293B))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ── ABA 4: PLAYGROUND DE TESTE AO VIVO ──────────────────────────────────────
  Widget _buildTab4Playground(bool isMobile) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Simulador de Treinamento em Tempo Real', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFF0F172A))),
          Text('Teste as novas instruções e regras antes de salvar para os seus operadores.', style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF64748B))),
          const SizedBox(height: 16),

          Text('Prompt / Instruções de Teste:', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: const Color(0xFF0F172A))),
          const SizedBox(height: 6),
          TextField(
            controller: _testPromptCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Digite um prompt ou cole o texto de uma cotação...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 12),

          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _isTesting ? null : _runPlaygroundTest,
              icon: _isTesting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.play_arrow_rounded, color: Colors.white),
              label: Text(_isTesting ? 'Processando com Gemini...' : 'Executar Teste do Agente'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (_testError != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF87171)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_testError!, style: GoogleFonts.inter(color: const Color(0xFF991B1B), fontSize: 13))),
                ],
              ),
            ),
          ],

          if (_testResult != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
                      const SizedBox(width: 8),
                      Text('Resultado da Análise do Agente:', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: const Color(0xFF0F172A))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Grid de Resumo
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      SizedBox(
                        width: isMobile ? double.infinity : 220,
                        child: _summaryBox('Cliente', _testResult!.clientName ?? 'Não informado', Icons.person_rounded),
                      ),
                      SizedBox(
                        width: isMobile ? double.infinity : 220,
                        child: _summaryBox('Potência Usina', '${_testResult!.kilowatts.toStringAsFixed(2)} kWp', Icons.solar_power_rounded),
                      ),
                      SizedBox(
                        width: isMobile ? double.infinity : 220,
                        child: _summaryBox('Geração Estimada', '${_testResult!.generationKwh?.toStringAsFixed(0) ?? 0} kWh/mês', Icons.bolt_rounded),
                      ),
                      SizedBox(
                        width: isMobile ? double.infinity : 220,
                        child: _summaryBox('Valor Serviço', 'R\$ ${_testResult!.servicePrice.toStringAsFixed(2)}', Icons.handyman_rounded),
                      ),
                      SizedBox(
                        width: isMobile ? double.infinity : 220,
                        child: _summaryBox('Cobertura / Telhado', _testResult!.roofType, Icons.roofing_rounded),
                      ),
                      SizedBox(
                        width: isMobile ? double.infinity : 220,
                        child: _summaryBox('Validade Proposta', '${_testResult!.validityDays} dias', Icons.calendar_today_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (_testResult!.aiSummary != null && _testResult!.aiSummary!.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFC7D2FE)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.auto_awesome_rounded, color: Color(0xFF6366F1), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _testResult!.aiSummary!,
                              style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF3730A3), height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  Text('Equipamentos Reconhecidos (${_testResult!.items.length}):', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFF0F172A))),
                  const SizedBox(height: 8),
                  if (_testResult!.items.isEmpty)
                    Text('Nenhum equipamento reconhecido.', style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF64748B)))
                  else
                    ..._testResult!.items.map((item) => Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check_rounded, size: 14, color: Color(0xFF10B981)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '${item.quantity.toStringAsFixed(0)}x ${item.name} (${item.unit})',
                                  style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
                                ),
                              ),
                              if (item.moduleWatts != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text('${item.moduleWatts!.toStringAsFixed(0)}W', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFB45309))),
                                ),
                            ],
                          ),
                        )),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryBox(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: const Color(0xFF6366F1)),
              const SizedBox(width: 6),
              Text(label, style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13.5, color: const Color(0xFF0F172A)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
