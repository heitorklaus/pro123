import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../app/theme/app_colors.dart';
import '../../auth/data/repositories/auth_repository.dart';
import '../../proposals/domain/models/proposal_item_model.dart';
import '../../proposals/presentation/widgets/proposal_product_picker_dialog.dart';
import '../data/repositories/product_repository.dart';
import '../domain/models/category_model.dart';
import '../domain/models/product_model.dart';
import 'widgets/solar_pdf_import_dialog.dart';

/// Formatador de máscara monetária brasileira (R$ 0,00) em tempo real
class CurrencyPtBrInputFormatter extends TextInputFormatter {
  static final NumberFormat _currencyFormatter =
      NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final double value = double.parse(digitsOnly) / 100.0;
    final String formatted = _currencyFormatter.format(value);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  /// Converte texto formatado (ex: "R$ 18.900,00" ou "18900.00") em double
  static double parse(String? text) {
    if (text == null || text.trim().isEmpty) return 0.0;
    final digitsOnly = text.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.isEmpty) return 0.0;
    return (double.tryParse(digitsOnly) ?? 0.0) / 100.0;
  }

  /// Formata um double para moeda brasileira (ex: 18900.0 -> "R$ 18.900,00")
  static String format(double? value) {
    if (value == null || value <= 0) return '';
    return _currencyFormatter.format(value);
  }
}

/// Item de Serviço Adicional na Usina Solar
class AdditionalServiceItem {
  final TextEditingController typeCtrl;
  final TextEditingController priceCtrl;

  AdditionalServiceItem({String type = '', double price = 0.0})
      : typeCtrl = TextEditingController(text: type),
        priceCtrl = TextEditingController(
            text: price > 0 ? CurrencyPtBrInputFormatter.format(price) : '');

  void dispose() {
    typeCtrl.dispose();
    priceCtrl.dispose();
  }
}

/// Formulário Especial de Cadastro & Edição de Usina Solar / Conjunto de Produtos
class SolarPlantFormCard extends StatefulWidget {
  final CategoryModel category;
  final ProductModel? product;
  final VoidCallback onBack;
  final VoidCallback? onChangeSector;
  final VoidCallback onSuccess;
  final ValueChanged<ProposalItemModel>? onProceedToProposal;
  final String? customProceedDescription;
  final String? customProceedActionLabel;

  const SolarPlantFormCard({
    super.key,
    required this.category,
    this.product,
    required this.onBack,
    this.onChangeSector,
    required this.onSuccess,
    this.onProceedToProposal,
    this.customProceedDescription,
    this.customProceedActionLabel,
  });

  @override
  State<SolarPlantFormCard> createState() => _SolarPlantFormCardState();
}

class _SolarPlantFormCardState extends State<SolarPlantFormCard> {
  late final ProductRepository _repo;

  // 1. Descrição da Usina
  final _nameCtrl = TextEditingController();
  final _skuCtrl = TextEditingController();

  // 2. Tipo de Cobertura (Dropdown com 7 opções)
  static const List<String> _roofTypes = [
    'Cerâmico',
    'Metálico',
    'Isotérmico',
    'Fibrocimento',
    'Solo',
    'Laje',
    'Sem Estrutura',
  ];
  String _selectedRoofType = 'Cerâmico';

  // Potência da Usina (kWp) - Importado do PDF ou digitado
  final _kilowattsCtrl = TextEditingController();

  // 4. Geração Estimada (kWh/mês) - Informado pelo usuário
  final _generationKwhCtrl = TextEditingController();

  // 3. Produtos do Conjunto (Múltiplos Produtos)
  final List<ProposalItemModel> _items = [];

  // 5. Preço dos Produtos (autocompletado com máscara, mas editável)
  final _productsPriceCtrl = TextEditingController();
  bool _isManualProductsPrice = false;

  // 6. Preço do Serviço (com máscara de moeda R$)
  final _servicePriceCtrl = TextEditingController();

  // 7. Serviços Adicionais
  final List<AdditionalServiceItem> _additionalServices = [];

  // Estoque e Notas
  final _stockCtrl = TextEditingController(text: '1');
  final _notesCtrl = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    try {
      _repo = Modular.get<ProductRepository>();
    } catch (_) {
      _repo = ProductRepository();
    }

