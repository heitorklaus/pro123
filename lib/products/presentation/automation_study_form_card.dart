import 'dart:async';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../auth/data/repositories/auth_repository.dart';
import '../../auth/domain/models/user_model.dart';
import '../../proposals/domain/models/proposal_item_model.dart';
import '../data/repositories/product_repository.dart';
import '../domain/models/automation_study_model.dart';
import '../domain/models/category_model.dart';
import '../domain/models/product_model.dart';
import 'solar_plant_form_card.dart';
import 'widgets/automation_category_dialogs.dart';
import 'widgets/automation_equipment_dialogs.dart';
import 'widgets/automation_pdf_import_dialog.dart';
import 'widgets/automation_proposal_customizer_dialog.dart';
import 'widgets/automation_preview_bridge.dart';

/// Formulário Especial de Cadastro & Edição de Estudo de Proposta de Automação Residencial/Comercial
class AutomationStudyFormCard extends StatefulWidget {
  final CategoryModel category;
  final ProductModel? product;
  final UserModel? currentUser;
  final VoidCallback onBack;
  final VoidCallback? onChangeSector;
  final VoidCallback onSuccess;
  final void Function(ProductModel product)? onProductSaved;
  final ValueChanged<ProposalItemModel>? onProceedToProposal;

  const AutomationStudyFormCard({
    super.key,
    required this.category,
    this.product,
    this.currentUser,
    required this.onBack,
    this.onChangeSector,
    required this.onSuccess,
    this.onProductSaved,
    this.onProceedToProposal,
  });

  @override
  State<AutomationStudyFormCard> createState() => _AutomationStudyFormCardState();
}

class _AutomationStudyFormCardState extends State<AutomationStudyFormCard> {
  final _formKey = GlobalKey<FormState>();
  late final ProductRepository _productRepo;
  late final AuthRepository _authRepo;

  final _nameCtrl = TextEditingController();
  final _clientNameCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _laborPriceCtrl = TextEditingController();

  List<AutomationEnvironment> _environments = [];
  bool _isSaving = false;
  String? _errorMessage;
  AutomationProposalThemeConfig _proposalThemeConfig = const AutomationProposalThemeConfig();

  StreamSubscription<List<AutomationCategoryModel>>? _categorySub;
  List<AutomationCategoryModel> _availableCategories =
      AutomationCategoryModel.defaultCategories;

  StreamSubscription<List<ProductModel>>? _productsSub;
  List<ProductModel> _automationProducts = [];
  String? _companyId;

  @override
  void initState() {
    super.initState();
    try {
      _productRepo = Modular.get<ProductRepository>();
    } catch (_) {
      _productRepo = ProductRepository();
    }
    try {
      _authRepo = Modular.get<AuthRepository>();
    } catch (_) {
      _authRepo = AuthRepository();
    }

    _initFromExistingProduct();
    _loadCategories();
  }

