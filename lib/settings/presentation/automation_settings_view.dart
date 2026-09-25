import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import '../../app/theme/app_colors.dart';
import '../../auth/data/repositories/auth_repository.dart';
import '../../products/domain/models/product_model.dart';
import '../../proposals/data/services/automation_proposal_pdf_service.dart';
import '../data/services/automation_preset_catalog.dart';
import '../data/services/automation_settings_service.dart';
import '../domain/models/automation_settings_model.dart';
import 'widgets/automation_cover_customizer_dialog.dart';
import 'widgets/automation_cyber_connector_painter.dart';
import 'widgets/solar_cover_divider_painter.dart';

/// Tela Principal do Configurador do Nicho de Automação Residencial (2 Abas: Dados da Empresa & Modelo Visual de Proposta PDF)
class AutomationSettingsView extends StatefulWidget {
  final VoidCallback? onBack;

  const AutomationSettingsView({super.key, this.onBack});

  @override
  State<AutomationSettingsView> createState() => _AutomationSettingsViewState();
}

class _AutomationSettingsViewState extends State<AutomationSettingsView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late final AutomationSettingsService _service;
  late final AuthRepository _authRepo;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isSearchingCep = false;

  AutomationSettingsModel _settings = const AutomationSettingsModel();

  // Categorias e busca na Tab 2 (100 Capas de Automação)
  String _selectedCategory = 'Cyber Mansion'; // 'Cyber Mansion' ou 'Cyber Divider'
  String _coverSearchQuery = '';

  // Controllers — Aba 1: Dados da Empresa
  final _nameCtrl = TextEditingController();
  final _docCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _instagramCtrl = TextEditingController();
  final _sloganCtrl = TextEditingController();

  // Controllers — Endereço (ViaCEP)
  final _cepCtrl = TextEditingController();
  final _logradouroCtrl = TextEditingController();
  final _numeroCtrl = TextEditingController();
  final _complementoCtrl = TextEditingController();
  final _bairroCtrl = TextEditingController();
  final _cidadeCtrl = TextEditingController();
  final _ufCtrl = TextEditingController();

  // Controllers — PDF Config
  final _pdfTermsCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _service = AutomationSettingsService();
    _authRepo = AuthRepository();
    _loadSettings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameCtrl.dispose();
    _docCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _websiteCtrl.dispose();
    _instagramCtrl.dispose();
    _sloganCtrl.dispose();
    _cepCtrl.dispose();
    _logradouroCtrl.dispose();
    _numeroCtrl.dispose();
    _complementoCtrl.dispose();
    _bairroCtrl.dispose();
    _cidadeCtrl.dispose();
    _ufCtrl.dispose();
    _pdfTermsCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final user = await _authRepo.getCurrentUser();
      final companyId = user?.companyId ?? '';
      _settings = await _service.fetchSettings(companyId);
      _selectedCategory = _settings.activeCategory;
      _populateControllers();
    } catch (_) {
      _settings = const AutomationSettingsModel();
      _populateControllers();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _populateControllers() {
    _nameCtrl.text = _settings.companyName;
    _docCtrl.text = _settings.companyDoc;
    _phoneCtrl.text = _settings.companyPhone;
    _emailCtrl.text = _settings.companyEmail;
    _websiteCtrl.text = _settings.companyWebsite;
    _instagramCtrl.text = _settings.companyInstagram;
    _sloganCtrl.text = _settings.companySlogan;

    _cepCtrl.text = _settings.cep;
    _logradouroCtrl.text = _settings.logradouro;
    _numeroCtrl.text = _settings.numero;
    _complementoCtrl.text = _settings.complemento;
    _bairroCtrl.text = _settings.bairro;
    _cidadeCtrl.text = _settings.cidade;
    _ufCtrl.text = _settings.uf;

    _pdfTermsCtrl.text = _settings.pdfTermsText;
  }

  // Consulta automática de CEP via ViaCEP
  Future<void> _fetchCep(String cep) async {
    final cleanCep = cep.replaceAll(RegExp(r'\D'), '');
    if (cleanCep.length != 8) return;

    setState(() => _isSearchingCep = true);
    try {
      final uri = Uri.parse('https://viacep.com.br/ws/$cleanCep/json/');
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['erro'] != true) {
          setState(() {
            _logradouroCtrl.text = data['logradouro'] ?? '';
            _bairroCtrl.text = data['bairro'] ?? '';
            _cidadeCtrl.text = data['localidade'] ?? '';
            _ufCtrl.text = data['uf'] ?? '';
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Endereço autocompletado via ViaCEP com sucesso!'),
                backgroundColor: AppColors.success,
              ),
            );
          }
        }
      }
    } catch (_) {
      // Falha silenciosa
    } finally {
      if (mounted) setState(() => _isSearchingCep = false);
    }
  }

  Future<void> _saveAll() async {
    setState(() => _isSaving = true);
    try {
      final updated = _settings.copyWith(
        companyName: _nameCtrl.text,
        companyDoc: _docCtrl.text,
        companyPhone: _phoneCtrl.text,
        companyEmail: _emailCtrl.text,
        companyWebsite: _websiteCtrl.text,
        companyInstagram: _instagramCtrl.text,
        companySlogan: _sloganCtrl.text,
        cep: _cepCtrl.text,
        logradouro: _logradouroCtrl.text,
        numero: _numeroCtrl.text,
        complemento: _complementoCtrl.text,
        bairro: _bairroCtrl.text,
        cidade: _cidadeCtrl.text,
        uf: _ufCtrl.text,
        pdfTermsText: _pdfTermsCtrl.text,
      );

      await AutomationSettingsService.saveSettings(updated);
      _settings = updated;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configurações de Automação salvas com sucesso!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  ProductModel _buildSampleProduct() {
    return ProductModel(
      id: 'sample_automation_study',
      name: 'Estudo de Automação Residencial Modelo ARBO',
      sector: ProductSector.homeAutomation,
      salePrice: 24500.0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      specificAttributes: {
        'automationEnvironments': [
          {
            'id': 'env_living',
            'name': 'Living Noturno & Home Cinema',
            'description': 'Iluminação cênica, climatização e som surround.',
            'items': [
              {'id': 'i1', 'name': 'Módulo Dimmer 6 Circuitos Zigbee', 'quantity': 2, 'unitPrice': 450.0},
              {'id': 'i2', 'name': 'Keypad Touch de Luxo 4 Teclas', 'quantity': 1, 'unitPrice': 680.0},
              {'id': 'i3', 'name': 'Amplificador Multiroom Streaming', 'quantity': 1, 'unitPrice': 4200.0},
            ],
          },
          {
            'id': 'env_gourmet',
            'name': 'Espaço Gourmet & Varanda',
            'description': 'Áudio de alta fidelidade e cenas de luz cênica.',
            'items': [
              {'id': 'i4', 'name': 'Caixas de Embutir Ângulo 8 polegadas', 'quantity': 4, 'unitPrice': 850.0},
              {'id': 'i5', 'name': 'Interface de Climatização HVAC', 'quantity': 1, 'unitPrice': 1200.0},
            ],
          },
        ],
        'laborPrice': 3500.0,
      },
    );
  }

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '').trim();
      if (clean.length == 6) return Color(int.parse('FF$clean', radix: 16));
      if (clean.length == 8) return Color(int.parse(clean, radix: 16));
      return const Color(0xFF38BDF8);
    } catch (_) {
      return const Color(0xFF38BDF8);
    }
  }

  IconData _getNodeIcon(String iconName) {
    switch (iconName) {
      case 'light':
        return Icons.lightbulb_outline_rounded;
      case 'music':
        return Icons.music_note_rounded;
      case 'temp':
        return Icons.thermostat_rounded;
      case 'camera':
        return Icons.videocam_outlined;
      case 'lock':
        return Icons.lock_outline_rounded;
      case 'wifi':
        return Icons.wifi_rounded;
      default:
        return Icons.bolt_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = _parseColor(_settings.primaryColorHex);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                // Top Header do Módulo
                _buildHeader(primaryColor),

                // Barra de Abas Principal (2 Abas)
                Container(
                  color: const Color(0xFF1E293B),
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: primaryColor,
                    labelColor: primaryColor,
                    unselectedLabelColor: Colors.white60,
                    labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
                    tabs: const [
                      Tab(
                        icon: Icon(Icons.business_rounded),
                        text: '1. DADOS DA EMPRESA & ENDEREÇO',
                      ),
                      Tab(
                        icon: Icon(Icons.style_rounded),
                        text: '2. CONFIGURAÇÃO DA PROPOSTA PDF (100 CAPAS)',
                      ),
                    ],
                  ),
                ),

                // Conteúdo das Abas
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // ABA 1: DADOS DA EMPRESA
                      _buildCompanyDataTab(primaryColor),

                      // ABA 2: MODELO VISUAL E 100 CAPAS (ESPELHO USINAS SOLARES)
                      _buildProposalConfigTab(primaryColor),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // Header da Tela
  Widget _buildHeader(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          if (widget.onBack != null) ...[
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: widget.onBack,
            ),
            const SizedBox(width: 8),
          ],
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primaryColor.withValues(alpha: 0.4)),
            ),
            child: Icon(Icons.bolt_rounded, color: primaryColor, size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Configurador do Nicho — Automação Residencial',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                'Dados da empresa (ViaCEP) e personalizador de propostas A4 (Cyber Mansion & Cyber Divider)',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.white60,
                ),
              ),
            ],
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveAll,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: const Color(0xFF0F172A),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F172A)),
                  )
                : const Icon(Icons.check_circle_rounded, size: 20),
            label: Text(
              _isSaving ? 'SALVANDO...' : 'SALVAR ALTERAÇÕES',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // 🏢 ABA 1: DADOS DA EMPRESA & ENDEREÇO (ViaCEP)
  Widget _buildCompanyDataTab(Color primaryColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1000),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('DADOS INSTITUCIONAIS DA EMPRESA', Icons.domain_rounded, primaryColor),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildInput('Razão Social / Nome Fantasia', _nameCtrl, Icons.business_rounded)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildInput('CNPJ / CPF', _docCtrl, Icons.badge_outlined)),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _buildInput('Telefone / WhatsApp', _phoneCtrl, Icons.phone_android_rounded)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildInput('E-mail Corporativo', _emailCtrl, Icons.email_outlined)),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _buildInput('Website Oficial', _websiteCtrl, Icons.language_rounded)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildInput('Instagram da Empresa', _instagramCtrl, Icons.camera_alt_outlined)),
                ],
              ),
              const SizedBox(height: 14),
              _buildInput('Slogan / Frase de Impacto', _sloganCtrl, Icons.record_voice_over_outlined),

              const SizedBox(height: 32),
              const Divider(color: Colors.white10),
              const SizedBox(height: 16),

              Row(
                children: [
                  _buildSectionTitle('ENDEREÇO DA SEDE (AUTO VIA CEP)', Icons.location_on_rounded, primaryColor),
                  const Spacer(),
                  if (_isSearchingCep)
                    Row(
                      children: [
                        SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor)),
                        const SizedBox(width: 8),
                        Text('Consultando ViaCEP...', style: TextStyle(color: primaryColor, fontSize: 12)),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  SizedBox(
                    width: 220,
                    child: _buildInput(
                      'CEP (8 Dígitos)',
                      _cepCtrl,
                      Icons.markunread_mailbox_outlined,
                      onChanged: _fetchCep,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: _buildInput('Logradouro / Rua', _logradouroCtrl, Icons.map_outlined)),
                  const SizedBox(width: 16),
                  SizedBox(width: 120, child: _buildInput('Número', _numeroCtrl, Icons.pin_drop_outlined)),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _buildInput('Complemento (Ex: Sala 402)', _complementoCtrl, Icons.apartment_rounded)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildInput('Bairro', _bairroCtrl, Icons.location_city_rounded)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildInput('Cidade', _cidadeCtrl, Icons.location_city_outlined)),
                  const SizedBox(width: 16),
                  SizedBox(width: 90, child: _buildInput('UF', _ufCtrl, Icons.flag_outlined)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🎨 ABA 2: ESTÚDIO DE CAPAS & MODELO VISUAL (ESPELHO USINAS SOLARES — IMAGENS 2, 3 E 4)
  Widget _buildProposalConfigTab(Color primaryColor) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        children: [
          // Sub-bar superior com título e botões de ação rápidas
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              border: Border(bottom: BorderSide(color: Colors.white10)),
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Estúdio de Capas & Modelo Visual da Proposta',
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      'Edite o título, cores e arraste os elementos em tempo real na capa, ou monte sua própria capa',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.white60),
                    ),
                  ],
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () async {
                    final pdfBytes = await AutomationProposalPdfService.generateProposalPdf(
                      studyProduct: _buildSampleProduct(),
                      settings: _settings,
                    );
                    await Printing.layoutPdf(
                      onLayout: (format) async => pdfBytes,
                      name: 'Proposta_Automacao_${_settings.coverTitle}.pdf',
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                  label: const Text('PRÉVIA PDF', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

          // Área Principal: Prévia ao Vivo A4 (Esquerda) + Galeria/Criador de Capas (Direita)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 👈 COLUNA ESQUERDA: PREVIEW A4 AO VIVO + BOTÃO AMARELO EM DESTAQUE "PERSONALIZAR CAPA & VISUAL"
              Container(
                width: 380,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Botão Amarelo em Destaque (Igual ao de Usinas - Imagem 2 e 3)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final updated = await AutomationCoverCustomizerDialog.show(
                            context,
                            initialSettings: _settings,
                            onSave: (saved) {
                              setState(() => _settings = saved);
                            },
                          );
                          if (updated != null) {
                            setState(() => _settings = updated);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEAB308),
                          foregroundColor: const Color(0xFF0F172A),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 4,
                        ),
                        icon: const Icon(Icons.palette_rounded, size: 20),
                        label: Text(
                          '🎨 PERSONALIZAR CAPA & VISUAL',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Card de Preview da Capa A4 com altura fixa proporcional A4
                    SizedBox(
                      height: 520,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF020617),
                            border: Border.all(color: primaryColor.withValues(alpha: 0.4), width: 2),
                          ),
                          child: LayoutBuilder(
                            builder: (ctx, constraints) {
                              final w = constraints.maxWidth;
                              final h = constraints.maxHeight;

                              return Stack(
                                children: [
                                  Positioned.fill(
                                    child: _settings.customCoverImageBase64 != null && _settings.customCoverImageBase64!.isNotEmpty
                                        ? Image.memory(
                                            base64Decode(_settings.customCoverImageBase64!.contains(',')
                                                ? _settings.customCoverImageBase64!.split(',').last
                                                : _settings.customCoverImageBase64!),
                                            fit: BoxFit.cover,
                                            errorBuilder: (c, e, s) => Container(color: Colors.white10),
                                          )
                                        : Image.network(
                                            AutomationSettingsService.getBigCoverUrl(
                                              _settings.selectedCoverTemplate.isNotEmpty
                                                  ? _settings.selectedCoverTemplate
                                                  : (_settings.coverImageUrl.isNotEmpty ? _settings.coverImageUrl : 'modelo_automacao_1.jpg'),
                                            ),
                                            fit: BoxFit.cover,
                                            errorBuilder: (c, e, s) => Container(color: Colors.white10),
                                          ),
                                  ),
                                  if (_settings.customDividerStyle < 0)
                                    Positioned.fill(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Colors.black.withValues(alpha: 0.75),
                                              Colors.transparent,
                                              Colors.black.withValues(alpha: 0.85),
                                            ],
                                            stops: const [0.0, 0.45, 1.0],
                                          ),
                                        ),
                                      ),
                                    ),

                                  // Separador geométrico se ativo (10 modelos matemáticos)
                                  if (_settings.customDividerStyle >= 0)
                                    CustomPaint(
                                      size: Size(w, h),
                                      painter: SolarCoverDividerPainter(
                                        dividerType: _settings.customDividerStyle,
                                        primaryColor: _parseColor(_settings.customDividerColor.isNotEmpty ? _settings.customDividerColor : '#38BDF8'),
                                        bottomAreaColor: _parseColor(_settings.customDividerBottomColor.isNotEmpty ? _settings.customDividerBottomColor : '#FFFFFF'),
                                        splitYRatio: 0.70,
                                      ),
                                    ),

                                  // Linhas cibernéticas se houver nós
                                  if (_settings.nodes.isNotEmpty)
                                    CustomPaint(
                                      size: Size(w, h),
                                      painter: AutomationCyberConnectorPainter(
                                        nodes: _settings.nodes,
                                        primaryColor: primaryColor,
                                      ),
                                    ),

                                  // Headlines no Preview
                                  Positioned(
                                    left: w * _settings.headlinePosX,
                                    top: h * _settings.headlinePosY,
                                    child: Container(
                                      constraints: BoxConstraints(maxWidth: w * 0.85),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: primaryColor.withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: primaryColor.withValues(alpha: 0.5)),
                                            ),
                                            child: Text(_settings.coverTag, style: GoogleFonts.inter(fontSize: 8, color: primaryColor, fontWeight: FontWeight.bold)),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(_settings.coverHeadline, style: GoogleFonts.outfit(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 4),
                                          Text(_settings.coverSubheadline, style: GoogleFonts.inter(fontSize: 9, color: Colors.white70)),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // Nós cibernéticos ícones sobre a casa
                                  for (final node in _settings.nodes)
                                    Positioned(
                                      left: node.posX * w - 10,
                                      top: node.posY * h - 10,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0F172A).withValues(alpha: 0.85),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: primaryColor, width: 1.5),
                                        ),
                                        child: Icon(_getNodeIcon(node.iconName), color: primaryColor, size: 12),
                                      ),
                                    ),

                                  // Card do Cliente translúcido
                                  Positioned(
                                    left: w * _settings.clientCardPosX,
                                    top: h * _settings.clientCardPosY,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0F172A).withValues(alpha: 0.85),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: primaryColor.withValues(alpha: 0.5)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.home_work_outlined, color: primaryColor, size: 12),
                                          const SizedBox(width: 6),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(_settings.clientTitle, style: const TextStyle(color: Colors.white54, fontSize: 7, fontWeight: FontWeight.bold)),
                                              Text(_settings.clientName, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // Badge "AO VIVO"
                                  Positioned(
                                    top: 10,
                                    right: 10,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'AO VIVO',
                                        style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 👉 COLUNA DIREITA: 100 CAPAS DE AUTOMAÇÃO (CATÁLOGO DIRETO)
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(top: 16, right: 16, bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: _build100CoversSubTab(primaryColor),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 🖼️ SUB-ABA 1: 100 CAPAS DE AUTOMAÇÃO (DROPDOWN DE CATEGORIAS + GRID - IMAGEM 2)
  Widget _build100CoversSubTab(Color primaryColor) {
    final allCategoryPresets = AutomationPresetCatalog.getPresetsByCategory(_selectedCategory);
    final filteredPresets = allCategoryPresets.where((p) {
      if (_coverSearchQuery.isEmpty) return true;
      return p.title.toLowerCase().contains(_coverSearchQuery.toLowerCase()) ||
          p.id.toLowerCase().contains(_coverSearchQuery.toLowerCase());
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selector Dropdown de Categoria (Cyber Mansion x Cyber Divider - Imagem 2)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.style_rounded, color: primaryColor, size: 20),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ESTILO DAS PROPOSTAS', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white54)),
                      Text(
                        _selectedCategory == 'Cyber Mansion'
                            ? 'Cyber Mansion (100 Capas Noturnas com Nós Cibernéticos)'
                            : 'Cyber Divider (100 Capas com Separadores & Decalque)',
                        style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white24),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCategory,
                    dropdownColor: const Color(0xFF1E293B),
                    icon: const Icon(Icons.arrow_drop_down_rounded, color: Colors.white),
                    items: const [
                      DropdownMenuItem(
                        value: 'Cyber Mansion',
                        child: Text('Cyber Mansion (100 Capas)', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                      DropdownMenuItem(
                        value: 'Cyber Divider',
                        child: Text('Cyber Divider (100 Capas)', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedCategory = val;
                        });
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Campo de Busca e Paginador
        Row(
          children: [
            Expanded(
              child: TextField(
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Buscar modelo por nome ou número (ex: 1, 15, 88)...',
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54, size: 18),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white10)),
                ),
                onChanged: (val) => setState(() => _coverSearchQuery = val),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white10),
              ),
              child: Text(
                'Total: ${filteredPresets.length} capas',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Grid de Capas da Categoria Selecionada (Expansível para rolagem na página toda)
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.71, // Formato Proporcional A4 PDF Vertical
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: filteredPresets.length,
          itemBuilder: (context, index) {
            final preset = filteredPresets[index];
            final isSelected = _settings.activePresetId == preset.id;

            return GestureDetector(
              onTap: () {
                setState(() {
                  _settings = _service.applyPreset(_settings, preset.id);
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? primaryColor : Colors.white10,
                    width: isSelected ? 2.5 : 1.0,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Image.network(
                          AutomationSettingsService.getSmallCoverUrl(preset.imageUrl),
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => Container(color: Colors.white10),
                        ),
                      ),
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black.withValues(alpha: 0.85)],
                            ),
                          ),
                        ),
                      ),

                      // Separador se for Cyber Divider
                      if (preset.category == 'Cyber Divider' && preset.customDividerStyle >= 0)
                        CustomPaint(
                          size: const Size(200, 200),
                          painter: SolarCoverDividerPainter(
                            dividerType: preset.customDividerStyle,
                            primaryColor: _parseColor(preset.primaryColorHex),
                            bottomAreaColor: Colors.white,
                            splitYRatio: 0.70,
                          ),
                        ),

                      // Número do Modelo (#1, #2)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '#${index + 1}',
                            style: GoogleFonts.outfit(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),

                      // Título e Categoria no Rodapé
                      Positioned(
                        left: 8,
                        bottom: 8,
                        right: 8,
                        child: Text(
                          preset.title,
                          style: GoogleFonts.outfit(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      if (isSelected)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(color: primaryColor, shape: BoxShape.circle),
                            child: const Icon(Icons.check_rounded, color: Color(0xFF0F172A), size: 14),
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

  Widget _buildSectionTitle(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildInput(
    String label,
    TextEditingController controller,
    IconData icon, {
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white70),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          onChanged: onChanged,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF0F172A),
            prefixIcon: Icon(icon, color: Colors.white54, size: 18),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white10)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white10)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _parseColor(_settings.primaryColorHex))),
          ),
        ),
      ],
    );
  }
}
