import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/repositories/product_repository.dart';
import '../domain/models/product_model.dart';
import 'automation_web_proposal_view.dart';
import 'widgets/automation_proposal_customizer_dialog.dart';
import 'widgets/automation_preview_bridge.dart';

/// Página Pública e Autônoma da Proposta Web de Automação (aberta em nova aba _blank)
class AutomationWebProposalPage extends StatefulWidget {
  final String studyId;
  final ProductModel? initialProduct;

  const AutomationWebProposalPage({
    super.key,
    required this.studyId,
    this.initialProduct,
  });

  @override
  State<AutomationWebProposalPage> createState() => _AutomationWebProposalPageState();
}

class _AutomationWebProposalPageState extends State<AutomationWebProposalPage> {
  final _productRepo = ProductRepository();

  bool _isLoading = true;
  String? _errorMessage;
  ProductModel? _studyProduct;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      ProductModel? loadedProduct;

      // 1. Se já fornecido diretamente em memória
      if (widget.initialProduct != null) {
        loadedProduct = widget.initialProduct;
      }

      // 2. Tenta carregar do IndexedDB / Bridge primeiro (onde o modelo 3D está intacto!)
      loadedProduct ??= await AutomationPreviewBridge.loadPreviewData(widget.studyId);

      // 3. Se for modo preview ou rascunho em tempo real pelo localStorage
      if (loadedProduct == null && (widget.studyId == 'preview' || widget.studyId == 'preview_mode' || widget.studyId.isEmpty)) {
        loadedProduct = await _loadFromLocalStorage();
      }

      // 4. Busca no Firestore pelo ID do Estudo
      if (loadedProduct == null && widget.studyId.isNotEmpty && widget.studyId != 'preview') {
        loadedProduct = await _productRepo.getProductById(widget.studyId);
      }

      // 5. Fallback: tentar carregar rascunho do Bridge ou localStorage se existir
      loadedProduct ??= await AutomationPreviewBridge.loadPreviewData();
      loadedProduct ??= await _loadFromLocalStorage();

      if (loadedProduct != null) {
        // Resolve o modelo 3D (GLB) via IndexedDB mesmo se carregado do Firestore
        loadedProduct = await AutomationPreviewBridge.resolve3DModelForProduct(loadedProduct);

        setState(() {
          _studyProduct = loadedProduct;
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = 'Estudo de automação não encontrado ou o link expirou.';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erro ao carregar proposta web: $e';
      });
    }
  }

  Future<ProductModel?> _loadFromLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('mavis_automation_preview_study');
      if (raw != null && raw.isNotEmpty) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        final id = map['id']?.toString() ?? 'preview_mode';
        final createdAt = DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now();
        final updatedAt = DateTime.tryParse(map['updatedAt']?.toString() ?? '') ?? DateTime.now();

        return ProductModel.fromMap(map, id).copyWith(
          createdAt: createdAt,
          updatedAt: updatedAt,
        );
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF070B14),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
                      blurRadius: 24,
                    ),
                  ],
                ),
                child: const CircularProgressIndicator(
                  color: Color(0xFF00E5FF),
                  strokeWidth: 2.5,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'CARREGANDO PROPOSTA WEB DE AUTOMAÇÃO...',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: const Color(0xFF00E5FF),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Preparando maquete 3D e especificações dos ambientes',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null || _studyProduct == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF070B14),
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 48),
                const SizedBox(height: 16),
                Text(
                  'Proposta Não Encontrada',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _errorMessage ?? 'Não foi possível carregar os dados desta proposta.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _loadData,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Tentar Novamente'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E5FF),
                    foregroundColor: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final themeAttrs = _studyProduct!.specificAttributes['proposalTheme'] as Map<String, dynamic>?;

    return AutomationWebProposalView(
      studyProduct: _studyProduct!,
      initialThemeConfig: AutomationProposalThemeConfig.fromMap(themeAttrs),
    );
  }
}
