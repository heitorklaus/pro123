import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../app/theme/app_colors.dart';
import '../../auth/data/repositories/auth_repository.dart';
import '../../auth/domain/models/user_model.dart';
import '../../suppliers/data/repositories/supplier_repository.dart';
import '../../suppliers/domain/models/supplier_model.dart';
import '../data/repositories/product_repository.dart';
import '../domain/models/product_model.dart';
import '../domain/models/subcategory_model.dart';
import '../domain/models/category_model.dart';
import '../../proposals/domain/models/proposal_item_model.dart';
import '../../settings/data/services/settings_service.dart';
import 'solar_plant_form_card.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ENTRY POINT: View principal integrada ao SPA Master do Dashboard
// ─────────────────────────────────────────────────────────────────────────────
class ProductsView extends StatefulWidget {
  final UserModel? currentUser;
  final ValueChanged<ProposalItemModel>? onProceedToProposal;

  const ProductsView({
    super.key,
    this.currentUser,
    this.onProceedToProposal,
  });

  @override
  State<ProductsView> createState() => _ProductsViewState();
}

enum _ProductsViewMode {
  table,
  sectorSelection,
  form,
}

class _ProductsViewState extends State<ProductsView> {
  _ProductsViewMode _mode = _ProductsViewMode.table;
  CategoryModel _selectedCategory = CategoryModel.nativeCategories.first;
  ProductModel? _editingProduct;

  void _startNewProduct() {
    setState(() {
      _editingProduct = null;
      _mode = _ProductsViewMode.sectorSelection;
    });
  }

  void _startNewSolarPlant() {
    setState(() {
      _editingProduct = null;
      _selectedCategory = CategoryModel.fromSector(ProductSector.solarPlant);
      _mode = _ProductsViewMode.form;
    });
  }

  void _onCategorySelected(CategoryModel category) {
    setState(() {
      _selectedCategory = category;
      _mode = _ProductsViewMode.form;
    });
  }

  void _onEditProduct(ProductModel product) {
    setState(() {
      _editingProduct = product;
      _selectedCategory = CategoryModel.fromSector(product.sector).copyWith(
        title: product.displaySectorTitle,
      );
      _mode = _ProductsViewMode.form;
    });
  }

  void _backToTable() {
    setState(() {
      _editingProduct = null;
      _mode = _ProductsViewMode.table;
    });
  }

  void _backToSectorSelection() {
    setState(() {
      _mode = _ProductsViewMode.sectorSelection;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        switch (_mode) {
          case _ProductsViewMode.table:
            return SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: _ProductTableView(
                currentUser: widget.currentUser,
                onAddNew: _startNewProduct,
                onAddNewSolarPlant: _startNewSolarPlant,
                onEdit: _onEditProduct,
              ),
            );

          case _ProductsViewMode.sectorSelection:
            return SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: _SectorSelectorView(
                parentWidth: constraints.maxWidth,
                onBack: _backToTable,
                onCategorySelected: _onCategorySelected,
              ),
            );

          case _ProductsViewMode.form:
            final isSolarPlant = (_editingProduct != null && _editingProduct!.isSolarPlantKit) ||
                (_editingProduct == null &&
                    (_selectedCategory.matchingSector == ProductSector.solarPlant ||
                        _selectedCategory.id == 'solarPlant' ||
                        _selectedCategory.title.toLowerCase().contains('solar')));

            return SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: SizedBox(
                    width: isSolarPlant ? 1040 : 760,
                    child: isSolarPlant
                        ? SolarPlantFormCard(
                            category: _selectedCategory,
                            product: _editingProduct,
                            currentUser: widget.currentUser,
                            onBack: _backToTable,
                            onChangeSector: _editingProduct == null
                                ? _backToSectorSelection
                                : null,
                            onSuccess: _backToTable,
                            onProceedToProposal: widget.onProceedToProposal,
                          )
                        : _ProductFormCard(
                            category: _selectedCategory,
                            product: _editingProduct,
                            currentUser: widget.currentUser,
                            onBack: _backToTable,
                            onChangeSector: _editingProduct == null
                                ? _backToSectorSelection
                                : null,
                            onSuccess: _backToTable,
                          ),
                  ),
                ),
              ),
            );
        }
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. TABELA DE PRODUTOS
// ─────────────────────────────────────────────────────────────────────────────
class _ProductTableView extends StatefulWidget {
  final UserModel? currentUser;
  final VoidCallback onAddNew;
  final VoidCallback? onAddNewSolarPlant;
  final ValueChanged<ProductModel> onEdit;

  const _ProductTableView({
    this.currentUser,
    required this.onAddNew,
    this.onAddNewSolarPlant,
    required this.onEdit,
  });

  @override
  State<_ProductTableView> createState() => _ProductTableViewState();
}

class _ProductTableViewState extends State<_ProductTableView> {
  late final ProductRepository _repo;
  late final AuthRepository _authRepo;
  StreamSubscription<UserModel?>? _userSub;
  StreamSubscription<List<UserModel>>? _sellersSub;
  final _searchCtrl = TextEditingController();
  String _query = '';
  ProductSector? _filterSector;
  String? _selectedSellerId;
  List<UserModel> _sellersList = [];
  int _currentPage = 1;
  int _itemsPerPage = 20;
  final List<int> _pageSizeOptions = const [20, 40, 100, 200];
  bool _isSeeding = false;
  bool _isDeletingAll = false;
  bool _showSolarComponents = false;
  bool _isFixedSector = false;
  String? _companyId;
  UserModel? _currentUser;
  final Set<String> _expandedProductIds = {};
  static const _filterSectorStorageKey = 'mavis_saved_product_filter_sector';

  @override
  void initState() {
    super.initState();
    try {
      _repo = Modular.get<ProductRepository>();
    } catch (_) {
      _repo = ProductRepository();
    }
    try {
      _authRepo = Modular.get<AuthRepository>();
    } catch (_) {
      _authRepo = AuthRepository();
    }
    _currentUser = widget.currentUser;
    _userSub = _authRepo.getCurrentUserStream().listen((user) {
      if (mounted) {
        setState(() {
          _currentUser = user;
          _companyId = user?.effectiveCompanyId ?? _companyId;
        });
        _listenSellers();
      }
    });
    _loadSavedFilterSector();
  }

  void _listenSellers() {
    _sellersSub?.cancel();
    final isSuper = widget.currentUser?.isSuperAdmin ?? _currentUser?.isSuperAdmin ?? false;
    final cid = _companyId ?? widget.currentUser?.effectiveCompanyId;
    _sellersSub = _authRepo.getUsersStream(
      companyId: cid,
      isSuperAdmin: isSuper,
    ).listen((users) {
      if (mounted) {
        setState(() => _sellersList = users);
      }
    });
  }

  static const _showSolarComponentsStorageKey = 'mavis_saved_show_solar_components';