    if (_isEditing) {
      final p = widget.product!;
      _nameCtrl.text = p.name;
      _skuCtrl.text = p.sku ?? '';
      _stockCtrl.text = p.stockQuantity.toStringAsFixed(0);
      _notesCtrl.text = p.description ?? '';

      final attrs = p.specificAttributes;
      if (attrs['roofType'] != null && _roofTypes.contains(attrs['roofType'])) {
        _selectedRoofType = attrs['roofType'] as String;
      }
      if (attrs['kilowatts'] != null) {
        _kilowattsCtrl.text = attrs['kilowatts'].toString();
      }
      if (attrs['generationKwh'] != null) {
        _generationKwhCtrl.text = attrs['generationKwh'].toString();
      }
      if (attrs['servicePrice'] != null) {
        final sp = (attrs['servicePrice'] as num).toDouble();
        _servicePriceCtrl.text = CurrencyPtBrInputFormatter.format(sp);
      }
      if (attrs['productsPrice'] != null) {
        final pp = (attrs['productsPrice'] as num).toDouble();
        _productsPriceCtrl.text = CurrencyPtBrInputFormatter.format(pp);
        _isManualProductsPrice = true;
      }

      // Recupera itens do conjunto
      if (attrs['items'] is List) {
        final rawItems = attrs['items'] as List;
        for (final itemMap in rawItems) {
          if (itemMap is Map) {
            _items.add(ProposalItemModel.fromMap(Map<String, dynamic>.from(itemMap)));
          }
        }
      }

      // Recupera serviços adicionais
      if (attrs['additionalServices'] is List) {
        final rawServs = attrs['additionalServices'] as List;
        for (final sMap in rawServs) {
          if (sMap is Map) {
            final t = sMap['type'] as String? ?? '';
            final p = (sMap['price'] as num?)?.toDouble() ?? 0.0;
            _additionalServices.add(AdditionalServiceItem(type: t, price: p));
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _skuCtrl.dispose();
    _kilowattsCtrl.dispose();
    _generationKwhCtrl.dispose();
    _productsPriceCtrl.dispose();
    _servicePriceCtrl.dispose();
    _stockCtrl.dispose();
    _notesCtrl.dispose();
    for (final s in _additionalServices) {
      s.dispose();
    }
    super.dispose();
  }

  // Cálculos reativos com parsing de moeda
  double get _calculatedProductsSum =>
      _items.fold(0.0, (acc, item) => acc + item.totalPrice);

  double get _productsPrice {
    if (_isManualProductsPrice && _productsPriceCtrl.text.isNotEmpty) {
      return CurrencyPtBrInputFormatter.parse(_productsPriceCtrl.text);
    }
    return _calculatedProductsSum;
  }

  double get _servicePrice =>
      CurrencyPtBrInputFormatter.parse(_servicePriceCtrl.text);

  double get _additionalServicesSum => _additionalServices.fold(
      0.0, (acc, s) => acc + CurrencyPtBrInputFormatter.parse(s.priceCtrl.text));

  double get _totalUsinaPrice =>
      _productsPrice + _servicePrice + _additionalServicesSum;

  void _syncProductsPriceIfAuto() {
    if (!_isManualProductsPrice) {
      final sum = _calculatedProductsSum;
      _productsPriceCtrl.text = CurrencyPtBrInputFormatter.format(sum);
    }
  }

  /// Calcula automaticamente a potência da usina (kWp) com base nos módulos fotovoltaicos adicionados
  void _recalculatePlantKilowatts() {
    double totalWatts = 0.0;
    bool foundModule = false;

    for (final item in _items) {
      final watts = item.effectiveModuleWatts;
      if (watts != null && watts > 0 && (item.isSolarModule || item.moduleWatts != null)) {
        totalWatts += (watts * item.quantity);
        foundModule = true;
      }
    }

    if (foundModule && totalWatts > 0) {
      final kwp = totalWatts / 1000.0;
      // Formatação limpa: ex. 5.0 para 5000W, 10.44 para 10440W
      final kwpStr = kwp % 1 == 0
          ? kwp.toStringAsFixed(1)
          : (kwp * 10 % 1 == 0 ? kwp.toStringAsFixed(1) : kwp.toStringAsFixed(2));
      _kilowattsCtrl.text = kwpStr;
    }
  }

  void _openPdfImportDialog() {
    showDialog(
      context: context,
      builder: (ctx) => SolarPdfImportDialog(
        onProposalImported: (parsed) {
          setState(() {
            _nameCtrl.text = parsed.plantName;
            _skuCtrl.text = parsed.proposalNumber;
            _selectedRoofType = parsed.roofType;
            // O campo Potência da Usina (kWp) recebe o valor importado da cotação
            _kilowattsCtrl.text = parsed.kilowatts > 0 ? parsed.kilowatts.toStringAsFixed(2) : '';
            // O campo Geração em kWh fica vazio para o usuário informar (ou recebe se a cotação tiver)
            _generationKwhCtrl.text = (parsed.generationKwh != null && parsed.generationKwh! > 0)
                ? parsed.generationKwh!.toStringAsFixed(0)
                : '';
            // Define o Preço dos Produtos diretamente com o Valor Total do orçamento PDF
            _productsPriceCtrl.text = CurrencyPtBrInputFormatter.format(parsed.totalAmount);
            _isManualProductsPrice = true;

            // Preenche os itens do conjunto
            _items.clear();
            for (final it in parsed.items) {
              _items.add(it.toProposalItem());
            }

            // Não adiciona frete como serviço adicional (o frete já está consolidado no valor total)
            _additionalServices.clear();

            _recalculatePlantKilowatts();
          });
        },
      ),
    );
  }

  void _openProductPicker() {
    showDialog(
      context: context,
      builder: (ctx) => ProposalProductPickerDialog(
        excludeSolarPlants: true,
        onItemSelected: (newItem) {
          setState(() {
            _items.add(newItem);
            _syncProductsPriceIfAuto();
            _recalculatePlantKilowatts();
          });
        },
      ),
    );
  }

  void _updateItemQuantity(int index, double newQty) {
    if (newQty <= 0) return;
    setState(() {
      final item = _items[index];
      _items[index] = item.copyWith(quantity: newQty);
      _syncProductsPriceIfAuto();
      _recalculatePlantKilowatts();
    });
  }

  void _updateItemPrice(int index, double newPrice) {
    if (newPrice < 0) return;
    setState(() {
      final item = _items[index];
      _items[index] = item.copyWith(unitPrice: newPrice);
      _syncProductsPriceIfAuto();
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
      _syncProductsPriceIfAuto();
      _recalculatePlantKilowatts();
    });
  }

  void _addAdditionalService() {
    setState(() {
      _additionalServices.add(AdditionalServiceItem());
    });
  }

  void _removeAdditionalService(int index) {
    setState(() {
      _additionalServices[index].dispose();
      _additionalServices.removeAt(index);
    });
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Informe a descrição da Usina Solar.');
      return;
    }

    if (_items.isEmpty) {
      setState(() => _errorMessage = 'Adicione ao menos um produto/equipamento ao conjunto da usina.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final kilowatts = double.tryParse(_kilowattsCtrl.text.replaceAll(',', '.')) ?? 0.0;
      final generationKwh = double.tryParse(_generationKwhCtrl.text.replaceAll(',', '.')) ?? 0.0;
      final stock = double.tryParse(_stockCtrl.text.replaceAll(',', '.')) ?? 1.0;

      // Monta os atributos específicos da Usina Solar
      final specificAttributes = <String, dynamic>{
        'isSolarPlantKit': true,
        'roofType': _selectedRoofType,
        'kilowatts': kilowatts,
        'generationKwh': generationKwh,
        'productsPrice': _productsPrice,
        'servicePrice': _servicePrice,
        'additionalServicesSum': _additionalServicesSum,
        'items': _items.map((i) => i.toMap()).toList(),
        'additionalServices': _additionalServices.map((s) => {
          'type': s.typeCtrl.text.trim(),
          'price': CurrencyPtBrInputFormatter.parse(s.priceCtrl.text),
        }).toList(),
      };

      ProductModel savedProduct;
      if (_isEditing) {
        final updated = widget.product!.copyWith(
          name: name,
          sku: _skuCtrl.text.trim().isNotEmpty ? _skuCtrl.text.trim() : null,
          sector: ProductSector.solarPlant,
          categoryTitle: 'Usina Solar',
          description: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
          salePrice: _totalUsinaPrice,
          costPrice: _calculatedProductsSum,
          stockQuantity: stock,
          unit: ProductUnit.un,
          specificAttributes: specificAttributes,
        );
        await _repo.updateProduct(updated);
        savedProduct = updated;
      } else {
        AuthRepository auth;
        try {
          auth = Modular.get<AuthRepository>();
        } catch (_) {
          auth = AuthRepository();
        }
        final companyId = await auth.getCurrentCompanyId();

        savedProduct = await _repo.createProduct(
          name: name,
          sku: _skuCtrl.text.trim().isNotEmpty ? _skuCtrl.text.trim() : null,
          sector: ProductSector.solarPlant,
          categoryTitle: 'Usina Solar',
          description: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
          salePrice: _totalUsinaPrice,
          costPrice: _calculatedProductsSum,
          stockQuantity: stock,
          minStock: 1,
          unit: ProductUnit.un,
          specificAttributes: specificAttributes,
          companyId: companyId,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isEditing ? 'Usina Solar atualizada com sucesso!' : 'Usina Solar cadastrada com sucesso!'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ));

        final proposalItem = ProposalItemModel.fromProduct(savedProduct);

        if (widget.onProceedToProposal != null) {
          _showProceedToProposalDialog(proposalItem);
        } else {
          widget.onSuccess();
        }
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Erro ao salvar usina solar: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showProceedToProposalDialog(ProposalItemModel proposalItem) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        contentPadding: const EdgeInsets.all(28),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF59E0B), Color(0xFFEA580C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEA580C).withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(Icons.solar_power_rounded, color: Colors.white, size: 30),
            ),
            const SizedBox(height: 20),
            Text(
              'Usina Salva com Sucesso!',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.customProceedDescription ??
                  'Deseja prosseguir com essa usina em uma nova proposta comercial?',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF64748B),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    proposalItem.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: const Color(0xFF92400E),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (proposalItem.solarKilowatts != null && proposalItem.solarKilowatts! > 0)
                        Text(
                          '⚡ ${proposalItem.solarKilowatts!.toStringAsFixed(2)} kWp',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFFD97706)),
                        ),
                      Text(
                        'R\$ ${proposalItem.totalPrice.toStringAsFixed(2).replaceAll('.', ',')}',
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      widget.onSuccess();
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    child: Text(
                      'NÃO, VOLTAR AO CATÁLOGO',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 11.5,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      widget.onProceedToProposal?.call(proposalItem);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 3,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.note_add_rounded, size: 16, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          widget.customProceedActionLabel ?? 'SIM, CRIAR PROPOSTA',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 11.5,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    const solarColor = Color(0xFFF59E0B);
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      constraints: const BoxConstraints(maxWidth: 1040),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: solarColor.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: solarColor.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: EdgeInsets.all(isMobile ? 14 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Cabeçalho do Formulário de Usina Solar ────────────────────────
          if (isMobile) ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: solarColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: solarColor.withValues(alpha: 0.4)),
                  ),
                  child: const Icon(Icons.solar_power_rounded, color: Color(0xFFD97706), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isEditing ? 'Editar Usina Solar' : 'Cadastro de Usina',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: solarColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'KIT COMPLETO',
                          style: GoogleFonts.inter(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFD97706),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _openPdfImportDialog,
                      borderRadius: BorderRadius.circular(10),
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF59E0B), Color(0xFFEA580C)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.document_scanner_rounded, color: Colors.white, size: 15),
                            SizedBox(width: 6),
                            Text(
                              'IMPORTAR PDF / IA',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: widget.onBack,
                    borderRadius: BorderRadius.circular(10),
                    child: Ink(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.arrow_back_rounded, size: 16, color: Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Text('Voltar', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12, color: const Color(0xFF64748B))),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: solarColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: solarColor.withValues(alpha: 0.4)),
                        ),
                        child: const Icon(Icons.solar_power_rounded, color: Color(0xFFD97706), size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    _isEditing ? 'Editar Usina Solar' : 'Cadastro de Usina Solar',
                                    style: GoogleFonts.outfit(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF0F172A),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: solarColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'CONJUNTO DE PRODUTOS',
                                    style: GoogleFonts.inter(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFFD97706),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Monte o kit com inversor, módulos fotovoltaicos, estruturas, cabeamento e serviços',
                              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _openPdfImportDialog,
                        borderRadius: BorderRadius.circular(10),
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFF59E0B), Color(0xFFEA580C)],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFEA580C).withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.document_scanner_rounded, color: Colors.white, size: 16),
                              SizedBox(width: 8),
                              Text(
                                'IMPORTAR COTAÇÃO (PDF / IA)',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: widget.onBack,
                        borderRadius: BorderRadius.circular(10),
                        child: Ink(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.arrow_back_rounded, size: 18, color: Color(0xFF64748B)),
                              const SizedBox(width: 8),
                              Text(
                                'Voltar ao Catálogo',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],

          const SizedBox(height: 16),
          const Divider(color: AppColors.divider),
          const SizedBox(height: 14),

          // ── Banner de Importação Automática de Proposta / PDF ───────────────
          Container(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 16),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Importe sua cotação em PDF / Foto',
                              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12.5, color: const Color(0xFF92400E)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'A IA analisa os dados, explode o kit com todos os equipamentos e cadastra tudo.',
                        style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFFB45309)),
                      ),
                      const SizedBox(height: 10),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _openPdfImportDialog,
                          borderRadius: BorderRadius.circular(8),
                          child: Ink(
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.file_upload_outlined, color: Colors.white, size: 15),
                                SizedBox(width: 6),
                                Text(
                                  'ENVIAR PDF / COTAÇÃO',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Importe sua cotação em PDF ou Imagem (BelEnergy, Edeltec, Fortlev, WEG, etc.)',
                              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12.5, color: const Color(0xFF92400E)),
                            ),
                            Text(
                              'O sistema analisa os dados, explode o kit com todos os equipamentos e cadastra tudo no catálogo automaticamente.',
                              style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFFB45309)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _openPdfImportDialog,
                          borderRadius: BorderRadius.circular(8),
                          child: Ink(
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.file_upload_outlined, color: Colors.white, size: 15),
                                SizedBox(width: 6),
                                Text(
                                  'ENVIAR PDF / COTAÇÃO',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.5),
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

          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                      style: GoogleFonts.inter(color: const Color(0xFF991B1B), fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── 1. DADOS PRINCIPAIS DA USINA SOLAR ────────────────────────────
          _sectionHeader(Icons.info_outline_rounded, '1. Identificação & Estrutura da Usina', 'Defina a descrição, tipo de telhado/cobertura e a potência da usina'),
          const SizedBox(height: 14),

          if (isMobile) ...[
            _label('1. Descrição da Usina *'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                hintText: 'Ex: Usina Solar 5.5 kWp Residencial - Microinversor Deye + 10x Módulos 550W',
                prefixIcon: Icon(Icons.wb_sunny_outlined, color: Color(0xFFD97706)),
              ),
            ),
            const SizedBox(height: 12),
            _label('Código SKU do Kit (Opcional)'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _skuCtrl,
              decoration: const InputDecoration(
                hintText: 'Ex: KIT-SOLAR-55',
                prefixIcon: Icon(Icons.qr_code_rounded, color: Color(0xFF64748B)),
              ),
            ),
            const SizedBox(height: 12),
            _label('2. Tipo de Cobertura / Telhado *'),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _selectedRoofType,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.roofing_rounded, color: Color(0xFF64748B)),
              ),
              items: _roofTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedRoofType = val);
              },
            ),
            const SizedBox(height: 12),
            _label('Potência da Usina (kWp) *'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _kilowattsCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                hintText: 'Ex: 25.83',
                prefixIcon: Icon(Icons.bolt_rounded, color: Color(0xFFF59E0B)),
                suffixText: 'kWp',
              ),
            ),
            const SizedBox(height: 12),
            _label('4. Geração Estimada (kWh/mês)'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _generationKwhCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                hintText: 'Ex: 3200',
                prefixIcon: Icon(Icons.electric_meter_rounded, color: Color(0xFF0284C7)),
                suffixText: 'kWh/mês',
              ),
            ),
            const SizedBox(height: 12),
            _label('Kits em Estoque'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _stockCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                hintText: '1',
                prefixIcon: Icon(Icons.inventory_2_outlined, color: Color(0xFF64748B)),
              ),
            ),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1 Descrição Usina
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('1. Descrição da Usina *'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Ex: Usina Solar 5.5 kWp Residencial - Microinversor Deye + 10x Módulos 550W',
                          prefixIcon: Icon(Icons.wb_sunny_outlined, color: Color(0xFFD97706)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),

                // SKU / Código do Kit
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Código SKU do Kit (Opcional)'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _skuCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Ex: KIT-SOLAR-55',
                          prefixIcon: Icon(Icons.qr_code_rounded, color: Color(0xFF64748B)),
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
                // 2. Tipo de Cobertura (DROPDOWN)
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('2. Tipo de Cobertura / Telhado *'),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedRoofType,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.roofing_rounded, color: Color(0xFF64748B)),
                        ),
                        items: _roofTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedRoofType = val);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),

                // Potência da Usina (kWp) - Recebe o valor importado da cotação
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Potência da Usina (kWp) *'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _kilowattsCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          hintText: 'Ex: 25.83',
                          prefixIcon: Icon(Icons.bolt_rounded, color: Color(0xFFF59E0B)),
                          suffixText: 'kWp',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),

                // 4. Geração Estimada em kWh (kWh/mês) - Informado pelo usuário
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('4. Geração Estimada (kWh/mês)'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _generationKwhCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          hintText: 'Ex: 3200',
                          prefixIcon: Icon(Icons.electric_meter_rounded, color: Color(0xFF0284C7)),
                          suffixText: 'kWh/mês',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),

                // Quantidade de Usinas em Estoque / Disponibilidade
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Kits em Estoque'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _stockCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          hintText: '1',
                          prefixIcon: Icon(Icons.inventory_2_outlined, color: Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 24),

          // ── 3. ESCOLHA DOS PRODUTOS DO CONJUNTO ───────────────────────────
          if (isMobile) ...[
            _sectionHeader(Icons.format_list_bulleted_rounded, '3. Equipamentos do Kit', 'Inversores, painéis solares, estruturas e cabos'),
            const SizedBox(height: 10),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _openProductPicker,
                borderRadius: BorderRadius.circular(10),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_shopping_cart_rounded, color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'ADICIONAR EQUIPAMENTO',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _sectionHeader(Icons.format_list_bulleted_rounded, '3. Equipamentos & Produtos do Conjunto', 'Adicione inversores, painéis solares, estruturas de fixação e cabeamento'),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _openProductPicker,
                    borderRadius: BorderRadius.circular(10),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add_shopping_cart_rounded, color: Colors.white, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'ADICIONAR PRODUTO AO CONJUNTO',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),

          // Tabela / Cards de Produtos do Kit
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Column(
                children: [
                  if (!isMobile) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      color: const Color(0xFFF8FAFC),
                      child: Row(
                        children: const [
                          SizedBox(width: 28, child: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B)))),
                          Expanded(flex: 5, child: Text('PRODUTO / EQUIPAMENTO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B)))),
                          SizedBox(width: 80, child: Center(child: Text('QTD', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B))))),
                          SizedBox(width: 50, child: Center(child: Text('UNID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B))))),
                          SizedBox(width: 120, child: Align(alignment: Alignment.centerRight, child: Text('UNITÁRIO (R\$)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B))))),
                          SizedBox(width: 120, child: Align(alignment: Alignment.centerRight, child: Text('TOTAL (R\$)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B))))),
                          SizedBox(width: 45), // Lixeira
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.divider),
                  ],

                  if (_items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const Icon(Icons.solar_power_outlined, size: 36, color: Color(0xFF94A3B8)),
                          const SizedBox(height: 8),
                          Text('Nenhum equipamento adicionado ainda', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: const Color(0xFF64748B), fontSize: 13)),
                          const SizedBox(height: 4),
                          Text('Clique no botão para adicionar módulos, inversores ou estruturas.', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF94A3B8))),
                        ],
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.divider),
                      itemBuilder: (ctx, idx) {
                        final item = _items[idx];
                        final qtyStr = item.quantity % 1 == 0 ? item.quantity.toInt().toString() : item.quantity.toString();

                        if (isMobile) {
                          return Padding(
                            key: ValueKey('solar_item_mobile_${item.productId ?? ""}_${item.name}_$idx'),
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Center(
                                        child: Text('${idx + 1}', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: const Color(0xFF475569), fontSize: 11)),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(item.name, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12.5, color: const Color(0xFF0F172A))),
                                          if (item.sku != null && item.sku!.isNotEmpty)
                                            Text('SKU: ${item.sku}', style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B))),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Remover',
                                      icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 18),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                      onPressed: () => _removeItem(idx),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    SizedBox(
                                      width: 70,
                                      child: TextFormField(
                                        key: ValueKey('qty_${item.productId ?? ""}_${item.name}_${item.quantity}'),
                                        initialValue: qtyStr,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.inter(fontSize: 12),
                                        decoration: const InputDecoration(
                                          contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                                          labelText: 'Qtd',
                                        ),
                                        onChanged: (val) {
                                          final q = double.tryParse(val.replaceAll(',', '.')) ?? 1.0;
                                          _updateItemQuantity(idx, q);
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextFormField(
                                        key: ValueKey('price_${item.productId ?? ""}_${item.name}_${item.unitPrice}'),
                                        initialValue: item.unitPrice.toStringAsFixed(2),
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        textAlign: TextAlign.right,
                                        style: GoogleFonts.inter(fontSize: 12),
                                        decoration: const InputDecoration(
                                          contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                          labelText: 'Unitário (R\$)',
                                        ),
                                        onChanged: (val) {
                                          final p = double.tryParse(val.replaceAll(',', '.')) ?? 0.0;
                                          _updateItemPrice(idx, p);
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text('Total', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B))),
                                        Text(
                                          currencyFormat.format(item.totalPrice),
                                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12.5, color: const Color(0xFF0F172A)),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }

                        return Padding(
                          key: ValueKey('solar_item_row_${item.productId ?? ""}_${item.name}_${item.quantity}_${item.unitPrice}_$idx'),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 28,
                                child: Text('${idx + 1}', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: const Color(0xFF64748B), fontSize: 12)),
                              ),
                              // Descrição
                              Expanded(
                                flex: 5,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.name, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: const Color(0xFF0F172A))),
                                    if (item.sku != null && item.sku!.isNotEmpty)
                                      Text('SKU: ${item.sku}', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                                  ],
                                ),
                              ),
                              // Quantidade
                              SizedBox(
                                width: 80,
                                child: TextFormField(
                                  key: ValueKey('qty_${item.productId ?? ""}_${item.name}_${item.quantity}'),
                                  initialValue: qtyStr,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(fontSize: 12.5),
                                  decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8)),
                                  onChanged: (val) {
                                    final q = double.tryParse(val.replaceAll(',', '.')) ?? 1.0;
                                    _updateItemQuantity(idx, q);
                                  },
                                ),
                              ),
                              // Unidade
                              SizedBox(
                                width: 50,
                                child: Center(
                                  child: Text(item.unit, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: const Color(0xFF64748B))),
                                ),
                              ),
                              // Preço Unitário
                              SizedBox(
                                width: 120,
                                child: TextFormField(
                                  key: ValueKey('price_${item.productId ?? ""}_${item.name}_${item.unitPrice}'),
                                  initialValue: item.unitPrice.toStringAsFixed(2),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  textAlign: TextAlign.right,
                                  style: GoogleFonts.inter(fontSize: 12.5),
                                  decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8)),
                                  onChanged: (val) {
                                    final p = double.tryParse(val.replaceAll(',', '.')) ?? 0.0;
                                    _updateItemPrice(idx, p);
                                  },
                                ),
                              ),
                              // Total do Item
                              SizedBox(
                                width: 120,
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    currencyFormat.format(item.totalPrice),
                                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFF0F172A)),
                                  ),
                                ),
                              ),
                              // Ação Remover
                              SizedBox(
                                width: 45,
                                child: IconButton(
                                  tooltip: 'Remover Produto',
                                  icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 18),
                                  onPressed: () => _removeItem(idx),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── 5, 6 & 7: PREÇOS, SERVIÇOS & SERVIÇO ADICIONAL ─────────────────
          _sectionHeader(Icons.payments_outlined, '5, 6 & 7. Composição Financeira & Serviços', 'Preço dos equipamentos, instalação e serviços extras'),
          const SizedBox(height: 14),

          if (isMobile) ...[
            // Mobile: Formulário Financeiro empilhado
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _label('5. Preço dos Produtos (R\$) *'),
                if (_isManualProductsPrice)
                  InkWell(
                    onTap: () {
                      setState(() {
                        _isManualProductsPrice = false;
                        _syncProductsPriceIfAuto();
                      });
                    },
                    child: Text('Recalcular soma', style: GoogleFonts.inter(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _productsPriceCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [
                CurrencyPtBrInputFormatter(),
              ],
              decoration: const InputDecoration(
                hintText: 'R\$ 0,00',
                prefixIcon: Icon(Icons.inventory_rounded, color: Color(0xFF64748B)),
              ),
              onChanged: (_) {
                setState(() {
                  _isManualProductsPrice = true;
                });
              },
            ),
            const SizedBox(height: 12),

            _label('6. Preço do Serviço / Instalação (R\$)'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _servicePriceCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [
                CurrencyPtBrInputFormatter(),
              ],
              decoration: const InputDecoration(
                hintText: 'R\$ 0,00',
                prefixIcon: Icon(Icons.handyman_outlined, color: Color(0xFF64748B)),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _label('7. Serviços Extras (Opcional)'),
                TextButton.icon(
                  icon: const Icon(Icons.add_rounded, size: 15),
                  label: const Text('Adicionar Extra'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    textStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11.5),
                  ),
                  onPressed: _addAdditionalService,
                ),
              ],
            ),
            const SizedBox(height: 6),

            if (_additionalServices.isEmpty)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  'Nenhum serviço extra incluído (ex: Reforço de Telhado).',
                  style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _additionalServices.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, sIdx) {
                  final s = _additionalServices[sIdx];
                  return Row(
                    key: ObjectKey(s),
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: s.typeCtrl,
                          decoration: const InputDecoration(
                            hintText: 'Ex: Homologação',
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: s.priceCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            CurrencyPtBrInputFormatter(),
                          ],
                          textAlign: TextAlign.right,
                          decoration: const InputDecoration(
                            hintText: 'R\$ 0,00',
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remover',
                        icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 18),
                        onPressed: () => _removeAdditionalService(sIdx),
                      ),
                    ],
                  );
                },
              ),

            const SizedBox(height: 14),
            _label('Observações Técnicas / Garantias'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Ex: Garantia de 25 anos de performance nos módulos.',
                prefixIcon: Icon(Icons.notes_rounded, color: Color(0xFF64748B)),
              ),
            ),

            const SizedBox(height: 18),

            // Card Totalizador no Mobile
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: solarColor.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _summaryRow('Preço dos Produtos:', currencyFormat.format(_productsPrice)),
                  const SizedBox(height: 6),
                  _summaryRow('Preço do Serviço:', currencyFormat.format(_servicePrice)),
                  if (_additionalServicesSum > 0) ...[
                    const SizedBox(height: 6),
                    _summaryRow('Serviços Extras:', currencyFormat.format(_additionalServicesSum)),
                  ],
                  const Divider(color: Color(0xFFFCD34D), height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF59E0B), Color(0xFFEA580C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'VALOR TOTAL DA USINA',
                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white70),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          currencyFormat.format(_totalUsinaPrice),
                          style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Desktop: Layout lado a lado
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Coluna Esquerda: Preço Produtos, Preço Serviço e Serviços Adicionais
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // 5 Preço dos produtos (com máscara Real R$, autocompletado, editável)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    _label('5. Preço dos Produtos (R\$) *'),
                                    if (_isManualProductsPrice)
                                      InkWell(
                                        onTap: () {
                                          setState(() {
                                            _isManualProductsPrice = false;
                                            _syncProductsPriceIfAuto();
                                          });
                                        },
                                        child: Text('Recalcular soma', style: GoogleFonts.inter(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold)),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _productsPriceCtrl,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    CurrencyPtBrInputFormatter(),
                                  ],
                                  decoration: const InputDecoration(
                                    hintText: 'R\$ 0,00',
                                    prefixIcon: Icon(Icons.inventory_rounded, color: Color(0xFF64748B)),
                                  ),
                                  onChanged: (_) {
                                    setState(() {
                                      _isManualProductsPrice = true;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),

                          // 6 Preço do Servico (com máscara Real R$)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label('6. Preço do Serviço / Instalação (R\$)'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _servicePriceCtrl,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    CurrencyPtBrInputFormatter(),
                                  ],
                                  decoration: const InputDecoration(
                                    hintText: 'R\$ 0,00',
                                    prefixIcon: Icon(Icons.handyman_outlined, color: Color(0xFF64748B)),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      // 7 Servico Adicional
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _label('7. Serviços Adicionais (Opcional)'),
                          TextButton.icon(
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text('Adicionar Serviço Extra'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              textStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            onPressed: _addAdditionalService,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      if (_additionalServices.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            'Nenhum serviço adicional incluído (ex: Reforço de Telhado, Adequação de Padrão). Clique acima para adicionar.',
                            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _additionalServices.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (ctx, sIdx) {
                            final s = _additionalServices[sIdx];
                            return Row(
                              key: ObjectKey(s),
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: TextFormField(
                                    controller: s.typeCtrl,
                                    decoration: const InputDecoration(
                                      hintText: 'Tipo do serviço (ex: Reforço Estrutural, Homologação)',
                                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: s.priceCtrl,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      CurrencyPtBrInputFormatter(),
                                    ],
                                    textAlign: TextAlign.right,
                                    decoration: const InputDecoration(
                                      hintText: 'R\$ 0,00',
                                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    ),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                IconButton(
                                  tooltip: 'Remover',
                                  icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
                                  onPressed: () => _removeAdditionalService(sIdx),
                                ),
                              ],
                            );
                          },
                        ),

                      const SizedBox(height: 16),
                      _label('Observações Técnicas / Garantias'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _notesCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          hintText: 'Ex: Garantia de 25 anos de performance nos módulos e 10 anos no inversor. Homologação inclusa.',
                          prefixIcon: Icon(Icons.notes_rounded, color: Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 24),

                // Coluna Direita: TOTALIZADOR AUTOMÁTICO EM TEMPO REAL
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB), // Fundo âmbar suave
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: solarColor.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.calculate_rounded, color: Color(0xFFD97706), size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'SOMA TOTALIZADORA',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF92400E), letterSpacing: 0.5),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        _summaryRow('Preço dos Produtos:', currencyFormat.format(_productsPrice)),
                        const SizedBox(height: 8),
                        _summaryRow('Preço do Serviço:', currencyFormat.format(_servicePrice)),
                        const SizedBox(height: 8),
                        if (_additionalServicesSum > 0) ...[
                          _summaryRow('Serviços Adicionais:', currencyFormat.format(_additionalServicesSum)),
                          const SizedBox(height: 8),
                        ],

                        const Divider(color: Color(0xFFFCD34D)),
                        const SizedBox(height: 8),

                        // Card de Total Geral da Usina Solar
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFF59E0B), Color(0xFFEA580C)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFEA580C).withValues(alpha: 0.25),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'VALOR TOTAL DA USINA SOLAR',
                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                currencyFormat.format(_totalUsinaPrice),
                                style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              if (_items.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '${_items.length} ${_items.length == 1 ? 'equipamento' : 'equipamentos'} inclusos',
                                  style: GoogleFonts.inter(fontSize: 11, color: Colors.white70),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 32),
          const Divider(color: AppColors.divider),
          const SizedBox(height: 20),

          // ── BOTÕES DE AÇÃO NO RODAPÉ ───────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onBack,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    child: Text(
                      'CANCELAR',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _isLoading ? null : _submit,
                  borderRadius: BorderRadius.circular(12),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF59E0B), Color(0xFFEA580C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFEA580C).withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.solar_power_rounded, color: Colors.white, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                _isEditing ? 'SALVAR ALTERAÇÕES DA USINA' : 'SALVAR USINA SOLAR',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
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

  Widget _sectionHeader(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFD97706), size: 20),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
            Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
          ],
        ),
      ],
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF78350F))),
        Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
      ],
    );
  }
}
