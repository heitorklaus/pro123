import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../app/theme/app_colors.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/services/gemini_solar_vision_service.dart';
import '../../data/services/solar_proposal_parser_service.dart';
import '../../domain/models/product_model.dart';

/// Modal inteligente com IA Google Gemini Vision para Upload, Análise e Explosão de Cotações Fotovoltaicas
class SolarPdfImportDialog extends StatefulWidget {
  final ValueChanged<ParsedSolarProposal> onProposalImported;

  const SolarPdfImportDialog({
    super.key,
    required this.onProposalImported,
  });

  @override
  State<SolarPdfImportDialog> createState() => _SolarPdfImportDialogState();
}

class _SolarPdfImportDialogState extends State<SolarPdfImportDialog> {
  late final ProductRepository _repo;
  final _textController = TextEditingController();
  final _apiKeyController = TextEditingController();

  String? _savedApiKey;
  bool _showApiKeyConfig = false;
  String? _selectedFileName;
  bool _isAnalyzing = false;
  bool _autoRegisterProducts = true;
  ParsedSolarProposal? _parsedResult;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    try {
      _repo = Modular.get<ProductRepository>();
    } catch (_) {
      _repo = ProductRepository();
    }
    _loadApiKey();
  }

  @override
  void dispose() {
    _textController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadApiKey() async {
    final key = await GeminiSolarVisionService.getSavedApiKey();
    if (mounted) {
      setState(() {
        _savedApiKey = key;
        _apiKeyController.text = key;
        _showApiKeyConfig = false;
      });
    }
  }

  Future<void> _saveApiKey() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) {
      await GeminiSolarVisionService.clearApiKey();
      setState(() {
        _savedApiKey = null;
      });
    } else {
      await GeminiSolarVisionService.saveApiKey(key);
      setState(() {
        _savedApiKey = key;
        _showApiKeyConfig = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Chave do Google Gemini salva com sucesso!'),
          backgroundColor: Color(0xFF10B981),
        ));
      }
    }
  }

  /// Seleciona o arquivo e envia para análise com IA Gemini Vision
  Future<void> _pickFile() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'webp', 'txt'],
      );

      if (files.isNotEmpty) {
        final file = files.first;
        setState(() {
          _selectedFileName = file.name;
          _isAnalyzing = true;
          _errorMessage = null;
        });

        final bytes = await file.readAsBytes();
        final ext = file.extension?.toLowerCase() ?? 'pdf';

        // Se tem chave API do Gemini, usa a IA multimodal do Gemini
        if (_savedApiKey != null && _savedApiKey!.isNotEmpty) {
          try {
            final parsed = await GeminiSolarVisionService.analyzeSolarProposal(
              fileBytes: bytes,
              fileExtension: ext,
              customApiKey: _savedApiKey,
            );

            setState(() {
              _parsedResult = parsed;
              _isAnalyzing = false;
            });
            return;
          } catch (geminiError) {
            // Se der erro na API, exibe o aviso
            setState(() {
              _errorMessage = 'Erro ao processar com IA Gemini: $geminiError';
              _isAnalyzing = false;
            });
            return;
          }
        }

        // Caso não tenha chave API, usa o extrator de texto local como fallback
        String extractedText = '';
        if (ext == 'pdf') {
          extractedText = SolarProposalParserService.extractTextFromPdfBytes(bytes);
        }

        if (extractedText.trim().isNotEmpty) {
          _textController.text = extractedText;
          final parsed = SolarProposalParserService.parseRawText(extractedText);
          setState(() {
            _parsedResult = parsed;
            _isAnalyzing = false;
          });
        } else {
          setState(() {
            _isAnalyzing = false;
            _showApiKeyConfig = true;
            _errorMessage = 'Para analisar arquivos PDF complexos ou imagens diretamente, configure sua chave da API do Google Gemini (gratuita) abaixo.';
          });
        }
      }
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
        _errorMessage = 'Erro ao carregar arquivo: $e';
      });
    }
  }

  /// Analisa o texto colado
  Future<void> _analyzePastedText() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Por favor, cole o texto da cotação fotovoltaica.'),
        backgroundColor: Color(0xFFF59E0B),
      ));
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
    });

    final parsed = SolarProposalParserService.parseRawText(text);
    setState(() {
      _parsedResult = parsed;
      _isAnalyzing = false;
    });
  }

  /// Confirma e aplica no formulário
  Future<void> _applyAndConfirm() async {
    if (_parsedResult == null) return;

    setState(() => _isAnalyzing = true);

    try {
      AuthRepository auth;
      try {
        auth = Modular.get<AuthRepository>();
      } catch (_) {
        auth = AuthRepository();
      }
      final companyId = await auth.getCurrentCompanyId();

      // 1. Busca rápida e econômica: busca apenas componentes/usinas solares existentes da empresa
      final existingProducts = await _repo.getSolarProductsForDeduplication(companyId: companyId);

      // 2. Cria mapas de índice em memória O(1) para busca instantânea sem varreduras lineares repetidas
      final Map<String, ProductModel> skuIndex = {};
      final Map<String, ProductModel> nameIndex = {};

      for (final p in existingProducts) {
        if (p.sku != null && p.sku!.trim().isNotEmpty) {
          skuIndex[ProductRepository.normalizeKey(p.sku!)] = p;
        }
        nameIndex[ProductRepository.normalizeKey(p.name)] = p;
      }

      final updatedItems = <ParsedSolarItem>[];
      final List<ProductModel> newProductsToCreate = [];
      final List<int> newProductIndicesInUpdated = [];

      for (final item in _parsedResult!.items) {
        final normItemName = ProductRepository.normalizeKey(item.name);
        final normItemSku = item.sku != null && item.sku!.trim().isNotEmpty
            ? ProductRepository.normalizeKey(item.sku!)
            : null;

        // Busca instantânea O(1) no índice de SKU e Nome
        ProductModel? existingMatch = (normItemSku != null ? skuIndex[normItemSku] : null) ?? nameIndex[normItemName];

        if (existingMatch != null) {
          // JÁ EXISTE NO BANCO: Zero duplicata no Firestore! Vincula o registro existente
          updatedItems.add(item.copyWith(
            productId: existingMatch.id,
            name: existingMatch.name,
            sku: existingMatch.sku ?? item.sku,
            unitPrice: existingMatch.salePrice > 0 ? existingMatch.salePrice : item.unitPrice,
          ));
        } else {
          // NÃO EXISTE NO BANCO: Prepara item
          final itemIndex = updatedItems.length;
          updatedItems.add(item);

          if (_autoRegisterProducts) {
            final prod = item.toProductModel(supplierName: _parsedResult!.distributorName).copyWith(
              companyId: companyId,
            );
            newProductsToCreate.add(prod);
            newProductIndicesInUpdated.add(itemIndex);

            // Atualiza os índices locais para evitar duplicatas dentro do mesmo arquivo/lote
            if (normItemSku != null) skuIndex[normItemSku] = prod;
            nameIndex[normItemName] = prod;
          }
        }
      }

      // 3. Se houver produtos inéditos, grava todos de uma única vez via WriteBatch (1 única requisição de rede)
      if (newProductsToCreate.isNotEmpty) {
        final createdProducts = await _repo.createProductsBatch(newProductsToCreate, companyId: companyId);
        for (int i = 0; i < createdProducts.length; i++) {
          final targetIdx = newProductIndicesInUpdated[i];
          final created = createdProducts[i];
          updatedItems[targetIdx] = updatedItems[targetIdx].copyWith(productId: created.id);
        }
      }

      final finalProposal = _parsedResult!.copyWith(items: updatedItems);

      if (mounted) {
        widget.onProposalImported(finalProposal);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            'Usina Solar e ${finalProposal.items.length} produtos importados com sucesso!',
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        widget.onProposalImported(_parsedResult!);
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 880,
        height: 700,
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Cabeçalho do Modal ──────────────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Importador de Usina Solar com IA Gemini Vision',
                            style: GoogleFonts.outfit(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: _savedApiKey != null ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _savedApiKey != null ? Icons.check_circle_rounded : Icons.vpn_key_rounded,
                                  size: 11,
                                  color: _savedApiKey != null ? const Color(0xFF166534) : const Color(0xFF92400E),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _savedApiKey != null ? 'IA GEMINI ATIVA' : 'CONFIGURAR IA',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: _savedApiKey != null ? const Color(0xFF166534) : const Color(0xFF92400E),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Envie qualquer cotação em PDF ou Imagem para a IA ler visualmente e explodir todos os equipamentos',
                        style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Configurar Chave Gemini API',
                  icon: Icon(
                    Icons.key_rounded,
                    color: _savedApiKey != null ? AppColors.primary : const Color(0xFFF59E0B),
                  ),
                  onPressed: () => setState(() => _showApiKeyConfig = !_showApiKeyConfig),
                ),
                IconButton(
                  tooltip: 'Fechar',
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            const SizedBox(height: 14),
            const Divider(color: AppColors.divider),
            const SizedBox(height: 10),

            // ── Bloco de Configuração da Chave da API Gemini ─────────────────
            if (_showApiKeyConfig) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFC7D2FE)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.vpn_key_rounded, size: 18, color: Color(0xFF4F46E5)),
                        const SizedBox(width: 8),
                        Text(
                          'Chave da API do Google Gemini (Gemini 1.5 Flash Vision)',
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFF312E81)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'A IA precisa de uma chave gratuita do Google AI Studio para ler seus PDFs e imagens diretamente. Obtenha em: https://aistudio.google.com/app/apikey',
                      style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF4338CA)),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _apiKeyController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              hintText: 'Cole aqui sua chave (ex: AIzaSy...)',
                              prefixIcon: Icon(Icons.lock_outline_rounded, size: 18),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _saveApiKey,
                            borderRadius: BorderRadius.circular(8),
                            child: Ink(
                              decoration: BoxDecoration(
                                color: const Color(0xFF4F46E5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                              child: Text(
                                'SALVAR CHAVE',
                                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
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
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF991B1B), fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // ── Área Principal: Upload ou Pré-Visualização ───────────────────
            if (_parsedResult == null) ...[
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Card de Upload com IA
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF4F46E5).withValues(alpha: 0.25),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.document_scanner_rounded, size: 36, color: Colors.white),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              _selectedFileName != null
                                  ? 'Arquivo selecionado: $_selectedFileName'
                                  : 'Envie o arquivo da cotação (PDF, JPG, PNG, WEBP)',
                              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14.5, color: const Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'A IA Gemini Vision lerá visualmente tabelas, potência em kWp, telhado, valor total e todos os componentes',
                              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 18),

                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _isAnalyzing ? null : _pickFile,
                                borderRadius: BorderRadius.circular(12),
                                child: Ink(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                                  child: _isAnalyzing
                                      ? Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: const [
                                            SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                            ),
                                            SizedBox(width: 10),
                                            Text(
                                              'ANALISANDO COM IA GEMINI...',
                                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                          ],
                                        )
                                      : Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: const [
                                            Icon(Icons.file_upload_outlined, color: Colors.white, size: 20),
                                            SizedBox(width: 8),
                                            Text(
                                              'ENVIAR PDF OU IMAGEM PARA A IA',
                                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Opção Alternativa: Colar Texto
                      Row(
                        children: [
                          const Expanded(child: Divider(color: AppColors.divider)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'OU COLE O TEXTO DA COTAÇÃO ABAIXO',
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8)),
                            ),
                          ),
                          const Expanded(child: Divider(color: AppColors.divider)),
                        ],
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _textController,
                        maxLines: 5,
                        style: GoogleFonts.firaCode(fontSize: 12),
                        decoration: const InputDecoration(
                          hintText: 'Cole aqui o texto copiado da cotação...',
                          prefixIcon: Icon(Icons.paste_rounded, color: Color(0xFF64748B)),
                        ),
                      ),
                      const SizedBox(height: 10),

                      Align(
                        alignment: Alignment.centerRight,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _isAnalyzing ? null : _analyzePastedText,
                            borderRadius: BorderRadius.circular(10),
                            child: Ink(
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 16),
                                  SizedBox(width: 8),
                                  Text(
                                    'ANALISAR TEXTO',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              // ── ÁREA DE PRÉ-VISUALIZAÇÃO DA EXPLOSÃO COM IA ────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Card Resumo da Usina Detectada pela IA
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.solar_power_rounded, color: Color(0xFF166534), size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _parsedResult!.plantName,
                                        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEEF2FF),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.auto_awesome_rounded, size: 12, color: Color(0xFF4F46E5)),
                                          const SizedBox(width: 4),
                                          Text(
                                            'IA Gemini Vision',
                                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF4F46E5)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    if (_selectedFileName != null)
                                      _tag(_selectedFileName!, const Color(0xFF0F172A), const Color(0xFFE2E8F0)),
                                    if (_parsedResult!.kilowatts > 0)
                                      _tag('Potência: ${_parsedResult!.kilowatts.toStringAsFixed(2)} kWp', const Color(0xFF166534), const Color(0xFFDCFCE7)),
                                    if (_parsedResult!.generationKwh != null && _parsedResult!.generationKwh! > 0)
                                      _tag('Geração Estimada: ${_parsedResult!.generationKwh!.toStringAsFixed(0)} kWh/mês', const Color(0xFF0369A1), const Color(0xFFE0F2FE)),
                                    _tag('Telhado: ${_parsedResult!.roofType}', const Color(0xFF475569), const Color(0xFFF1F5F9)),
                                    _tag('${_parsedResult!.items.length} Equipamentos Identificados', const Color(0xFF2563EB), const Color(0xFFEFF6FF)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                currencyFormat.format(_parsedResult!.totalAmount),
                                style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF059669)),
                              ),
                              Text(
                                'Valor Total do Orçamento',
                                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Tabela de Equipamentos Explodidos
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Equipamentos Fotovoltaicos Explodidos (${_parsedResult!.items.length}):',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF334155)),
                        ),
                        InkWell(
                          onTap: () => setState(() => _parsedResult = null),
                          child: Text(
                            'Trocar Arquivo / Reanalisar',
                            style: GoogleFonts.inter(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: ListView.separated(
                            itemCount: _parsedResult!.items.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.divider),
                            itemBuilder: (ctx, idx) {
                              final item = _parsedResult!.items[idx];
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(7),
                                      decoration: BoxDecoration(
                                        color: item.componentType.color.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(item.componentType.icon, size: 16, color: item.componentType.color),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.name,
                                            style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                                          ),
                                          Text(
                                            '${item.componentType.label}${item.sku != null && item.sku!.isNotEmpty ? " • SKU: ${item.sku}" : ""}${item.manufacturer != null && item.manufacturer!.isNotEmpty ? " • Fabricante: ${item.manufacturer}" : ""}',
                                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '${item.quantity % 1 == 0 ? item.quantity.toInt().toString() : item.quantity.toString()} ${item.unit}',
                                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Opção de auto-cadastrar no catálogo geral de produtos
                    Row(
                      children: [
                        Checkbox(
                          value: _autoRegisterProducts,
                          activeColor: AppColors.primary,
                          onChanged: (val) => setState(() => _autoRegisterProducts = val ?? true),
                        ),
                        Text(
                          'Cadastrar cada item individual como Produto no catálogo geral do Mavis CRM',
                          style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w500, color: const Color(0xFF334155)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 14),
            const Divider(color: AppColors.divider),
            const SizedBox(height: 12),

            // ── Rodapé do Modal ─────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Text(
                        'CANCELAR',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                if (_parsedResult != null)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _isAnalyzing ? null : _applyAndConfirm,
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
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        child: _isAnalyzing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'EXPLODIR E PREENCHER USINA NO FORMULÁRIO',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5),
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
      ),
    );
  }

  Widget _tag(String text, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: textColor),
      ),
    );
  }
}
