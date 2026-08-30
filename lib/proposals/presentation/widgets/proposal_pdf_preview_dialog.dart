import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';
import '../../../app/theme/app_colors.dart';
import '../../data/services/solar_proposal_pdf_service.dart';
import '../../data/services/proposal_pdf_service.dart';
import '../../domain/models/proposal_model.dart';
import '../web_proposal_page.dart';

/// Diálogo modal interativo de pré-visualização do PDF da proposta em alta resolução
class ProposalPdfPreviewDialog extends StatelessWidget {
  final ProposalModel proposal;

  const ProposalPdfPreviewDialog({
    super.key,
    required this.proposal,
  });

  @override
  Widget build(BuildContext context) {
    final isSolar = proposal.items.any((i) => i.isSolarPlant);

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 950,
        height: 750,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ── Cabeçalho do Modal ───────────────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: isSolar
                        ? const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)])
                        : AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isSolar ? Icons.solar_power_rounded : Icons.picture_as_pdf_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Visualização da Proposta: ${proposal.proposalNumber}',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          if (isSolar) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFF59E0B)),
                              ),
                              child: Text(
                                '☀️ USINA SOLAR (6 PÁGINAS)',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFB45309),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        'Cliente: ${proposal.clientName}  •  Total: R\$ ${proposal.totalAmount.toStringAsFixed(2).replaceAll('.', ',')}',
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        showDialog(
                          context: context,
                          builder: (ctx) => Dialog(
                            backgroundColor: Colors.transparent,
                            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: SizedBox(
                                width: 1200,
                                height: 900,
                                child: WebProposalPage(
                                  proposalId: proposal.id,
                                  initialProposal: proposal,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.language_rounded, size: 16, color: Color(0xFF059669)),
                      label: const Text('VER VERSÃO WEB', style: TextStyle(color: Color(0xFF059669), fontSize: 12, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF059669)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Fechar',
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(color: AppColors.divider, height: 1),
            const SizedBox(height: 12),

            // ── Visualizador de PDF Interativo (Printing / PdfPreview) ───────
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: PdfPreview(
                  build: (format) => isSolar
                      ? SolarProposalPdfService.generateSolarProposalPdf(proposal)
                      : ProposalPdfService.generateProposalPdf(proposal),
                  canChangeOrientation: false,
                  canChangePageFormat: false,
                  canDebug: false,
                  dynamicLayout: false,
                  pdfFileName: 'Proposta_${proposal.proposalNumber}.pdf',
                  loadingWidget: const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
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
