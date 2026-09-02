import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../app/theme/app_colors.dart';
import '../../domain/models/proposal_model.dart';

/// Visualização Interativa em Colunas KANBAN para Propostas Comerciais
class ProposalKanbanView extends StatefulWidget {
  final List<ProposalModel> proposals;
  final VoidCallback onAddNew;
  final ValueChanged<ProposalModel> onEdit;
  final ValueChanged<ProposalModel> onPreviewWeb;
  final ValueChanged<ProposalModel> onCopyLink;
  final ValueChanged<ProposalModel> onWhatsApp;
  final ValueChanged<ProposalModel> onPreviewPdf;
  final ValueChanged<ProposalModel> onDelete;
  final void Function(ProposalModel proposal, ProposalStatus newStatus) onStatusChange;

  const ProposalKanbanView({
    super.key,
    required this.proposals,
    required this.onAddNew,
    required this.onEdit,
    required this.onPreviewWeb,
    required this.onCopyLink,
    required this.onWhatsApp,
    required this.onPreviewPdf,
    required this.onDelete,
    required this.onStatusChange,
  });

  @override
  State<ProposalKanbanView> createState() => _ProposalKanbanViewState();
}

class _ProposalKanbanViewState extends State<ProposalKanbanView> {
  final _currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  ProposalStatus? _hoveredColumn;

  // As 4 colunas oficiais do Kanban
  static const List<ProposalStatus> _kanbanStatuses = [
    ProposalStatus.inApproval,
    ProposalStatus.negotiating,
    ProposalStatus.closed,
    ProposalStatus.rejected,
  ];

