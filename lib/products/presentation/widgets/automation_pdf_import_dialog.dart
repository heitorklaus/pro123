import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/services/gemini_automation_vision_service.dart';

/// Modal inteligente com IA Google Gemini Vision para Upload e Leitura de Projetos de Automação
class AutomationPdfImportDialog extends StatefulWidget {
  const AutomationPdfImportDialog({super.key});

  static Future<ParsedAutomationStudy?> show(BuildContext context) {
    return showDialog<ParsedAutomationStudy>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AutomationPdfImportDialog(),
    );
  }

  @override
  State<AutomationPdfImportDialog> createState() => _AutomationPdfImportDialogState();
}

class _AutomationPdfImportDialogState extends State<AutomationPdfImportDialog> {
  bool _isLoading = false;
  String? _statusText;
  String? _errorMessage;
  String? _selectedFileName;

  Future<void> _pickFile() async {
    setState(() {
      _errorMessage = null;
    });

    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'webp'],
      );

      if (files.isEmpty) return;

      final file = files.first;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        setState(() {
          _errorMessage = 'Não foi possível ler os dados do arquivo selecionado.';
        });
        return;
      }

      setState(() {
        _selectedFileName = file.name;
      });

      // Dispara a análise automaticamente ao selecionar o arquivo
      _processBytes(bytes, file.name, file.extension ?? 'pdf');
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro ao selecionar arquivo: $e';
      });
    }
  }

  Future<void> _processBytes(Uint8List bytes, String fileName, String extension) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _statusText = 'Enviando documento para análise visual com Google Gemini Vision...';
    });

    try {
      setState(() {
        _statusText = 'A IA está identificando ambientes e mapeando equipamentos por cômodo...';
      });

      final study = await GeminiAutomationVisionService.analyzeAutomationProject(
        fileBytes: bytes,
        fileExtension: extension,
      );

      if (mounted) {
        Navigator.of(context).pop(study);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _statusText = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: const Color(0xFF0F172A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ──
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF06B6D4)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
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
                        Text(
                          'Importar com IA Gemini',
                          style: GoogleFonts.outfit(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Leitura inteligente de memorial, planta ou cotação de automação',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Dropzone / Card de Upload ──
              if (!_isLoading) ...[
                InkWell(
                  onTap: _pickFile,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 34),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B).withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.cloud_upload_rounded,
                            color: Color(0xFF818CF8),
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Clique para selecionar PDF ou Imagem',
                          style: GoogleFonts.inter(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Formatos aceitos: PDF, PNG, JPG, WEBP (Projetos, Cotações de Distribuidores, Memoriais)',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // ── Estado de Carregamento / Progresso da IA ──
              if (_isLoading) ...[
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(
                        width: 42,
                        height: 42,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Color(0xFF6366F1),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        _selectedFileName ?? 'Processando arquivo...',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _statusText ?? 'Analisando documento...',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF818CF8),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],

              // ── Mensagem de Erro (se houver) ──
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF450A0A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFEF4444)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFFFCA5A5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // ── Dica de Como Funciona ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B).withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFFF59E0B), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'A IA extrai o nome do estudo, cadastra os ambientes automaticamente e organiza os circuitos/equipamentos em cada cômodo.',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