  Future<void> _loadSavedFilterSector() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_filterSectorStorageKey);
      final savedShowSolar = prefs.getBool(_showSolarComponentsStorageKey);
      final prefSector = await SettingsService.getPreferredSector();
      final isFixed = await SettingsService.isFixedSectorMode();

      AuthRepository auth;
      try {
        auth = Modular.get<AuthRepository>();
      } catch (_) {
        auth = AuthRepository();
      }
      final user = await auth.getCurrentUser();
      final cid = user?.effectiveCompanyId ?? await auth.getCurrentCompanyId();

      if (mounted) {
        setState(() {
          _currentUser = user;
          _companyId = cid;
          if (savedShowSolar != null) {
            _showSolarComponents = savedShowSolar;
          }
          if (isFixed && prefSector != null) {
            _isFixedSector = true;
            _filterSector = prefSector;
          } else {
            _isFixedSector = false;
            if (saved != null && saved.isNotEmpty) {
              for (final s in ProductSector.values) {
                if (s.name == saved) {
                  _filterSector = s;
                  break;
                }
              }
            } else {
              _filterSector = prefSector ?? ProductSector.solarPlant;
            }
          }
        });
        _listenSellers();
      }
    } catch (_) {}
  }

  Future<void> _saveFilterSector(ProductSector? sector) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (sector != null) {
        await prefs.setString(_filterSectorStorageKey, sector.name);
      } else {
        await prefs.remove(_filterSectorStorageKey);
      }
    } catch (_) {}
  }

  Future<void> _saveShowSolarComponents(bool val) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_showSolarComponentsStorageKey, val);
    } catch (_) {}
  }

  @override
  void dispose() {
    _userSub?.cancel();
    _sellersSub?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _confirmDeleteAllProducts() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_forever_rounded,
                  color: Color(0xFFEF4444), size: 24),
            ),
            const SizedBox(width: 10),
            Text('Excluir Todos os Produtos',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'ATENÇÃO: Esta ação irá remover PERMANENTEMENTE todos os produtos e usinas solares cadastrados no banco de dados do catálogo.\n\nTem certeza de que deseja apagar tudo?',
          style:
              GoogleFonts.inter(fontSize: 14, color: const Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CANCELAR',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B))),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                Navigator.pop(ctx);
                setState(() => _isDeletingAll = true);
                try {
                  final count = await _repo.deleteAllProducts(companyId: _companyId);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                          '$count produto(s) excluído(s) com sucesso! Catálogo limpo.'),
                      backgroundColor: const Color(0xFF10B981),
                      behavior: SnackBarBehavior.floating,
                    ));
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Erro ao apagar produtos: $e'),
                      backgroundColor: const Color(0xFFEF4444),
                      behavior: SnackBarBehavior.floating,
                    ));
                  }
                } finally {
                  if (mounted) setState(() => _isDeletingAll = false);
                }
              },
              borderRadius: BorderRadius.circular(10),
              child: Ink(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'SIM, APAGAR TUDO',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmSeedProducts() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.bolt_rounded,
                  color: Color(0xFFF59E0B), size: 24),
            ),
            const SizedBox(width: 10),
            Text('Gerar 200 Produtos de Teste',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Deseja cadastrar automaticamente 200 produtos realistas cobrindo os 20 segmentos comerciais do mercado brasileiro?\n\nIsso permitirá testar a paginação (20, 40, 100, 200 itens) e os filtros do catálogo.',
          style:
              GoogleFonts.inter(fontSize: 14, color: const Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CANCELAR',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B))),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                Navigator.pop(ctx);
                setState(() => _isSeeding = true);
                try {
                  final count = await _repo.seed200TestProducts(companyId: _companyId);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                          '$count produtos de teste cadastrados com sucesso!'),
                      backgroundColor: const Color(0xFF10B981),
                      behavior: SnackBarBehavior.floating,
                    ));
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Erro ao gerar produtos: $e'),
                      backgroundColor: const Color(0xFFEF4444),
                      behavior: SnackBarBehavior.floating,
                    ));
                  }
                } finally {
                  if (mounted) setState(() => _isSeeding = false);
                }
              },
              borderRadius: BorderRadius.circular(10),
              child: Ink(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'SIM, GERAR 200 PRODUTOS',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
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
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Padding(
      padding: EdgeInsets.all(isMobile ? 14 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Cabeçalho Principal ──────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Produtos & Serviços',
                      style: GoogleFonts.outfit(
                        fontSize: isMobile ? 20 : 26,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Catálogo inteligente com 20 segmentos',
                      style: GoogleFonts.inter(
                          fontSize: isMobile ? 12 : 14, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.currentUser?.canCreateProducts ?? _currentUser?.canCreateProducts ?? false) ...[
                    if (!isMobile) ...[
                      // Botão de Gerar 200 Produtos de Teste
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: (_isSeeding || _isDeletingAll)
                              ? null
                              : _confirmSeedProducts,
                          borderRadius: BorderRadius.circular(12),
                          child: Ink(
                            decoration: BoxDecoration(
                              color:
                                  const Color(0xFFF59E0B).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color:
                                    const Color(0xFFF59E0B).withValues(alpha: 0.4),
                                width: 1,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 11),
                              child: _isSeeding
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFFF59E0B),
                                      ),
                                    )
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.bolt_rounded,
                                            size: 18, color: Color(0xFFF59E0B)),
                                        const SizedBox(width: 8),
                                        Text(
                                          'GERAR 200 PRODUTOS TESTE',
                                          style: GoogleFonts.inter(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12.5,
                                            letterSpacing: 0.3,
                                            color: const Color(0xFFB45309),
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Botão de Limpar / Excluir Todos os Produtos
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: (_isSeeding || _isDeletingAll)
                              ? null
                              : _confirmDeleteAllProducts,
                          borderRadius: BorderRadius.circular(12),
                          child: Ink(
                            decoration: BoxDecoration(
                              color:
                                  const Color(0xFFEF4444).withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color:
                                    const Color(0xFFEF4444).withValues(alpha: 0.35),
                                width: 1,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 11),
                              child: _isDeletingAll
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFFEF4444),
                                      ),
                                    )
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.delete_sweep_rounded,
                                            size: 18, color: Color(0xFFEF4444)),
                                        const SizedBox(width: 8),
                                        Text(
                                          'LIMPAR CATÁLOGO',
                                          style: GoogleFonts.inter(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12.5,
                                            letterSpacing: 0.3,
                                            color: const Color(0xFFDC2626),
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],

                    // Botão Novo Produto / Nova Usina
                    Builder(builder: (context) {
                      final isSolarFiltered =
                          _filterSector == ProductSector.solarPlant;
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: isSolarFiltered
                              ? (widget.onAddNewSolarPlant ?? widget.onAddNew)
                              : widget.onAddNew,
                          borderRadius: BorderRadius.circular(12),
                          child: Ink(
                            decoration: BoxDecoration(
                              gradient: isSolarFiltered
                                  ? const LinearGradient(
                                      colors: [
                                        Color(0xFFF59E0B),
                                        Color(0xFFEA580C)
                                      ],
                                    )
                                  : AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: (isSolarFiltered
                                          ? const Color(0xFFEA580C)
                                          : AppColors.primary)
                                      .withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: isMobile ? 14 : 20, vertical: isMobile ? 9 : 11),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isSolarFiltered
                                        ? Icons.solar_power_rounded
                                        : Icons.add_shopping_cart_rounded,
                                    size: isMobile ? 16 : 18,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    isSolarFiltered
                                        ? (isMobile ? 'USINA' : 'NOVA USINA')
                                        : (isMobile ? 'NOVO' : 'NOVO PRODUTO'),
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.bold,
                                      fontSize: isMobile ? 12 : 13,
                                      letterSpacing: 0.5,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ],
          ),

          SizedBox(height: isMobile ? 12 : 20),

          // ── Barra de Busca & Filtros ─────────────────────────────────────
          if (isMobile) ...[
            TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() {
                _query = v.trim().toLowerCase();
                _currentPage = 1;
              }),
              decoration: InputDecoration(
                hintText: 'Buscar produto ou SKU...',
                hintStyle: GoogleFonts.inter(
                    fontSize: 13, color: const Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: Color(0xFF64748B), size: 20),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                      color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (!_isFixedSector)
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<ProductSector?>(
                          value: _filterSector,
                          hint: Text(
                            'Todos Segmentos',
                            style: GoogleFonts.inter(
                                fontSize: 12, color: const Color(0xFF64748B)),
                          ),
                          isExpanded: true,
                          icon: const Icon(Icons.filter_list_rounded,
                              size: 16, color: Color(0xFF64748B)),
                          items: [
                            DropdownMenuItem<ProductSector?>(
                              value: null,
                              child: Text('Todos os Segmentos (20)',
                                  style: GoogleFonts.inter(
                                      fontSize: 12, fontWeight: FontWeight.w600)),
                            ),
                            ...ProductSector.values.map(
                              (s) => DropdownMenuItem<ProductSector?>(
                                value: s,
                                child: Row(
                                  children: [
                                    Icon(s.icon, size: 14, color: s.themeColor),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        s.title,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _filterSector = val;
                              _currentPage = 1;
                            });
                            _saveFilterSector(val);
                          },
                        ),
                      ),
                    ),
                  ),
                if (_filterSector == ProductSector.solarPlant) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      final newVal = !_showSolarComponents;
                      setState(() {
                        _showSolarComponents = newVal;
                        _currentPage = 1;
                      });
                      _saveShowSolarComponents(newVal);
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: _showSolarComponents
                            ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _showSolarComponents
                              ? const Color(0xFFF59E0B)
                              : AppColors.border,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _showSolarComponents
                                ? Icons.visibility_rounded
                                : Icons.visibility_off_outlined,
                            size: 16,
                            color: _showSolarComponents
                                ? const Color(0xFFB45309)
                                : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _showSolarComponents ? 'Itens: ON' : 'Itens: OFF',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _showSolarComponents
                                  ? const Color(0xFFB45309)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (_sellersList.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: _selectedSellerId,
                          hint: Text('Vendedor',
                              style: GoogleFonts.inter(
                                  fontSize: 12, color: const Color(0xFF64748B))),
                          isExpanded: true,
                          icon: const Icon(Icons.person_outline_rounded,
                              size: 16, color: Color(0xFF64748B)),
                          items: [
                            DropdownMenuItem<String?>(
                              value: null,
                              child: Text('Todos Vendedores',
                                  style: GoogleFonts.inter(
                                      fontSize: 12, fontWeight: FontWeight.w600)),
                            ),
                            ..._sellersList.map((u) => DropdownMenuItem<String?>(
                                  value: u.uid,
                                  child: Text(u.name,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(fontSize: 12)),
                                )),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _selectedSellerId = val;
                              _currentPage = 1;
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ] else ...[
            Row(
              children: [
                // Campo de busca
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() {
                      _query = v.trim().toLowerCase();
                      _currentPage = 1;
                    }),
                    decoration: InputDecoration(
                      hintText:
                          'Buscar por nome, código SKU ou código de barras...',
                      hintStyle: GoogleFonts.inter(
                          fontSize: 13, color: const Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: Color(0xFF64748B), size: 20),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: AppColors.primary, width: 1.5),
                      ),
                    ),
                  ),
                ),
                // Filtro por Segmento (Ocultado quando em Modo Fixo como Usina Solar)
                if (!_isFixedSector) ...[
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 2,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<ProductSector?>(
                          value: _filterSector,
                          hint: Text(
                            'Todos os Segmentos (20)',
                            style: GoogleFonts.inter(
                                fontSize: 13, color: const Color(0xFF64748B)),
                          ),
                          isExpanded: true,
                          icon: const Icon(Icons.filter_list_rounded,
                              size: 18, color: Color(0xFF64748B)),
                          items: [
                            DropdownMenuItem<ProductSector?>(
                              value: null,
                              child: Text('Todos os Segmentos (20)',
                                  style: GoogleFonts.inter(
                                      fontSize: 13, fontWeight: FontWeight.w600)),
                            ),
                            ...ProductSector.values.map(
                              (s) => DropdownMenuItem<ProductSector?>(
                                value: s,
                                child: Row(
                                  children: [
                                    Icon(s.icon, size: 16, color: s.themeColor),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        s.title,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _filterSector = val;
                              _currentPage = 1;
                            });
                            _saveFilterSector(val);
                          },
                        ),
                      ),
                    ),
                  ),
                ],

                // Filtro por Vendedor / Criador
                if (_sellersList.isNotEmpty) ...[
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 2,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: _selectedSellerId,
                          hint: Text(
                            'Todos os Vendedores',
                            style: GoogleFonts.inter(
                                fontSize: 13, color: const Color(0xFF64748B)),
                          ),
                          isExpanded: true,
                          icon: const Icon(Icons.person_outline_rounded,
                              size: 18, color: Color(0xFF64748B)),
                          items: [
                            DropdownMenuItem<String?>(
                              value: null,
                              child: Text('👥 Todos os Vendedores',
                                  style: GoogleFonts.inter(
                                      fontSize: 13, fontWeight: FontWeight.w600)),
                            ),
                            ..._sellersList.map((u) => DropdownMenuItem<String?>(
                                  value: u.uid,
                                  child: Row(
                                    children: [
                                      const Icon(Icons.person_pin_rounded, size: 16, color: Color(0xFF6366F1)),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          u.name,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _selectedSellerId = val;
                              _currentPage = 1;
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                ],

                // Botão Toggle "Mostrar Itens de Usinas" (Aparece apenas quando USINA SOLAR estiver selecionada)
                if (_filterSector == ProductSector.solarPlant) ...[
                  const SizedBox(width: 12),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        final newVal = !_showSolarComponents;
                        setState(() {
                          _showSolarComponents = newVal;
                          _currentPage = 1;
                        });
                        _saveShowSolarComponents(newVal);
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Ink(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: _showSolarComponents
                              ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _showSolarComponents
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFFCBD5E1),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _showSolarComponents
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_outlined,
                              size: 17,
                              color: _showSolarComponents
                                  ? const Color(0xFFB45309)
                                  : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Mostrar Itens de Usinas',
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: _showSolarComponents
                                    ? const Color(0xFFB45309)
                                    : const Color(0xFF475569),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _showSolarComponents
                                    ? const Color(0xFFF59E0B)
                                    : const Color(0xFF94A3B8),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _showSolarComponents ? 'ATIVO' : 'OCULTO',
                                style: GoogleFonts.inter(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],

          SizedBox(height: isMobile ? 10 : 16),

          // ── Conteúdo da Tabela com Paginação ───────────────────────────────
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isMobile ? Colors.transparent : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: isMobile ? null : Border.all(color: AppColors.border),
                boxShadow: isMobile
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: StreamBuilder<List<ProductModel>>(
                  stream: _repo.getProductsStream(
                    companyId: _companyId,
                    isSuperAdmin: widget.currentUser?.isSuperAdmin ?? _currentUser?.isSuperAdmin ?? false,
                  ),
                  builder: (ctx, snap) {
                    final isSuper = widget.currentUser?.isSuperAdmin ?? _currentUser?.isSuperAdmin ?? false;
                    if ((_companyId == null && !isSuper) || snap.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child:
                            CircularProgressIndicator(color: AppColors.primary),
                      );
                    }
                    if (snap.hasError) {
                      return Center(
                        child: Text(
                          'Erro ao carregar catálogo:\n${snap.error}',
                          textAlign: TextAlign.center,
                          style:
                              GoogleFonts.inter(color: const Color(0xFF64748B)),
                        ),
                      );
                    }

                    final all = snap.data ?? [];
                    final filtered = all.where((p) {
                      final matchesQuery = _query.isEmpty ||
                          p.name.toLowerCase().contains(_query) ||
                          (p.sku?.toLowerCase().contains(_query) ?? false) ||
                          (p.barcode?.toLowerCase().contains(_query) ?? false);

                      final matchesSector =
                          _filterSector == null || p.sector == _filterSector;

                      final matchesSeller = _selectedSellerId == null ||
                          p.createdByUserId == _selectedSellerId;

                      if (!matchesQuery || !matchesSector || !matchesSeller) return false;

                      if (_filterSector == ProductSector.solarPlant) {
                        if (!_showSolarComponents && p.isSolarComponent) {
                          return false;
                        }
                      }

                      return true;
                    }).toList();

                    final totalItems = filtered.length;
                    final totalPages = (totalItems == 0)
                        ? 1
                        : (totalItems / _itemsPerPage).ceil();

                    final safePage = _currentPage.clamp(1, totalPages);
                    final startIndex =
                        (totalItems == 0) ? 0 : (safePage - 1) * _itemsPerPage;
                    final paginatedList =
                        filtered.skip(startIndex).take(_itemsPerPage).toList();
                    final endIndex = (startIndex + paginatedList.length);

                    return Column(
                      children: [
                        if (!isMobile) ...[
                          _ProductTableHeader(),
                          const Divider(height: 1, color: AppColors.divider),
                        ],
                        Expanded(
                          child: filtered.isEmpty
                              ? _ProductEmptyState(
                                  isEmpty: all.isEmpty,
                                  onAdd: widget.onAddNew,
                                  onSeed: _confirmSeedProducts,
                                )
                              : isMobile
                                  ? ListView.builder(
                                      itemCount: paginatedList.length,
                                      padding: EdgeInsets.zero,
                                      itemBuilder: (_, i) {
                                        final item = paginatedList[i];
                                        final isExpanded =
                                            _expandedProductIds.contains(item.id);
                                        return _ProductMobileCard(
                                          product: item,
                                          isExpanded: isExpanded,
                                          onToggleExpand: item.isSolarPlantKit
                                              ? () => setState(() {
                                                    if (isExpanded) {
                                                      _expandedProductIds
                                                          .remove(item.id);
                                                    } else {
                                                      _expandedProductIds
                                                          .add(item.id);
                                                    }
                                                  })
                                              : null,
                                          onEdit: () => widget.onEdit(item),
                                          onDelete: () => _showDeleteDialog(item),
                                        );
                                      },
                                    )
                                  : ListView.separated(
                                      itemCount: paginatedList.length,
                                      separatorBuilder: (_, __) => const Divider(
                                          height: 1, color: AppColors.divider),
                                      itemBuilder: (_, i) {
                                        final item = paginatedList[i];
                                        final isExpanded =
                                            _expandedProductIds.contains(item.id);
                                        return _ProductRow(
                                          product: item,
                                          isExpanded: isExpanded,
                                          onToggleExpand: item.isSolarPlantKit
                                              ? () => setState(() {
                                                    if (isExpanded) {
                                                      _expandedProductIds
                                                          .remove(item.id);
                                                    } else {
                                                      _expandedProductIds
                                                          .add(item.id);
                                                    }
                                                  })
                                              : null,
                                          onEdit: () => widget.onEdit(item),
                                          onDelete: () => _showDeleteDialog(item),
                                        );
                                      },
                                    ),
                        ),
                        if (isMobile) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                TextButton.icon(
                                  onPressed: safePage > 1
                                      ? () => setState(() => _currentPage = safePage - 1)
                                      : null,
                                  icon: const Icon(Icons.chevron_left_rounded, size: 18),
                                  label: const Text('Anterior'),
                                ),
                                Text(
                                  'Pág $safePage de $totalPages',
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                                ),
                                TextButton.icon(
                                  onPressed: safePage < totalPages
                                      ? () => setState(() => _currentPage = safePage + 1)
                                      : null,
                                  label: const Text('Próxima'),
                                  icon: const Icon(Icons.chevron_right_rounded, size: 18),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          const Divider(height: 1, color: AppColors.divider),
                          _ProductPaginationBar(
                            currentPage: safePage,
                            totalPages: totalPages,
                            totalItems: totalItems,
                            startIndex: totalItems == 0 ? 0 : startIndex + 1,
                            endIndex: endIndex,
                            itemsPerPage: _itemsPerPage,
                            pageSizeOptions: _pageSizeOptions,
                            onPageChanged: (p) =>
                                setState(() => _currentPage = p),
                            onPageSizeChanged: (s) => setState(() {
                              _itemsPerPage = s;
                              _currentPage = 1;
                            }),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(ProductModel product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Color(0xFFEF4444), size: 26),
            const SizedBox(width: 10),
            Text('Excluir Produto',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Remover "${product.name}" do catálogo? Essa ação não pode ser desfeita.',
          style:
              GoogleFonts.inter(fontSize: 14, color: const Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CANCELAR',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B))),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                Navigator.pop(ctx);
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await _repo.deleteProduct(product.id);
                  if (!mounted) return;
                  messenger.showSnackBar(const SnackBar(
                    content: Text('Produto removido com sucesso.'),
                    backgroundColor: Color(0xFF10B981),
                    behavior: SnackBarBehavior.floating,
                  ));
                } catch (e) {
                  if (!mounted) return;
                  messenger.showSnackBar(SnackBar(
                    content: Text('Erro ao remover: $e'),
                    backgroundColor: const Color(0xFFEF4444),
                    behavior: SnackBarBehavior.floating,
                  ));
                }
              },
              borderRadius: BorderRadius.circular(10),
              child: Ink(
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(10),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Text(
                  'EXCLUIR',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cabeçalho da Tabela de Produtos
// ─────────────────────────────────────────────────────────────────────────────
class _ProductTableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      color: const Color(0xFFF8FAFC),
      child: Row(
        children: [
          _col('PRODUTO / SERVIÇO', flex: 6),
          _col('SEGMENTO', flex: 2),
          _col('PREÇO VENDA / CUSTO', flex: 2),
          _col('ESTOQUE', flex: 1),
          _col('STATUS', flex: 1),
          const SizedBox(width: 88),
        ],
      ),
    );
  }

  Widget _col(String label, {required int flex}) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontWeight: FontWeight.bold,
          fontSize: 11,
          color: const Color(0xFF64748B),
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Linha do Produto na Tabela
// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
// Linha do Produto na Tabela (com Suporte a Agrupamento e Expansão de Usina Solar)
// ─────────────────────────────────────────────────────────────────────────────
class _ProductRow extends StatelessWidget {
  final ProductModel product;
  final bool isExpanded;
  final VoidCallback? onToggleExpand;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProductRow({
    required this.product,
    this.isExpanded = false,
    this.onToggleExpand,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isPlant = product.isSolarPlantKit;
    final isComponent = product.isSolarComponent;
    final kitItems = product.solarKitItems;

    // Ícone e cores do produto
    IconData productIcon = product.sector.icon;
    Color productIconColor = product.sector.themeColor;
    Color productIconBg = product.sector.themeColor.withValues(alpha: 0.12);
    Color productIconBorder = product.sector.themeColor.withValues(alpha: 0.3);

    if (isPlant) {
      productIcon = Icons.solar_power_rounded;
      productIconColor = const Color(0xFFD97706);
      productIconBg = const Color(0xFFF59E0B).withValues(alpha: 0.15);
      productIconBorder = const Color(0xFFF59E0B).withValues(alpha: 0.4);
    } else if (isComponent) {
      final lowerName = product.name.toLowerCase();
      if (lowerName.contains('modulo') ||
          lowerName.contains('módulo') ||
          lowerName.contains('painel') ||
          lowerName.contains('placa') ||
          lowerName.contains('bifacial') ||
          lowerName.contains('cel.') ||
          product.subcategory?.toUpperCase().contains('MÓDULO') == true ||
          product.subcategory?.toUpperCase().contains('MODULO') == true ||
          product.subcategory?.toUpperCase().contains('PAINEL') == true ||
          product.subcategory?.toUpperCase().contains('PLACA') == true) {
        productIcon = Icons.solar_power_rounded;
        productIconColor = const Color(0xFFD97706);
        productIconBg = const Color(0xFFF59E0B).withValues(alpha: 0.15);
        productIconBorder = const Color(0xFFF59E0B).withValues(alpha: 0.4);
      } else if (lowerName.contains('inversor') || lowerName.contains('microinversor')) {
        productIcon = Icons.offline_bolt_rounded;
        productIconColor = const Color(0xFF0284C7);
        productIconBg = const Color(0xFF0284C7).withValues(alpha: 0.12);
        productIconBorder = const Color(0xFF0284C7).withValues(alpha: 0.35);
      } else if (lowerName.contains('estrutura') ||
          lowerName.contains('perfil') ||
          lowerName.contains('trilho') ||
          lowerName.contains('gancho') ||
          lowerName.contains('grampo')) {
        productIcon = Icons.handyman_rounded;
        productIconColor = const Color(0xFF7C3AED);
        productIconBg = const Color(0xFF7C3AED).withValues(alpha: 0.12);
        productIconBorder = const Color(0xFF7C3AED).withValues(alpha: 0.35);
      } else if (lowerName.contains('cabo') ||
          lowerName.contains('conector') ||
          lowerName.contains('mc4') ||
          lowerName.contains('string')) {
        productIcon = Icons.cable_rounded;
        productIconColor = const Color(0xFF059669);
        productIconBg = const Color(0xFF059669).withValues(alpha: 0.12);
        productIconBorder = const Color(0xFF059669).withValues(alpha: 0.35);
      } else {
        productIcon = Icons.bolt_rounded;
        productIconColor = const Color(0xFF4F46E5);
        productIconBg = const Color(0xFFEEF2FF);
        productIconBorder = const Color(0xFFC7D2FE);
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: Row(
            children: [
              // 1. Produto / Nome / SKU (Largura Expandida flex 6)
              Expanded(
                flex: 6,
                child: Row(
                  children: [
                    // Botão [+] / [-] se for Usina Solar Kit
                    if (isPlant) ...[
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onToggleExpand,
                          borderRadius: BorderRadius.circular(8),
                          child: Ink(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: isExpanded
                                  ? const Color(0xFFEA580C).withValues(alpha: 0.15)
                                  : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isExpanded
                                    ? const Color(0xFFEA580C)
                                    : const Color(0xFFF59E0B),
                                width: 1.2,
                              ),
                            ),
                            child: Icon(
                              isExpanded ? Icons.remove_rounded : Icons.add_rounded,
                              size: 16,
                              color: isExpanded
                                  ? const Color(0xFFEA580C)
                                  : const Color(0xFFB45309),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],

                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: productIconBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: productIconBorder,
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          productIcon,
                          color: productIconColor,
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Tooltip(
                                  message: product.name,
                                  waitDuration: const Duration(milliseconds: 150),
                                  child: Text(
                                    product.name.length > 55
                                        ? '${product.name.substring(0, 55)}...'
                                        : product.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF0F172A)),
                                  ),
                                ),
                              ),
                              if (isComponent) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEEF2FF),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                        color: const Color(0xFFC7D2FE)),
                                  ),
                                  child: Text(
                                    'ITEM AVULSO',
                                    style: GoogleFonts.inter(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF4F46E5),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Wrap(
                            spacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (product.sku != null && product.sku!.isNotEmpty)
                                Text(
                                  'SKU: ${product.sku!} ',
                                  style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF64748B)),
                                ),
                              if (product.barcode != null &&
                                  product.barcode!.isNotEmpty)
                                Text(
                                  '• EAN: ${product.barcode!}',
                                  style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: const Color(0xFF94A3B8)),
                                ),
                              if (product.supplierName != null &&
                                  product.supplierName!.isNotEmpty)
                                Text(
                                  '• Forn: ${product.supplierName!}',
                                  style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF0284C7)),
                                ),
                              if (isPlant) ...[
                                if (product.solarKilowatts != null &&
                                    product.solarKilowatts! > 0)
                                  Text(
                                    '• ⚡ ${product.solarKilowatts!.toStringAsFixed(1)} kWp',
                                    style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFFD97706)),
                                  ),
                                if (product.solarRoofType != null &&
                                    product.solarRoofType!.isNotEmpty)
                                  Text(
                                    '• 🏠 ${product.solarRoofType!}',
                                    style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: const Color(0xFF475569)),
                                  ),
                                Text(
                                  '• 📦 ${kitItems.length} equipamentos no kit',
                                  style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF059669)),
                                ),
                              ],
                              if (product.createdByUserName != null && product.createdByUserName!.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFFBFDBFE)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.person_pin_rounded, size: 10, color: Color(0xFF2563EB)),
                                      const SizedBox(width: 3),
                                      Text(
                                        product.createdByUserName!,
                                        style: GoogleFonts.inter(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF1D4ED8),
                                        ),
                                      ),
                                    ],
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

              // 2. Segmento (Largura otimizada flex 2)
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _SectorBadge(
                    sector: product.sector,
                    categoryTitle: product.categoryTitle,
                  ),
                ),
              ),

              // 3. Preço Venda / Custo / Margem (flex 2)
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'R\$ ${product.salePrice.toStringAsFixed(2).replaceAll('.', ',')}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    if (isPlant) ...[
                      if (product.solarProductsPrice != null &&
                          product.solarProductsPrice! > 0)
                        Text(
                          'Equipamentos: R\$ ${product.solarProductsPrice!.toStringAsFixed(2).replaceAll('.', ',')}',
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                    ] else if (product.costPrice != null &&
                        product.costPrice! > 0) ...[
                      Text(
                        'Custo: R\$ ${product.costPrice!.toStringAsFixed(2).replaceAll('.', ',')} (${product.profitMargin.toStringAsFixed(0)}% margem)',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFF10B981),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // 4. Estoque (flex 1 - compacto)
              Expanded(
                flex: 1,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _StockBadge(product: product),
                ),
              ),

              // 5. Status (flex 1 - compacto)
              Expanded(
                flex: 1,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _ProductStatusBadge(status: product.status),
                ),
              ),

              // 6. Ações
              SizedBox(
                width: 88,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Editar',
                      icon: const Icon(Icons.edit_outlined,
                          color: Color(0xFF6366F1), size: 18),
                      onPressed: onEdit,
                    ),
                    IconButton(
                      tooltip: 'Excluir',
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: Color(0xFFEF4444), size: 18),
                      onPressed: onDelete,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Bloco Expansível da Usina Solar com Lista dos Subprodutos Agrupados
        if (isPlant && isExpanded)
          _SolarPlantKitDetails(product: product),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Detalhes Expansíveis dos Equipamentos Inclusos na Usina Solar
// ─────────────────────────────────────────────────────────────────────────────
class _SolarPlantKitDetails extends StatelessWidget {
  final ProductModel product;

  const _SolarPlantKitDetails({required this.product});

  @override
  Widget build(BuildContext context) {
    final items = product.solarKitItems;
    final services = product.solarAdditionalServices;

    return Container(
      margin: const EdgeInsets.only(left: 48, right: 24, bottom: 12, top: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho da Usina Solar Expandida
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.solar_power_rounded,
                        size: 16, color: Color(0xFFD97706)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Equipamentos Inclusos nesta Usina (${items.length} itens cadastrados)',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                children: [
                  if (product.solarKilowatts != null &&
                      product.solarKilowatts! > 0)
                    _specBadge(
                        'Potência: ${product.solarKilowatts!.toStringAsFixed(1)} kWp',
                        const Color(0xFFD97706),
                        const Color(0xFFFEF3C7)),
                  if (product.solarGenerationKwh != null &&
                      product.solarGenerationKwh! > 0)
                    _specBadge(
                        'Geração: ${product.solarGenerationKwh!.toStringAsFixed(0)} kWh/mês',
                        const Color(0xFF0369A1),
                        const Color(0xFFE0F2FE)),
                  if (product.solarRoofType != null &&
                      product.solarRoofType!.isNotEmpty)
                    _specBadge(
                        'Telhado: ${product.solarRoofType}',
                        const Color(0xFF475569),
                        const Color(0xFFF1F5F9)),
                  if (product.solarProductsPrice != null &&
                      product.solarProductsPrice! > 0)
                    _specBadge(
                        'Produtos: R\$ ${product.solarProductsPrice!.toStringAsFixed(2).replaceAll('.', ',')}',
                        const Color(0xFF0284C7),
                        const Color(0xFFE0F2FE)),
                  if (product.solarServicePrice != null &&
                      product.solarServicePrice! > 0)
                    _specBadge(
                        'Serviço: R\$ ${product.solarServicePrice!.toStringAsFixed(2).replaceAll('.', ',')}',
                        const Color(0xFF10B981),
                        const Color(0xFFD1FAE5)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 10),

          // Lista de Equipamentos
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Nenhum subproduto individual detalhado nesta usina.',
                style: GoogleFonts.inter(
                    fontSize: 12, color: const Color(0xFF94A3B8)),
              ),
            )
          else
            ...items.map((item) {
              final name = item['name']?.toString() ?? 'Item';
              final sku = item['sku']?.toString();
              final qty = (item['quantity'] as num?)?.toDouble() ?? 1.0;
              final unit = item['unit']?.toString() ?? 'UN';
              final unitPrice = (item['unitPrice'] as num?)?.toDouble() ?? 0.0;
              final totalPrice =
                  (item['totalPrice'] as num?)?.toDouble() ?? (qty * unitPrice);

              IconData iconData = Icons.extension_rounded;
              Color iconColor = const Color(0xFF6366F1);
              final lowerName = name.toLowerCase();
              if (lowerName.contains('painel') ||
                  lowerName.contains('módulo') ||
                  lowerName.contains('modulo') ||
                  lowerName.contains('placa')) {
                iconData = Icons.solar_power_rounded;
                iconColor = const Color(0xFFD97706);
              } else if (lowerName.contains('inversor') ||
                  lowerName.contains('microinversor')) {
                iconData = Icons.offline_bolt_rounded;
                iconColor = const Color(0xFF0284C7);
              } else if (lowerName.contains('estrutura') ||
                  lowerName.contains('gancho') ||
                  lowerName.contains('trilho') ||
                  lowerName.contains('grampo') ||
                  lowerName.contains('perfil')) {
                iconData = Icons.handyman_rounded;
                iconColor = const Color(0xFF7C3AED);
              } else if (lowerName.contains('cabo') ||
                  lowerName.contains('string') ||
                  lowerName.contains('conector') ||
                  lowerName.contains('mc4')) {
                iconData = Icons.cable_rounded;
                iconColor = const Color(0xFF059669);
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(iconData, size: 15, color: iconColor),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                          if (sku != null && sku.isNotEmpty)
                            Text(
                              'SKU: $sku',
                              style: GoogleFonts.inter(
                                  fontSize: 11, color: const Color(0xFF64748B)),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${qty.toStringAsFixed(qty.truncateToDouble() == qty ? 0 : 2)} $unit',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF4338CA),
                        ),
                      ),
                    ),
                    if (totalPrice > 0) ...[
                      const SizedBox(width: 16),
                      Text(
                        'R\$ ${totalPrice.toStringAsFixed(2).replaceAll('.', ',')}',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),

          // Serviços Adicionais
          if (services.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Serviços e Adicionais Inclusos:',
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF475569)),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: services.map((srv) {
                final type = srv['type']?.toString() ?? 'Serviço';
                final price = (srv['price'] as num?)?.toDouble() ?? 0.0;
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_outline_rounded,
                          size: 14, color: Color(0xFF10B981)),
                      const SizedBox(width: 6),
                      Text(
                        '$type: R\$ ${price.toStringAsFixed(2).replaceAll('.', ',')}',
                        style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF334155)),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _specBadge(String text, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card Mobile de Produto / Usina Solar
// ─────────────────────────────────────────────────────────────────────────────
class _ProductMobileCard extends StatelessWidget {
  final ProductModel product;
  final bool isExpanded;
  final VoidCallback? onToggleExpand;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProductMobileCard({
    required this.product,
    this.isExpanded = false,
    this.onToggleExpand,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final hasKit = product.isSolarPlantKit;
    final themeColor = product.sector.themeColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasKit ? const Color(0xFFF59E0B).withValues(alpha: 0.4) : AppColors.border,
          width: hasKit ? 1.2 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onEdit,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: themeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            hasKit ? Icons.solar_power_rounded : product.sector.icon,
                            color: themeColor,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.name,
                                style: GoogleFonts.inter(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0F172A),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (product.sku != null && product.sku!.isNotEmpty)
                                Text(
                                  'SKU: ${product.sku}',
                                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                                ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'R\$ ${product.salePrice.toStringAsFixed(2).replaceAll('.', ',')}',
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            if (hasKit)
                              Container(
                                margin: const EdgeInsets.only(top: 2),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${product.solarKilowatts ?? 0} kWp',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFB45309),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Divider(height: 1, color: AppColors.divider),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: themeColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            product.displaySectorTitle,
                            style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: themeColor),
                          ),
                        ),
                        if (hasKit && onToggleExpand != null) ...[
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: onToggleExpand,
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isExpanded ? Icons.remove_rounded : Icons.add_rounded,
                                    size: 14,
                                    color: const Color(0xFF475569),
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${product.solarKitItems.length} itens',
                                    style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF475569)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF6366F1)),
                          onPressed: onEdit,
                          tooltip: 'Editar',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                          onPressed: onDelete,
                          tooltip: 'Excluir',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (hasKit && isExpanded && product.solarKitItems.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Itens inclusos no Kit:',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF475569)),
                  ),
                  const SizedBox(height: 6),
                  ...product.solarKitItems.map((item) {
                    final qty = item['quantity'] ?? item['qty'] ?? 1;
                    final name = item['name'] ?? item['productName'] ?? 'Item';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline_rounded, size: 12, color: Color(0xFF10B981)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${qty}x $name',
                              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF334155)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Badges de Produto
// ─────────────────────────────────────────────────────────────────────────────
class _SectorBadge extends StatelessWidget {
  final ProductSector sector;
  final String? categoryTitle;

  const _SectorBadge({
    required this.sector,
    this.categoryTitle,
  });

  @override
  Widget build(BuildContext context) {
    final fullTitle =
        categoryTitle?.isNotEmpty == true ? categoryTitle! : sector.title;
    final displayTitle =
        fullTitle.length > 12 ? '${fullTitle.substring(0, 12)}...' : fullTitle;

    return Tooltip(
      message: fullTitle,
      waitDuration: const Duration(milliseconds: 150),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: sector.themeColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: sector.themeColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(sector.icon, size: 11, color: sector.themeColor),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                displayTitle,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: sector.themeColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StockBadge extends StatelessWidget {
  final ProductModel product;
  const _StockBadge({required this.product});

  @override
  Widget build(BuildContext context) {
    final bool isService =
        product.unit == ProductUnit.hr || product.unit == ProductUnit.sv;

    if (isService) {
      return Text(
        'Serviço (${product.unit.symbol})',
        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
      );
    }

    final (color, bg, text) = product.isOutOfStock
        ? (const Color(0xFFDC2626), const Color(0xFFFEF2F2), 'Esgotado')
        : product.isLowStock
            ? (
                const Color(0xFFD97706),
                const Color(0xFFFEF3C7),
                '${product.stockQuantity.toStringAsFixed(0)} ${product.unit.symbol} (Baixo)'
              )
            : (
                const Color(0xFF059669),
                const Color(0xFFD1FAE5),
                '${product.stockQuantity.toStringAsFixed(0)} ${product.unit.symbol}'
              );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _ProductStatusBadge extends StatelessWidget {
  final ProductStatus status;
  const _ProductStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: status.bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: status.textColor,
        ),
      ),
    );
  }
}

class _ProductEmptyState extends StatelessWidget {
  final bool isEmpty;
  final VoidCallback onAdd;
  final VoidCallback? onSeed;

  const _ProductEmptyState({
    required this.isEmpty,
    required this.onAdd,
    this.onSeed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
                color: Color(0xFFEEF2FF), shape: BoxShape.circle),
            child: const Icon(Icons.inventory_2_outlined,
                color: AppColors.primary, size: 40),
          ),
          const SizedBox(height: 16),
          Text(
            isEmpty
                ? 'Nenhum produto cadastrado'
                : 'Nenhum resultado encontrado',
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: const Color(0xFF1E293B)),
          ),
          const SizedBox(height: 6),
          Text(
            isEmpty
                ? 'Cadastre um produto manualmente ou gere 200 produtos de teste com 1 clique.'
                : 'Tente alterar os filtros ou o termo de busca.',
            style:
                GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 13),
          ),
          if (isEmpty) ...[
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onAdd,
                    borderRadius: BorderRadius.circular(12),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.add_shopping_cart_rounded,
                                size: 18, color: Colors.white),
                            const SizedBox(width: 8),
                            Text(
                              'Cadastrar Novo Produto',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (onSeed != null)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onSeed,
                      borderRadius: BorderRadius.circular(12),
                      child: Ink(
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFFF59E0B).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                const Color(0xFFF59E0B).withValues(alpha: 0.4),
                            width: 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.bolt_rounded,
                                  size: 18, color: Color(0xFFF59E0B)),
                              const SizedBox(width: 8),
                              Text(
                                'Gerar 200 Produtos de Teste',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFB45309),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BARRA DE PAGINAÇÃO COM SELETOR DE ITENS POR PÁGINA (20, 40, 100, 200)
// ─────────────────────────────────────────────────────────────────────────────
class _ProductPaginationBar extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final int totalItems;
  final int startIndex;
  final int endIndex;
  final int itemsPerPage;
  final List<int> pageSizeOptions;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onPageSizeChanged;

  const _ProductPaginationBar({
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.startIndex,
    required this.endIndex,
    required this.itemsPerPage,
    required this.pageSizeOptions,
    required this.onPageChanged,
    required this.onPageSizeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final canPrev = currentPage > 1;
    final canNext = currentPage < totalPages;

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(
          top: BorderSide(color: Color(0xFFF1F5F9), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // ── Esquerda: Contador de Registros ─────────────────────────────────
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.format_list_numbered_rounded,
                  size: 18, color: Color(0xFF64748B)),
              const SizedBox(width: 8),
              Text(
                totalItems > 0
                    ? 'Exibindo $startIndex–$endIndex de $totalItems produtos'
                    : 'Nenhum produto cadastrado',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF475569),
                ),
              ),
            ],
          ),

          // ── Direita: Seletor de Itens por Página + Navegação ───────────────
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Seletor de Quantidade por Página (20, 40, 100, 200)
              Text(
                'Itens por página:',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: itemsPerPage,
                    isDense: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded,
                        size: 16, color: Color(0xFF64748B)),
                    items: pageSizeOptions.map((size) {
                      return DropdownMenuItem<int>(
                        value: size,
                        child: Text(
                          '$size',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (newSize) {
                      if (newSize != null) {
                        onPageSizeChanged(newSize);
                      }
                    },
                  ),
                ),
              ),

              const SizedBox(width: 20),

              // Botão Primeira Página (<<)
              IconButton(
                tooltip: 'Primeira Página',
                icon: const Icon(Icons.first_page_rounded, size: 20),
                color:
                    canPrev ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: canPrev ? () => onPageChanged(1) : null,
              ),

              // Botão Anterior (<)
              IconButton(
                tooltip: 'Página Anterior',
                icon: const Icon(Icons.chevron_left_rounded, size: 20),
                color:
                    canPrev ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed:
                    canPrev ? () => onPageChanged(currentPage - 1) : null,
              ),

              const SizedBox(width: 6),

              // Indicador da Página Atual
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  '$currentPage / $totalPages',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),

              const SizedBox(width: 6),

              // Botão Próxima (>)
              IconButton(
                tooltip: 'Próxima Página',
                icon: const Icon(Icons.chevron_right_rounded, size: 20),
                color:
                    canNext ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed:
                    canNext ? () => onPageChanged(currentPage + 1) : null,
              ),

              // Botão Última Página (>>)
              IconButton(
                tooltip: 'Última Página',
                icon: const Icon(Icons.last_page_rounded, size: 20),
                color:
                    canNext ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: canNext ? () => onPageChanged(totalPages) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. SELETOR DE CATEGORIA / RAMIFICAÇÃO (NATIVAS + PERSONALIZADAS)
// ─────────────────────────────────────────────────────────────────────────────
class _SectorSelectorView extends StatefulWidget {
  final double parentWidth;
  final VoidCallback onBack;
  final ValueChanged<CategoryModel> onCategorySelected;

  const _SectorSelectorView({
    required this.parentWidth,
    required this.onBack,
    required this.onCategorySelected,
  });

  @override
  State<_SectorSelectorView> createState() => _SectorSelectorViewState();
}

class _SectorSelectorViewState extends State<_SectorSelectorView> {
  late final ProductRepository _repo;
  final _searchSectorCtrl = TextEditingController();
  String _filter = '';

  @override
  void initState() {
    super.initState();
    try {
      _repo = Modular.get<ProductRepository>();
    } catch (_) {
      _repo = ProductRepository();
    }
  }

  @override
  void dispose() {
    _searchSectorCtrl.dispose();
    super.dispose();
  }

  void _openCategoryDialog([CategoryModel? categoryToEdit]) {
    showDialog(
      context: context,
      builder: (ctx) => _CategoryFormDialog(categoryToEdit: categoryToEdit),
    );
  }

  void _confirmDeleteCategory(CategoryModel category) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Color(0xFFEF4444), size: 24),
            const SizedBox(width: 8),
            Text(
              'Excluir Categoria',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Deseja realmente excluir a categoria personalizada "${category.title}"?\nOs produtos já cadastrados não serão apagados.',
          style:
              GoogleFonts.inter(fontSize: 14, color: const Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'CANCELAR',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                Navigator.pop(ctx);
                await _repo.deleteCategory(category.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Categoria removida com sucesso!'),
                    backgroundColor: Color(0xFF10B981),
                    behavior: SnackBarBehavior.floating,
                  ));
                }
              },
              borderRadius: BorderRadius.circular(10),
              child: Ink(
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(10),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Text(
                  'EXCLUIR',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.white,
                  ),
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
    final isMobile = widget.parentWidth < 768;
    // Cálculo responsivo de largura de cada card usando Wrap
    final availableWidth = widget.parentWidth -
        (isMobile ? 28 : 64);
    final int columns = availableWidth > 1200
        ? 4
        : availableWidth > 800
            ? 3
            : availableWidth > 500
                ? 2
                : 1;

    final double cardWidth = (availableWidth - ((columns - 1) * 16)) / columns;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 14 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Botão Voltar
          Align(
            alignment: Alignment.centerLeft,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onBack,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_back_rounded,
                          size: 16, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Text(
                        'Voltar para o Catálogo',
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
          ),
          const SizedBox(height: 12),

          // Título
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isMobile ? 10 : 12),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.category_rounded,
                    color: Colors.white, size: isMobile ? 20 : 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Qual é a área de atuação do seu produto ou serviço?',
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Selecione uma categoria existente ou crie uma nova personalizada para seu segmento',
                      style: GoogleFonts.inter(
                          fontSize: 13, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Barra de Ações: Busca + Botão Nova Categoria
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 380,
                child: TextField(
                  controller: _searchSectorCtrl,
                  onChanged: (v) =>
                      setState(() => _filter = v.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText:
                        'Filtrar categorias (ex: limpeza, moda, serviços...)',
                    hintStyle: GoogleFonts.inter(
                        fontSize: 13, color: const Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: Color(0xFF64748B), size: 20),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                          color: AppColors.primary, width: 1.5),
                    ),
                  ),
                ),
              ),

              // Botão Cadastrar Nova Categoria
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _openCategoryDialog(),
                  borderRadius: BorderRadius.circular(10),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add_circle_outline_rounded,
                            color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'NOVA CATEGORIA',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
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

          const SizedBox(height: 24),

          // Grade Reativa de Categorias
          StreamBuilder<List<CategoryModel>>(
            stream: _repo.getCategoriesStream(),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                );
              }

              final all = snap.data ?? CategoryModel.nativeCategories;
              final filtered = all.where((c) {
                if (_filter.isEmpty) return true;
                return c.title.toLowerCase().contains(_filter) ||
                    c.description.toLowerCase().contains(_filter);
              }).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      children: [
                        const Icon(Icons.category_outlined,
                            size: 48, color: Color(0xFF94A3B8)),
                        const SizedBox(height: 12),
                        Text(
                          'Nenhuma categoria encontrada com o termo "$_filter"',
                          style: GoogleFonts.inter(
                              fontSize: 14, color: const Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 12),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _openCategoryDialog(),
                            borderRadius: BorderRadius.circular(8),
                            child: Ink(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Criar categoria com este nome',
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: filtered.map((c) {
                  return SizedBox(
                    width: cardWidth,
                    height: 144,
                    child: _CategoryCard(
                      category: c,
                      onTap: () => widget.onCategorySelected(c),
                      onEdit: c.isCustom ? () => _openCategoryDialog(c) : null,
                      onDelete:
                          c.isCustom ? () => _confirmDeleteCategory(c) : null,
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final CategoryModel category;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _CategoryCard({
    required this.category,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: category.isCustom
                  ? category.themeColor.withValues(alpha: 0.4)
                  : AppColors.border,
              width: category.isCustom ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: category.themeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(category.icon,
                        color: category.themeColor, size: 20),
                  ),
                  if (category.isCustom) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: category.themeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Personalizada',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: category.themeColor,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (category.isCustom) ...[
                    if (onEdit != null)
                      IconButton(
                        tooltip: 'Editar Categoria',
                        icon: const Icon(Icons.edit_outlined,
                            size: 16, color: Color(0xFF6366F1)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: onEdit,
                      ),
                    if (onDelete != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Excluir Categoria',
                        icon: const Icon(Icons.delete_outline_rounded,
                            size: 16, color: Color(0xFFEF4444)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: onDelete,
                      ),
                    ],
                  ] else ...[
                    const Icon(Icons.arrow_forward_ios_rounded,
                        size: 14, color: Color(0xFF94A3B8)),
                  ],
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    category.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFF64748B),
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MODAL GRANDE: CADASTRO / EDIÇÃO DE CATEGORIAS COM SELETOR DE ÍCONE E COR
// ─────────────────────────────────────────────────────────────────────────────
class _CategoryFormDialog extends StatefulWidget {
  final CategoryModel? categoryToEdit;

  const _CategoryFormDialog({this.categoryToEdit});

  @override
  State<_CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<_CategoryFormDialog> {
  late final ProductRepository _repo;
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _iconSearchCtrl = TextEditingController();

  late IconData _selectedIcon;
  late int _selectedColorValue;
  String _iconFilter = '';
  bool _isLoading = false;
  String? _errorMessage;

  bool get _isEditing => widget.categoryToEdit != null;

  @override
  void initState() {
    super.initState();
    try {
      _repo = Modular.get<ProductRepository>();
    } catch (_) {
      _repo = ProductRepository();
    }

    if (_isEditing) {
      _titleCtrl.text = widget.categoryToEdit!.title;
      _descCtrl.text = widget.categoryToEdit!.description;
      _selectedIcon = widget.categoryToEdit!.icon;
      _selectedColorValue = widget.categoryToEdit!.colorValue;
    } else {
      _selectedIcon = CategoryIconOption.allIcons.first.icon;
      _selectedColorValue = CategoryColorOption.allColors.first.value;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _iconSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    final desc = _descCtrl.text.trim();

    if (title.isEmpty) {
      setState(() => _errorMessage = 'O nome da categoria é obrigatório.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isEditing) {
        final updated = widget.categoryToEdit!.copyWith(
          title: title,
          description: desc,
          iconCodePoint: _selectedIcon.codePoint,
          iconFontFamily: _selectedIcon.fontFamily,
          colorValue: _selectedColorValue,
        );
        await _repo.updateCategory(updated);
      } else {
        AuthRepository auth;
        try {
          auth = Modular.get<AuthRepository>();
        } catch (_) {
          auth = AuthRepository();
        }
        final companyId = await auth.getCurrentCompanyId();

        await _repo.createCategory(
          title: title,
          description:
              desc.isNotEmpty ? desc : 'Produtos e serviços personalizados',
          iconCodePoint: _selectedIcon.codePoint,
          iconFontFamily: _selectedIcon.fontFamily,
          colorValue: _selectedColorValue,
          companyId: companyId,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isEditing
              ? 'Categoria atualizada com sucesso!'
              : 'Categoria criada com sucesso!'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Erro ao salvar: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = Color(_selectedColorValue);

    final filteredIcons = CategoryIconOption.allIcons.where((i) {
      if (_iconFilter.isEmpty) return true;
      return i.label.toLowerCase().contains(_iconFilter);
    }).toList();

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 680,
        height: 720,
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabeçalho do Diálogo
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: themeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_selectedIcon, color: themeColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isEditing
                            ? 'Editar Categoria'
                            : 'Cadastrar Nova Categoria',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Defina o nome, ícone e cor temática da categoria',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Fechar',
                  icon:
                      const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            const SizedBox(height: 14),
            const Divider(color: AppColors.divider),
            const SizedBox(height: 14),

            if (_errorMessage != null) ...[
              _FormErrorBanner(message: _errorMessage!),
              const SizedBox(height: 12),
            ],

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nome da Categoria
                    _dialogLabel('Nome da Categoria *'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _titleCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText:
                            'Ex: Artigos Religiosos, Distribuidora de Gás, Papelaria...',
                        prefixIcon: Icon(Icons.category_outlined,
                            color: Color(0xFF64748B)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Descrição
                    _dialogLabel('Descrição / Exemplos de Itens'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _descCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText:
                            'Ex: Velas, imagens, incensos, artigos para presentes...',
                        prefixIcon:
                            Icon(Icons.notes_rounded, color: Color(0xFF64748B)),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Paleta de Cores
                    _dialogLabel('Cor do Tema da Categoria'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: CategoryColorOption.allColors.map((c) {
                        final isSelected = c.value == _selectedColorValue;
                        return InkWell(
                          onTap: () =>
                              setState(() => _selectedColorValue = c.value),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: c.color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color:
                                    isSelected ? Colors.black87 : Colors.white,
                                width: isSelected ? 2.5 : 1.5,
                              ),
                              boxShadow: [
                                if (isSelected)
                                  BoxShadow(
                                    color: c.color.withValues(alpha: 0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                              ],
                            ),
                            child: isSelected
                                ? const Icon(Icons.check,
                                    size: 16, color: Colors.white)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),

                    // Seletor de Ícone
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _dialogLabel('Escolha o Ícone'),
                        Text(
                          '${CategoryIconOption.allIcons.length} ícones disponíveis',
                          style: GoogleFonts.inter(
                              fontSize: 11, color: const Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Busca de ícones
                    SizedBox(
                      height: 38,
                      child: TextField(
                        controller: _iconSearchCtrl,
                        onChanged: (v) => setState(
                            () => _iconFilter = v.trim().toLowerCase()),
                        decoration: InputDecoration(
                          hintText:
                              'Buscar ícone (ex: carro, comida, ferramenta...)',
                          hintStyle: GoogleFonts.inter(
                              fontSize: 11, color: const Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.search_rounded,
                              size: 16, color: Color(0xFF64748B)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  const BorderSide(color: AppColors.border)),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  const BorderSide(color: AppColors.border)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Grade de Ícones
                    Container(
                      height: 160,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 8,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                        itemCount: filteredIcons.length,
                        itemBuilder: (ctx, idx) {
                          final opt = filteredIcons[idx];
                          final isSelected =
                              opt.icon.codePoint == _selectedIcon.codePoint;
                          return Tooltip(
                            message: opt.label,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () =>
                                    setState(() => _selectedIcon = opt.icon),
                                borderRadius: BorderRadius.circular(8),
                                child: Ink(
                                  decoration: BoxDecoration(
                                    color:
                                        isSelected ? themeColor : Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelected
                                          ? themeColor
                                          : AppColors.border,
                                      width: isSelected ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Icon(
                                    opt.icon,
                                    size: 20,
                                    color: isSelected
                                        ? Colors.white
                                        : const Color(0xFF475569),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Pré-Visualização do Card
                    _dialogLabel('Pré-visualização do Card'),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      height: 110,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: themeColor.withValues(alpha: 0.5),
                            width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: themeColor.withValues(alpha: 0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: themeColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(_selectedIcon,
                                color: themeColor, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _titleCtrl.text.trim().isNotEmpty
                                      ? _titleCtrl.text.trim()
                                      : 'Nome da Categoria',
                                  style: GoogleFonts.outfit(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF0F172A)),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _descCtrl.text.trim().isNotEmpty
                                      ? _descCtrl.text.trim()
                                      : 'Descrição e exemplos de produtos da categoria',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: const Color(0xFF64748B)),
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

            const SizedBox(height: 16),
            const Divider(color: AppColors.divider),
            const SizedBox(height: 14),

            // Botões de Ação
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'CANCELAR',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B)),
                  ),
                ),
                const SizedBox(width: 12),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isLoading ? null : _submit,
                    borderRadius: BorderRadius.circular(12),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      child: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              _isEditing
                                  ? 'SALVAR ALTERAÇÕES'
                                  : 'CADASTRAR CATEGORIA',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
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

  Widget _dialogLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF334155),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. FORMULÁRIO DINÂMICO ADAPTATIVO POR CATEGORIA / SEGMENTO
// ─────────────────────────────────────────────────────────────────────────────
class _ProductFormCard extends StatefulWidget {
  final CategoryModel category;
  final ProductModel? product;
  final UserModel? currentUser;
  final VoidCallback onBack;
  final VoidCallback? onChangeSector;
  final VoidCallback onSuccess;

  const _ProductFormCard({
    required this.category,
    this.product,
    this.currentUser,
    required this.onBack,
    this.onChangeSector,
    required this.onSuccess,
  });

  @override
  State<_ProductFormCard> createState() => _ProductFormCardState();
}

class _ProductFormCardState extends State<_ProductFormCard> {
  late final ProductRepository _repo;
  late final SupplierRepository _supplierRepo;

  // Controladores universais
  final _nameCtrl = TextEditingController();
  final _skuCtrl = TextEditingController();
  final _barcodeCtrl = TextEditingController();
  final _subcategoryCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _salePriceCtrl = TextEditingController();
  final _costPriceCtrl = TextEditingController();
  final _stockCtrl = TextEditingController(text: '0');
  final _minStockCtrl = TextEditingController(text: '5');
  final _ncmCtrl = TextEditingController();

  String? _selectedSupplierId;
  String? _selectedSupplierName;

  ProductUnit _unit = ProductUnit.un;
  ProductStatus _status = ProductStatus.active;
  bool _isLoading = false;
  String? _errorMessage;

  // Mapa de Controladores para Campos Específicos do Nicho
  final Map<String, TextEditingController> _dynamicControllers = {};

  bool get _isEditing => widget.product != null;

  ProductSector get _effectiveSector =>
      widget.category.matchingSector ?? ProductSector.cleaning;

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

    _initDynamicControllers();

    if (_isEditing) {
      final p = widget.product!;
      _nameCtrl.text = p.name;
      _skuCtrl.text = p.sku ?? '';
      _barcodeCtrl.text = p.barcode ?? '';
      _subcategoryCtrl.text = p.subcategory ?? '';
      _descriptionCtrl.text = p.description ?? '';
      _selectedSupplierId = p.supplierId;
      _selectedSupplierName = p.supplierName;
      _salePriceCtrl.text = p.salePrice.toStringAsFixed(2);
      _costPriceCtrl.text =
          p.costPrice != null ? p.costPrice!.toStringAsFixed(2) : '';
      _stockCtrl.text = p.stockQuantity.toStringAsFixed(0);
      _minStockCtrl.text = p.minStock.toStringAsFixed(0);
      _ncmCtrl.text = p.ncm ?? '';
      _unit = p.unit;
      _status = p.status;

      p.specificAttributes.forEach((key, val) {
        if (_dynamicControllers.containsKey(key)) {
          _dynamicControllers[key]!.text = val.toString();
        }
      });
    }
  }

  void _initDynamicControllers() {
    final sector = widget.category.matchingSector;
    if (sector == null) {
      // Categoria Personalizada
      _dynamicControllers['brand'] = TextEditingController();
      _dynamicControllers['model'] = TextEditingController();
      _dynamicControllers['warranty'] = TextEditingController();
      _dynamicControllers['technicalNotes'] = TextEditingController();
      return;
    }

    switch (sector) {
      case ProductSector.solarPlant:
        _dynamicControllers['moduleWatts'] = TextEditingController();
        _dynamicControllers['efficiencyWarrantyYears'] = TextEditingController();
        _dynamicControllers['mfgWarrantyYears'] = TextEditingController();
        _dynamicControllers['inverterPowerKwp'] = TextEditingController();
        _dynamicControllers['overloadMaxKwp'] = TextEditingController();
        _dynamicControllers['microPowerKwp'] = TextEditingController();
        _dynamicControllers['batteryCapacityKwh'] = TextEditingController();
        _dynamicControllers['batteryVoltage'] = TextEditingController();
        _dynamicControllers['brand'] = TextEditingController();
        _dynamicControllers['model'] = TextEditingController();
        _dynamicControllers['warranty'] = TextEditingController();
        _dynamicControllers['technicalNotes'] = TextEditingController();
        break;

      case ProductSector.cleaning:
        _dynamicControllers['fragrance'] = TextEditingController();
        _dynamicControllers['dilution'] = TextEditingController();
        _dynamicControllers['volume'] = TextEditingController();
        _dynamicControllers['anvisa'] = TextEditingController();
        _dynamicControllers['ph'] = TextEditingController();
        break;

      case ProductSector.food:
        _dynamicControllers['expiration'] = TextEditingController();
        _dynamicControllers['netWeight'] = TextEditingController();
        _dynamicControllers['allergens'] = TextEditingController();
        _dynamicControllers['storage'] = TextEditingController();
        break;

      case ProductSector.fashion:
        _dynamicControllers['sizeGrade'] = TextEditingController();
        _dynamicControllers['color'] = TextEditingController();
        _dynamicControllers['gender'] = TextEditingController();
        _dynamicControllers['material'] = TextEditingController();
        break;

      case ProductSector.construction:
        _dynamicControllers['dimensions'] = TextEditingController();
        _dynamicControllers['yieldPerUnit'] = TextEditingController();
        _dynamicControllers['voltage'] = TextEditingController();
        _dynamicControllers['finishColor'] = TextEditingController();
        break;

      case ProductSector.pharmacy:
        _dynamicControllers['batchNumber'] = TextEditingController();
        _dynamicControllers['anvisaReg'] = TextEditingController();
        _dynamicControllers['activeIngredient'] = TextEditingController();
        _dynamicControllers['skinHairType'] = TextEditingController();
        break;

      case ProductSector.tech:
        _dynamicControllers['warrantyMonths'] = TextEditingController();
        _dynamicControllers['voltage'] = TextEditingController();
        _dynamicControllers['connectivity'] = TextEditingController();
        _dynamicControllers['serialNumber'] = TextEditingController();
        break;

      case ProductSector.autoparts:
        _dynamicControllers['vehicleCompat'] = TextEditingController();
        _dynamicControllers['yearCompat'] = TextEditingController();
        _dynamicControllers['position'] = TextEditingController();
        _dynamicControllers['oemCode'] = TextEditingController();
        break;

      case ProductSector.stationery:
        _dynamicControllers['brand'] = TextEditingController();
        _dynamicControllers['grammage'] = TextEditingController();
        _dynamicControllers['packageQty'] = TextEditingController();
        break;

      case ProductSector.pet:
        _dynamicControllers['petSize'] = TextEditingController();
        _dynamicControllers['petAge'] = TextEditingController();
        _dynamicControllers['petSpecies'] = TextEditingController();
        break;

      case ProductSector.furniture:
        _dynamicControllers['dimensions'] = TextEditingController();
        _dynamicControllers['mainMaterial'] = TextEditingController();
        _dynamicControllers['needsAssembly'] = TextEditingController();
        break;

      case ProductSector.restaurant:
        _dynamicControllers['prepTimeMin'] = TextEditingController();
        _dynamicControllers['servings'] = TextEditingController();
        _dynamicControllers['ingredients'] = TextEditingController();
        break;

      case ProductSector.generalServices:
        _dynamicControllers['estimatedDuration'] = TextEditingController();
        _dynamicControllers['modality'] = TextEditingController();
        _dynamicControllers['requirements'] = TextEditingController();
        break;

      case ProductSector.healthServices:
        _dynamicControllers['sessionDuration'] = TextEditingController();
        _dynamicControllers['specialty'] = TextEditingController();
        _dynamicControllers['needsEval'] = TextEditingController();
        break;

      case ProductSector.education:
        _dynamicControllers['courseHours'] = TextEditingController();
        _dynamicControllers['courseModality'] = TextEditingController();
        _dynamicControllers['certificate'] = TextEditingController();
        break;

      case ProductSector.mechanic:
        _dynamicControllers['execHours'] = TextEditingController();
        _dynamicControllers['vehicleType'] = TextEditingController();
        break;

      case ProductSector.printing:
        _dynamicControllers['printFormat'] = TextEditingController();
        _dynamicControllers['mediaType'] = TextEditingController();
        _dynamicControllers['colorMode'] = TextEditingController();
        break;

      case ProductSector.optics:
        _dynamicControllers['frameType'] = TextEditingController();
        _dynamicControllers['frameMaterial'] = TextEditingController();
        _dynamicControllers['uvProtection'] = TextEditingController();
        break;

      case ProductSector.toys:
        _dynamicControllers['recommendedAge'] = TextEditingController();
        _dynamicControllers['inmetroSeal'] = TextEditingController();
        break;

      case ProductSector.gardening:
        _dynamicControllers['wateringFrequency'] = TextEditingController();
        _dynamicControllers['sunlight'] = TextEditingController();
        _dynamicControllers['plantSize'] = TextEditingController();
        break;

      case ProductSector.industry:
        _dynamicControllers['rawMaterial'] = TextEditingController();
        _dynamicControllers['tolerance'] = TextEditingController();
        _dynamicControllers['standardNorm'] = TextEditingController();
        break;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _skuCtrl.dispose();
    _barcodeCtrl.dispose();
    _subcategoryCtrl.dispose();
    _descriptionCtrl.dispose();
    _salePriceCtrl.dispose();
    _costPriceCtrl.dispose();
    _stockCtrl.dispose();
    _minStockCtrl.dispose();
    _ncmCtrl.dispose();
    for (final c in _dynamicControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final salePriceText = _salePriceCtrl.text.replaceAll(',', '.').trim();

    if (name.isEmpty) {
      setState(
          () => _errorMessage = 'O nome do produto/serviço é obrigatório.');
      return;
    }

    final salePrice = double.tryParse(salePriceText) ?? 0.0;

    final costPrice =
        double.tryParse(_costPriceCtrl.text.replaceAll(',', '.').trim());
    final stock =
        double.tryParse(_stockCtrl.text.replaceAll(',', '.').trim()) ?? 0.0;
    final minStock =
        double.tryParse(_minStockCtrl.text.replaceAll(',', '.').trim()) ?? 5.0;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final messenger = ScaffoldMessenger.of(context);

    final Map<String, dynamic> attributes = {};
    _dynamicControllers.forEach((key, ctrl) {
      if (ctrl.text.trim().isNotEmpty) {
        attributes[key] = ctrl.text.trim();
      }
    });

    String? n(String? v) => (v == null || v.trim().isEmpty) ? null : v.trim();

    try {
      if (_isEditing) {
        final updated = widget.product!.copyWith(
          name: name,
          sku: n(_skuCtrl.text),
          barcode: n(_barcodeCtrl.text),
          sector: widget.category.matchingSector ?? widget.product!.sector,
          categoryTitle: widget.category.title,
          subcategory: n(_subcategoryCtrl.text),
          description: n(_descriptionCtrl.text),
          supplierId: _selectedSupplierId,
          supplierName: _selectedSupplierName,
          salePrice: salePrice,
          costPrice: costPrice,
          stockQuantity: stock,
          minStock: minStock,
          unit: _unit,
          ncm: n(_ncmCtrl.text),
          status: _status,
          specificAttributes: attributes,
          updatedAt: DateTime.now(),
        );
        await _repo.updateProduct(updated);
      } else {
        AuthRepository auth;
        try {
          auth = Modular.get<AuthRepository>();
        } catch (_) {
          auth = AuthRepository();
        }
        final user = widget.currentUser ?? await auth.getCurrentUser();
        final companyId = user?.effectiveCompanyId ?? await auth.getCurrentCompanyId();

        await _repo.createProduct(
          name: name,
          sku: n(_skuCtrl.text),
          barcode: n(_barcodeCtrl.text),
          sector: _effectiveSector,
          categoryTitle: widget.category.title,
          subcategory: n(_subcategoryCtrl.text),
          description: n(_descriptionCtrl.text),
          supplierId: _selectedSupplierId,
          supplierName: _selectedSupplierName,
          salePrice: salePrice,
          costPrice: costPrice,
          stockQuantity: stock,
          minStock: minStock,
          unit: _unit,
          ncm: n(_ncmCtrl.text),
          status: _status,
          specificAttributes: attributes,
          companyId: companyId,
          createdByUserId: user?.uid,
          createdByUserName: user?.name,
        );
      }

      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text(_isEditing
            ? 'Produto atualizado com sucesso!'
            : 'Produto cadastrado com sucesso!'),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ));
      widget.onSuccess();
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Erro ao salvar produto: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openSubcategoriesDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _SubcategoriesDialog(
        sector: _effectiveSector,
        onSelect: (selectedName) {
          setState(() {
            _subcategoryCtrl.text = selectedName;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Botão Voltar ──────────────────────────────────────────────────
          Align(
            alignment: Alignment.centerLeft,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onBack,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_back_rounded,
                          size: 16, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Text(
                        'Voltar para o Catálogo',
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
          ),
          const SizedBox(height: 12),

          // ── Cabeçalho do Formulário ───────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.category.themeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: widget.category.themeColor.withValues(alpha: 0.3)),
                ),
                child: Icon(widget.category.icon,
                    color: widget.category.themeColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isEditing
                          ? ((widget.product?.isSolarComponent == true ||
                                  widget.category.matchingSector == ProductSector.solarPlant)
                              ? 'Editar Item Avulso'
                              : 'Editar Produto')
                          : 'Novo Cadastro',
                      style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary),
                    ),
                    Text(
                      (widget.product?.isSolarComponent == true ||
                              widget.category.matchingSector == ProductSector.solarPlant)
                          ? 'Usina Solar • Item Avulso / Equipamento'
                          : 'Categoria: ${widget.category.title}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: widget.category.themeColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.onChangeSector != null)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: widget.onChangeSector,
                    borderRadius: BorderRadius.circular(10),
                    child: Ink(
                      decoration: BoxDecoration(
                        color:
                            widget.category.themeColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: widget.category.themeColor),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.swap_horiz_rounded,
                              size: 16, color: widget.category.themeColor),
                          const SizedBox(width: 6),
                          Text(
                            'Trocar Categoria',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: widget.category.themeColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: AppColors.divider),
          const SizedBox(height: 16),

          // Erro global
          if (_errorMessage != null) ...[
            _FormErrorBanner(message: _errorMessage!),
            const SizedBox(height: 16),
          ],

          // ── SEÇÃO 1: INFORMAÇÕES GERAIS ──────────────────────────────────
          _FormSectionHeader(
            icon: Icons.info_outline_rounded,
            title: 'Informações Básicas',
            subtitle: 'Identificação principal do item no sistema',
          ),
          const SizedBox(height: 14),

          // Nome do Produto
          _label('Nome do Produto / Serviço *'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              hintText: 'Ex: Desinfetante Floral 5L ou Camiseta Algodão Básica',
              prefixIcon:
                  Icon(Icons.label_outline_rounded, color: Color(0xFF64748B)),
            ),
          ),
          const SizedBox(height: 14),

          // SKU + Código de Barras + Subcategoria
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Código SKU / Interno'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _skuCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Ex: LIM-001',
                        prefixIcon: Icon(Icons.qr_code_2_rounded,
                            color: Color(0xFF64748B)),
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
                    _label('Código de Barras / EAN'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _barcodeCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: '7890000000000',
                        prefixIcon: Icon(Icons.barcode_reader,
                            color: Color(0xFF64748B)),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _label('Subcategoria'),
                        Text(
                          'clique em + p/ Add!',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _subcategoryCtrl,
                      decoration: InputDecoration(
                        hintText: 'Ex: Desinfetantes',
                        prefixIcon: const Icon(Icons.folder_outlined,
                            color: Color(0xFF64748B)),
                        suffixIcon: Tooltip(
                          message:
                              'Gerenciar Subcategorias (Lista / Adicionar / Editar / Excluir)',
                          child: IconButton(
                            icon: const Icon(Icons.playlist_add_rounded,
                                color: AppColors.primary, size: 22),
                            onPressed: _openSubcategoriesDialog,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Fornecedor / Distribuidor Parceiro ────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _label('Fornecedor / Distribuidor Parceiro'),
              Text(
                'opcional / compras',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          StreamBuilder<List<SupplierModel>>(
            stream: _supplierRepo.getSuppliersStream(),
            builder: (ctx, snap) {
              final suppliers = snap.data ?? [];
              final hasSelection = _selectedSupplierId != null &&
                  suppliers.any((s) => s.id == _selectedSupplierId);

              return DropdownButtonFormField<String?>(
                initialValue: hasSelection ? _selectedSupplierId : null,
                isExpanded: true,
                decoration: const InputDecoration(
                  hintText:
                      'Selecione o fornecedor ou deixe como fabricação própria...',
                  prefixIcon: Icon(Icons.local_shipping_outlined,
                      color: Color(0xFF64748B)),
                ),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(
                      'Nenhum fornecedor / Fabricação Própria',
                      style: GoogleFonts.inter(
                          color: const Color(0xFF64748B), fontSize: 13),
                    ),
                  ),
                  ...suppliers.map((s) => DropdownMenuItem<String?>(
                        value: s.id,
                        child: Text(
                          s.displayName +
                              (s.contactPerson?.isNotEmpty == true
                                  ? ' (${s.contactPerson})'
                                  : ''),
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                              fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      )),
                ],
                onChanged: (val) {
                  setState(() {
                    _selectedSupplierId = val;
                    if (val != null) {
                      final found =
                          suppliers.where((s) => s.id == val).firstOrNull;
                      _selectedSupplierName = found?.displayName;
                    } else {
                      _selectedSupplierName = null;
                    }
                  });
                },
              );
            },
          ),
          const SizedBox(height: 14),

          // Descrição
          _label('Descrição detalhada do produto / serviço'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _descriptionCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText:
                  'Anotações sobre a composição, instruções de uso ou detalhes adicionais...',
              prefixIcon: Icon(Icons.notes_rounded, color: Color(0xFF64748B)),
            ),
          ),
          const SizedBox(height: 22),

          // ── SEÇÃO 2: PRECIFICAÇÃO & ESTOQUE ──────────────────────────────
          _FormSectionHeader(
            icon: Icons.monetization_on_outlined,
            title: 'Precificação & Estoque',
            subtitle: 'Controle de valores, margem de lucro e reposição',
          ),
          const SizedBox(height: 14),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Preço Venda
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Preço de Venda (R\$)'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _salePriceCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        hintText: '0,00',
                        prefixText: 'R\$ ',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Preço Custo
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Preço de Custo (R\$)'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _costPriceCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        hintText: '0,00',
                        prefixText: 'R\$ ',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Unidade de Medida
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Unidade de Medida'),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<ProductUnit>(
                      initialValue: _unit,
                      decoration: const InputDecoration(
                        prefixIcon:
                            Icon(Icons.scale_rounded, color: Color(0xFF64748B)),
                      ),
                      items: ProductUnit.values
                          .map((u) => DropdownMenuItem(
                                value: u,
                                child: Text('${u.symbol} - ${u.label}',
                                    style: GoogleFonts.inter(fontSize: 13)),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _unit = v!),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Estoque Atual + Estoque Mínimo + NCM
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Estoque Atual'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _stockCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        hintText: '0',
                        prefixIcon: Icon(Icons.inventory_2_outlined,
                            color: Color(0xFF64748B)),
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
                    _label('Estoque Mínimo (Alerta)'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _minStockCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        hintText: '5',
                        prefixIcon: Icon(Icons.notification_important_outlined,
                            color: Color(0xFF64748B)),
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
                    _label('NCM (Código Fiscal)'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _ncmCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: '0000.00.00',
                        prefixIcon: Icon(Icons.receipt_long_outlined,
                            color: Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),

          // ── SEÇÃO 3: CAMPOS ESPECÍFICOS DA CATEGORIA / SEGMENTO ────────────
          _FormSectionHeader(
            icon: widget.category.icon,
            title: 'Campos Específicos: ${widget.category.title}',
            subtitle: widget.category.isCustom
                ? 'Informações técnicas e especificações do produto/serviço'
                : 'Personalizado automaticamente para seu segmento de atuação',
            customColor: widget.category.themeColor,
          ),
          const SizedBox(height: 14),

          // Renderização dinâmica dos campos específicos
          _buildDynamicFields(),

          const SizedBox(height: 20),

          // ── Status (só na edição) ─────────────────────────────────────────
          if (_isEditing) ...[
            _label('Status do Produto'),
            const SizedBox(height: 6),
            DropdownButtonFormField<ProductStatus>(
              initialValue: _status,
              decoration: const InputDecoration(
                prefixIcon:
                    Icon(Icons.toggle_on_outlined, color: Color(0xFF64748B)),
              ),
              items: ProductStatus.values
                  .map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(s.label,
                            style: GoogleFonts.inter(fontSize: 14)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _status = v!),
            ),
            const SizedBox(height: 24),
          ],

          // ── Botão Salvar ──────────────────────────────────────────────────
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isLoading ? null : _submit,
              borderRadius: BorderRadius.circular(12),
              child: Ink(
                decoration: BoxDecoration(
                  color: widget.category.themeColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: widget.category.themeColor.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(vertical: 15),
                child: Center(
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        )
                      : Text(
                          _isEditing
                              ? 'SALVAR ALTERAÇÕES'
                              : 'CADASTRAR PRODUTO',
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Renderização dos Campos Específicos por Categoria / Segmento ───────────
  Widget _buildDynamicFields() {
    final sector = widget.category.matchingSector;
    if (sector == null) {
      // Categoria Personalizada criada pelo usuário
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _dynField(
                  'brand',
                  'Marca / Fabricante / Autor',
                  'Ex: Própria, Importado, Marca X',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _dynField(
                  'model',
                  'Modelo / Linha / Versão',
                  'Ex: Linha Premium 2026',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _dynField(
                  'warranty',
                  'Garantia / Validade',
                  'Ex: 90 dias, 12 meses, N/A',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _dynField(
            'technicalNotes',
            'Especificações Técnicas / Observações do Ramo',
            'Detalhes técnicos adicionais específicos para esta categoria...',
          ),
        ],
      );
    }

    switch (sector) {
      // 0. Componente / Item Avulso de Usina Solar
      case ProductSector.solarPlant:
        final subcat = _subcategoryCtrl.text.toUpperCase();
        final isModule = subcat.contains('MÓDULO') || subcat.contains('MODULO') || subcat.contains('PAINEL') || subcat.contains('PLACA');
        final isInverter = subcat.contains('INVERSOR') && !subcat.contains('MICRO');
        final isMicro = subcat.contains('MICRO');
        final isBattery = subcat.contains('BATERIA');

        if (isModule) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _dynField('moduleWatts', 'Potência do Módulo (Watts)', 'Ex: 550, 580, 670'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _dynField('efficiencyWarrantyYears', 'Garantia de Eficiência (Anos)', 'Ex: 25 ou 30'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _dynField('mfgWarrantyYears', 'Garantia de Fabricação (Anos)', 'Ex: 12 ou 15'),
                  ),
                ],
              ),
            ],
          );
        } else if (isInverter) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _dynField('inverterPowerKwp', 'Potência do Inversor (kWp)', 'Ex: 5.0, 15.0'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _dynField('overloadMaxKwp', 'Overload Máx (kWp)', 'Ex: 7.5, 22.5'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _dynField('mfgWarrantyYears', 'Garantia de Fabricação (Anos)', 'Ex: 5 ou 10'),
                  ),
                ],
              ),
            ],
          );
        } else if (isMicro) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _dynField('microPowerKwp', 'Potência do Micro (kWp)', 'Ex: 2.0, 2.25'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _dynField('overloadMaxKwp', 'Overload Máx (kWp)', 'Ex: 3.0'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _dynField('mfgWarrantyYears', 'Garantia de Fabricação (Anos)', 'Ex: 12 ou 15'),
                  ),
                ],
              ),
            ],
          );
        } else if (isBattery) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _dynField('batteryCapacityKwh', 'Capacidade (kWh)', 'Ex: 5.12, 10.0'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _dynField('batteryVoltage', 'Tensão Nominal (V/Ah)', 'Ex: 51.2V / 100Ah'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _dynField('mfgWarrantyYears', 'Garantia de Fabricação (Anos)', 'Ex: 10'),
                  ),
                ],
              ),
            ],
          );
        }

        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _dynField('brand', 'Fabricante / Marca', 'Ex: Canadian, Growatt, Clamper...'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _dynField('mfgWarrantyYears', 'Garantia de Fabricação (Anos)', 'Ex: 5 ou 12 anos'),
                ),
              ],
            ),
          ],
        );

      // 1. Produtos de Limpeza & Higiene
      case ProductSector.cleaning:
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                    child: _dynField('fragrance', 'Fragrância / Aroma',
                        'Ex: Lavanda, Floral, Neutro')),
                const SizedBox(width: 12),
                Expanded(
                    child: _dynField('dilution', 'Proporção de Diluição',
                        'Ex: Pronto Uso, 1:10, 1:50')),
                const SizedBox(width: 12),
                Expanded(
                    child: _dynField('volume', 'Volume / Conteúdo Líquido',
                        'Ex: 500ml, 1 Litro, 5 Litros')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: _dynField('anvisa', 'Nº Notificação / Reg. Anvisa',
                        'Ex: 25351.000000/2024')),
                const SizedBox(width: 12),
                Expanded(
                    child: _dynField('ph', 'pH do Produto',
                        'Ex: Neutro (7.0), Ácido, Alcalino')),
              ],
            ),
          ],
        );

      // 2. Alimentos, Bebidas & Mercearia
      case ProductSector.food:
        return Row(
          children: [
            Expanded(
                child:
                    _dynField('expiration', 'Data de Validade', 'DD/MM/AAAA')),
            const SizedBox(width: 12),
            Expanded(
                child: _dynField('netWeight', 'Peso Líquido / Volume',
                    'Ex: 1kg, 350g, 2 Litros')),
            const SizedBox(width: 12),
            Expanded(
                child: _dynField('allergens', 'Alérgenos / Glúten',
                    'Ex: Contém Glúten, Zero Lactose')),
            const SizedBox(width: 12),
            Expanded(
                child: _dynField(
                    'storage', 'Conservação', 'Ex: Ambiente, Refrigerado')),
          ],
        );

      // 3. Vestuário, Calçados & Moda
      case ProductSector.fashion:
        return Row(
          children: [
            Expanded(
                child: _dynField('sizeGrade', 'Grade / Tamanho',
                    'Ex: P, M, G, GG ou 38, 40, 42')),
            const SizedBox(width: 12),
            Expanded(
                child: _dynField('color', 'Cor Predominante',
                    'Ex: Preto, Azul Marinho, Estampado')),
            const SizedBox(width: 12),
            Expanded(
                child: _dynField('gender', 'Gênero / Público',
                    'Ex: Masculino, Feminino, Unissex')),
            const SizedBox(width: 12),
            Expanded(
                child: _dynField('material', 'Tecido / Composição',
                    'Ex: 100% Algodão, Jeans, Couro')),
          ],
        );

      // 4. Material de Construção & Reforma
      case ProductSector.construction:
        return Row(
          children: [
            Expanded(
                child: _dynField('dimensions', 'Dimensões (AxLxP)',
                    'Ex: 60x60cm ou 3 metros')),
            const SizedBox(width: 12),
            Expanded(
                child: _dynField(
                    'yieldPerUnit', 'Rendimento Médio', 'Ex: 15 m² por demão')),
            const SizedBox(width: 12),
            Expanded(
                child: _dynField('voltage', 'Voltagem (se elétrico)',
                    'Ex: 110V, 220V, Bivolt, N/A')),
            const SizedBox(width: 12),
            Expanded(
                child: _dynField('finishColor', 'Acabamento / Cor',
                    'Ex: Fosco, Brilhante, Inox')),
          ],
        );

      // 5. Farmácia, Cosméticos & Cuidados
      case ProductSector.pharmacy:
        return Row(
          children: [
            Expanded(
                child: _dynField(
                    'batchNumber', 'Número do Lote', 'Ex: LOTE-2024A')),
            const SizedBox(width: 12),
            Expanded(
                child: _dynField('anvisaReg', 'Registro MS / Anvisa',
                    'Ex: 1.0000.0000.000-0')),
            const SizedBox(width: 12),
            Expanded(
                child: _dynField('activeIngredient', 'Princípio Ativo / Função',
                    'Ex: Ácido Hialurônico, Vitamina C')),
            const SizedBox(width: 12),
            Expanded(
                child: _dynField('skinHairType', 'Tipo de Pele / Cabelo',
                    'Ex: Oleosa, Seca, Todos')),
          ],
        );

      // 6. Informática, Eletrônicos & Telefonia
      case ProductSector.tech:
        return Row(
          children: [
            Expanded(
                child: _dynField('warrantyMonths', 'Garantia (Meses)',
                    'Ex: 12 meses, 24 meses')),
            const SizedBox(width: 12),
            Expanded(
                child: _dynField('voltage', 'Alimentação / Voltagem',
                    'Ex: Bivolt Automático, USB-C, 220V')),
            const SizedBox(width: 12),
            Expanded(
                child: _dynField('connectivity', 'Conectividade',
                    'Ex: Wi-Fi 6, Bluetooth 5.3, 5G')),
            const SizedBox(width: 12),
            Expanded(
                child: _dynField(
                    'serialNumber', 'Nº de Série / IMEI', 'Ex: SN1234567890')),
          ],
        );

      // 7. Autopeças, Moto & Acessórios
      case ProductSector.autoparts:
        return Row(
          children: [
            Expanded(
                child: _dynField('vehicleCompat', 'Veículo / Montadora',
                    'Ex: VW Gol, Fiat Palio, Ford Ka')),
            const SizedBox(width: 12),
            Expanded(
                child: _dynField(
                    'yearCompat', 'Anos Compatíveis', 'Ex: 2015 a 2022')),
            const SizedBox(width: 12),
            Expanded(
                child: _dynField('position', 'Posição / Lado',
                    'Ex: Dianteiro Direito, Traseiro')),
            const SizedBox(width: 12),
            Expanded(
                child: _dynField(
                    'oemCode', 'Código OEM Original', 'Ex: OEM-5U0919051A')),
          ],
        );

      // 8. Papelaria & Escritório
      case ProductSector.stationery:
        return Row(
          children: [
            Expanded(
                child: _dynField('brand', 'Marca / Fabricante',
                    'Ex: Faber-Castell, Tilibra, Chamex')),
            const SizedBox(width: 12),
            Expanded(
                child: _dynField('grammage', 'Gramatura (g/m²)',
                    'Ex: 75g/m², 90g/m², 180g/m²')),
            const SizedBox(width: 12),
            Expanded(
                child: _dynField('packageQty', 'Qtd por Pacote / Embalagem',
                    'Ex: 500 folhas, 12 unidades')),
          ],
        );

      // 9. Pet Shop & Agropecuária
      case ProductSector.pet:
        return Row(
          children: [
            Expanded(
                child: _dynField('petSpecies', 'Espécie / Indicação',
                    'Ex: Cães, Gatos, Aves, Bovinos')),
            const SizedBox(width: 12),
            Expanded(
                child: _dynField('petSize', 'Porte Indicado',
                    'Ex: Pequeno, Médio, Grande, Todos')),
            const SizedBox(width: 12),
            Expanded(
                child: _dynField(
                    'petAge', 'Fase / Idade', 'Ex: Filhote, Adulto, Sênior')),
          ],
        );

      // 10. Móveis, Decoração & Casa
      case ProductSector.furniture:
        return Row(
          children: [
            Expanded(
                child: _dynField('dimensions', 'Dimensões AxLxP (cm)',
                    'Ex: 180 x 90 x 45 cm')),
            const SizedBox(width: 12),
            Expanded(
                child: _dynField('mainMaterial', 'Material da Estrutura',
                    'Ex: MDF 18mm, Madeira Maciça, Aço')),
            const SizedBox(width: 12),
            Expanded(
                child: _dynField('needsAssembly', 'Necessita Montagem?',
                    'Ex: Sim (Complexa), Não (Montado)')),
          ],
        );

      // 11. Restaurantes, Bares & Delivery
      case ProductSector.restaurant:
        return Row(
          children: [
            Expanded(
                child: _dynField('prepTimeMin', 'Tempo Médio de Preparo',
                    'Ex: 20 a 30 minutos')),
            const SizedBox(width: 12),
            Expanded(
                child: _dynField('servings', 'Rendimento / Serve',
                    'Ex: 1 pessoa, 2 a 3 pessoas')),
            const SizedBox(width: 12),
            Expanded(
                child: _dynField(
                    'ingredients',
                    'Ingredientes / Acompanhamentos',
                    'Ex: Arroz, feijão, fritas e salada')),
          ],
        );

      // 12. Prestação de Serviços Gerais
      case ProductSector.generalServices:
        return Row(
          children: [
            Expanded(
                child: _dynField('estimatedDuration', 'Duração Estimada',
                    'Ex: 2 horas, 1 dia útil')),
            const SizedBox(width: 12),
            Expanded(
                child: _dynField('modality', 'Modalidade de Atendimento',
                    'Ex: Presencial, Remoto, Híbrido')),
            const SizedBox(width: 12),
            Expanded(
                child: _dynField('requirements', 'Pré-requisitos do Cliente',
                    'Ex: Acesso à internet, espaço livre')),
          ],
        );

      // 13. Saúde, Clínicas & Estética
      case ProductSector.healthServices:
        return Row(
          children: [
            Expanded(
                child: _dynField('sessionDuration', 'Duração da Sessão',
                    'Ex: 50 minutos, 1h30')),
            const SizedBox(width: 12),
            Expanded(
                child: _dynField('specialty', 'Especialidade / Procedimento',
                    'Ex: Fisioterapia, Limpeza de Pele')),
            const SizedBox(width: 12),
            Expanded(
                child: _dynField(
                    'needsEval', 'Requer Avaliação Prévia?', 'Ex: Sim, Não')),
          ],
        );

      // 14. Educação, Cursos & Treinamentos
      case ProductSector.education:
        return Row(
          children: [
            Expanded(
                child: _dynField('courseHours', 'Carga Horária (Horas)',
                    'Ex: 40h, 120h, 8 semanas')),
            const SizedBox(width: 12),
            Expanded(
                child: _dynField('courseModality', 'Modalidade do Curso',
                    'Ex: EAD Gravado, Ao Vivo, Presencial')),
            const SizedBox(width: 12),
            Expanded(
                child: _dynField('certificate', 'Emite Certificado Válido?',
                    'Ex: Sim (com código de validação)')),
          ],
        );

      // 15. Oficina Mecânica & Manutenção Auto
      case ProductSector.mechanic:
        return Row(
          children: [
            Expanded(
                child: _dynField('execHours', 'Tempo de Execução Médio',
                    'Ex: 1 hora, 4 horas')),
            const SizedBox(width: 12),
            Expanded(
                child: _dynField('vehicleType', 'Tipo de Veículo',
                    'Ex: Carro de passeio, SUV, Moto, Caminhão')),
          ],
        );

      // 16. Gráfica & Comunicação Visual
      case ProductSector.printing:
        return Row(
          children: [
            Expanded(
                child: _dynField('printFormat', 'Formato / Dimensões',
                    'Ex: 9x5cm, A4, 1x2m (Banner)')),
            const SizedBox(width: 12),
            Expanded(
                child: _dynField('mediaType', 'Mídia / Papel',
                    'Ex: Couché 300g, Lona Frontlight, Vinil')),
            const SizedBox(width: 12),
            Expanded(
                child: _dynField('colorMode', 'Modo de Cor / Acabamento',
                    'Ex: 4x4 Cor + Verniz Localizado')),
          ],
        );

      // 17. Óticas & Acessórios Visuais
      case ProductSector.optics:
        return Row(
          children: [
            Expanded(
                child: _dynField('frameType', 'Tipo de Armação / Lente',
                    'Ex: Grau, Solar, Clip-on')),
            const SizedBox(width: 12),
            Expanded(
                child: _dynField('frameMaterial', 'Material',
                    'Ex: Acetato, Titânio, Metal')),
            const SizedBox(width: 12),
            Expanded(
                child: _dynField('uvProtection', 'Tratamentos / Proteção',
                    'Ex: UV400, Antirreflexo, Blue Light')),
          ],
        );

      // 18. Brinquedos, Presentes & Utilidades
      case ProductSector.toys:
        return Row(
          children: [
            Expanded(
                child: _dynField('recommendedAge', 'Faixa Etária Recomendada',
                    'Ex: +3 anos, +8 anos, Livre')),
            const SizedBox(width: 12),
            Expanded(
                child: _dynField('inmetroSeal', 'Certificação Inmetro / Selo',
                    'Ex: CE-BRI/INNAC-00000')),
          ],
        );

      // 19. Floricultura, Jardinagem & Plantas
      case ProductSector.gardening:
        return Row(
          children: [
            Expanded(
                child: _dynField('wateringFrequency', 'Frequência de Rega',
                    'Ex: Diária, 2x por semana, Semanal')),
            const SizedBox(width: 12),
            Expanded(
                child: _dynField('sunlight', 'Exposição Solar Recomendada',
                    'Ex: Sol Pleno, Meia Sombra, Sombra')),
            const SizedBox(width: 12),
            Expanded(
                child: _dynField('plantSize', 'Porte Médio da Planta',
                    'Ex: Pequena (Vaso 11), Média (1m)')),
          ],
        );

      // 20. Indústria & Metalmecânica
      case ProductSector.industry:
        return Row(
          children: [
            Expanded(
                child: _dynField('rawMaterial', 'Matéria-Prima / Liga',
                    'Ex: Aço Carbono 1020, Inox 304, Alumínio')),
            const SizedBox(width: 12),
            Expanded(
                child: _dynField('tolerance', 'Tolerância Dimensional',
                    'Ex: +/- 0.05mm, DIN 2768')),
            const SizedBox(width: 12),
            Expanded(
                child: _dynField('standardNorm', 'Norma Técnica / Padrão',
                    'Ex: ABNT NBR ISO 9001, ASTM A36')),
          ],
        );
    }
  }

  Widget _dynField(String key, String label, String hint) {
    final ctrl = _dynamicControllers[key] ?? TextEditingController();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
          ),
        ),
      ],
    );
  }

  Widget _label(String text) => Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF475569),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Auxiliares do Formulário
// ─────────────────────────────────────────────────────────────────────────────
class _FormSectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? customColor;

  const _FormSectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.customColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = customColor ?? AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: color.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FormErrorBanner extends StatelessWidget {
  final String message;
  const _FormErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                color: const Color(0xFF991B1B),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// POPUP GRANDE: GERENCIADOR DE SUBCATEGORIAS (LISTA / INCLUIR / EDITAR / EXCLUIR)
// ─────────────────────────────────────────────────────────────────────────────
class _SubcategoriesDialog extends StatefulWidget {
  final ProductSector sector;
  final ValueChanged<String> onSelect;

  const _SubcategoriesDialog({
    required this.sector,
    required this.onSelect,
  });

  @override
  State<_SubcategoriesDialog> createState() => _SubcategoriesDialogState();
}

class _SubcategoriesDialogState extends State<_SubcategoriesDialog> {
  late final ProductRepository _repo;
  final _newSubcategoryCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  bool _isCreating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    try {
      _repo = Modular.get<ProductRepository>();
    } catch (_) {
      _repo = ProductRepository();
    }
  }

  @override
  void dispose() {
    _newSubcategoryCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _addSubcategory() async {
    final name = _newSubcategoryCtrl.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _isCreating = true;
      _error = null;
    });

    try {
      await _repo.createSubcategory(
        name: name,
        sector: widget.sector.name,
      );
      _newSubcategoryCtrl.clear();
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Erro ao adicionar subcategoria: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  void _showEditDialog(SubcategoryModel item) {
    final editCtrl = TextEditingController(text: item.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Editar Subcategoria',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: editCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Nome da subcategoria',
            prefixIcon: Icon(Icons.edit_outlined, color: Color(0xFF64748B)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'CANCELAR',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                final newName = editCtrl.text.trim();
                if (newName.isNotEmpty) {
                  await _repo.updateSubcategory(item.id, newName);
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              borderRadius: BorderRadius.circular(10),
              child: Ink(
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Text(
                  'SALVAR',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(SubcategoryModel item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Color(0xFFEF4444), size: 24),
            const SizedBox(width: 8),
            Text(
              'Excluir Subcategoria',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Remover "${item.name}" das subcategorias deste segmento?',
          style:
              GoogleFonts.inter(fontSize: 14, color: const Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'CANCELAR',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                Navigator.pop(ctx);
                await _repo.deleteSubcategory(item.id);
              },
              borderRadius: BorderRadius.circular(10),
              child: Ink(
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(10),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Text(
                  'EXCLUIR',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.white,
                  ),
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
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 680,
        height: 600,
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabeçalho da Popup
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: widget.sector.themeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.folder_special_rounded,
                      color: widget.sector.themeColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gerenciar Subcategorias',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Segmento: ${widget.sector.title}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: widget.sector.themeColor,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Fechar',
                  icon:
                      const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: AppColors.divider),
            const SizedBox(height: 16),

            // Adicionar Nova Subcategoria
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _newSubcategoryCtrl,
                    onFieldSubmitted: (_) => _addSubcategory(),
                    decoration: const InputDecoration(
                      hintText: 'Digite o nome da nova subcategoria...',
                      prefixIcon: Icon(Icons.add_circle_outline_rounded,
                          color: Color(0xFF64748B)),
                      filled: true,
                      fillColor: Color(0xFFF8FAFC),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isCreating ? null : _addSubcategory,
                    borderRadius: BorderRadius.circular(12),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 13),
                      child: _isCreating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : Row(
                              children: [
                                const Icon(Icons.add_rounded,
                                    color: Colors.white, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  'INCLUIR',
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

            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style: GoogleFonts.inter(
                      color: const Color(0xFFEF4444), fontSize: 12)),
            ],

            const SizedBox(height: 16),

            // Campo de Busca
            SizedBox(
              height: 42,
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) =>
                    setState(() => _searchQuery = v.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Filtrar subcategorias existentes...',
                  hintStyle: GoogleFonts.inter(
                      fontSize: 12, color: const Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search_rounded,
                      size: 18, color: Color(0xFF64748B)),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Lista em Tempo Real
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: StreamBuilder<List<SubcategoryModel>>(
                    stream: _repo.getSubcategoriesStream(widget.sector.name),
                    builder: (ctx, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(
                            child: CircularProgressIndicator(
                                color: AppColors.primary));
                      }
                      final all = snap.data ?? [];
                      final filtered = all
                          .where((s) =>
                              _searchQuery.isEmpty ||
                              s.name.toLowerCase().contains(_searchQuery))
                          .toList();

                      if (filtered.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.folder_open_rounded,
                                  size: 36, color: Color(0xFF94A3B8)),
                              const SizedBox(height: 8),
                              Text(
                                all.isEmpty
                                    ? 'Nenhuma subcategoria cadastrada para este segmento.'
                                    : 'Nenhuma subcategoria encontrada.',
                                style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: const Color(0xFF64748B)),
                              ),
                              if (all.isEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Digite o nome acima e clique em "INCLUIR" para começar.',
                                  style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: const Color(0xFF94A3B8)),
                                ),
                              ],
                            ],
                          ),
                        );
                      }

                      return ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, color: AppColors.divider),
                        itemBuilder: (ctx, i) {
                          final item = filtered[i];
                          return ListTile(
                            dense: true,
                            leading: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: widget.sector.themeColor
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.folder_rounded,
                                  size: 16, color: widget.sector.themeColor),
                            ),
                            title: Text(
                              item.name,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Botão Selecionar
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      widget.onSelect(item.name);
                                      Navigator.pop(context);
                                    },
                                    borderRadius: BorderRadius.circular(8),
                                    child: Ink(
                                      decoration: BoxDecoration(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: AppColors.primary
                                                .withValues(alpha: 0.3)),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.check_rounded,
                                              size: 14,
                                              color: AppColors.primary),
                                          const SizedBox(width: 4),
                                          Text(
                                            'SELECIONAR',
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                // Botão Editar
                                IconButton(
                                  tooltip: 'Editar',
                                  icon: const Icon(Icons.edit_outlined,
                                      size: 16, color: Color(0xFF6366F1)),
                                  onPressed: () => _showEditDialog(item),
                                ),
                                // Botão Excluir
                                IconButton(
                                  tooltip: 'Excluir',
                                  icon: const Icon(Icons.delete_outline_rounded,
                                      size: 16, color: Color(0xFFEF4444)),
                                  onPressed: () => _showDeleteDialog(item),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
