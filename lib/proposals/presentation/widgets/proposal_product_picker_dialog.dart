import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/theme/app_colors.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../../products/data/repositories/product_repository.dart';
import '../../../products/domain/models/product_model.dart';
import '../../../suppliers/data/repositories/supplier_repository.dart';
import '../../../suppliers/domain/models/supplier_model.dart';
import '../../domain/models/proposal_item_model.dart';

enum _PickerViewMode {
  catalog,
  registerItem,
  quickCustom,
}

/// Diálogo modal para selecionar produtos do catálogo ou cadastrar novos itens/equipamentos solares
class ProposalProductPickerDialog extends StatefulWidget {
  final ValueChanged<ProposalItemModel> onItemSelected;
  final bool excludeSolarPlants;

  const ProposalProductPickerDialog({
    super.key,
    required this.onItemSelected,
    this.excludeSolarPlants = false,
  });

  @override
  State<ProposalProductPickerDialog> createState() => _ProposalProductPickerDialogState();
}

class _ProposalProductPickerDialogState extends State<ProposalProductPickerDialog> {
  late final ProductRepository _repo;
  late final SupplierRepository _supplierRepo;

  _PickerViewMode _viewMode = _PickerViewMode.catalog;
  final _searchCtrl = TextEditingController();
  String _query = '';
  String? _companyId;

  // ── Modo Item Rápido Sob Medida ──
  final _customNameCtrl = TextEditingController();
  final _customPriceCtrl = TextEditingController();
  final _customQtyCtrl = TextEditingController(text: '1');
  String _customUnit = 'UN';

  // ── Modo Novo Cadastro Completo de Equipamento / Produto ──
  final _regNameCtrl = TextEditingController();
  final _regSkuCtrl = TextEditingController();
  final _regSalePriceCtrl = TextEditingController();
  final _regCostPriceCtrl = TextEditingController();
  final _regStockCtrl = TextEditingController(text: '10');
  ProductUnit _regUnit = ProductUnit.un;
  String? _selectedSupplierId;
  String? _selectedSupplierName;
  String _selectedSubcategory = 'MÓDULO SOLAR';
  bool _isSavingNewProduct = false;

  // Subcategorias Pré-cadastradas
  static const List<Map<String, dynamic>> _solarSubcategoryOptions = [
    {
      'label': 'MÓDULO SOLAR',
      'title': 'Módulo Solar / Painel',
      'icon': Icons.solar_power_rounded,
      'color': Color(0xFFD97706),
      'bg': Color(0xFFFEF3C7),
      'placeholder': 'Ex: Módulo Solar 580W Bifacial N-Type Jinko Tiger Pro',
    },
    {
      'label': 'INVERSOR SOLAR',
      'title': 'Inversor String / Central',
      'icon': Icons.offline_bolt_rounded,
      'color': Color(0xFF0284C7),
      'bg': Color(0xFFE0F2FE),
      'placeholder': 'Ex: Inversor Solar On-Grid Trifásico 15kW Growatt MID',
    },
    {
      'label': 'MICROINVERSOR',
      'title': 'Microinversor',
      'icon': Icons.bolt_rounded,
      'color': Color(0xFF4F46E5),
      'bg': Color(0xFFEEF2FF),
      'placeholder': 'Ex: Microinversor Solar 2250W Hoymiles HMS-2000-4T',
    },
    {
      'label': 'BATERIA',
      'title': 'Bateria / Armazenamento',
      'icon': Icons.battery_charging_full_rounded,
      'color': Color(0xFF059669),
      'bg': Color(0xFFD1FAE5),
      'placeholder': 'Ex: Bateria de Lítio LiFePO4 5.12kWh 51.2V 100Ah Growatt AXE',
    },
    {
      'label': 'ESTRUTURA',
      'title': 'Estrutura de Fixação',
      'icon': Icons.handyman_rounded,
      'color': Color(0xFF7C3AED),
      'bg': Color(0xFFF3E8FF),
      'placeholder': 'Ex: Estrutura Cerâmico Alumínio Perfil 4.80m com Ganchos',
    },
    {
      'label': 'CABOS & CONECTORES',
      'title': 'Cabos & Conectores',
      'icon': Icons.cable_rounded,
      'color': Color(0xFFE11D48),
      'bg': Color(0xFFFFE4E6),
      'placeholder': 'Ex: Cabo Solar 6mm² Vermelho 1.8kV DC 100 Metros',
    },
    {
      'label': 'STRING BOX',
      'title': 'String Box / Proteção',
      'icon': Icons.shield_rounded,
      'color': Color(0xFF0D9488),
      'bg': Color(0xFFCCFBF1),
      'placeholder': 'Ex: String Box Solar 2 Entradas 2 Saídas 1000V DC com DPS e Chave',
    },
    {
      'label': 'OUTRO',
      'title': 'Outro Equipamento / Acessório',
      'icon': Icons.category_rounded,
      'color': Color(0xFF64748B),
      'bg': Color(0xFFF1F5F9),
      'placeholder': 'Ex: Acessório ou Componente Fotovoltaico',
    },
  ];

