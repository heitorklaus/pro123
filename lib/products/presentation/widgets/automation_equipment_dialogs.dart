import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../data/repositories/product_repository.dart';
import '../../domain/models/automation_study_model.dart';
import '../../domain/models/product_model.dart';
import '../solar_plant_form_card.dart';
import 'automation_category_dialogs.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DIÁLOGO DE GERENCIAMENTO & SELEÇÃO DE EQUIPAMENTOS DE AUTOMAÇÃO
// ─────────────────────────────────────────────────────────────────────────────
class AutomationEquipmentManagerDialog extends StatefulWidget {
  final ValueChanged<ProductModel>? onProductSelected;
  final String? companyId;
  final bool startInRegisterMode;
  final String? initialName;
  final List<AutomationCategoryModel>? availableCategories;

  const AutomationEquipmentManagerDialog({
    super.key,
    this.onProductSelected,
    this.companyId,
    this.startInRegisterMode = false,
    this.initialName,
    this.availableCategories,
  });

  @override
  State<AutomationEquipmentManagerDialog> createState() =>
      _AutomationEquipmentManagerDialogState();
}

enum _EquipmentViewMode { catalog, form }

class _AutomationEquipmentManagerDialogState
    extends State<AutomationEquipmentManagerDialog> {
  late final ProductRepository _repo;
  String? _companyId;

  _EquipmentViewMode _viewMode = _EquipmentViewMode.catalog;
  ProductModel? _editingProduct;

  // Busca e Filtros no Catálogo
  final _searchCtrl = TextEditingController();
  String _filterQuery = '';
  String? _selectedCategoryFilter;

  // Categorias
  List<AutomationCategoryModel> _categories = [];

  // Campos do Formulário de Cadastro / Edição
  final _nameCtrl = TextEditingController();
  final _skuCtrl = TextEditingController();
  final _salePriceCtrl = TextEditingController();
  final _costPriceCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _stockCtrl = TextEditingController(text: '10');
  final _descriptionCtrl = TextEditingController();
  ProductUnit _selectedUnit = ProductUnit.un;
  AutomationCategoryModel? _selectedCategory;
  bool _isSaving = false;
  String? _formError;

  @override
  void initState() {
    super.initState();
    _companyId = widget.companyId;
    if (widget.availableCategories != null && widget.availableCategories!.isNotEmpty) {
      _categories = widget.availableCategories!;
    } else {
      _categories = AutomationCategoryModel.defaultCategories;
    }

    try {
      _repo = Modular.get<ProductRepository>();
    } catch (_) {
      _repo = ProductRepository();
    }

    if (_companyId == null) {
      _loadCompanyId();
    }

    if (widget.startInRegisterMode) {
      _startCreateNew(initialName: widget.initialName);
    }
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

  void _startCreateNew({String? initialName}) {
    setState(() {
      _viewMode = _EquipmentViewMode.form;
      _editingProduct = null;
      _nameCtrl.text = initialName ?? '';
      _skuCtrl.text = '';
      _salePriceCtrl.text = '';
      _costPriceCtrl.text = '';
      _brandCtrl.text = '';
      _stockCtrl.text = '10';
      _descriptionCtrl.text = '';
      _selectedUnit = ProductUnit.un;
      _selectedCategory = _categories.isNotEmpty ? _categories.first : null;
      _formError = null;
    });
  }

  void _startEditProduct(ProductModel product) {
    setState(() {
      _viewMode = _EquipmentViewMode.form;
      _editingProduct = product;
      _nameCtrl.text = product.name;
      _skuCtrl.text = product.sku ?? '';
      _salePriceCtrl.text = product.salePrice > 0
          ? CurrencyPtBrInputFormatter.format(product.salePrice)
          : '';
      _costPriceCtrl.text = product.costPrice != null && product.costPrice! > 0
          ? CurrencyPtBrInputFormatter.format(product.costPrice!)
          : '';
      _brandCtrl.text = product.brandModel ?? product.supplierName ?? '';
      _stockCtrl.text = product.stockQuantity.toStringAsFixed(0);
      _descriptionCtrl.text = product.description ?? '';
      _selectedUnit = product.unit;

      final catTitle = product.categoryTitle ??
          product.specificAttributes['automationCategoryTitle']?.toString();
      _selectedCategory = _categories.firstWhere(
        (c) => c.title == catTitle,
        orElse: () => _categories.isNotEmpty ? _categories.first : AutomationCategoryModel.defaultCategories.first,
      );
      _formError = null;
    });
  }

  Future<void> _saveProduct() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _formError = 'Informe o nome do equipamento.');
      return;
    }

    final salePrice = CurrencyPtBrInputFormatter.parse(_salePriceCtrl.text);
    final costPrice = CurrencyPtBrInputFormatter.parse(_costPriceCtrl.text);
    final stock = double.tryParse(_stockCtrl.text.replaceAll(',', '.')) ?? 10.0;

    setState(() {
      _isSaving = true;
      _formError = null;
    });

    try {
      final category = _selectedCategory ??
          (_categories.isNotEmpty ? _categories.first : AutomationCategoryModel.defaultCategories.first);

      final specificAttrs = <String, dynamic>{
        'isAutomationDevice': true,
        'isAutomationStudy': false,
        'automationCategoryTitle': category.title,
        'categoryIconCodePoint': category.icon.codePoint,
        'categoryColorValue': category.color.toARGB32(),
        if (_brandCtrl.text.trim().isNotEmpty) 'brand': _brandCtrl.text.trim(),
        if (_skuCtrl.text.trim().isNotEmpty) 'sku': _skuCtrl.text.trim(),
      };

      ProductModel resultProduct;
      if (_editingProduct != null) {
        final updated = _editingProduct!.copyWith(
          name: name,
          sku: _skuCtrl.text.trim().isNotEmpty ? _skuCtrl.text.trim() : null,
          categoryTitle: category.title,
          description: _descriptionCtrl.text.trim().isNotEmpty ? _descriptionCtrl.text.trim() : null,
          supplierName: _brandCtrl.text.trim().isNotEmpty ? _brandCtrl.text.trim() : null,
          salePrice: salePrice,
          costPrice: costPrice > 0 ? costPrice : null,
          stockQuantity: stock,
          unit: _selectedUnit,
          specificAttributes: {
            ..._editingProduct!.specificAttributes,
            ...specificAttrs,
          },
        );
        await _repo.updateProduct(updated);
        resultProduct = updated;
      } else {
        resultProduct = await _repo.createProduct(
          name: name,
          sku: _skuCtrl.text.trim().isNotEmpty ? _skuCtrl.text.trim() : null,
          sector: ProductSector.homeAutomation,
          categoryTitle: category.title,
          description: _descriptionCtrl.text.trim().isNotEmpty ? _descriptionCtrl.text.trim() : null,
          supplierName: _brandCtrl.text.trim().isNotEmpty ? _brandCtrl.text.trim() : null,
          salePrice: salePrice,
          costPrice: costPrice > 0 ? costPrice : null,
          stockQuantity: stock,
          unit: _selectedUnit,
          specificAttributes: specificAttrs,
          companyId: _companyId,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _editingProduct != null
                  ? 'Equipamento atualizado com sucesso!'
                  : 'Equipamento cadastrado com sucesso!',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );

        if (widget.onProductSelected != null) {
          widget.onProductSelected!(resultProduct);
          Navigator.of(context).pop();
        } else {
          setState(() {
            _viewMode = _EquipmentViewMode.catalog;
            _isSaving = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _formError = 'Erro ao salvar equipamento: $e';
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _deleteProduct(ProductModel product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Excluir Equipamento?',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        content: Text(
          'Tem certeza que deseja excluir "${product.name}" do catálogo de automação?',
          style: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('CANCELAR', style: GoogleFonts.inter(color: const Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('EXCLUIR', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _repo.deleteProduct(product.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Equipamento "${product.name}" removido com sucesso.'),
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao excluir: $e'),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        }
      }
    }
  }

  void _openCategoryManager() {
    showDialog(
      context: context,
      builder: (ctx) => AutomationCategoryManagerDialog(
        companyId: _companyId,
        onCategorySelected: (cat) {
          setState(() {
            _selectedCategory = cat;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF334155), width: 1.2),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 900,
        height: 700,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 18),
            Expanded(
              child: _viewMode == _EquipmentViewMode.catalog
                  ? _buildCatalogView()
                  : _buildFormView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.35)),
          ),
          child: const Icon(Icons.precision_manufacturing_rounded, color: Color(0xFF818CF8), size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Catálogo de Equipamentos de Automação',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                'Gerencie dimmers, relés, interruptores, sensores, módulos e atuadores do seu ecossistema',
                style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF94A3B8)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),

        // Alternância de Abas (Catálogo / Novo)
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () => setState(() => _viewMode = _EquipmentViewMode.catalog),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: _viewMode == _EquipmentViewMode.catalog
                        ? const Color(0xFF6366F1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.inventory_2_rounded,
                        size: 15,
                        color: _viewMode == _EquipmentViewMode.catalog
                            ? Colors.white
                            : const Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Catálogo',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _viewMode == _EquipmentViewMode.catalog
                              ? Colors.white
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: () => _startCreateNew(),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: _viewMode == _EquipmentViewMode.form && _editingProduct == null
                        ? const Color(0xFF10B981)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.add_rounded,
                        size: 15,
                        color: _viewMode == _EquipmentViewMode.form && _editingProduct == null
                            ? Colors.white
                            : const Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Novo Equipamento',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _viewMode == _EquipmentViewMode.form && _editingProduct == null
                              ? Colors.white
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),

        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
          tooltip: 'Fechar',
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // ABA CATÁLOGO
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildCatalogView() {
    return Column(
      children: [
        // Barra de Pesquisa e Filtro de Categoria
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Buscar por nome do equipamento, SKU, marca ou modelo...',
                          hintStyle: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onChanged: (val) => setState(() => _filterQuery = val.trim().toLowerCase()),
                      ),
                    ),
                    if (_filterQuery.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16, color: Color(0xFF94A3B8)),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _filterQuery = '');
                        },
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Filtro Dropdown de Categorias
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: DropdownButton<String?>(
                value: _selectedCategoryFilter,
                underline: const SizedBox(),
                dropdownColor: const Color(0xFF1E293B),
                style: GoogleFonts.inter(fontSize: 12, color: Colors.white),
                hint: Text('Todas as Categorias', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8))),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Todas as Categorias', style: GoogleFonts.inter(fontSize: 12, color: Colors.white)),
                  ),
                  ..._categories.map((c) => DropdownMenuItem<String?>(
                        value: c.title,
                        child: Row(
                          children: [
                            Icon(c.icon, size: 14, color: c.color),
                            const SizedBox(width: 6),
                            Text(c.title, style: GoogleFonts.inter(fontSize: 12, color: Colors.white)),
                          ],
                        ),
                      )),
                ],
                onChanged: (val) => setState(() => _selectedCategoryFilter = val),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Lista de Equipamentos em Tempo Real
        Expanded(
          child: StreamBuilder<List<ProductModel>>(
            stream: _repo.getProductsStream(companyId: _companyId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)));
              }

              final allProducts = snapshot.data ?? [];
              final automationProducts = allProducts.where((p) {
                // Setor precisa ser homeAutomation ou possuir flag isAutomationDevice
                if (p.sector != ProductSector.homeAutomation) return false;
                if (p.isAutomationStudy) return false; // Exclui estudos inteiros da lista de equipamentos avulsos

                if (_selectedCategoryFilter != null && _selectedCategoryFilter!.isNotEmpty) {
                  final catTitle = p.categoryTitle ??
                      p.specificAttributes['automationCategoryTitle']?.toString();
                  if (catTitle != _selectedCategoryFilter) return false;
                }

                if (_filterQuery.isNotEmpty) {
                  final query = _filterQuery;
                  final nameMatch = p.name.toLowerCase().contains(query);
                  final skuMatch = p.sku?.toLowerCase().contains(query) ?? false;
                  final brandMatch = (p.brandModel ?? p.supplierName ?? '')
                      .toLowerCase()
                      .contains(query);
                  final catMatch = (p.categoryTitle ?? '').toLowerCase().contains(query);
                  if (!nameMatch && !skuMatch && !brandMatch && !catMatch) return false;
                }

                return true;
              }).toList();

              if (automationProducts.isEmpty) {
                return _buildEmptyCatalogState();
              }

              return ListView.separated(
                itemCount: automationProducts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final product = automationProducts[index];
                  return _buildEquipmentCard(product);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyCatalogState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: const Icon(Icons.devices_other_rounded, size: 40, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          Text(
            _filterQuery.isNotEmpty
                ? 'Nenhum equipamento encontrado para "$_filterQuery"'
                : 'Nenhum equipamento de automação cadastrado',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Cadastre dimmers, relés inteligentes, sensores e interruptores para usar nos estudos.',
            style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _startCreateNew(initialName: _filterQuery.isNotEmpty ? _filterQuery : null),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('CADASTRAR EQUIPAMENTO'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEquipmentCard(ProductModel product) {
    final catTitle = product.categoryTitle ??
        product.specificAttributes['automationCategoryTitle']?.toString() ??
        'Automação';

    final matchedCategory = _categories.firstWhere(
      (c) => c.title == catTitle,
      orElse: () => AutomationCategoryModel.defaultCategories.first,
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        children: [
          // Ícone com a cor da categoria
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: matchedCategory.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: matchedCategory.color.withValues(alpha: 0.4)),
            ),
            child: Icon(matchedCategory.icon, color: matchedCategory.color, size: 22),
          ),
          const SizedBox(width: 14),

          // Informações Principais
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        product.name,
                        style: GoogleFonts.outfit(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    // Badge Categoria
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: matchedCategory.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: matchedCategory.color.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(matchedCategory.icon, size: 12, color: matchedCategory.color),
                          const SizedBox(width: 4),
                          Text(
                            matchedCategory.title,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: matchedCategory.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (product.sku != null && product.sku!.isNotEmpty) ...[
                      Text(
                        'SKU: ${product.sku}',
                        style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF94A3B8)),
                      ),
                      const SizedBox(width: 12),
                    ],
                    if (product.brandModel != null && product.brandModel!.isNotEmpty) ...[
                      Text(
                        'Marca: ${product.brandModel}',
                        style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF94A3B8)),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Text(
                      'Estoque: ${product.stockQuantity.toStringAsFixed(0)} ${product.unit.code}',
                      style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),

          // Preço Unitário
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                product.salePrice > 0
                    ? CurrencyPtBrInputFormatter.format(product.salePrice)
                    : 'R\$ 0,00',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF10B981),
                ),
              ),
              if (product.costPrice != null && product.costPrice! > 0)
                Text(
                  'Custo: ${CurrencyPtBrInputFormatter.format(product.costPrice!)}',
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                ),
            ],
          ),
          const SizedBox(width: 16),

          // Ações
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.onProductSelected != null) ...[
                ElevatedButton(
                  onPressed: () {
                    widget.onProductSelected!(product);
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    'USAR NO ITEM',
                    style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
              ],

              // Botão Editar
              Tooltip(
                message: 'Editar Equipamento',
                child: InkWell(
                  onTap: () => _startEditProduct(product),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF334155).withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF94A3B8)),
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Botão Excluir
              Tooltip(
                message: 'Excluir Equipamento',
                child: InkWell(
                  onTap: () => _deleteProduct(product),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // ABA FORMULÁRIO (CADASTRO / EDIÇÃO)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildFormView() {
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _editingProduct != null ? Icons.edit_rounded : Icons.add_circle_outline_rounded,
                  color: const Color(0xFF10B981),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _editingProduct != null
                      ? 'Editar Equipamento: ${_editingProduct!.name}'
                      : 'Cadastrar Novo Equipamento de Automação',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_formError != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _formError!,
                        style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFFEF4444)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 1. Nome do Equipamento
            _fieldLabel('Nome do Equipamento / Dispositivo *'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _nameCtrl,
              style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
              decoration: _inputDecoration('Ex: Módulo Relé Inteligente Zigbee 1 Canal Mini'),
            ),
            const SizedBox(height: 16),

            // 2. Categoria e Marca
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _fieldLabel('Categoria de Automação *'),
                          const Spacer(),
                          InkWell(
                            onTap: _openCategoryManager,
                            child: Text(
                              '+ Nova Categoria',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF818CF8),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: DropdownButton<AutomationCategoryModel>(
                          value: _selectedCategory,
                          isExpanded: true,
                          underline: const SizedBox(),
                          dropdownColor: const Color(0xFF0F172A),
                          style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
                          items: _categories.map((cat) {
                            return DropdownMenuItem(
                              value: cat,
                              child: Row(
                                children: [
                                  Icon(cat.icon, size: 16, color: cat.color),
                                  const SizedBox(width: 8),
                                  Text(cat.title),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedCategory = val);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),

                // Marca / Fabricante
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _fieldLabel('Marca / Fabricante'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _brandCtrl,
                        style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
                        decoration: _inputDecoration('Ex: Sonoff, Tuya, Intelbras'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 3. Preço de Venda, Preço de Custo, SKU, Unidade e Estoque
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _fieldLabel('Preço de Venda (R\$) *'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _salePriceCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [CurrencyPtBrInputFormatter()],
                        style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF10B981), fontWeight: FontWeight.bold),
                        decoration: _inputDecoration('R\$ 0,00'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _fieldLabel('Preço de Custo (R\$)'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _costPriceCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [CurrencyPtBrInputFormatter()],
                        style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
                        decoration: _inputDecoration('R\$ 0,00'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _fieldLabel('Código / SKU'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _skuCtrl,
                        style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
                        decoration: _inputDecoration('Ex: REL-ZB-01'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _fieldLabel('Estoque Inicial'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _stockCtrl,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
                        decoration: _inputDecoration('10'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 4. Descrição
            _fieldLabel('Descrição / Observações Técnicas'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _descriptionCtrl,
              maxLines: 2,
              style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
              decoration: _inputDecoration('Protocolo (Zigbee 3.0 / Wi-Fi), voltagem (110V/220V), carga máxima...'),
            ),
            const SizedBox(height: 24),

            // Botões de Ação do Formulário
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => setState(() => _viewMode = _EquipmentViewMode.catalog),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF334155)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    'CANCELAR',
                    style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveProduct,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_rounded, size: 18),
                  label: Text(_editingProduct != null ? 'ATUALIZAR EQUIPAMENTO' : 'SALVAR NO CATÁLOGO'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8)),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
      filled: true,
      fillColor: const Color(0xFF0F172A),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
        borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CAMPO AUTOCOMPLETE DE EQUIPAMENTOS DE AUTOMAÇÃO COM SELEÇÃO DE TEXTO
// ─────────────────────────────────────────────────────────────────────────────
class AutomationEquipmentAutocompleteField extends StatefulWidget {
  final String initialValue;
  final List<ProductModel> automationProducts;
  final List<AutomationCategoryModel> categories;
  final ValueChanged<String> onChanged;
  final ValueChanged<ProductModel> onProductSelected;
  final VoidCallback onOpenEquipmentManager;

  const AutomationEquipmentAutocompleteField({
    super.key,
    required this.initialValue,
    required this.automationProducts,
    required this.categories,
    required this.onChanged,
    required this.onProductSelected,
    required this.onOpenEquipmentManager,
  });

  @override
  State<AutomationEquipmentAutocompleteField> createState() =>
      _AutomationEquipmentAutocompleteFieldState();
}

class _AutomationEquipmentAutocompleteFieldState
    extends State<AutomationEquipmentAutocompleteField> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        // Ao clicar/focar, seleciona todo o texto para facilitar edição ou substituição imediata
        _controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _controller.text.length,
        );
        _showOverlay();
      }
    });
  }

  @override
  void didUpdateWidget(covariant AutomationEquipmentAutocompleteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue &&
        widget.initialValue != _controller.text) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _hideOverlay();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _showOverlay() {
    if (_overlayEntry != null) return;

    final overlay = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          width: 440,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: const Offset(0, 36),
            child: TapRegion(
              groupId: _layerLink,
              child: Material(
                color: Colors.transparent,
                child: _buildSuggestionsCard(),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Widget _buildSuggestionsCard() {
    final query = _controller.text.trim().toLowerCase();

    // Filtra produtos de automação do catálogo
    var matches = widget.automationProducts.where((p) {
      if (query.isEmpty) return true;
      final nameMatch = p.name.toLowerCase().contains(query);
      final skuMatch = p.sku?.toLowerCase().contains(query) ?? false;
      final brandMatch = (p.brandModel ?? p.supplierName ?? '').toLowerCase().contains(query);
      final catMatch = (p.categoryTitle ?? '').toLowerCase().contains(query);
      return nameMatch || skuMatch || brandMatch || catMatch;
    }).toList();

    // Limita a 7 sugestões para manter visual leve
    if (matches.length > 7) {
      matches = matches.sublist(0, 7);
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Cabeçalho da listinha de autocomplete
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              children: [
                const Icon(Icons.flash_on_rounded, size: 14, color: Color(0xFFF59E0B)),
                const SizedBox(width: 6),
                Text(
                  'EQUIPAMENTOS DO CATÁLOGO DE AUTOMAÇÃO',
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
                const Spacer(),
                Text(
                  '${matches.length} encontrados',
                  style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B)),
                ),
              ],
            ),
          ),

          if (matches.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              child: Text(
                'Nenhum equipamento cadastrado com esse termo.',
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
              ),
            )
          else
            ...matches.map((product) {
              final catTitle = product.categoryTitle ??
                  product.specificAttributes['automationCategoryTitle']?.toString() ??
                  'Automação';

              final matchedCategory = widget.categories.firstWhere(
                (c) => c.title == catTitle,
                orElse: () => AutomationCategoryModel.defaultCategories.first,
              );

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    _controller.text = product.name;
                    _hideOverlay();
                    _focusNode.unfocus();
                    widget.onProductSelected(product);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
                    ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: matchedCategory.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(matchedCategory.icon, size: 14, color: matchedCategory.color),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (product.brandModel != null || product.sku != null)
                              Text(
                                [
                                  if (product.brandModel != null) product.brandModel,
                                  if (product.sku != null) 'SKU: ${product.sku}',
                                ].join(' • '),
                                style: GoogleFonts.inter(
                                  fontSize: 10.5,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        product.salePrice > 0
                            ? CurrencyPtBrInputFormatter.format(product.salePrice)
                            : 'R\$ 0,00',
                        style: GoogleFonts.outfit(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),

          // Rodapé com atalho para cadastrar novo equipamento
          Material(
            color: const Color(0xFF1E293B),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(11)),
            child: InkWell(
              onTap: () {
                _hideOverlay();
                _focusNode.unfocus();
                widget.onOpenEquipmentManager();
              },
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(11)),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_circle_outline_rounded, size: 16, color: Color(0xFF818CF8)),
                    const SizedBox(width: 8),
                    Text(
                      'Cadastrar Equipamento / Ver Catálogo Completo',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF818CF8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      groupId: _layerLink,
      onTapOutside: (_) {
        _hideOverlay();
        _focusNode.unfocus();
      },
      child: CompositedTransformTarget(
        link: _layerLink,
        child: TextFormField(
          controller: _controller,
          focusNode: _focusNode,
          style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Nome do equipamento (ex: Módulo Dimmer Zigbee)',
            hintStyle: TextStyle(color: Color(0xFF64748B), fontSize: 12),
            isDense: true,
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          onTap: () {
            // Seleciona todo o texto ao clicar
            _controller.selection = TextSelection(
              baseOffset: 0,
              extentOffset: _controller.text.length,
            );
            _showOverlay();
          },
          onChanged: (val) {
            widget.onChanged(val);
            _overlayEntry?.markNeedsBuild();
          },
        ),
      ),
    );
  }
}
