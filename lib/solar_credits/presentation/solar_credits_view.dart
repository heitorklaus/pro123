import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../auth/domain/models/user_model.dart';
import '../data/repositories/solar_credit_repository.dart';
import '../data/services/gemini_gd_bill_explosion_service.dart';
import '../data/services/solar_credit_boleto_pdf_service.dart';
import '../domain/models/solar_credit_models.dart';
import 'widgets/solar_credit_analytics_tab.dart';
import 'widgets/solar_credit_forms_dialogs.dart';

class SolarCreditsView extends StatefulWidget {
  final UserModel? currentUser;

  const SolarCreditsView({
    super.key,
    this.currentUser,
  });

  @override
  State<SolarCreditsView> createState() => _SolarCreditsViewState();
}

class _SolarCreditsViewState extends State<SolarCreditsView> {
  final SolarCreditRepository _repository = SolarCreditRepository();
  final _currencyFmt =
      NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  final _numFmt = NumberFormat('#,##0', 'pt_BR');
  final _decFmt = NumberFormat('#,##0.00', 'pt_BR');

  int _activeTabIndex = 0; // 0: IA Rápido | 1: Gráficos & Rateio | 2: Clientes/UCs | 3: Usinas & Faturas

  // Estado da Aba 0 (Explosão IA & Lançamento Rápido)
  bool _isAnalyzingPdf = false;
  String? _uploadedFileName;
  ExplodedGdEnergyBill? _explodedBill;
  SolarCreditBeneficiaryModel? _selectedBeneficiary;
  SolarGeneratorPlantModel? _selectedPlant;
  SolarCreditBillModel? _editingBill;

  // Controllers do Lançamento
  final _refMonthCtrl = TextEditingController(text: 'Outubro / 2026');
  final _dueDateCtrl = TextEditingController(text: '03/11/2026');
  final _ucNumberCtrl = TextEditingController();
  final _addressStreetCtrl = TextEditingController();
  final _holderNameCtrl = TextEditingController(
    text: 'HEITOR FABRICIO KLAUS DE OLIVEIRA',
  );
  final _allocationPercentCtrl = TextEditingController(text: '10,00');
  final _discountPercentCtrl = TextEditingController(text: '20,0');

  // Energia e Valores da Conta
  final _consumptionKwhCtrl = TextEditingController(text: '0');
  final _consumptionRsCtrl = TextEditingController(text: '0,00');
  final _injectedGdiKwhCtrl = TextEditingController(text: '0');
  final _injectedGdiRsCtrl = TextEditingController(text: '0,00');
  final _injectedGdiiKwhCtrl = TextEditingController(text: '0');
  final _injectedGdiiRsCtrl = TextEditingController(text: '0,00');
  final _gdAdjustmentKwhCtrl = TextEditingController(text: '0');
  final _gdAdjustmentRsCtrl = TextEditingController(text: '0,00');
  final _publicLightingRsCtrl = TextEditingController(text: '0,00');
  final _finesAndInterestRsCtrl = TextEditingController(text: '0,00');
  final _utilityTotalToPayRsCtrl = TextEditingController(text: '0,00');
  final _accumulatedBalanceKwhCtrl = TextEditingController(text: '0');

  // Campos de Fechamento Solar 7 (Permite ajuste fino / arredondamento se desejar)
  final _customSolarAmountCtrl = TextEditingController();
  bool _useCustomSolarAmount = false;

  // Campos Opcionais de Pagamento (QR Code e Link no Boleto)
  String? _qrCodeImageBase64;
  String? _qrCodeFileName;
  final _paymentLinkCtrl = TextEditingController();
  final _pixCopyPasteCtrl = TextEditingController();

  List<InjectedEnergyLineItem> _injectedLines = [];
  List<MonthlyConsumptionHistoryItem> _consumptionHistory = [];
  String _ucGdClassification = 'GD_II, conforme Lei 14.300/22';
  bool _isSavingBill = false;

  // Busca e agrupamento nas abas CRUD
  final _clientSearchCtrl = TextEditingController();
  final _billSearchCtrl = TextEditingController();
  bool _groupClientsByPlant = true;
  String _selectedClientPlantFilter = 'all';
  final Set<String> _collapsedPlantGroupKeys = {};

  String get _companyId =>
      widget.currentUser?.effectiveCompanyId ?? 'default_company';

  @override
  void dispose() {
    _refMonthCtrl.dispose();
    _dueDateCtrl.dispose();
    _ucNumberCtrl.dispose();
    _addressStreetCtrl.dispose();
    _holderNameCtrl.dispose();
    _allocationPercentCtrl.dispose();
    _discountPercentCtrl.dispose();
    _consumptionKwhCtrl.dispose();
    _consumptionRsCtrl.dispose();
    _injectedGdiKwhCtrl.dispose();
    _injectedGdiRsCtrl.dispose();
    _injectedGdiiKwhCtrl.dispose();
    _injectedGdiiRsCtrl.dispose();
    _gdAdjustmentKwhCtrl.dispose();
    _gdAdjustmentRsCtrl.dispose();
    _publicLightingRsCtrl.dispose();
    _finesAndInterestRsCtrl.dispose();
    _utilityTotalToPayRsCtrl.dispose();
    _accumulatedBalanceKwhCtrl.dispose();
    _customSolarAmountCtrl.dispose();
    _paymentLinkCtrl.dispose();
    _pixCopyPasteCtrl.dispose();
    _clientSearchCtrl.dispose();
    _billSearchCtrl.dispose();
    super.dispose();
  }

  double _parseNum(String text) {
    final clean = text
        .replaceAll('R\$', '')
        .replaceAll('%', '')
        .replaceAll('kWh', '')
        .trim();
    if (clean.isEmpty) return 0.0;
    if (clean.contains(',') && clean.contains('.')) {
      return double.tryParse(
            clean.replaceAll('.', '').replaceAll(',', '.'),
          ) ??
          0.0;
    }
    if (clean.contains(',')) {
      return double.tryParse(clean.replaceAll(',', '.')) ?? 0.0;
    }
    return double.tryParse(clean) ?? 0.0;
  }

  String _fmtDec(double val) => _decFmt.format(val);

  // ── CÁLCULOS EM TEMPO REAL DO LANÇAMENTO (OPÇÃO A) ─────────────────────────
  double get _totalInjectedKwh =>
      _parseNum(_injectedGdiKwhCtrl.text) +
      _parseNum(_injectedGdiiKwhCtrl.text);

  double get _totalInjectedGrossRs =>
      _parseNum(_injectedGdiRsCtrl.text) +
      _parseNum(_injectedGdiiRsCtrl.text);

  double get _gdAdjustmentRs => _parseNum(_gdAdjustmentRsCtrl.text);

  double get _netCompensatedCreditRs =>
      (_totalInjectedGrossRs - _gdAdjustmentRs).clamp(0.0, double.infinity);

  double get _clientDiscountPercent {
    double v = _parseNum(_discountPercentCtrl.text).abs();
    while (v > 100.0) {
      v = v / 10.0;
    }
    return v.clamp(0.0, 100.0);
  }

  double get _calculatedSolarCompanyAmountRs =>
      _netCompensatedCreditRs * (1.0 - (_clientDiscountPercent / 100.0));

  double get _effectiveSolarCompanyAmountRs {
    if (_useCustomSolarAmount && _customSolarAmountCtrl.text.trim().isNotEmpty) {
      return _parseNum(_customSolarAmountCtrl.text);
    }
    return _calculatedSolarCompanyAmountRs;
  }

  double get _utilityTotalToPayRs => _parseNum(_utilityTotalToPayRsCtrl.text);

  double get _totalWithSolarCompanyRs =>
      _effectiveSolarCompanyAmountRs + _utilityTotalToPayRs;

  double get _totalWithoutSolarCompanyRs {
    final byNet = _utilityTotalToPayRs + _netCompensatedCreditRs;
    if (byNet > 0) return byNet;
    final consRs = _parseNum(_consumptionRsCtrl.text);
    final ilumRs = _parseNum(_publicLightingRsCtrl.text);
    final finesRs = _parseNum(_finesAndInterestRsCtrl.text);
    return consRs + ilumRs + finesRs;
  }