  // Fichas Técnicas Dinâmicas por Equipamento:
  // 1. Módulo Solar
  final _modWattsCtrl = TextEditingController();
  final _modEffWarrCtrl = TextEditingController(text: '25');
  final _modMfgWarrCtrl = TextEditingController(text: '12');

  // 2. Inversor
  final _invPowerCtrl = TextEditingController();
  final _invOverloadCtrl = TextEditingController();
  final _invMfgWarrCtrl = TextEditingController(text: '10');

  // 3. Microinversor
  final _microPowerCtrl = TextEditingController();
  final _microOverloadCtrl = TextEditingController();
  final _microMfgWarrCtrl = TextEditingController(text: '12');

  // 4. Bateria
  final _batCapacityCtrl = TextEditingController();
  final _batVoltageCtrl = TextEditingController();
  final _batMfgWarrCtrl = TextEditingController(text: '10');

  @override
  void initState() {
    super.initState();
    try {
      _repo = Modular.get<ProductRepository>();
    } catch (_) {
      _repo = ProductRepository();
    }
    try {
      _supplierRepo = Modular.get<SupplierRepository>();
    } catch (_) {
      _supplierRepo = SupplierRepository();
    }
    _loadCompanyId();
  }

  Future<void> _loadCompanyId() async {
    try {
      AuthRepository auth;
      try {
        auth = Modular.get<AuthRepository>();
      } catch (_) {
        auth = AuthRepository();
      }
      final cid = await auth.getCurrentCompanyId();
      if (mounted) setState(() => _companyId = cid);
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _customNameCtrl.dispose();
    _customPriceCtrl.dispose();
    _customQtyCtrl.dispose();

    _regNameCtrl.dispose();
    _regSkuCtrl.dispose();
    _regSalePriceCtrl.dispose();
    _regCostPriceCtrl.dispose();
    _regStockCtrl.dispose();

    _modWattsCtrl.dispose();
    _modEffWarrCtrl.dispose();
    _modMfgWarrCtrl.dispose();

    _invPowerCtrl.dispose();
    _invOverloadCtrl.dispose();
    _invMfgWarrCtrl.dispose();

    _microPowerCtrl.dispose();
    _microOverloadCtrl.dispose();
    _microMfgWarrCtrl.dispose();

    _batCapacityCtrl.dispose();
    _batVoltageCtrl.dispose();
    _batMfgWarrCtrl.dispose();

    super.dispose();
  }

  void _addCustomItem() {
    final name = _customNameCtrl.text.trim();
    final price = double.tryParse(_customPriceCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final qty = double.tryParse(_customQtyCtrl.text.replaceAll(',', '.')) ?? 1.0;

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Informe o nome ou descrição do item.'),
        backgroundColor: Color(0xFFEF4444),
      ));
      return;
    }

