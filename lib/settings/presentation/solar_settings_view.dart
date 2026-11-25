import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../app/theme/app_colors.dart';
import '../../proposals/data/services/solar_proposal_pdf_service.dart';
import '../../proposals/domain/models/proposal_item_model.dart';
import '../../proposals/domain/models/proposal_model.dart';
import '../../proposals/presentation/web_proposal_page.dart';
import '../data/services/ai_agent_settings_service.dart';
import '../data/services/ai_usage_telemetry_service.dart';
import '../data/services/solar_settings_service.dart';
import '../domain/models/solar_settings_model.dart';
import 'widgets/solar_cover_divider_painter.dart';
import 'widgets/solar_vertical_split_painter.dart';
import 'widgets/solar_cover_customizer_dialog.dart';
import 'widgets/corporate_wave_cover_view.dart';
import 'widgets/cover_header_footer_widgets.dart';
import 'widgets/taos_loading_popup.dart';

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
  final _generationFactorCtrl = TextEditingController();
  final _monoAvailCtrl = TextEditingController();
  final _biAvailCtrl = TextEditingController();
  final _triAvailCtrl = TextEditingController();
  final _defaultCipCtrl = TextEditingController();
  bool _useDetailedBillingCalc = false;
  String _defaultConnectionType = 'Bifásico';
  final _sunHoursCtrl = TextEditingController();
  final _projectionYearsCtrl = TextEditingController();

  // Controllers: Dados da Empresa para a Proposta
  final _companyNameCtrl = TextEditingController();
  final _companyDocCtrl = TextEditingController();
  final _companyPhoneCtrl = TextEditingController();
  final _companyWebsiteCtrl = TextEditingController();
  final _companyInstagramCtrl = TextEditingController();
  final _companySloganCtrl = TextEditingController();

  // Controllers & Estado do Editor em Tempo Real de Capa
  final _coverTitleCtrl = TextEditingController(text: 'PROPOSTA COMERCIAL');
  final _coverSubtitleCtrl = TextEditingController(text: 'ENERGIA SOLAR FOTOVOLTAICA');
  bool _coverShowBadge = true;
  String _coverBadgeColor = '#FFFFFF';
  double _coverBadgeOpacity = 0.92;
  String _coverTitleColor = '#0284C7';
  String _coverSubtitleColor = '#0F172A';
  double _coverTitleFontSize = 26.0;
  double _coverSubtitleFontSize = 11.0;
  double _coverBadgePosX = 0.08;
  double _coverBadgePosY = 0.06;
  bool _isCustomCoverMode = false;
  String? _customCoverImageBase64;
  int _customDividerStyle = 0;
  String _customDividerColor = '#0284C7';
  int _coverPage = 1;
  String _coverSearchQuery = '';
  int _coverSubTab = 0; // 0 = 100 Capas Prontas, 1 = Criar Capa Personalizada

  // ── Estilo de Proposta & Vertical Split ───────────────────────────────
  String _proposalStyle = 'modern'; // 'modern' ou 'verticalSplit'
  String _selectedVerticalSplit = 'vertical_split_1';
  int _verticalSplitDividerType = 0;
  final _verticalSplitHeadlineCtrl = TextEditingController(text: 'ENERGIA\nQUE MOVE\nO SEU\nAMANHÃ');
  final _verticalSplitSubheadlineCtrl = TextEditingController(text: 'MAIS ECONOMIA.\nMAIS LIBERDADE.\nUM FUTURO SUSTENTÁVEL.');
  final _verticalSplitLeftFooterCtrl = TextEditingController(text: 'PESSOAS  •  TECNOLOGIA  •  UM PLANETA MELHOR');
  final _verticalSplitRightTitleCtrl = TextEditingController(text: 'PROPOSTA');
  final _verticalSplitRightSubtitleCtrl = TextEditingController(text: 'SOLAR');
  final _verticalSplitRightTaglineCtrl = TextEditingController(text: 'SOLUÇÕES EM ENERGIA\nPARA UM FUTURO MELHOR');
  final _verticalSplitRightFooterCtrl = TextEditingController(text: 'ENERGIA HOJE.\nMAIS POSSIBILIDADES\nAMANHÃ.');
  String _verticalSplitAccentColor = '#EAB308';
  List<CoverFooterBadge> _verticalSplitFooterBadges = List.from(CoverFooterBadge.defaultBadges());

  // Logomarca Customizada na Capa
  String? _companyLogoBase64;
  bool _coverShowLogo = true;
  double _coverLogoPosX = 0.65;
  double _coverLogoPosY = 0.05;
  double _coverLogoWidth = 90.0;

  // Financiamento & Cartão
  late List<SolarFinancingBank> _banks;
  late List<CreditCardInstallmentRate> _cardRates;
  String _selectedCover = 'modelo_proposta_1.jpg';
  String _selectedSvgTheme = '#2563EB';
  String _secondaryThemeColor = '#102C49';
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

  int _hexToInt(String hexStr, {int fallback = 0xFF0284C7}) {
    final clean = hexStr.replaceAll('#', '').trim();
    if (clean.length == 6) return int.tryParse('FF$clean', radix: 16) ?? fallback;
    if (clean.length == 8) return int.tryParse(clean, radix: 16) ?? fallback;
    return fallback;
  }

  final ValueNotifier<int> _editorTick = ValueNotifier<int>(0);
  final ScrollController _coverCarouselCtrl = ScrollController();
  final ScrollController _webBgCarouselCtrl = ScrollController();
  bool _panelCoverModelsExpanded = true;
  bool _panelWebBgExpanded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _coverTitleCtrl.addListener(() => setState(() {}));
    _coverSubtitleCtrl.addListener(() => setState(() {}));
    _verticalSplitHeadlineCtrl.addListener(() => setState(() {}));
    _verticalSplitSubheadlineCtrl.addListener(() => setState(() {}));
    _verticalSplitLeftFooterCtrl.addListener(() => setState(() {}));
    _verticalSplitRightTitleCtrl.addListener(() => setState(() {}));
    _verticalSplitRightSubtitleCtrl.addListener(() => setState(() {}));
    _verticalSplitRightTaglineCtrl.addListener(() => setState(() {}));
    _verticalSplitRightFooterCtrl.addListener(() => setState(() {}));
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
      _generationFactorCtrl.text = loaded.generationFactor.toStringAsFixed(1).replaceAll('.', ',');
      _useDetailedBillingCalc = loaded.useDetailedBillingCalc;
      _defaultConnectionType = loaded.defaultConnectionType;
      _monoAvailCtrl.text = loaded.monoAvailabilityKwh.toStringAsFixed(0);
      _biAvailCtrl.text = loaded.biAvailabilityKwh.toStringAsFixed(0);
      _triAvailCtrl.text = loaded.triAvailabilityKwh.toStringAsFixed(0);
      _defaultCipCtrl.text = loaded.defaultPublicLightingRs.toStringAsFixed(2).replaceAll('.', ',');
      _sunHoursCtrl.text = loaded.defaultSunHours.toStringAsFixed(1).replaceAll('.', ',');
      _projectionYearsCtrl.text = loaded.projectionYears.toString();

      _companyNameCtrl.text = loaded.companyName ?? '';
      _companyDocCtrl.text = loaded.companyDocument ?? '';
      _companyPhoneCtrl.text = loaded.companyPhone ?? '';
      _companyWebsiteCtrl.text = loaded.companyWebsite ?? '';
      _companyInstagramCtrl.text = loaded.companyInstagram ?? '';
      _companySloganCtrl.text = loaded.companySlogan ?? 'Energia que Transforma';

      _coverTitleCtrl.text = loaded.coverTitle;
      _coverSubtitleCtrl.text = loaded.coverSubtitle;
      _coverShowBadge = loaded.coverShowBadge;
      _coverBadgeColor = loaded.coverBadgeColor;
      _coverBadgeOpacity = loaded.coverBadgeOpacity;
      _coverTitleColor = loaded.coverTitleColor;
      _coverSubtitleColor = loaded.coverSubtitleColor;
      _coverTitleFontSize = loaded.coverTitleFontSize;
      _coverSubtitleFontSize = loaded.coverSubtitleFontSize;
      _coverBadgePosX = loaded.coverBadgePositionX;
      _coverBadgePosY = loaded.coverBadgePositionY;
      _isCustomCoverMode = loaded.isCustomCoverMode;
      _customCoverImageBase64 = loaded.customCoverImageBase64;
      _customDividerStyle = loaded.customDividerStyle;
      _customDividerColor = loaded.customDividerColor;
      _companyLogoBase64 = loaded.companyLogoBase64;
      _coverShowLogo = loaded.coverShowLogo;
      _coverLogoPosX = loaded.coverLogoPositionX;
      _coverLogoPosY = loaded.coverLogoPositionY;
      _coverLogoWidth = loaded.coverLogoWidth;

      _banks = List.from(loaded.financingBanks);
      if (_banks.isEmpty) _banks = SolarFinancingBank.defaultBanks();

      _cardRates = List.from(loaded.creditCardRates);
      if (_cardRates.isEmpty) _cardRates = CreditCardInstallmentRate.defaultRates();

      _selectedCover = loaded.selectedCoverTemplate;
      _selectedSvgTheme = loaded.selectedSvgTheme;
      _secondaryThemeColor = loaded.secondaryThemeColor;
      _selectedWebBg = loaded.webBackgroundTemplate;

      _proposalStyle = loaded.proposalStyle;
      _selectedVerticalSplit = loaded.selectedVerticalSplitTemplate;
      _verticalSplitDividerType = loaded.verticalSplitDividerType;
      _verticalSplitHeadlineCtrl.text = loaded.verticalSplitHeadline;
      _verticalSplitSubheadlineCtrl.text = loaded.verticalSplitSubheadline;
      _verticalSplitLeftFooterCtrl.text = loaded.verticalSplitLeftFooter;
      _verticalSplitRightTitleCtrl.text = loaded.verticalSplitRightTitle;
      _verticalSplitRightSubtitleCtrl.text = loaded.verticalSplitRightSubtitle;
      _verticalSplitRightTaglineCtrl.text = loaded.verticalSplitRightTagline;
      _verticalSplitRightFooterCtrl.text = loaded.verticalSplitRightFooter;
      _verticalSplitAccentColor = loaded.verticalSplitAccentColor;
      _verticalSplitFooterBadges = List.from(loaded.verticalSplitFooterBadges);

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
    _generationFactorCtrl.dispose();
    _monoAvailCtrl.dispose();
    _biAvailCtrl.dispose();
    _triAvailCtrl.dispose();
    _defaultCipCtrl.dispose();
    _sunHoursCtrl.dispose();
    _projectionYearsCtrl.dispose();
    _companyNameCtrl.dispose();
    _companyDocCtrl.dispose();
    _companyPhoneCtrl.dispose();
    _companyWebsiteCtrl.dispose();
    _companyInstagramCtrl.dispose();
    _companySloganCtrl.dispose();
    _coverTitleCtrl.dispose();
    _coverSubtitleCtrl.dispose();
    _verticalSplitHeadlineCtrl.dispose();
    _verticalSplitSubheadlineCtrl.dispose();
    _verticalSplitLeftFooterCtrl.dispose();
    _verticalSplitRightTitleCtrl.dispose();
    _verticalSplitRightSubtitleCtrl.dispose();
    _verticalSplitRightTaglineCtrl.dispose();
    _verticalSplitRightFooterCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    _editorTick.value++;
    bool popupOpen = false;
    if (mounted) {
      popupOpen = true;
      TaosLoadingPopup.show(context, message: 'Salvando Alterações...');
      await Future.delayed(const Duration(milliseconds: 30));
    }

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
        generationFactor: parseD(_generationFactorCtrl.text, 118.0),
        useDetailedBillingCalc: _useDetailedBillingCalc,
        defaultConnectionType: _defaultConnectionType,
        monoAvailabilityKwh: parseD(_monoAvailCtrl.text, 30.0),
        biAvailabilityKwh: parseD(_biAvailCtrl.text, 50.0),
        triAvailabilityKwh: parseD(_triAvailCtrl.text, 100.0),
        defaultPublicLightingRs: parseD(_defaultCipCtrl.text, 45.0),
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
        secondaryThemeColor: _secondaryThemeColor,
        webBackgroundTemplate: (!_isCustomCoverMode && _selectedCover.isNotEmpty) ? _selectedCover : _selectedWebBg,
        coverTitle: _coverTitleCtrl.text.trim().isNotEmpty ? _coverTitleCtrl.text.trim() : 'PROPOSTA COMERCIAL',
        coverSubtitle: _coverSubtitleCtrl.text.trim().isNotEmpty ? _coverSubtitleCtrl.text.trim() : 'ENERGIA SOLAR FOTOVOLTAICA',
        coverShowBadge: _coverShowBadge,
        coverBadgeColor: _coverBadgeColor,
        coverBadgeOpacity: _coverBadgeOpacity,
        coverTitleColor: _coverTitleColor,
        coverSubtitleColor: _coverSubtitleColor,
        coverTitleFontSize: _coverTitleFontSize,
        coverSubtitleFontSize: _coverSubtitleFontSize,
        coverBadgePositionX: _coverBadgePosX,
        coverBadgePositionY: _coverBadgePosY,
        isCustomCoverMode: _isCustomCoverMode,
        customCoverImageBase64: _customCoverImageBase64,
        customDividerStyle: _customDividerStyle,
        customDividerColor: _customDividerColor,
        companyLogoBase64: _companyLogoBase64,
        coverShowLogo: _coverShowLogo,
        coverLogoPositionX: _coverLogoPosX,
        coverLogoPositionY: _coverLogoPosY,
        coverLogoWidth: _coverLogoWidth,
        proposalStyle: _proposalStyle,
        selectedVerticalSplitTemplate: _selectedVerticalSplit,
        verticalSplitDividerType: _verticalSplitDividerType,
        verticalSplitHeadline: _verticalSplitHeadlineCtrl.text,
        verticalSplitSubheadline: _verticalSplitSubheadlineCtrl.text,
        verticalSplitLeftFooter: _verticalSplitLeftFooterCtrl.text,
        verticalSplitRightTitle: _verticalSplitRightTitleCtrl.text,
        verticalSplitRightSubtitle: _verticalSplitRightSubtitleCtrl.text,
        verticalSplitRightTagline: _verticalSplitRightTaglineCtrl.text,
        verticalSplitRightFooter: _verticalSplitRightFooterCtrl.text,
        verticalSplitAccentColor: _verticalSplitAccentColor,
        verticalSplitFooterBadges: _verticalSplitFooterBadges,
      );

      await SolarSettingsService.saveSettings(updated);
      _settings = updated;

      // Sincroniza também o Fator de Geração em segundo plano sem travar o botão
      AiAgentSettingsService.getSettings().then((aiSettings) {
        return AiAgentSettingsService.saveSettings(
          aiSettings.copyWith(defaultGenerationFactor: updated.generationFactor),
        );
      }).catchError((_) {});

      if (mounted && popupOpen) {
        popupOpen = false;
        TaosLoadingPopup.hide(context);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Configurações de Usina Solar salvas com sucesso!'),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted && popupOpen) {
        popupOpen = false;
        TaosLoadingPopup.hide(context);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro ao salvar: $e'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted && popupOpen) {
        TaosLoadingPopup.hide(context);
      }
      if (mounted) {
        setState(() => _isSaving = false);
        _editorTick.value++;
      }
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
                    solarSettings: _buildCurrentLiveSettings().copyWith(
                      selectedCoverTemplate: _selectedCover,
                      selectedSvgTheme: _selectedSvgTheme,
                      secondaryThemeColor: _secondaryThemeColor,
                      webBackgroundTemplate: _selectedWebBg,
                      coverTitle: _coverTitleCtrl.text.trim().isNotEmpty ? _coverTitleCtrl.text.trim() : 'PROPOSTA COMERCIAL',
                      coverSubtitle: _coverSubtitleCtrl.text.trim().isNotEmpty ? _coverSubtitleCtrl.text.trim() : 'ENERGIA SOLAR FOTOVOLTAICA',
                      coverShowBadge: _coverShowBadge,
                      coverBadgeColor: _coverBadgeColor,
                      coverBadgeOpacity: _coverBadgeOpacity,
                      coverTitleColor: _coverTitleColor,
                      coverSubtitleColor: _coverSubtitleColor,
                      coverTitleFontSize: _coverTitleFontSize,
                      coverSubtitleFontSize: _coverSubtitleFontSize,
                      coverBadgePositionX: _coverBadgePosX,
                      coverBadgePositionY: _coverBadgePosY,
                      isCustomCoverMode: _isCustomCoverMode,
                      customCoverImageBase64: _customCoverImageBase64,
                      customDividerStyle: _customDividerStyle,
                      customDividerColor: _customDividerColor,
                    ),
                  ),
                  allowPrinting: true,
                  allowSharing: true,
                  canChangePageFormat: false,
                  scrollViewDecoration: TaosLoadingPopup.pdfBackdropDecoration,
                  loadingWidget: TaosLoadingPopup.pdfLoadingWidget(),
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
                  onTap: (index) {
                    if (index == 4) {
                      final prev = _tabController.previousIndex;
                      _tabController.index = prev == 4 ? 0 : prev;
                      _openFullscreenProposalEditor();
                    }
                  },
                  isScrollable: true,
                  labelColor: const Color(0xFFD97706),
                  unselectedLabelColor: const Color(0xFF64748B),
                  indicatorColor: const Color(0xFFF59E0B),
                  indicatorWeight: 3,
                  labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                  unselectedLabelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
                  tabs: const [
                    Tab(icon: Icon(Icons.bolt_rounded), text: '1. Concessionária & Tarifas'),
                    Tab(icon: Icon(Icons.wb_sunny_outlined), text: '2. Simultaneidade & Fator de Geração'),
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

            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _useDetailedBillingCalc ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _useDetailedBillingCalc ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: const Color(0xFF10B981),
                    title: Text(
                      'Cálculo Detalhado: Padrão (Mono / Bi / Tri) + Iluminação Pública',
                      style: GoogleFonts.outfit(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    subtitle: Text(
                      _useDetailedBillingCalc
                          ? 'LIGADO — A proposta usa a taxa de disponibilidade (Mono/Bi/Tri) + Iluminação Pública nos cálculos Com e Sem Solar.'
                          : 'DESLIGADO — Mantém o cálculo padrão simplificado (Fio B + R\$ 65 a R\$ 95 estimados).',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                    ),
                    value: _useDetailedBillingCalc,
                    onChanged: (val) => setState(() => _useDetailedBillingCalc = val),
                  ),
                  if (_useDetailedBillingCalc) ...[
                    const SizedBox(height: 12),
                    const Divider(color: Color(0xFFDCFCE7)),
                    const SizedBox(height: 12),
                    _label('Padrão de Ligação Padrão (Presets)'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: ['Monofásico', 'Bifásico', 'Trifásico'].map((type) {
                        final selected = _defaultConnectionType == type;
                        return ChoiceChip(
                          label: Text(type),
                          selected: selected,
                          selectedColor: const Color(0xFF10B981).withValues(alpha: 0.18),
                          side: BorderSide(
                            color: selected ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
                            width: selected ? 1.8 : 1,
                          ),
                          labelStyle: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                            color: const Color(0xFF0F172A),
                          ),
                          onSelected: (v) {
                            if (v) setState(() => _defaultConnectionType = type);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: 170,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label('Monofásico (kWh)'),
                              const SizedBox(height: 6),
                              _tariffField(_monoAvailCtrl, '30'),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 170,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label('Bifásico (kWh)'),
                              const SizedBox(height: 6),
                              _tariffField(_biAvailCtrl, '50'),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 170,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label('Trifásico (kWh)'),
                              const SizedBox(height: 6),
                              _tariffField(_triAvailCtrl, '100'),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 210,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label('Iluminação Pública (R\$)'),
                              const SizedBox(height: 6),
                              _tariffField(_defaultCipCtrl, '45,00'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),
            const Divider(color: AppColors.divider),
            const SizedBox(height: 16),

            _sectionTitle('Dados da Empresa Integradora (Exibidos na Capa do PDF)', 'Nome, CNPJ e contatos que aparecem no rodapé da capa da proposta'),
            const SizedBox(height: 16),

            if (isMobile) ...[
              _label('Razão Social / Nome Fantasia'),
              const SizedBox(height: 6),
              TextFormField(controller: _companyNameCtrl, decoration: const InputDecoration(hintText: 'Ex: Minha Empresa / Razão Social')),
              const SizedBox(height: 12),
              _label('CNPJ / CPF'),
              const SizedBox(height: 6),
              TextFormField(controller: _companyDocCtrl, decoration: const InputDecoration(hintText: '00.000.000/0000-00')),
              const SizedBox(height: 12),
              _label('Telefone / WhatsApp'),
              const SizedBox(height: 6),
              TextFormField(controller: _companyPhoneCtrl, decoration: const InputDecoration(hintText: '(00) 00000-0000')),
              const SizedBox(height: 12),
              _label('Site Oficial'),
              const SizedBox(height: 6),
              TextFormField(controller: _companyWebsiteCtrl, decoration: const InputDecoration(hintText: 'www.suaempresa.com.br')),
              const SizedBox(height: 12),
              _label('Instagram / Redes'),
              const SizedBox(height: 6),
              TextFormField(controller: _companyInstagramCtrl, decoration: const InputDecoration(hintText: '@suaempresa')),
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
                        TextFormField(controller: _companyNameCtrl, decoration: const InputDecoration(hintText: 'Ex: Minha Empresa / Razão Social', prefixIcon: Icon(Icons.solar_power_outlined, color: Color(0xFF64748B)))),
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
                        TextFormField(controller: _companyDocCtrl, decoration: const InputDecoration(hintText: '00.000.000/0000-00', prefixIcon: Icon(Icons.badge_outlined, color: Color(0xFF64748B)))),
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
                        TextFormField(controller: _companyPhoneCtrl, decoration: const InputDecoration(hintText: '(00) 00000-0000', prefixIcon: Icon(Icons.phone_outlined, color: Color(0xFF64748B)))),
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
                        TextFormField(controller: _companyWebsiteCtrl, decoration: const InputDecoration(hintText: 'www.suaempresa.com.br', prefixIcon: Icon(Icons.language_rounded, color: Color(0xFF64748B)))),
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
                        TextFormField(controller: _companyInstagramCtrl, decoration: const InputDecoration(hintText: '@suaempresa', prefixIcon: Icon(Icons.camera_alt_outlined, color: Color(0xFF64748B)))),
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

            const SizedBox(height: 24),
            const Divider(color: AppColors.divider),
            const SizedBox(height: 20),

            // Fator de Geração Regional (Sincronizado com o Agente de IA)
            _label('Fator de Geração Regional (kWh/kWp) — Sincronizado com a IA'),
            const SizedBox(height: 6),
            Text(
              'Define o multiplicador usado pelo sistema e pelo Agente de IA no WhatsApp (opção 4) para calcular a geração estimada da usina. Alterar aqui atualiza automaticamente a IA.',
              style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF64748B), height: 1.4),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 260,
                  child: TextFormField(
                    controller: _generationFactorCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Ex: 118,0',
                      prefixIcon: Icon(Icons.bolt_rounded, color: Color(0xFF10B981)),
                      suffixText: 'kWh/kWp',
                    ),
                  ),
                ),
                Builder(
                  builder: (_) {
                    final factor = double.tryParse(_generationFactorCtrl.text.replaceAll(',', '.').trim()) ?? 118.0;
                    final sampleGen = (8.25 * factor).round();
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.auto_awesome_rounded, color: Color(0xFF059669), size: 20),
                          const SizedBox(width: 10),
                          Text(
                            'Simulação: caso o sistema seja 8,25 kWp, a geração sugerida será $sampleGen kWh/mês',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF065F46),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
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
                        InkWell(
                          onTap: () async {
                            final b64 = await _pickBankLogoBase64();
                            if (b64 != null) {
                              setState(() {
                                _banks[idx] = bank.copyWith(logoBase64: b64);
                              });
                            }
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 68,
                            height: 44,
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: (bank.logoBase64 != null && bank.logoBase64!.isNotEmpty)
                                  ? Colors.white
                                  : const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: (bank.logoBase64 != null && bank.logoBase64!.isNotEmpty)
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.memory(
                                      base64Decode(
                                        bank.logoBase64!.contains(',')
                                            ? bank.logoBase64!.split(',').last
                                            : bank.logoBase64!,
                                      ),
                                      fit: BoxFit.contain,
                                    ),
                                  )
                                : const Icon(Icons.account_balance_rounded, color: AppColors.primary, size: 22),
                          ),
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
                              Row(
                                children: [
                                  Text(
                                    'Taxa: ${bank.monthlyInterestRate.toStringAsFixed(2)}% ao mês',
                                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                                  ),
                                  const SizedBox(width: 8),
                                  InkWell(
                                    onTap: () async {
                                      final b64 = await _pickBankLogoBase64();
                                      if (b64 != null) {
                                        setState(() {
                                          _banks[idx] = bank.copyWith(logoBase64: b64);
                                        });
                                      }
                                    },
                                    child: Text(
                                      (bank.logoBase64 != null && bank.logoBase64!.isNotEmpty)
                                          ? 'Alterar logo'
                                          : '+ Enviar logo',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                  if (bank.logoBase64 != null && bank.logoBase64!.isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    InkWell(
                                      onTap: () => setState(() {
                                        _banks[idx] = bank.copyWith(clearLogoBase64: true);
                                      }),
                                      child: Text(
                                        'Remover',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFFEF4444),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
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

  Future<String?> _pickBankLogoBase64() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
      );
      if (files.isNotEmpty) {
        final bytes = await files.first.readAsBytes();
        return base64Encode(bytes);
      }
    } catch (e) {
      debugPrint('[SolarSettingsView] Erro ao selecionar logo do banco: $e');
    }
    return null;
  }

  void _openAddBankDialog() {
    final nameCtrl = TextEditingController();
    final rateCtrl = TextEditingController(text: '1,25');
    String? pickedLogoBase64;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Adicionar Banco / Financeira', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              const SizedBox(height: 14),
              InkWell(
                onTap: () async {
                  final b64 = await _pickBankLogoBase64();
                  if (b64 != null) {
                    setDialogState(() => pickedLogoBase64 = b64);
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      if (pickedLogoBase64 != null)
                        Container(
                          width: 48,
                          height: 32,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Image.memory(base64Decode(pickedLogoBase64!), fit: BoxFit.contain),
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.only(right: 10),
                          child: Icon(Icons.add_photo_alternate_outlined, color: AppColors.primary, size: 22),
                        ),
                      Expanded(
                        child: Text(
                          pickedLogoBase64 != null
                              ? 'Logo selecionada (clique para alterar)'
                              : 'Logo da financiadora (PNG/JPG - opcional)',
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF475569), fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
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
                      logoBase64: pickedLogoBase64,
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
  // ───────────────────────────────────────────────────────────────────────────
  // ABA 5: MODELO DE PROPOSTA COMERCIAL (EDITOR EM TEMPO REAL + 100 CAPAS)
  // ───────────────────────────────────────────────────────────────────────────
  Future<void> _openFullscreenProposalEditor() async {
    TaosLoadingPopup.show(
      context,
      message: 'Aguarde... Carregando o Editor de Propostas',
    );
    await Future.delayed(const Duration(milliseconds: 550));
    if (!mounted) return;
    TaosLoadingPopup.hide(context);

    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ValueListenableBuilder<int>(
          valueListenable: _editorTick,
          builder: (ctx, _, __) => Scaffold(
            backgroundColor: const Color(0xFF0F172A),
            appBar: AppBar(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Voltar para Configurações',
                onPressed: () =>
                    Navigator.of(context, rootNavigator: true).pop(),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Editor de Propostas TAOS',
                    style: GoogleFonts.outfit(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white),
                  ),
                  Text(
                    'Capas, estilos, papel de parede web e identidade visual',
                    style: GoogleFonts.inter(
                        fontSize: 11, color: const Color(0xFF94A3B8)),
                  ),
                ],
              ),
              actions: [
                TextButton.icon(
                  onPressed: _previewWebProposal,
                  icon: const Icon(Icons.language_rounded,
                      size: 17, color: Color(0xFF34D399)),
                  label: Text('PRÉVIA WEB',
                      style: GoogleFonts.inter(
                          color: const Color(0xFF34D399),
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 6),
                TextButton.icon(
                  onPressed: _previewProposalPdf,
                  icon: const Icon(Icons.picture_as_pdf_rounded,
                      size: 17, color: Color(0xFFF87171)),
                  label: Text('PRÉVIA PDF',
                      style: GoogleFonts.inter(
                          color: const Color(0xFFF87171),
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveSettings,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.save_rounded, size: 17),
                    label:
                        Text(_isSaving ? 'SALVANDO...' : 'SALVAR ALTERAÇÕES'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      textStyle: GoogleFonts.inter(
                          fontWeight: FontWeight.w800, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildProposalTemplateTab(false),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsiblePanel({
    required IconData icon,
    required Color accentColor,
    required String title,
    required String subtitle,
    required bool isExpanded,
    required VoidCallback onToggle,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpanded
              ? accentColor.withValues(alpha: 0.45)
              : AppColors.border,
          width: isExpanded ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(15),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: accentColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          subtitle,
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF64748B),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1, color: AppColors.divider),
            Padding(
              padding: const EdgeInsets.all(16),
              child: child,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHorizontalCarousel({
    required ScrollController controller,
    required double height,
    required int itemCount,
    required IndexedWidgetBuilder itemBuilder,
    double itemWidth = 175,
  }) {
    void scrollBy(double delta) {
      if (!controller.hasClients) return;
      final target = (controller.offset + delta)
          .clamp(0.0, controller.position.maxScrollExtent);
      controller.animateTo(
        target,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    }

    return SizedBox(
      height: height,
      child: Stack(
        children: [
          Scrollbar(
            controller: controller,
            thumbVisibility: true,
            child: ListView.separated(
              controller: controller,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              itemCount: itemCount,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (ctx, idx) => SizedBox(
                width: itemWidth,
                child: itemBuilder(ctx, idx),
              ),
            ),
          ),
          Positioned(
            left: 2,
            top: (height - 36) / 2,
            child: Material(
              color: const Color(0xFF0F172A).withValues(alpha: 0.85),
              shape: const CircleBorder(),
              elevation: 4,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => scrollBy(-(itemWidth * 2)),
                child: const Padding(
                  padding: EdgeInsets.all(7),
                  child: Icon(Icons.chevron_left_rounded,
                      color: Colors.white, size: 22),
                ),
              ),
            ),
          ),
          Positioned(
            right: 2,
            top: (height - 36) / 2,
            child: Material(
              color: const Color(0xFF0F172A).withValues(alpha: 0.85),
              shape: const CircleBorder(),
              elevation: 4,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => scrollBy(itemWidth * 2),
                child: const Padding(
                  padding: EdgeInsets.all(7),
                  child: Icon(Icons.chevron_right_rounded,
                      color: Colors.white, size: 22),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProposalTemplateTab(bool isMobile) {
    final availableThemes = SolarSettingsService.getAvailableSvgThemes();
    return SingleChildScrollView(
      child: Container(
        padding: EdgeInsets.all(isMobile ? 14 : 22),
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
                  'Estúdio de Capas & Modelo Visual da Proposta',
                  'Edite o título, cores e arraste o retângulo em tempo real na capa, ou monte sua própria capa',
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

            // ── ESTÚDIO PRINCIPAL DE CAPAS (2 COLUNAS: LIVE PREVIEW + CONTROLES) ─
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 920;

                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // COLUNA ESQUERDA: LIVE PREVIEW A4 INTERATIVO
                      SizedBox(
                        width: 360,
                        child: _buildLiveCoverPreviewCard(),
                      ),
                      const SizedBox(width: 24),

                      // COLUNA DIREITA: PAINEL COLAPSÁVEL DE CAPAS & CONTROLES
                      Expanded(
                        child: _buildCollapsiblePanel(
                          icon: Icons.layers_rounded,
                          accentColor: const Color(0xFF6366F1),
                          title: '1. Modelos de Capa & Estilo da Proposta',
                          subtitle:
                              'Escolha o estilo e deslize horizontalmente pelos modelos de capa',
                          isExpanded: _panelCoverModelsExpanded,
                          onToggle: () {
                            setState(() => _panelCoverModelsExpanded =
                                !_panelCoverModelsExpanded);
                            _editorTick.value++;
                          },
                          child: _buildCoverStudioControls(),
                        ),
                      ),
                    ],
                  );
                } else {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: SizedBox(
                          width: constraints.maxWidth.clamp(280.0, 360.0),
                          child: _buildLiveCoverPreviewCard(),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildCoverStudioControls(),
                    ],
                  );
                }
              },
            ),

            const SizedBox(height: 18),

            // ── 2. Painel Colapsável: Papel de Parede da Proposta Web (Scroll Horizontal) ──
            _buildCollapsiblePanel(
              icon: Icons.wallpaper_rounded,
              accentColor: const Color(0xFF10B981),
              title: '2. Papel de Parede da Proposta Web Interativa (34 Modelos)',
              subtitle:
                  'Escolha em scroll horizontal a imagem de fundo do link web da proposta',
              isExpanded: _panelWebBgExpanded,
              onToggle: () {
                setState(() => _panelWebBgExpanded = !_panelWebBgExpanded);
                _editorTick.value++;
              },
              child: Builder(
                builder: (context) {
                  final backgrounds = SolarSettingsModel.availableWebBackgrounds;
                  return _buildHorizontalCarousel(
                    controller: _webBgCarouselCtrl,
                    height: 155,
                    itemWidth: 210,
                    itemCount: backgrounds.length,
                    itemBuilder: (context, idx) {
                      final bgName = backgrounds[idx];
                      final isSelected = _selectedWebBg == bgName;

                      return InkWell(
                        onTap: () {
                          setState(() => _selectedWebBg = bgName);
                          _editorTick.value++;
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFCBD5E1),
                              width: isSelected ? 3 : 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF10B981)
                                          .withValues(alpha: 0.35),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : null,
                          ),
                          child: ClipRRect(
                            borderRadius:
                                BorderRadius.circular(isSelected ? 9 : 11),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(
                                  SolarSettingsService.getWebBackgroundUrl(bgName),
                                  fit: BoxFit.cover,
                                  errorBuilder: (ctx, err, stack) => Container(
                                    color: const Color(0xFF0F172A),
                                    child: Center(
                                      child: Text(
                                        'Fundo ${idx + 1}',
                                        style: GoogleFonts.inter(
                                            fontSize: 10,
                                            color: const Color(0xFF94A3B8)),
                                      ),
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  Positioned(
                                    top: 6,
                                    right: 6,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Icon(Icons.check_circle_rounded,
                                              size: 12, color: Colors.white),
                                          SizedBox(width: 3),
                                          Text(
                                            'WEB ATIVO',
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold),
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
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 3, horizontal: 4),
                                    color: Colors.black.withValues(alpha: 0.6),
                                    child: Text(
                                      'Modelo ${idx + 1}',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.inter(
                                          fontSize: 9.5,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600),
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
            ),

            const SizedBox(height: 24),
            const Divider(color: AppColors.divider),
            const SizedBox(height: 16),

            // ── 3. Seletor de Paleta de Cores (Principal + Secundária) + Preview Realtime ──
            _label('3. Paleta de Cores da Proposta (PDF & Web)'),
            const SizedBox(height: 6),
            Text(
              'Escolha a cor principal (faixa superior, destaques e ícones) e a cor secundária (banners e blocos escuros) e acompanhe a prévia da página interna em tempo real:',
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 860;
                final primaryColor = _parseHexColor(_selectedSvgTheme, 0xFF2563EB);
                final secondaryColor = _parseHexColor(_secondaryThemeColor, 0xFF102C49);

                final controls = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(color: primaryColor, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Cor Principal (Destaques, Faixa & Ícones)',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ...availableThemes.map((theme) {
                        final fileName = theme['fileName'] as String;
                        final name = theme['name'] as String;
                        final colorValue = (theme['color'] as num?)?.toInt() ?? 0xFF2563EB;
                        final isSelected = _selectedSvgTheme.toUpperCase() == fileName.toUpperCase();

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
                          backgroundColor: const Color(0xFF1E293B),
                          selectedColor: Color(colorValue).withValues(alpha: 0.35),
                          checkmarkColor: Colors.white,
                          side: BorderSide(
                            color: isSelected ? Color(colorValue) : const Color(0xFF475569),
                            width: isSelected ? 2 : 1,
                          ),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : const Color(0xFFE2E8F0),
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            fontSize: 12,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setState(() => _selectedSvgTheme = fileName);
                              _editorTick.value++;
                            }
                          },
                        );
                      }),
                        ActionChip(
                          avatar: const Icon(Icons.colorize_rounded, size: 15, color: Color(0xFF38BDF8)),
                          label: const Text('Cor Personalizada'),
                          backgroundColor: const Color(0xFF0F172A),
                          side: const BorderSide(color: Color(0xFF38BDF8), width: 1.2),
                          labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                          onPressed: () => _openCustomTonePickerDialog(
                            title: 'Cor Principal Personalizada',
                            initialColor: primaryColor,
                            onPickHex: (hex) {
                              setState(() => _selectedSvgTheme = hex);
                              _editorTick.value++;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(color: secondaryColor, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Cor Secundária (Banners & Blocos Escuros)',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ...[
                        {'name': 'Azul Marinho (Padrão)', 'hex': '#102C49', 'color': 0xFF102C49},
                        {'name': 'Azul Noite', 'hex': '#041E42', 'color': 0xFF041E42},
                        {'name': 'Ardósia Escuro', 'hex': '#0F172A', 'color': 0xFF0F172A},
                        {'name': 'Petróleo Escuro', 'hex': '#0C4A6E', 'color': 0xFF0C4A6E},
                        {'name': 'Turquesa Profundo', 'hex': '#115E59', 'color': 0xFF115E59},
                        {'name': 'Verde Floresta', 'hex': '#064E3B', 'color': 0xFF064E3B},
                        {'name': 'Verde Musgo', 'hex': '#14532D', 'color': 0xFF14532D},
                        {'name': 'Índigo Profundo', 'hex': '#1E1B4B', 'color': 0xFF1E1B4B},
                        {'name': 'Roxo Executivo', 'hex': '#3B0764', 'color': 0xFF3B0764},
                        {'name': 'Grafite Solar', 'hex': '#1E293B', 'color': 0xFF1E293B},
                        {'name': 'Carvão Neutro', 'hex': '#18181B', 'color': 0xFF18181B},
                        {'name': 'Terracota Escuro', 'hex': '#450A0A', 'color': 0xFF450A0A},
                        {'name': 'Vinho Borgonha', 'hex': '#500724', 'color': 0xFF500724},
                        {'name': 'Bronze Escuro', 'hex': '#431407', 'color': 0xFF431407},
                      ].map((item) {
                        final hex = item['hex'] as String;
                        final name = item['name'] as String;
                        final colorValue = item['color'] as int;
                        final isSelected = _secondaryThemeColor.toUpperCase() == hex.toUpperCase();

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
                          backgroundColor: const Color(0xFF1E293B),
                          selectedColor: Color(colorValue).withValues(alpha: 0.45),
                          checkmarkColor: Colors.white,
                          side: BorderSide(
                            color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF475569),
                            width: isSelected ? 2 : 1,
                          ),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : const Color(0xFFE2E8F0),
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            fontSize: 12,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setState(() => _secondaryThemeColor = hex);
                              _editorTick.value++;
                            }
                          },
                        );
                      }),
                        ActionChip(
                          avatar: const Icon(Icons.colorize_rounded, size: 15, color: Color(0xFF38BDF8)),
                          label: const Text('Cor Personalizada'),
                          backgroundColor: const Color(0xFF0F172A),
                          side: const BorderSide(color: Color(0xFF38BDF8), width: 1.2),
                          labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                          onPressed: () => _openCustomTonePickerDialog(
                            title: 'Cor Secundária Personalizada',
                            initialColor: secondaryColor,
                            onPickHex: (hex) {
                              setState(() => _secondaryThemeColor = hex);
                              _editorTick.value++;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.palette_outlined, size: 16, color: primaryColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Paleta ativa: Principal ${_selectedSvgTheme.toUpperCase()}  •  Secundária ${_secondaryThemeColor.toUpperCase()}',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF334155),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildQuickHeaderFooterColorControls(),
                  ],
                );

                final liveInternalPreview = _buildInternalPageColorPreview(
                  primaryColor: primaryColor,
                  secondaryColor: secondaryColor,
                );

                if (isWide) {
                  return _StickySectionPreviewRow(
                    controls: controls,
                    preview: liveInternalPreview,
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    controls,
                    const SizedBox(height: 18),
                    liveInternalPreview,
                  ],
                );
              },
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _openCustomTonePickerDialog({
    required String title,
    required Color initialColor,
    required ValueChanged<String> onPickHex,
  }) async {
    HSVColor hsv = HSVColor.fromColor(initialColor);
    String toHex(Color c) {
      final r = (c.r * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
      final g = (c.g * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
      final b = (c.b * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
      return '#${r.toUpperCase()}${g.toUpperCase()}${b.toUpperCase()}';
    }

    final hexCtrl = TextEditingController(text: toHex(initialColor));

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final currentColor = hsv.toColor();
          return Dialog(
            backgroundColor: const Color(0xFF0F172A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: Color(0xFF334155)),
            ),
            child: Container(
              width: 390,
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: currentColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.outfit(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Matiz (Cor)', style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFFCBD5E1), fontWeight: FontWeight.w600)),
                  Slider(
                    value: hsv.hue,
                    min: 0,
                    max: 360,
                    activeColor: currentColor,
                    onChanged: (v) {
                      setDialogState(() {
                        hsv = hsv.withHue(v);
                        hexCtrl.text = toHex(hsv.toColor());
                      });
                    },
                  ),
                  Text('Saturação', style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFFCBD5E1), fontWeight: FontWeight.w600)),
                  Slider(
                    value: hsv.saturation,
                    min: 0,
                    max: 1,
                    activeColor: currentColor,
                    onChanged: (v) {
                      setDialogState(() {
                        hsv = hsv.withSaturation(v);
                        hexCtrl.text = toHex(hsv.toColor());
                      });
                    },
                  ),
                  Text('Luminosidade / Brilho', style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFFCBD5E1), fontWeight: FontWeight.w600)),
                  Slider(
                    value: hsv.value,
                    min: 0.05,
                    max: 1,
                    activeColor: currentColor,
                    onChanged: (v) {
                      setDialogState(() {
                        hsv = hsv.withValue(v);
                        hexCtrl.text = toHex(hsv.toColor());
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: hexCtrl,
                    style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      labelText: 'Código Hexadecimal (#RRGGBB)',
                      labelStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 12),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onChanged: (val) {
                      final cleaned = val.replaceAll('#', '').trim();
                      if (cleaned.length == 6) {
                        final parsed = int.tryParse('FF$cleaned', radix: 16);
                        if (parsed != null) {
                          setDialogState(() => hsv = HSVColor.fromColor(Color(parsed)));
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Cancelar', style: TextStyle(color: Color(0xFF94A3B8))),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          onPickHex(toHex(hsv.toColor()));
                          Navigator.of(ctx).pop();
                        },
                        icon: const Icon(Icons.check_rounded, size: 17),
                        label: const Text('Aplicar Tom'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Color _parseHexColor(String hex, int fallback) {
    final cleaned = hex.replaceAll('#', '').trim();
    if (cleaned.length == 6) {
      return Color(int.tryParse('FF$cleaned', radix: 16) ?? fallback);
    }
    if (cleaned.length == 8) {
      return Color(int.tryParse(cleaned, radix: 16) ?? fallback);
    }
    return Color(fallback);
  }

  Widget _buildQuickHeaderFooterColorControls() {
    const bgPresets = <Map<String, String>>[
      {'label': 'Azul Marinho', 'hex': '#0F172A'},
      {'label': 'Azul Corp.', 'hex': '#0284C7'},
      {'label': 'Esmeralda', 'hex': '#10B981'},
      {'label': 'Laranja', 'hex': '#F97316'},
      {'label': 'Dourado', 'hex': '#F59E0B'},
      {'label': 'Roxo', 'hex': '#7C3AED'},
      {'label': 'Vinho', 'hex': '#500724'},
      {'label': 'Branco', 'hex': '#FFFFFF'},
    ];
    const textPresets = <Map<String, String>>[
      {'label': 'Branco', 'hex': '#FFFFFF'},
      {'label': 'Gelo', 'hex': '#E2E8F0'},
      {'label': 'Grafite', 'hex': '#0F172A'},
      {'label': 'Ardósia', 'hex': '#334155'},
      {'label': 'Dourado', 'hex': '#FBBF24'},
    ];

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
            children: [
              const Icon(Icons.view_day_outlined, size: 16, color: Color(0xFF0284C7)),
              const SizedBox(width: 8),
              Text(
                'Cabeçalho e Rodapé (Modo Rápido)',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildQuickColorPickerRow(
            title: 'Cabeçalho — Fundo (${_settings.coverHeaderBgColor.toUpperCase()})',
            selectedHex: _settings.coverHeaderBgColor,
            presets: bgPresets,
            dialogTitle: 'Cor de Fundo do Cabeçalho',
            onSelectHex: (hex) {
              setState(() {
                _settings = _settings.copyWith(coverHeaderBgColor: hex);
                _editorTick.value++;
              });
            },
          ),
          const SizedBox(height: 10),
          _buildQuickColorPickerRow(
            title: 'Cabeçalho — Texto (${_settings.coverHeaderTextColor.toUpperCase()})',
            selectedHex: _settings.coverHeaderTextColor,
            presets: textPresets,
            dialogTitle: 'Cor do Texto do Cabeçalho',
            onSelectHex: (hex) {
              setState(() {
                _settings = _settings.copyWith(coverHeaderTextColor: hex);
                _editorTick.value++;
              });
            },
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: Color(0xFFE2E8F0)),
          ),
          _buildQuickColorPickerRow(
            title: 'Rodapé — Fundo (${_settings.coverFooterBgColor.toUpperCase()})',
            selectedHex: _settings.coverFooterBgColor,
            presets: bgPresets,
            dialogTitle: 'Cor de Fundo do Rodapé',
            onSelectHex: (hex) {
              setState(() {
                _settings = _settings.copyWith(coverFooterBgColor: hex);
                _editorTick.value++;
              });
            },
          ),
          const SizedBox(height: 10),
          _buildQuickColorPickerRow(
            title: 'Rodapé — Texto (${_settings.coverFooterTextColor.toUpperCase()})',
            selectedHex: _settings.coverFooterTextColor,
            presets: textPresets,
            dialogTitle: 'Cor do Texto do Rodapé',
            onSelectHex: (hex) {
              setState(() {
                _settings = _settings.copyWith(coverFooterTextColor: hex);
                _editorTick.value++;
              });
            },
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: Color(0xFFE2E8F0)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mostrar Slogan / Rodapé Minimalista (PDF)',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'Quando desligado, oculta texto, linha e "Página X de X" no PDF',
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: _settings.showPdfSloganFooter,
                      activeTrackColor: const Color(0xFF10B981),
                      onChanged: (val) {
                        setState(() {
                          _settings = _settings.copyWith(showPdfSloganFooter: val);
                          _editorTick.value++;
                        });
                      },
                    ),
                  ],
                ),
                if (_settings.showPdfSloganFooter) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: _companySloganCtrl,
                    onChanged: (val) {
                      _settings = _settings.copyWith(companySlogan: val.trim());
                      _editorTick.value++;
                    },
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: const Color(0xFF0F172A),
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Slogan / Frase do Rodapé',
                      hintText: 'Ex: ENERGIA QUE TRANSFORMA',
                      isDense: true,
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickColorPickerRow({
    required String title,
    required String selectedHex,
    required List<Map<String, String>> presets,
    required String dialogTitle,
    required ValueChanged<String> onSelectHex,
  }) {
    final normalizedSelected = selectedHex.trim().toUpperCase();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...presets.map((item) {
              final hex = item['hex']!;
              final label = item['label']!;
              final isSelected = normalizedSelected == hex.toUpperCase();
              final chipColor = _parseHexColor(hex, 0xFF0F172A);
              return ChoiceChip(
                label: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.white : const Color(0xFFE2E8F0),
                  ),
                ),
                avatar: CircleAvatar(
                  backgroundColor: chipColor,
                  radius: 7,
                  child: isSelected
                      ? Icon(
                          Icons.check,
                          size: 9,
                          color: chipColor.computeLuminance() > 0.6 ? Colors.black : Colors.white,
                        )
                      : null,
                ),
                selected: isSelected,
                selectedColor: const Color(0xFF0F172A),
                backgroundColor: const Color(0xFF1E293B),
                side: BorderSide(
                  color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF334155),
                  width: isSelected ? 1.5 : 1,
                ),
                onSelected: (_) => onSelectHex(hex),
              );
            }),
            ActionChip(
              avatar: const Icon(Icons.colorize_rounded, size: 14, color: Color(0xFF38BDF8)),
              label: Text(
                'Cor Personalizada',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              backgroundColor: const Color(0xFF0F172A),
              side: const BorderSide(color: Color(0xFF0284C7), width: 1.2),
              onPressed: () => _openCustomTonePickerDialog(
                title: dialogTitle,
                initialColor: _parseHexColor(selectedHex, 0xFF0F172A),
                onPickHex: onSelectHex,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInternalPageColorPreview({
    required Color primaryColor,
    required Color secondaryColor,
  }) {
    final headerBgColor = _settings.coverHeaderBgColor.trim().isNotEmpty
        ? _parseHexColor(_settings.coverHeaderBgColor, 0xFF0284C7)
        : primaryColor;
    final headerTextColor = _settings.coverHeaderTextColor.trim().isNotEmpty
        ? _parseHexColor(_settings.coverHeaderTextColor, 0xFFFFFFFF)
        : Colors.white;
    final footerBgColor = _settings.coverFooterBgColor.trim().isNotEmpty
        ? _parseHexColor(_settings.coverFooterBgColor, 0xFF0F172A)
        : secondaryColor;
    final footerTextColor = _settings.coverFooterTextColor.trim().isNotEmpty
        ? _parseHexColor(_settings.coverFooterTextColor, 0xFFFFFFFF)
        : Colors.white;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Ribbon (Cabeçalho idêntico ao editor da popup)
          if (_settings.coverShowHeader)
            CoverHeaderWidget(
              styleId: _settings.coverHeaderStyle,
              text1: _settings.coverHeaderStyle == 11
                  ? (_settings.pdfPageTitle2.trim().isNotEmpty
                      ? _settings.pdfPageTitle2.trim().toUpperCase()
                      : 'PROPOSTA COMERCIAL')
                  : (_settings.coverHeaderText1.isNotEmpty
                      ? _settings.coverHeaderText1
                      : 'PROPOSTA COMERCIAL'),
              text2: _settings.coverHeaderText2.isNotEmpty
                  ? _settings.coverHeaderText2
                  : 'ENERGIA SOLAR FOTOVOLTAICA',
              text3: _settings.coverHeaderText3.isNotEmpty
                  ? _settings.coverHeaderText3
                  : 'ALTA PERFORMANCE',
              accentColor: primaryColor,
              scale: 0.72,
              customBgColorHex: _settings.coverHeaderBgColor,
              customTextColorHex: _settings.coverHeaderTextColor,
              customIconColorHex: _settings.coverHeaderIconColor,
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Hero Banner (Cor Secundária) + Solar Iconography (Cor Principal)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: secondaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Equipamentos e\ncomponentes inclusos',
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Conheça o conjunto fotovoltaico da sua proposta.',
                              style: GoogleFonts.inter(fontSize: 9.5, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 78,
                        height: 54,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned(
                              top: 0,
                              right: 2,
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: primaryColor.withValues(alpha: 0.25),
                                ),
                                child: Center(
                                  child: Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: primaryColor,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 2,
                              left: 4,
                              child: Container(
                                width: 56,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: primaryColor.withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(color: Colors.white70, width: 1.2),
                                ),
                                child: Icon(Icons.solar_power_rounded, color: Colors.white.withValues(alpha: 0.92), size: 20),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Itens inclusos no seu projeto:',
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                // Zebra Equipment List
                _buildPreviewEquipmentRow(
                  primaryColor: primaryColor,
                  icon: Icons.solar_power_rounded,
                  text: '14x Módulo Fotovoltaico 615W Monocristalino',
                  shaded: false,
                ),
                _buildPreviewEquipmentRow(
                  primaryColor: primaryColor,
                  icon: Icons.bolt_rounded,
                  text: '1x Inversor Solar Grid-Tie 8.0 kW Alta Eficiência',
                  shaded: true,
                ),
                _buildPreviewEquipmentRow(
                  primaryColor: primaryColor,
                  icon: Icons.roofing_rounded,
                  text: '1x Estrutura de Fixação + Homologação Completa',
                  shaded: false,
                ),
                const SizedBox(height: 10),
                // Bottom Summary Bar (Cor Secundária)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: secondaryColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'INVESTIMENTO TOTAL',
                        style: GoogleFonts.inter(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white70,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'R\$ 26.800,00',
                          style: GoogleFonts.outfit(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Bottom Ribbon (Rodapé idêntico ao editor da popup ou Slogan Minimalista)
          if (_settings.coverShowFooter)
            CoverFooterWidget(
              styleId: _settings.coverFooterStyle,
              text1: _settings.coverFooterText1,
              text2: _settings.coverFooterText2,
              text3: _settings.coverFooterText3,
              text4: _settings.coverFooterText4,
              accentColor: primaryColor,
              scale: 0.72,
              customBgColorHex: _settings.coverFooterBgColor,
              customTextColorHex: _settings.coverFooterTextColor,
              customIconColorHex: _settings.coverFooterIconColor,
            )
          else if (_settings.showPdfSloganFooter)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Stack(
                    children: [
                      Container(
                        height: 1,
                        width: double.infinity,
                        color: const Color(0xFFE2E8F0),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          height: 2,
                          width: 48,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.solar_power_outlined, size: 11, color: primaryColor),
                          const SizedBox(width: 5),
                          Text(
                            _companySloganCtrl.text.trim().isNotEmpty
                                ? _companySloganCtrl.text.trim().toUpperCase()
                                : 'ENERGIA QUE TRANSFORMA',
                            style: GoogleFonts.inter(
                              fontSize: 7.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF64748B),
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Página 2 de 6',
                        style: GoogleFonts.inter(
                          fontSize: 7.5,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
    const SizedBox(height: 12),
    Align(
      alignment: Alignment.centerRight,
      child: _buildPersonalizeProposalButton(compact: true),
    ),
  ],
);
  }

  Widget _buildPersonalizeProposalButton({bool compact = false}) {
    return ElevatedButton.icon(
      onPressed: _openCoverCustomizer,
      icon: const Icon(Icons.palette_rounded, size: 18),
      label: const Text('PERSONALIZAR + PROPOSTA'),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFEAB308),
        foregroundColor: const Color(0xFF0F172A),
        elevation: 4,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 18 : 12,
          vertical: compact ? 12 : 14,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.outfit(
          fontWeight: FontWeight.w900,
          fontSize: compact ? 12.5 : 13.5,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildPreviewEquipmentRow({
    required Color primaryColor,
    required IconData icon,
    required String text,
    required bool shaded,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: shaded ? primaryColor.withValues(alpha: 0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 11, color: primaryColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 9.5,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF1E293B),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // COMPONENTES DO ESTÚDIO DE CAPAS EM TEMPO REAL
  // ───────────────────────────────────────────────────────────────────────────

  SolarSettingsModel _buildCurrentLiveSettings() {
    return _settings.copyWith(
      proposalStyle: _proposalStyle,
      selectedVerticalSplitTemplate: _selectedVerticalSplit,
      verticalSplitDividerType: _verticalSplitDividerType,
      verticalSplitHeadline: _verticalSplitHeadlineCtrl.text,
      verticalSplitSubheadline: _verticalSplitSubheadlineCtrl.text,
      verticalSplitLeftFooter: _verticalSplitLeftFooterCtrl.text,
      verticalSplitRightTitle: _verticalSplitRightTitleCtrl.text,
      verticalSplitRightSubtitle: _verticalSplitRightSubtitleCtrl.text,
      verticalSplitRightTagline: _verticalSplitRightTaglineCtrl.text,
      verticalSplitRightFooter: _verticalSplitRightFooterCtrl.text,
      verticalSplitAccentColor: _verticalSplitAccentColor,
      verticalSplitFooterBadges: _verticalSplitFooterBadges,
      webBackgroundTemplate: (!_isCustomCoverMode && _selectedCover.isNotEmpty) ? _selectedCover : _selectedWebBg,
      companyLogoBase64: _companyLogoBase64,
      coverShowLogo: _coverShowLogo,
      coverLogoPositionX: _coverLogoPosX,
      coverLogoPositionY: _coverLogoPosY,
      coverLogoWidth: _coverLogoWidth,
      selectedSvgTheme: _selectedSvgTheme,
      secondaryThemeColor: _secondaryThemeColor,
      verticalSplitHeadlineTop: _settings.verticalSplitHeadlineTop,
      verticalSplitHeadlineLeft: _settings.verticalSplitHeadlineLeft,
      verticalSplitRightBlockTop: _settings.verticalSplitRightBlockTop,
      verticalSplitRightBlockRight: _settings.verticalSplitRightBlockRight,
      verticalSplitLeftFooterBottom: _settings.verticalSplitLeftFooterBottom,
      verticalSplitLeftFooterLeft: _settings.verticalSplitLeftFooterLeft,
      verticalSplitRightFooterBottom: _settings.verticalSplitRightFooterBottom,
      verticalSplitRightFooterRight: _settings.verticalSplitRightFooterRight,
      // ── Configurações do Estilo Modern ──
      coverTitle: _coverTitleCtrl.text,
      coverSubtitle: _coverSubtitleCtrl.text,
      coverShowBadge: _coverShowBadge,
      coverBadgeColor: _coverBadgeColor,
      coverBadgeOpacity: _coverBadgeOpacity,
      coverTitleColor: _coverTitleColor,
      coverSubtitleColor: _coverSubtitleColor,
      coverTitleFontSize: _coverTitleFontSize,
      coverSubtitleFontSize: _coverSubtitleFontSize,
      coverBadgePositionX: _coverBadgePosX,
      coverBadgePositionY: _coverBadgePosY,
      isCustomCoverMode: _isCustomCoverMode,
      customCoverImageBase64: _customCoverImageBase64,
      customDividerStyle: _customDividerStyle,
      customDividerColor: _customDividerColor,
      selectedCoverTemplate: _selectedCover,
      customTextItems: _settings.customTextItems,
      customIconItems: _settings.customIconItems,
    );
  }

  Future<void> _openCoverCustomizer() async {
    final updated = await SolarCoverCustomizerDialog.show(
      context,
      initialSettings: _buildCurrentLiveSettings(),
      onSave: (val) {
        setState(() {
          _settings = val;
          _proposalStyle = val.proposalStyle;
          _selectedVerticalSplit = val.selectedVerticalSplitTemplate;
          _verticalSplitDividerType = val.verticalSplitDividerType;
          _verticalSplitHeadlineCtrl.text = val.verticalSplitHeadline;
          _verticalSplitSubheadlineCtrl.text = val.verticalSplitSubheadline;
          _verticalSplitLeftFooterCtrl.text = val.verticalSplitLeftFooter;
          _verticalSplitRightTitleCtrl.text = val.verticalSplitRightTitle;
          _verticalSplitRightSubtitleCtrl.text = val.verticalSplitRightSubtitle;
          _verticalSplitRightTaglineCtrl.text = val.verticalSplitRightTagline;
          _verticalSplitRightFooterCtrl.text = val.verticalSplitRightFooter;
          _verticalSplitAccentColor = val.verticalSplitAccentColor;
          _selectedSvgTheme = val.selectedSvgTheme;
          _secondaryThemeColor = val.secondaryThemeColor;
          _selectedWebBg = val.webBackgroundTemplate;
          _companyLogoBase64 = val.companyLogoBase64;
          _coverShowLogo = val.coverShowLogo;
          _coverLogoPosX = val.coverLogoPositionX;
          _coverLogoPosY = val.coverLogoPositionY;
          _coverLogoWidth = val.coverLogoWidth;
          // Sincronização dos campos do Estilo Modern
          _coverTitleCtrl.text = val.coverTitle;
          _coverSubtitleCtrl.text = val.coverSubtitle;
          _coverShowBadge = val.coverShowBadge;
          _coverBadgeColor = val.coverBadgeColor;
          _coverBadgeOpacity = val.coverBadgeOpacity;
          _coverTitleColor = val.coverTitleColor;
          _coverSubtitleColor = val.coverSubtitleColor;
          _coverTitleFontSize = val.coverTitleFontSize;
          _coverSubtitleFontSize = val.coverSubtitleFontSize;
          _coverBadgePosX = val.coverBadgePositionX;
          _coverBadgePosY = val.coverBadgePositionY;
          _isCustomCoverMode = val.isCustomCoverMode;
          _customCoverImageBase64 = val.customCoverImageBase64;
          _customDividerStyle = val.customDividerStyle;
          _customDividerColor = val.customDividerColor;
          _selectedCover = val.selectedCoverTemplate;
        });
        _editorTick.value++;
      },
    );
    if (updated != null && mounted) {
      setState(() {
        _settings = updated;
        _proposalStyle = updated.proposalStyle;
        _selectedVerticalSplit = updated.selectedVerticalSplitTemplate;
        _verticalSplitDividerType = updated.verticalSplitDividerType;
        _verticalSplitHeadlineCtrl.text = updated.verticalSplitHeadline;
        _verticalSplitSubheadlineCtrl.text = updated.verticalSplitSubheadline;
        _verticalSplitLeftFooterCtrl.text = updated.verticalSplitLeftFooter;
        _verticalSplitRightTitleCtrl.text = updated.verticalSplitRightTitle;
        _verticalSplitRightSubtitleCtrl.text = updated.verticalSplitRightSubtitle;
        _verticalSplitRightTaglineCtrl.text = updated.verticalSplitRightTagline;
        _verticalSplitRightFooterCtrl.text = updated.verticalSplitRightFooter;
        _verticalSplitAccentColor = updated.verticalSplitAccentColor;
        _selectedSvgTheme = updated.selectedSvgTheme;
        _secondaryThemeColor = updated.secondaryThemeColor;
        _selectedWebBg = updated.webBackgroundTemplate;
        _companyLogoBase64 = updated.companyLogoBase64;
        _coverShowLogo = updated.coverShowLogo;
        _coverLogoPosX = updated.coverLogoPositionX;
        _coverLogoPosY = updated.coverLogoPositionY;
        _coverLogoWidth = updated.coverLogoWidth;
        // Sincronização dos campos do Estilo Modern
        _coverTitleCtrl.text = updated.coverTitle;
        _coverSubtitleCtrl.text = updated.coverSubtitle;
        _coverShowBadge = updated.coverShowBadge;
        _coverBadgeColor = updated.coverBadgeColor;
        _coverBadgeOpacity = updated.coverBadgeOpacity;
        _coverTitleColor = updated.coverTitleColor;
        _coverSubtitleColor = updated.coverSubtitleColor;
        _coverTitleFontSize = updated.coverTitleFontSize;
        _coverSubtitleFontSize = updated.coverSubtitleFontSize;
        _coverBadgePosX = updated.coverBadgePositionX;
        _coverBadgePosY = updated.coverBadgePositionY;
        _isCustomCoverMode = updated.isCustomCoverMode;
        _customCoverImageBase64 = updated.customCoverImageBase64;
        _customDividerStyle = updated.customDividerStyle;
        _customDividerColor = updated.customDividerColor;
        _selectedCover = updated.selectedCoverTemplate;
      });
      _editorTick.value++;
    }
  }

  /// Card A4 Interativo com Drag & Drop do Retângulo e Textos em Tempo Real
  Widget _buildLiveCoverPreviewCard() {
    const previewW = 340.0;
    const previewH = 480.0; // Proporção A4 (1:1.414)
    final scale = previewW / 595.28;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── BOTÕES DESTACADOS: SALVAR ALTERAÇÕES & PERSONALIZAR CAPA ────────
        SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveSettings,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.2),
                  )
                : const Icon(Icons.save_rounded, size: 20),
            label: Text(_isSaving ? 'SALVANDO ALTERAÇÕES...' : 'SALVAR ALTERAÇÕES'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              elevation: 5,
              shadowColor: const Color(0xFF10B981).withValues(alpha: 0.45),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              textStyle: GoogleFonts.outfit(
                fontWeight: FontWeight.w900,
                fontSize: 14,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _buildPersonalizeProposalButton(),
        const SizedBox(height: 12),

        // Header com Badge de Modo Interativo
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
          ),
          child: Row(
            children: [
              Icon(
                _proposalStyle == 'verticalSplit' ? Icons.view_sidebar_rounded : Icons.picture_as_pdf_rounded,
                color: const Color(0xFF38BDF8),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _proposalStyle == 'verticalSplit'
                      ? 'Prévia da Capa A4 (Vertical Split)'
                      : 'Prévia da Capa A4',
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF10B981)),
                ),
                child: const Text('AO VIVO', style: TextStyle(color: Color(0xFF10B981), fontSize: 9.5, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),

        // Moldura A4 com Live Canvas
        Container(
          width: previewW,
          height: previewH,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
            border: Border.all(color: const Color(0xFF0F172A), width: 2),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, 8)),
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(14), bottomRight: Radius.circular(14)),
            child: _proposalStyle == 'corporateWave'
                ? CorporateWaveCoverView(
                    width: previewW,
                    height: previewH,
                    title: _settings.coverTitle.isNotEmpty
                        ? _settings.coverTitle
                        : 'PROPOSTA\nCOMERCIAL',
                    subtitle: _settings.coverSubtitle.isNotEmpty
                        ? _settings.coverSubtitle
                        : 'ENERGIA SOLAR FOTOVOLTAICA',
                    clientName: 'João da Silva Santos',
                    locationAndDate: 'Brasil • 2026',
                    companyName: _companyNameCtrl.text.isNotEmpty
                        ? _companyNameCtrl.text
                        : 'SUA EMPRESA SOLAR',
                    companyPhone: _companyPhoneCtrl.text.isNotEmpty
                        ? _companyPhoneCtrl.text
                        : '(11) 98765-4321',
                    companyEmail: 'contato@empresa.com.br',
                    companyWebsite: _companyWebsiteCtrl.text.isNotEmpty
                        ? _companyWebsiteCtrl.text
                        : 'www.empresa.com.br',
                    companyLogoBase64: _companyLogoBase64,
                    photoUrl: (_selectedCover.startsWith('modelo_') ||
                            _selectedCover.contains('energiasolar'))
                        ? SolarSettingsService.getBigCoverUrl(_selectedCover)
                        : SolarSettingsService.getWebBackgroundUrl(_selectedCover),
                    customPhotoBase64: _customCoverImageBase64,
                    primaryColor: Color(
                      _hexToInt(_settings.verticalSplitAccentColor,
                          fallback: 0xFF0284C7),
                    ),
                    showLogo: _settings.coverShowLogo,
                    logoWidth: _settings.coverLogoWidth,
                    logoPositionX: _settings.coverLogoPositionX,
                    logoPositionY: _settings.coverLogoPositionY,
                    titleColor: Color(_settings.coverTitleColorValue),
                    titleFontSize: _settings.coverTitleFontSize,
                    subtitleColor: Color(_settings.coverSubtitleColorValue),
                    subtitleFontSize: _settings.coverSubtitleFontSize,
                    showHeadline: _settings.verticalSplitShowHeadline,
                    headline: _settings.verticalSplitHeadline,
                    subheadline: _settings.verticalSplitSubheadline,
                    headlineColor: Color(_settings.coverHeadlineColorValue),
                    headlineLeft: _settings.verticalSplitHeadlineLeft,
                    headlineTop: _settings.verticalSplitHeadlineTop,
                    showBadges: _settings.verticalSplitShowLeftFooter,
                    badges: _settings.verticalSplitFooterBadges
                        .map((b) => b.label)
                        .toList(),
                    badgesLeft: _settings.verticalSplitLeftFooterLeft,
                    badgesBottom: _settings.verticalSplitLeftFooterBottom,
                  )
                : (_proposalStyle == 'verticalSplit'
                    ? SolarVerticalSplitCoverView(
                        width: previewW,
                        height: previewH,
                        settings: _buildCurrentLiveSettings(),
                        clientName: 'João da Silva Santos',
                        proposalNumber: 'PROP-2026/001',
                        kwp: '8.61',
                      )
                    : Stack(
                    fit: StackFit.expand,
                    children: [
                      // 1. Imagem de Fundo da Capa
                      if (_isCustomCoverMode) ...[
                  if (_customCoverImageBase64 != null && _customCoverImageBase64!.isNotEmpty)
                    Image.memory(
                      base64Decode(_customCoverImageBase64!),
                      fit: BoxFit.cover,
                      width: previewW,
                      height: previewH,
                    )
                  else
                    Image.network(
                      SolarSettingsService.getWebBackgroundUrl(
                        (_selectedWebBg.isNotEmpty &&
                                !_selectedWebBg.startsWith('modelo_') &&
                                !_selectedWebBg.contains('energiasolar'))
                            ? _selectedWebBg
                            : SolarSettingsModel.availableWebBackgrounds.first,
                      ),
                      fit: BoxFit.cover,
                      width: previewW,
                      height: previewH,
                      errorBuilder: (_, __, ___) => Container(color: const Color(0xFF0F172A)),
                    ),

                  // Separador Vetorial Desenhado sobre a Foto
                  CustomPaint(
                    size: const Size(previewW, previewH),
                    painter: SolarCoverDividerPainter(
                      dividerType: _customDividerStyle,
                      primaryColor: Color(_hexToInt(_customDividerColor)),
                      splitYRatio: 0.70,
                    ),
                  ),
                ] else ...[
                  Image.network(
                    SolarSettingsService.getBigCoverUrl(_selectedCover),
                    fit: BoxFit.cover,
                    width: previewW,
                    height: previewH,
                    loadingBuilder: (ctx, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        color: const Color(0xFF0F172A),
                        child: const Center(
                          child: CircularProgressIndicator(color: Color(0xFF38BDF8), strokeWidth: 2),
                        ),
                      );
                    },
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFF0F172A),
                      child: const Center(
                        child: Icon(Icons.broken_image_rounded, color: Colors.white38, size: 36),
                      ),
                    ),
                  ),
                ],

                // 2. Frase de Impacto da Foto (Headline & Subheadline)
                if (_settings.verticalSplitShowHeadline)
                  Positioned(
                    left: (previewW * _settings.verticalSplitHeadlineLeft).clamp(8.0, previewW * 0.85),
                    top: (previewH * _settings.verticalSplitHeadlineTop).clamp(8.0, previewH * 0.85),
                    child: SizedBox(
                      width: previewW * 0.88,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _verticalSplitHeadlineCtrl.text.isNotEmpty
                                ? _verticalSplitHeadlineCtrl.text
                                : 'ENERGIA QUE MOVE O SEU AMANHÃ',
                            style: GoogleFonts.montserrat(
                              fontSize: (_settings.verticalSplitHeadlineFontSize * (previewW / 595.28)).clamp(8.0, 26.0),
                              fontWeight: FontWeight.w900,
                              color: Color(_settings.coverHeadlineColorValue),
                              letterSpacing: 0.2,
                              height: 1.15,
                            ),
                          ),
                          if (_settings.verticalSplitShowHeadlineDivider) ...[
                            const SizedBox(height: 4),
                            Container(
                              width: (_settings.verticalSplitHeadlineDividerWidth * (previewW / 595.28)).clamp(14.0, 60.0),
                              height: (_settings.verticalSplitHeadlineDividerHeight * (previewW / 595.28)).clamp(1.5, 5.0),
                              decoration: BoxDecoration(
                                color: _settings.verticalSplitHeadlineDividerColor.isNotEmpty
                                    ? Color(_hexToInt(_settings.verticalSplitHeadlineDividerColor))
                                    : Color(_hexToInt(_verticalSplitAccentColor)),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(height: 5),
                          ] else
                            const SizedBox(height: 5),
                          Text(
                            _verticalSplitSubheadlineCtrl.text.isNotEmpty
                                ? _verticalSplitSubheadlineCtrl.text
                                : 'MAIS ECONOMIA.\nMAIS LIBERDADE.\nUM FUTURO SUSTENTÁVEL.',
                            style: GoogleFonts.montserrat(
                              fontSize: (10.5 * (previewW / 595.28)).clamp(5.5, 13.0),
                              fontWeight: FontWeight.w700,
                              color: Color(_settings.coverHeadlineColorValue).withValues(alpha: 0.95),
                              letterSpacing: 0.3,
                              height: 1.22,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // 3. Badges Informativos na Foto (Pilares dinâmicos iguais ao Estúdio Visual & PDF)
                if (_settings.verticalSplitShowLeftFooter && _settings.verticalSplitFooterBadges.isNotEmpty)
                  Positioned(
                    left: (previewW * _settings.verticalSplitLeftFooterLeft).clamp(8.0, previewW * 0.85),
                    top: (previewH - (_settings.verticalSplitLeftFooterBottom * previewH) - 12).clamp(8.0, previewH - 20),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        for (int i = 0; i < _settings.verticalSplitFooterBadges.length; i++) ...[
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Icon(
                                _settings.verticalSplitFooterBadges[i].iconKey == 'bolt'
                                    ? Icons.bolt_rounded
                                    : (_settings.verticalSplitFooterBadges[i].iconKey == 'chart'
                                        ? Icons.bar_chart_rounded
                                        : Icons.eco_outlined),
                                size: (11 * (previewW / 595.28)).clamp(6.5, 14.0),
                                color: Color(_settings.coverBadgesIconColorValue),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                _settings.verticalSplitFooterBadges[i].label,
                                style: GoogleFonts.montserrat(
                                  fontSize: (8.5 * (previewW / 595.28)).clamp(5.0, 10.0),
                                  fontWeight: FontWeight.w700,
                                  color: Color(_settings.coverBadgesTextColorValue),
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                          if (i < _settings.verticalSplitFooterBadges.length - 1)
                            Container(
                              width: 1,
                              height: 8,
                              color: Color(_settings.coverBadgesTextColorValue).withValues(alpha: 0.35),
                              margin: const EdgeInsets.symmetric(horizontal: 5),
                            ),
                        ],
                      ],
                    ),
                  ),

                // 4. Bloco Institucional na Área Branca Preservada (Direita)
                if (_settings.verticalSplitShowRightBlock)
                  Positioned(
                    right: (_settings.verticalSplitRightBlockRight * previewW).clamp(10.0, previewW * 0.45),
                    top: (_settings.verticalSplitRightBlockTop * previewH).clamp(10.0, previewH - 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _verticalSplitRightTitleCtrl.text.isNotEmpty
                              ? _verticalSplitRightTitleCtrl.text
                              : 'PROPOSTA',
                          style: GoogleFonts.montserrat(
                            fontSize: (_settings.verticalSplitRightTitleFontSize * (previewW / 595.28)).clamp(6.5, 18.0),
                            fontWeight: FontWeight.w700,
                            color: Color(_settings.coverRightTitleColorValue),
                            letterSpacing: 2.5,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          _verticalSplitRightSubtitleCtrl.text.isNotEmpty
                              ? _verticalSplitRightSubtitleCtrl.text
                              : 'SOLAR',
                          style: GoogleFonts.montserrat(
                            fontSize: (_settings.verticalSplitRightSubtitleFontSize * (previewW / 595.28)).clamp(13.0, 32.0),
                            fontWeight: FontWeight.w900,
                            color: Color(_settings.coverRightSubtitleColorValue),
                            letterSpacing: 1.0,
                            height: 1.0,
                          ),
                        ),
                        if (_settings.verticalSplitShowRightDivider) ...[
                          const SizedBox(height: 4),
                          Container(
                            width: (_settings.verticalSplitRightDividerWidth * 0.8 * (previewW / 595.28)).clamp(16.0, 54.0),
                            height: (_settings.verticalSplitRightDividerHeight * 0.8 * (previewW / 595.28)).clamp(1.5, 4.0),
                            decoration: BoxDecoration(
                              color: _settings.verticalSplitRightDividerColor.isNotEmpty
                                  ? Color(_hexToInt(_settings.verticalSplitRightDividerColor))
                                  : Color(_hexToInt(_verticalSplitAccentColor)),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 4),
                        ] else
                          const SizedBox(height: 4),
                        Text(
                          _verticalSplitRightTaglineCtrl.text.isNotEmpty
                              ? _verticalSplitRightTaglineCtrl.text
                              : 'SOLUÇÕES EM ENERGIA\nPARA UM FUTURO MELHOR',
                          style: GoogleFonts.montserrat(
                            fontSize: (9.5 * (previewW / 595.28)).clamp(5.0, 11.0),
                            fontWeight: FontWeight.w700,
                            color: Color(_settings.coverRightTaglineColorValue),
                            letterSpacing: 0.4,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),

                // 5. Logomarca Estática (Exibição Limpa ao Vivo)
                if (_coverShowLogo && _companyLogoBase64 != null && _companyLogoBase64!.isNotEmpty)
                  Positioned(
                    left: (previewW * _coverLogoPosX).clamp(0.0, previewW - (_coverLogoWidth * scale)),
                    top: (previewH * _coverLogoPosY).clamp(0.0, previewH * 0.85),
                    child: Container(
                      width: (_coverLogoWidth * scale).clamp(30.0, previewW * 0.6),
                      padding: const EdgeInsets.all(2),
                      child: Image.memory(
                        base64Decode(_companyLogoBase64!),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),

                // 6. Rodapé Informativo na Área Branca Preservada
                if (_settings.verticalSplitShowRightFooter)
                  Positioned(
                    left: previewW - (((_settings.verticalSplitRightFooterRight <= 0.12) ? 0.50 : _settings.verticalSplitRightFooterRight) * previewW) - (previewW * 0.45),
                    bottom: (previewH * _settings.verticalSplitRightFooterBottom).clamp(8.0, previewH * 0.20),
                    child: SizedBox(
                      width: previewW * 0.45,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _verticalSplitRightFooterCtrl.text.isNotEmpty
                                ? _verticalSplitRightFooterCtrl.text
                                : 'ENERGIA HOJE. MAIS POSSIBILIDADES AMANHÃ.',
                            style: GoogleFonts.montserrat(
                              fontSize: 6.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'PROP-2026/001 • Emissão: 06/09/2026',
                            style: GoogleFonts.inter(fontSize: 6.0, color: const Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ),
                  ),

                // 7. Informações do Cliente & Usina (Esquerda por default, seguindo o Estúdio Visual)
                if (_settings.coverShowClientInfo)
                  Positioned(
                    left: (previewW * _settings.coverClientInfoPositionX).clamp(8.0, previewW - 40.0),
                    top: (previewH * _settings.coverClientInfoPositionY).clamp(8.0, previewH - 28.0),
                    child: SizedBox(
                      width: (_settings.coverClientInfoWidth * (previewW / 595.28)).clamp(90.0, previewW),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Cliente: João da Silva Santos',
                            style: GoogleFonts.montserrat(
                              fontSize: (_settings.coverClientInfoFontSize * (previewW / 595.28)).clamp(5.5, 11.0),
                              fontWeight: FontWeight.bold,
                              color: Color(_settings.coverClientInfoColorValue),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 1.5),
                          Text(
                            'CPF/CNPJ: 123.456.789-00',
                            style: GoogleFonts.montserrat(
                              fontSize: (_settings.coverClientInfoFontSize * 0.9 * (previewW / 595.28)).clamp(5.0, 10.0),
                              fontWeight: FontWeight.bold,
                              color: Color(_settings.coverClientInfoSecondaryColorValue),
                            ),
                            maxLines: 1,
                          ),
                          const SizedBox(height: 1.5),
                          Text(
                            'Geração: 990 kWh/mês (8.61 kWp)',
                            style: GoogleFonts.montserrat(
                              fontSize: (_settings.coverClientInfoFontSize * 0.9 * (previewW / 595.28)).clamp(5.0, 10.0),
                              fontWeight: FontWeight.bold,
                              color: Color(_settings.coverClientInfoSecondaryColorValue),
                            ),
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            )),
          ),
        ),

        const SizedBox(height: 10),

        // Barra informativa elegante indicando personalização visual
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF0284C7)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Arraste a logo, edite os textos e configure o separador no botão amarelo acima.',
                  style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF475569)),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // ── BOTÃO "ENVIAR LOGO" & CONTROLES DE REDIMENSIONAMENTO/POSIÇÃO ──
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _pickLogoFile,
                      icon: Icon(_companyLogoBase64 != null ? Icons.sync_rounded : Icons.cloud_upload_rounded, size: 16),
                      label: Text(
                        _companyLogoBase64 != null ? 'TROCAR LOGOMARCA' : 'ENVIAR LOGO',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11.5),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  if (_companyLogoBase64 != null) ...[
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
                      tooltip: 'Remover Logo da Capa',
                      onPressed: () => setState(() => _companyLogoBase64 = null),
                    ),
                  ],
                ],
              ),

              if (_companyLogoBase64 != null) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.photo_size_select_large_rounded, size: 14, color: Color(0xFF0284C7)),
                        const SizedBox(width: 6),
                        Text(
                          'Tamanho da Logo: ${_coverLogoWidth.toInt()}px',
                          style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFF334155)),
                        ),
                      ],
                    ),
                    Switch.adaptive(
                      value: _coverShowLogo,
                      activeTrackColor: const Color(0xFF0284C7),
                      onChanged: (v) => setState(() => _coverShowLogo = v),
                    ),
                  ],
                ),
                Slider(
                  value: _coverLogoWidth,
                  min: 40,
                  max: 180,
                  divisions: 28,
                  activeColor: const Color(0xFF0284C7),
                  onChanged: (v) => setState(() => _coverLogoWidth = v),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: () => setState(() {
                        _coverLogoPosX = 0.65;
                        _coverLogoPosY = 0.05;
                      }),
                      icon: const Icon(Icons.align_horizontal_right_rounded, size: 13),
                      label: const Text('Topo Direito', style: TextStyle(fontSize: 10.5)),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF0284C7),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => setState(() {
                        _coverLogoPosX = 0.35;
                        _coverLogoPosY = 0.05;
                      }),
                      icon: const Icon(Icons.align_horizontal_center_rounded, size: 13),
                      label: const Text('Topo Centro', style: TextStyle(fontSize: 10.5)),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => setState(() {
                        _coverLogoPosX = 0.08;
                        _coverLogoPosY = 0.85;
                      }),
                      icon: const Icon(Icons.vertical_align_bottom_rounded, size: 13),
                      label: const Text('Rodapé', style: TextStyle(fontSize: 10.5)),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Painel de Controles: Seletor de Modos, 100 Capas, Criador e Editor de Texto
  Widget _buildCoverStudioControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── BARRA SELETORA DE ABAS (100 MODELOS vs CRIAR DO ZERO) ────────────
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _coverSubTab = 0;
                      _isCustomCoverMode = false;
                    });
                    _editorTick.value++;
                  },
                  borderRadius: BorderRadius.circular(9),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _coverSubTab == 0 ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                      boxShadow: _coverSubTab == 0
                          ? [const BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.photo_library_rounded, size: 18, color: _coverSubTab == 0 ? AppColors.primary : const Color(0xFF64748B)),
                        const SizedBox(width: 8),
                        Text(
                          '100 Capas Fotovoltaicas',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _coverSubTab == 0 ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _coverSubTab = 1;
                      _isCustomCoverMode = true;
                    });
                    _editorTick.value++;
                  },
                  borderRadius: BorderRadius.circular(9),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _coverSubTab == 1 ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                      boxShadow: _coverSubTab == 1
                          ? [const BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.palette_rounded, size: 18, color: _coverSubTab == 1 ? const Color(0xFF059669) : const Color(0xFF64748B)),
                        const SizedBox(width: 8),
                        Text(
                          'Criar Capa (Sua Foto + Decalque)',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _coverSubTab == 1 ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // Conteúdo da Aba 0 (100 Capas) ou Aba 1 (Criar do Zero)
        if (_coverSubTab == 0)
          _build100CoversPicker()
        else
          _buildCustomCoverCreator(),

        const SizedBox(height: 22),
        const Divider(color: Color(0xFFE2E8F0)),
        const SizedBox(height: 14),

        // ── EDITOR DO RETÂNGULO DE FUNDO, TÍTULO E SUBTÍTULO ─────────────────
        _buildTypographyAndBadgeEditor(),
      ],
    );
  }

  /// Grade dos Modelos de Capa com Dropdown de Estilo, Paginação de 50 em 50 e Busca
  Widget _build100CoversPicker() {
    const pageSize = 50;

    // Se for Estilo Corporate Wave (40 Novos Modelos)
    if (_proposalStyle == 'corporateWave') {
      final allWave = SolarSettingsService.getDefaultCorporateWaveList();
      final filteredWave = _coverSearchQuery.trim().isEmpty
          ? allWave
          : allWave.where((m) =>
              (m['title'] as String).toLowerCase().contains(_coverSearchQuery.toLowerCase().trim()) ||
              (m['headline'] as String).toLowerCase().contains(_coverSearchQuery.toLowerCase().trim())).toList();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProposalStyleDropdown(),
          const SizedBox(height: 14),

          _buildSearchAndPaginationBar(1, 1, 'Buscar modelo corporate wave...'),
          const SizedBox(height: 14),

          _buildHorizontalCarousel(
            controller: _coverCarouselCtrl,
            height: 255,
            itemWidth: 180,
            itemCount: filteredWave.length,
            itemBuilder: (context, idx) {
              final model = filteredWave[idx];
              final imgName = model['imageName'] as String;
              final isSelected = !_isCustomCoverMode &&
                  _proposalStyle == 'corporateWave' &&
                  _selectedCover == imgName;

              return InkWell(
                onTap: () {
                  setState(() {
                    final modelColor =
                        (model['primaryColor'] as String?) ?? '#0284C7';
                    _proposalStyle = 'corporateWave';
                    _selectedCover = imgName;
                    _isCustomCoverMode = false;
                    _customDividerStyle = -1;
                    _customCoverImageBase64 = null;
                    _verticalSplitAccentColor = modelColor;
                    _selectedSvgTheme = modelColor;
                    _secondaryThemeColor = modelColor;
                    _settings = _settings.copyWith(
                      selectedCoverTemplate: imgName,
                      webBackgroundTemplate: imgName,
                      clearCustomCoverImage: true,
                      isCustomCoverMode: false,
                      customDividerStyle: -1,
                      proposalStyle: 'corporateWave',
                      verticalSplitAccentColor: modelColor,
                      selectedSvgTheme: modelColor,
                      secondaryThemeColor: modelColor,
                    );
                  });
                  _editorTick.value++;
                },
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFCBD5E1),
                      width: isSelected ? 3 : 1,
                    ),
                    boxShadow: isSelected
                        ? [BoxShadow(color: const Color(0xFF0284C7).withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 3))]
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(isSelected ? 7 : 9),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CorporateWaveCoverView(
                          width: 200,
                          height: 280,
                          title: 'PROPOSTA\nCOMERCIAL',
                          subtitle: 'ENERGIA SOLAR',
                          locationAndDate: '2026',
                          photoUrl: SolarSettingsService.getSmallCoverUrl(imgName),
                          primaryColor: Color(_hexToInt(model['primaryColor'] as String)),
                        ),
                        if (isSelected)
                          Positioned(
                            top: 5,
                            right: 5,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0284C7),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.check_circle_rounded, size: 11, color: Colors.white),
                                  SizedBox(width: 3),
                                  Text('ATIVO', style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      );
    }

    // Se for Estilo Vertical Split (100 Novos Modelos)
    if (_proposalStyle == 'verticalSplit') {
      final allVertical = SolarSettingsService.getDefaultVerticalSplitList();
      final filteredVertical = _coverSearchQuery.trim().isEmpty
          ? allVertical
          : allVertical.where((m) =>
              m.name.toLowerCase().contains(_coverSearchQuery.toLowerCase().trim()) ||
              m.headline.toLowerCase().contains(_coverSearchQuery.toLowerCase().trim())).toList();

      final totalPages = (filteredVertical.length / pageSize).ceil().clamp(1, 99);
      final currentPage = _coverPage.clamp(1, totalPages);
      final startIndex = (currentPage - 1) * pageSize;
      final endIndex = (startIndex + pageSize).clamp(0, filteredVertical.length);
      final pagedVertical = filteredVertical.sublist(startIndex, endIndex);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProposalStyleDropdown(),
          const SizedBox(height: 14),

          // Barra de Busca e Paginação (50 em 50)
          _buildSearchAndPaginationBar(currentPage, totalPages, 'Buscar modelo vertical...'),
          const SizedBox(height: 14),

          // Carrossel horizontal de modelos verticais
          _buildHorizontalCarousel(
            controller: _coverCarouselCtrl,
            height: 255,
            itemWidth: 180,
            itemCount: pagedVertical.length,
            itemBuilder: (context, idx) {
              final model = pagedVertical[idx];
              final isSelected = !_isCustomCoverMode &&
                  _proposalStyle == 'verticalSplit' &&
                  _selectedVerticalSplit == model.id;

              return InkWell(
                onTap: () {
                  setState(() {
                    _proposalStyle = 'verticalSplit';
                    _selectedVerticalSplit = model.id;
                    _verticalSplitDividerType = model.dividerType;
                    _selectedWebBg = model.imageName;
                    _selectedCover = model.imageName;
                    _verticalSplitHeadlineCtrl.text = model.headline;
                    _verticalSplitSubheadlineCtrl.text = model.subheadline;
                    _verticalSplitRightTaglineCtrl.text = model.rightTagline;
                    _verticalSplitRightFooterCtrl.text = model.rightFooter;
                    _verticalSplitAccentColor = model.accentColor;
                    _selectedSvgTheme = model.accentColor;
                    _secondaryThemeColor = model.accentColor;
                    _isCustomCoverMode = false;
                    _customDividerStyle = -1;
                    _customCoverImageBase64 = null;
                    _settings = _settings.copyWith(
                      proposalStyle: 'verticalSplit',
                      selectedVerticalSplitTemplate: model.id,
                      verticalSplitDividerType: model.dividerType,
                      selectedCoverTemplate: model.imageName,
                      webBackgroundTemplate: model.imageName,
                      clearCustomCoverImage: true,
                      isCustomCoverMode: false,
                      customDividerStyle: -1,
                      verticalSplitAccentColor: model.accentColor,
                      selectedSvgTheme: model.accentColor,
                      secondaryThemeColor: model.accentColor,
                    );
                  });
                  _editorTick.value++;
                },
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? const Color(0xFFEAB308) : const Color(0xFFCBD5E1),
                      width: isSelected ? 3 : 1,
                    ),
                    boxShadow: isSelected
                        ? [BoxShadow(color: const Color(0xFFEAB308).withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 3))]
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(isSelected ? 7 : 9),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Mini preview completo do modelo com foto limpa, divisor vetorial e textos em Montserrat
                        LayoutBuilder(
                          builder: (ctx, box) {
                            return SolarVerticalSplitCoverView(
                              settings: _settings.copyWith(
                                proposalStyle: 'verticalSplit',
                                verticalSplitDividerType: model.dividerType,
                                webBackgroundTemplate: model.imageName,
                                verticalSplitHeadline: model.headline,
                                verticalSplitSubheadline: model.subheadline,
                                verticalSplitRightTitle: 'PROPOSTA',
                                verticalSplitRightSubtitle: 'SOLAR',
                                verticalSplitRightTagline: model.rightTagline,
                                verticalSplitRightFooter: model.rightFooter,
                                verticalSplitAccentColor: model.accentColor,
                                verticalSplitFooterBadges: CoverFooterBadge.defaultBadges(),
                              ),
                              customWebBgUrl: SolarSettingsService.getWebBackgroundUrl(model.imageName),
                              width: box.maxWidth,
                              height: box.maxHeight,
                            );
                          },
                        ),

                        // Tag do Modelo
                        Positioned(
                          top: 6,
                          left: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              '#${model.id.replaceAll(RegExp(r'\D'), '')}',
                              style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),

                        // Chip do Tipo de Divisor
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: model.dividerType == 1
                                  ? const Color(0xFFEAB308)
                                  : model.dividerType == 2
                                      ? const Color(0xFFF97316)
                                      : const Color(0xFF0284C7),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              model.dividerType == 1
                                  ? '⚡ RAIO'
                                  : model.dividerType == 2
                                      ? '☀️ SOL'
                                      : '📐 DIAGONAL',
                              style: const TextStyle(color: Colors.white, fontSize: 7.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),

                        // Nome & Headline no Rodapé do Card
                        Positioned(
                          left: 6,
                          right: 6,
                          bottom: 6,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              model.name,
                              style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),

                        // Badge Ativo
                        if (isSelected)
                          Positioned(
                            top: 28,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEAB308),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.check_circle_rounded, size: 10, color: Colors.white),
                                  SizedBox(width: 3),
                                  Text('ATIVO', style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      );
    }

    // ── Se for Estilo Modern (100 Capas Clássicas do Banco) ────────────────
    final allCovers = _availableCovers.isNotEmpty ? _availableCovers : SolarSettingsService.getDefaultCoverList();
    final filtered = _coverSearchQuery.trim().isEmpty
        ? allCovers
        : allCovers.where((c) => c.toLowerCase().contains(_coverSearchQuery.toLowerCase().trim())).toList();

    final totalPages = (filtered.length / pageSize).ceil().clamp(1, 99);
    final currentPage = _coverPage.clamp(1, totalPages);
    final startIndex = (currentPage - 1) * pageSize;
    final endIndex = (startIndex + pageSize).clamp(0, filtered.length);
    final pagedCovers = filtered.sublist(startIndex, endIndex);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildProposalStyleDropdown(),
        const SizedBox(height: 14),

        // Barra de Busca e Paginação (50 em 50)
        _buildSearchAndPaginationBar(currentPage, totalPages, 'Buscar modelo modern (ex: 1, 15, 88)...'),
        const SizedBox(height: 14),

        if (_loadingCovers && _availableCovers.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          )
        else
          // Carrossel horizontal de capas Modern
          _buildHorizontalCarousel(
            controller: _coverCarouselCtrl,
            height: 255,
            itemWidth: 180,
            itemCount: pagedCovers.length,
            itemBuilder: (context, idx) {
              final coverName = pagedCovers[idx];
              final isSelected = !_isCustomCoverMode && _proposalStyle == 'modern' && _selectedCover == coverName;
              final numStr = coverName.replaceAll(RegExp(r'\D'), '');

              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedCover = coverName;
                    _proposalStyle = 'modern';
                    _isCustomCoverMode = false;
                    _customDividerStyle = -1;
                    _customCoverImageBase64 = null;
                    _selectedSvgTheme = '#2563EB';
                    _secondaryThemeColor = '#102C49';
                    _settings = _settings.copyWith(
                      selectedCoverTemplate: coverName,
                      webBackgroundTemplate: coverName,
                      clearCustomCoverImage: true,
                      isCustomCoverMode: false,
                      customDividerStyle: -1,
                      proposalStyle: 'modern',
                      selectedSvgTheme: '#2563EB',
                      secondaryThemeColor: '#102C49',
                    );
                  });
                  _editorTick.value++;
                },
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFCBD5E1),
                      width: isSelected ? 3 : 1,
                    ),
                    boxShadow: isSelected
                        ? [BoxShadow(color: const Color(0xFF0284C7).withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 3))]
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(isSelected ? 7 : 9),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          SolarSettingsService.getSmallCoverUrl(coverName),
                          fit: BoxFit.cover,
                          loadingBuilder: (ctx, child, progress) {
                            if (progress == null) return child;
                            return Container(
                              color: const Color(0xFF0F172A),
                              child: const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Color(0xFF38BDF8), strokeWidth: 2),
                                ),
                              ),
                            );
                          },
                          errorBuilder: (_, __, ___) => Container(
                            color: const Color(0xFF0F172A),
                            child: Center(
                              child: Text(
                                '#$numStr',
                                style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),

                        // Tag com o Número do Modelo
                        Positioned(
                          top: 5,
                          left: 5,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              '#$numStr',
                              style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),

                        // Badge Ativo
                        if (isSelected)
                          Positioned(
                            top: 5,
                            right: 5,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0284C7),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.check_circle_rounded, size: 11, color: Colors.white),
                                  SizedBox(width: 3),
                                  Text('ATIVO', style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  /// Dropdown Seletor de Estilo das Propostas (Estilo Modern vs Estilo Vertical Split)
  Widget _buildProposalStyleDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _proposalStyle == 'verticalSplit'
                  ? const Color(0xFFEAB308).withValues(alpha: 0.15)
                  : const Color(0xFF0284C7).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _proposalStyle == 'verticalSplit' ? Icons.view_sidebar_rounded : Icons.style_rounded,
              color: _proposalStyle == 'verticalSplit' ? const Color(0xFFD97706) : const Color(0xFF0284C7),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ESTILO DAS PROPOSTAS',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF64748B),
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 2),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _proposalStyle,
                    isDense: true,
                    icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF334155)),
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'modern',
                        child: Text('Estilo Modern (100 Capas Clássicas do Banco)'),
                      ),
                      DropdownMenuItem(
                        value: 'verticalSplit',
                        child: Text('Estilo Vertical Split (100 Novos Modelos com Divisores)'),
                      ),
                      DropdownMenuItem(
                        value: 'corporateWave',
                        child: Text('Estilo Corporate Wave (40 Modelos com Ondas & Janela Fluida)'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _proposalStyle = val;
                          _coverPage = 1;
                          _isCustomCoverMode = false;
                        });
                        _editorTick.value++;
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _proposalStyle == 'corporateWave'
                  ? const Color(0xFFE0F2FE)
                  : (_proposalStyle == 'verticalSplit' ? const Color(0xFFFEF08A) : const Color(0xFFE0F2FE)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _proposalStyle == 'corporateWave'
                  ? '40 Modelos Ondas'
                  : (_proposalStyle == 'verticalSplit' ? '100 Modelos Verticais' : '100 Capas Modern'),
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: _proposalStyle == 'corporateWave'
                    ? const Color(0xFF0369A1)
                    : (_proposalStyle == 'verticalSplit' ? const Color(0xFF854D0E) : const Color(0xFF0369A1)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Barra de busca e paginação de 50 em 50
  Widget _buildSearchAndPaginationBar(int currentPage, int totalPages, String hint) {
    return Row(
      children: [
        // Campo de Busca Rápida
        Expanded(
          child: SizedBox(
            height: 38,
            child: TextField(
              onChanged: (v) {
                setState(() {
                  _coverSearchQuery = v;
                  _coverPage = 1;
                });
                _editorTick.value++;
              },
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Paginação (Pág. X de Y - 50 em 50)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: currentPage > 1
                    ? () {
                        setState(() => _coverPage = currentPage - 1);
                        _editorTick.value++;
                      }
                    : null,
              ),
              const SizedBox(width: 6),
              Text(
                'Pág. $currentPage de $totalPages (50/pág)',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF334155)),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: currentPage < totalPages
                    ? () {
                        setState(() => _coverPage = currentPage + 1);
                        _editorTick.value++;
                      }
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Criador de Capa Personalizada: Upload de Imagem + Seletor de 10 Decalques
  Widget _buildCustomCoverCreator() {
    final dividers = SolarSettingsService.getAvailableDividers();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Botão de Upload da Própria Foto
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF86EFAC)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.cloud_upload_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Foto Personalizada da sua Empresa',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFF065F46)),
                    ),
                    Text(
                      _customCoverImageBase64 != null
                          ? '✅ Foto customizada carregada e ativa'
                          : 'Envie uma foto em alta resolução do seu escritório ou usina instalada',
                      style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF047857)),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _pickCustomCoverFile,
                icon: const Icon(Icons.folder_open_rounded, size: 16),
                label: Text(_customCoverImageBase64 != null ? 'TROCAR FOTO' : 'ESCOLHER FOTO'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Seletor dos 10 Modelos de Separador (Decalque)
        _label('Estilo do Separador / Decalque da Foto (10 Opções Matemáticas):'),
        const SizedBox(height: 8),

        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.3,
          ),
          itemCount: dividers.length,
          itemBuilder: (context, idx) {
            final div = dividers[idx];
            final divId = div['id'] as int;
            final isSelected = _isCustomCoverMode && _customDividerStyle == divId;

            return InkWell(
              onTap: () => setState(() {
                _customDividerStyle = divId;
                _isCustomCoverMode = true;
                if (_selectedWebBg.isEmpty ||
                    _selectedWebBg.startsWith('modelo_') ||
                    _selectedWebBg.contains('energiasolar')) {
                  _selectedWebBg = SolarSettingsModel.availableWebBackgrounds.first;
                }
              }),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    // Mini Preview Vetorial do Separador
                    Container(
                      width: 50,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: CustomPaint(
                          painter: SolarCoverDividerPainter(
                            dividerType: divId,
                            primaryColor: Color(_hexToInt(_customDividerColor)),
                            splitYRatio: 0.60,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            div['name'] as String,
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? const Color(0xFF065F46) : const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            div['desc'] as String,
                            style: GoogleFonts.inter(fontSize: 9.5, color: const Color(0xFF64748B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 14),

        // Seletor de Cor do Separador
        _label('Cor do Separador / Fita Geométrica:'),
        const SizedBox(height: 6),
        _buildColorChipSelector(
          selectedColorHex: _customDividerColor,
          onColorSelected: (c) => setState(() => _customDividerColor = c),
        ),
      ],
    );
  }

  /// Editor de Textos, Tipografia e Emblemas de acordo com o Estilo Selecionado
  Widget _buildTypographyAndBadgeEditor() {
    // Ambos os estilos (Modern e Vertical Split) são agora 100% padronizados
    // e personalizados dentro do Estúdio Visual ("PERSONALIZAR CAPA & VISUAL")
    return const SizedBox.shrink();
  }



  /// Seletor de Cores com Chips Rápidos
  Widget _buildColorChipSelector({
    required String selectedColorHex,
    required ValueChanged<String> onColorSelected,
  }) {
    const colors = [
      {'hex': '#FFFFFF', 'name': 'Branco', 'border': true},
      {'hex': '#0F172A', 'name': 'Preto Grafite'},
      {'hex': '#0284C7', 'name': 'Azul Ciano'},
      {'hex': '#2563EB', 'name': 'Azul Royal'},
      {'hex': '#F59E0B', 'name': 'Âmbar Solar'},
      {'hex': '#F97316', 'name': 'Laranja Energia'},
      {'hex': '#10B981', 'name': 'Verde Esmeralda'},
      {'hex': '#8B5CF6', 'name': 'Roxo Tech'},
      {'hex': '#EF4444', 'name': 'Vermelho Rubi'},
      {'hex': '#475569', 'name': 'Cinza Ardósia'},
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: colors.map((c) {
        final hex = c['hex'] as String;
        final isSelected = selectedColorHex.toUpperCase() == hex.toUpperCase();
        final colorVal = Color(_hexToInt(hex));
        final needsBorder = c['border'] == true;

        return InkWell(
          onTap: () => onColorSelected(hex),
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: colorVal,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF0284C7)
                    : needsBorder
                        ? const Color(0xFFCBD5E1)
                        : Colors.transparent,
                width: isSelected ? 2.5 : 1,
              ),
              boxShadow: isSelected
                  ? [BoxShadow(color: colorVal.withValues(alpha: 0.5), blurRadius: 6, offset: const Offset(0, 2))]
                  : null,
            ),
            child: isSelected
                ? Icon(
                    Icons.check,
                    size: 14,
                    color: hex == '#FFFFFF' ? Colors.black : Colors.white,
                  )
                : null,
          ),
        );
      }).toList(),
    );
  }

  /// Abertura de Seletor de Arquivos para Foto da Capa
  Future<void> _pickCustomCoverFile() async {
    try {
      final allowed = await AiUsageTelemetryService.guardUploadOrAgent(
        context,
        actionLabel: 'Upload de Foto da Capa',
      );
      if (!allowed) return;

      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      );

      if (files.isNotEmpty) {
        if (mounted) {
          TaosLoadingPopup.show(context, message: 'Carregando Imagem');
          await Future.delayed(const Duration(milliseconds: 60));
        }
        try {
          final bytes = await files.first.readAsBytes();
          final b64 = SolarSettingsService.compressImageBytesForFirestore(bytes);
          await AiUsageTelemetryService.recordUploadOrAgentCost(
            actionType: 'upload_cover',
            bytes: bytes.length,
          );
          if (mounted) {
            setState(() {
              _customCoverImageBase64 = b64;
              _isCustomCoverMode = true;
              _coverSubTab = 1;
              _settings = _settings.copyWith(
                customCoverImageBase64: b64,
                isCustomCoverMode: true,
              );
            });
            _editorTick.value++;
          }
        } finally {
          if (mounted) {
            TaosLoadingPopup.hide(context);
          }
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Foto da capa carregada com sucesso!'),
              backgroundColor: Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[SolarSettingsView] Erro ao selecionar arquivo: $e');
    }
  }

  /// Abertura de Seletor de Arquivos para Logomarca da Empresa
  Future<void> _pickLogoFile() async {
    try {
      final allowed = await AiUsageTelemetryService.guardUploadOrAgent(
        context,
        actionLabel: 'Upload de Logomarca',
      );
      if (!allowed) return;

      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
      );

      if (files.isNotEmpty) {
        final bytes = await files.first.readAsBytes();
        final b64 = SolarSettingsService.compressImageBytesForFirestore(
          bytes,
          maxWidth: 600,
          maxBase64Chars: 350000,
          keepPngTransparency: true,
        );
        await AiUsageTelemetryService.recordUploadOrAgentCost(
          actionType: 'upload_logo',
          bytes: bytes.length,
        );
        setState(() {
          _companyLogoBase64 = b64;
          _coverShowLogo = true;
        });
        _editorTick.value++;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Logomarca carregada! Arraste e posicione na capa.'),
              backgroundColor: Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[SolarSettingsView] Erro ao selecionar logomarca: $e');
    }
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

class _StickySectionPreviewRow extends StatefulWidget {
  final Widget controls;
  final Widget preview;

  const _StickySectionPreviewRow({
    required this.controls,
    required this.preview,
  });

  @override
  State<_StickySectionPreviewRow> createState() => _StickySectionPreviewRowState();
}

class _StickySectionPreviewRowState extends State<_StickySectionPreviewRow> {
  final GlobalKey _rowKey = GlobalKey();
  final GlobalKey _previewKey = GlobalKey();
  final ValueNotifier<double> _offsetNotifier = ValueNotifier<double>(0.0);
  ScrollPosition? _scrollPosition;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newPosition = Scrollable.maybeOf(context)?.position;
    if (newPosition != _scrollPosition) {
      _scrollPosition?.removeListener(_updateStickyOffset);
      _scrollPosition = newPosition;
      _scrollPosition?.addListener(_updateStickyOffset);
      WidgetsBinding.instance.addPostFrameCallback((_) => _updateStickyOffset());
    }
  }

  @override
  void didUpdateWidget(covariant _StickySectionPreviewRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateStickyOffset());
  }

  void _updateStickyOffset() {
    if (!mounted) return;
    final rowCtx = _rowKey.currentContext;
    final previewCtx = _previewKey.currentContext;
    final scrollableCtx = _scrollPosition?.context.storageContext;
    if (rowCtx == null || previewCtx == null || scrollableCtx == null) return;

    final rowBox = rowCtx.findRenderObject() as RenderBox?;
    final previewBox = previewCtx.findRenderObject() as RenderBox?;
    final viewportBox = scrollableCtx.findRenderObject() as RenderBox?;
    if (rowBox == null || previewBox == null || viewportBox == null) return;
    if (!rowBox.hasSize || !previewBox.hasSize || !viewportBox.hasSize) return;

    final rowTopInViewport = rowBox.localToGlobal(Offset.zero, ancestor: viewportBox).dy;
    final maxOffset = (rowBox.size.height - previewBox.size.height).clamp(0.0, double.infinity);
    final desiredOffset = rowTopInViewport < 16.0 ? (16.0 - rowTopInViewport) : 0.0;
    final nextOffset = desiredOffset.clamp(0.0, maxOffset);

    if ((nextOffset - _offsetNotifier.value).abs() > 0.5) {
      _offsetNotifier.value = nextOffset;
    }
  }

  @override
  void dispose() {
    _scrollPosition?.removeListener(_updateStickyOffset);
    _offsetNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      key: _rowKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 5, child: widget.controls),
        const SizedBox(width: 24),
        Expanded(
          flex: 5,
          child: ValueListenableBuilder<double>(
            valueListenable: _offsetNotifier,
            builder: (context, offset, child) {
              return Transform.translate(
                offset: Offset(0, offset),
                child: child,
              );
            },
            child: KeyedSubtree(
              key: _previewKey,
              child: widget.preview,
            ),
          ),
        ),
      ],
    );
  }
}
