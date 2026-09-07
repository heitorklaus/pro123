import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/models/roof_study_model.dart';

/// Diálogo Modal de Adição de Fotos ao Estudo e Emissão do Relatório em PDF
class SolarStudyPhotoDialog extends StatefulWidget {
  final List<RoofStudyPhoto> initialPhotos;
  final double currentHour;
  final Future<Uint8List?> Function() onCaptureCanvas;
  final Future<void> Function(List<RoofStudyPhoto> photos) onConcludeStudy;

  const SolarStudyPhotoDialog({
    super.key,
    required this.initialPhotos,
    required this.currentHour,
    required this.onCaptureCanvas,
    required this.onConcludeStudy,
  });

  static Future<void> show(
    BuildContext context, {
    required List<RoofStudyPhoto> initialPhotos,
    required double currentHour,
    required Future<Uint8List?> Function() onCaptureCanvas,
    required Future<void> Function(List<RoofStudyPhoto> photos) onConcludeStudy,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => SolarStudyPhotoDialog(
        initialPhotos: initialPhotos,
        currentHour: currentHour,
        onCaptureCanvas: onCaptureCanvas,
        onConcludeStudy: onConcludeStudy,
      ),
    );
  }

  @override
  State<SolarStudyPhotoDialog> createState() => _SolarStudyPhotoDialogState();
}

class _SolarStudyPhotoDialogState extends State<SolarStudyPhotoDialog> {
  late List<RoofStudyPhoto> _photos;
  bool _isCapturing = false;
  bool _isGeneratingPdf = false;

  @override
  void initState() {
    super.initState();
    _photos = List.from(widget.initialPhotos);
  }

  String _formatHour(double h) {
    final hour = h.floor();
    final minute = ((h - hour) * 60).round();
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  Future<void> _capturePhoto() async {
    if (_isCapturing) return;
    setState(() => _isCapturing = true);

    try {
      final bytes = await widget.onCaptureCanvas();
      if (bytes != null && mounted) {
        final b64 = base64Encode(bytes);
        final hourStr = _formatHour(widget.currentHour);
        final newPhoto = RoofStudyPhoto(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          label: 'Simulação Solar às $hourStr',
          hourOfDay: widget.currentHour,
          imageBase64: b64,
          capturedAt: DateTime.now(),
        );

        setState(() {
          _photos.add(newPhoto);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Foto capturada com sucesso às $hourStr!',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('[SolarStudyPhotoDialog] Erro ao capturar foto: $e');
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  Future<void> _concludeAndDownload() async {
    if (_isGeneratingPdf) return;
    setState(() => _isGeneratingPdf = true);

    try {
      await widget.onConcludeStudy(_photos);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('[SolarStudyPhotoDialog] Erro ao concluir estudo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao gerar relatório: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: 620,
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF334155), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.60),
              blurRadius: 36,
              offset: const Offset(0, 14),
            ),
            BoxShadow(
              color: const Color(0xFF38BDF8).withValues(alpha: 0.10),
              blurRadius: 28,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── CABEÇALHO DO DIÁLOGO ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 16, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
                    ),
                    child: const Icon(
                      Icons.add_a_photo_rounded,
                      color: Color(0xFF38BDF8),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Deseja adicionar uma foto ao estudo?',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Capture imagens em diferentes horários e ângulos para o relatório técnico.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                    tooltip: 'Voltar ao desenho',
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFF1E293B), height: 1),

            // ── GALERIA DE FOTOS CAPTURADAS ATÉ O MOMENTO ────────────────────
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Fotos Adicionadas (${_photos.length}):',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFCBD5E1),
                        ),
                      ),
                      if (_photos.isNotEmpty)
                        Text(
                          'Horário atual: ${_formatHour(widget.currentHour)}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF38BDF8),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (_photos.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 36),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B).withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF334155), style: BorderStyle.solid),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.photo_camera_back_outlined, size: 38, color: Color(0xFF64748B)),
                          const SizedBox(height: 10),
                          Text(
                            'Nenhuma foto capturada ainda neste estudo.',
                            style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Clique em "Adicionar Foto Atual" para registrar a vista e as sombras.',
                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    )
                  else
                    SizedBox(
                      height: 150,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _photos.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final p = _photos[index];
                          Uint8List? imgBytes;
                          try {
                            imgBytes = base64Decode(p.imageBase64);
                          } catch (_) {}

                          return Container(
                            width: 160,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF334155), width: 1.2),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: imgBytes != null
                                        ? Image.memory(imgBytes, fit: BoxFit.cover)
                                        : Container(color: Colors.black26),
                                  ),
                                  // Gradiente de contraste inferior
                                  Positioned(
                                    bottom: 0,
                                    left: 0,
                                    right: 0,
                                    height: 50,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.transparent,
                                            Colors.black.withValues(alpha: 0.85),
                                          ],
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Tag de Horário
                                  Positioned(
                                    bottom: 8,
                                    left: 8,
                                    child: Text(
                                      _formatHour(p.hourOfDay),
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF38BDF8),
                                      ),
                                    ),
                                  ),
                                  // Botão Excluir Foto
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: InkWell(
                                      onTap: () => setState(() => _photos.removeAt(index)),
                                      borderRadius: BorderRadius.circular(20),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.65),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.delete_outline_rounded,
                                          size: 16,
                                          color: Color(0xFFEF4444),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),

            const Divider(color: Color(0xFF1E293B), height: 1),

            // ── BOTÕES DE AÇÃO INFERIORES ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Row(
                children: [
                  // Botão Secundário: Concluir com fotos existentes e Gerar PDF
                  Expanded(
                    flex: 6,
                    child: OutlinedButton.icon(
                      onPressed: _isGeneratingPdf ? null : _concludeAndDownload,
                      icon: _isGeneratingPdf
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                            )
                          : const Icon(Icons.picture_as_pdf_rounded, size: 18, color: Color(0xFF10B981)),
                      label: Text(
                        _isGeneratingPdf
                            ? 'GERANDO PDF...'
                            : 'Não, concluir estudo com as fotos existentes',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFF10B981), width: 1.2),
                        backgroundColor: const Color(0xFF064E3B).withValues(alpha: 0.3),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Botão Primário: Adicionar Foto Atual
                  Expanded(
                    flex: 5,
                    child: ElevatedButton.icon(
                      onPressed: _isCapturing ? null : _capturePhoto,
                      icon: _isCapturing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.camera_alt_rounded, size: 18),
                      label: Text(
                        _isCapturing ? 'CAPTURANDO...' : 'Adicionar Foto Atual',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                      ),
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
