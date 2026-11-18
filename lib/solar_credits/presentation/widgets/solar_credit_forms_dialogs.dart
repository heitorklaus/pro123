import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../data/repositories/solar_credit_repository.dart';
import '../../data/services/gemini_gd_bill_explosion_service.dart';
import '../../domain/models/solar_credit_models.dart';

/// Modal de Cadastro / Edição de Usina Geradora (Origem dos Créditos)
class GeneratorPlantFormDialog extends StatefulWidget {
  final SolarGeneratorPlantModel? plant;
  final String companyId;
  final SolarCreditRepository repository;

  const GeneratorPlantFormDialog({
    super.key,
    this.plant,
    required this.companyId,
    required this.repository,
  });

  static Future<SolarGeneratorPlantModel?> show(
    BuildContext context, {
    SolarGeneratorPlantModel? plant,
    required String companyId,
    required SolarCreditRepository repository,
  }) {
    return showDialog<SolarGeneratorPlantModel>(
      context: context,
      barrierDismissible: false,
      builder: (_) => GeneratorPlantFormDialog(
        plant: plant,
        companyId: companyId,
        repository: repository,
      ),
    );
  }

  @override
  State<GeneratorPlantFormDialog> createState() =>
      _GeneratorPlantFormDialogState();
}

class _GeneratorPlantFormDialogState extends State<GeneratorPlantFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _ucCtrl;
  late final TextEditingController _holderNameCtrl;
  late final TextEditingController _holderDocCtrl;
  late final TextEditingController _powerKwpCtrl;
  late final TextEditingController _genKwhCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _stateCtrl;
  late final TextEditingController _notesCtrl;

  GdRegime _regime = GdRegime.gd2;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.plant;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _ucCtrl = TextEditingController(text: p?.generatorUcNumber ?? '');
    _holderNameCtrl = TextEditingController(
      text: p?.accountHolderName ?? 'HEITOR FABRICIO KLAUS DE OLIVEIRA',
    );
    _holderDocCtrl = TextEditingController(text: p?.accountHolderDocument ?? '');
    _powerKwpCtrl = TextEditingController(
      text: p != null && p.installedPowerKwp > 0
          ? p.installedPowerKwp.toStringAsFixed(2)
          : '',
    );
    _genKwhCtrl = TextEditingController(
      text: p != null && p.estimatedMonthlyGenerationKwh > 0
          ? p.estimatedMonthlyGenerationKwh.toStringAsFixed(0)
          : '',
    );
    _cityCtrl = TextEditingController(text: p?.city ?? 'Cuiabá');
    _stateCtrl = TextEditingController(text: p?.state ?? 'MT');
    _notesCtrl = TextEditingController(text: p?.notes ?? '');
    _regime = p?.regime ?? GdRegime.gd2;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ucCtrl.dispose();
    _holderNameCtrl.dispose();
    _holderDocCtrl.dispose();
    _powerKwpCtrl.dispose();
    _genKwhCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _notesCtrl.dispose();
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();
      final model = SolarGeneratorPlantModel(
        id: widget.plant?.id ?? '',
        companyId: widget.companyId,
        name: _nameCtrl.text.trim(),
        generatorUcNumber: _ucCtrl.text.trim(),
        accountHolderName: _holderNameCtrl.text.trim(),
        accountHolderDocument: _holderDocCtrl.text.trim(),
        regime: _regime,
        installedPowerKwp: _parseNum(_powerKwpCtrl.text),
        estimatedMonthlyGenerationKwh: _parseNum(_genKwhCtrl.text),
        city: _cityCtrl.text.trim().isNotEmpty ? _cityCtrl.text.trim() : 'Cuiabá',
        state: _stateCtrl.text.trim().isNotEmpty ? _stateCtrl.text.trim() : 'MT',
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        createdAt: widget.plant?.createdAt ?? now,
        updatedAt: now,
      );

      final savedId = await widget.repository.savePlant(
        model,
        companyId: widget.companyId,
      );

      if (mounted) {
        Navigator.pop(context, model.copyWith(id: savedId));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar usina geradora: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.plant != null;

    return Dialog(
      backgroundColor: const Color(0xFF0F172A),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF334155)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.solar_power_rounded,
                        color: Color(0xFFF59E0B),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEdit
                                ? 'Editar Usina Geradora (Origem)'
                                : 'Nova Usina Geradora de Créditos',
                            style: GoogleFonts.outfit(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Cadastre a usina de onde saem os créditos distribuídos na concessionária',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white70),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Nome da Usina + UC Geradora
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildTextField(
                        controller: _nameCtrl,
                        label: 'Nome de Identificação da Usina *',
                        hint: 'Ex: Usina Solar I - Chapada / UFV Solar 7',
                        icon: Icons.bolt_rounded,
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Informe o nome da usina'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: _buildTextField(
                        controller: _ucCtrl,
                        label: 'Nº da UC Geradora (Energisa)',
                        hint: 'Ex: 1.020.304.050-01',
                        icon: Icons.tag_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Regime GD1 vs GD2
                Text(
                  'Regime de Compensação (Lei 14.300/22) *',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFCBD5E1),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildRegimeOption(
                        regime: GdRegime.gd1,
                        title: 'GD I (Direito Adquirido)',
                        subtitle: 'Compensação 100% integral s/ Ajuste GD',
                        color: const Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildRegimeOption(
                        regime: GdRegime.gd2,
                        title: 'GD II (Lei 14.300/22)',
                        subtitle: 'Possui desconto do Ajuste GD na conta',
                        color: const Color(0xFF38BDF8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Titular da Conta (Seu Nome ou Empresa)
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildTextField(
                        controller: _holderNameCtrl,
                        label: 'Titular da Usina (Seu Nome ou Sua Empresa) *',
                        hint: 'Ex: HEITOR FABRICIO KLAUS DE OLIVEIRA / SOLAR 7',
                        icon: Icons.badge_outlined,
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Informe o titular'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: _buildTextField(
                        controller: _holderDocCtrl,
                        label: 'CPF / CNPJ do Titular',
                        hint: 'Ex: 42.117.511/0001-38',
                        icon: Icons.credit_card_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Potência kWp + Geração Mensal Estimada kWh
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _powerKwpCtrl,
                        label: 'Potência Instalada (kWp)',
                        hint: 'Ex: 75.0',
                        icon: Icons.speed_rounded,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (val) {
                          final kwp = _parseNum(val);
                          if (kwp > 0 && _genKwhCtrl.text.trim().isEmpty) {
                            _genKwhCtrl.text = (kwp * 115).toStringAsFixed(0);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        controller: _genKwhCtrl,
                        label: 'Geração Média Mensal (kWh/mês) *',
                        hint: 'Ex: 9000',
                        icon: Icons.energy_savings_leaf_rounded,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (v) => _parseNum(v ?? '') <= 0
                            ? 'Informe a geração mensal estimada (kWh)'
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Cidade + UF
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildTextField(
                        controller: _cityCtrl,
                        label: 'Cidade da Usina',
                        hint: 'Cuiabá',
                        icon: Icons.location_city_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: _buildTextField(
                        controller: _stateCtrl,
                        label: 'UF',
                        hint: 'MT',
                        icon: Icons.map_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Botões
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed:
                          _isSaving ? null : () => Navigator.pop(context),
                      child: Text(
                        'CANCELAR',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF94A3B8),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        foregroundColor: const Color(0xFF0F172A),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF0F172A),
                              ),
                            )
                          : const Icon(Icons.check_circle_outline_rounded,
                              size: 18),
                      label: Text(
                        isEdit ? 'SALVAR ALTERAÇÕES' : 'CADASTRAR USINA',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRegimeOption({
    required GdRegime regime,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    final isSelected = _regime == regime;
    return InkWell(
      onTap: () => setState(() => _regime = regime),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.15)
              : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : const Color(0xFF334155),
            width: isSelected ? 1.8 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: isSelected ? color : const Color(0xFF64748B),
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Modal de Cadastro / Edição de Cliente / Unidade Consumidora Beneficiária
class BeneficiaryFormDialog extends StatefulWidget {
  final SolarCreditBeneficiaryModel? beneficiary;
  final ExplodedGdEnergyBill? prefillFromBill;
  final String? initialPlantId;
  final String companyId;
  final List<SolarGeneratorPlantModel> availablePlants;
  final SolarCreditRepository repository;

  const BeneficiaryFormDialog({
    super.key,
    this.beneficiary,
    this.prefillFromBill,
    this.initialPlantId,
    required this.companyId,
    required this.availablePlants,
    required this.repository,
  });

  static Future<SolarCreditBeneficiaryModel?> show(
    BuildContext context, {
    SolarCreditBeneficiaryModel? beneficiary,
    ExplodedGdEnergyBill? prefillFromBill,
    String? initialPlantId,
    required String companyId,
    required List<SolarGeneratorPlantModel> availablePlants,
    required SolarCreditRepository repository,
  }) {
    return showDialog<SolarCreditBeneficiaryModel>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BeneficiaryFormDialog(
        beneficiary: beneficiary,
        prefillFromBill: prefillFromBill,
        initialPlantId: initialPlantId,
        companyId: companyId,
        availablePlants: availablePlants,
        repository: repository,
      ),
    );
  }

  @override
  State<BeneficiaryFormDialog> createState() => _BeneficiaryFormDialogState();
}

class _PlantAllocationDraft {
  SolarGeneratorPlantModel? plant;
  String fallbackPlantId;
  String fallbackPlantName;
  GdRegime regime;
  final TextEditingController percentCtrl;

  _PlantAllocationDraft({
    this.plant,
    this.fallbackPlantId = '',
    this.fallbackPlantName = '',
    this.regime = GdRegime.gd2,
    String initialPercent = '10,00',
  }) : percentCtrl = TextEditingController(text: initialPercent);

  void dispose() => percentCtrl.dispose();
}

class _BeneficiaryFormDialogState extends State<BeneficiaryFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _clientNameCtrl;
  late final TextEditingController _clientPhoneCtrl;
  late final TextEditingController _clientDocCtrl;
  late final TextEditingController _holderNameCtrl;
  late final TextEditingController _holderDocCtrl;
  late final TextEditingController _ucNumberCtrl;
  late final TextEditingController _zipCodeCtrl;
  late final TextEditingController _streetCtrl;
  late final TextEditingController _neighborhoodCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _stateCtrl;
  late final TextEditingController _discountPercentCtrl;
  late final TextEditingController _avgConsumptionCtrl;
  late final TextEditingController _accumulatedBalanceCtrl;

  String _connectionType = 'Trifásico';
  late List<SolarGeneratorPlantModel> _plants;
  final List<_PlantAllocationDraft> _plantDrafts = [];
  GdRegime _regime = GdRegime.gd2;
  bool _isLookingUpCep = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final b = widget.beneficiary;
    final pre = widget.prefillFromBill;
    _plants = List<SolarGeneratorPlantModel>.from(widget.availablePlants);

    _clientNameCtrl = TextEditingController(
      text: b?.clientName ??
          (pre != null && pre.addressStreet.isNotEmpty
              ? 'Cliente - ${pre.addressStreet}'
              : ''),
    );
    _clientPhoneCtrl = TextEditingController(text: b?.clientPhone ?? '');
    _clientDocCtrl = TextEditingController(text: b?.clientDocument ?? '');
    _holderNameCtrl = TextEditingController(
      text: b?.accountHolderName ??
          pre?.accountHolderName ??
          'HEITOR FABRICIO KLAUS DE OLIVEIRA',
    );
    _holderDocCtrl = TextEditingController(
      text: b?.accountHolderDocument ?? pre?.accountHolderDocument ?? '',
    );
    _ucNumberCtrl = TextEditingController(
      text: b?.ucNumber ?? pre?.ucNumber ?? '',
    );
    _zipCodeCtrl = TextEditingController(
      text: b?.addressZipCode ?? pre?.addressZipCode ?? '',
    );
    _streetCtrl = TextEditingController(
      text: b?.addressStreet ?? pre?.addressStreet ?? '',
    );
    _neighborhoodCtrl = TextEditingController(
      text: b?.addressNeighborhood ?? pre?.addressNeighborhood ?? '',
    );
    _cityCtrl = TextEditingController(
      text: b?.addressCity ?? pre?.addressCity ?? 'Cuiabá',
    );
    _stateCtrl = TextEditingController(
      text: b?.addressState ?? pre?.addressState ?? 'MT',
    );
    _discountPercentCtrl = TextEditingController(
      text: b != null
          ? b.clientDiscountPercent.toStringAsFixed(1).replaceAll('.', ',')
          : '20,0',
    );
    _avgConsumptionCtrl = TextEditingController(
      text: b != null && b.averageMonthlyConsumptionKwh > 0
          ? b.averageMonthlyConsumptionKwh.toStringAsFixed(0)
          : (pre != null && pre.consumptionKwh > 0
              ? pre.consumptionKwh.toStringAsFixed(0)
              : ''),
    );
    _accumulatedBalanceCtrl = TextEditingController(
      text: b != null && b.lastAccumulatedBalanceKwh > 0
          ? b.lastAccumulatedBalanceKwh.toStringAsFixed(0)
          : (pre != null && pre.accumulatedBalanceKwh > 0
              ? pre.accumulatedBalanceKwh.toStringAsFixed(0)
              : '0'),
    );

    _connectionType = b?.connectionType ?? pre?.connectionType ?? 'Trifásico';
    if (!['Monofásico', 'Bifásico', 'Trifásico'].contains(_connectionType)) {
      _connectionType = 'Trifásico';
    }

    if (b != null) {
      for (final alloc in b.effectivePlantAllocations) {
        SolarGeneratorPlantModel? matched;
        for (final p in _plants) {
          if (p.id == alloc.generatorPlantId ||
              p.name.trim().toUpperCase() ==
                  alloc.generatorPlantName.trim().toUpperCase()) {
            matched = p;
            break;
          }
        }
        _plantDrafts.add(
          _PlantAllocationDraft(
            plant: matched,
            fallbackPlantId: alloc.generatorPlantId,
            fallbackPlantName: alloc.generatorPlantName,
            regime: matched?.regime ?? alloc.generatorRegime,
            initialPercent:
                alloc.allocationPercent.toStringAsFixed(2).replaceAll('.', ','),
          ),
        );
      }
      if (_plantDrafts.isNotEmpty) {
        _regime = _plantDrafts.first.regime;
      }
    } else {
      SolarGeneratorPlantModel? initialPlant;
      if (widget.initialPlantId != null && widget.initialPlantId!.isNotEmpty) {
        for (final p in _plants) {
          if (p.id == widget.initialPlantId) {
            initialPlant = p;
            break;
          }
        }
      }
      initialPlant ??= _plants.isNotEmpty ? _plants.first : null;
      _regime = initialPlant?.regime ??
          (pre != null && (pre.gdAdjustmentValueRs > 0 || pre.injectedGdiiKwh > 0)
              ? GdRegime.gd2
              : GdRegime.gd1);
      _plantDrafts.add(
        _PlantAllocationDraft(
          plant: initialPlant,
          fallbackPlantId: initialPlant?.id ?? 'default_plant',
          fallbackPlantName: initialPlant?.name ?? 'Usina Solar Principal',
          regime: _regime,
          initialPercent: '10,00',
        ),
      );
    }
  }

  @override
  void dispose() {
    _clientNameCtrl.dispose();
    _clientPhoneCtrl.dispose();
    _clientDocCtrl.dispose();
    _holderNameCtrl.dispose();
    _holderDocCtrl.dispose();
    _ucNumberCtrl.dispose();
    _zipCodeCtrl.dispose();
    _streetCtrl.dispose();
    _neighborhoodCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    for (final d in _plantDrafts) {
      d.dispose();
    }
    _discountPercentCtrl.dispose();
    _avgConsumptionCtrl.dispose();
    _accumulatedBalanceCtrl.dispose();
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

  Future<void> _lookupCep(String rawCep) async {
    final digits = rawCep.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length != 8) return;

    setState(() => _isLookingUpCep = true);
    try {
      final res = await http.get(
        Uri.parse('https://viacep.com.br/ws/$digits/json/'),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['erro'] != true && mounted) {
          setState(() {
            if ((data['logradouro'] ?? '').toString().isNotEmpty &&
                _streetCtrl.text.trim().isEmpty) {
              _streetCtrl.text = data['logradouro'].toString().toUpperCase();
            }
            if ((data['bairro'] ?? '').toString().isNotEmpty) {
              _neighborhoodCtrl.text = data['bairro'].toString().toUpperCase();
            }
            if ((data['localidade'] ?? '').toString().isNotEmpty) {
              _cityCtrl.text = data['localidade'].toString();
            }
            if ((data['uf'] ?? '').toString().isNotEmpty) {
              _stateCtrl.text = data['uf'].toString().toUpperCase();
            }
          });
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLookingUpCep = false);
    }
  }

  Future<void> _createNewPlantInline([int? assignToDraftIndex]) async {
    final created = await GeneratorPlantFormDialog.show(
      context,
      companyId: widget.companyId,
      repository: widget.repository,
    );
    if (created != null && mounted) {
      setState(() {
        _plants.add(created);
        if (assignToDraftIndex != null &&
            assignToDraftIndex >= 0 &&
            assignToDraftIndex < _plantDrafts.length) {
          _plantDrafts[assignToDraftIndex].plant = created;
          _plantDrafts[assignToDraftIndex].regime = created.regime;
        } else if (_plantDrafts.isNotEmpty && _plantDrafts.first.plant == null) {
          _plantDrafts.first.plant = created;
          _plantDrafts.first.regime = created.regime;
        } else {
          _plantDrafts.add(
            _PlantAllocationDraft(
              plant: created,
              fallbackPlantId: created.id,
              fallbackPlantName: created.name,
              regime: created.regime,
              initialPercent: '10,00',
            ),
          );
        }
      });
    }
  }

  void _addAnotherPlantRow() {
    setState(() {
      // Sugere uma usina diferente da primeira se houver mais de uma
      final usedIds = _plantDrafts
          .map((d) => d.plant?.id ?? d.fallbackPlantId)
          .toSet();
      SolarGeneratorPlantModel? nextPlant;
      for (final p in _plants) {
        if (!usedIds.contains(p.id)) {
          nextPlant = p;
          break;
        }
      }
      nextPlant ??= _plants.isNotEmpty ? _plants.first : null;
      _plantDrafts.add(
        _PlantAllocationDraft(
          plant: nextPlant,
          fallbackPlantId: nextPlant?.id ?? 'default_plant',
          fallbackPlantName: nextPlant?.name ?? 'Usina Solar',
          regime: nextPlant?.regime ?? GdRegime.gd2,
          initialPercent: '10,00',
        ),
      );
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();
      final allocations = _plantDrafts.map((d) {
        final p = d.plant;
        return BeneficiaryPlantAllocationItem(
          generatorPlantId: p?.id ??
              (d.fallbackPlantId.isNotEmpty
                  ? d.fallbackPlantId
                  : 'default_plant'),
          generatorPlantName: p?.name ??
              (d.fallbackPlantName.isNotEmpty
                  ? d.fallbackPlantName
                  : 'Usina Solar Principal'),
          generatorRegime: p?.regime ?? d.regime,
          allocationPercent: _parseNum(d.percentCtrl.text),
        );
      }).toList();

      final primary = allocations.first;

      final model = SolarCreditBeneficiaryModel(
        id: widget.beneficiary?.id ?? '',
        companyId: widget.companyId,
        clientName: _clientNameCtrl.text.trim(),
        clientPhone: _clientPhoneCtrl.text.trim(),
        clientDocument: _clientDocCtrl.text.trim(),
        accountHolderName: _holderNameCtrl.text.trim(),
        accountHolderDocument: _holderDocCtrl.text.trim(),
        ucNumber: _ucNumberCtrl.text.trim(),
        addressStreet: _streetCtrl.text.trim(),
        addressNeighborhood: _neighborhoodCtrl.text.trim(),
        addressCity: _cityCtrl.text.trim(),
        addressState: _stateCtrl.text.trim(),
        addressZipCode: _zipCodeCtrl.text.trim(),
        connectionType: _connectionType,
        generatorPlantId: primary.generatorPlantId,
        generatorPlantName: primary.generatorPlantName,
        generatorRegime: primary.generatorRegime,
        utilityAllocationPercent: primary.allocationPercent,
        plantAllocations: allocations,
        clientDiscountPercent: _parseNum(_discountPercentCtrl.text),
        averageMonthlyConsumptionKwh: _parseNum(_avgConsumptionCtrl.text),
        lastAccumulatedBalanceKwh: _parseNum(_accumulatedBalanceCtrl.text),
        lastInjectedKwh: widget.beneficiary?.lastInjectedKwh ??
            widget.prefillFromBill?.totalInjectedKwh ??
            0.0,
        lastReferenceMonth: widget.beneficiary?.lastReferenceMonth ??
            widget.prefillFromBill?.referenceMonth,
        createdAt: widget.beneficiary?.createdAt ?? now,
        updatedAt: now,
      );

      final savedId = await widget.repository.saveBeneficiary(
        model,
        companyId: widget.companyId,
      );

      if (mounted) {
        Navigator.pop(context, model.copyWith(id: savedId));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar cliente/UC: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.beneficiary != null;

    return Dialog(
      backgroundColor: const Color(0xFF0F172A),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF334155)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.person_add_alt_1_rounded,
                        color: Color(0xFF10B981),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEdit
                                ? 'Editar Cliente / UC Beneficiária'
                                : 'Novo Cliente Recebedor de Créditos (UC)',
                            style: GoogleFonts.outfit(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Vincule o cliente real, o titular na concessionária, a usina de origem, % de rateio e deságio',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white70),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // SEÇÃO 1: CLIENTE REAL vs TITULAR DA CONTA NA ENERGISA
                _buildSectionHeader(
                  '1. IDENTIFICAÇÃO DO CLIENTE E TITULAR DA CONTA',
                  Icons.people_alt_rounded,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildTextField(
                        controller: _clientNameCtrl,
                        label: 'Nome do Cliente (Quem paga pelos créditos) *',
                        hint: 'Ex: Supermercado Bom Preço / João Silva',
                        icon: Icons.person_rounded,
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Informe o nome do cliente'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: _buildTextField(
                        controller: _clientPhoneCtrl,
                        label: 'WhatsApp do Cliente',
                        hint: 'Ex: (65) 99999-9999',
                        icon: Icons.phone_android_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildTextField(
                        controller: _holderNameCtrl,
                        label:
                            'Titular da Conta na Concessionária (Seu Nome / Empresa) *',
                        hint: 'Ex: HEITOR FABRICIO KLAUS DE OLIVEIRA',
                        icon: Icons.assignment_ind_outlined,
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Informe o titular da conta'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: _buildTextField(
                        controller: _ucNumberCtrl,
                        label: 'Número da UC na Concessionária *',
                        hint: 'Ex: 2.024.081.017-07',
                        icon: Icons.bolt_rounded,
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Informe o número da UC'
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // SEÇÃO 2: ENDEREÇO DA UNIDADE CONSUMIDORA
                _buildSectionHeader(
                  '2. ENDEREÇO DA UNIDADE CONSUMIDORA (COM VIACEP)',
                  Icons.location_on_outlined,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildTextField(
                        controller: _zipCodeCtrl,
                        label: 'CEP (Busca Automática)',
                        hint: '78040-600',
                        icon: _isLookingUpCep
                            ? Icons.hourglass_top_rounded
                            : Icons.search_rounded,
                        onChanged: (val) {
                          if (val.replaceAll(RegExp(r'[^0-9]'), '').length ==
                              8) {
                            _lookupCep(val);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 4,
                      child: _buildTextField(
                        controller: _streetCtrl,
                        label: 'Endereço da UC (Rua, Número, Complemento) *',
                        hint: 'Ex: RUA ALFENAS, 120',
                        icon: Icons.home_work_outlined,
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Informe o endereço da UC'
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildTextField(
                        controller: _neighborhoodCtrl,
                        label: 'Bairro',
                        hint: 'JARDIM MARIANA',
                        icon: Icons.map_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: _buildTextField(
                        controller: _cityCtrl,
                        label: 'Cidade',
                        hint: 'Cuiabá',
                        icon: Icons.location_city_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: _buildTextField(
                        controller: _stateCtrl,
                        label: 'UF',
                        hint: 'MT',
                        icon: Icons.flag_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // SEÇÃO 3: USINAS ORIGEM (1 OU MAIS), % NA CONCESSIONÁRIA E % DE DESCONTO (DESÁGIO)
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _buildSectionHeader(
                      '3. USINAS GERADORAS VINCULADAS, RATEIO (%) E DESCONTO (DESÁGIO %)',
                      Icons.solar_power_rounded,
                    ),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        TextButton.icon(
                          onPressed: _createNewPlantInline,
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFF59E0B),
                          ),
                          icon: const Icon(Icons.add_business_rounded, size: 16),
                          label: Text(
                            'Cadastrar Nova Usina',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _addAnotherPlantRow,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color(0xFFF59E0B).withValues(alpha: 0.2),
                            foregroundColor: const Color(0xFFF59E0B),
                            elevation: 0,
                            side: const BorderSide(color: Color(0xFFF59E0B)),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.add_circle_outline_rounded,
                              size: 16),
                          label: Text(
                            '+ ADICIONAR OUTRA USINA NESTE CLIENTE',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Lista dinâmica de Usinas que enviam créditos para este cliente
                ...List.generate(_plantDrafts.length, (idx) {
                  final draft = _plantDrafts[idx];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B).withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          flex: 6,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _plantDrafts.length > 1
                                    ? 'Usina Origem #${idx + 1} (De onde vêm os créditos) *'
                                    : 'Usina Origem de Geração (De onde vêm os créditos) *',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFCBD5E1),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFF334155),
                                  ),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _plants.any(
                                            (p) => p.id == draft.plant?.id)
                                        ? draft.plant?.id
                                        : null,
                                    isExpanded: true,
                                    dropdownColor: const Color(0xFF0F172A),
                                    hint: Text(
                                      draft.fallbackPlantName.isNotEmpty
                                          ? '${draft.fallbackPlantName} (${draft.regime.shortLabel})'
                                          : 'Selecione a Usina Geradora',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: Colors.white,
                                      ),
                                    ),
                                    items: _plants.map((p) {
                                      return DropdownMenuItem<String>(
                                        value: p.id,
                                        child: Text(
                                          '${p.name} • [${p.regime.shortLabel}] • Geração: ${p.estimatedMonthlyGenerationKwh.toStringAsFixed(0)} kWh/mês',
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
                                      final found = _plants
                                          .firstWhere((e) => e.id == val);
                                      setState(() {
                                        draft.plant = found;
                                        draft.fallbackPlantId = found.id;
                                        draft.fallbackPlantName = found.name;
                                        draft.regime = found.regime;
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 4,
                          child: _buildTextField(
                            controller: draft.percentCtrl,
                            label:
                                '% na Energisa (${draft.plant?.name ?? "Nesta Usina"}) *',
                            hint: 'Ex: 15,00',
                            icon: Icons.pie_chart_outline_rounded,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ),
                        if (_plantDrafts.length > 1) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: 'Remover esta usina do cliente',
                            onPressed: () {
                              setState(() {
                                final removed = _plantDrafts.removeAt(idx);
                                removed.dispose();
                              });
                            },
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: Color(0xFFEF4444),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _discountPercentCtrl,
                        label: 'Desconto / Deságio do Cliente (%) *',
                        hint: 'Ex: 20,0',
                        icon: Icons.discount_outlined,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        controller: _avgConsumptionCtrl,
                        label: 'Consumo Médio Mensal (kWh)',
                        hint: 'Ex: 1472',
                        icon: Icons.offline_bolt_outlined,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        controller: _accumulatedBalanceCtrl,
                        label: 'Saldo Acumulado Atual na UC (kWh)',
                        hint: 'Ex: 4160',
                        icon: Icons.account_balance_wallet_outlined,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Botões de ação
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed:
                          _isSaving ? null : () => Navigator.pop(context),
                      child: Text(
                        'CANCELAR',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF94A3B8),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_circle_outline_rounded,
                              size: 18),
                      label: Text(
                        isEdit ? 'SALVAR ALTERAÇÕES' : 'CADASTRAR CLIENTE / UC',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: const Color(0xFF38BDF8)),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF38BDF8),
              letterSpacing: 0.8,
            ),
          ),
        ),
      ],
    );
  }
}

Widget _buildTextField({
  required TextEditingController controller,
  required String label,
  required String hint,
  required IconData icon,
  TextInputType? keyboardType,
  String? Function(String?)? validator,
  ValueChanged<String>? onChanged,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: const Color(0xFFCBD5E1),
        ),
      ),
      const SizedBox(height: 6),
      TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        onChanged: onChanged,
        style: GoogleFonts.inter(color: Colors.white, fontSize: 13.5),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(
            color: const Color(0xFF64748B),
            fontSize: 12.5,
          ),
          prefixIcon: Icon(icon, color: const Color(0xFF94A3B8), size: 18),
          filled: true,
          fillColor: const Color(0xFF1E293B),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF334155)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF334155)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
          ),
        ),
      ),
    ],
  );
}
