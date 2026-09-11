import 'dart:convert';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../products/domain/models/product_model.dart';
import '../../settings/data/services/cnpj_service.dart';
import '../../settings/data/services/company_service.dart';
import '../../settings/data/services/settings_service.dart';
import '../../settings/domain/models/company_model.dart';
import 'widgets/dark_tech_image_data.dart';
import 'widgets/onboarding_niche_card.dart';
import 'widgets/onboarding_step_progress.dart';
import '../../subscription/data/services/subscription_service.dart';
import '../../subscription/presentation/widgets/pix_checkout_dialog.dart';

/// Página Full-Screen Oficial de Onboarding do TAOS (Passo 1 de 3)
class OnboardingPage extends StatefulWidget {
  final VoidCallback? onCompleted;

  const OnboardingPage({
    super.key,
    this.onCompleted,
  });

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  int _currentStep = 1;
  final int _totalSteps = 3;

  ProductSector _selectedSector = ProductSector.solarPlant;
  SubscriptionPlan _step3SelectedPlan = SubscriptionPlan.monthly;

  // ─────────────────────────────────────────────────────────────────────────
  // CONTROLLERS DA FICHA CADASTRAL (PASSO 2)
  // ─────────────────────────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _corporateNameCtrl = TextEditingController();
  final _tradeNameCtrl = TextEditingController();
  final _cnpjCtrl = TextEditingController();
  final _statusCtrl = TextEditingController(text: 'ATIVA');
  final _sizeCtrl = TextEditingController();
  final _mainCnaeCtrl = TextEditingController();
  final _secondaryCnaesCtrl = TextEditingController();
  final _companyEmailCtrl = TextEditingController();
  final _commercialEmailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _socialCtrl = TextEditingController();
  final _sloganCtrl = TextEditingController();

  // Endereço
  final _cepCtrl = TextEditingController();
  final _streetCtrl = TextEditingController();
  final _numberCtrl = TextEditingController();
  final _complementCtrl = TextEditingController();
  final _neighborhoodCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();

  final _focusNumber = FocusNode();

  bool _isSearchingCnpj = false;
  bool _isSearchingCep = false;
  bool _isSaving = false;
  bool _isFinishing = false;
  bool _addressLocked = false;
  String? _logoBase64;
  String? _companyId;
  String? _lastAutoSearchedCnpj;

