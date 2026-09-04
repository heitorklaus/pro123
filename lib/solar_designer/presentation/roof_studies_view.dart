import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../app/theme/app_colors.dart';
import '../../auth/data/repositories/auth_repository.dart';
import '../../auth/domain/models/user_model.dart';
import '../data/repositories/roof_study_repository.dart';
import '../domain/models/roof_study_model.dart';
import 'solar_roof_designer_dialog.dart';
import 'widgets/roof_study_setup_dialog.dart';

/// View Principal do Módulo de Estudos de Telhado (SPA Miolo)
class RoofStudiesView extends StatefulWidget {
  final UserModel? currentUser;

  const RoofStudiesView({
    super.key,
    this.currentUser,
  });

  @override
  State<RoofStudiesView> createState() => _RoofStudiesViewState();
}

class _RoofStudiesViewState extends State<RoofStudiesView> {
  final RoofStudyRepository _repo = RoofStudyRepository();
  final AuthRepository _authRepo = AuthRepository();
  final TextEditingController _searchCtrl = TextEditingController();

  StreamSubscription<UserModel?>? _userSub;
  UserModel? _currentUser;
  String? _companyId;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _currentUser = widget.currentUser;
    _companyId = widget.currentUser?.effectiveCompanyId;

    _userSub = _authRepo.getCurrentUserStream().listen((user) {
      if (mounted) {
        setState(() {
          _currentUser = user;
          _companyId = user?.effectiveCompanyId ?? _companyId;
        });
      }
    });
  }

  @override
  void dispose() {
    _userSub?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _startNewStudy() async {
    final setupResult = await RoofStudySetupDialog.show(
      context,
      currentUser: _currentUser,
    );

    if (setupResult == null || !mounted) return;

    await SolarRoofDesignerDialog.show(
      context,
      initialStudyName: setupResult.studyName,
      initialClient: setupResult.selectedClient,
      initialProposal: setupResult.selectedProposal,
      currentUser: _currentUser,
    );
  }

  Future<void> _openStudy(RoofStudyModel study) async {
    await SolarRoofDesignerDialog.show(
      context,
      initialStudy: study,
      currentUser: _currentUser,
    );
  }

  Future<void> _editStudyLinks(RoofStudyModel study) async {
    final result = await RoofStudySetupDialog.show(
      context,
      currentUser: _currentUser,
      isEditingLinksOnly: true,
      existingStudy: study,
    );

    if (result != null) {
      final updated = study.copyWith(
        name: result.studyName,
        clientId: result.selectedClient?.id,
        clientName: result.selectedClient?.name,
        proposalId: result.selectedProposal?.id,
        proposalCode: result.selectedProposal != null
            ? '#${result.selectedProposal!.proposalNumber}'
            : null,
      );

      try {
        await _repo.saveStudy(updated);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vínculos do estudo atualizados com sucesso!'),
              backgroundColor: Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao atualizar vínculos: $e'),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        }
      }
    }
  }

  Future<void> _confirmDeleteStudy(RoofStudyModel study) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_outline_rounded,
                  color: Color(0xFFEF4444), size: 24),
            ),
            const SizedBox(width: 12),
            Text(
              'Excluir Estudo',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Deseja realmente excluir o estudo "${study.name}"?\nEsta ação não poderá ser desfeita.',
          style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('CANCELAR',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('SIM, EXCLUIR',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _repo.deleteStudy(study.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Estudo excluído com sucesso.'),
              backgroundColor: Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao excluir estudo: $e'),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 768;

        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 14 : 32),
            child: StreamBuilder<List<RoofStudyModel>>(
              stream: _repo.getRoofStudiesStream(
                companyId: _companyId,
                currentUser: _currentUser,
                isSuperAdmin: _currentUser?.isSuperAdmin ?? false,
              ),
              builder: (context, snapshot) {
                final allStudies = snapshot.data ?? [];
                final queryLower = _query.trim().toLowerCase();

                final filteredStudies = allStudies.where((s) {
                  if (queryLower.isEmpty) return true;
                  final nameMatch = s.name.toLowerCase().contains(queryLower);
                  final clientMatch = (s.clientName ?? '').toLowerCase().contains(queryLower);
                  final proposalMatch = (s.proposalCode ?? '').toLowerCase().contains(queryLower);
                  final addrMatch = s.formattedAddress.toLowerCase().contains(queryLower);
                  return nameMatch || clientMatch || proposalMatch || addrMatch;
                }).toList();

                // Cálculos de KPIs
                final totalCount = allStudies.length;
                final totalKwp = allStudies.fold<double>(0.0, (sum, s) => sum + s.totalKwp);
                final totalModules = allStudies.fold<int>(0, (sum, s) => sum + s.totalModules);
                final withProposalCount = allStudies.where((s) => s.hasProposal).length;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 1. CABEÇALHO COM TÍTULO E BOTÃO NOVO ESTUDO ─────────
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
                                'Estudos de Telhado 🛰️',
                                style: GoogleFonts.outfit(
                                  fontSize: isMobile ? 20 : 26,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Mapeamento de telhados, alocação de placas e dimensionamento solar via satélite',
                                style: GoogleFonts.inter(
                                  fontSize: isMobile ? 12 : 14,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _startNewStudy,
                            borderRadius: BorderRadius.circular(12),
                            child: Ink(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFD97706).withValues(alpha: 0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isMobile ? 14 : 20,
                                  vertical: isMobile ? 9 : 11,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.satellite_alt_rounded,
                                        size: 18, color: Colors.white),
                                    const SizedBox(width: 8),
                                    Text(
                                      isMobile ? 'NOVO' : 'NOVO ESTUDO',
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                        fontSize: isMobile ? 12 : 13.5,
                                        color: Colors.white,
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

                    SizedBox(height: isMobile ? 12 : 20),

                    // ── 2. KPIS EM TEMPO REAL ───────────────────────────────
                    _buildKpiRow(
                      isMobile: isMobile,
                      isDark: isDark,
                      totalCount: totalCount,
                      totalKwp: totalKwp,
                      totalModules: totalModules,
                      withProposalCount: withProposalCount,
                    ),

                    SizedBox(height: isMobile ? 12 : 18),

                    // ── 3. CAMPO DE BUSCA ───────────────────────────────────
                    SizedBox(
                      width: isMobile ? double.infinity : 400,
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (v) => setState(() => _query = v),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        decoration: InputDecoration(
                          hintText: isMobile
                              ? 'Buscar estudo...'
                              : 'Buscar por nome, cliente, proposta ou endereço...',
                          hintStyle: GoogleFonts.inter(
                              fontSize: 13, color: const Color(0xFF94A3B8)),
                          prefixIcon: Icon(Icons.search_rounded,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), size: 20),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: isDark ? const Color(0xFF334155) : AppColors.border,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: isDark ? const Color(0xFF334155) : AppColors.border,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: Color(0xFFF59E0B), width: 1.5),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: isMobile ? 12 : 16),

                    // ── 4. TABELA DE ESTUDOS (OU ESTADO VAZIO) ───────────────
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: isMobile
                              ? Colors.transparent
                              : (isDark ? const Color(0xFF1E293B) : Colors.white),
                          borderRadius: BorderRadius.circular(16),
                          border: isMobile
                              ? null
                              : Border.all(
                                  color: isDark ? const Color(0xFF334155) : AppColors.border),
                          boxShadow: isMobile
                              ? null
                              : [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: snapshot.connectionState == ConnectionState.waiting &&
                                  allStudies.isEmpty
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    color: Color(0xFFF59E0B),
                                  ),
                                )
                              : filteredStudies.isEmpty
                                  ? _buildEmptyState(
                                      isQuerying: queryLower.isNotEmpty,
                                      isDark: isDark,
                                    )
                                  : isMobile
                                      ? _buildMobileList(filteredStudies, isDark: isDark)
                                      : _buildDesktopTable(filteredStudies, isDark: isDark),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  // ── KPIS ─────────────────────────────────────────────────────────────────
  Widget _buildKpiRow({
    required bool isMobile,
    required bool isDark,
    required int totalCount,
    required double totalKwp,
    required int totalModules,
    required int withProposalCount,
  }) {
    final kpis = [
      _KpiData(
        title: 'Total de Estudos',
        value: '$totalCount',
        icon: Icons.satellite_alt_rounded,
        color: const Color(0xFF38BDF8),
        bgGradient: const [Color(0xFF0284C7), Color(0xFF0369A1)],
      ),
      _KpiData(
        title: 'Potência Mapeada',
        value: '${totalKwp.toStringAsFixed(1)} kWp',
        icon: Icons.solar_power_rounded,
        color: const Color(0xFFF59E0B),
        bgGradient: const [Color(0xFFD97706), Color(0xFFB45309)],
      ),
      _KpiData(
        title: 'Placas Alocadas',
        value: '$totalModules un',
        icon: Icons.grid_view_rounded,
        color: const Color(0xFF10B981),
        bgGradient: const [Color(0xFF059669), Color(0xFF047857)],
      ),
      _KpiData(
        title: 'Com Proposta',
        value: '$withProposalCount estudos',
        icon: Icons.description_rounded,
        color: const Color(0xFF818CF8),
        bgGradient: const [Color(0xFF4F46E5), Color(0xFF4338CA)],
      ),
    ];

    if (isMobile) {
      return SizedBox(
        height: 78,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: kpis.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (ctx, i) => _buildKpiCard(kpis[i], isDark: isDark, width: 170),
        ),
      );
    }

    return Row(
      children: kpis
          .map((kpi) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _buildKpiCard(kpi, isDark: isDark),
                ),
              ))
          .toList()
        ..last = Expanded(child: _buildKpiCard(kpis.last, isDark: isDark)),
    );
  }

  Widget _buildKpiCard(_KpiData kpi, {required bool isDark, double? width}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF334155) : AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: kpi.bgGradient),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(kpi.icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  kpi.title,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  kpi.value,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── TABELA DESKTOP ────────────────────────────────────────────────────────
  Widget _buildDesktopTable(List<RoofStudyModel> studies, {required bool isDark}) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Column(
      children: [
        // Cabeçalho da Tabela
        Container(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text('ESTUDO & ENDEREÇO',
                    style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569))),
              ),
              Expanded(
                flex: 2,
                child: Text('CLIENTE',
                    style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569))),
              ),
              Expanded(
                flex: 2,
                child: Text('PROPOSTA',
                    style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569))),
              ),
              Expanded(
                flex: 2,
                child: Text('DIMENSIONAMENTO',
                    style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569))),
              ),
              Expanded(
                flex: 2,
                child: Text('TELHADOS / ÁREA',
                    style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569))),
              ),
              Expanded(
                flex: 2,
                child: Text('ATUALIZADO EM',
                    style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569))),
              ),
              SizedBox(
                width: 130,
                child: Text('AÇÕES',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569))),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: isDark ? const Color(0xFF334155) : AppColors.border),

        // Linhas da Tabela
        Expanded(
          child: ListView.separated(
            itemCount: studies.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
            itemBuilder: (ctx, index) {
              final study = studies[index];

              return InkWell(
                onTap: () => _openStudy(study),
                hoverColor: isDark ? const Color(0xFF334155).withValues(alpha: 0.3) : const Color(0xFFF8FAFC),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(
                    children: [
                      // 1. Estudo & Miniatura
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF334155)),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: study.snapshotImageBase64 != null &&
                                      study.snapshotImageBase64!.isNotEmpty
                                  ? Image.memory(
                                      base64Decode(study.snapshotImageBase64!),
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(
                                        Icons.satellite_alt_rounded,
                                        color: Color(0xFFF59E0B),
                                        size: 20,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.satellite_alt_rounded,
                                      color: Color(0xFFF59E0B),
                                      size: 20,
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
                                        child: Text(
                                          study.name,
                                          style: GoogleFonts.inter(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      _buildStudyModeBadge(study, isDark: isDark),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    study.formattedAddress,
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 2. Cliente
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: study.hasClient
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF064E3B).withValues(alpha: 0.6)
                                        : const Color(0xFFECFDF5),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isDark
                                          ? const Color(0xFF059669)
                                          : const Color(0xFFA7F3D0),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.person_rounded,
                                          size: 13,
                                          color: isDark
                                              ? const Color(0xFF34D399)
                                              : const Color(0xFF059669)),
                                      const SizedBox(width: 5),
                                      Flexible(
                                        child: Text(
                                          study.displayClientName,
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: isDark
                                                ? const Color(0xFF34D399)
                                                : const Color(0xFF047857),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF0F172A)
                                        : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Sem Cliente',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ),
                        ),
                      ),

                      // 3. Proposta
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: study.hasProposal
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF312E81).withValues(alpha: 0.6)
                                        : const Color(0xFFEEF2FF),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isDark
                                          ? const Color(0xFF6366F1)
                                          : const Color(0xFFC7D2FE),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.description_rounded,
                                          size: 13,
                                          color: isDark
                                              ? const Color(0xFF818CF8)
                                              : const Color(0xFF4F46E5)),
                                      const SizedBox(width: 5),
                                      Text(
                                        study.displayProposal,
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? const Color(0xFF818CF8)
                                              : const Color(0xFF4338CA),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF0F172A)
                                        : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Sem Proposta',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ),
                        ),
                      ),

                      // 4. Dimensionamento (Placas & kWp)
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${study.totalKwp.toStringAsFixed(2)} kWp',
                              style: GoogleFonts.outfit(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              '${study.totalModules} placas • ~${study.estimatedMonthlyKwh.toStringAsFixed(0)} kWh/mês',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 5. Águas & Área
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${study.sections.length} ${study.sections.length == 1 ? 'telhado' : 'telhados'}',
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                              ),
                            ),
                            Text(
                              '${study.totalRoofAreaM2.toStringAsFixed(1)} m²',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 6. Atualizado Em
                      Expanded(
                        flex: 2,
                        child: Text(
                          dateFormat.format(study.updatedAt),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ),

                      // 7. Ações
                      SizedBox(
                        width: 130,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.satellite_alt_rounded,
                                  color: Color(0xFF0284C7), size: 20),
                              tooltip: 'Abrir no Satélite 🛰️',
                              onPressed: () => _openStudy(study),
                            ),
                            IconButton(
                              icon: const Icon(Icons.link_rounded,
                                  color: Color(0xFF6366F1), size: 20),
                              tooltip: 'Alterar Vínculos / Nome 🔗',
                              onPressed: () => _editStudyLinks(study),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded,
                                  color: Color(0xFFEF4444), size: 20),
                              tooltip: 'Excluir Estudo 🗑️',
                              onPressed: () => _confirmDeleteStudy(study),
                            ),
                          ],
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
    );
  }

  // ── LISTA MOBILE ─────────────────────────────────────────────────────────
  Widget _buildMobileList(List<RoofStudyModel> studies, {required bool isDark}) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: studies.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, index) {
        final study = studies[index];

        return InkWell(
          onTap: () => _openStudy(study),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : AppColors.border,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: study.snapshotImageBase64 != null &&
                              study.snapshotImageBase64!.isNotEmpty
                          ? Image.memory(
                              base64Decode(study.snapshotImageBase64!),
                              fit: BoxFit.cover,
                            )
                          : const Icon(Icons.satellite_alt_rounded,
                              color: Color(0xFFF59E0B), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  study.name,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildStudyModeBadge(study, isDark: isDark),
                            ],
                          ),
                          Text(
                            study.formattedAddress,
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (study.hasClient)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF064E3B).withValues(alpha: 0.6)
                              : const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isDark ? const Color(0xFF059669) : const Color(0xFFA7F3D0),
                          ),
                        ),
                        child: Text(
                          study.displayClientName,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFF34D399) : const Color(0xFF047857),
                          ),
                        ),
                      ),
                    if (study.hasProposal)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF312E81).withValues(alpha: 0.6)
                              : const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isDark ? const Color(0xFF6366F1) : const Color(0xFFC7D2FE),
                          ),
                        ),
                        child: Text(
                          study.displayProposal,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4338CA),
                          ),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${study.totalKwp.toStringAsFixed(1)} kWp • ${study.totalModules} un',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFB45309),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _openStudy(study),
                      icon: const Icon(Icons.satellite_alt_rounded, size: 16),
                      label: const Text('ABRIR'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.link_rounded, size: 18),
                      onPressed: () => _editStudyLinks(study),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded,
                          size: 18, color: Color(0xFFEF4444)),
                      onPressed: () => _confirmDeleteStudy(study),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── ESTADO VAZIO ─────────────────────────────────────────────────────────
  Widget _buildEmptyState({required bool isQuerying, required bool isDark}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : AppColors.border,
                ),
              ),
              child: Icon(
                isQuerying
                    ? Icons.search_off_rounded
                    : Icons.satellite_alt_rounded,
                size: 48,
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isQuerying
                  ? 'Nenhum estudo encontrado para a busca'
                  : 'Nenhum estudo de telhado cadastrado',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isQuerying
                  ? 'Tente pesquisar com outro termo ou limpe o campo de busca.'
                  : 'Inicie um novo estudo mapeando um telhado via satélite para um cliente ou proposta.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
            if (!isQuerying) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _startNewStudy,
                icon: const Icon(Icons.satellite_alt_rounded, size: 18),
                label: Text(
                  'CRIAR PRIMEIRO ESTUDO',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Badge indicador do modo do estudo (Maps, Drone ou Ambos)
  Widget _buildStudyModeBadge(RoofStudyModel study, {required bool isDark}) {
    if (study.hasBothStudies) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF6366F1).withValues(alpha: 0.2)
              : const Color(0xFFEEF2FF),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isDark ? const Color(0xFF818CF8) : const Color(0xFFC7D2FE),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.satellite_alt_rounded, size: 11, color: Color(0xFFF59E0B)),
            const SizedBox(width: 2),
            Text('+',
                style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF6366F1))),
            const SizedBox(width: 2),
            const Icon(Icons.camera_alt_rounded, size: 11, color: Color(0xFF0284C7)),
            const SizedBox(width: 4),
            Text(
              'Maps + Drone',
              style: GoogleFonts.inter(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFFC7D2FE) : const Color(0xFF4338CA),
              ),
            ),
          ],
        ),
      );
    }

    if (study.hasDroneStudy) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF0284C7).withValues(alpha: 0.2)
              : const Color(0xFFE0F2FE),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isDark ? const Color(0xFF38BDF8) : const Color(0xFFBAE6FD),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.camera_alt_rounded, size: 11, color: Color(0xFF0284C7)),
            const SizedBox(width: 4),
            Text(
              'Drone',
              style: GoogleFonts.inter(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFFBAE6FD) : const Color(0xFF0369A1),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFFD97706).withValues(alpha: 0.15)
            : const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark ? const Color(0xFFF59E0B) : const Color(0xFFFDE68A),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.satellite_alt_rounded, size: 11, color: Color(0xFFD97706)),
          const SizedBox(width: 4),
          Text(
            'Maps',
            style: GoogleFonts.inter(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309),
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiData {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final List<Color> bgGradient;

  _KpiData({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.bgGradient,
  });
}