  @override
  void dispose() {
    _categorySub?.cancel();
    _productsSub?.cancel();
    _nameCtrl.dispose();
    _clientNameCtrl.dispose();
    _notesCtrl.dispose();
    _laborPriceCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final user = widget.currentUser ?? await _authRepo.getCurrentUser();
      final cid =
          user?.effectiveCompanyId ?? await _authRepo.getCurrentCompanyId();
      _companyId = cid;

      _categorySub = _productRepo
          .getAutomationCategoriesStream(companyId: cid)
          .listen((cats) {
        if (mounted && cats.isNotEmpty) {
          setState(() {
            _availableCategories = cats;
          });
        }
      });

      _productsSub = _productRepo.getProductsStream(companyId: cid).listen((products) {
        if (mounted) {
          final autoProds = products
              .where((p) => p.sector == ProductSector.homeAutomation && p.isAutomationDevice)
              .toList();
          setState(() {
            _automationProducts = autoProds;
          });
        }
      });
    } catch (_) {}
  }

  void _openAutomationCategoryDialog([int? envIndex, int? itemIndex]) {
    showDialog(
      context: context,
      builder: (ctx) => AutomationCategoryManagerDialog(
        companyId: _companyId,
        onCategorySelected: (cat) {
          if (envIndex != null &&
              itemIndex != null &&
              envIndex < _environments.length &&
              itemIndex < _environments[envIndex].items.length) {
            final currentItem = _environments[envIndex].items[itemIndex];
            _updateItemInEnvironment(
              envIndex,
              itemIndex,
              currentItem.copyWith(
                categoryTitle: cat.title,
                categoryIconCodePoint: cat.icon.codePoint,
                categoryColorValue: cat.color.toARGB32(),
                category: AutomationItemCategory.fromString(cat.title),
              ),
            );
          }
        },
      ),
    );
  }

  void _openAutomationEquipmentDialog([int? envIndex, int? itemIndex, bool startInRegister = false]) {
    final initialName = (envIndex != null && itemIndex != null &&
            envIndex < _environments.length &&
            itemIndex < _environments[envIndex].items.length)
        ? _environments[envIndex].items[itemIndex].name
        : null;

    showDialog(
      context: context,
      builder: (ctx) => AutomationEquipmentManagerDialog(
        companyId: _companyId,
        availableCategories: _availableCategories,
        startInRegisterMode: startInRegister,
        initialName: initialName,
        onProductSelected: (prod) {
          if (envIndex != null && itemIndex != null) {
            _applyProductToItem(envIndex, itemIndex, prod);
          }
        },
      ),
    );
  }

  void _applyProductToItem(int envIndex, int itemIndex, ProductModel prod) {
    if (envIndex >= _environments.length || itemIndex >= _environments[envIndex].items.length) return;
    final currentItem = _environments[envIndex].items[itemIndex];

    final catTitle = prod.categoryTitle ??
        prod.specificAttributes['automationCategoryTitle']?.toString() ??
        currentItem.categoryTitle;

    final matchedCat = _availableCategories.firstWhere(
      (c) => c.title == catTitle,
      orElse: () => _availableCategories.isNotEmpty
          ? _availableCategories.first
          : AutomationCategoryModel.defaultCategories.first,
    );

    final unitPrice = prod.salePrice > 0 ? prod.salePrice : currentItem.unitPrice;
    final totalPrice = currentItem.quantity * unitPrice;

    _updateItemInEnvironment(
      envIndex,
      itemIndex,
      currentItem.copyWith(
        productId: prod.id,
        name: prod.name,
        sku: prod.sku,
        manufacturer: prod.brandModel ?? prod.supplierName,
        unit: prod.unit.code,
        unitPrice: unitPrice,
        totalPrice: totalPrice,
        categoryTitle: matchedCat.title,
        categoryIconCodePoint: matchedCat.icon.codePoint,
        categoryColorValue: matchedCat.color.toARGB32(),
        category: AutomationItemCategory.fromString(matchedCat.title),
      ),
    );
  }

  void _initFromExistingProduct() {
    final p = widget.product;
    if (p != null) {
      _nameCtrl.text = p.name;
      final attrs = p.specificAttributes;
      _clientNameCtrl.text = attrs['clientName']?.toString() ?? '';
      _notesCtrl.text = p.description ?? attrs['notes']?.toString() ?? '';

      final labor = (attrs['laborPrice'] as num?)?.toDouble() ?? 0.0;
      if (labor > 0) {
        _laborPriceCtrl.text = CurrencyPtBrInputFormatter.format(labor);
      }

      _environments = List<AutomationEnvironment>.from(p.automationEnvironments);
      if (attrs['proposalTheme'] is Map) {
        _proposalThemeConfig = AutomationProposalThemeConfig.fromMap(
          Map<String, dynamic>.from(attrs['proposalTheme'] as Map),
        );
      }
    }

    if (_environments.isEmpty) {
      // Cria pelo menos um ambiente padrão inicial com miniexplicação
      _environments.add(const AutomationEnvironment(
        id: 'env_1',
        name: 'Living & Home Theater',
        description: 'Conforto e entretenimento para a família e visitas com cenas de iluminação e áudio imersivo.',
        items: [],
      ));
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CÁLCULOS TOTAIS
  // ─────────────────────────────────────────────────────────────────────────
  double get _equipmentTotal {
    return _environments.fold(0.0, (acc, env) => acc + env.subtotal);
  }

  double get _laborTotal {
    return CurrencyPtBrInputFormatter.parse(_laborPriceCtrl.text);
  }

  double get _grandTotal {
    return _equipmentTotal + _laborTotal;
  }

  int get _totalItemsCount {
    return _environments.fold(0, (acc, env) => acc + env.totalItemsCount);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // AÇÕES DE AMBIENTES & ITENS
  // ─────────────────────────────────────────────────────────────────────────
  void _addNewEnvironment([String? defaultName]) {
    setState(() {
      final nextNum = _environments.length + 1;
      _environments.add(AutomationEnvironment(
        id: UniqueKey().toString(),
        name: defaultName ?? 'Novo Ambiente $nextNum',
        items: const [],
      ));
    });
  }

  void _removeEnvironment(int index) {
    if (_environments.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('O estudo precisa ter pelo menos um ambiente.'),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }
    setState(() {
      _environments.removeAt(index);
    });
  }

  void _addNewItemToEnvironment(int envIndex) {
    setState(() {
      final env = _environments[envIndex];
      final newItems = List<AutomationItem>.from(env.items);
      final defaultCat = _availableCategories.isNotEmpty
          ? _availableCategories.first
          : AutomationCategoryModel.defaultCategories.first;

      newItems.add(AutomationItem(
        id: UniqueKey().toString(),
        name: 'Novo Equipamento',
        category: AutomationItemCategory.fromString(defaultCat.title),
        categoryTitle: defaultCat.title,
        categoryIconCodePoint: defaultCat.icon.codePoint,
        categoryColorValue: defaultCat.color.toARGB32(),
        quantity: 1,
        unit: 'UN',
        unitPrice: 0.0,
      ));
      _environments[envIndex] = env.copyWith(items: newItems);
    });
  }

  void _updateItemInEnvironment(int envIndex, int itemIndex, AutomationItem updatedItem) {
    setState(() {
      final env = _environments[envIndex];
      final newItems = List<AutomationItem>.from(env.items);
      newItems[itemIndex] = updatedItem;
      _environments[envIndex] = env.copyWith(items: newItems);
    });
  }

  void _removeItemFromEnvironment(int envIndex, int itemIndex) {
    setState(() {
      final env = _environments[envIndex];
      final newItems = List<AutomationItem>.from(env.items);
      newItems.removeAt(itemIndex);
      _environments[envIndex] = env.copyWith(items: newItems);
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // IMPORTAÇÃO COM IA (GEMINI VISION)
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _handleImportWithAi() async {
    final parsed = await AutomationPdfImportDialog.show(context);
    if (parsed == null) return;

    setState(() {
      if (parsed.studyName.isNotEmpty) {
        _nameCtrl.text = parsed.studyName;
      }
      if (parsed.clientName != null && parsed.clientName!.isNotEmpty) {
        _clientNameCtrl.text = parsed.clientName!;
      }
      if (parsed.notes != null && parsed.notes!.isNotEmpty) {
        _notesCtrl.text = parsed.notes!;
      }
      if (parsed.laborAmount > 0) {
        _laborPriceCtrl.text = CurrencyPtBrInputFormatter.format(parsed.laborAmount);
      }

      if (parsed.environments.isNotEmpty) {
        _environments = parsed.environments.map((e) => e.toAutomationEnvironment()).toList();
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✓ IA importou com sucesso: ${_environments.length} ambientes e $_totalItemsCount equipamentos!',
          ),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PERSONALIZAÇÃO E PREVIEW DA PROPOSTA WEB
  // ─────────────────────────────────────────────────────────────────────────
  void _openThemeCustomizer() {
    showDialog(
      context: context,
      builder: (ctx) => AutomationProposalCustomizerDialog(
        initialConfig: _proposalThemeConfig,
        clientName: _nameCtrl.text.trim().isNotEmpty
            ? _nameCtrl.text.trim()
            : (_clientNameCtrl.text.trim().isNotEmpty ? _clientNameCtrl.text.trim() : 'Residência'),
        onLiveChange: (liveConfig) {
          setState(() => _proposalThemeConfig = liveConfig);
        },
        onSave: (newConfig) {
          setState(() => _proposalThemeConfig = newConfig);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Configurações visuais da proposta web atualizadas!'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openProposalPreview([ProductModel? customProduct]) async {
    final baseProduct = customProduct ?? widget.product;
    final previewProduct = ProductModel(
      id: baseProduct?.id ?? 'preview_mode',
      name: _nameCtrl.text.trim().isNotEmpty
          ? _nameCtrl.text.trim()
          : (baseProduct?.name ?? 'Residência Inteligente'),
      sector: ProductSector.homeAutomation,
      categoryTitle: 'Automação Residencial',
      description: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : baseProduct?.description,
      salePrice: _grandTotal > 0 ? _grandTotal : _equipmentTotal,
      costPrice: _equipmentTotal,
      unit: ProductUnit.un,
      stockQuantity: 1,
      createdAt: baseProduct?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      specificAttributes: {
        ...?baseProduct?.specificAttributes,
        'studyType': 'automation',
        'environments': _environments.map((e) => e.toMap()).toList(),
        'laborPrice': _laborTotal,
        'grandTotal': _grandTotal,
        // Injeta sempre a configuração visual completa e o modelo 3D real da tela!
        'proposalTheme': _proposalThemeConfig.toMap(),
        if (_clientNameCtrl.text.trim().isNotEmpty) 'clientName': _clientNameCtrl.text.trim(),
      },
    );

    final baseUri = Uri.base.origin;
    final targetPath = (previewProduct.id.isNotEmpty && previewProduct.id != 'preview_mode')
        ? '/automacao-proposta/${previewProduct.id}'
        : '/preview-automacao';
    final fullUrl = '$baseUri/#$targetPath';

    // Abre estritamente em uma nova aba (_blank) no navegador e sincroniza via IndexedDB sem limite de 5MB
    await AutomationPreviewBridge.openPreviewInNewTab(
      fullUrl: fullUrl,
      previewProduct: previewProduct,
      themeConfig: _proposalThemeConfig,
    );
  }

  void _showPostSavePreviewDialog(ProductModel savedProduct) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF00E5FF), width: 1.5),
        ),
        child: Container(
          width: 480,
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.4)),
                ),
                child: const Icon(Icons.language_rounded, color: Color(0xFF00E5FF), size: 38),
              ),
              const SizedBox(height: 18),
              Text(
                'Estudo Salvo com Sucesso!',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Deseja ver um preview interativo do estudo na web proposta comercial?',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF94A3B8),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        widget.onSuccess();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF94A3B8),
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text('Concluir e Voltar', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _openProposalPreview(savedProduct);
                      },
                      icon: const Icon(Icons.visibility_rounded, size: 18),
                      label: Text(
                        'Ver Preview Agora',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E5FF),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
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

  // ─────────────────────────────────────────────────────────────────────────
  // SALVAR NO FIRESTORE
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _handleSave({bool proceedToProposal = false}) async {
    if (!_formKey.currentState!.validate()) return;

    if (_environments.isEmpty) {
      setState(() => _errorMessage = 'Adicione ao menos um ambiente no estudo.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final user = widget.currentUser ?? await _authRepo.getCurrentUser();
      final companyId = user?.effectiveCompanyId;

      final isEditing = widget.product != null;

      final envsData = _environments.map((e) {
        final map = e.toMap();
        final img = map['imageUrl']?.toString() ?? '';
        if (img.startsWith('data:') || img.length > 200000) {
          map['imageUrl'] = null;
        }
        return map;
      }).toList();

      final themeMap = _proposalThemeConfig.toMap();

      // Sanitiza URLs de mídia base64 para evitar exceder o limite de 1MB do Firestore
      final heroUrl = themeMap['heroImageUrl']?.toString() ?? '';
      if (heroUrl.startsWith('data:') || heroUrl.length > 200000) {
        themeMap['heroImageUrl'] = 'assets/images/smart_home_hero.jpg';
      }

      final bgUrl = themeMap['backgroundImageUrl']?.toString() ?? '';
      if (bgUrl.startsWith('data:') || bgUrl.length > 200000) {
        themeMap['backgroundImageUrl'] = kDefaultProposalBackgrounds.first.imageUrl;
      }

      final glbUrl = themeMap['glbModelUrl']?.toString() ?? '';
      if (glbUrl.startsWith('data:') || glbUrl.length > 200000) {
        themeMap['glbModelUrl'] = '';
        themeMap['hasGlbModel'] = true;
      }

      final specificAttrs = <String, dynamic>{
        ...?widget.product?.specificAttributes,
        'isAutomationStudy': true,
        'environments': envsData,
        'environmentsCount': _environments.length,
        'totalItemsCount': _totalItemsCount,
        'equipmentTotal': _equipmentTotal,
        'laborPrice': _laborTotal,
        'grandTotal': _grandTotal,
        'proposalTheme': themeMap,
        if (_clientNameCtrl.text.trim().isNotEmpty) 'clientName': _clientNameCtrl.text.trim(),
        if (_notesCtrl.text.trim().isNotEmpty) 'notes': _notesCtrl.text.trim(),
      };

      ProductModel savedProduct;
      if (isEditing) {
        final updated = widget.product!.copyWith(
          name: _nameCtrl.text.trim(),
          sector: ProductSector.homeAutomation,
          categoryTitle: 'Automação Residencial',
          description: _notesCtrl.text.trim().isNotEmpty
              ? _notesCtrl.text.trim()
              : null,
          salePrice: _grandTotal > 0 ? _grandTotal : _equipmentTotal,
          costPrice: _equipmentTotal,
          unit: ProductUnit.un,
          stockQuantity: 1,
          specificAttributes: specificAttrs,
        );
        await _productRepo.updateProduct(updated);
        savedProduct = updated;
      } else {
        savedProduct = await _productRepo.createProduct(
          name: _nameCtrl.text.trim(),
          sector: ProductSector.homeAutomation,
          categoryTitle: 'Automação Residencial',
          description: _notesCtrl.text.trim().isNotEmpty
              ? _notesCtrl.text.trim()
              : null,
          salePrice: _grandTotal > 0 ? _grandTotal : _equipmentTotal,
          costPrice: _equipmentTotal,
          stockQuantity: 1,
          minStock: 1,
          unit: ProductUnit.un,
          specificAttributes: specificAttrs,
          companyId: companyId,
          createdByUserId: user?.uid,
          createdByUserName: user?.name,
        );
      }

      // Salva o rascunho completo com a foto da casa, 3D e background no IndexedDB / Bridge
      await AutomationPreviewBridge.savePreviewData(savedProduct.copyWith(
        specificAttributes: {
          ...savedProduct.specificAttributes,
          'proposalTheme': _proposalThemeConfig.toMap(),
          'environments': _environments.map((e) => e.toMap()).toList(),
        },
      ));

      widget.onProductSaved?.call(savedProduct);

      if (proceedToProposal && widget.onProceedToProposal != null) {
        final proposalItem = ProposalItemModel.fromProduct(savedProduct);
        widget.onProceedToProposal!(proposalItem);
        return;
      }

      if (mounted) {
        setState(() => _isSaving = false);
        _showPostSavePreviewDialog(savedProduct);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Erro ao salvar estudo: $e';
        });
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD PRINCIPAL
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isEditing = widget.product != null;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF1E293B), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.all(32),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── CABEÇALHO COM BOTÃO IA E VOLTAR ──
            _buildHeader(isEditing),
            const SizedBox(height: 28),

            // ── ALERTA DE ERRO ──
            if (_errorMessage != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF450A0A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEF4444)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFFFCA5A5)),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── DADOS BÁSICOS DO ESTUDO ──
            _buildBasicDataSection(),
            const SizedBox(height: 32),

            // ── SEÇÃO DE AMBIENTES E EQUIPAMENTOS ──
            _buildEnvironmentsSection(),
            const SizedBox(height: 32),

            // ── PAINEL CONSOLIDADO DE TOTAIS E MÃO DE OBRA ──
            _buildTotalsSection(),
            const SizedBox(height: 36),

            // ── RODAPÉ DE AÇÕES ──
            _buildFooterActions(isEditing),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // COMPONENTES DE UI
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildHeader(bool isEditing) {
    return Row(
      children: [
        IconButton(
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF94A3B8)),
          tooltip: 'Voltar para a listagem',
        ),
        const SizedBox(width: 12),
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.sensors_rounded, color: Colors.white, size: 26),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEditing ? 'Editar Estudo de Proposta' : 'Novo Estudo de Proposta',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                'Automação Residencial & Comercial • Estruturação por Ambientes e Circuitos',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),

        // ── BOTÕES DA PROPOSTA WEB & IA ──
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _openThemeCustomizer,
              icon: const Icon(Icons.palette_rounded, size: 16, color: Color(0xFF00E5FF)),
              label: Text(
                'PERSONALIZAR PROPOSTA WEB',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF00E5FF),
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF00E5FF), width: 1.2),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            // ── BOTÃO DE IMPORTAÇÃO COM IA ──
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF06B6D4)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _handleImportWithAi,
                icon: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
                label: Text(
                  'IMPORTAR COM IA (PDF/IMG)',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.4,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBasicDataSection() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '1. IDENTIFICAÇÃO DO ESTUDO',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF818CF8),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nome do Estudo
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nome do Estudo / Projeto *',
                      style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFFCBD5E1)),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _nameCtrl,
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 13.5),
                      decoration: InputDecoration(
                        hintText: 'Ex: Projeto Automação Residência Silva',
                        hintStyle: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 13),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        prefixIcon: const Icon(Icons.description_outlined, color: Color(0xFF818CF8), size: 18),
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
                      ),
                      validator: (val) => (val == null || val.trim().isEmpty) ? 'Informe o nome do estudo' : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // Cliente / Identificação
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cliente / Local (Opcional)',
                      style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFFCBD5E1)),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _clientNameCtrl,
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 13.5),
                      decoration: InputDecoration(
                        hintText: 'Ex: Dr. Roberto - Condomínio Alphaville',
                        hintStyle: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 13),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF818CF8), size: 18),
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
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Observações Gerais
          Text(
            'Observações Gerais / Escopo Técnico',
            style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFFCBD5E1)),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _notesCtrl,
            maxLines: 2,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Ex: Projeto prevê automação de iluminação dimerizável, cortinas motorizadas e sonorização multiroom.',
              hintStyle: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 12.5),
              filled: true,
              fillColor: const Color(0xFF0F172A),
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnvironmentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '2. AMBIENTES & EQUIPAMENTOS',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF818CF8),
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Cadastre os cômodos e adicione as soluções inteligentes pertencentes a cada um',
                  style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: () => _addNewEnvironment(),
              icon: const Icon(Icons.add_home_work_rounded, size: 17),
              label: Text(
                'ADICIONAR AMBIENTE',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.4),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B),
                foregroundColor: const Color(0xFF818CF8),
                side: const BorderSide(color: Color(0xFF6366F1), width: 1.2),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Lista de Cards de Ambientes
        ..._environments.asMap().entries.map((entry) {
          final envIndex = entry.key;
          final env = entry.value;
          return _buildEnvironmentCard(envIndex, env);
        }),
      ],
    );
  }

  Widget _buildEnvironmentCard(int envIndex, AutomationEnvironment env) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header do Ambiente
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: const Border(bottom: BorderSide(color: Color(0xFF334155))),
            ),
            child: Row(
              children: [
                const Icon(Icons.meeting_room_rounded, color: Color(0xFF818CF8), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    initialValue: env.name,
                    style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.bold, color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Nome do Ambiente (ex: Suíte Master)',
                      hintStyle: TextStyle(color: Color(0xFF64748B)),
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (val) {
                      _environments[envIndex] = env.copyWith(name: val);
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '${env.totalItemsCount} dispositivos • ${CurrencyPtBrInputFormatter.format(env.subtotal)}',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF818CF8)),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
                  tooltip: 'Remover este ambiente',
                  onPressed: () => _removeEnvironment(envIndex),
                ),
              ],
            ),
          ),

          // Tabela de Equipamentos do Ambiente
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── CAMPO MINISEXPLICAÇÃO DO AMBIENTE (PROPOSTA WEB) ──
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_stories_rounded, size: 18, color: Color(0xFF00E5FF)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'MINIEXPLICAÇÃO DO AMBIENTE (PROPOSTA WEB INTERATIVA)',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                                color: const Color(0xFF00E5FF),
                              ),
                            ),
                            const SizedBox(height: 4),
                            TextFormField(
                              initialValue: env.description ?? '',
                              style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'Ex: ${env.miniexplanation}',
                                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                isDense: true,
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                              onChanged: (val) {
                                _environments[envIndex] = env.copyWith(description: val);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── CAMPO IMAGEM / RENDER DO CÔMODO (BANCO DE IMAGENS OU UPLOAD) ──
                _buildEnvironmentImagePickerRow(envIndex, env),

                if (env.items.isEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Center(
                      child: Text(
                        'Nenhum equipamento cadastrado neste ambiente ainda.',
                        style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF64748B)),
                      ),
                    ),
                  ),
                ] else ...[
                  // Cabeçalho da Tabela
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 5,
                          child: Row(
                            children: [
                              Text('EQUIPAMENTO / SOLUÇÃO', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8))),
                              const SizedBox(width: 6),
                              Tooltip(
                                message: 'Catálogo de Equipamentos de Automação',
                                child: InkWell(
                                  onTap: () => _openAutomationEquipmentDialog(null, null, false),
                                  borderRadius: BorderRadius.circular(4),
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Icon(Icons.add_rounded, size: 13, color: Color(0xFF818CF8)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Row(
                            children: [
                              Text(
                                'CATEGORIA',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF94A3B8),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Tooltip(
                                message: 'Catálogo de Categorias de Automação',
                                child: InkWell(
                                  onTap: () => _openAutomationCategoryDialog(),
                                  borderRadius: BorderRadius.circular(4),
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF6366F1)
                                          .withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Icon(Icons.add_rounded,
                                        size: 13, color: Color(0xFF818CF8)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 80,
                          child: Text('QTD', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8))),
                        ),
                        SizedBox(
                          width: 120,
                          child: Text('UNITÁRIO (R\$)', textAlign: TextAlign.right, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8))),
                        ),
                        SizedBox(
                          width: 130,
                          child: Text('TOTAL (R\$)', textAlign: TextAlign.right, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8))),
                        ),
                        const SizedBox(width: 40),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Linhas de Itens
                  ...env.items.asMap().entries.map((itemEntry) {
                    final itemIndex = itemEntry.key;
                    final item = itemEntry.value;
                    return _buildItemRow(envIndex, itemIndex, item);
                  }),
                ],
                const SizedBox(height: 12),

                // Botão Adicionar Item no Ambiente
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _addNewItemToEnvironment(envIndex),
                    icon: const Icon(Icons.add_rounded, size: 18, color: Color(0xFF818CF8)),
                    label: Text(
                      '+ Adicionar Equipamento a este Ambiente',
                      style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF818CF8)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(int envIndex, int itemIndex, AutomationItem item) {
    final unitPriceCtrl = TextEditingController(
      text: item.unitPrice > 0 ? CurrencyPtBrInputFormatter.format(item.unitPrice) : '',
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF334155).withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          // Nome do Equipamento com Autocomplete inteligente e Botão +
          Expanded(
            flex: 5,
            child: Row(
              children: [
                Expanded(
                  child: AutomationEquipmentAutocompleteField(
                    key: ValueKey('auto_item_${envIndex}_${itemIndex}_${item.id}_${item.name}'),
                    initialValue: item.name,
                    automationProducts: _automationProducts,
                    categories: _availableCategories,
                    onChanged: (val) {
                      _updateItemInEnvironment(envIndex, itemIndex, item.copyWith(name: val));
                    },
                    onProductSelected: (prod) {
                      _applyProductToItem(envIndex, itemIndex, prod);
                    },
                    onOpenEquipmentManager: () {
                      _openAutomationEquipmentDialog(envIndex, itemIndex, true);
                    },
                  ),
                ),
                const SizedBox(width: 6),
                Tooltip(
                  message: 'Cadastrar Equipamento / Ver Catálogo',
                  child: InkWell(
                    onTap: () => _openAutomationEquipmentDialog(envIndex, itemIndex, false),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                        ),
                      ),
                      child: const Icon(Icons.add_rounded, size: 15, color: Color(0xFF818CF8)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Categoria (Dropdown + Botão +)
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    value: _availableCategories
                            .any((c) => c.title == item.categoryTitle)
                        ? item.categoryTitle
                        : (_availableCategories.isNotEmpty
                            ? _availableCategories.first.title
                            : null),
                    isExpanded: true,
                    isDense: true,
                    underline: const SizedBox(),
                    dropdownColor: const Color(0xFF0F172A),
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.white),
                    items: _availableCategories.map((cat) {
                      return DropdownMenuItem<String>(
                        value: cat.title,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(cat.icon, size: 14, color: cat.color),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(cat.title,
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (newTitle) {
                      if (newTitle != null) {
                        final found = _availableCategories.firstWhere(
                          (c) => c.title == newTitle,
                          orElse: () => _availableCategories.first,
                        );
                        _updateItemInEnvironment(
                          envIndex,
                          itemIndex,
                          item.copyWith(
                            categoryTitle: found.title,
                            categoryIconCodePoint: found.icon.codePoint,
                            categoryColorValue: found.color.toARGB32(),
                            category:
                                AutomationItemCategory.fromString(found.title),
                          ),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(width: 6),
                Tooltip(
                  message: 'Nova Categoria / Gerenciar',
                  child: InkWell(
                    onTap: () =>
                        _openAutomationCategoryDialog(envIndex, itemIndex),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color:
                              const Color(0xFF6366F1).withValues(alpha: 0.35),
                        ),
                      ),
                      child: const Icon(Icons.add_rounded,
                          size: 15, color: Color(0xFF818CF8)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Quantidade
          SizedBox(
            width: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                InkWell(
                  onTap: item.quantity > 1
                      ? () {
                          _updateItemInEnvironment(envIndex, itemIndex, item.copyWith(quantity: item.quantity - 1));
                        }
                      : null,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF334155),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(Icons.remove, size: 14, color: Colors.white),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '${item.quantity}',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                InkWell(
                  onTap: () {
                    _updateItemInEnvironment(envIndex, itemIndex, item.copyWith(quantity: item.quantity + 1));
                  },
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF334155),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(Icons.add, size: 14, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Preço Unitário
          SizedBox(
            width: 120,
            child: TextFormField(
              controller: unitPriceCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [CurrencyPtBrInputFormatter()],
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'R\$ 0,00',
                hintStyle: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (val) {
                final price = CurrencyPtBrInputFormatter.parse(val);
                _updateItemInEnvironment(envIndex, itemIndex, item.copyWith(
                  unitPrice: price,
                  totalPrice: price * item.quantity,
                ));
              },
            ),
          ),
          const SizedBox(width: 10),

          // Preço Total
          SizedBox(
            width: 130,
            child: Text(
              CurrencyPtBrInputFormatter.format(item.calculatedTotal),
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF34D399)),
            ),
          ),

          // Remover Item
          SizedBox(
            width: 40,
            child: IconButton(
              icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF94A3B8)),
              onPressed: () => _removeItemFromEnvironment(envIndex, itemIndex),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalsSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '3. RESUMO CONSOLIDADO DO ESTUDO',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF818CF8),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              // Badge Ambientes
              _buildMetricCard(
                icon: Icons.meeting_room_rounded,
                iconColor: const Color(0xFF818CF8),
                label: 'Ambientes Cadastrados',
                value: '${_environments.length} cômodos',
              ),
              const SizedBox(width: 16),

              // Badge Dispositivos
              _buildMetricCard(
                icon: Icons.devices_rounded,
                iconColor: const Color(0xFF06B6D4),
                label: 'Dispositivos & Itens',
                value: '$_totalItemsCount unidades',
              ),
              const SizedBox(width: 16),

              // Subtotal de Equipamentos
              _buildMetricCard(
                icon: Icons.inventory_2_rounded,
                iconColor: const Color(0xFFF59E0B),
                label: 'Subtotal de Equipamentos',
                value: CurrencyPtBrInputFormatter.format(_equipmentTotal),
              ),
              const SizedBox(width: 16),

              // Campo de Mão de Obra / Instalação
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mão de Obra / Programação (R\$)',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF94A3B8)),
                      ),
                      const SizedBox(height: 4),
                      TextFormField(
                        controller: _laborPriceCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [CurrencyPtBrInputFormatter()],
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'R\$ 0,00',
                          hintStyle: TextStyle(color: Color(0xFF64748B)),
                          isDense: true,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Color(0xFF334155)),
          const SizedBox(height: 12),

          // Linha do Grande Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'VALOR TOTAL DO ESTUDO DE AUTOMAÇÃO:',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6,
                  color: const Color(0xFFCBD5E1),
                ),
              ),
              Text(
                CurrencyPtBrInputFormatter.format(_grandTotal),
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF34D399),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF94A3B8))),
                  const SizedBox(height: 2),
                  Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterActions(bool isEditing) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Botão Cancelar
        OutlinedButton(
          onPressed: widget.onBack,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF94A3B8),
            side: const BorderSide(color: Color(0xFF334155)),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(
            'CANCELAR',
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
        ),
        const SizedBox(width: 14),

        // Botão Salvar Estudo
        ElevatedButton(
          onPressed: _isSaving ? null : () => _handleSave(proceedToProposal: false),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6366F1),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 4,
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      isEditing ? 'SALVAR ALTERAÇÕES' : 'SALVAR ESTUDO',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                  ],
                ),
        ),

        // Botão Avançar para Proposta (se fornecido callback)
        if (widget.onProceedToProposal != null) ...[
          const SizedBox(width: 14),
          ElevatedButton(
            onPressed: _isSaving ? null : () => _handleSave(proceedToProposal: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 4,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'AVANÇAR PARA PROPOSTA',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded, size: 18),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // GESTÃO DE IMAGEM / RENDER DO CÔMODO (BANCO DE IMAGENS + UPLOAD)
  // ---------------------------------------------------------------------------
  String _getDefaultRoomPhotoUrl(String roomName) {
    final lower = roomName.toLowerCase();
    if (lower.contains('quarto') || lower.contains('suite') || lower.contains('suíte') || lower.contains('dormitório') || lower.contains('closet')) {
      return 'https://images.unsplash.com/photo-1595526114035-0d45ed16cfbf?auto=format&fit=crop&w=800&q=80';
    }
    if (lower.contains('cozinha') || lower.contains('gourmet') || lower.contains('jantar') || lower.contains('copa')) {
      return 'https://images.unsplash.com/photo-1600585152220-90363fe7e115?auto=format&fit=crop&w=800&q=80';
    }
    if (lower.contains('serviço') || lower.contains('servico') || lower.contains('lavanderia') || lower.contains('despensa')) {
      return 'https://images.unsplash.com/photo-1517677208171-0bc6725a3e60?auto=format&fit=crop&w=800&q=80';
    }
    if (lower.contains('garagem') || lower.contains('estacionamento') || lower.contains('portão') || lower.contains('perímetro')) {
      return 'https://images.unsplash.com/photo-1590362891991-f776e747a588?auto=format&fit=crop&w=800&q=80';
    }
    if (lower.contains('banheiro') || lower.contains('lavabo') || lower.contains('bwc') || lower.contains('spa')) {
      return 'https://images.unsplash.com/photo-1584622650111-993a426fbf0a?auto=format&fit=crop&w=800&q=80';
    }
    if (lower.contains('piscina') || lower.contains('jardim') || lower.contains('lazer') || lower.contains('varanda') || lower.contains('deck')) {
      return 'https://images.unsplash.com/photo-1576013551627-0cc20b96c2a7?auto=format&fit=crop&w=800&q=80';
    }
    if (lower.contains('cinema') || lower.contains('theater') || lower.contains('som') || lower.contains('áudio')) {
      return 'https://images.unsplash.com/photo-1593784991095-a205069470b6?auto=format&fit=crop&w=800&q=80';
    }
    if (lower.contains('escritório') || lower.contains('office') || lower.contains('estudo')) {
      return 'https://images.unsplash.com/photo-1524758631624-e2822e304c36?auto=format&fit=crop&w=800&q=80';
    }
    return 'https://images.unsplash.com/photo-1600210492486-724fe5c67fb0?auto=format&fit=crop&w=800&q=80';
  }

  Widget _buildEnvironmentImagePickerRow(int envIndex, AutomationEnvironment env) {
    final hasCustomImage = env.imageUrl != null && env.imageUrl!.trim().isNotEmpty;
    final currentPhotoUrl = hasCustomImage
        ? env.imageUrl!.trim()
        : _getDefaultRoomPhotoUrl(env.name);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasCustomImage ? const Color(0xFF6366F1) : const Color(0xFF334155),
          width: hasCustomImage ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          // Preview Thumbnail com Badge
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                Image.network(
                  currentPhotoUrl,
                  width: 96,
                  height: 64,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 96,
                    height: 64,
                    color: const Color(0xFF1E293B),
                    child: const Icon(Icons.meeting_room_rounded, color: Colors.white38),
                  ),
                ),
                Positioned(
                  bottom: 2,
                  left: 2,
                  right: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      hasCustomImage ? 'RENDER CUSTOM' : 'IMAGEM PADRÃO',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 7.5,
                        fontWeight: FontWeight.bold,
                        color: hasCustomImage ? const Color(0xFF818CF8) : const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // Informações e Ações
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.photo_camera_rounded, size: 14, color: Color(0xFF818CF8)),
                    const SizedBox(width: 6),
                    Text(
                      'IMAGEM / RENDER DO CÔMODO (PROPOSTA WEB)',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: const Color(0xFF818CF8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  hasCustomImage
                      ? 'Render 3D personalizado configurado para a visualização web deste cômodo.'
                      : 'Imagem padrão selecionada. Escolha do banco de imagens ou faça o upload do render 3D.',
                  style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF94A3B8)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    // Botão Escolher no Banco
                    OutlinedButton.icon(
                      onPressed: () => _openRoomImagePickerDialog(envIndex, env),
                      icon: const Icon(Icons.collections_rounded, size: 14, color: Colors.white),
                      label: Text('Banco de Renders', style: GoogleFonts.inter(fontSize: 11, color: Colors.white)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        side: const BorderSide(color: Color(0xFF475569)),
                        backgroundColor: const Color(0xFF1E293B),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),

                    // Botão Upload de Render
                    ElevatedButton.icon(
                      onPressed: () => _pickCustomRoomImage(envIndex, env),
                      icon: const Icon(Icons.upload_file_rounded, size: 14, color: Colors.white),
                      label: Text('Upload Render 3D', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        backgroundColor: const Color(0xFF6366F1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),

                    // Botão Restaurar Padrão (se customizado)
                    if (hasCustomImage)
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _environments[envIndex] = env.copyWith(imageUrl: '');
                          });
                        },
                        icon: const Icon(Icons.undo_rounded, size: 14, color: Color(0xFFEF4444)),
                        label: Text('Restaurar Padrão', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFEF4444))),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openRoomImagePickerDialog(int envIndex, AutomationEnvironment env) {
    final urlController = TextEditingController(text: env.imageUrl ?? '');
    String selectedCategoryFilter = 'TODOS';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final categoriesList = [
              'TODOS',
              'Salas & Living',
              'Quartos & Suítes',
              'Área de Serviço',
              'Garagem',
              'Cozinhas & Gourmet',
              'Home Cinema',
              'Banheiros & SPA',
              'Escritórios',
              'Lazer & Externo',
            ];

            final filteredPresets = selectedCategoryFilter == 'TODOS'
                ? kDefaultRoomRenderPresets
                : kDefaultRoomRenderPresets.where((p) => p.category == selectedCategoryFilter).toList();

            return Dialog(
              backgroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Color(0xFF334155)),
              ),
              child: Container(
                width: 860,
                height: MediaQuery.of(dialogCtx).size.height * 0.85,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header do Dialog
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.collections_rounded, color: Color(0xFF818CF8), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Banco de Imagens & Renders de Cômodos',
                                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              Text(
                                'Selecione uma imagem HD da biblioteca por categoria ou informe a URL do render 3D.',
                                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white70),
                          onPressed: () => Navigator.pop(dialogCtx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(color: Color(0xFF1E293B), height: 1),
                    const SizedBox(height: 14),

                    // Barra de Filtros por Categoria (Chips)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: categoriesList.map((cat) {
                          final isCatSelected = selectedCategoryFilter == cat;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              selected: isCatSelected,
                              label: Text(
                                cat,
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  fontWeight: isCatSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isCatSelected ? Colors.white : const Color(0xFF94A3B8),
                                ),
                              ),
                              selectedColor: const Color(0xFF6366F1),
                              backgroundColor: const Color(0xFF1E293B),
                              side: BorderSide(
                                color: isCatSelected ? const Color(0xFF818CF8) : const Color(0xFF334155),
                              ),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              onSelected: (_) {
                                setDialogState(() {
                                  selectedCategoryFilter = cat;
                                });
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Campo para URL Direta da Imagem / Render
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: urlController,
                            style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Cole aqui a URL da imagem ou render 3D (http://... ou https://...)',
                              hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                              filled: true,
                              fillColor: const Color(0xFF1E293B),
                              prefixIcon: const Icon(Icons.link_rounded, color: Color(0xFF818CF8), size: 18),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF334155))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF334155))),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: () {
                            final val = urlController.text.trim();
                            if (val.isNotEmpty) {
                              setState(() {
                                _environments[envIndex] = env.copyWith(imageUrl: val);
                              });
                              Navigator.pop(dialogCtx);
                            }
                          },
                          icon: const Icon(Icons.check_rounded, size: 16),
                          label: Text('Aplicar URL', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Grid de Renders do Banco
                    Expanded(
                      child: filteredPresets.isEmpty
                          ? Center(
                              child: Text(
                                'Nenhuma imagem cadastrada para esta categoria.',
                                style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 13),
                              ),
                            )
                          : SingleChildScrollView(
                              child: Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: filteredPresets.map((preset) {
                                  final isSelected = env.imageUrl == preset.imageUrl;
                                  return InkWell(
                                    onTap: () {
                                      setState(() {
                                        _environments[envIndex] = env.copyWith(imageUrl: preset.imageUrl);
                                      });
                                      Navigator.pop(dialogCtx);
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      width: 248,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1E293B),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected ? const Color(0xFF818CF8) : const Color(0xFF334155),
                                          width: isSelected ? 2 : 1,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          ClipRRect(
                                            borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                                            child: Stack(
                                              children: [
                                                Image.network(
                                                  preset.imageUrl,
                                                  height: 130,
                                                  width: double.infinity,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) => Container(
                                                    height: 130,
                                                    color: const Color(0xFF0F172A),
                                                    child: const Icon(Icons.broken_image_rounded, color: Colors.white24),
                                                  ),
                                                ),
                                                if (isSelected)
                                                  Positioned(
                                                    top: 8,
                                                    right: 8,
                                                    child: Container(
                                                      padding: const EdgeInsets.all(4),
                                                      decoration: const BoxDecoration(
                                                        color: Color(0xFF6366F1),
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(10),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  preset.category.toUpperCase(),
                                                  style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF818CF8), letterSpacing: 0.5),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  preset.title,
                                                  style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.white),
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
                                }).toList(),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _pickCustomRoomImage(int envIndex, AutomationEnvironment env) async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      );

      if (files.isNotEmpty) {
        final file = files.first;
        final bytes = await file.readAsBytes();
        final base64String = base64Encode(bytes);
        final ext = file.extension?.toLowerCase() ?? 'jpeg';
        final mime = ext == 'png' ? 'image/png' : (ext == 'webp' ? 'image/webp' : 'image/jpeg');
        final dataUrl = 'data:$mime;base64,$base64String';

        setState(() {
          _environments[envIndex] = env.copyWith(imageUrl: dataUrl);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✓ Render do cômodo "${env.name}" (${file.name}) carregado com sucesso!'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar render: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }
}

/// Modelo de Preset para Banco de Renders/Imagens de Cômodos
class RoomRenderPreset {
  final String id;
  final String category;
  final String title;
  final String imageUrl;

  const RoomRenderPreset({
    required this.id,
    required this.category,
    required this.title,
    required this.imageUrl,
  });
}

/// Catálogo de Renders e Fotos HD de Cômodos em Alta Definição
const List<RoomRenderPreset> kDefaultRoomRenderPresets = [
  // ── SALAS & LIVING ──
  RoomRenderPreset(
    id: 'living_luxury',
    category: 'Salas & Living',
    title: 'Living Sofisticado & Integrado',
    imageUrl: 'https://images.unsplash.com/photo-1600210492486-724fe5c67fb0?auto=format&fit=crop&w=800&q=80',
  ),
  RoomRenderPreset(
    id: 'living_modern',
    category: 'Salas & Living',
    title: 'Sala Modernista com Cenas de Luz',
    imageUrl: 'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?auto=format&fit=crop&w=800&q=80',
  ),
  RoomRenderPreset(
    id: 'living_minimalist',
    category: 'Salas & Living',
    title: 'Living Minimalista Clean',
    imageUrl: 'https://images.unsplash.com/photo-1618221195710-dd6b41faaea6?auto=format&fit=crop&w=800&q=80',
  ),
  RoomRenderPreset(
    id: 'living_high_ceiling',
    category: 'Salas & Living',
    title: 'Sala de Estar Pé-Direito Duplo',
    imageUrl: 'https://images.unsplash.com/photo-1600607687939-ce8a6c25118c?auto=format&fit=crop&w=800&q=80',
  ),
  RoomRenderPreset(
    id: 'living_open_concept',
    category: 'Salas & Living',
    title: 'Living Conceito Aberto & Lareira',
    imageUrl: 'https://images.unsplash.com/photo-1600566753190-17f0baa2a6c3?auto=format&fit=crop&w=800&q=80',
  ),
  RoomRenderPreset(
    id: 'dining_room_luxury',
    category: 'Salas & Living',
    title: 'Sala de Jantar Elegante',
    imageUrl: 'https://images.unsplash.com/photo-1617806118233-18e1de247200?auto=format&fit=crop&w=800&q=80',
  ),

  // ── QUARTOS & SUÍTES ──
  RoomRenderPreset(
    id: 'bedroom_suite_master',
    category: 'Quartos & Suítes',
    title: 'Suíte Master de Alto Padrão',
    imageUrl: 'https://images.unsplash.com/photo-1595526114035-0d45ed16cfbf?auto=format&fit=crop&w=800&q=80',
  ),
  RoomRenderPreset(
    id: 'bedroom_cozy',
    category: 'Quartos & Suítes',
    title: 'Quarto Aconchegante com Dimerização',
    imageUrl: 'https://images.unsplash.com/photo-1616594039964-ae9021a400a0?auto=format&fit=crop&w=800&q=80',
  ),
  RoomRenderPreset(
    id: 'bedroom_modern_led',
    category: 'Quartos & Suítes',
    title: 'Quarto Casal Moderno com Fita LED',
    imageUrl: 'https://images.unsplash.com/photo-1540518614846-7eded433c457?auto=format&fit=crop&w=800&q=80',
  ),
  RoomRenderPreset(
    id: 'bedroom_gamer',
    category: 'Quartos & Suítes',
    title: 'Quarto Solteiro / Gamer Cênico',
    imageUrl: 'https://images.unsplash.com/photo-1598550476439-6847785fcea6?auto=format&fit=crop&w=800&q=80',
  ),
  RoomRenderPreset(
    id: 'closet_luxury',
    category: 'Quartos & Suítes',
    title: 'Closet Planejado com LED',
    imageUrl: 'https://images.unsplash.com/photo-1558997519-83ea9252edf8?auto=format&fit=crop&w=800&q=80',
  ),

  // ── ÁREA DE SERVIÇO & LAVANDERIA ──
  RoomRenderPreset(
    id: 'laundry_modern',
    category: 'Área de Serviço',
    title: 'Lavanderia Moderna & Planejada',
    imageUrl: 'https://images.unsplash.com/photo-1517677208171-0bc6725a3e60?auto=format&fit=crop&w=800&q=80',
  ),
  RoomRenderPreset(
    id: 'laundry_clean',
    category: 'Área de Serviço',
    title: 'Área de Serviço Clean Automatizada',
    imageUrl: 'https://images.unsplash.com/photo-1582735689369-4fe89db7114c?auto=format&fit=crop&w=800&q=80',
  ),
  RoomRenderPreset(
    id: 'laundry_minimal',
    category: 'Área de Serviço',
    title: 'Lavanderia Técnica Integrada',
    imageUrl: 'https://images.unsplash.com/photo-1626806787461-102c1bfaaea1?auto=format&fit=crop&w=800&q=80',
  ),

  // ── GARAGEM & ACESSO ──
  RoomRenderPreset(
    id: 'garage_luxury',
    category: 'Garagem',
    title: 'Garagem Residencial de Luxo',
    imageUrl: 'https://images.unsplash.com/photo-1590362891991-f776e747a588?auto=format&fit=crop&w=800&q=80',
  ),
  RoomRenderPreset(
    id: 'garage_smart_ev',
    category: 'Garagem',
    title: 'Garagem Inteligente & Carregador EV',
    imageUrl: 'https://images.unsplash.com/photo-1558442074-3c19857bc1dc?auto=format&fit=crop&w=800&q=80',
  ),
  RoomRenderPreset(
    id: 'garage_perimeter',
    category: 'Garagem',
    title: 'Acesso Garagem & Fachada Noturna',
    imageUrl: 'https://images.unsplash.com/photo-1512917774080-9991f1c4c750?auto=format&fit=crop&w=800&q=80',
  ),

  // ── COZINHAS & GOURMET ──
  RoomRenderPreset(
    id: 'kitchen_gourmet',
    category: 'Cozinhas & Gourmet',
    title: 'Cozinha Gourmet com Ilha',
    imageUrl: 'https://images.unsplash.com/photo-1600585152220-90363fe7e115?auto=format&fit=crop&w=800&q=80',
  ),
  RoomRenderPreset(
    id: 'gourmet_balcony',
    category: 'Cozinhas & Gourmet',
    title: 'Espaço Gourmet & Churrasqueira',
    imageUrl: 'https://images.unsplash.com/photo-1556911220-e15b29be8c8f?auto=format&fit=crop&w=800&q=80',
  ),
  RoomRenderPreset(
    id: 'kitchen_modern_dark',
    category: 'Cozinhas & Gourmet',
    title: 'Cozinha Contemporânea Dark',
    imageUrl: 'https://images.unsplash.com/photo-1507089947368-19c1da9775ae?auto=format&fit=crop&w=800&q=80',
  ),
  RoomRenderPreset(
    id: 'kitchen_american',
    category: 'Cozinhas & Gourmet',
    title: 'Cozinha Americana Conceito Aberto',
    imageUrl: 'https://images.unsplash.com/photo-1556909114-f6e7ad7d3136?auto=format&fit=crop&w=800&q=80',
  ),

  // ── HOME CINEMA & SOM ──
  RoomRenderPreset(
    id: 'cinema_home_theater',
    category: 'Home Cinema',
    title: 'Home Cinema Hi-Fi Premium',
    imageUrl: 'https://images.unsplash.com/photo-1593784991095-a205069470b6?auto=format&fit=crop&w=800&q=80',
  ),
  RoomRenderPreset(
    id: 'cinema_dark_room',
    category: 'Home Cinema',
    title: 'Sala de Projeção & Acústica Dark',
    imageUrl: 'https://images.unsplash.com/photo-1517604931442-7e0c8ed2963c?auto=format&fit=crop&w=800&q=80',
  ),
  RoomRenderPreset(
    id: 'audio_lounge',
    category: 'Home Cinema',
    title: 'Lounge de Som Ambiente & Áudio',
    imageUrl: 'https://images.unsplash.com/photo-1545454675-3531b543be5d?auto=format&fit=crop&w=800&q=80',
  ),

  // ── BANHEIROS & SPA ──
  RoomRenderPreset(
    id: 'bathroom_spa',
    category: 'Banheiros & SPA',
    title: 'Banheiro SPA & Hidromassagem',
    imageUrl: 'https://images.unsplash.com/photo-1584622650111-993a426fbf0a?auto=format&fit=crop&w=800&q=80',
  ),
  RoomRenderPreset(
    id: 'bathroom_master_led',
    category: 'Banheiros & SPA',
    title: 'Suíte Master Banheiro com Espelho LED',
    imageUrl: 'https://images.unsplash.com/photo-1620626011761-996317b8d101?auto=format&fit=crop&w=800&q=80',
  ),
  RoomRenderPreset(
    id: 'powder_room_luxury',
    category: 'Banheiros & SPA',
    title: 'Lavabo Social Elegante',
    imageUrl: 'https://images.unsplash.com/photo-1507652313519-d4e9174996dd?auto=format&fit=crop&w=800&q=80',
  ),

  // ── ESCRITÓRIOS & HOME OFFICE ──
  RoomRenderPreset(
    id: 'office_executive',
    category: 'Escritórios',
    title: 'Escritório Executive & Produtividade',
    imageUrl: 'https://images.unsplash.com/photo-1524758631624-e2822e304c36?auto=format&fit=crop&w=800&q=80',
  ),
  RoomRenderPreset(
    id: 'home_office_modern',
    category: 'Escritórios',
    title: 'Home Office Moderno com Automação',
    imageUrl: 'https://images.unsplash.com/photo-1593062096033-9a26b09da705?auto=format&fit=crop&w=800&q=80',
  ),

  // ── LAZER, PISCINA & EXTERNO ──
  RoomRenderPreset(
    id: 'outdoor_pool_lounge',
    category: 'Lazer & Externo',
    title: 'Varanda, Deck & Piscina Iluminada',
    imageUrl: 'https://images.unsplash.com/photo-1576013551627-0cc20b96c2a7?auto=format&fit=crop&w=800&q=80',
  ),
  RoomRenderPreset(
    id: 'outdoor_garden_lighting',
    category: 'Lazer & Externo',
    title: 'Jardim & Paisagismo Noturno',
    imageUrl: 'https://images.unsplash.com/photo-1613490493576-7fde63acd811?auto=format&fit=crop&w=800&q=80',
  ),
  RoomRenderPreset(
    id: 'firepit_lounge',
    category: 'Lazer & Externo',
    title: 'Espaço Fogo & Firepit Cênico',
    imageUrl: 'https://images.unsplash.com/photo-1600585154526-990dced4db0d?auto=format&fit=crop&w=800&q=80',
  ),
];