  void _onCnpjChanged(String val) {
    final clean = val.replaceAll(RegExp(r'\D'), '');
    if (clean.length == 14 && clean != _lastAutoSearchedCnpj && !_isSearchingCnpj) {
      _lastAutoSearchedCnpj = clean;
      _searchCnpj();
    } else if (clean.length < 14) {
      _lastAutoSearchedCnpj = null;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadInitialUserData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _corporateNameCtrl.dispose();
    _tradeNameCtrl.dispose();
    _cnpjCtrl.dispose();
    _statusCtrl.dispose();
    _sizeCtrl.dispose();
    _mainCnaeCtrl.dispose();
    _secondaryCnaesCtrl.dispose();
    _companyEmailCtrl.dispose();
    _commercialEmailCtrl.dispose();
    _phoneCtrl.dispose();
    _websiteCtrl.dispose();
    _socialCtrl.dispose();
    _sloganCtrl.dispose();
    _cepCtrl.dispose();
    _streetCtrl.dispose();
    _numberCtrl.dispose();
    _complementCtrl.dispose();
    _neighborhoodCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _focusNumber.dispose();
    super.dispose();
  }

  Future<void> _loadInitialUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedStep = prefs.getInt('taos_onboarding_step') ?? 1;
      final savedSector = prefs.getString('taos_onboarding_sector');
      if (savedSector != null && savedSector.isNotEmpty) {
        for (final s in ProductSector.values) {
          if (s.name == savedSector) {
            _selectedSector = s;
            break;
          }
        }
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user?.email != null) {
        _commercialEmailCtrl.text = user!.email!;
      }
      final existingComp = await CompanyService.getCompany();
      if (existingComp != null && mounted) {
        setState(() {
          _companyId = existingComp.id;
          if (existingComp.sector != null && existingComp.sector!.isNotEmpty) {
            for (final s in ProductSector.values) {
              if (s.name == existingComp.sector) {
                _selectedSector = s;
                break;
              }
            }
          }
          _nameCtrl.text = existingComp.name;
          if (existingComp.corporateName != null && existingComp.corporateName!.isNotEmpty) {
            _corporateNameCtrl.text = existingComp.corporateName!;
          } else {
            _corporateNameCtrl.text = existingComp.name;
          }
          _tradeNameCtrl.text = existingComp.tradeName ?? existingComp.name;
          if (existingComp.document.isNotEmpty) {
            _cnpjCtrl.text = CnpjInputFormatter.format(existingComp.document);
            _lastAutoSearchedCnpj = existingComp.document.replaceAll(RegExp(r'\D'), '');
          } else {
            _cnpjCtrl.text = '';
          }
          _statusCtrl.text = existingComp.registrationStatus ?? 'ATIVA';
          _sizeCtrl.text = existingComp.companySize ?? '';
          _mainCnaeCtrl.text = existingComp.mainCnae ?? '';
          _secondaryCnaesCtrl.text = existingComp.secondaryCnaes ?? '';
          _companyEmailCtrl.text = existingComp.companyEmail ?? '';
          if (existingComp.email != null && existingComp.email!.isNotEmpty) {
            _commercialEmailCtrl.text = existingComp.email!;
          }
          _phoneCtrl.text = existingComp.phone;
          _websiteCtrl.text = existingComp.website ?? '';
          _socialCtrl.text = existingComp.instagram ?? '';
          _sloganCtrl.text = existingComp.slogan ?? '';

          if ((existingComp.zipCode ?? '').isNotEmpty) {
            _cepCtrl.text = CepInputFormatter.format(existingComp.zipCode!);
          } else {
            _cepCtrl.text = '';
          }
          _streetCtrl.text = existingComp.street ?? '';
          _numberCtrl.text = existingComp.number ?? '';
          _complementCtrl.text = existingComp.complement ?? '';
          _neighborhoodCtrl.text = existingComp.neighborhood ?? '';
          _cityCtrl.text = existingComp.city ?? '';
          _stateCtrl.text = existingComp.state ?? '';
          if ((existingComp.street ?? '').isNotEmpty) {
            _addressLocked = true;
          }

          _logoBase64 = existingComp.logoBase64;
        });
      }

      // Se havia um passo salvo (ex: 2 ao atualizar a página), restaura exatamente nesse passo!
      if (savedStep > 1 && mounted) {
        setState(() {
          _currentStep = savedStep;
        });
      }
    } catch (e) {
      debugPrint('[OnboardingPage] Erro ao carregar dados existentes: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // AÇÕES DO PASSO 1 (ESCOLHA DO NICHO)
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _onSelectSector(ProductSector sector) async {
    setState(() {
      _selectedSector = sector;
      _currentStep = 2;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('taos_onboarding_step', 2);
    await prefs.setString('taos_onboarding_sector', sector.name);

    await SettingsService.savePreferredSector(sector, isFixed: true);
  }

  // Retorno ao passo anterior com persistência da etapa
  Future<void> _goToPreviousStep() async {
    if (_currentStep > 1) {
      final prev = _currentStep - 1;
      setState(() => _currentStep = prev);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('taos_onboarding_step', prev);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUSCA INTELIGENTE DE CNPJ (BRASILAPI)
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _searchCnpj() async {
    final rawCnpj = _cnpjCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (rawCnpj.length != 14) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Digite um CNPJ válido com 14 dígitos para buscar na Receita.'),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    _lastAutoSearchedCnpj = rawCnpj;
    _cnpjCtrl.text = CnpjInputFormatter.format(rawCnpj);
    setState(() => _isSearchingCnpj = true);

    try {
      final isTaken = await CompanyService.isCnpjAlreadyRegistered(
        rawCnpj,
        currentCompanyId: _companyId,
        currentUserId: FirebaseAuth.instance.currentUser?.uid,
      );
      if (isTaken && mounted) {
        setState(() => _isSearchingCnpj = false);
        _showCnpjAlreadyExistsAlert();
        return;
      }

      final data = await CnpjService.lookupCnpj(rawCnpj);
      if (!mounted) return;
      setState(() => _isSearchingCnpj = false);

      if (data == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('CNPJ não localizado na base pública ou serviço indisponível.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      _corporateNameCtrl.text = data.razaoSocial;
      _tradeNameCtrl.text = data.displayName;
      _nameCtrl.text = data.displayName;
      if (data.situacaoCadastral != null) {
        _statusCtrl.text = data.situacaoCadastral!.toUpperCase();
      }
      if (data.porte != null) _sizeCtrl.text = data.porte!.toUpperCase();
      if (data.cnaePrincipal != null) _mainCnaeCtrl.text = data.cnaePrincipal!;
      if (data.cnaesSecundarios != null) _secondaryCnaesCtrl.text = data.cnaesSecundarios!;
      if (data.email != null && data.email!.isNotEmpty) {
        _companyEmailCtrl.text = data.email!.toLowerCase();
        if (_commercialEmailCtrl.text.isEmpty) {
          _commercialEmailCtrl.text = data.email!.toLowerCase();
        }
      }
      if (data.phone != null && data.phone!.isNotEmpty) {
        _phoneCtrl.text = data.phone!;
      }

      if (data.zipCode != null && data.zipCode!.isNotEmpty) {
        _cepCtrl.text = CepInputFormatter.format(data.zipCode!);
      }
      if (data.street != null && data.street!.isNotEmpty) {
        _streetCtrl.text = data.street!;
      }
      if (data.number != null && data.number!.isNotEmpty) {
        _numberCtrl.text = data.number!;
      }
      if (data.complement != null && data.complement!.isNotEmpty) {
        _complementCtrl.text = data.complement!;
      }
      if (data.neighborhood != null && data.neighborhood!.isNotEmpty) {
        _neighborhoodCtrl.text = data.neighborhood!;
      }
      if (data.city != null && data.city!.isNotEmpty) {
        _cityCtrl.text = data.city!;
      }
      if (data.state != null && data.state!.isNotEmpty) {
        _stateCtrl.text = data.state!;
      }
      _addressLocked = true;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ficha Cadastral da empresa "${data.razaoSocial}" preenchida com sucesso!'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isSearchingCnpj = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao consultar CNPJ: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showCnpjAlreadyExistsAlert() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
            const SizedBox(width: 8),
            Text(
              'CNPJ Já Cadastrado',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 18),
            ),
          ],
        ),
        content: const Text(
          'Este CNPJ já está vinculado a outra empresa ou conta no sistema.\n\n'
          'Cada CNPJ é único por organização. Por favor, revise o número ou entre em contato com o suporte caso acredite ser um erro.',
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('CORRIGIR CNPJ'),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUSCA VIACEP
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _searchCep(String val) async {
    final clean = val.replaceAll(RegExp(r'\D'), '');
    if (clean.length != 8) return;

    setState(() => _isSearchingCep = true);
    try {
      final uri = Uri.parse('https://viacep.com.br/ws/$clean/json/');
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (!mounted) return;
      setState(() => _isSearchingCep = false);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (!data.containsKey('erro')) {
          setState(() {
            _streetCtrl.text = data['logradouro'] as String? ?? '';
            _neighborhoodCtrl.text = data['bairro'] as String? ?? '';
            _cityCtrl.text = data['localidade'] as String? ?? '';
            _stateCtrl.text = data['uf'] as String? ?? '';
            final comp = data['complemento'] as String? ?? '';
            if (comp.isNotEmpty && _complementCtrl.text.isEmpty) {
              _complementCtrl.text = comp;
            }
            _addressLocked = true;
          });
          _focusNumber.requestFocus();
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isSearchingCep = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _pickLogo() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
      );
      if (files.isNotEmpty) {
        final bytes = await files.first.readAsBytes();
        setState(() {
          _logoBase64 = base64Encode(bytes);
        });
      }
    } catch (e) {
      debugPrint('[OnboardingPage] Erro ao selecionar logomarca: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SALVAMENTO DA FICHA CADASTRAL (PASSO 2)
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _saveCompanyAndProceed() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, revise os campos obrigatórios em destaque.'),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    final rawCnpj = _cnpjCtrl.text.replaceAll(RegExp(r'\D'), '');
    final currentUser = FirebaseAuth.instance.currentUser;
    final effectiveCid = await CompanyService.getEffectiveCompanyId(_companyId);
    final cid = (effectiveCid != null && effectiveCid.isNotEmpty)
        ? effectiveCid
        : (currentUser?.uid ?? 'company_${DateTime.now().millisecondsSinceEpoch}');
    _companyId = cid;

    if (rawCnpj.length == 14) {
      final isTaken = await CompanyService.isCnpjAlreadyRegistered(
        rawCnpj,
        currentCompanyId: cid,
        currentUserId: currentUser?.uid,
      );
      if (isTaken && mounted) {
        _showCnpjAlreadyExistsAlert();
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();

      final company = CompanyModel(
        id: cid,
        name: _tradeNameCtrl.text.trim().isNotEmpty
            ? _tradeNameCtrl.text.trim()
            : (_corporateNameCtrl.text.trim().isNotEmpty ? _corporateNameCtrl.text.trim() : 'Minha Empresa'),
        corporateName: _corporateNameCtrl.text.trim().isNotEmpty ? _corporateNameCtrl.text.trim() : null,
        tradeName: _tradeNameCtrl.text.trim().isNotEmpty ? _tradeNameCtrl.text.trim() : null,
        document: _cnpjCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        email: _commercialEmailCtrl.text.trim().isNotEmpty ? _commercialEmailCtrl.text.trim() : null,
        companyEmail: _companyEmailCtrl.text.trim().isNotEmpty ? _companyEmailCtrl.text.trim() : null,
        registrationStatus: _statusCtrl.text.trim().isNotEmpty ? _statusCtrl.text.trim() : null,
        companySize: _sizeCtrl.text.trim().isNotEmpty ? _sizeCtrl.text.trim() : null,
        mainCnae: _mainCnaeCtrl.text.trim().isNotEmpty ? _mainCnaeCtrl.text.trim() : null,
        secondaryCnaes: _secondaryCnaesCtrl.text.trim().isNotEmpty ? _secondaryCnaesCtrl.text.trim() : null,
        website: _websiteCtrl.text.trim().isNotEmpty ? _websiteCtrl.text.trim() : null,
        instagram: _socialCtrl.text.trim().isNotEmpty ? _socialCtrl.text.trim() : null,
        slogan: _sloganCtrl.text.trim().isNotEmpty ? _sloganCtrl.text.trim() : null,
        sector: _selectedSector.name,
        logoBase64: _logoBase64,
        zipCode: _cepCtrl.text.trim().isNotEmpty ? _cepCtrl.text.trim() : null,
        street: _streetCtrl.text.trim().isNotEmpty ? _streetCtrl.text.trim() : null,
        number: _numberCtrl.text.trim().isNotEmpty ? _numberCtrl.text.trim() : null,
        complement: _complementCtrl.text.trim().isNotEmpty ? _complementCtrl.text.trim() : null,
        neighborhood: _neighborhoodCtrl.text.trim().isNotEmpty ? _neighborhoodCtrl.text.trim() : null,
        city: _cityCtrl.text.trim().isNotEmpty ? _cityCtrl.text.trim() : null,
        state: _stateCtrl.text.trim().isNotEmpty ? _stateCtrl.text.trim() : null,
        onboardingCompleted: false, // Efetivado somente no Passo 3 ao escolher o plano!
        createdAt: now,
        updatedAt: now,
      );

      await CompanyService.saveCompany(company);
      await SettingsService.savePreferredSector(_selectedSector, isFixed: true);
      await SettingsService.setCompletedOnboarding(false);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('taos_onboarding_step', 3);

      if (!mounted) return;
      setState(() => _isSaving = false);

      // Avança para o Passo 3
      setState(() => _currentStep = 3);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar dados da empresa: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _performFinishOnboarding() async {
    try {
      // 1. Salva prioritariamente no SharedPreferences local para transição instantânea
      await SettingsService.savePreferredSector(_selectedSector, isFixed: true);
      await SettingsService.setCompletedOnboarding(true);

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('taos_onboarding_step');
      await prefs.remove('taos_onboarding_sector');

      final auth = FirebaseAuth.instance;
      final uid = auth.currentUser?.uid;
      final cid = await CompanyService.getEffectiveCompanyId(_companyId);
      final effectiveId = (cid != null && cid.isNotEmpty) ? cid : uid;

      // 2. Grava no Firestore da empresa que o onboarding está concluído
      if (effectiveId != null && effectiveId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('companies').doc(effectiveId).set({
          'onboardingCompleted': true,
          'sector': _selectedSector.name,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // 3. Grava no Firestore do usuário
      if (uid != null && uid.isNotEmpty) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'onboardingCompleted': true,
          'sector': _selectedSector.name,
          'preferredSector': _selectedSector.name,
          'nicheChosen': true,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // 4. Notifica callback e fecha o diálogo
      if (widget.onCompleted != null) {
        widget.onCompleted!();
      } else if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    } catch (e) {
      debugPrint('[OnboardingPage] Erro ao finalizar onboarding: $e');
      if (widget.onCompleted != null) {
        widget.onCompleted!();
      } else if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    } finally {
      if (mounted) setState(() => _isFinishing = false);
    }
  }

  Future<void> _finishOnboarding() async {
    if (_isFinishing) return;
    setState(() => _isFinishing = true);
    await _performFinishOnboarding();
  }

  // Ativa o período de testes de 30 dias e entra no Dashboard
  Future<void> _startTrialAndEnterDashboard() async {
    if (_isFinishing) return;
    setState(() => _isFinishing = true);
    try {
      await SettingsService.setCompletedOnboarding(true);
      await SubscriptionService.startTrial(companyId: _companyId);
    } catch (e) {
      debugPrint('[OnboardingPage] Erro ao iniciar trial: $e');
    }
    await _performFinishOnboarding();
  }

  // Abre a tela modal de Checkout com PIX
  void _openPixCheckout() {
    PixCheckoutDialog.show(
      context,
      plan: _step3SelectedPlan,
      onSuccess: () {
        _finishOnboarding();
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD PRINCIPAL
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isDesktop = screenSize.width >= 1080;
    final topCutX = isDesktop ? (screenSize.width * 0.17).clamp(190.0, 260.0) : 0.0;
    final bottomCutX = isDesktop ? topCutX * 0.42 : 0.0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: _TechAngledArtBackground(
        topCutX: topCutX,
        bottomCutX: bottomCutX,
        child: SafeArea(
          child: Column(
            children: [
              // Header Superior: Logo TAOS deslocada para o início do painel branco (fiel à Imagem 2)
              _buildHeader(isDesktop, leftOffset: topCutX + 22),

              // Miolo Dinâmico por Passo (AnimatedSwitcher para transição fluida)
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  child: _currentStep == 1
                      ? _buildStep1NicheSelection(isDesktop)
                      : _currentStep == 2
                          ? _buildStep2CompanyForm(isDesktop)
                          : _buildStep3Ready(isDesktop),
                ),
              ),

              // Rodapé Institucional posicionado na área branca
              _buildFooter(isDesktop, leftOffset: bottomCutX + 26),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 1. HEADER SUPERIOR (POSIÇÃO EXATA DA IMAGEM 2)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildHeader(bool isDesktop, {double leftOffset = 48}) {
    return Container(
      padding: EdgeInsets.only(
        left: isDesktop ? leftOffset : 20,
        right: isDesktop ? 48 : 20,
        top: 10,
        bottom: 6,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logomarca Oficial TAOS (ícone + texto) + Botão de Voltar ao Passo Anterior
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_currentStep > 1) ...[
                Tooltip(
                  message: 'Voltar ao passo anterior',
                  child: InkWell(
                    onTap: _goToPreviousStep,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.arrow_back_rounded, size: 15, color: Color(0xFF0F172A)),
                          const SizedBox(width: 5),
                          Text(
                            'Voltar',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              Image.asset(
                'assets/images/taos_t_icon.png',
                height: 28,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.layers_rounded,
                  color: Color(0xFF0F172A),
                  size: 26,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'TAOS',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),

          // Indicador de Etapas (Passo X de 3) + Ajuda (?)
          OnboardingStepProgress(
            currentStep: _currentStep,
            totalSteps: _totalSteps,
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 2. PASSO 1: ESCOLHA DO NICHO (GRID DOS 4 CARDS)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildStep1NicheSelection(bool isDesktop) {
    return SingleChildScrollView(
      key: const ValueKey<int>(1),
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 48 : 20,
        vertical: 2,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1160),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Kicker Text
              Text(
                'B E M - V I N D O   A O   T A O S',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3.0,
                  color: const Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 6),

              // Main Title
              Text(
                'Vamos começar?',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: isDesktop ? 34 : 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.0,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),

              // Subtitles
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  children: [
                    Text(
                      'O TAOS é um CRM inteligente, feito para organizar seu negócio, aumentar suas vendas e simplificar sua operação.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w400,
                        height: 1.4,
                        color: const Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Para personalizar sua experiência, escolha o nicho principal que você vai operar:',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Os 4 Cards de Nicho com Micro-animações de Hover
              if (isDesktop)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OnboardingNicheCard(
                      title: 'Usinas Solares',
                      description: 'Gerencie propostas, projetos, clientes e todo o ciclo de vendas de energia solar.',
                      icon: Icons.solar_power_rounded,
                      iconBgColor: const Color(0xFFE0F2FE),
                      iconColor: const Color(0xFF0284C7),
                      imagePath: 'assets/images/onboarding/solar_card.jpg',
                      onTap: () => _onSelectSector(ProductSector.solarPlant),
                    ),
                    const SizedBox(width: 16),
                    OnboardingNicheCard(
                      title: 'Automação\nResidencial',
                      description: 'Controle seus projetos, clientes e orçamentos de automação residencial.',
                      icon: Icons.home_work_rounded,
                      iconBgColor: const Color(0xFFDCFCE7),
                      iconColor: const Color(0xFF16A34A),
                      imagePath: 'assets/images/onboarding/automation_card.jpg',
                      onTap: () => _onSelectSector(ProductSector.homeAutomation),
                    ),
                    const SizedBox(width: 16),
                    OnboardingNicheCard(
                      title: 'Móveis e\nDecorações',
                      description: 'Organize seus clientes, projetos e vendas de móveis e itens de decoração.',
                      icon: Icons.chair_rounded,
                      iconBgColor: const Color(0xFFFFEDD5),
                      iconColor: const Color(0xFFEA580C),
                      imagePath: 'assets/images/onboarding/furniture_card.jpg',
                      onTap: () => _onSelectSector(ProductSector.furniture),
                    ),
                    const SizedBox(width: 16),
                    OnboardingNicheCard(
                      title: 'Prestações de\nServiços Gerais',
                      description: 'Gerencie atendimentos, orçamentos e clientes de diversos serviços.',
                      icon: Icons.handyman_rounded,
                      iconBgColor: const Color(0xFFEDE9FE),
                      iconColor: const Color(0xFF7C3AED),
                      imagePath: 'assets/images/onboarding/services_card.jpg',
                      onTap: () => _onSelectSector(ProductSector.generalServices),
                    ),
                  ],
                )
              else
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: WrapAlignment.center,
                  children: [
                    OnboardingNicheCard(
                      title: 'Usinas Solares',
                      description: 'Gerencie propostas, projetos, clientes e todo o ciclo de vendas de energia solar.',
                      icon: Icons.solar_power_rounded,
                      iconBgColor: const Color(0xFFE0F2FE),
                      iconColor: const Color(0xFF0284C7),
                      imagePath: 'assets/images/onboarding/solar_card.jpg',
                      onTap: () => _onSelectSector(ProductSector.solarPlant),
                    ),
                    OnboardingNicheCard(
                      title: 'Automação\nResidencial',
                      description: 'Controle seus projetos, clientes e orçamentos de automação residencial.',
                      icon: Icons.home_work_rounded,
                      iconBgColor: const Color(0xFFDCFCE7),
                      iconColor: const Color(0xFF16A34A),
                      imagePath: 'assets/images/onboarding/automation_card.jpg',
                      onTap: () => _onSelectSector(ProductSector.homeAutomation),
                    ),
                    OnboardingNicheCard(
                      title: 'Móveis e\nDecorações',
                      description: 'Organize seus clientes, projetos e vendas de móveis e itens de decoração.',
                      icon: Icons.chair_rounded,
                      iconBgColor: const Color(0xFFFFEDD5),
                      iconColor: const Color(0xFFEA580C),
                      imagePath: 'assets/images/onboarding/furniture_card.jpg',
                      onTap: () => _onSelectSector(ProductSector.furniture),
                    ),
                    OnboardingNicheCard(
                      title: 'Prestações de\nServiços Gerais',
                      description: 'Gerencie atendimentos, orçamentos e clientes de diversos serviços.',
                      icon: Icons.handyman_rounded,
                      iconBgColor: const Color(0xFFEDE9FE),
                      iconColor: const Color(0xFF7C3AED),
                      imagePath: 'assets/images/onboarding/services_card.jpg',
                      onTap: () => _onSelectSector(ProductSector.generalServices),
                    ),
                  ],
                ),

              const SizedBox(height: 18),

              // Divisor com Texto
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(width: 70, height: 1, color: const Color(0xFFE2E8F0)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text(
                      'VOCÊ SEMPRE PODERÁ ALTERAR DEPOIS',
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2.0,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                  Container(width: 70, height: 1, color: const Color(0xFFE2E8F0)),
                ],
              ),

              const SizedBox(height: 10),

              // Selo de Segurança
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_rounded, size: 13, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 6),
                  Text(
                    'Seus dados estão seguros com a gente.',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 3. PASSO 2: FICHA CADASTRAL DA EMPRESA (TELA COMPLETA)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildStep2CompanyForm(bool isDesktop) {
    return SingleChildScrollView(
      key: const ValueKey<int>(2),
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 48 : 20,
        vertical: 16,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ação de Retorno ao Passo 1 (Escolha do Nicho)
                InkWell(
                  onTap: _goToPreviousStep,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.arrow_back_rounded, size: 16, color: Color(0xFF6366F1)),
                        const SizedBox(width: 6),
                        Text(
                          '← Voltar para o Passo 1 (Escolha do Nicho)',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF6366F1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Header do Passo 2
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.apartment_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Configuração da Empresa',
                                style: GoogleFonts.outfit(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFF59E0B)),
                                ),
                                child: Text(
                                  _selectedSector.title.toUpperCase(),
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFB45309),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Preencha os dados institucionais, fiscais e endereço para personalizar suas propostas, contratos e relatórios.',
                            style: GoogleFonts.inter(
                              fontSize: 13.5,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // Card 1: Ficha Cadastral da Empresa
                _buildFormSectionCard(
                  icon: Icons.badge_rounded,
                  title: '1. Ficha Cadastral da Empresa (Receita Federal)',
                  subtitle: 'Consulte pelo CNPJ para autocompletar 100% dos dados cadastrais',
                  children: [
                    // Linha CNPJ com Busca Automática
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: _buildTextField(
                            controller: _cnpjCtrl,
                            label: 'CNPJ da Empresa * (Auto-busca na Receita)',
                            hint: '00.000.000/0000-00',
                            keyboardType: TextInputType.number,
                            inputFormatters: [CnpjInputFormatter()],
                            onChanged: _onCnpjChanged,
                            prefixIcon: Icons.search_rounded,
                            suffix: _isSearchingCnpj
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : IconButton(
                                    icon: const Icon(Icons.search, color: Color(0xFF6366F1)),
                                    tooltip: 'Buscar na Receita Federal',
                                    onPressed: _searchCnpj,
                                  ),
                            onSubmitted: (_) => _searchCnpj(),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Informe o CNPJ da empresa';
                              final digits = v.replaceAll(RegExp(r'\D'), '');
                              if (digits.length != 14) return 'CNPJ incompleto (14 dígitos)';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            controller: _statusCtrl,
                            label: 'Situação Cadastral',
                            hint: 'ATIVA',
                            readOnly: true,
                            prefixIcon: Icons.verified_rounded,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            controller: _sizeCtrl,
                            label: 'Porte da Empresa',
                            hint: 'ME / EPP / DEMAIS',
                            prefixIcon: Icons.domain_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Razão Social e Nome Fantasia
                    if (isDesktop)
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _corporateNameCtrl,
                              label: 'Nome Empresarial / Razão Social *',
                              hint: 'Ex: RAZAO SOCIAL INDUSTRIA LTDA',
                              prefixIcon: Icons.business_rounded,
                              validator: (v) => v == null || v.trim().isEmpty ? 'Obrigatório' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              controller: _tradeNameCtrl,
                              label: 'Nome Fantasia *',
                              hint: 'Ex: NOME DA MARCA',
                              prefixIcon: Icons.storefront_rounded,
                            ),
                          ),
                        ],
                      )
                    else ...[
                      _buildTextField(
                        controller: _corporateNameCtrl,
                        label: 'Nome Empresarial / Razão Social *',
                        hint: 'Ex: RAZAO SOCIAL INDUSTRIA LTDA',
                        prefixIcon: Icons.business_rounded,
                        validator: (v) => v == null || v.trim().isEmpty ? 'Obrigatório' : null,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _tradeNameCtrl,
                        label: 'Nome Fantasia *',
                        hint: 'Ex: NOME DA MARCA',
                        prefixIcon: Icons.storefront_rounded,
                      ),
                    ],

                    const SizedBox(height: 16),

                    // CNAE Principal
                    _buildTextField(
                      controller: _mainCnaeCtrl,
                      label: 'Código e Atividade Econômica Principal (CNAE Principal)',
                      hint: 'Ex: 25.39-0-01 - Serviços de usinagem, tornearia e solda',
                      prefixIcon: Icons.account_tree_rounded,
                    ),

                    const SizedBox(height: 16),

                    // CNAEs Secundários
                    _buildTextField(
                      controller: _secondaryCnaesCtrl,
                      label: 'Atividades Econômicas Secundárias (CNAEs)',
                      hint: 'Lista de CNAEs secundários...',
                      maxLines: 2,
                      prefixIcon: Icons.format_list_bulleted_rounded,
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Card 2: Contatos e Imagem Institucional
                _buildFormSectionCard(
                  icon: Icons.contact_mail_rounded,
                  title: '2. Canais de Contato & Identidade Visual',
                  subtitle: 'Informações exibidas no cabeçalho das propostas e contratos emitidos',
                  children: [
                    if (isDesktop)
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _companyEmailCtrl,
                              label: 'E-mail Empresarial (Registrado no CNPJ)',
                              hint: 'fiscal@empresa.com.br',
                              prefixIcon: Icons.alternate_email_rounded,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              controller: _commercialEmailCtrl,
                              label: 'E-mail Comercial (Propostas & PDFs) *',
                              hint: 'contato@empresa.com.br',
                              prefixIcon: Icons.email_rounded,
                              validator: (v) => v == null || v.trim().isEmpty ? 'Obrigatório' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              controller: _phoneCtrl,
                              label: 'Telefone / WhatsApp Comercial *',
                              hint: '(00) 00000-0000',
                              prefixIcon: Icons.phone_rounded,
                              validator: (v) => v == null || v.trim().isEmpty ? 'Obrigatório' : null,
                            ),
                          ),
                        ],
                      )
                    else ...[
                      _buildTextField(
                        controller: _companyEmailCtrl,
                        label: 'E-mail Empresarial (Registrado no CNPJ)',
                        hint: 'fiscal@empresa.com.br',
                        prefixIcon: Icons.alternate_email_rounded,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _commercialEmailCtrl,
                        label: 'E-mail Comercial (Propostas & PDFs) *',
                        hint: 'contato@empresa.com.br',
                        prefixIcon: Icons.email_rounded,
                        validator: (v) => v == null || v.trim().isEmpty ? 'Obrigatório' : null,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _phoneCtrl,
                        label: 'Telefone / WhatsApp Comercial *',
                        hint: '(00) 00000-0000',
                        prefixIcon: Icons.phone_rounded,
                        validator: (v) => v == null || v.trim().isEmpty ? 'Obrigatório' : null,
                      ),
                    ],

                    const SizedBox(height: 16),

                    if (isDesktop)
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _websiteCtrl,
                              label: 'Site Oficial',
                              hint: 'www.empresa.com.br',
                              prefixIcon: Icons.language_rounded,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              controller: _socialCtrl,
                              label: 'Instagram / Redes',
                              hint: '@empresa',
                              prefixIcon: Icons.camera_alt_rounded,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              controller: _sloganCtrl,
                              label: 'Slogan / Frase de Impacto',
                              hint: 'Ex: Energia que Transforma o Futuro',
                              prefixIcon: Icons.auto_awesome_rounded,
                            ),
                          ),
                        ],
                      )
                    else ...[
                      _buildTextField(
                        controller: _websiteCtrl,
                        label: 'Site Oficial',
                        hint: 'www.empresa.com.br',
                        prefixIcon: Icons.language_rounded,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _socialCtrl,
                        label: 'Instagram / Redes',
                        hint: '@empresa',
                        prefixIcon: Icons.camera_alt_rounded,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _sloganCtrl,
                        label: 'Slogan / Frase de Impacto',
                        hint: 'Ex: Energia que Transforma o Futuro',
                        prefixIcon: Icons.auto_awesome_rounded,
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Logomarca
                    Row(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: _logoBase64 != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(11),
                                  child: Image.memory(
                                    base64Decode(_logoBase64!.split(',').last),
                                    fit: BoxFit.contain,
                                  ),
                                )
                              : const Center(
                                  child: Icon(Icons.image_outlined, color: Color(0xFF94A3B8), size: 32),
                                ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Logomarca da Empresa',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'PNG ou JPG com fundo transparente recomendado (máx. 2MB)',
                              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: _pickLogo,
                              icon: const Icon(Icons.upload_rounded, size: 16),
                              label: Text(_logoBase64 == null ? 'ENVIAR LOGO' : 'ALTERAR LOGO'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Card 3: Endereço Completo
                _buildFormSectionCard(
                  icon: Icons.location_on_rounded,
                  title: '3. Endereço Completo da Empresa',
                  subtitle: 'Autocompletado via CNPJ ou CEP (ViaCEP)',
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 220,
                          child: _buildTextField(
                            controller: _cepCtrl,
                            label: 'CEP (8 dígitos)',
                            hint: '00000-000',
                            keyboardType: TextInputType.number,
                            inputFormatters: [CepInputFormatter()],
                            prefixIcon: Icons.search_rounded,
                            onChanged: _searchCep,
                            suffix: _isSearchingCep
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        TextButton.icon(
                          onPressed: () => setState(() => _addressLocked = !_addressLocked),
                          icon: Icon(
                            _addressLocked ? Icons.lock_outline_rounded : Icons.lock_open_rounded,
                            size: 16,
                          ),
                          label: Text(_addressLocked ? 'Editar campos' : 'Bloquear campos'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: _buildTextField(
                            controller: _streetCtrl,
                            label: 'Logradouro / Rua',
                            hint: 'Ex: Av. Paulista',
                            readOnly: _addressLocked,
                          ),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 140,
                          child: _buildTextField(
                            controller: _numberCtrl,
                            focusNode: _focusNumber,
                            label: 'Número',
                            hint: '1000',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _complementCtrl,
                            label: 'Complemento',
                            hint: 'Sala 101, Bloco B',
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            controller: _neighborhoodCtrl,
                            label: 'Bairro',
                            hint: 'Centro',
                            readOnly: _addressLocked,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            controller: _cityCtrl,
                            label: 'Cidade',
                            hint: 'São Paulo',
                            readOnly: _addressLocked,
                          ),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 90,
                          child: _buildTextField(
                            controller: _stateCtrl,
                            label: 'UF',
                            hint: 'SP',
                            readOnly: _addressLocked,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Botões de Ação do Passo 2
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: _goToPreviousStep,
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: Text(
                        'VOLTAR AO NICHO',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                      ),
                      onPressed: _isSaving ? null : _saveCompanyAndProceed,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.check_circle_rounded, size: 20),
                      label: Text(
                        _isSaving ? 'SALVANDO DADOS...' : 'CONCLUIR E AVANÇAR 🚀',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 4. PASSO 3: PÁGINA COMERCIAL DE PLANOS (ASSINAR PIX vs 30 DIAS GRÁTIS)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildStep3Ready(bool isDesktop) {
    final isMonthly = _step3SelectedPlan == SubscriptionPlan.monthly;

    return SingleChildScrollView(
      key: const ValueKey<int>(3),
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 48 : 20,
        vertical: 16,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Badge de Sucesso de Cadastro
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'EMPRESA CONFIGURADA COM SUCESSO',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        color: const Color(0xFF065F46),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              Text(
                'Escolha como deseja iniciar no TAOS',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: isDesktop ? 30 : 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: const Color(0xFF0F172A),
                ),
              ),

              const SizedBox(height: 8),

              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Text(
                  'Acesso personalizado para o nicho de "${_selectedSector.title}". Comece a acelerar suas vendas hoje mesmo assinando o Plano Pro ou aproveite 30 dias de degustação grátis.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    height: 1.5,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Grade com as 2 Opções Comerciais (Mesma Altura via IntrinsicHeight)
              if (isDesktop)
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _buildPlanProCard(isMonthly)),
                      const SizedBox(width: 24),
                      Expanded(child: _buildTrialCard()),
                    ],
                  ),
                )
              else
                Column(
                  children: [
                    _buildPlanProCard(isMonthly),
                    const SizedBox(height: 24),
                    _buildTrialCard(),
                  ],
                ),

              const SizedBox(height: 24),

              // Ação de Voltar
              TextButton.icon(
                onPressed: _goToPreviousStep,
                icon: const Icon(Icons.arrow_back_rounded, size: 16, color: Color(0xFF64748B)),
                label: Text(
                  'Voltar e revisar ficha cadastral da empresa',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Selo de Segurança & Pagar.me
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_rounded, size: 13, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 6),
                  Text(
                    'Pagamentos protegidos via Pagar.me Gateway • Cancele quando quiser • Sem fidelidade',
                    style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF94A3B8)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlanProCard(bool isMonthly) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF030D1A),
            Color(0xFF08182D),
            Color(0xFF040E1C),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF0284C7).withValues(alpha: 0.85),
          width: 1.8,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withValues(alpha: 0.22),
            blurRadius: 28,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Linha de Badges Superiores
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  // RECOMENDADO badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF38BDF8), width: 1),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 13, color: Color(0xFFFBBF24)),
                        const SizedBox(width: 4),
                        Text(
                          'RECOMENDADO',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // ACESSO TOTAL PRO badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F243E),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF1E3A5F), width: 1),
                    ),
                    child: Text(
                      'ACESSO TOTAL PRO',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                ],
              ),
              // Pague com PIX badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF062A32),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF0D9488), width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.pix_rounded, size: 13, color: Color(0xFF2DD4BF)),
                    const SizedBox(width: 4),
                    Text(
                      'Pague com PIX',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF2DD4BF),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Título
          Text(
            'Plano TAOS PRO',
            style: GoogleFonts.outfit(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Para empresas que querem acelerar vendas, propostas e fechar contratos sem limites.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF94A3B8),
              height: 1.4,
            ),
          ),

          const SizedBox(height: 18),

          // Alternador de Frequência (Mensal vs Semestral)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF051326),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF0E274A)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _step3SelectedPlan = SubscriptionPlan.monthly),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        gradient: isMonthly
                            ? const LinearGradient(
                                colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
                              )
                            : null,
                        color: isMonthly ? null : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: isMonthly
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF0EA5E9).withValues(alpha: 0.3),
                                  blurRadius: 8,
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          'MENSAL',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: isMonthly ? Colors.white : const Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _step3SelectedPlan = SubscriptionPlan.semiannual),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        gradient: !isMonthly
                            ? const LinearGradient(
                                colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
                              )
                            : null,
                        color: !isMonthly ? null : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: !isMonthly
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF0EA5E9).withValues(alpha: 0.3),
                                  blurRadius: 8,
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'SEMESTRAL',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: !isMonthly ? Colors.white : const Color(0xFF94A3B8),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5)),
                            ),
                            child: Text(
                              '-24%',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF34D399),
                              ),
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

          // Preço
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                isMonthly ? 'R\$ 99,00' : 'R\$ 450,00',
                style: GoogleFonts.outfit(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isMonthly ? '/ mês via PIX' : 'por 6 meses (R\$ 75/mês)',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Bullets de Recursos com Gráfico Mini 3D Monitor
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFuturisticFeatureRow('Usinas Solares, Kits e Produtos ilimitados', isPro: true),
                    _buildFuturisticFeatureRow('Emissão de Propostas comerciais em PDF personalizadas', isPro: true),
                    _buildFuturisticFeatureRow('Emissão e Assinatura de Contratos com IA', isPro: true),
                    _buildFuturisticFeatureRow('OCR inteligente para faturas de energia e orçamentos', isPro: true),
                    _buildFuturisticFeatureRow('Suporte VIP e atualizações prioritárias', isPro: true),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _build3DMonitorGraphic(),
            ],
          ),

          const Spacer(),
          const SizedBox(height: 20),

          // Botão Assinar
          Container(
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0EA5E9).withValues(alpha: 0.4),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _openPixCheckout,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'ASSINAR PLANO PRO >',
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrialCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF030D1A),
            Color(0xFF08182D),
            Color(0xFF040E1C),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF0284C7).withValues(alpha: 0.85),
          width: 1.8,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withValues(alpha: 0.22),
            blurRadius: 28,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Row: Title + SEM CARTÃO
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Degustação 30 Dias',
                style: GoogleFonts.outfit(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F243E),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF1E3A5F), width: 1),
                ),
                child: Text(
                  'SEM CARTÃO',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),
          Text(
            'Aproveite 30 dias de acesso gratuito para conhecer e testar todo o ecossistema na sua empresa.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF94A3B8),
              height: 1.4,
            ),
          ),

          const SizedBox(height: 24),

          // Preço R$ 0,00
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'R\$ 0,00',
                style: GoogleFonts.outfit(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF00E599),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'por 30 dias de acesso total',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Bullets de Recursos
          _buildFuturisticFeatureRow('Acesso completo a todas as funções por 30 dias', isPro: false),
          _buildFuturisticFeatureRow('Cadastre clientes, produtos e monte usinas', isPro: false),
          _buildFuturisticFeatureRow('Emita orçamentos reais para seus clientes', isPro: false),
          _buildFuturisticFeatureRow('Contador de dias no painel para assinar quando quiser', isPro: false),
          _buildFuturisticFeatureRow('Sem compromisso e sem cobranças automáticas', isPro: false),

          const Spacer(),
          const SizedBox(height: 20),

          // Botão Usar Grátis
          Container(
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00E599), Color(0xFF059669)],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00E599).withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _isFinishing ? null : _startTrialAndEnterDashboard,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              child: _isFinishing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'USAR GRÁTIS POR 30 DIAS >',
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFuturisticFeatureRow(String text, {required bool isPro}) {
    final checkColor = isPro ? const Color(0xFF0EA5E9) : const Color(0xFF00E599);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_rounded, size: 17, color: checkColor),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 12.8,
                fontWeight: FontWeight.w500,
                color: const Color(0xFFE2E8F0),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _build3DMonitorGraphic() {
    return Container(
      width: 120,
      height: 95,
      decoration: BoxDecoration(
        color: const Color(0xFF071B36),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF0EA5E9).withValues(alpha: 0.6), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0EA5E9).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 4, height: 4, decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle)),
              const SizedBox(width: 3),
              Container(width: 4, height: 4, decoration: const BoxDecoration(color: Color(0xFFFBBF24), shape: BoxShape.circle)),
              const SizedBox(width: 3),
              Container(width: 4, height: 4, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
              const Spacer(),
              Container(width: 16, height: 4, decoration: BoxDecoration(color: const Color(0xFF0EA5E9).withValues(alpha: 0.5), borderRadius: BorderRadius.circular(2))),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 18,
                  decoration: BoxDecoration(color: const Color(0xFF0C2950), borderRadius: BorderRadius.circular(4)),
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                  child: Row(
                    children: [
                      Container(width: 5, height: 5, decoration: const BoxDecoration(color: Color(0xFF38BDF8), shape: BoxShape.circle)),
                      const SizedBox(width: 3),
                      Expanded(child: Container(height: 3, color: const Color(0xFF64748B))),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Container(
                  height: 18,
                  decoration: BoxDecoration(color: const Color(0xFF0C2950), borderRadius: BorderRadius.circular(4)),
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                  child: Row(
                    children: [
                      Container(width: 5, height: 5, decoration: const BoxDecoration(color: Color(0xFF34D399), shape: BoxShape.circle)),
                      const SizedBox(width: 3),
                      Expanded(child: Container(height: 3, color: const Color(0xFF64748B))),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(width: 7, height: 12, decoration: BoxDecoration(color: const Color(0xFF0284C7), borderRadius: BorderRadius.circular(2))),
              Container(width: 7, height: 22, decoration: BoxDecoration(color: const Color(0xFF0EA5E9), borderRadius: BorderRadius.circular(2))),
              Container(width: 7, height: 16, decoration: BoxDecoration(color: const Color(0xFF38BDF8), borderRadius: BorderRadius.circular(2))),
              Container(width: 7, height: 28, decoration: BoxDecoration(color: const Color(0xFF60A5FA), borderRadius: BorderRadius.circular(2))),
              Container(width: 7, height: 36, decoration: BoxDecoration(color: const Color(0xFF00E599), borderRadius: BorderRadius.circular(2))),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 5. RODAPÉ INSTITUCIONAL (REFERÊNCIA DO MOCKUP)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildFooter(bool isDesktop, {double leftOffset = 48}) {
    return Container(
      padding: EdgeInsets.only(
        left: isDesktop ? leftOffset : 20,
        right: isDesktop ? 48 : 20,
        top: 8,
        bottom: 8,
      ),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFFF1F5F9), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Esquerda: TAOS | Technology • AI • Operations • Sales
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'TAOS',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 14),
              Container(width: 1, height: 14, color: const Color(0xFFCBD5E1)),
              const SizedBox(width: 14),
              Text(
                'Technology  •  AI  •  Operations  •  Sales',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),

          // Direita: Mais negócios. Menos complexidade.
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Mais negócios.',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF94A3B8),
                ),
              ),
              Text(
                'Menos complexidade.',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS DE UI
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildFormSectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFF0F172A)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    IconData? prefixIcon,
    Widget? suffix,
    bool readOnly = false,
    int maxLines = 1,
    FocusNode? focusNode,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
    FormFieldValidator<String>? validator,
    List<TextInputFormatter>? inputFormatters,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          maxLines: maxLines,
          focusNode: focusNode,
          onChanged: onChanged,
          onFieldSubmitted: onSubmitted,
          validator: validator,
          inputFormatters: inputFormatters,
          keyboardType: keyboardType,
          style: GoogleFonts.inter(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: readOnly ? const Color(0xFF64748B) : const Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
            filled: true,
            fillColor: readOnly ? const Color(0xFFF8FAFC) : Colors.white,
            prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 18, color: const Color(0xFF64748B)) : null,
            suffixIcon: suffix,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

/// Fundo em camadas artísticas com foto escura real e sombras suaves (fiel à Imagem 2)
class _TechAngledArtBackground extends StatelessWidget {
  final double topCutX;
  final double bottomCutX;
  final Widget child;

  const _TechAngledArtBackground({
    required this.topCutX,
    required this.bottomCutX,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (topCutX <= 0) {
      return Container(color: Colors.white, child: child);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── CAMADA 1: Imagem Escura Tecnológica na Lateral Esquerda ──
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: topCutX + 160,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Fundo escuro base
              Container(color: const Color(0xFF0B132B)),

              // Fotografia tecnológica real (carregamento instantâneo via memória)
              Image.memory(
                base64Decode(kDarkTechBgBase64),
                fit: BoxFit.cover,
                alignment: Alignment.centerLeft,
                errorBuilder: (ctx, err, stack) => Image.asset(
                  'assets/images/onboarding/dark_tech_bg.jpg',
                  fit: BoxFit.cover,
                  alignment: Alignment.centerLeft,
                ),
              ),

              // Overlay de profundidade e contraste
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.black.withValues(alpha: 0.15),
                      const Color(0xFF0B132B).withValues(alpha: 0.35),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── CAMADAS 2 & 3: Fita Geométrica Translúcida + Painel Branco Principal com Sombra Suave ──
        Positioned.fill(
          child: CustomPaint(
            painter: _ArtLayeredShadowPainter(
              topCutX: topCutX,
              bottomCutX: bottomCutX,
            ),
          ),
        ),

        // Conteúdo da aplicação
        child,
      ],
    );
  }
}

/// Pintor das camadas de arte geométrica com sombras suaves (fiel à Imagem 2)
/// Silhueta com linhas retas e vértices/pontas baulados (curvas suaves nos cantos)
class _ArtLayeredShadowPainter extends CustomPainter {
  final double topCutX;
  final double bottomCutX;

  _ArtLayeredShadowPainter({
    required this.topCutX,
    required this.bottomCutX,
  });

  /// Gera a linha de contorno: reta contínua com curvatura matematicamente tangente e harmônica (sem quebras)
  Path _buildBeveledContour(Size size, {double offsetX = 0}) {
    final h = size.height;
    final tX = topCutX + offsetX;
    final bX = bottomCutX + offsetX;

    final vx = bX - tX;
    final vy = h;
    final len = math.sqrt(vx * vx + vy * vy);
    final ux = vx / len;
    final uy = vy / len;

    const d = 32.0; // raio harmônico de transição contínua

    final path = Path();
    // 1. Início na borda superior horizontal
    path.moveTo(tX - d, 0);

    // 2. Curva harmônica tangente: vértice em (tX, 0), une a horizontal à diagonal sem nenhuma dobra
    path.quadraticBezierTo(tX, 0, tX + d * ux, d * uy);

    // 3. Linha 100% RETA descendo em diagonal ao longo do vetor
    path.lineTo(bX - d * ux, h - d * uy);

    // 4. Curva harmônica tangente na base: vértice em (bX, h), une a diagonal à horizontal perfeitamente
    path.quadraticBezierTo(bX, h, bX - d, h);

    return path;
  }

  /// Gera a fita intermediária translúcida perfeitamente paralela e com curvas harmônicas
  Path _buildRibbonPath(Size size, double ribbonWidth) {
    final h = size.height;
    final rtX = topCutX;
    final rbX = bottomCutX;

    final ltX = topCutX - ribbonWidth;
    final lbX = bottomCutX - ribbonWidth;

    final vx = rbX - rtX;
    final vy = h;
    final len = math.sqrt(vx * vx + vy * vy);
    final ux = vx / len;
    final uy = vy / len;

    const d = 32.0;

    final path = Path();
    // Borda esquerda (descendo: topo baulado harmônico -> reta -> base baulada)
    path.moveTo(ltX - d, 0);
    path.quadraticBezierTo(ltX, 0, ltX + d * ux, d * uy);
    path.lineTo(lbX - d * ux, h - d * uy);
    path.quadraticBezierTo(lbX, h, lbX - d, h);

    // Conexão na base
    path.lineTo(rbX - d, h);

    // Borda direita (subindo em sentido inverso: base baulada -> reta -> topo baulado)
    path.quadraticBezierTo(rbX, h, rbX - d * ux, h - d * uy);
    path.lineTo(rtX + d * ux, d * uy);
    path.quadraticBezierTo(rtX, 0, rtX - d, 0);

    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (topCutX <= 0) {
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = Colors.white);
      return;
    }

    // ── CAMADA 2: Lâmina Translúcida Geometria Prata / Gelo (Fita Intermediária) ──
    const ribbonWidth = 28.0;
    final ribbonPath = _buildRibbonPath(size, ribbonWidth);

    // Sombra suave da fita intermediária sobre a imagem escura
    canvas.drawShadow(
      ribbonPath,
      const Color(0xFF0F172A).withValues(alpha: 0.30),
      10.0,
      true,
    );

    // Pintura da fita translúcida em tom gelo / prateado suave
    final ribbonPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF94A3B8).withValues(alpha: 0.55),
          const Color(0xFFCBD5E1).withValues(alpha: 0.50),
          const Color(0xFFE2E8F0).withValues(alpha: 0.40),
        ],
      ).createShader(Rect.fromLTWH(topCutX - ribbonWidth - 40, 0, ribbonWidth + 120, size.height));

    canvas.drawPath(ribbonPath, ribbonPaint);

    // ── CAMADA 3: Painel Branco Principal com Sombra Suave e Profunda ──
    final contour = _buildBeveledContour(size, offsetX: 0);
    final whitePath = Path.from(contour)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width, 0)
      ..close();

    // Sombra suave e difusa projetada sobre a fita e a foto escura
    canvas.drawShadow(
      whitePath,
      const Color(0xFF0F172A).withValues(alpha: 0.35),
      18.0,
      true,
    );

    // Preenchimento branco puro do painel principal
    final whitePaint = Paint()..color = Colors.white;
    canvas.drawPath(whitePath, whitePaint);

    // Linha sutil de transição tecnológica no corte (linhas retas bauladas nas pontas)
    final linePaint = Paint()
      ..color = const Color(0xFFCBD5E1).withValues(alpha: 0.7)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    canvas.drawPath(contour, linePaint);
  }

  @override
  bool shouldRepaint(covariant _ArtLayeredShadowPainter oldDelegate) {
    return oldDelegate.topCutX != topCutX || oldDelegate.bottomCutX != bottomCutX;
  }
}

/// Formatador de máscara em tempo real para CNPJ: 00.000.000/0000-00
class CnpjInputFormatter extends TextInputFormatter {
  static String format(String raw) {
    var text = raw.replaceAll(RegExp(r'\D'), '');
    if (text.length > 14) text = text.substring(0, 14);
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i == 2 || i == 5) buffer.write('.');
      if (i == 8) buffer.write('/');
      if (i == 12) buffer.write('-');
      buffer.write(text[i]);
    }
    return buffer.toString();
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = format(newValue.text);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Formatador de máscara em tempo real para CEP: 00000-000
class CepInputFormatter extends TextInputFormatter {
  static String format(String raw) {
    var text = raw.replaceAll(RegExp(r'\D'), '');
    if (text.length > 8) text = text.substring(0, 8);
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i == 5) buffer.write('-');
      buffer.write(text[i]);
    }
    return buffer.toString();
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = format(newValue.text);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