  double get _monthlySavingsRs =>
      (_totalWithoutSolarCompanyRs - _totalWithSolarCompanyRs)
          .clamp(0.0, double.infinity);

  double get _annualProjectedSavingsRs => _monthlySavingsRs * 12.0;

  void _applyBeneficiaryToForm(
    SolarCreditBeneficiaryModel b,
    List<SolarGeneratorPlantModel> plants,
  ) {
    setState(() {
      _selectedBeneficiary = b;
      _ucNumberCtrl.text = b.ucNumber;
      _addressStreetCtrl.text = b.addressStreet;
      _holderNameCtrl.text = b.accountHolderName;
      _allocationPercentCtrl.text = _fmtDec(b.utilityAllocationPercent);
      _discountPercentCtrl.text = _fmtDec(b.clientDiscountPercent);
      if (_accumulatedBalanceKwhCtrl.text == '0' &&
          b.lastAccumulatedBalanceKwh > 0) {
        _accumulatedBalanceKwhCtrl.text =
            b.lastAccumulatedBalanceKwh.toStringAsFixed(0);
      }
      _selectedPlant =
          plants.where((p) => p.id == b.generatorPlantId).firstOrNull;
    });
  }

  Future<void> _pickAndExplodeBillWithAi(
    List<SolarCreditBeneficiaryModel> beneficiaries,
    List<SolarGeneratorPlantModel> plants,
  ) async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'webp'],
      );

      if (files.isEmpty) return;
      final file = files.first;
      final Uint8List bytes = await file.readAsBytes();
      if (bytes.isEmpty) return;

      setState(() {
        _isAnalyzingPdf = true;
        _uploadedFileName = file.name;
      });

      final exploded = await GeminiGdBillExplosionService.explodeEnergyBill(
        fileBytes: bytes,
        fileExtension: file.extension ?? 'pdf',
      );

      // Tenta vincular automaticamente ao cliente cadastrado pela UC ou Endereço
      final matchedBeneficiary =
          SolarCreditRepository.findMatchingBeneficiary(
        extractedUcNumber: exploded.ucNumber,
        extractedStreet: exploded.addressStreet,
        beneficiaries: beneficiaries,
      );

      if (!mounted) return;

      setState(() {
        _explodedBill = exploded;
        _editingBill = null;
        _useCustomSolarAmount = false;
        _customSolarAmountCtrl.clear();

        if (exploded.referenceMonth.isNotEmpty) {
          _refMonthCtrl.text = exploded.referenceMonth;
        }
        if (exploded.dueDate.isNotEmpty) {
          _dueDateCtrl.text = exploded.dueDate;
        }
        _ucNumberCtrl.text = exploded.ucNumber;
        _addressStreetCtrl.text = exploded.addressStreet;
        if (exploded.accountHolderName.isNotEmpty) {
          _holderNameCtrl.text = exploded.accountHolderName;
        }

        _consumptionKwhCtrl.text = exploded.consumptionKwh.toStringAsFixed(0);
        _consumptionRsCtrl.text = _fmtDec(exploded.consumptionValueRs);

        _injectedLines = List<InjectedEnergyLineItem>.from(
          exploded.injectedLines,
        );
        _injectedGdiKwhCtrl.text = exploded.injectedGdiKwh.toStringAsFixed(0);
        _injectedGdiRsCtrl.text = _fmtDec(exploded.injectedGdiValueRs);
        _injectedGdiiKwhCtrl.text =
            exploded.injectedGdiiKwh.toStringAsFixed(0);
        _injectedGdiiRsCtrl.text = _fmtDec(exploded.injectedGdiiValueRs);

        _gdAdjustmentKwhCtrl.text =
            exploded.gdAdjustmentKwh.toStringAsFixed(0);
        _gdAdjustmentRsCtrl.text = _fmtDec(exploded.gdAdjustmentValueRs);

        _publicLightingRsCtrl.text = _fmtDec(exploded.publicLightingValueRs);
        _finesAndInterestRsCtrl.text =
            _fmtDec(exploded.finesAndInterestValueRs);
        _utilityTotalToPayRsCtrl.text =
            _fmtDec(exploded.utilityBillTotalToPayRs);

        _accumulatedBalanceKwhCtrl.text =
            exploded.accumulatedBalanceKwh.toStringAsFixed(0);
        _ucGdClassification = exploded.ucGdClassification;
        _consumptionHistory = exploded.consumptionHistory;

        if (matchedBeneficiary != null) {
          _selectedBeneficiary = matchedBeneficiary;
          _allocationPercentCtrl.text =
              _fmtDec(matchedBeneficiary.utilityAllocationPercent);
          _discountPercentCtrl.text =
              _fmtDec(matchedBeneficiary.clientDiscountPercent);
          _selectedPlant = plants
              .where((p) => p.id == matchedBeneficiary.generatorPlantId)
              .firstOrNull;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              matchedBeneficiary != null
                  ? '✅ Conta explodida com sucesso! Cliente "${matchedBeneficiary.clientName}" (UC ${exploded.ucNumber}) identificado automaticamente.'
                  : '⚡ Conta explodida com sucesso! UC ${exploded.ucNumber} lida — selecione ou cadastre o cliente abaixo.',
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao analisar conta com IA: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAnalyzingPdf = false);
    }
  }

  Future<void> _pickQrCodeImage() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
      );
      if (files.isEmpty) return;
      final file = files.first;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return;

      setState(() {
        _qrCodeImageBase64 = base64Encode(bytes);
        _qrCodeFileName = file.name;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar imagem do QR Code: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  SolarCreditBillModel _buildCurrentBillModel() {
    final now = DateTime.now();
    final ben = _selectedBeneficiary;
    final plant = _selectedPlant;

    final regime = plant?.regime ??
        ben?.generatorRegime ??
        (_gdAdjustmentRs > 0 ? GdRegime.gd2 : GdRegime.gd1);

    return SolarCreditBillModel(
      id: _editingBill?.id ?? '',
      companyId: _companyId,
      beneficiaryId: ben?.id ?? '',
      clientName: ben?.clientName ??
          (_addressStreetCtrl.text.trim().isNotEmpty
              ? _addressStreetCtrl.text.trim()
              : 'Cliente Avulso'),
      clientPhone: ben?.clientPhone ?? '',
      accountHolderName: _holderNameCtrl.text.trim(),
      ucNumber: _ucNumberCtrl.text.trim(),
      addressStreet: _addressStreetCtrl.text.trim(),
      addressFull: ben?.fullAddressSummary ?? _addressStreetCtrl.text.trim(),
      generatorPlantId: plant?.id ?? ben?.generatorPlantId ?? '',
      generatorPlantName:
          plant?.name ?? ben?.generatorPlantName ?? 'Usina Solar',
      generatorRegime: regime,
      utilityAllocationPercent: _parseNum(_allocationPercentCtrl.text),
      clientDiscountPercent: _clientDiscountPercent,
      referenceMonth: _refMonthCtrl.text.trim(),
      dueDate: _dueDateCtrl.text.trim(),
      readingPreviousDate: _explodedBill?.readingPreviousDate,
      readingCurrentDate: _explodedBill?.readingCurrentDate,
      billingDays: _explodedBill?.billingDays ?? 30,
      consumptionKwh: _parseNum(_consumptionKwhCtrl.text),
      consumptionUnitTariff: _explodedBill?.consumptionUnitTariff ?? 1.194080,
      consumptionValueRs: _parseNum(_consumptionRsCtrl.text),
      injectedLines: _injectedLines,
      injectedGdiKwh: _parseNum(_injectedGdiKwhCtrl.text),
      injectedGdiValueRs: _parseNum(_injectedGdiRsCtrl.text),
      injectedGdiiKwh: _parseNum(_injectedGdiiKwhCtrl.text),
      injectedGdiiValueRs: _parseNum(_injectedGdiiRsCtrl.text),
      totalInjectedKwh: _totalInjectedKwh,
      totalInjectedGrossValueRs: _totalInjectedGrossRs,
      gdAdjustmentKwh: _parseNum(_gdAdjustmentKwhCtrl.text),
      gdAdjustmentTariff: _explodedBill?.gdAdjustmentTariff ?? 0.189080,
      gdAdjustmentValueRs: _gdAdjustmentRs,
      publicLightingValueRs: _parseNum(_publicLightingRsCtrl.text),
      finesAndInterestValueRs: _parseNum(_finesAndInterestRsCtrl.text),
      utilityBillTotalToPayRs: _utilityTotalToPayRs,
      accumulatedBalanceKwh: _parseNum(_accumulatedBalanceKwhCtrl.text),
      expiringNextCycleKwh: _explodedBill?.expiringNextCycleKwh ?? 0.0,
      ucGdClassification: _ucGdClassification,
      consumptionHistory: _consumptionHistory,
      netCompensatedCreditRs: _netCompensatedCreditRs,
      solarCompanyAmountToPayRs: _effectiveSolarCompanyAmountRs,
      totalWithSolarCompanyRs: _totalWithSolarCompanyRs,
      totalWithoutSolarCompanyRs: _totalWithoutSolarCompanyRs,
      monthlySavingsRs: _monthlySavingsRs,
      annualProjectedSavingsRs: _annualProjectedSavingsRs,
      qrCodeImageBase64: _qrCodeImageBase64,
      pixCopyPasteCode: _pixCopyPasteCtrl.text.trim().isEmpty
          ? null
          : _pixCopyPasteCtrl.text.trim(),
      paymentLinkUrl: _paymentLinkCtrl.text.trim().isEmpty
          ? null
          : _paymentLinkCtrl.text.trim(),
      paymentStatus: _editingBill?.paymentStatus ?? 'pending',
      createdAt: _editingBill?.createdAt ?? now,
      updatedAt: now,
    );
  }

  Future<void> _saveBillAndOpenPdf() async {
    if (_ucNumberCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe o número da UC ou envie uma conta em PDF.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() => _isSavingBill = true);
    try {
      final bill = _buildCurrentBillModel();
      final savedId = await _repository.saveBill(
        bill,
        companyId: _companyId,
      );

      if (!mounted) return;
      final savedBill = SolarCreditBillModel.fromMap(
        bill.toMap(),
        savedId,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '✅ Conta lançada com sucesso! Abrindo o Boleto / Demonstrativo PDF...',
          ),
          backgroundColor: Color(0xFF10B981),
        ),
      );

      await SolarCreditBoletoPreviewDialog.show(context, savedBill);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar lançamento: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingBill = false);
    }
  }

  void _loadBillIntoEditor(
    SolarCreditBillModel bill,
    List<SolarCreditBeneficiaryModel> beneficiaries,
    List<SolarGeneratorPlantModel> plants,
  ) {
    setState(() {
      _editingBill = bill;
      _activeTabIndex = 0;
      _selectedBeneficiary = beneficiaries
          .where((b) => b.id == bill.beneficiaryId)
          .firstOrNull;
      _selectedPlant = plants
          .where((p) => p.id == bill.generatorPlantId)
          .firstOrNull;
      _refMonthCtrl.text = bill.referenceMonth;
      _dueDateCtrl.text = bill.dueDate;
      _ucNumberCtrl.text = bill.ucNumber;
      _addressStreetCtrl.text = bill.addressStreet;
      _holderNameCtrl.text = bill.accountHolderName;
      _allocationPercentCtrl.text = _fmtDec(bill.utilityAllocationPercent);
      _discountPercentCtrl.text = _fmtDec(bill.clientDiscountPercent);
      _consumptionKwhCtrl.text = bill.consumptionKwh.toStringAsFixed(0);
      _consumptionRsCtrl.text = _fmtDec(bill.consumptionValueRs);
      _injectedLines = List<InjectedEnergyLineItem>.from(bill.injectedLines);
      _injectedGdiKwhCtrl.text = bill.injectedGdiKwh.toStringAsFixed(0);
      _injectedGdiRsCtrl.text = _fmtDec(bill.injectedGdiValueRs);
      _injectedGdiiKwhCtrl.text = bill.injectedGdiiKwh.toStringAsFixed(0);
      _injectedGdiiRsCtrl.text = _fmtDec(bill.injectedGdiiValueRs);
      _gdAdjustmentKwhCtrl.text = bill.gdAdjustmentKwh.toStringAsFixed(0);
      _gdAdjustmentRsCtrl.text = _fmtDec(bill.gdAdjustmentValueRs);
      _publicLightingRsCtrl.text = _fmtDec(bill.publicLightingValueRs);
      _finesAndInterestRsCtrl.text = _fmtDec(bill.finesAndInterestValueRs);
      _utilityTotalToPayRsCtrl.text = _fmtDec(bill.utilityBillTotalToPayRs);
      _accumulatedBalanceKwhCtrl.text =
          bill.accumulatedBalanceKwh.toStringAsFixed(0);
      _ucGdClassification = bill.ucGdClassification;
      _consumptionHistory = bill.consumptionHistory;
      _qrCodeImageBase64 = bill.qrCodeImageBase64;
      _pixCopyPasteCtrl.text = bill.pixCopyPasteCode ?? '';
      _paymentLinkCtrl.text = bill.paymentLinkUrl ?? '';
      _customSolarAmountCtrl.text = _fmtDec(bill.solarCompanyAmountToPayRs);
      _useCustomSolarAmount =
          (bill.solarCompanyAmountToPayRs - _calculatedSolarCompanyAmountRs)
                  .abs() >
              0.05;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: StreamBuilder<List<SolarGeneratorPlantModel>>(
            stream: _repository.getPlantsStream(companyId: _companyId),
            builder: (context, plantsSnap) {
              final plants = plantsSnap.data ?? [];

              return StreamBuilder<List<SolarCreditBeneficiaryModel>>(
                stream:
                    _repository.getBeneficiariesStream(companyId: _companyId),
                builder: (context, benSnap) {
                  final beneficiaries = benSnap.data ?? [];

                  return StreamBuilder<List<SolarCreditBillModel>>(
                    stream: _repository.getBillsStream(companyId: _companyId),
                    builder: (context, billsSnap) {
                      final bills = billsSnap.data ?? [];

                      return Container(
                        color: const Color(0xFF0F172A),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ── CABEÇALHO DO MÓDULO & NAVEGAÇÃO POR ABAS ──
                              _buildTopModuleHeader(
                                plants: plants,
                                beneficiaries: beneficiaries,
                                bills: bills,
                              ),
                              const SizedBox(height: 20),

                              // ── CONTEÚDO DA ABA ATIVA ─────────────────────
                              if (_activeTabIndex == 0)
                                _buildQuickLaunchAiTab(
                                  plants: plants,
                                  beneficiaries: beneficiaries,
                                )
                              else if (_activeTabIndex == 1)
                                SolarCreditAnalyticsTab(
                                  plants: plants,
                                  beneficiaries: beneficiaries,
                                  bills: bills,
                                  repository: _repository,
                                )
                              else if (_activeTabIndex == 2)
                                _buildBeneficiariesCrudTab(
                                  plants: plants,
                                  beneficiaries: beneficiaries,
                                )
                              else
                                _buildPlantsAndBillsHistoryTab(
                                  plants: plants,
                                  beneficiaries: beneficiaries,
                                  bills: bills,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CABEÇALHO SUPERIOR E SELETOR DE ABAS
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildTopModuleHeader({
    required List<SolarGeneratorPlantModel> plants,
    required List<SolarCreditBeneficiaryModel> beneficiaries,
    required List<SolarCreditBillModel> bills,
  }) {
    final totalFaturadoSolar = bills.fold<double>(
      0.0,
      (acc, b) => acc + b.solarCompanyAmountToPayRs,
    );
    final totalEconomiaClientes = bills.fold<double>(
      0.0,
      (acc, b) => acc + b.monthlySavingsRs,
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 14,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0284C7), Color(0xFF10B981)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.energy_savings_leaf_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Gestão de Créditos de Energia Solar (GD I & GD II)',
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981)
                                  .withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFF10B981),
                              ),
                            ),
                            child: Text(
                              'EXCLUSIVO MASTER',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF10B981),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Explosão de faturas Energisa com IA, cálculo automático de deságio/Ajuste GD, emissão de Boleto Solar 7 e controle de % de rateio por Usina',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Atalhos rápidos de cadastro
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      await GeneratorPlantFormDialog.show(
                        context,
                        companyId: _companyId,
                        repository: _repository,
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFF59E0B),
                      side: const BorderSide(color: Color(0xFFF59E0B)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.solar_power_rounded, size: 17),
                    label: Text(
                      '+ NOVA USINA',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final created = await BeneficiaryFormDialog.show(
                        context,
                        companyId: _companyId,
                        availablePlants: plants,
                        repository: _repository,
                      );
                      if (created != null && mounted) {
                        _applyBeneficiaryToForm(created, plants);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 17),
                    label: Text(
                      '+ NOVO CLIENTE / UC',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Barra de Abas + Mini KPIs
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildNavTabButton(
                    index: 0,
                    icon: Icons.auto_awesome_rounded,
                    label: '⚡ Explosão IA & Lançar Conta',
                  ),
                  _buildNavTabButton(
                    index: 1,
                    icon: Icons.bar_chart_rounded,
                    label: '📊 Gráficos de Usinas & Rateio (%)',
                  ),
                  _buildNavTabButton(
                    index: 2,
                    icon: Icons.people_alt_rounded,
                    label: '👥 Clientes & UCs (${beneficiaries.length})',
                  ),
                  _buildNavTabButton(
                    index: 3,
                    icon: Icons.receipt_long_rounded,
                    label:
                        '🏭 Usinas (${plants.length}) & Faturas (${bills.length})',
                  ),
                ],
              ),
              Wrap(
                spacing: 16,
                children: [
                  _buildMiniHeaderKpi(
                    'Receita Créditos:',
                    _currencyFmt.format(totalFaturadoSolar),
                    const Color(0xFF38BDF8),
                  ),
                  _buildMiniHeaderKpi(
                    'Economia Gerada:',
                    _currencyFmt.format(totalEconomiaClientes),
                    const Color(0xFF10B981),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavTabButton({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _activeTabIndex == index;
    return InkWell(
      onTap: () => setState(() => _activeTabIndex = index),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF0284C7)
              : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF38BDF8)
                : const Color(0xFF334155),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 17,
              color: isSelected ? Colors.white : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniHeaderKpi(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              color: const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ABA 0: PÁGINA DE ACESSO RÁPIDO — EXPLOSÃO DE CONTA EM PDF COM IA + BOLETO
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildQuickLaunchAiTab({
    required List<SolarGeneratorPlantModel> plants,
    required List<SolarCreditBeneficiaryModel> beneficiaries,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 1. DROPZONE / UPLOAD RÁPIDO DE CONTA EM PDF PARA EXPLOSÃO IA ────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF0284C7).withValues(alpha: 0.18),
                const Color(0xFF1E293B),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFF38BDF8).withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          child: Wrap(
            spacing: 20,
            runSpacing: 16,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: _isAnalyzingPdf
                        ? const SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.6,
                              color: Color(0xFF38BDF8),
                            ),
                          )
                        : const Icon(
                            Icons.picture_as_pdf_rounded,
                            color: Color(0xFF38BDF8),
                            size: 30,
                          ),
                  ),
                  const SizedBox(width: 16),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isAnalyzingPdf
                              ? 'Explodindo Fatura com IA Gemini Vision...'
                              : 'Acesso Rápido: Envie a Conta da Energisa em PDF ou Imagem',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _uploadedFileName != null
                              ? 'Arquivo lido: $_uploadedFileName • A IA extraiu Consumo, todas as linhas de Energia Injetada (GDI/GDII), Ajuste GDII e o Saldo Acumulado do rodapé!'
                              : 'A IA identifica a UC e o endereço, soma todas as linhas de Energia Injetada (GDI e GDII), separa o Ajuste GDII, captura o Saldo Acumulado de créditos na Página 2 e já monta o Boleto Solar 7.',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            color: const Color(0xFFCBD5E1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _isAnalyzingPdf
                    ? null
                    : () => _pickAndExplodeBillWithAi(beneficiaries, plants),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.auto_awesome_rounded, size: 20),
                label: Text(
                  _isAnalyzingPdf
                      ? 'ANALISANDO CONTA...'
                      : 'ENVIAR CONTA EM PDF (EXPLODIR IA)',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Banner caso a IA tenha lido uma UC que ainda não está cadastrada
        if (_explodedBill != null && _selectedBeneficiary == null)
          Container(
            margin: const EdgeInsets.only(bottom: 18),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFF59E0B)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: Color(0xFFF59E0B),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'A UC "${_explodedBill!.ucNumber}" (${_explodedBill!.addressStreet}) ainda não está cadastrada na sua lista de clientes. Cadastre-a agora em 1 clique já com os dados preenchidos!',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () async {
                    final created = await BeneficiaryFormDialog.show(
                      context,
                      prefillFromBill: _explodedBill,
                      companyId: _companyId,
                      availablePlants: plants,
                      repository: _repository,
                    );
                    if (created != null && mounted) {
                      _applyBeneficiaryToForm(created, plants);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: const Color(0xFF0F172A),
                  ),
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 17),
                  label: Text(
                    'CADASTRAR CLIENTE DESTA UC',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // ── 2. GRID PRINCIPAL: DADOS EXPLODIDOS (ESQUERDA) + DEMONSTRATIVO/BOLETO (DIREITA) ──
        LayoutBuilder(
          builder: (context, gridConstraints) {
            final isDesktop = gridConstraints.maxWidth >= 980;

            final leftColumn = _buildLeftExplosionFormCard(
              beneficiaries: beneficiaries,
              plants: plants,
            );
            final rightColumn = _buildRightBoletoPreviewAndPaymentCard();

            if (!isDesktop) {
              return Column(
                children: [
                  leftColumn,
                  const SizedBox(height: 20),
                  rightColumn,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 58, child: leftColumn),
                const SizedBox(width: 20),
                Expanded(flex: 42, child: rightColumn),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildLeftExplosionFormCard({
    required List<SolarCreditBeneficiaryModel> beneficiaries,
    required List<SolarGeneratorPlantModel> plants,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '1. Vínculo do Cliente, Usina Origem e Dados da Conta',
            style: GoogleFonts.outfit(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),

          // Seletor de Cliente Cadastrado
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: beneficiaries.any(
                        (b) => b.id == _selectedBeneficiary?.id,
                      )
                          ? _selectedBeneficiary?.id
                          : null,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF0F172A),
                      hint: Text(
                        'Selecione o Cliente / UC Beneficiária (ou envie o PDF para auto-identificar)',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                      items: beneficiaries.map((b) {
                        return DropdownMenuItem<String>(
                          value: b.id,
                          child: Text(
                            '${b.clientName} • UC: ${b.ucNumber} • ${b.addressStreet} (Deságio: ${b.clientDiscountPercent.toStringAsFixed(0)}%)',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val == null) return;
                        final found =
                            beneficiaries.firstWhere((b) => b.id == val);
                        _applyBeneficiaryToForm(found, plants);
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Linha: Mês Referência, Vencimento, Nº da UC, Endereço
          Row(
            children: [
              Expanded(
                child: _buildCompactField(
                  controller: _refMonthCtrl,
                  label: 'Mês de Referência',
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildCompactField(
                  controller: _dueDateCtrl,
                  label: 'Vencimento',
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildCompactField(
                  controller: _ucNumberCtrl,
                  label: 'Número da UC',
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _buildCompactField(
                  controller: _addressStreetCtrl,
                  label: 'Endereço da UC (Aparece no Demonstrativo)',
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: _buildCompactField(
                  controller: _holderNameCtrl,
                  label: 'Titular da Conta (Energisa)',
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildCompactField(
                  controller: _allocationPercentCtrl,
                  label: '% Rateio na Energisa',
                  suffix: '%',
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildCompactField(
                  controller: _discountPercentCtrl,
                  label: 'Desconto / Deságio do Cliente',
                  suffix: '%',
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildCompactField(
                  controller: _accumulatedBalanceKwhCtrl,
                  label: 'Saldo Acumulado Rodapé (Pág. 2)',
                  suffix: 'kWh',
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── 2. EXPLOSÃO DAS LINHAS DE ENERGIA INJETADA (GDI e GDII) ──────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '2. Explosão da Fatura (Consumo, Injetada GDI/GDII e Ajuste GD)',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              if (_injectedLines.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_injectedLines.length} linhas de Energia Injetada somadas',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Lista detalhada das linhas de Energia Injetada lidas pela IA
          if (_injectedLines.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LINHAS INDIVIDUAIS EXTRAÍDAS DA FATURA ENERGISA:',
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF38BDF8),
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._injectedLines.map((line) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: line.isGdi
                                  ? const Color(0xFF10B981)
                                      .withValues(alpha: 0.2)
                                  : const Color(0xFF38BDF8)
                                      .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              line.isGdi ? 'GD I' : 'GD II',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: line.isGdi
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF38BDF8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              line.description,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                          ),
                          Text(
                            '${_numFmt.format(line.quantityKwh)} kWh',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Text(
                            '- ${_currencyFmt.format(line.totalValueRs)}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],

          // Campos consolidados de Consumo, Injetada GDI, Injetada GDII e Ajuste GDII
          Row(
            children: [
              Expanded(
                child: _buildCompactField(
                  controller: _consumptionKwhCtrl,
                  label: 'Consumo Total (kWh)',
                  suffix: 'kWh',
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildCompactField(
                  controller: _consumptionRsCtrl,
                  label: 'Valor do Consumo (R\$)',
                  prefix: 'R\$ ',
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildCompactField(
                  controller: _injectedGdiKwhCtrl,
                  label: 'Soma Injetada GD I (kWh)',
                  suffix: 'kWh',
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildCompactField(
                  controller: _injectedGdiRsCtrl,
                  label: 'Soma Injetada GD I (R\$)',
                  prefix: 'R\$ ',
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildCompactField(
                  controller: _injectedGdiiKwhCtrl,
                  label: 'Soma Injetada GD II (kWh)',
                  suffix: 'kWh',
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildCompactField(
                  controller: _injectedGdiiRsCtrl,
                  label: 'Soma Injetada GD II (R\$)',
                  prefix: 'R\$ ',
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildCompactField(
                  controller: _gdAdjustmentKwhCtrl,
                  label: 'Ajuste GD II (kWh)',
                  suffix: 'kWh',
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildCompactField(
                  controller: _gdAdjustmentRsCtrl,
                  label: 'Valor Ajuste GD II (R\$)',
                  prefix: 'R\$ ',
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildCompactField(
                  controller: _publicLightingRsCtrl,
                  label: 'Ilum. Pública CIP (R\$)',
                  prefix: 'R\$ ',
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildCompactField(
                  controller: _finesAndInterestRsCtrl,
                  label: 'Multa / Juros (R\$)',
                  prefix: 'R\$ ',
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildCompactField(
                  controller: _utilityTotalToPayRsCtrl,
                  label: 'TOTAL A PAGAR PARA A ENERGISA (Boleto Concessionária)',
                  prefix: 'R\$ ',
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),

          // Histórico de 13 meses se extraído pela IA
          if (_consumptionHistory.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Histórico de Consumo dos Últimos 13 Meses (Extraído da Conta):',
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _consumptionHistory.map((h) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Text(
                    '${h.monthYear}: ${_numFmt.format(h.consumptionKwh)} kWh',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFFCBD5E1),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRightBoletoPreviewAndPaymentCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF0284C7), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.receipt_long_rounded,
                color: Color(0xFF38BDF8),
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Resumo do Demonstrativo / Boleto Solar 7',
                  style: GoogleFonts.outfit(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Memória de cálculo Opção A
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              children: [
                _buildCalcSummaryRow(
                  'Energia Injetada Total (${_numFmt.format(_totalInjectedKwh)} kWh):',
                  _currencyFmt.format(_totalInjectedGrossRs),
                  valueColor: const Color(0xFF38BDF8),
                ),
                if (_gdAdjustmentRs > 0)
                  _buildCalcSummaryRow(
                    '(-) Ajuste GD II (Lei 14.300/22):',
                    '- ${_currencyFmt.format(_gdAdjustmentRs)}',
                    valueColor: const Color(0xFFF59E0B),
                  ),
                _buildCalcSummaryRow(
                  '(=) Crédito Líquido Abatido na Fatura:',
                  _currencyFmt.format(_netCompensatedCreditRs),
                  isBold: true,
                ),
                _buildCalcSummaryRow(
                  '(-) Deságio do Cliente (${_decFmt.format(_clientDiscountPercent)}%):',
                  '- ${_currencyFmt.format(_netCompensatedCreditRs - _calculatedSolarCompanyAmountRs)}',
                  valueColor: const Color(0xFF10B981),
                ),
                const Divider(color: Color(0xFF334155), height: 18),

                // Valor a pagar para Solar 7
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'O valor a pagar para Solar 7 é de:',
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      _currencyFmt.format(_effectiveSolarCompanyAmountRs),
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF38BDF8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Opção de arredondar / digitar valor manual para Solar 7
                Row(
                  children: [
                    Checkbox(
                      value: _useCustomSolarAmount,
                      activeColor: const Color(0xFF0284C7),
                      onChanged: (v) {
                        setState(() {
                          _useCustomSolarAmount = v ?? false;
                          if (_useCustomSolarAmount &&
                              _customSolarAmountCtrl.text.isEmpty) {
                            _customSolarAmountCtrl.text =
                                _fmtDec(_calculatedSolarCompanyAmountRs);
                          }
                        });
                      },
                    ),
                    Expanded(
                      child: Text(
                        'Arredondar / Ajustar valor a pagar Solar 7 manualmente',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                    if (_useCustomSolarAmount)
                      SizedBox(
                        width: 120,
                        child: _buildCompactField(
                          controller: _customSolarAmountCtrl,
                          label: 'Valor Solar 7',
                          prefix: 'R\$ ',
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                  ],
                ),
                const Divider(color: Color(0xFF334155), height: 16),

                _buildCalcSummaryRow(
                  'O valor a pagar para Energisa é de:',
                  _currencyFmt.format(_utilityTotalToPayRs),
                ),
                _buildCalcSummaryRow(
                  'O valor final COM a Solar 7 é de:',
                  _currencyFmt.format(_totalWithSolarCompanyRs),
                  isBold: true,
                ),
                _buildCalcSummaryRow(
                  'O valor final SEM a Solar 7 SERIA de:',
                  _currencyFmt.format(_totalWithoutSolarCompanyRs),
                  valueColor: const Color(0xFF94A3B8),
                ),
                const SizedBox(height: 8),

                // Destaque Economia Mensal e Anual
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF10B981)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Você economizou este mês:',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            _currencyFmt.format(_monthlySavingsRs),
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Economia Anual neste ritmo:',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFFA7F3D0),
                            ),
                          ),
                          Text(
                            '${_currencyFmt.format(_annualProjectedSavingsRs)} / ANO',
                            style: GoogleFonts.inter(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFA7F3D0),
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
          const SizedBox(height: 16),

          // ── SEÇÃO OPCIONAL: QR CODE E LINK DE PAGAMENTO NO BOLETO PDF ────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '💳 QR Code & Link de Pagamento no Boleto (Opcional)',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF38BDF8),
                      ),
                    ),
                    Text(
                      'Opcional',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickQrCodeImage,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF38BDF8),
                        side: const BorderSide(color: Color(0xFF38BDF8)),
                      ),
                      icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                      label: Text(
                        _qrCodeImageBase64 != null
                            ? 'Trocar Imagem QR Code'
                            : 'Enviar Imagem QR Code',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (_qrCodeImageBase64 != null) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _qrCodeFileName ?? 'QR Code anexado',
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: const Color(0xFF10B981),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remover QR Code',
                        onPressed: () => setState(() {
                          _qrCodeImageBase64 = null;
                          _qrCodeFileName = null;
                        }),
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: Color(0xFFEF4444),
                          size: 18,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                _buildCompactField(
                  controller: _paymentLinkCtrl,
                  label: 'Link para Pagamento (Aparece clicável no Boleto PDF)',
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                _buildCompactField(
                  controller: _pixCopyPasteCtrl,
                  label:
                      'Chave PIX ou PIX Copia e Cola (Se preenchido s/ imagem, gera QR Code automático)',
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ── BOTÕES DE GERAR PDF E SALVAR LANÇAMENTO ──────────────────────
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    final previewBill = _buildCurrentBillModel();
                    SolarCreditBoletoPreviewDialog.show(context, previewBill);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF38BDF8)),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                  label: Text(
                    'VER BOLETO PDF',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _isSavingBill ? null : _saveBillAndOpenPdf,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: _isSavingBill
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_rounded, size: 19),
                  label: Text(
                    'LANÇAR CONTA & GERAR BOLETO PDF',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ABA 2: CRUD COMPLETO DE CLIENTES & UNIDADES CONSUMIDORAS BENEFICIÁRIAS
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildBeneficiariesCrudTab({
    required List<SolarGeneratorPlantModel> plants,
    required List<SolarCreditBeneficiaryModel> beneficiaries,
  }) {
    final query = _clientSearchCtrl.text.toLowerCase().trim();

    // Monta lista única de chaves/nomes de usinas (cadastradas + vinculadas nos clientes)
    final plantKeyMap = <String, String>{};
    for (final p in plants) {
      plantKeyMap[p.id] = '${p.name} (${p.regime.shortLabel})';
    }
    for (final b in beneficiaries) {
      for (final alloc in b.effectivePlantAllocations) {
        final key = alloc.generatorPlantId.trim().isNotEmpty
            ? alloc.generatorPlantId.trim()
            : alloc.generatorPlantName.trim().toUpperCase();
        if (key.isNotEmpty && !plantKeyMap.containsKey(key)) {
          plantKeyMap[key] =
              '${alloc.generatorPlantName} (${alloc.generatorRegime.shortLabel})';
        }
      }
    }

    final filtered = beneficiaries.where((b) {
      if (_selectedClientPlantFilter != 'all') {
        final matchesFilter = b.effectivePlantAllocations.any((alloc) {
          final aKey = alloc.generatorPlantId.trim().isNotEmpty
              ? alloc.generatorPlantId.trim()
              : alloc.generatorPlantName.trim().toUpperCase();
          return aKey == _selectedClientPlantFilter ||
              alloc.generatorPlantName.trim().toUpperCase() ==
                  _selectedClientPlantFilter.toUpperCase();
        });
        if (!matchesFilter) return false;
      }
      if (query.isEmpty) return true;
      return b.clientName.toLowerCase().contains(query) ||
          b.ucNumber.toLowerCase().contains(query) ||
          b.addressStreet.toLowerCase().contains(query) ||
          b.accountHolderName.toLowerCase().contains(query) ||
          b.allPlantsSummaryLabel.toLowerCase().contains(query);
    }).toList();

    // Agrupa os clientes filtrados por Usina Geradora (se o cliente recebe de 2+ usinas, aparece em cada usina correspondente)
    final Map<String, List<SolarCreditBeneficiaryModel>> groupedByPlant = {};
    for (final b in filtered) {
      for (final alloc in b.effectivePlantAllocations) {
        final groupKey = alloc.generatorPlantId.trim().isNotEmpty
            ? alloc.generatorPlantId.trim()
            : (alloc.generatorPlantName.trim().isNotEmpty
                ? alloc.generatorPlantName.trim().toUpperCase()
                : 'SEM_USINA');
        if (_selectedClientPlantFilter != 'all' &&
            groupKey != _selectedClientPlantFilter &&
            alloc.generatorPlantName.trim().toUpperCase() !=
                _selectedClientPlantFilter.toUpperCase()) {
          continue;
        }
        final list = groupedByPlant.putIfAbsent(groupKey, () => []);
        if (!list.any((item) => item.id == b.id)) {
          list.add(b);
        }
      }
    }

    // Ordena os grupos pelo nome da Usina e os clientes dentro de cada usina por % ou Nome
    final sortedGroupKeys = groupedByPlant.keys.toList()
      ..sort((k1, k2) {
        final n1 = plantKeyMap[k1] ??
            groupedByPlant[k1]!.first.generatorPlantName;
        final n2 = plantKeyMap[k2] ??
            groupedByPlant[k2]!.first.generatorPlantName;
        return n1.toLowerCase().compareTo(n2.toLowerCase());
      });

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 14,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Carteira de Clientes & Unidades Consumidoras (${filtered.length})',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Organize seus clientes agrupados por Usina Geradora, acompanhe a soma de % na Energisa e o saldo no rodapé',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Botão de Alternar: Agrupar por Usina vs Lista Geral
                  InkWell(
                    onTap: () => setState(
                      () => _groupClientsByPlant = !_groupClientsByPlant,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _groupClientsByPlant
                            ? const Color(0xFFF59E0B).withValues(alpha: 0.18)
                            : const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _groupClientsByPlant
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF334155),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _groupClientsByPlant
                                ? Icons.workspaces_rounded
                                : Icons.view_list_rounded,
                            size: 17,
                            color: _groupClientsByPlant
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _groupClientsByPlant
                                ? 'Agrupado por Usina'
                                : 'Agrupar por Usina',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: _groupClientsByPlant
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFFCBD5E1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Botão Expandir / Recolher Todos os Grupos (quando agrupado)
                  if (_groupClientsByPlant && sortedGroupKeys.length > 1)
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          if (_collapsedPlantGroupKeys.length ==
                              sortedGroupKeys.length) {
                            _collapsedPlantGroupKeys.clear();
                          } else {
                            _collapsedPlantGroupKeys
                              ..clear()
                              ..addAll(sortedGroupKeys);
                          }
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFCBD5E1),
                        side: const BorderSide(color: Color(0xFF334155)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 11,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: Icon(
                        _collapsedPlantGroupKeys.length ==
                                sortedGroupKeys.length
                            ? Icons.unfold_more_rounded
                            : Icons.unfold_less_rounded,
                        size: 16,
                      ),
                      label: Text(
                        _collapsedPlantGroupKeys.length ==
                                sortedGroupKeys.length
                            ? 'Expandir Usinas'
                            : 'Recolher Usinas',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                  // Filtro Dropdown por Usina Específica
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedClientPlantFilter == 'all' ||
                                plantKeyMap
                                    .containsKey(_selectedClientPlantFilter)
                            ? _selectedClientPlantFilter
                            : 'all',
                        dropdownColor: const Color(0xFF0F172A),
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Color(0xFFF59E0B),
                          size: 18,
                        ),
                        items: [
                          DropdownMenuItem<String>(
                            value: 'all',
                            child: Text(
                              '🏭 Todas as Usinas (${plantKeyMap.length})',
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          ...plantKeyMap.entries.map((entry) {
                            return DropdownMenuItem<String>(
                              value: entry.key,
                              child: Text(
                                '☀️ ${entry.value}',
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  color: Colors.white,
                                ),
                              ),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedClientPlantFilter = val);
                          }
                        },
                      ),
                    ),
                  ),

                  // Campo de Busca
                  SizedBox(
                    width: 290,
                    child: TextField(
                      controller: _clientSearchCtrl,
                      onChanged: (_) => setState(() {}),
                      style:
                          GoogleFonts.inter(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Buscar cliente, UC, endereço ou usina...',
                        hintStyle: GoogleFonts.inter(
                          color: const Color(0xFF64748B),
                          fontSize: 12,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: Color(0xFF94A3B8),
                          size: 18,
                        ),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFF334155)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),

          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'Nenhum cliente/UC encontrado. Clique em "+ NOVO CLIENTE / UC" no topo para cadastrar.',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF94A3B8),
                    fontSize: 13,
                  ),
                ),
              ),
            )
          else if (_groupClientsByPlant)
            ...sortedGroupKeys.map((groupKey) {
              final groupClients = groupedByPlant[groupKey]!;
              final matchedAlloc = groupClients.first.effectivePlantAllocations
                  .where(
                    (a) =>
                        a.generatorPlantId == groupKey ||
                        a.generatorPlantName.trim().toUpperCase() ==
                            groupKey.toUpperCase(),
                  )
                  .firstOrNull;

              final matchedPlant = plants
                  .where(
                    (p) =>
                        p.id == groupKey ||
                        (matchedAlloc != null &&
                            p.name.trim().toUpperCase() ==
                                matchedAlloc.generatorPlantName
                                    .trim()
                                    .toUpperCase()),
                  )
                  .firstOrNull;

              final plantName = matchedPlant?.name ??
                  matchedAlloc?.generatorPlantName ??
                  (groupClients.first.generatorPlantName.trim().isNotEmpty
                      ? groupClients.first.generatorPlantName
                      : 'Usina Não Definida');
              final regime = matchedPlant?.regime ??
                  matchedAlloc?.generatorRegime ??
                  groupClients.first.generatorRegime;
              final isCollapsed = _collapsedPlantGroupKeys.contains(groupKey);

              final totalAllocatedPct = groupClients.fold<double>(
                0.0,
                (acc, item) =>
                    acc + item.allocationPercentForPlant(groupKey, plantName),
              );
              final freePct = (100.0 - totalAllocatedPct).clamp(0.0, 100.0);
              final isOver100 = totalAllocatedPct > 100.01;
              final totalBalanceKwh = groupClients.fold<double>(
                0.0,
                (acc, item) => acc + item.lastAccumulatedBalanceKwh,
              );

              return Container(
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.45),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── CABEÇALHO DO GRUPO DA USINA GERADORA ──────────────────
                    InkWell(
                      onTap: () {
                        setState(() {
                          if (isCollapsed) {
                            _collapsedPlantGroupKeys.remove(groupKey);
                          } else {
                            _collapsedPlantGroupKeys.add(groupKey);
                          }
                        });
                      },
                      borderRadius: BorderRadius.vertical(
                        top: const Radius.circular(15),
                        bottom: Radius.circular(isCollapsed ? 15 : 0),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFFF59E0B).withValues(alpha: 0.16),
                              const Color(0xFF1E293B),
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.vertical(
                            top: const Radius.circular(15),
                            bottom: Radius.circular(isCollapsed ? 15 : 0),
                          ),
                        ),
                        child: Wrap(
                          spacing: 16,
                          runSpacing: 10,
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            // Nome da Usina + Regime + Qtd de Clientes
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(9),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF59E0B)
                                        .withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.solar_power_rounded,
                                    color: Color(0xFFF59E0B),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          plantName.toUpperCase(),
                                          style: GoogleFonts.outfit(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: regime == GdRegime.gd1
                                                ? const Color(0xFF10B981)
                                                    .withValues(alpha: 0.2)
                                                : const Color(0xFF38BDF8)
                                                    .withValues(alpha: 0.2),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            border: Border.all(
                                              color: regime == GdRegime.gd1
                                                  ? const Color(0xFF10B981)
                                                  : const Color(0xFF38BDF8),
                                            ),
                                          ),
                                          child: Text(
                                            regime.shortLabel,
                                            style: GoogleFonts.inter(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.bold,
                                              color: regime == GdRegime.gd1
                                                  ? const Color(0xFF10B981)
                                                  : const Color(0xFF38BDF8),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF0F172A),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            '${groupClients.length} ${groupClients.length == 1 ? "cliente" : "clientes"}',
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFFCBD5E1),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (matchedPlant != null &&
                                        matchedPlant
                                                .estimatedMonthlyGenerationKwh >
                                            0)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          'Geração Estimada: ${_numFmt.format(matchedPlant.estimatedMonthlyGenerationKwh)} kWh/mês • Titular: ${matchedPlant.accountHolderName}',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: const Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),

                            // Indicadores Consolidados da Usina (% Alocado, % Livre, Saldo Total e Botão + Cliente)
                            Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F172A),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isOver100
                                          ? const Color(0xFFEF4444)
                                          : const Color(0xFF38BDF8)
                                              .withValues(alpha: 0.5),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.pie_chart_rounded,
                                        size: 14,
                                        color: isOver100
                                            ? const Color(0xFFEF4444)
                                            : const Color(0xFF38BDF8),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Rateio Usina: ${_decFmt.format(totalAllocatedPct)}%',
                                        style: GoogleFonts.inter(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.bold,
                                          color: isOver100
                                              ? const Color(0xFFEF4444)
                                              : const Color(0xFF38BDF8),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        isOver100
                                            ? '(⚠️ Passou de 100%)'
                                            : '(${_decFmt.format(freePct)}% livre)',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: isOver100
                                              ? const Color(0xFFFCA5A5)
                                              : const Color(0xFF10B981),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F172A),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFF818CF8)
                                          .withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: Text(
                                    'Saldo Acumulado: ${_numFmt.format(totalBalanceKwh)} kWh',
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF818CF8),
                                    ),
                                  ),
                                ),
                                if (matchedPlant != null)
                                  TextButton.icon(
                                    onPressed: () {
                                      BeneficiaryFormDialog.show(
                                        context,
                                        initialPlantId: matchedPlant.id,
                                        companyId: _companyId,
                                        availablePlants: plants,
                                        repository: _repository,
                                      );
                                    },
                                    style: TextButton.styleFrom(
                                      backgroundColor: const Color(0xFF10B981)
                                          .withValues(alpha: 0.16),
                                      foregroundColor: const Color(0xFF10B981),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.person_add_alt_1_rounded,
                                      size: 14,
                                    ),
                                    label: Text(
                                      '+ Cliente',
                                      style: GoogleFonts.inter(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                Icon(
                                  isCollapsed
                                      ? Icons.expand_more_rounded
                                      : Icons.expand_less_rounded,
                                  color: const Color(0xFFF59E0B),
                                  size: 22,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── LISTA DE CLIENTES DESTA USINA ─────────────────────────
                    if (!isCollapsed)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                        child: Column(
                          children: groupClients
                              .map(
                                (b) => _buildBeneficiaryRowCard(
                                  b,
                                  plants,
                                  contextPlantId: groupKey,
                                  contextPlantName: plantName,
                                  contextPlantRegime: regime,
                                ),
                              )
                              .toList(),
                        ),
                      ),
                  ],
                ),
              );
            })
          else
            ...filtered.map((b) => _buildBeneficiaryRowCard(b, plants)),
        ],
      ),
    );
  }

  Widget _buildBeneficiaryRowCard(
    SolarCreditBeneficiaryModel b,
    List<SolarGeneratorPlantModel> plants, {
    String? contextPlantId,
    String? contextPlantName,
    GdRegime? contextPlantRegime,
  }) {
    final bool isInsidePlantGroup =
        contextPlantId != null && contextPlantId.isNotEmpty;
    final double displayAllocationPct = isInsidePlantGroup
        ? b.allocationPercentForPlant(contextPlantId, contextPlantName)
        : b.effectivePlantAllocations.fold<double>(
            0.0,
            (acc, a) => acc + a.allocationPercent,
          );

    final otherPlantsText = isInsidePlantGroup && b.hasMultiplePlants
        ? b.effectivePlantAllocations
            .where(
              (a) =>
                  a.generatorPlantId != contextPlantId &&
                  a.generatorPlantName.trim().toUpperCase() !=
                      (contextPlantName ?? '').trim().toUpperCase(),
            )
            .map(
              (a) =>
                  '${a.generatorPlantName} (${_decFmt.format(a.allocationPercent)}%)',
            )
            .join(', ')
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        b.clientName,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'UC: ${b.ucNumber}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF38BDF8),
                        ),
                      ),
                    ),
                    if (b.hasMultiplePlants) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${b.effectivePlantAllocations.length} USINAS',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFF59E0B),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '📍 ${b.fullAddressSummary}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFFCBD5E1),
                  ),
                ),
                Text(
                  '👤 Titular na Conta: ${b.accountHolderName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
                if (otherPlantsText.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      '🔗 Recebe também de: $otherPlantsText',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFF59E0B),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Badges de Usina, % na Concessionária, % Desconto e Saldo Acumulado + Ações
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildInfoBadge(
                b.hasMultiplePlants && !isInsidePlantGroup
                    ? 'Usinas Origem (${b.effectivePlantAllocations.length})'
                    : 'Usina Origem',
                isInsidePlantGroup
                    ? '${contextPlantName ?? b.generatorPlantName} (${(contextPlantRegime ?? b.generatorRegime).shortLabel})'
                    : b.allPlantsSummaryLabel,
                const Color(0xFFF59E0B),
              ),
              _buildInfoBadge(
                isInsidePlantGroup ? '% nesta Usina' : '% na Energisa',
                '${_decFmt.format(displayAllocationPct)}%',
                const Color(0xFF38BDF8),
              ),
              _buildInfoBadge(
                'Desconto (Deságio)',
                '${_decFmt.format(b.clientDiscountPercent)}%',
                const Color(0xFF10B981),
              ),
              _buildInfoBadge(
                'Saldo no Rodapé',
                '${_numFmt.format(b.lastAccumulatedBalanceKwh)} kWh',
                const Color(0xFF818CF8),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Tooltip(
                    message: 'Lançar Conta para este Cliente',
                    child: IconButton(
                      onPressed: () {
                        _applyBeneficiaryToForm(b, plants);
                        setState(() => _activeTabIndex = 0);
                      },
                      icon: const Icon(
                        Icons.bolt_rounded,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ),
                  Tooltip(
                    message: 'Editar Cliente / UC',
                    child: IconButton(
                      onPressed: () {
                        BeneficiaryFormDialog.show(
                          context,
                          beneficiary: b,
                          companyId: _companyId,
                          availablePlants: plants,
                          repository: _repository,
                        );
                      },
                      icon: const Icon(
                        Icons.edit_outlined,
                        color: Color(0xFF38BDF8),
                      ),
                    ),
                  ),
                  Tooltip(
                    message: 'Excluir Cliente / UC',
                    child: IconButton(
                      onPressed: () async {
                        await _repository.deleteBeneficiary(b.id);
                      },
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ABA 3: USINAS GERADORAS & HISTÓRICO DE FATURAS / BOLETOS EMITIDOS
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildPlantsAndBillsHistoryTab({
    required List<SolarGeneratorPlantModel> plants,
    required List<SolarCreditBeneficiaryModel> beneficiaries,
    required List<SolarCreditBillModel> bills,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. LISTA DE USINAS GERADORAS (ORIGEM)
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '🏭 Usinas Geradoras de Origem (${plants.length})',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => GeneratorPlantFormDialog.show(
                      context,
                      companyId: _companyId,
                      repository: _repository,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      foregroundColor: const Color(0xFF0F172A),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(
                      'CADASTRAR USINA',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (plants.isEmpty)
                Text(
                  'Nenhuma usina geradora cadastrada ainda.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF94A3B8),
                  ),
                )
              else
                ...plants.map((p) {
                  final plantBen = beneficiaries
                      .where((b) => b.receivesFromPlant(p.id, p.name))
                      .toList();
                  final allocatedPct = plantBen.fold<double>(
                    0.0,
                    (acc, b) => acc + b.allocationPercentForPlant(p.id, p.name),
                  );

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${p.name} • [${p.regime.label}]',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'UC Geradora: ${p.generatorUcNumber.isEmpty ? "N/I" : p.generatorUcNumber} • Titular: ${p.accountHolderName} • Geração: ${_numFmt.format(p.estimatedMonthlyGenerationKwh)} kWh/mês • Rateio Alocado: ${_decFmt.format(allocatedPct)}% (${plantBen.length} clientes)',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => GeneratorPlantFormDialog.show(
                                context,
                                plant: p,
                                companyId: _companyId,
                                repository: _repository,
                              ),
                              icon: const Icon(
                                Icons.edit_outlined,
                                color: Color(0xFF38BDF8),
                              ),
                            ),
                            IconButton(
                              onPressed: () => _repository.deletePlant(p.id),
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: Color(0xFFEF4444),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 2. HISTÓRICO DE FATURAS LANÇADAS & BOLETOS EMITIDOS
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '📄 Histórico de Contas Lançadas & Boletos Solar 7 (${bills.length})',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 14),
              if (bills.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'Nenhuma conta mensal lançada ainda.',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF94A3B8),
                        fontSize: 13,
                      ),
                    ),
                  ),
                )
              else
                ...bills.map((bill) {
                  final isPaid = bill.paymentStatus == 'paid';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isPaid
                            ? const Color(0xFF10B981).withValues(alpha: 0.5)
                            : const Color(0xFF334155),
                      ),
                    ),
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 10,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  bill.clientName,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E293B),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Ref: ${bill.referenceMonth} • Venc: ${bill.dueDate}',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: const Color(0xFF38BDF8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'UC: ${bill.ucNumber} • Consumo: ${_numFmt.format(bill.consumptionKwh)} kWh • Injetado: ${_numFmt.format(bill.totalInjectedKwh)} kWh • Saldo Rodapé: ${_numFmt.format(bill.accumulatedBalanceKwh)} kWh',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                        Wrap(
                          spacing: 10,
                          children: [
                            _buildInfoBadge(
                              'Pagar Solar 7',
                              _currencyFmt.format(bill.solarCompanyAmountToPayRs),
                              const Color(0xFF38BDF8),
                            ),
                            _buildInfoBadge(
                              'Pagar Energisa',
                              _currencyFmt.format(bill.utilityBillTotalToPayRs),
                              const Color(0xFFF59E0B),
                            ),
                            _buildInfoBadge(
                              'Economia Cliente',
                              _currencyFmt.format(bill.monthlySavingsRs),
                              const Color(0xFF10B981),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton.icon(
                              onPressed: () {
                                _repository.updateBillPaymentStatus(
                                  bill.id,
                                  isPaid ? 'pending' : 'paid',
                                );
                              },
                              icon: Icon(
                                isPaid
                                    ? Icons.check_circle_rounded
                                    : Icons.schedule_rounded,
                                size: 16,
                                color: isPaid
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFF59E0B),
                              ),
                              label: Text(
                                isPaid ? 'PAGO' : 'PENDENTE',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isPaid
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFF59E0B),
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Gerar / Baixar Boleto PDF',
                              onPressed: () =>
                                  SolarCreditBoletoPreviewDialog.show(
                                context,
                                bill,
                              ),
                              icon: const Icon(
                                Icons.picture_as_pdf_rounded,
                                color: Color(0xFF38BDF8),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Enviar Resumo no WhatsApp',
                              onPressed: () async {
                                final msg =
                                    'Olá *${bill.clientName}*! Segue o demonstrativo da sua UC *${bill.ucNumber}* referente a *${bill.referenceMonth}*:\n\n'
                                    '⚡ Consumo: ${_numFmt.format(bill.consumptionKwh)} kWh\n'
                                    '☀️ Energia Injetada: ${_numFmt.format(bill.totalInjectedKwh)} kWh\n'
                                    '💳 Valor a pagar Solar 7: *${_currencyFmt.format(bill.solarCompanyAmountToPayRs)}*\n'
                                    '🏢 Valor a pagar Energisa: *${_currencyFmt.format(bill.utilityBillTotalToPayRs)}*\n'
                                    '✅ *Sua Economia neste mês: ${_currencyFmt.format(bill.monthlySavingsRs)}* (${_currencyFmt.format(bill.annualProjectedSavingsRs)}/ano!)';
                                final phone = bill.clientPhone
                                    .replaceAll(RegExp(r'[^0-9]'), '');
                                final uri = Uri.parse(
                                  'https://wa.me/${phone.isNotEmpty ? "55$phone" : ""}?text=${Uri.encodeComponent(msg)}',
                                );
                                await launchUrl(
                                  uri,
                                  mode: LaunchMode.externalApplication,
                                );
                              },
                              icon: const Icon(
                                Icons.chat_bubble_outline_rounded,
                                color: Color(0xFF10B981),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Editar Lançamento',
                              onPressed: () => _loadBillIntoEditor(
                                bill,
                                beneficiaries,
                                plants,
                              ),
                              icon: const Icon(
                                Icons.edit_outlined,
                                color: Colors.white70,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Excluir Lançamento',
                              onPressed: () => _repository.deleteBill(bill.id),
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: Color(0xFFEF4444),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  // ── HELPERS VISUAIS ────────────────────────────────────────────────────────
  Widget _buildCompactField({
    required TextEditingController controller,
    required String label,
    String? prefix,
    String? suffix,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          onChanged: onChanged,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
          decoration: InputDecoration(
            prefixText: prefix,
            suffixText: suffix,
            prefixStyle: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF94A3B8),
            ),
            suffixStyle: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF94A3B8),
            ),
            filled: true,
            fillColor: const Color(0xFF0F172A),
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF334155)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF334155)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF38BDF8)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCalcSummaryRow(
    String label,
    String value, {
    Color? valueColor,
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isBold ? Colors.white : const Color(0xFFCBD5E1),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: valueColor ?? Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: const Color(0xFF94A3B8),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

