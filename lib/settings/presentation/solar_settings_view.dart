import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../app/theme/app_colors.dart';
import '../../proposals/data/services/solar_proposal_pdf_service.dart';
import '../../proposals/domain/models/proposal_item_model.dart';
import '../../proposals/domain/models/proposal_model.dart';
import '../../proposals/presentation/web_proposal_page.dart';
import '../data/services/solar_settings_service.dart';
import '../domain/models/solar_settings_model.dart';

class SolarSettingsView extends StatefulWidget {
  final VoidCallback? onBack;

  const SolarSettingsView({super.key, this.onBack});

  @override
  State<SolarSettingsView> createState() => _SolarSettingsViewState();
}

class _SolarSettingsViewState extends State<SolarSettingsView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  late SolarSettingsModel _settings;
  List<String> _availableCovers = [];
  bool _loadingCovers = false;

  // Controllers: Concessionária & Parâmetros
  final _utilityCtrl = TextEditingController();
  final _tariffCtrl = TextEditingController();
  final _fioBCtrl = TextEditingController();
  final _inflationCtrl = TextEditingController();
  final _simultaneityCtrl = TextEditingController();
  final _sunHoursCtrl = TextEditingController();
  final _projectionYearsCtrl = TextEditingController();

  // Controllers: Dados da Empresa para a Proposta
  final _companyNameCtrl = TextEditingController();
  final _companyDocCtrl = TextEditingController();
  final _companyPhoneCtrl = TextEditingController();
  final _companyWebsiteCtrl = TextEditingController();
  final _companyInstagramCtrl = TextEditingController();
  final _companySloganCtrl = TextEditingController();

  // Financiamento & Cartão
  late List<SolarFinancingBank> _banks;
  late List<CreditCardInstallmentRate> _cardRates;
  String _selectedCover = 'capa-1.jpeg';
  String _selectedSvgTheme = '#2563EB';
  String _selectedWebBg = 'AdobeStock_1030854734.jpg';

  // Simulação ao vivo
  final double _simulationValue = 19700.0;

  static const _popularUtilities = [
    'Amazonas Energia',
    'Energisa',
    'Enel SP',
    'Enel RJ',
    'Enel CE',
    'CPFL Paulista',
    'CPFL Piratininga',
    'CPFL Santa Cruz',
    'Cemig',
    'Copel',
    'Equatorial MA',
    'Equatorial PA',
    'Equatorial PI',
    'Equatorial AL',
    'Equatorial GO',
    'Neoenergia Coelba',
    'Neoenergia Elektro',
    'Neoenergia Pernambuco',
    'Neoenergia Cosern',
    'Neoenergia Brasília',
    'Light',
    'RGE',
    'CEEE Equatorial',
    'EDP SP',
    'EDP ES',
    'Celesc',
    'Outra Concessionária (Personalizada)',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    try {
      final loaded = await SolarSettingsService.loadSettings();
      _settings = loaded;

      _utilityCtrl.text = loaded.utilityCompany;
      _tariffCtrl.text = loaded.energyTariff.toStringAsFixed(3).replaceAll('.', ',');
      _fioBCtrl.text = loaded.fioBTariff.toStringAsFixed(3).replaceAll('.', ',');
      _inflationCtrl.text = loaded.annualInflation.toStringAsFixed(1).replaceAll('.', ',');
      _simultaneityCtrl.text = loaded.simultaneityRate.toStringAsFixed(1).replaceAll('.', ',');
      _sunHoursCtrl.text = loaded.defaultSunHours.toStringAsFixed(1).replaceAll('.', ',');
      _projectionYearsCtrl.text = loaded.projectionYears.toString();

      _companyNameCtrl.text = loaded.companyName ?? '';
      _companyDocCtrl.text = loaded.companyDocument ?? '';
      _companyPhoneCtrl.text = loaded.companyPhone ?? '';
      _companyWebsiteCtrl.text = loaded.companyWebsite ?? '';
      _companyInstagramCtrl.text = loaded.companyInstagram ?? '';
      _companySloganCtrl.text = loaded.companySlogan ?? 'Energia que Transforma';

      _banks = List.from(loaded.financingBanks);
      if (_banks.isEmpty) _banks = SolarFinancingBank.defaultBanks();

      _cardRates = List.from(loaded.creditCardRates);
      if (_cardRates.isEmpty) _cardRates = CreditCardInstallmentRate.defaultRates();

      _selectedCover = loaded.selectedCoverTemplate;
      _selectedSvgTheme = loaded.selectedSvgTheme;
      _selectedWebBg = loaded.webBackgroundTemplate;

      setState(() => _isLoading = false);
      _loadCoversList();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Erro ao carregar configurações: $e';
        });
      }
    }
  }

  Future<void> _loadCoversList() async {
    setState(() => _loadingCovers = true);
    final covers = await SolarSettingsService.fetchAvailableCovers();
    if (mounted) {
      setState(() {
        _availableCovers = covers;
        _loadingCovers = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _utilityCtrl.dispose();
    _tariffCtrl.dispose();
    _fioBCtrl.dispose();
    _inflationCtrl.dispose();
    _simultaneityCtrl.dispose();
    _sunHoursCtrl.dispose();
    _projectionYearsCtrl.dispose();
    _companyNameCtrl.dispose();
    _companyDocCtrl.dispose();
    _companyPhoneCtrl.dispose();
    _companyWebsiteCtrl.dispose();
    _companyInstagramCtrl.dispose();
    _companySloganCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      double parseD(String text, double fallback) =>
          double.tryParse(text.replaceAll(',', '.').trim()) ?? fallback;
      int parseI(String text, int fallback) => int.tryParse(text.trim()) ?? fallback;

      final updated = _settings.copyWith(
        utilityCompany: _utilityCtrl.text.trim().isNotEmpty ? _utilityCtrl.text.trim() : 'Amazonas Energia',
        energyTariff: parseD(_tariffCtrl.text, 1.125),
        fioBTariff: parseD(_fioBCtrl.text, 0.28),
        annualInflation: parseD(_inflationCtrl.text, 5.0),
        simultaneityRate: parseD(_simultaneityCtrl.text, 13.0),
        defaultSunHours: parseD(_sunHoursCtrl.text, 4.8),
        projectionYears: parseI(_projectionYearsCtrl.text, 21),
        companyName: _companyNameCtrl.text.trim(),
        companyDocument: _companyDocCtrl.text.trim(),
        companyPhone: _companyPhoneCtrl.text.trim(),
        companyWebsite: _companyWebsiteCtrl.text.trim(),
        companyInstagram: _companyInstagramCtrl.text.trim(),
        companySlogan: _companySloganCtrl.text.trim(),
        financingBanks: _banks,
        creditCardRates: _cardRates,
        selectedCoverTemplate: _selectedCover,
        selectedSvgTheme: _selectedSvgTheme,
        webBackgroundTemplate: _selectedWebBg,
      );

      await SolarSettingsService.saveSettings(updated);
      _settings = updated;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Configurações de Usina Solar salvas com sucesso!'),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro ao salvar: $e'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _previewWebProposal() {
    final now = DateTime.now();
    final sampleProposal = ProposalModel(
      id: 'demo_web_preview',
      proposalNumber: 'PROP-2026/001',
      title: 'Proposta Comercial - Usina Solar Fotovoltaica',
      clientName: 'João da Silva Santos',
      clientDocument: '123.456.789-00',
      clientEmail: 'joao.silva@exemplo.com.br',
      clientPhone: _companyPhoneCtrl.text.trim().isNotEmpty ? _companyPhoneCtrl.text.trim() : '(92) 98123-4567',
      clientAddress: 'Av. Paulista, 1000 - Bela Vista, São Paulo - SP',
      totalAmount: 24900.0,
      subtotal: 24900.0,
      discount: 0.0,
      shippingFee: 0.0,
      paymentTerms: 'À Vista, Financiamento em até 90x ou Cartão de Crédito',
      deliveryTime: '60 dias',
      validityDays: 15,
      items: [
        ProposalItemModel(
          name: 'Usina Solar Fotovoltaica 8.61 kWp',
          quantity: 1,
          unitPrice: 24900.0,
          totalPrice: 24900.0,
          isSolarPlant: true,
          solarKilowatts: 8.61,
          moduleWatts: 615.0,
          solarRoofType: 'Cerâmico',
          solarComponents: const [
            '14x Módulo Fotovoltaico 615W Monocristalino Tier 1',
            '1x Inversor Solar Grid-Tie 8.0 kW 220V',
            '1x Estrutura Fixação Telhado Cerâmico',
            '1x String Box CC/CA com DPS e Chave Seccionadora',
            '60m Cabo Solar 6mm² Preto/Vermelho Anti-UV',
            '1x Homologação e Engenharia de Acesso à Rede',
          ],
        ),
      ],
      createdAt: now,
      updatedAt: now,
      status: ProposalStatus.negotiating,
      themeColorValue: _settings.copyWith(selectedSvgTheme: _selectedSvgTheme).themeColorValue,
    );

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
              proposalId: 'demo_web_preview',
              initialProposal: sampleProposal,
            ),
          ),
        ),
      ),
    );
  }

  void _previewProposalPdf() {
    final now = DateTime.now();
    final sampleProposal = ProposalModel(
      id: 'demo_preview',
      proposalNumber: 'PROP-2026/001',
      title: 'Proposta Comercial - Usina Solar Fotovoltaica',
      clientName: 'João da Silva Santos',
      clientDocument: '123.456.789-00',
      clientEmail: 'joao.silva@exemplo.com.br',
      clientPhone: '(92) 98123-4567',
      clientAddress: 'Av. Paulista, 1000 - Bela Vista, São Paulo - SP',
      totalAmount: 24900.0,
      subtotal: 24900.0,
      discount: 0.0,
      shippingFee: 0.0,
      paymentTerms: 'Financiamento Bancário / Cartão de Crédito',
      deliveryTime: '60 dias',
      validityDays: 15,
      items: [
        ProposalItemModel(
          name: 'Usina Solar Fotovoltaica 8.61 kWp',
          quantity: 1,
          unitPrice: 24900.0,
          totalPrice: 24900.0,
          isSolarPlant: true,
          solarKilowatts: 8.61,
          solarRoofType: 'Cerâmico',
          solarComponents: const [
            '14x Módulo Fotovoltaico 615W Monocristalino Tier 1',
            '1x Inversor Solar Grid-Tie 8.0 kW 220V',
            '1x Estrutura Fixação Telhado Cerâmico',
            '1x String Box CC/CA com DPS e Chave Seccionadora',
            '60m Cabo Solar 6mm² Preto/Vermelho Anti-UV',
            '1x Homologação e Engenharia de Acesso à Rede',
          ],
        ),
      ],
      createdAt: now,
      updatedAt: now,
      status: ProposalStatus.negotiating,
      themeColorValue: 0xFF6366F1,
    );

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: Container(
          width: 1000,
          height: 800,
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 20)],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  children: [
                    const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFDC2626), size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Pré-visualização do Modelo de Proposta Comercial (6 Páginas)',
                        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PdfPreview(
                  build: (format) => SolarProposalPdfService.generateSolarProposalPdf(
                    sampleProposal,
                    solarSettings: _settings.copyWith(
                      selectedCoverTemplate: _selectedCover,
                      selectedSvgTheme: _selectedSvgTheme,
                    ),
                  ),
                  allowPrinting: true,
                  allowSharing: true,
                  canChangePageFormat: false,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    final isMobile = MediaQuery.of(context).size.width < 768;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 14 : 32),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
              // ── Header da Página ───────────────────────────────────────────
              Row(
                children: [
                  if (widget.onBack != null) ...[
                    IconButton(
                      tooltip: 'Voltar',
                      icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
                      onPressed: widget.onBack,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Container(
                    padding: EdgeInsets.all(isMobile ? 10 : 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(Icons.solar_power_rounded, color: Colors.white, size: isMobile ? 22 : 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Configurações • Usina Solar Fotovoltaica',
                          style: GoogleFonts.outfit(
                            fontSize: isMobile ? 18 : 22,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Concessionária, simultaneidade, financiamento, cartões e modelo da proposta',
                          style: GoogleFonts.inter(fontSize: isMobile ? 11.5 : 13, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  if (!isMobile) ...[
                    ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveSettings,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.save_rounded, size: 18),
                      label: Text(_isSaving ? 'SALVANDO...' : 'SALVAR ALTERAÇÕES'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
                    ),
                  ],
                ],
              ),

              if (isMobile) ...[
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveSettings,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.save_rounded, size: 18),
                  label: Text(_isSaving ? 'SALVANDO...' : 'SALVAR ALTERAÇÕES'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],

              const SizedBox(height: 16),
              const Divider(color: AppColors.divider),
              const SizedBox(height: 12),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF991B1B)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── TabBar de Navegação ────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelColor: const Color(0xFFD97706),
                  unselectedLabelColor: const Color(0xFF64748B),
                  indicatorColor: const Color(0xFFF59E0B),
                  indicatorWeight: 3,
                  labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                  unselectedLabelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
                  tabs: const [
                    Tab(icon: Icon(Icons.bolt_rounded), text: '1. Concessionária & Tarifas'),
                    Tab(icon: Icon(Icons.wb_sunny_outlined), text: '2. Simultaneidade & Consumo'),
                    Tab(icon: Icon(Icons.account_balance_outlined), text: '3. Financiamentos Bancários'),
                    Tab(icon: Icon(Icons.credit_card_rounded), text: '4. Cartão de Crédito'),
                    Tab(icon: Icon(Icons.picture_as_pdf_outlined), text: '5. Modelo de Proposta'),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Conteúdo das Abas ──────────────────────────────────────────
              SizedBox(
                height: 720,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildUtilityTab(isMobile),
                    _buildSimultaneityTab(isMobile),
                    _buildFinancingTab(isMobile),
                    _buildCreditCardTab(isMobile),
                    _buildProposalTemplateTab(isMobile),
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
  }

  // ───────────────────────────────────────────────────────────────────────────
  // ABA 1: CONCESSIONÁRIA & TARIFAS
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildUtilityTab(bool isMobile) {
    return SingleChildScrollView(
      child: Container(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Dados da Concessionária & Tarifas Elétricas', 'Defina os valores padrão aplicados nos cálculos de economia e proposta'),
            const SizedBox(height: 16),

            // Dropdown de Concessionárias Populares + Campo Livre
            _label('Concessionária / Distribuidora de Energia Padrão'),
            const SizedBox(height: 6),
            Autocomplete<String>(
              initialValue: TextEditingValue(text: _utilityCtrl.text),
              optionsBuilder: (textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return _popularUtilities;
                }
                return _popularUtilities.where((opt) => opt.toLowerCase().contains(textEditingValue.text.toLowerCase()));
              },
              onSelected: (val) {
                if (val != 'Outra Concessionária (Personalizada)') {
                  _utilityCtrl.text = val;
                }
              },
              fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                _utilityCtrl.addListener(() {
                  if (textEditingController.text != _utilityCtrl.text) {
                    textEditingController.text = _utilityCtrl.text;
                  }
                });
                return TextFormField(
                  controller: textEditingController,
                  focusNode: focusNode,
                  onChanged: (v) => _utilityCtrl.text = v,
                  decoration: const InputDecoration(
                    hintText: 'Ex: Amazonas Energia, Energisa, Enel, CPFL, Cemig...',
                    prefixIcon: Icon(Icons.business_rounded, color: Color(0xFF64748B)),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Tarifas Grid
            if (isMobile) ...[
              _label('Tarifa de Energia (R\$/kWh)'),
              const SizedBox(height: 6),
              _tariffField(_tariffCtrl, 'Ex: 1,125'),
              const SizedBox(height: 12),
              _label('Tarifa Fio B / Rede (R\$/kWh)'),
              const SizedBox(height: 6),
              _tariffField(_fioBCtrl, 'Ex: 0,280'),
              const SizedBox(height: 12),
              _label('Inflação Anual Energética (% a.a.)'),
              const SizedBox(height: 6),
              _tariffField(_inflationCtrl, 'Ex: 5,0'),
              const SizedBox(height: 12),
              _label('Anos de Projeção / Payback'),
              const SizedBox(height: 6),
              _tariffField(_projectionYearsCtrl, 'Ex: 21'),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Tarifa de Energia (R\$/kWh)'),
                        const SizedBox(height: 6),
                        _tariffField(_tariffCtrl, 'Ex: 1,125'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Tarifa Fio B / Rede (R\$/kWh)'),
                        const SizedBox(height: 6),
                        _tariffField(_fioBCtrl, 'Ex: 0,280'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Inflação Anual (% a.a.)'),
                        const SizedBox(height: 6),
                        _tariffField(_inflationCtrl, 'Ex: 5,0'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Anos de Projeção'),
                        const SizedBox(height: 6),
                        _tariffField(_projectionYearsCtrl, 'Ex: 21'),
                      ],
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 24),
            const Divider(color: AppColors.divider),
            const SizedBox(height: 16),

            _sectionTitle('Dados da Empresa Integradora (Exibidos na Capa do PDF)', 'Nome, CNPJ e contatos que aparecem no rodapé da capa da proposta'),
            const SizedBox(height: 16),

            if (isMobile) ...[
              _label('Razão Social / Nome Fantasia'),
              const SizedBox(height: 6),
              TextFormField(controller: _companyNameCtrl, decoration: const InputDecoration(hintText: 'Ex: Soli Energia Solar')),
              const SizedBox(height: 12),
              _label('CNPJ / CPF'),
              const SizedBox(height: 6),
              TextFormField(controller: _companyDocCtrl, decoration: const InputDecoration(hintText: 'Ex: 42.117.511/0001-38')),
              const SizedBox(height: 12),
              _label('Telefone / WhatsApp'),
              const SizedBox(height: 6),
              TextFormField(controller: _companyPhoneCtrl, decoration: const InputDecoration(hintText: 'Ex: (92) 99999-9999')),
              const SizedBox(height: 12),
              _label('Site Oficial'),
              const SizedBox(height: 6),
              TextFormField(controller: _companyWebsiteCtrl, decoration: const InputDecoration(hintText: 'Ex: www.solienergiasolar.com.br')),
              const SizedBox(height: 12),
              _label('Instagram / Redes'),
              const SizedBox(height: 6),
              TextFormField(controller: _companyInstagramCtrl, decoration: const InputDecoration(hintText: 'Ex: @solienergiasolar')),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Razão Social / Nome Fantasia'),
                        const SizedBox(height: 6),
                        TextFormField(controller: _companyNameCtrl, decoration: const InputDecoration(hintText: 'Ex: Soli Energia Solar', prefixIcon: Icon(Icons.solar_power_outlined, color: Color(0xFF64748B)))),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('CNPJ / CPF'),
                        const SizedBox(height: 6),
                        TextFormField(controller: _companyDocCtrl, decoration: const InputDecoration(hintText: 'Ex: 42.117.511/0001-38', prefixIcon: Icon(Icons.badge_outlined, color: Color(0xFF64748B)))),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Telefone / WhatsApp'),
                        const SizedBox(height: 6),
                        TextFormField(controller: _companyPhoneCtrl, decoration: const InputDecoration(hintText: 'Ex: (92) 99999-9999', prefixIcon: Icon(Icons.phone_outlined, color: Color(0xFF64748B)))),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Site Oficial'),
                        const SizedBox(height: 6),
                        TextFormField(controller: _companyWebsiteCtrl, decoration: const InputDecoration(hintText: 'Ex: www.solienergiasolar.com.br', prefixIcon: Icon(Icons.language_rounded, color: Color(0xFF64748B)))),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Instagram / Redes'),
                        const SizedBox(height: 6),
                        TextFormField(controller: _companyInstagramCtrl, decoration: const InputDecoration(hintText: 'Ex: @solienergiasolar', prefixIcon: Icon(Icons.camera_alt_outlined, color: Color(0xFF64748B)))),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tariffField(TextEditingController ctrl, String hint) {
    return TextFormField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.monetization_on_outlined, color: Color(0xFF64748B)),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // ABA 2: SIMULTANEIDADE & CONSUMO
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildSimultaneityTab(bool isMobile) {
    double currentSimRate = double.tryParse(_simultaneityCtrl.text.replaceAll(',', '.')) ?? 13.0;

    return SingleChildScrollView(
      child: Container(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Parâmetros de Simultaneidade & Geração Fotovoltaica', 'Configuração da taxa de autoconsumo instantâneo e horas de irradiação'),
            const SizedBox(height: 20),

            // Card explicativo sobre Simultaneidade
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFFD97706), size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'O que é Simultaneidade Solar?',
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFF92400E)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'É a porcentagem da energia gerada pelos painéis que é consumida instantaneamente no imóvel durante o dia, sem ser injetada na rede da concessionária. Quanto maior a simultaneidade, menor o impacto da cobrança do Fio B (Lei 14.300).',
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF78350F), height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Slider de Simultaneidade
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _label('Taxa de Simultaneidade Média Padrão'),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${currentSimRate.toStringAsFixed(1)}%',
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFFD97706)),
                  ),
                ),
              ],
            ),
            Slider(
              value: currentSimRate.clamp(0.0, 100.0),
              min: 0.0,
              max: 100.0,
              divisions: 100,
              activeColor: const Color(0xFFF59E0B),
              onChanged: (val) {
                setState(() {
                  _simultaneityCtrl.text = val.toStringAsFixed(1).replaceAll('.', ',');
                });
              },
            ),
            const SizedBox(height: 16),

            // Horas de Sol Pleno (HSP)
            _label('Horas de Sol Pleno (HSP Médio Diário na Região)'),
            const SizedBox(height: 6),
            SizedBox(
              width: 260,
              child: TextFormField(
                controller: _sunHoursCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  hintText: 'Ex: 4.8 a 5.5 h/dia',
                  prefixIcon: Icon(Icons.wb_sunny_rounded, color: Color(0xFFF59E0B)),
                  suffixText: 'h/dia',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // ABA 3: FINANCIAMENTO BANCÁRIO
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildFinancingTab(bool isMobile) {
    final currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return SingleChildScrollView(
      child: Container(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _sectionTitle('Instituições Financeiras & Taxas de Juros', 'Simulação calculada automaticamente na página 6 da proposta comercial'),
                ),
                ElevatedButton.icon(
                  onPressed: _openAddBankDialog,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('NOVO BANCO'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Lista de Bancos
            ..._banks.asMap().entries.map((entry) {
              final idx = entry.key;
              final bank = entry.value;

              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: bank.isActive ? Colors.white : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: bank.isActive ? AppColors.primary.withValues(alpha: 0.3) : AppColors.border,
                    width: bank.isActive ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.account_balance_rounded, color: AppColors.primary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                bank.name,
                                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                              ),
                              Text(
                                'Taxa: ${bank.monthlyInterestRate.toStringAsFixed(2)}% ao mês',
                                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        // Campo de Taxa Rápida
                        SizedBox(
                          width: 110,
                          child: TextFormField(
                            initialValue: bank.monthlyInterestRate.toStringAsFixed(2).replaceAll('.', ','),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (v) {
                              final rate = double.tryParse(v.replaceAll(',', '.'));
                              if (rate != null) {
                                setState(() {
                                  _banks[idx] = bank.copyWith(monthlyInterestRate: rate);
                                });
                              }
                            },
                            decoration: const InputDecoration(
                              suffixText: '% a.m.',
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Switch.adaptive(
                          value: bank.isActive,
                          activeTrackColor: AppColors.primary,
                          onChanged: (val) {
                            setState(() {
                              _banks[idx] = bank.copyWith(isActive: val);
                            });
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
                          onPressed: () => setState(() => _banks.removeAt(idx)),
                          tooltip: 'Remover Banco',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: AppColors.divider),
                    const SizedBox(height: 10),

                    // Prazos habilitados
                    Text(
                      'Prazos Habilitados (clique para ativar/desativar):',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [12, 24, 36, 48, 60, 72, 84, 90].map((months) {
                        final isEnabled = bank.enabledInstallments.contains(months);
                        final installmentVal = bank.calculateInstallment(_simulationValue, months);

                        return FilterChip(
                          label: Text(
                            '$months' 'x de ${currencyFormat.format(installmentVal)}',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: isEnabled ? FontWeight.bold : FontWeight.normal,
                              color: isEnabled ? Colors.white : const Color(0xFF334155),
                            ),
                          ),
                          selected: isEnabled,
                          selectedColor: AppColors.primary,
                          checkmarkColor: Colors.white,
                          onSelected: (selected) {
                            final list = List<int>.from(bank.enabledInstallments);
                            if (selected) {
                              list.add(months);
                              list.sort();
                            } else {
                              list.remove(months);
                            }
                            setState(() {
                              _banks[idx] = bank.copyWith(enabledInstallments: list);
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _openAddBankDialog() {
    final nameCtrl = TextEditingController();
    final rateCtrl = TextEditingController(text: '1,25');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Adicionar Banco / Financeira', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: nameCtrl,
              decoration: const InputDecoration(hintText: 'Nome da Instituição (ex: Banco do Brasil)'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: rateCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(hintText: 'Taxa ao mês em %', suffixText: '% a.m.'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCELAR')),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final rate = double.tryParse(rateCtrl.text.replaceAll(',', '.')) ?? 1.25;
              if (name.isNotEmpty) {
                setState(() {
                  _banks.add(SolarFinancingBank(
                    id: name.toLowerCase().replaceAll(RegExp(r'\s+'), '_'),
                    name: name,
                    monthlyInterestRate: rate,
                    enabledInstallments: [12, 24, 36, 48, 60],
                    isActive: true,
                  ));
                });
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('ADICIONAR'),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // ABA 4: CARTÃO DE CRÉDITO
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildCreditCardTab(bool isMobile) {
    final currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return SingleChildScrollView(
      child: Container(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Taxas de Parcelamento no Cartão de Crédito', 'Configure a tabela de coeficientes/taxas repassadas ao cliente em até 12x ou 18x'),
            const SizedBox(height: 16),

            // Bandeiras
            _label('Bandeiras Suportadas'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['VISA', 'MASTERCARD', 'ELO', 'AMEX', 'HIPERCARD', 'DINERS CLUB'].map((flag) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(flag, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF334155))),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            const Divider(color: AppColors.divider),
            const SizedBox(height: 16),

            // Tabela de Parcelamento
            _label('Tabela de Taxas por Parcela'),
            const SizedBox(height: 10),

            LayoutBuilder(
              builder: (ctx, constraints) {
                final crossCount = constraints.maxWidth > 800 ? 4 : (constraints.maxWidth > 500 ? 2 : 1);
                final width = (constraints.maxWidth - ((crossCount - 1) * 12)) / crossCount;

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _cardRates.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final rate = entry.value;
                    final installmentVal = rate.calculateInstallmentValue(_simulationValue);

                    return Container(
                      width: width,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: rate.isActive ? const Color(0xFFF8FAFC) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${rate.installment}x no Cartão',
                                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFF0F172A)),
                              ),
                              Switch.adaptive(
                                value: rate.isActive,
                                activeTrackColor: AppColors.primary,
                                onChanged: (v) {
                                  setState(() {
                                    _cardRates[idx] = CreditCardInstallmentRate(
                                      installment: rate.installment,
                                      feePercentage: rate.feePercentage,
                                      isActive: v,
                                    );
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            initialValue: rate.feePercentage.toStringAsFixed(2).replaceAll('.', ','),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (v) {
                              final f = double.tryParse(v.replaceAll(',', '.'));
                              if (f != null) {
                                setState(() {
                                  _cardRates[idx] = CreditCardInstallmentRate(
                                    installment: rate.installment,
                                    feePercentage: f,
                                    isActive: rate.isActive,
                                  );
                                });
                              }
                            },
                            decoration: const InputDecoration(
                              labelText: 'Taxa Total (%)',
                              suffixText: '%',
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Ex: ${rate.installment}x de ${currencyFormat.format(installmentVal)}',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF059669)),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // ABA 5: MODELO DE PROPOSTA COMERCIAL (CAPAS FIREBASE + TEMA SVG INTEGRADO)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildProposalTemplateTab(bool isMobile) {
    final availableThemes = SolarSettingsService.getAvailableSvgThemes();

    return SingleChildScrollView(
      child: Container(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                _sectionTitle(
                  'Modelo Visual da Proposta (PDF & Versão Web Interativa)',
                  'Escolha a capa do PDF, papel de parede da Proposta Web e a cor temática do sistema',
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _previewWebProposal,
                      icon: const Icon(Icons.language_rounded, size: 18),
                      label: const Text('PRÉVIA PROPOSTA WEB'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _previewProposalPdf,
                      icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                      label: const Text('PRÉVIA PDF'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── 1. Seletor de Capas do PDF ────────────────────────────────────
            _label('1. Capa Principal da Proposta Comercial em PDF (Templates em Alta Resolução)'),
            const SizedBox(height: 6),
            Text(
              'Clique na capa desejada para selecioná-la como capa oficial das propostas impressas/PDF:',
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),

            if (_loadingCovers && _availableCovers.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: AppColors.primary)))
            else if (_availableCovers.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Color(0xFF64748B)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'As capas são sincronizadas diretamente do catálogo em nuvem. Seleção padrão ativa: $_selectedCover',
                        style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF334155)),
                      ),
                    ),
                  ],
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = constraints.maxWidth > 900
                      ? 4
                      : constraints.maxWidth > 600
                          ? 3
                          : 2;

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.72,
                    ),
                    itemCount: _availableCovers.length,
                    itemBuilder: (context, idx) {
                      final coverName = _availableCovers[idx];
                      final isSelected = _selectedCover == coverName;
                      final thumbUrl = SolarSettingsService.getSmallCoverUrl(coverName);

                      return InkWell(
                        onTap: () => setState(() => _selectedCover = coverName),
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF6366F1) : const Color(0xFFCBD5E1),
                              width: isSelected ? 3 : 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : null,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(isSelected ? 9 : 11),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(
                                  thumbUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (ctx, err, stack) => Container(
                                    color: const Color(0xFF0F172A),
                                    child: Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          coverName,
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B)),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF59E0B),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Icon(Icons.check_circle_rounded, size: 14, color: Colors.white),
                                          SizedBox(width: 4),
                                          Text(
                                            'ATIVO',
                                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    color: Colors.black.withValues(alpha: 0.65),
                                    child: Text(
                                      coverName,
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.inter(fontSize: 10.5, color: Colors.white, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),

            const SizedBox(height: 24),
            const Divider(color: AppColors.divider),
            const SizedBox(height: 16),

            // ── 2. Seletor de Papel de Parede da Proposta Web (34 Modelos) ───
            _label('2. Papel de Parede da Proposta Web Interativa (34 Modelos em Alta Resolução)'),
            const SizedBox(height: 6),
            Text(
              'Escolha a imagem de fundo que o seu cliente verá ao abrir o link da proposta no navegador:',
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),

            LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth > 900
                    ? 5
                    : constraints.maxWidth > 600
                        ? 3
                        : 2;

                final backgrounds = SolarSettingsModel.availableWebBackgrounds;

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.4,
                  ),
                  itemCount: backgrounds.length,
                  itemBuilder: (context, idx) {
                    final bgName = backgrounds[idx];
                    final isSelected = _selectedWebBg == bgName;

                    return InkWell(
                      onTap: () => setState(() => _selectedWebBg = bgName),
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
                            width: isSelected ? 3 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.35),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(isSelected ? 9 : 11),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.asset(
                                'assets/background_web/$bgName',
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, err, stack) => Container(
                                  color: const Color(0xFF0F172A),
                                  child: Center(
                                    child: Text(
                                      'Fundo ${idx + 1}',
                                      style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8)),
                                    ),
                                  ),
                                ),
                              ),
                              if (isSelected)
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Icon(Icons.check_circle_rounded, size: 12, color: Colors.white),
                                        SizedBox(width: 3),
                                        Text(
                                          'WEB ATIVO',
                                          style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
                                  color: Colors.black.withValues(alpha: 0.6),
                                  child: Text(
                                    'Modelo ${idx + 1}',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(fontSize: 9.5, color: Colors.white, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 24),
            const Divider(color: AppColors.divider),
            const SizedBox(height: 16),

            // ── 3. Seletor de Paleta de Cores Minimalista ─────────────────────
            _label('3. Cor de Destaque da Proposta (PDF & Web)'),
            const SizedBox(height: 6),
            Text(
              'A cor temática é aplicada nos cabeçalhos, destaques e cards da proposta comercial:',
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: availableThemes.map((theme) {
                final fileName = theme['fileName'] as String;
                final name = theme['name'] as String;
                final colorValue = (theme['color'] as num?)?.toInt() ?? 0xFF2563EB;
                final isSelected = _selectedSvgTheme == fileName;

                return ChoiceChip(
                  avatar: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Color(colorValue),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                  label: Text(name),
                  selected: isSelected,
                  selectedColor: Color(colorValue).withValues(alpha: 0.2),
                  side: BorderSide(
                    color: isSelected ? Color(colorValue) : const Color(0xFFCBD5E1),
                    width: isSelected ? 2 : 1,
                  ),
                  labelStyle: TextStyle(
                    color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF334155),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12.5,
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _selectedSvgTheme = fileName);
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            // ── 4. Slogan da Empresa no Rodapé ────────────────────────────────
            _label('4. Slogan / Frase de Impacto da Empresa'),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: TextFormField(
                controller: _companySloganCtrl,
                decoration: const InputDecoration(
                  hintText: 'Ex: Energia que Transforma',
                  prefixIcon: Icon(Icons.wb_incandescent_outlined, color: Color(0xFF64748B)),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── 5. Live Preview Card ──────────────────────────────────────────
            _label('5. Prévia Visual da Identidade Minimalista'),
            const SizedBox(height: 10),
            Container(
              constraints: const BoxConstraints(maxWidth: 700),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header Preview
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 3.5,
                            height: 14,
                            decoration: BoxDecoration(
                              color: Color(_settings.copyWith(selectedSvgTheme: _selectedSvgTheme).themeColorValue),
                              borderRadius: BorderRadius.circular(1.5),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'PROPOSTA COMERCIAL',
                            style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A), letterSpacing: 0.8),
                          ),
                        ],
                      ),
                      Text(
                        'PROP-2026/001',
                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Stack(
                    children: [
                      Container(height: 1, color: const Color(0xFFE2E8F0)),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          height: 2,
                          width: 80,
                          color: Color(_settings.copyWith(selectedSvgTheme: _selectedSvgTheme).themeColorValue),
                        ),
                      ),
                    ],
                  ),

                  // Content Placeholder
                  Container(
                    height: 60,
                    alignment: Alignment.center,
                    child: Text(
                      'Conteúdo interno da proposta (Ficha Técnica, Escopo, Análise de Investimento)',
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8), fontStyle: FontStyle.italic),
                    ),
                  ),

                  // Footer Preview
                  Stack(
                    children: [
                      Container(height: 1, color: const Color(0xFFE2E8F0)),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          height: 2,
                          width: 80,
                          color: Color(_settings.copyWith(selectedSvgTheme: _selectedSvgTheme).themeColorValue),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.solar_power_rounded, size: 16, color: Color(_settings.copyWith(selectedSvgTheme: _selectedSvgTheme).themeColorValue)),
                          const SizedBox(width: 6),
                          Text(
                            _companySloganCtrl.text.trim().isNotEmpty ? _companySloganCtrl.text.trim().toUpperCase() : 'ENERGIA QUE TRANSFORMA',
                            style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF64748B), letterSpacing: 1.2),
                          ),
                        ],
                      ),
                      Text(
                        'Página 2 de 6',
                        style: GoogleFonts.inter(fontSize: 9.5, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
        Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
      ],
    );
  }

  Widget _label(String text) {
    return Text(text, style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF334155)));
  }
}
