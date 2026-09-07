import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../auth/domain/models/user_model.dart';
import '../../../solar_designer/data/repositories/roof_study_repository.dart';
import '../../../solar_designer/domain/models/roof_study_model.dart';

/// Diálogo Seletor de Estudos de Telhado & Sombreamento Salvos no Banco para Vincular à Proposta
class ProposalRoofStudyPickerDialog extends StatefulWidget {
  final UserModel? currentUser;
  final String? companyId;
  final ValueChanged<RoofStudyModel> onStudySelected;

  const ProposalRoofStudyPickerDialog({
    super.key,
    this.currentUser,
    this.companyId,
    required this.onStudySelected,
  });

  static Future<RoofStudyModel?> show(
    BuildContext context, {
    UserModel? currentUser,
    String? companyId,
  }) {
    return showDialog<RoofStudyModel>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ProposalRoofStudyPickerDialog(
        currentUser: currentUser,
        companyId: companyId,
        onStudySelected: (study) => Navigator.of(ctx).pop(study),
      ),
    );
  }

  @override
  State<ProposalRoofStudyPickerDialog> createState() =>
      _ProposalRoofStudyPickerDialogState();
}

class _ProposalRoofStudyPickerDialogState
    extends State<ProposalRoofStudyPickerDialog> {
  final _searchCtrl = TextEditingController();
  final _repo = RoofStudyRepository();
  String _searchFilter = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 820,
        height: 640,
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF334155), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.65),
              blurRadius: 40,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── CABEÇALHO DO SELETOR ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 20, 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.3)),
                    ),
                    child: const Icon(
                      Icons.solar_power_rounded,
                      color: Color(0xFF38BDF8),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Vincular Estudo de Telhado à Proposta',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Selecione um dimensionamento e análise de sombra salvos para incorporar à proposta.',
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
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFF1E293B), height: 1),

            // ── BARRA DE BUSCA RÁPIDA ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 10),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (val) => setState(() => _searchFilter = val.trim().toLowerCase()),
                style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Buscar por nome do estudo, cliente ou endereço...',
                  hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
                  suffixIcon: _searchFilter.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18, color: Colors.white60),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _searchFilter = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF334155)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF334155)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
                  ),
                ),
              ),
            ),

            // ── LISTA DE ESTUDOS EM TEMPO REAL ──────────────────────────────
            Expanded(
              child: StreamBuilder<List<RoofStudyModel>>(
                stream: _repo.getRoofStudiesStream(
                  companyId: widget.companyId,
                  currentUser: widget.currentUser,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Erro ao carregar estudos: ${snapshot.error}',
                        style: GoogleFonts.inter(color: const Color(0xFFEF4444)),
                      ),
                    );
                  }

                  var studies = snapshot.data ?? [];

                  if (_searchFilter.isNotEmpty) {
                    studies = studies.where((s) {
                      final name = s.name.toLowerCase();
                      final client = (s.clientName ?? '').toLowerCase();
                      final addr = s.formattedAddress.toLowerCase();
                      return name.contains(_searchFilter) ||
                          client.contains(_searchFilter) ||
                          addr.contains(_searchFilter);
                    }).toList();
                  }

                  if (studies.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.folder_open_rounded, size: 48, color: Color(0xFF475569)),
                          const SizedBox(height: 12),
                          Text(
                            _searchFilter.isNotEmpty
                                ? 'Nenhum estudo encontrado para "$_searchFilter".'
                                : 'Nenhum estudo de telhado cadastrado ainda.',
                            style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    itemCount: studies.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final study = studies[index];
                      return _buildStudyItemCard(study);
                    },
                  );
                },
              ),
            ),

            // ── RODAPÉ ───────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFF0B1120),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
                border: Border(top: BorderSide(color: Color(0xFF1E293B))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '💡 Ao selecionar, a usina e módulos serão adicionados à proposta.',
                    style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                  ),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFCBD5E1),
                      side: const BorderSide(color: Color(0xFF334155)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudyItemCard(RoofStudyModel study) {
    // Tenta obter thumbnail em base64 da miniatura ou da primeira foto capturada
    String? thumbB64 = study.thumbnailBase64;
    if ((thumbB64 == null || thumbB64.isEmpty) && study.studyPhotos.isNotEmpty) {
      thumbB64 = study.studyPhotos.first.imageBase64;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF334155)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.20),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Miniatura com borda arredondada
          Container(
            width: 84,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF475569)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: thumbB64 != null && thumbB64.isNotEmpty
                  ? Image.memory(
                      base64Decode(thumbB64.contains(',') ? thumbB64.split(',').last : thumbB64),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported_rounded, color: Colors.white30),
                    )
                  : const Center(
                      child: Icon(Icons.solar_power_rounded, color: Color(0xFF38BDF8), size: 28),
                    ),
            ),
          ),
          const SizedBox(width: 16),

          // Informações do Estudo
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        study.name.isNotEmpty ? study.name : 'Estudo de Telhado Solar',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.35)),
                      ),
                      child: Text(
                        '${study.totalKwp.toStringAsFixed(2)} kWp',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (study.clientName != null && study.clientName!.isNotEmpty)
                  Text(
                    'Cliente: ${study.clientName}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFCBD5E1),
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  study.formattedAddress.isNotEmpty
                      ? study.formattedAddress
                      : (study.cep != null ? 'CEP: ${study.cep}' : 'Local não especificado'),
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: const Color(0xFF94A3B8),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      '${study.totalModulesCount} módulos',
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF38BDF8), fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '~${study.estimatedMonthlyKwh.toStringAsFixed(0)} kWh/mês',
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF10B981), fontWeight: FontWeight.w600),
                    ),
                    if (study.studyPhotos.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.photo_library_rounded, size: 13, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 4),
                          Text(
                            '${study.studyPhotos.length} fotos',
                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFF59E0B), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // Botão Vincular à Proposta
          ElevatedButton.icon(
            onPressed: () => widget.onStudySelected(study),
            icon: const Icon(Icons.link_rounded, size: 16),
            label: Text(
              'Vincular',
              style: GoogleFonts.outfit(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}
