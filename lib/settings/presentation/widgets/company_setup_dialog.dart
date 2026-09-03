import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../../app/theme/app_colors.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../../products/domain/models/product_model.dart';
import '../../data/services/company_service.dart';
import '../../data/services/settings_service.dart';
import '../../domain/models/company_model.dart';

/// Diálogo Modal Completo para Cadastro e Edição dos Dados da Empresa, Endereço com ViaCEP e Logomarca
class CompanySetupDialog extends StatefulWidget {
  final ProductSector? selectedSector;
  final bool isFirstAccess;
  final VoidCallback? onBackToSectors;
  final VoidCallback? onCompleted;

  const CompanySetupDialog({
    super.key,
    this.selectedSector,
    this.isFirstAccess = true,
    this.onBackToSectors,
    this.onCompleted,
  });

  @override
  State<CompanySetupDialog> createState() => _CompanySetupDialogState();
}

class _CompanySetupDialogState extends State<CompanySetupDialog> {
  final _formKey = GlobalKey<FormState>();

  // Controladores: Dados Principais da Empresa
  final _nameCtrl = TextEditingController();
  final _docCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _instagramCtrl = TextEditingController();
  final _sloganCtrl = TextEditingController();

  // Controladores: Endereço (ViaCEP)
  final _cepCtrl = TextEditingController();
  final _streetCtrl = TextEditingController();
  final _numberCtrl = TextEditingController();
  final _complementCtrl = TextEditingController();
  final _neighborhoodCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _numberFocus = FocusNode();

  bool _isCepLoading = false;
  String? _cepError;
  bool _addressLocked = false;

  // Logomarca da Empresa
  String? _logoBase64;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  String? _companyId;

  late ProductSector _sector;

  @override
  void initState() {
    super.initState();
    _sector = widget.selectedSector ?? ProductSector.solarPlant;
    _loadCompanyData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _docCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _websiteCtrl.dispose();
    _instagramCtrl.dispose();
    _sloganCtrl.dispose();
    _cepCtrl.dispose();
    _streetCtrl.dispose();
    _numberCtrl.dispose();
    _complementCtrl.dispose();
    _neighborhoodCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _numberFocus.dispose();
    super.dispose();
  }

  Future<void> _loadCompanyData() async {
    try {
      final auth = AuthRepository();
      final user = await auth.getCurrentUser();
      _companyId = user?.effectiveCompanyId ?? user?.uid;

      final existing = await CompanyService.getCompany(companyId: _companyId);

      if (existing != null) {
        _nameCtrl.text = existing.name;
        _docCtrl.text = existing.document;
        _phoneCtrl.text = existing.phone;
        _emailCtrl.text = existing.email ?? (user?.email ?? '');
        _websiteCtrl.text = existing.website ?? '';
        _instagramCtrl.text = existing.instagram ?? '';
        _sloganCtrl.text = existing.slogan ?? '';

        _cepCtrl.text = existing.zipCode ?? '';
        _streetCtrl.text = existing.street ?? '';
        _numberCtrl.text = existing.number ?? '';
        _complementCtrl.text = existing.complement ?? '';
        _neighborhoodCtrl.text = existing.neighborhood ?? '';
        _cityCtrl.text = existing.city ?? '';
        _stateCtrl.text = existing.state ?? '';

        if (existing.street != null && existing.street!.isNotEmpty) {
          _addressLocked = true;
        }

        _logoBase64 = existing.logoBase64;
        if (existing.productSector != null) {
          _sector = existing.productSector!;
        }
      } else {
        // Pré-preenche com o e-mail do admin logado caso seja cadastro inicial
        if (user?.email != null && user!.email.isNotEmpty) {
          _emailCtrl.text = user.email;
        }
      }
    } catch (e) {
      debugPrint('[CompanySetupDialog] Erro ao carregar dados da empresa: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Busca de Endereço via API Pública ViaCEP ─────────────────────────────
  Future<void> _searchCep(String rawCep) async {
    final cep = rawCep.replaceAll(RegExp(r'\D'), '');
    if (cep.length != 8) return;

    setState(() {
      _isCepLoading = true;
      _cepError = null;
    });

    try {
      final uri = Uri.parse('https://viacep.com.br/ws/$cep/json/');
      final response = await http.get(uri).timeout(const Duration(seconds: 8));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        if (data.containsKey('erro') && data['erro'] == true) {
          setState(() {
            _isCepLoading = false;
            _cepError = 'CEP não encontrado.';
          });
          return;
        }

        setState(() {
          _isCepLoading = false;
          _streetCtrl.text = data['logradouro'] as String? ?? '';
          _neighborhoodCtrl.text = data['bairro'] as String? ?? '';
          _cityCtrl.text = data['localidade'] as String? ?? '';
          _stateCtrl.text = data['uf'] as String? ?? '';
          final comp = data['complemento'] as String? ?? '';
          if (comp.isNotEmpty && _complementCtrl.text.isEmpty) {
            _complementCtrl.text = comp;
          }
          _addressLocked = true;
          _cepError = null;
        });

        _numberFocus.requestFocus();
      } else {
        setState(() {
          _isCepLoading = false;
          _cepError = 'Erro ao consultar CEP.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCepLoading = false;
        _cepError = 'Falha ao buscar CEP. Preencha manualmente.';
      });
    }
  }

  // ── Upload da Logomarca ──────────────────────────────────────────────────
  Future<void> _pickLogoFile() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
      );

      if (files.isNotEmpty) {
        final bytes = await files.first.readAsBytes();
        final b64 = base64Encode(bytes);
        setState(() {
          _logoBase64 = b64;
          _errorMessage = null;
        });
      }
    } catch (e) {
      debugPrint('[CompanySetupDialog] Erro ao selecionar logomarca: $e');
      setState(() => _errorMessage = 'Erro ao selecionar imagem: $e');
    }
  }