  @override
  Widget build(BuildContext context) {
    // Agrupamento de propostas por status
    final Map<ProposalStatus, List<ProposalModel>> grouped = {
      for (var s in _kanbanStatuses) s: [],
    };

    double totalPipelineAmount = 0.0;
    for (var p in widget.proposals) {
      grouped[p.status]?.add(p);
      totalPipelineAmount += p.totalAmount;
    }

    final isMobile = MediaQuery.of(context).size.width < 768;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── BARRA RESUMO EXECUTIVO DO PIPELINE ────────────────────────────
        _buildPipelineSummaryBar(grouped, totalPipelineAmount, isMobile),

        const SizedBox(height: 14),

        // ── COLUNAS KANBAN COM DRAG & DROP ────────────────────────────────
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columnWidth = (constraints.maxWidth > 1200)
                  ? (constraints.maxWidth - (3 * 16)) / 4
                  : 320.0;

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: SizedBox(
                  height: constraints.maxHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _kanbanStatuses.map((status) {
                      final items = grouped[status] ?? [];
                      return Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: SizedBox(
                          width: columnWidth,
                          child: _buildKanbanColumn(status, items),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── RESUMO EXECUTIVO DO PIPELINE ──────────────────────────────────────────
  Widget _buildPipelineSummaryBar(
    Map<ProposalStatus, List<ProposalModel>> grouped,
    double totalAmount,
    bool isMobile,
  ) {
    final closedCount = grouped[ProposalStatus.closed]?.length ?? 0;
    final totalCount = widget.proposals.length;
    final winRate = totalCount > 0 ? (closedCount / totalCount) * 100 : 0.0;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 18,
        vertical: isMobile ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: isMobile
          ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _summaryPill(
                    icon: Icons.monetization_on_outlined,
                    color: const Color(0xFF6366F1),
                    label: 'Pipeline Total',
                    value: _currencyFormat.format(totalAmount),
                  ),
                  const SizedBox(width: 12),
                  _summaryPill(
                    icon: Icons.analytics_outlined,
                    color: const Color(0xFF0284C7),
                    label: 'Propostas',
                    value: '$totalCount',
                  ),
                  const SizedBox(width: 12),
                  _summaryPill(
                    icon: Icons.verified_outlined,
                    color: const Color(0xFF059669),
                    label: 'Conversão',
                    value: '${winRate.toStringAsFixed(1)}%',
                  ),
                ],
              ),
            )
          : Row(
              children: [
                _summaryPill(
                  icon: Icons.monetization_on_outlined,
                  color: const Color(0xFF6366F1),
                  label: 'Pipeline Total',
                  value: _currencyFormat.format(totalAmount),
                ),
                const SizedBox(width: 16),
                _summaryPill(
                  icon: Icons.analytics_outlined,
                  color: const Color(0xFF0284C7),
                  label: 'Total de Propostas',
                  value: '$totalCount ${totalCount == 1 ? 'proposta' : 'propostas'}',
                ),
                const SizedBox(width: 16),
                _summaryPill(
                  icon: Icons.verified_outlined,
                  color: const Color(0xFF059669),
                  label: 'Taxa de Conversão',
                  value: '${winRate.toStringAsFixed(1)}% fechadas',
                ),
                const Spacer(),
                Text(
                  '💡 Arraste os cards entre as colunas para atualizar a etapa',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF94A3B8),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _summaryPill({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 17, color: color),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── COLUNA INDIVIDUAL DO KANBAN COM DRAG TARGET ───────────────────────────
  Widget _buildKanbanColumn(ProposalStatus status, List<ProposalModel> items) {
    final isHovered = _hoveredColumn == status;
    final columnTotal = items.fold<double>(0.0, (acc, p) => acc + p.totalAmount);

    return DragTarget<ProposalModel>(
      onWillAcceptWithDetails: (details) {
        setState(() => _hoveredColumn = status);
        return true;
      },
      onLeave: (_) {
        setState(() => _hoveredColumn = null);
      },
      onAcceptWithDetails: (details) {
        final dropped = details.data;
        setState(() => _hoveredColumn = null);
        if (dropped.status != status) {
          widget.onStatusChange(dropped, status);
        }
      },
      builder: (context, candidateData, rejectedData) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isHovered
                ? status.bgColor.withValues(alpha: 0.6)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isHovered ? status.textColor : const Color(0xFFE2E8F0),
              width: isHovered ? 2 : 1,
            ),
            boxShadow: isHovered
                ? [
                    BoxShadow(
                      color: status.textColor.withValues(alpha: 0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.01),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
          ),
          child: Column(
            children: [
              // Cabeçalho da Coluna
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                  border: Border(
                    bottom: BorderSide(
                      color: isHovered
                          ? status.textColor.withValues(alpha: 0.3)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: status.bgColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(status.icon, size: 16, color: status.textColor),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            status.label.toUpperCase(),
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 0.5,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: status.bgColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${items.length}',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: status.textColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Soma da etapa:',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                        Text(
                          _currencyFormat.format(columnTotal),
                          style: GoogleFonts.outfit(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: status.textColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Área de Drop Interativa / Indicador de Hover
              if (isHovered)
                Container(
                  margin: const EdgeInsets.all(10),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: status.textColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: status.textColor.withValues(alpha: 0.4),
                      style: BorderStyle.solid,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.arrow_downward_rounded,
                            size: 16, color: status.textColor),
                        const SizedBox(width: 6),
                        Text(
                          'Soltar para mover para ${status.label}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: status.textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Lista de Cards com Scroll Independente
              Expanded(
                child: items.isEmpty
                    ? _buildEmptyColumnState(status)
                    : ListView.builder(
                        padding: const EdgeInsets.all(10),
                        itemCount: items.length,
                        physics: const BouncingScrollPhysics(),
                        itemBuilder: (context, index) {
                          final proposal = items[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _buildDraggableCard(proposal),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── ESTADO VAZIO DA COLUNA ───────────────────────────────────────────────
  Widget _buildEmptyColumnState(ProposalStatus status) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Icon(status.icon, size: 22, color: const Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 10),
            Text(
              'Nenhuma proposta',
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Arraste propostas para cá',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── CARD DRAGGABLE DO KANBAN ─────────────────────────────────────────────
  Widget _buildDraggableCard(ProposalModel proposal) {
    final cardWidget = _KanbanCard(
      proposal: proposal,
      currencyFormat: _currencyFormat,
      onEdit: () => widget.onEdit(proposal),
      onPreviewWeb: () => widget.onPreviewWeb(proposal),
      onCopyLink: () => widget.onCopyLink(proposal),
      onWhatsApp: () => widget.onWhatsApp(proposal),
      onPreviewPdf: () => widget.onPreviewPdf(proposal),
      onDelete: () => widget.onDelete(proposal),
      onStatusChange: (newStatus) => widget.onStatusChange(proposal, newStatus),
    );

    return Draggable<ProposalModel>(
      data: proposal,
      // Card fantasma exibido enquanto arrasta
      feedback: Material(
        elevation: 14,
        borderRadius: BorderRadius.circular(14),
        color: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        child: Transform.rotate(
          angle: -0.02,
          child: SizedBox(
            width: 300,
            child: _KanbanCard(
              proposal: proposal,
              currencyFormat: _currencyFormat,
              isDragging: true,
              onEdit: () {},
              onPreviewWeb: () {},
              onCopyLink: () {},
              onWhatsApp: () {},
              onPreviewPdf: () {},
              onDelete: () {},
              onStatusChange: (_) {},
            ),
          ),
        ),
      ),
      // Espaço reservado enquanto o card original está no ar
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFF94A3B8),
              style: BorderStyle.solid,
            ),
          ),
          child: cardWidget,
        ),
      ),
      child: cardWidget,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD INDIVIDUAL KANBAN (UI & AÇÕES RÁPIDAS)
// ─────────────────────────────────────────────────────────────────────────────
class _KanbanCard extends StatefulWidget {
  final ProposalModel proposal;
  final NumberFormat currencyFormat;
  final bool isDragging;
  final VoidCallback onEdit;
  final VoidCallback onPreviewWeb;
  final VoidCallback onCopyLink;
  final VoidCallback onWhatsApp;
  final VoidCallback onPreviewPdf;
  final VoidCallback onDelete;
  final ValueChanged<ProposalStatus> onStatusChange;

  const _KanbanCard({
    required this.proposal,
    required this.currencyFormat,
    this.isDragging = false,
    required this.onEdit,
    required this.onPreviewWeb,
    required this.onCopyLink,
    required this.onWhatsApp,
    required this.onPreviewPdf,
    required this.onDelete,
    required this.onStatusChange,
  });

  @override
  State<_KanbanCard> createState() => _KanbanCardState();
}

class _KanbanCardState extends State<_KanbanCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.proposal;
    final themeColor = Color(p.themeColorValue);
    final hasSolar = p.items.any((i) => i.isSolarPlant);

    // Calcular kWp total se houver usina solar
    double totalKwp = 0.0;
    for (var item in p.items) {
      if (item.isSolarPlant && item.solarPowerKwp != null) {
        totalKwp += item.solarPowerKwp!;
      }
    }

    return MouseRegion(
      cursor: SystemMouseCursors.grab,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _isHovered ? themeColor : AppColors.border,
            width: _isHovered ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: _isHovered
                  ? themeColor.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.03),
              blurRadius: _isHovered ? 12 : 6,
              offset: Offset(0, _isHovered ? 4 : 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onEdit,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Linha Superior: Código da Proposta + Drag Handle
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.tag_rounded, size: 11, color: const Color(0xFF64748B)),
                            const SizedBox(width: 2),
                            Text(
                              p.proposalNumber,
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // Ícone de Drag
                      Icon(
                        Icons.drag_indicator_rounded,
                        size: 16,
                        color: _isHovered ? const Color(0xFF64748B) : const Color(0xFFCBD5E1),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Título da Proposta
                  Text(
                    p.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: const Color(0xFF0F172A),
                      height: 1.25,
                    ),
                  ),

                  const SizedBox(height: 4),

                  // Nome do Cliente com Ícone
                  Row(
                    children: [
                      const Icon(Icons.person_outline_rounded,
                          size: 14, color: Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          p.clientName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Badges: Usina Solar ou Qtd de Itens
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (hasSolar)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.solar_power_rounded,
                                  size: 11, color: Color(0xFFD97706)),
                              const SizedBox(width: 3),
                              Text(
                                totalKwp > 0
                                    ? 'Usina ${totalKwp.toStringAsFixed(2)} kWp'
                                    : 'Usina Solar',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF92400E),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          '${p.items.length} ${p.items.length == 1 ? 'item' : 'itens'}',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (p.createdByUserName != null && p.createdByUserName!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.person_pin_rounded,
                                  size: 11, color: Color(0xFF2563EB)),
                              const SizedBox(width: 3),
                              Text(
                                p.createdByUserName!,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF1D4ED8),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Valor Total Destacado
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        'Total:',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                      Text(
                        widget.currencyFormat.format(p.totalAmount),
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),
                  const Divider(height: 1, color: AppColors.divider),
                  const SizedBox(height: 6),

                  // Barra de Ações Rápidas do Card
                  Row(
                    children: [
                      // Data / Validade
                      Text(
                        'Validade: ${p.validityDays}d',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                      const Spacer(),
                      _actionIcon(
                        icon: Icons.language_rounded,
                        tooltip: 'Visualizar Proposta Web',
                        color: const Color(0xFF059669),
                        onTap: widget.onPreviewWeb,
                      ),
                      _actionIcon(
                        icon: Icons.link_rounded,
                        tooltip: 'Copiar Link da Proposta',
                        color: const Color(0xFF0284C7),
                        onTap: widget.onCopyLink,
                      ),
                      _actionIcon(
                        icon: Icons.chat_bubble_outline_rounded,
                        tooltip: 'Enviar via WhatsApp',
                        color: const Color(0xFF25D366),
                        onTap: widget.onWhatsApp,
                      ),
                      _actionIcon(
                        icon: Icons.picture_as_pdf_outlined,
                        tooltip: 'Exportar PDF',
                        color: const Color(0xFFDC2626),
                        onTap: widget.onPreviewPdf,
                      ),
                      _actionIcon(
                        icon: Icons.edit_outlined,
                        tooltip: 'Editar Proposta',
                        color: const Color(0xFF6366F1),
                        onTap: widget.onEdit,
                      ),
                      // Menu de Status Rápido
                      PopupMenuButton<ProposalStatus>(
                        tooltip: 'Mudar Etapa / Status',
                        icon: const Icon(Icons.swap_horiz_rounded,
                            size: 17, color: Color(0xFF64748B)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                        onSelected: widget.onStatusChange,
                        itemBuilder: (ctx) => ProposalStatus.values.map((s) {
                          final isCurrent = s == p.status;
                          return PopupMenuItem(
                            value: s,
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: s.textColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  s.label,
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    fontWeight: isCurrent
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isCurrent
                                        ? s.textColor
                                        : const Color(0xFF0F172A),
                                  ),
                                ),
                                if (isCurrent) ...[
                                  const Spacer(),
                                  Icon(Icons.check_rounded, size: 14, color: s.textColor),
                                ],
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      _actionIcon(
                        icon: Icons.delete_outline_rounded,
                        tooltip: 'Excluir Proposta',
                        color: const Color(0xFFEF4444),
                        onTap: widget.onDelete,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionIcon({
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback onTap,
  }) {
    return IconButton(
      icon: Icon(icon, size: 16, color: color),
      tooltip: tooltip,
      onPressed: onTap,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
      visualDensity: VisualDensity.compact,
    );
  }
}