    final item = ProposalItemModel(
      name: name,
      quantity: qty,
      unit: _customUnit,
      unitPrice: price,
      totalPrice: ProposalItemModel.calculateTotal(qty, price, 0),
    );

    widget.onItemSelected(item);
    Navigator.pop(context);
  }

  Future<void> _submitNewProduct() async {
    final name = _regNameCtrl.text.trim();
    final salePrice = double.tryParse(_regSalePriceCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final costPrice = double.tryParse(_regCostPriceCtrl.text.replaceAll(',', '.'));
    final stock = double.tryParse(_regStockCtrl.text.replaceAll(',', '.')) ?? 1.0;

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Informe o nome do equipamento / produto.'),
        backgroundColor: Color(0xFFEF4444),
      ));
      return;
    }

    setState(() => _isSavingNewProduct = true);

    try {
      final specificAttributes = <String, dynamic>{
        'isSolarComponent': true,
        'subcategory': _selectedSubcategory,
      };

      if (_selectedSubcategory == 'MÓDULO SOLAR') {
        if (_modWattsCtrl.text.trim().isNotEmpty) {
          specificAttributes['moduleWatts'] = double.tryParse(_modWattsCtrl.text.replaceAll(',', '.')) ?? _modWattsCtrl.text.trim();
        }
        if (_modEffWarrCtrl.text.trim().isNotEmpty) {
          specificAttributes['efficiencyWarrantyYears'] = int.tryParse(_modEffWarrCtrl.text) ?? _modEffWarrCtrl.text.trim();
        }
        if (_modMfgWarrCtrl.text.trim().isNotEmpty) {
          specificAttributes['mfgWarrantyYears'] = int.tryParse(_modMfgWarrCtrl.text) ?? _modMfgWarrCtrl.text.trim();
        }
      } else if (_selectedSubcategory == 'INVERSOR SOLAR') {
        if (_invPowerCtrl.text.trim().isNotEmpty) {
          specificAttributes['inverterPowerKwp'] = double.tryParse(_invPowerCtrl.text.replaceAll(',', '.')) ?? _invPowerCtrl.text.trim();
        }
        if (_invOverloadCtrl.text.trim().isNotEmpty) {
          specificAttributes['overloadMaxKwp'] = double.tryParse(_invOverloadCtrl.text.replaceAll(',', '.')) ?? _invOverloadCtrl.text.trim();
        }
        if (_invMfgWarrCtrl.text.trim().isNotEmpty) {
          specificAttributes['mfgWarrantyYears'] = int.tryParse(_invMfgWarrCtrl.text) ?? _invMfgWarrCtrl.text.trim();
        }
      } else if (_selectedSubcategory == 'MICROINVERSOR') {
        if (_microPowerCtrl.text.trim().isNotEmpty) {
          specificAttributes['microPowerKwp'] = double.tryParse(_microPowerCtrl.text.replaceAll(',', '.')) ?? _microPowerCtrl.text.trim();
        }
        if (_microOverloadCtrl.text.trim().isNotEmpty) {
          specificAttributes['overloadMaxKwp'] = double.tryParse(_microOverloadCtrl.text.replaceAll(',', '.')) ?? _microOverloadCtrl.text.trim();
        }
        if (_microMfgWarrCtrl.text.trim().isNotEmpty) {
          specificAttributes['mfgWarrantyYears'] = int.tryParse(_microMfgWarrCtrl.text) ?? _microMfgWarrCtrl.text.trim();
        }
      } else if (_selectedSubcategory == 'BATERIA') {
        if (_batCapacityCtrl.text.trim().isNotEmpty) {
          specificAttributes['batteryCapacityKwh'] = double.tryParse(_batCapacityCtrl.text.replaceAll(',', '.')) ?? _batCapacityCtrl.text.trim();
        }
        if (_batVoltageCtrl.text.trim().isNotEmpty) {
          specificAttributes['batteryVoltage'] = _batVoltageCtrl.text.trim();
        }
        if (_batMfgWarrCtrl.text.trim().isNotEmpty) {
          specificAttributes['mfgWarrantyYears'] = int.tryParse(_batMfgWarrCtrl.text) ?? _batMfgWarrCtrl.text.trim();
        }
      }

      final createdProduct = await _repo.createProduct(
        name: name,
        sku: _regSkuCtrl.text.trim().isNotEmpty ? _regSkuCtrl.text.trim() : null,
        sector: ProductSector.solarPlant,
        categoryTitle: 'Usina Solar',
        subcategory: _selectedSubcategory,
        supplierId: _selectedSupplierId,
        supplierName: _selectedSupplierName,
        salePrice: salePrice,
        costPrice: costPrice,
        stockQuantity: stock,
        minStock: 1,
        unit: _regUnit,
        specificAttributes: specificAttributes,
        companyId: _companyId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Item "$name" cadastrado com sucesso!'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ));

        _selectProduct(createdProduct);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro ao salvar produto: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ));
      }
    } finally {
      if (mounted) setState(() => _isSavingNewProduct = false);
    }
  }

  void _selectProduct(ProductModel p) {
    final item = ProposalItemModel.fromProduct(p);
    widget.onItemSelected(item);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 640;
    final dialogWidth = (screenSize.width * 0.95).clamp(320.0, 820.0);
    final dialogHeight = (screenSize.height * 0.92).clamp(460.0, 680.0);

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 24, vertical: isMobile ? 12 : 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        padding: EdgeInsets.all(isMobile ? 14 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Cabeçalho do Diálogo ─────────────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: _viewMode == _PickerViewMode.registerItem
                        ? const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFEA580C)])
                        : AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _viewMode == _PickerViewMode.registerItem
                        ? Icons.add_circle_rounded
                        : _viewMode == _PickerViewMode.quickCustom
                            ? Icons.edit_note_rounded
                            : Icons.add_shopping_cart_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _viewMode == _PickerViewMode.registerItem
                            ? 'Novo Cadastro de Equipamento / Item'
                            : _viewMode == _PickerViewMode.quickCustom
                                ? 'Incluir Item / Serviço Sob Medida'
                                : (widget.excludeSolarPlants
                                    ? 'Adicionar Produto ao Conjunto'
                                    : 'Adicionar Produto do Catálogo'),
                        style: GoogleFonts.outfit(
                          fontSize: 18.5,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        _viewMode == _PickerViewMode.registerItem
                            ? 'Cadastre no catálogo com ficha técnica e adicione automaticamente'
                            : _viewMode == _PickerViewMode.quickCustom
                                ? 'Digite os detalhes para um item avulso ou serviço sob medida'
                                : 'Selecione produtos existentes ou cadastre novos equipamentos',
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),

                // ── Botão "ADICIONAR ITEM" com subtexto explicativo ──
                if (_viewMode == _PickerViewMode.catalog) ...[
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => setState(() => _viewMode = _PickerViewMode.registerItem),
                      borderRadius: BorderRadius.circular(10),
                      child: Ink(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFF59E0B), width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.add_circle_rounded, color: Color(0xFFD97706), size: 20),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'ADICIONAR ITEM',
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.3,
                                    color: const Color(0xFF92400E),
                                  ),
                                ),
                                Text(
                                  'Inversor, Módulo, Bateria, etc...',
                                  style: GoogleFonts.inter(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFFB45309),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ] else ...[
                  // Botão Voltar para o Catálogo
                  TextButton.icon(
                    onPressed: () => setState(() => _viewMode = _PickerViewMode.catalog),
                    icon: const Icon(Icons.arrow_back_rounded, size: 16, color: AppColors.primary),
                    label: Text(
                      'Ver Catálogo',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],

                IconButton(
                  tooltip: 'Fechar',
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(color: AppColors.divider),
            const SizedBox(height: 12),

            // ── Corpo Dinâmico conforme o Modo ──
            if (_viewMode == _PickerViewMode.registerItem)
              Expanded(child: _buildNewProductForm())
            else if (_viewMode == _PickerViewMode.quickCustom)
              Expanded(child: _buildQuickCustomForm())
            else
              Expanded(child: _buildCatalogList()),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 1. LISTAGEM DO CATÁLOGO
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildCatalogList() {
    return Column(
      children: [
        // Busca de Produtos
        TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
          decoration: InputDecoration(
            hintText: 'Buscar produto por nome, código SKU ou categoria...',
            hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
            prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
          ),
        ),
        const SizedBox(height: 14),

        Expanded(
          child: StreamBuilder<List<ProductModel>>(
            stream: _repo.getProductsStream(companyId: _companyId),
            builder: (ctx, snap) {
              if (_companyId == null || snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primary));
              }

              final all = snap.data ?? [];
              final filtered = all.where((p) {
                if (widget.excludeSolarPlants && p.isSolarPlantKit) {
                  return false;
                }
                if (_query.isEmpty) return true;
                return p.name.toLowerCase().contains(_query) ||
                    (p.sku?.toLowerCase().contains(_query) ?? false) ||
                    p.sector.title.toLowerCase().contains(_query);
              }).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.inventory_2_outlined, size: 44, color: Color(0xFF94A3B8)),
                      const SizedBox(height: 10),
                      Text(
                        'Nenhum produto encontrado com o termo "$_query"',
                        style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        onPressed: () => setState(() => _viewMode = _PickerViewMode.registerItem),
                        icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                        label: const Text('CADASTRAR NOVO ITEM AGORA'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF59E0B),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.divider),
                itemBuilder: (ctx, idx) {
                  final p = filtered[idx];
                  final isPlant = p.isSolarPlantKit;
                  final isComponent = p.isSolarComponent;

                  IconData itemIcon = p.sector.icon;
                  Color itemIconColor = p.sector.themeColor;
                  Color itemIconBg = p.sector.themeColor.withValues(alpha: 0.12);

                  if (isPlant) {
                    itemIcon = Icons.solar_power_rounded;
                    itemIconColor = const Color(0xFFD97706);
                    itemIconBg = const Color(0xFFF59E0B).withValues(alpha: 0.15);
                  } else if (isComponent) {
                    final lowerName = p.name.toLowerCase();
                    if (lowerName.contains('modulo') ||
                        lowerName.contains('módulo') ||
                        lowerName.contains('painel') ||
                        lowerName.contains('placa') ||
                        lowerName.contains('bifacial') ||
                        lowerName.contains('cel.') ||
                        p.subcategory?.toUpperCase().contains('MÓDULO') == true ||
                        p.subcategory?.toUpperCase().contains('MODULO') == true ||
                        p.subcategory?.toUpperCase().contains('PAINEL') == true ||
                        p.subcategory?.toUpperCase().contains('PLACA') == true) {
                      itemIcon = Icons.solar_power_rounded;
                      itemIconColor = const Color(0xFFD97706);
                      itemIconBg = const Color(0xFFFEF3C7);
                    } else if (lowerName.contains('inversor') || lowerName.contains('microinversor')) {
                      itemIcon = Icons.offline_bolt_rounded;
                      itemIconColor = const Color(0xFF0284C7);
                      itemIconBg = const Color(0xFF0284C7).withValues(alpha: 0.12);
                    } else if (lowerName.contains('bateria') || lowerName.contains('litio') || lowerName.contains('lifepo4')) {
                      itemIcon = Icons.battery_charging_full_rounded;
                      itemIconColor = const Color(0xFF059669);
                      itemIconBg = const Color(0xFF059669).withValues(alpha: 0.12);
                    } else if (lowerName.contains('estrutura') ||
                        lowerName.contains('perfil') ||
                        lowerName.contains('trilho') ||
                        lowerName.contains('gancho') ||
                        lowerName.contains('grampo')) {
                      itemIcon = Icons.handyman_rounded;
                      itemIconColor = const Color(0xFF7C3AED);
                      itemIconBg = const Color(0xFF7C3AED).withValues(alpha: 0.12);
                    } else if (lowerName.contains('cabo') ||
                        lowerName.contains('conector') ||
                        lowerName.contains('mc4') ||
                        lowerName.contains('string')) {
                      itemIcon = Icons.cable_rounded;
                      itemIconColor = const Color(0xFFE11D48);
                      itemIconBg = const Color(0xFFE11D48).withValues(alpha: 0.12);
                    } else {
                      itemIcon = Icons.bolt_rounded;
                      itemIconColor = const Color(0xFF4F46E5);
                      itemIconBg = const Color(0xFFEEF2FF);
                    }
                  }

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _selectProduct(p),
                      hoverColor: const Color(0xFFF8FAFC),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: itemIconBg,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(itemIcon, color: itemIconColor, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                                  ),
                                  Text(
                                    isPlant
                                        ? '☀️ Usina Solar Fotovoltaica${p.solarKilowatts != null ? ' • ⚡ ${p.solarKilowatts!.toStringAsFixed(1)} kWp' : ''} • 📦 ${p.solarKitItems.length} equipamentos no kit'
                                        : '${p.sector.title}${p.sku != null ? ' • SKU: ${p.sku}' : ''} • Estoque: ${p.stockQuantity.toStringAsFixed(0)} ${p.unit.symbol}',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: isPlant ? FontWeight.w500 : FontWeight.normal,
                                      color: isPlant ? const Color(0xFFD97706) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'R\$ ${p.salePrice.toStringAsFixed(2).replaceAll('.', ',')}',
                                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF059669)),
                                ),
                                Text('por ${p.unit.symbol}', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8))),
                              ],
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary, size: 20),
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
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 2. FORMULÁRIO DE NOVO CADASTRO COMPLETO (COM SUBCATEGORIAS E ESPECIFICAÇÕES)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildNewProductForm() {
    final currentOpt = _solarSubcategoryOptions.firstWhere(
      (opt) => opt['label'] == _selectedSubcategory,
      orElse: () => _solarSubcategoryOptions.first,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.only(right: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Seletor de Subcategorias Pré-cadastradas ──
          Text(
            'Selecione o Tipo de Equipamento / Subcategoria *',
            style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF334155)),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _solarSubcategoryOptions.map((opt) {
              final isSel = _selectedSubcategory == opt['label'];
              final color = opt['color'] as Color;
              final bg = opt['bg'] as Color;
              final icon = opt['icon'] as IconData;
              final label = opt['label'] as String;

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedSubcategory = label;
                    });
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSel ? bg : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSel ? color : AppColors.border,
                        width: isSel ? 1.5 : 1,
                      ),
                      boxShadow: isSel
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: 0.15),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 16, color: isSel ? color : const Color(0xFF64748B)),
                        const SizedBox(width: 6),
                        Text(
                          label,
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                            color: isSel ? color : const Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),

          // ── Dados Básicos do Equipamento ──
          Text(
            'Nome / Descrição do Equipamento *',
            style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _regNameCtrl,
            decoration: InputDecoration(
              hintText: currentOpt['placeholder'] as String,
              prefixIcon: Icon(currentOpt['icon'] as IconData, color: currentOpt['color'] as Color),
            ),
          ),
          const SizedBox(height: 14),

          // Linha: SKU + Fornecedor
          Row(
            children: [
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Código SKU / Modelo', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _regSkuCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Ex: MOD-550W',
                        prefixIcon: Icon(Icons.qr_code_2_rounded, color: Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Fornecedor / Distribuidor (Opcional)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                    const SizedBox(height: 6),
                    StreamBuilder<List<SupplierModel>>(
                      stream: _supplierRepo.getSuppliersStream(),
                      builder: (ctx, snap) {
                        final suppliers = snap.data ?? [];
                        return DropdownButtonFormField<String?>(
                          initialValue: _selectedSupplierId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.business_rounded, color: Color(0xFF64748B)),
                            hintText: 'Selecione o fornecedor...',
                          ),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('Nenhum fornecedor vinculado')),
                            ...suppliers.map((s) {
                              final name = s.tradeName.isNotEmpty ? s.tradeName : s.corporateName;
                              return DropdownMenuItem(
                                value: s.id,
                                child: Text(name, overflow: TextOverflow.ellipsis),
                              );
                            }),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _selectedSupplierId = val;
                              if (val != null) {
                                final s = suppliers.where((item) => item.id == val).firstOrNull;
                                _selectedSupplierName = s != null ? (s.tradeName.isNotEmpty ? s.tradeName : s.corporateName) : null;
                              } else {
                                _selectedSupplierName = null;
                              }
                            });
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Linha: Preço Venda + Preço Custo + Estoque + Unidade
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Preço de Venda (R\$)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _regSalePriceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        hintText: '0,00',
                        prefixIcon: Icon(Icons.attach_money_rounded, color: Color(0xFF059669)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Preço de Custo (R\$)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _regCostPriceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        hintText: '0,00',
                        prefixIcon: Icon(Icons.price_change_outlined, color: Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Qtd Estoque', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _regStockCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        hintText: '10',
                        prefixIcon: Icon(Icons.inventory_2_outlined, color: Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Unidade', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<ProductUnit>(
                      initialValue: _regUnit,
                      items: ProductUnit.values.map((u) => DropdownMenuItem(value: u, child: Text(u.symbol))).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _regUnit = val);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // ── ESPECIFICAÇÕES TÉCNICAS REATIVAS POR SUBCATEGORIA ──
          _buildSubcategoryTechnicalFields(),

          const SizedBox(height: 24),

          // ── Botões de Ação ──
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _viewMode = _PickerViewMode.catalog),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('CANCELAR', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isSavingNewProduct ? null : _submitNewProduct,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 2,
                  ),
                  child: _isSavingNewProduct
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_rounded, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'SALVAR E ADICIONAR AO CONJUNTO',
                              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12.5, letterSpacing: 0.3),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // ── Renderizador de Campos Técnicos Conforme Subcategoria ──
  Widget _buildSubcategoryTechnicalFields() {
    Widget content;

    if (_selectedSubcategory == 'MÓDULO SOLAR') {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Potência do Módulo (Watts) *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF92400E))),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _modWattsCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        hintText: 'Ex: 550, 580, 670',
                        suffixText: 'W',
                        prefixIcon: Icon(Icons.flash_on_rounded, color: Color(0xFFD97706)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Garantia de Eficiência (Anos)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF92400E))),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _modEffWarrCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: 'Ex: 25 ou 30',
                        suffixText: 'Anos',
                        prefixIcon: Icon(Icons.verified_rounded, color: Color(0xFFD97706)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Garantia de Fabricação (Anos)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF92400E))),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _modMfgWarrCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: 'Ex: 12 ou 15',
                        suffixText: 'Anos',
                        prefixIcon: Icon(Icons.shield_outlined, color: Color(0xFFD97706)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      );
    } else if (_selectedSubcategory == 'INVERSOR SOLAR') {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Potência do Inversor (kWp) *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0369A1))),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _invPowerCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        hintText: 'Ex: 5.0, 7.5, 15.0',
                        suffixText: 'kWp',
                        prefixIcon: Icon(Icons.bolt_rounded, color: Color(0xFF0284C7)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Overload Máx (kWp)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0369A1))),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _invOverloadCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        hintText: 'Ex: 7.5, 22.5',
                        suffixText: 'kWp',
                        prefixIcon: Icon(Icons.speed_rounded, color: Color(0xFF0284C7)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Garantia de Fabricação (Anos)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0369A1))),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _invMfgWarrCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: 'Ex: 5 ou 10',
                        suffixText: 'Anos',
                        prefixIcon: Icon(Icons.shield_outlined, color: Color(0xFF0284C7)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      );
    } else if (_selectedSubcategory == 'MICROINVERSOR') {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Potência do Micro (kWp) *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF4338CA))),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _microPowerCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        hintText: 'Ex: 2.0, 2.25',
                        suffixText: 'kWp',
                        prefixIcon: Icon(Icons.electrical_services_rounded, color: Color(0xFF4F46E5)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Overload Máx (kWp)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF4338CA))),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _microOverloadCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        hintText: 'Ex: 3.0',
                        suffixText: 'kWp',
                        prefixIcon: Icon(Icons.speed_rounded, color: Color(0xFF4F46E5)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Garantia de Fabricação (Anos)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF4338CA))),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _microMfgWarrCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: 'Ex: 12 ou 15',
                        suffixText: 'Anos',
                        prefixIcon: Icon(Icons.shield_outlined, color: Color(0xFF4F46E5)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      );
    } else if (_selectedSubcategory == 'BATERIA') {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Capacidade de Armazenamento (kWh) *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF047857))),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _batCapacityCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        hintText: 'Ex: 5.12, 10.0, 15.36',
                        suffixText: 'kWh',
                        prefixIcon: Icon(Icons.battery_charging_full_rounded, color: Color(0xFF059669)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tensão Nominal / Amperagem (V / Ah)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF047857))),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _batVoltageCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Ex: 51.2V / 100Ah ou 48V',
                        prefixIcon: Icon(Icons.power_rounded, color: Color(0xFF059669)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Garantia de Fabricação (Anos)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF047857))),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _batMfgWarrCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: 'Ex: 10',
                        suffixText: 'Anos',
                        prefixIcon: Icon(Icons.shield_outlined, color: Color(0xFF059669)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      );
    } else {
      content = Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Material / Aplicação', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
                const SizedBox(height: 6),
                TextFormField(
                  decoration: const InputDecoration(
                    hintText: 'Ex: Alumínio 6063, Cobre Estanhado...',
                    prefixIcon: Icon(Icons.category_outlined, color: Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Garantia de Fabricação (Anos / Meses)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
                const SizedBox(height: 6),
                TextFormField(
                  decoration: const InputDecoration(
                    hintText: 'Ex: 5 anos, 12 meses',
                    prefixIcon: Icon(Icons.shield_outlined, color: Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune_rounded, size: 18, color: Color(0xFF475569)),
              const SizedBox(width: 8),
              Text(
                'Ficha Técnica Específica — $_selectedSubcategory',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          content,
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 3. MODO ITEM RÁPIDO SOB MEDIDA
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildQuickCustomForm() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nome / Descrição do Item ou Serviço *',
            style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _customNameCtrl,
            decoration: const InputDecoration(
              hintText: 'Ex: Desenvolvimento de Módulo Sob Medida, Consultoria Especial...',
              prefixIcon: Icon(Icons.description_outlined, color: Color(0xFF64748B)),
            ),
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Preço Unitário (R\$)',
                      style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _customPriceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        hintText: '0,00',
                        prefixIcon: Icon(Icons.payments_outlined, color: Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quantidade',
                      style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _customQtyCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        hintText: '1',
                        prefixIcon: Icon(Icons.numbers_rounded, color: Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Unidade',
                      style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: _customUnit,
                      items: ['UN', 'CX', 'KG', 'LT', 'SV', 'HR', 'MT', 'PCT'].map((u) {
                        return DropdownMenuItem(value: u, child: Text(u));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _customUnit = val);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _addCustomItem,
              borderRadius: BorderRadius.circular(12),
              child: Ink(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    'INCLUIR ITEM NA PROPOSTA',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