  // ── Salvar Configuração da Empresa ───────────────────────────────────────
  Future<void> _saveCompanyProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final now = DateTime.now();
      final cid = _companyId ?? 'company_${now.millisecondsSinceEpoch}';

      final company = CompanyModel(
        id: cid,
        name: _nameCtrl.text.trim(),
        document: _docCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim().isNotEmpty ? _emailCtrl.text.trim() : null,
        website: _websiteCtrl.text.trim().isNotEmpty ? _websiteCtrl.text.trim() : null,
        instagram: _instagramCtrl.text.trim().isNotEmpty ? _instagramCtrl.text.trim() : null,
        slogan: _sloganCtrl.text.trim().isNotEmpty ? _sloganCtrl.text.trim() : null,
        sector: _sector.name,
        logoBase64: _logoBase64,
        zipCode: _cepCtrl.text.trim().isNotEmpty ? _cepCtrl.text.trim() : null,
        street: _streetCtrl.text.trim().isNotEmpty ? _streetCtrl.text.trim() : null,
        number: _numberCtrl.text.trim().isNotEmpty ? _numberCtrl.text.trim() : null,
        complement: _complementCtrl.text.trim().isNotEmpty ? _complementCtrl.text.trim() : null,
        neighborhood: _neighborhoodCtrl.text.trim().isNotEmpty ? _neighborhoodCtrl.text.trim() : null,
        city: _cityCtrl.text.trim().isNotEmpty ? _cityCtrl.text.trim() : null,
        state: _stateCtrl.text.trim().isNotEmpty ? _stateCtrl.text.trim() : null,
        onboardingCompleted: true,
        createdAt: now,
        updatedAt: now,
      );

      // Salva no Firestore e no cache local
      await CompanyService.saveCompany(company);

      // Salva a preferência de nicho fixo
      await SettingsService.savePreferredSector(_sector, isFixed: true);
      await SettingsService.setCompletedOnboarding(true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.isFirstAccess
                        ? 'Empresa configurada com sucesso! Bem-vindo ao Mavis CRM.'
                        : 'Dados da empresa atualizados com sucesso!',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );

        Navigator.of(context).pop();
        widget.onCompleted?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Falha ao salvar dados da empresa: $e';
        });
      }
    }
  }

  // ── Pular Preenchimento e Configurar Depois ──────────────────────────────
  Future<void> _skipAndFillLater() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      // 1. Salva o nicho de atuação escolhido como fixo no cache e no Firestore
      await SettingsService.savePreferredSector(_sector, isFixed: true);
      await SettingsService.setCompletedOnboarding(true);
      await CompanyService.saveCompanySector(_sector, companyId: _companyId);

      // 2. Se houver algum campo preenchido, salva silenciosamente
      if (_nameCtrl.text.trim().isNotEmpty || _docCtrl.text.trim().isNotEmpty) {
        final now = DateTime.now();
        final cid = _companyId ?? 'company_${now.millisecondsSinceEpoch}';
        final partialCompany = CompanyModel(
          id: cid,
          name: _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : '',
          document: _docCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          email: _emailCtrl.text.trim().isNotEmpty ? _emailCtrl.text.trim() : null,
          website: _websiteCtrl.text.trim().isNotEmpty ? _websiteCtrl.text.trim() : null,
          instagram: _instagramCtrl.text.trim().isNotEmpty ? _instagramCtrl.text.trim() : null,
          slogan: _sloganCtrl.text.trim().isNotEmpty ? _sloganCtrl.text.trim() : null,
          sector: _sector.name,
          logoBase64: _logoBase64,
          zipCode: _cepCtrl.text.trim().isNotEmpty ? _cepCtrl.text.trim() : null,
          street: _streetCtrl.text.trim().isNotEmpty ? _streetCtrl.text.trim() : null,
          number: _numberCtrl.text.trim().isNotEmpty ? _numberCtrl.text.trim() : null,
          complement: _complementCtrl.text.trim().isNotEmpty ? _complementCtrl.text.trim() : null,
          neighborhood: _neighborhoodCtrl.text.trim().isNotEmpty ? _neighborhoodCtrl.text.trim() : null,
          city: _cityCtrl.text.trim().isNotEmpty ? _cityCtrl.text.trim() : null,
          state: _stateCtrl.text.trim().isNotEmpty ? _stateCtrl.text.trim() : null,
          onboardingCompleted: true,
          createdAt: now,
          updatedAt: now,
        );
        await CompanyService.saveCompany(partialCompany);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Ramo "${_sector.title}" ativado! Você pode preencher os dados da empresa e logomarca a qualquer momento em Configurações.',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF0F172A),
            behavior: SnackBarBehavior.floating,
          ),
        );

        Navigator.of(context).pop();
        widget.onCompleted?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Falha ao salvar preferências: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 768;
    final dialogWidth = (screenSize.width * 0.94).clamp(380.0, 980.0);
    final dialogHeight = (screenSize.height * 0.92).clamp(520.0, 840.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Center(
        child: Container(
          width: dialogWidth,
          height: dialogHeight,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 40,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                        // ── CABEÇALHO DO DIÁLOGO ──────────────────────────────
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 18 : 28,
                            vertical: isMobile ? 16 : 22,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(24),
                              topRight: Radius.circular(24),
                            ),
                            border: Border(
                              bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: _sector.themeColor.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _sector.themeColor.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Icon(_sector.icon, color: _sector.themeColor, size: isMobile ? 22 : 26),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          widget.isFirstAccess
                                              ? 'Configuração da Empresa'
                                              : 'Dados da Empresa & Identidade Visual',
                                          style: GoogleFonts.outfit(
                                            fontSize: isMobile ? 16 : 19,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: _sector.themeColor.withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: _sector.themeColor.withValues(alpha: 0.4)),
                                          ),
                                          child: Text(
                                            _sector.title.toUpperCase(),
                                            style: GoogleFonts.inter(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: _sector.themeColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      widget.isFirstAccess
                                          ? 'Preencha os dados institucionais, endereço e logomarca para personalizar suas propostas e PDFs.'
                                          : 'Edite os dados cadastrais, endereço e logomarca da sua empresa.',
                                      style: GoogleFonts.inter(
                                        fontSize: isMobile ? 11.5 : 12.5,
                                        color: const Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!widget.isFirstAccess)
                                IconButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                                  tooltip: 'Fechar',
                                ),
                            ],
                          ),
                        ),

                        // ── CORPO DO FORMULÁRIO (SCROLLÁVEL) ───────────────────
                        Expanded(
                          child: SingleChildScrollView(
                            padding: EdgeInsets.all(isMobile ? 16 : 28),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_errorMessage != null) ...[
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF2F2),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 20),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              _errorMessage!,
                                              style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFFB91C1C)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                  ],

                                  // ── SEÇÃO 1: DADOS OBRIGATÓRIOS DA EMPRESA ────
                                  _sectionHeader(
                                    icon: Icons.business_rounded,
                                    title: '1. Dados da Empresa (Exibidos em Propostas & PDFs)',
                                    subtitle: 'Informações cadastrais e canais de contato da organização',
                                  ),
                                  const SizedBox(height: 14),

                                  if (isMobile) ...[
                                    _buildTextField(
                                      controller: _nameCtrl,
                                      label: 'Razão Social / Nome Fantasia *',
                                      hintText: 'Ex: Alpha Soluções & Energia Ltda',
                                      prefixIcon: Icons.business_rounded,
                                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe a Razão Social ou Nome Fantasia' : null,
                                    ),
                                    const SizedBox(height: 12),
                                    _buildTextField(
                                      controller: _docCtrl,
                                      label: 'CNPJ / CPF *',
                                      hintText: '00.000.000/0000-00',
                                      prefixIcon: Icons.badge_outlined,
                                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o CNPJ ou CPF' : null,
                                    ),
                                    const SizedBox(height: 12),
                                    _buildTextField(
                                      controller: _phoneCtrl,
                                      label: 'Telefone / WhatsApp Comercial *',
                                      hintText: '(00) 00000-0000',
                                      prefixIcon: Icons.phone_outlined,
                                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o Telefone / WhatsApp' : null,
                                    ),
                                    const SizedBox(height: 12),
                                    _buildTextField(
                                      controller: _emailCtrl,
                                      label: 'E-mail Comercial',
                                      hintText: 'contato@empresa.com.br',
                                      prefixIcon: Icons.mail_outline_rounded,
                                    ),
                                    const SizedBox(height: 12),
                                    _buildTextField(
                                      controller: _websiteCtrl,
                                      label: 'Site Oficial',
                                      hintText: 'www.empresa.com.br',
                                      prefixIcon: Icons.language_rounded,
                                    ),
                                    const SizedBox(height: 12),
                                    _buildTextField(
                                      controller: _instagramCtrl,
                                      label: 'Instagram / Redes',
                                      hintText: '@empresa',
                                      prefixIcon: Icons.camera_alt_outlined,
                                    ),
                                    const SizedBox(height: 12),
                                    _buildTextField(
                                      controller: _sloganCtrl,
                                      label: 'Slogan / Frase de Impacto',
                                      hintText: 'Ex: Energia que Transforma o Futuro',
                                      prefixIcon: Icons.auto_awesome_rounded,
                                    ),
                                  ] else ...[
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: _buildTextField(
                                            controller: _nameCtrl,
                                            label: 'Razão Social / Nome Fantasia *',
                                            hintText: 'Ex: Alpha Soluções & Energia Ltda',
                                            prefixIcon: Icons.business_rounded,
                                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe a Razão Social ou Nome Fantasia' : null,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          flex: 2,
                                          child: _buildTextField(
                                            controller: _docCtrl,
                                            label: 'CNPJ / CPF *',
                                            hintText: '00.000.000/0000-00',
                                            prefixIcon: Icons.badge_outlined,
                                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o CNPJ ou CPF' : null,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: _buildTextField(
                                            controller: _phoneCtrl,
                                            label: 'Telefone / WhatsApp Comercial *',
                                            hintText: '(00) 00000-0000',
                                            prefixIcon: Icons.phone_outlined,
                                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o Telefone / WhatsApp' : null,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: _buildTextField(
                                            controller: _emailCtrl,
                                            label: 'E-mail Comercial',
                                            hintText: 'contato@empresa.com.br',
                                            prefixIcon: Icons.mail_outline_rounded,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: _buildTextField(
                                            controller: _websiteCtrl,
                                            label: 'Site Oficial',
                                            hintText: 'www.empresa.com.br',
                                            prefixIcon: Icons.language_rounded,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: _buildTextField(
                                            controller: _instagramCtrl,
                                            label: 'Instagram / Redes',
                                            hintText: '@empresa',
                                            prefixIcon: Icons.camera_alt_outlined,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          flex: 2,
                                          child: _buildTextField(
                                            controller: _sloganCtrl,
                                            label: 'Slogan / Frase de Impacto',
                                            hintText: 'Ex: Energia que Transforma o Futuro',
                                            prefixIcon: Icons.auto_awesome_rounded,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],

                                  const SizedBox(height: 24),
                                  const Divider(color: AppColors.divider),
                                  const SizedBox(height: 18),

                                  // ── SEÇÃO 2: ENDEREÇO DA EMPRESA (VIACEP) ────
                                  _sectionHeader(
                                    icon: Icons.location_on_rounded,
                                    title: '2. Endereço da Empresa (Busca Automática ViaCEP)',
                                    subtitle: 'Digite o CEP para autocompletar logradouro, bairro, cidade e estado',
                                  ),
                                  const SizedBox(height: 14),

                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      SizedBox(
                                        width: isMobile ? 160 : 200,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            _fieldLabel('CEP (8 dígitos)'),
                                            const SizedBox(height: 6),
                                            TextFormField(
                                              controller: _cepCtrl,
                                              keyboardType: TextInputType.number,
                                              onChanged: (v) {
                                                final clean = v.replaceAll(RegExp(r'\D'), '');
                                                if (clean.length == 8) _searchCep(clean);
                                              },
                                              decoration: InputDecoration(
                                                hintText: '00000-000',
                                                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 18),
                                                suffixIcon: _isCepLoading
                                                    ? const Padding(
                                                        padding: EdgeInsets.all(10),
                                                        child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                                                      )
                                                    : null,
                                                filled: true,
                                                fillColor: const Color(0xFFF8FAFC),
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      if (_addressLocked)
                                        TextButton.icon(
                                          onPressed: () => setState(() => _addressLocked = false),
                                          icon: const Icon(Icons.lock_open_rounded, size: 16, color: Color(0xFF64748B)),
                                          label: Text('Editar campos', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                                        ),
                                    ],
                                  ),

                                  if (_cepError != null) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      _cepError!,
                                      style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFFEF4444), fontWeight: FontWeight.w600),
                                    ),
                                  ],

                                  const SizedBox(height: 14),

                                  if (isMobile) ...[
                                    _buildTextField(
                                      controller: _streetCtrl,
                                      label: 'Logradouro / Rua',
                                      hintText: 'Ex: Av. Paulista',
                                      prefixIcon: Icons.signpost_outlined,
                                      readOnly: _addressLocked,
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildTextField(
                                            controller: _numberCtrl,
                                            label: 'Número',
                                            hintText: '1000',
                                            focusNode: _numberFocus,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          flex: 2,
                                          child: _buildTextField(
                                            controller: _complementCtrl,
                                            label: 'Complemento',
                                            hintText: 'Sala 402 / Galpão B',
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    _buildTextField(
                                      controller: _neighborhoodCtrl,
                                      label: 'Bairro',
                                      hintText: 'Bela Vista',
                                      readOnly: _addressLocked,
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: _buildTextField(
                                            controller: _cityCtrl,
                                            label: 'Cidade',
                                            hintText: 'São Paulo',
                                            readOnly: _addressLocked,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _buildTextField(
                                            controller: _stateCtrl,
                                            label: 'UF',
                                            hintText: 'SP',
                                            readOnly: _addressLocked,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ] else ...[
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: _buildTextField(
                                            controller: _streetCtrl,
                                            label: 'Logradouro / Rua',
                                            hintText: 'Ex: Av. Paulista',
                                            prefixIcon: Icons.signpost_outlined,
                                            readOnly: _addressLocked,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        SizedBox(
                                          width: 110,
                                          child: _buildTextField(
                                            controller: _numberCtrl,
                                            label: 'Número',
                                            hintText: '1000',
                                            focusNode: _numberFocus,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          flex: 2,
                                          child: _buildTextField(
                                            controller: _complementCtrl,
                                            label: 'Complemento',
                                            hintText: 'Sala 402 / Galpão B',
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          flex: 2,
                                          child: _buildTextField(
                                            controller: _neighborhoodCtrl,
                                            label: 'Bairro',
                                            hintText: 'Bela Vista',
                                            readOnly: _addressLocked,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          flex: 2,
                                          child: _buildTextField(
                                            controller: _cityCtrl,
                                            label: 'Cidade',
                                            hintText: 'São Paulo',
                                            readOnly: _addressLocked,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        SizedBox(
                                          width: 90,
                                          child: _buildTextField(
                                            controller: _stateCtrl,
                                            label: 'UF',
                                            hintText: 'SP',
                                            readOnly: _addressLocked,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],

                                  const SizedBox(height: 24),
                                  const Divider(color: AppColors.divider),
                                  const SizedBox(height: 18),

                                  // ── SEÇÃO 3: LOGOMARCA DA EMPRESA ────────────
                                  _sectionHeader(
                                    icon: Icons.image_rounded,
                                    title: '3. Logomarca da Empresa',
                                    subtitle: 'A imagem será exibida nas capas das propostas comerciais, PDFs e cabeçalhos',
                                  ),
                                  const SizedBox(height: 14),

                                  Container(
                                    padding: const EdgeInsets.all(18),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: AppColors.border),
                                    ),
                                    child: Row(
                                      children: [
                                        // Preview da Logo
                                        Container(
                                          width: 110,
                                          height: 70,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: const Color(0xFFE2E8F0)),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.04),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: _logoBase64 != null && _logoBase64!.isNotEmpty
                                              ? ClipRRect(
                                                  borderRadius: BorderRadius.circular(12),
                                                  child: Image.memory(
                                                    base64Decode(_logoBase64!),
                                                    fit: BoxFit.contain,
                                                    errorBuilder: (_, __, ___) => const Center(
                                                      child: Icon(Icons.broken_image_rounded, color: Color(0xFF94A3B8)),
                                                    ),
                                                  ),
                                                )
                                              : Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Icon(Icons.add_photo_alternate_outlined, color: const Color(0xFF94A3B8), size: 24),
                                                    const SizedBox(height: 4),
                                                    Text('Sem Logo', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8))),
                                                  ],
                                                ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _logoBase64 != null
                                                    ? 'Logomarca carregada com sucesso'
                                                    : 'Nenhuma logomarca enviada',
                                                style: GoogleFonts.outfit(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13.5,
                                                  color: const Color(0xFF0F172A),
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'Formatos suportados: PNG com fundo transparente, JPG ou WEBP.',
                                                style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                                              ),
                                              const SizedBox(height: 10),
                                              Row(
                                                children: [
                                                  ElevatedButton.icon(
                                                    onPressed: _pickLogoFile,
                                                    icon: Icon(
                                                      _logoBase64 != null ? Icons.sync_rounded : Icons.cloud_upload_rounded,
                                                      size: 16,
                                                    ),
                                                    label: Text(
                                                      _logoBase64 != null ? 'TROCAR LOGOMARCA' : 'ENVIAR LOGOMARCA',
                                                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                                                    ),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: const Color(0xFF0F172A),
                                                      foregroundColor: Colors.white,
                                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                    ),
                                                  ),
                                                  if (_logoBase64 != null) ...[
                                                    const SizedBox(width: 10),
                                                    TextButton.icon(
                                                      onPressed: () => setState(() => _logoBase64 = null),
                                                      icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                                                      label: Text(
                                                        'Remover',
                                                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFEF4444), fontWeight: FontWeight.bold),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ],
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

                        // ── RODAPÉ DO DIÁLOGO ─────────────────────────────────
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 16 : 28,
                            vertical: isMobile ? 14 : 18,
                          ),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(24),
                              bottomRight: Radius.circular(24),
                            ),
                            border: Border(
                              top: BorderSide(color: AppColors.border),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (widget.isFirstAccess && widget.onBackToSectors != null)
                                TextButton.icon(
                                  onPressed: widget.onBackToSectors,
                                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                                  label: Text(
                                    'VOLTAR AO NICHO',
                                    style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold),
                                  ),
                                  style: TextButton.styleFrom(foregroundColor: const Color(0xFF64748B)),
                                )
                              else
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: Text(
                                    'CANCELAR',
                                    style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF64748B)),
                                  ),
                                ),
                              Row(
                                children: [
                                  if (widget.isFirstAccess) ...[
                                    OutlinedButton.icon(
                                      onPressed: _isSaving ? null : _skipAndFillLater,
                                      icon: const Icon(Icons.schedule_rounded, size: 16, color: Color(0xFF64748B)),
                                      label: Text(
                                        'PREENCHER DEPOIS',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF475569),
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                                        padding: EdgeInsets.symmetric(
                                          horizontal: isMobile ? 12 : 18,
                                          vertical: isMobile ? 12 : 14,
                                        ),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                  ],
                                  ElevatedButton.icon(
                                    onPressed: _isSaving ? null : _saveCompanyProfile,
                                    icon: _isSaving
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                          )
                                        : const Icon(Icons.check_circle_rounded, size: 18),
                                    label: Text(
                                      _isSaving
                                          ? 'SALVANDO...'
                                          : (widget.isFirstAccess ? 'CONCLUIR E INICIAR 🚀' : 'SALVAR ALTERAÇÕES'),
                                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF10B981),
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isMobile ? 18 : 26,
                                        vertical: isMobile ? 12 : 14,
                                      ),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      elevation: 2,
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
      ),
    );
  }

  Widget _sectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF0F172A), size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(fontSize: 14.5, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
              ),
              Text(
                subtitle,
                style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    IconData? prefixIcon,
    FocusNode? focusNode,
    bool readOnly = false,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          readOnly: readOnly,
          validator: validator,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: readOnly ? const Color(0xFF64748B) : const Color(0xFF0F172A),
            fontWeight: readOnly ? FontWeight.w500 : FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF94A3B8)),
            prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: const Color(0xFF64748B), size: 18) : null,
            filled: true,
            fillColor: readOnly ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.2)),
            focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5)),
          ),
        ),
      ],
    );
  }
}
