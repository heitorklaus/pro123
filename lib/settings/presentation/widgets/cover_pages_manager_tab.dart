import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/services/solar_settings_service.dart';
import '../../domain/models/proposal_pages_models.dart';
import '../../domain/models/solar_settings_model.dart';
import 'cover_header_footer_widgets.dart';

/// Aba "Páginas": Gerenciamento multipáginas, mini-previews, 20 templates de Página 2,
/// 20 presets de páginas internas, editor de portfólio da Página 3 e banco com 30 imagens curadas.
class CoverPagesManagerTab extends StatefulWidget {
  final bool isSolar;
  final String
      activePageId; // 'page_1', 'page_2', 'page_3', 'page_4', 'page_5', ou 'custom_...'
  final ValueChanged<String> onSelectPage;
  final List<String> hiddenPageIds;
  final ValueChanged<List<String>> onUpdateHiddenPages;
  final List<ProposalCustomPage> customPages;
  final ValueChanged<List<ProposalCustomPage>> onUpdateCustomPages;
  final List<ProposalPageCard> page2Cards;
  final ValueChanged<List<ProposalPageCard>> onUpdatePage2Cards;
  final String selectedPage2TemplateId;
  final ValueChanged<ProposalPage2TemplateInfo> onSelectPage2Template;
  final String selectedInternalPresetId;
  final ValueChanged<InternalPagesLayoutPreset> onSelectInternalPreset;
  final bool page2ShowIllustration;
  final ValueChanged<bool> onTogglePage2Illustration;
  final String page2IllustrationType; // 'banner', 'isometric', 'photo', 'none'
  final ValueChanged<String> onSelectPage2IllustrationType;
  final ValueChanged<CuratedProposalImage>? onSelectImageFromBank;
  final Color primaryColor;

  // Customização de Portfólio & Clientes da Página 3
  final String page3Title;
  final ValueChanged<String>? onUpdatePage3Title;
  final String page3Subtitle;
  final ValueChanged<String>? onUpdatePage3Subtitle;
  final List<AutomationPortfolioItem> page3PortfolioItems;
  final ValueChanged<List<AutomationPortfolioItem>>?
      onUpdatePage3PortfolioItems;
  final String page3BgColor;
  final ValueChanged<String>? onUpdatePage3BgColor;
  final String page3CardBgColor;
  final ValueChanged<String>? onUpdatePage3CardBgColor;
  final String page3BorderColor;
  final ValueChanged<String>? onUpdatePage3BorderColor;
  final String page3TitleColor;
  final ValueChanged<String>? onUpdatePage3TitleColor;
  final String page3SubtitleColor;
  final ValueChanged<String>? onUpdatePage3SubtitleColor;
  final String page3AccentColor;
  final ValueChanged<String>? onUpdatePage3AccentColor;
  final VoidCallback? onResetPage3Items;

  // Customização de Cores da Página 4 (Ambientes & Equipamentos)
  final String page4BgColor;
  final ValueChanged<String>? onUpdatePage4BgColor;
  final String page4CardBgColor;
  final ValueChanged<String>? onUpdatePage4CardBgColor;
  final String page4BorderColor;
  final ValueChanged<String>? onUpdatePage4BorderColor;
  final String page4TitleColor;
  final ValueChanged<String>? onUpdatePage4TitleColor;
  final String page4SubtitleColor;
  final ValueChanged<String>? onUpdatePage4SubtitleColor;
  final String page4AccentColor;
  final ValueChanged<String>? onUpdatePage4AccentColor;
  final VoidCallback? onResetPage4Colors;

  // Portfólio Solar (Página 2 opcional após a capa)
  final bool showSolarPortfolio;
  final ValueChanged<bool>? onToggleSolarPortfolio;
  final String solarPortfolioTitle;
  final ValueChanged<String>? onSolarPortfolioTitleChanged;
  final String solarPortfolioSubtitle;
  final ValueChanged<String>? onSolarPortfolioSubtitleChanged;
  final String solarPortfolioFooterNote;
  final ValueChanged<String>? onSolarPortfolioFooterNoteChanged;
  final List<SolarPortfolioItem> solarPortfolioItems;
  final ValueChanged<List<SolarPortfolioItem>>? onUpdateSolarPortfolioItems;
  final List<String> pageOrder;
  final ValueChanged<List<String>>? onUpdatePageOrder;

  const CoverPagesManagerTab({
    super.key,
    required this.isSolar,
    required this.activePageId,
    required this.onSelectPage,
    required this.hiddenPageIds,
    required this.onUpdateHiddenPages,
    required this.customPages,
    required this.onUpdateCustomPages,
    required this.page2Cards,
    required this.onUpdatePage2Cards,
    required this.selectedPage2TemplateId,
    required this.onSelectPage2Template,
    required this.selectedInternalPresetId,
    required this.onSelectInternalPreset,
    required this.page2ShowIllustration,
    required this.onTogglePage2Illustration,
    required this.page2IllustrationType,
    required this.onSelectPage2IllustrationType,
    this.onSelectImageFromBank,
    required this.primaryColor,
    this.page3Title = 'PORTFÓLIO & CLIENTES',
    this.onUpdatePage3Title,
    this.page3Subtitle =
        'Projetos executados com excelência e tecnologia de ponta',
    this.onUpdatePage3Subtitle,
    this.page3PortfolioItems = const [],
    this.onUpdatePage3PortfolioItems,
    this.page3BgColor = '#0B132B',
    this.onUpdatePage3BgColor,
    this.page3CardBgColor = '#111C38',
    this.onUpdatePage3CardBgColor,
    this.page3BorderColor = '#38BDF8',
    this.onUpdatePage3BorderColor,
    this.page3TitleColor = '#FFFFFF',
    this.onUpdatePage3TitleColor,
    this.page3SubtitleColor = '#94A3B8',
    this.onUpdatePage3SubtitleColor,
    this.page3AccentColor = '#38BDF8',
    this.onUpdatePage3AccentColor,
    this.onResetPage3Items,
    this.page4BgColor = '#0B132B',
    this.onUpdatePage4BgColor,
    this.page4CardBgColor = '#111C38',
    this.onUpdatePage4CardBgColor,
    this.page4BorderColor = '#00E5FF',
    this.onUpdatePage4BorderColor,
    this.page4TitleColor = '#FFFFFF',
    this.onUpdatePage4TitleColor,
    this.page4SubtitleColor = '#94A3B8',
    this.onUpdatePage4SubtitleColor,
    this.page4AccentColor = '#00E5FF',
    this.onUpdatePage4AccentColor,
    this.onResetPage4Colors,
    this.showSolarPortfolio = false,
    this.onToggleSolarPortfolio,
    this.solarPortfolioTitle = 'Portfólio de clientes',
    this.onSolarPortfolioTitleChanged,
    this.solarPortfolioSubtitle = 'Instalações residenciais, comerciais e rurais',
    this.onSolarPortfolioSubtitleChanged,
    this.solarPortfolioFooterNote = 'Projetos executados com engenharia própria e homologação completa.',
    this.onSolarPortfolioFooterNoteChanged,
    this.solarPortfolioItems = const [],
    this.onUpdateSolarPortfolioItems,
    this.pageOrder = const [],
    this.onUpdatePageOrder,
  });

  @override
  State<CoverPagesManagerTab> createState() => _CoverPagesManagerTabState();
}

class _CoverPagesManagerTabState extends State<CoverPagesManagerTab> {
  int _currentSection =
      0; // 0: Todas as Páginas, 1: Editar Pág 2, 2: Editar Pág 3, 3: Editar Pág 4
  bool _showPage2Templates = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Sub-menu horizontal limpo e intuitivo
        _buildSubNavBar(),

        // Conteúdo da seção ativa
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: _buildActiveSection(),
          ),
        ),
      ],
    );
  }

  Widget _buildSubNavBar() {
    final isEditingSubPage = _currentSection != 0;
    String editingLabel = '';
    if (_currentSection == 1) {
      editingLabel = 'Página 2 (Editando)';
    } else if (_currentSection == 2) {
      editingLabel = 'Portfólio & Clientes (Editando)';
    } else if (_currentSection == 3) {
      editingLabel = 'Ambientes & Cards (Editando)';
    } else if (_currentSection == 4) {
      editingLabel = 'Portfólio Solar (Editando)';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(bottom: BorderSide(color: Color(0xFF334155))),
      ),
      child: Row(
        children: [
          // Botão TODAS PÁGINAS (sempre presente para voltar à visão geral quando estiver editando qualquer página)
          InkWell(
            onTap: isEditingSubPage
                ? () => setState(() => _currentSection = 0)
                : null,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: !isEditingSubPage
                    ? const Color(0xFF0284C7)
                    : const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: !isEditingSubPage
                      ? const Color(0xFF38BDF8)
                      : const Color(0xFF38BDF8).withValues(alpha: 0.6),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isEditingSubPage
                        ? Icons.arrow_back_rounded
                        : Icons.auto_stories_rounded,
                    size: 15,
                    color: !isEditingSubPage
                        ? Colors.white
                        : const Color(0xFF38BDF8),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isEditingSubPage
                        ? '← Voltar a Todas as Páginas'
                        : 'Todas Páginas',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight:
                          !isEditingSubPage ? FontWeight.bold : FontWeight.w600,
                      color: !isEditingSubPage
                          ? Colors.white
                          : const Color(0xFF38BDF8),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Pílula indicando a página atualmente em edição com botão de fechar
          if (isEditingSubPage) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFF0C4A6E),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF38BDF8), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.edit_note_rounded,
                      size: 15, color: Color(0xFF38BDF8)),
                  const SizedBox(width: 6),
                  Text(
                    editingLabel,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () => setState(() => _currentSection = 0),
                    child: const Icon(Icons.close_rounded,
                        size: 15, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActiveSection() {
    switch (_currentSection) {
      case 0:
        return _buildAllPagesOverview();
      case 1:
        return _buildPage2EditorSection();
      case 2:
        return _buildPage3PortfolioEditor();
      case 3:
        return _buildPage4EditorSection();
      case 4:
        return _buildSolarPortfolioEditorSection();
      default:
        return _buildAllPagesOverview();
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // SEÇÃO 0: TODAS AS PÁGINAS (VISÃO GERAL, ORDEM, EXCLUIR E ADICIONAR NOVA)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildAllPagesOverview() {
    // Lista base de páginas padrão
    final standardPages = [
      {
        'id': 'page_1',
        'number': 1,
        'title': 'Página 1: Capa Oficial',
        'subtitle': widget.isSolar
            ? 'Capa executiva, logo, foto da usina e dados da proposta solar'
            : 'Capa holográfica, logo, título e nós de tecnologia',
        'icon': Icons.branding_watermark_rounded,
        'canDelete': false,
      },
      {
        'id': 'page_2',
        'number': 2,
        'title': 'Página 2: Escopo & Diferenciais',
        'subtitle': widget.isSolar
            ? 'Componentes da usina, tecnologia dos módulos e diferenciais'
            : 'Cards de tecnologia, conforto, segurança e ilustração',
        'icon': Icons.grid_view_rounded,
        'canDelete': true,
      },
      {
        'id': 'page_3',
        'number': 3,
        'title': 'Página 3: Portfólio e Clientes',
        'subtitle': widget.isSolar
            ? 'Usinas instaladas, homologação e histórico de clientes'
            : 'Cases de sucesso, obras entregues e especificações técnicas',
        'icon': Icons.photo_library_rounded,
        'canDelete': true,
      },
      {
        'id': 'page_4',
        'number': 4,
        'title': widget.isSolar
            ? 'Página 4: Detalhamento do Sistema Fotovoltaico'
            : 'Página 4: Detalhamento de Ambientes & Equipamentos',
        'subtitle': widget.isSolar
            ? 'Módulos, inversores, proteções e ficha técnica completa'
            : 'Cards visuais dos ambientes com cores e layout da proposta web',
        'icon': Icons.list_alt_rounded,
        'canDelete': true,
      },
      {
        'id': 'page_5',
        'number': 5,
        'title': 'Página 5: Resumo Financeiro & Garantias',
        'subtitle': widget.isSolar
            ? 'Economia prevista, payback, mão de obra e termos de garantia'
            : 'Valores, mão de obra, termos e validade jurídica',
        'icon': Icons.payments_rounded,
        'canDelete': true,
      },
    ];

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
                  'Estrutura do Documento da Proposta',
                  style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                Text(
                  'Selecione uma página para inspecionar, oculte páginas ou adicione novas.',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: const Color(0xFF94A3B8)),
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: _addNewCustomPage,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('+ NOVA PÁGINA'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Lista de Páginas Padrão
        if (widget.isSolar && widget.onUpdatePageOrder != null)
          ..._buildSolarReorderablePagesList()
        else
        ...standardPages.map((p) {
          final pageId = p['id'] as String;
          final isHidden = widget.hiddenPageIds.contains(pageId);
          final isSelected = widget.activePageId == pageId;
          final canDelete = p['canDelete'] as bool;

          final card = Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF0C4A6E)
                  : const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF38BDF8)
                    : isHidden
                        ? const Color(0xFF475569).withValues(alpha: 0.5)
                        : const Color(0xFF334155),
                width: isSelected ? 1.8 : 1,
              ),
            ),
            child: ListTile(
              onTap: () => widget.onSelectPage(pageId),
              leading: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isHidden
                      ? const Color(0xFF334155)
                      : const Color(0xFF1E293B),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: isSelected
                          ? const Color(0xFF38BDF8)
                          : const Color(0xFF475569)),
                ),
                child: Center(
                  child: Text(
                    '${p['number']}',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isHidden ? const Color(0xFF94A3B8) : Colors.white,
                    ),
                  ),
                ),
              ),
              title: Row(
                children: [
                  Text(
                    p['title'] as String,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isHidden ? const Color(0xFF94A3B8) : Colors.white,
                      decoration: isHidden ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (pageId == 'page_2')
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: const Color(0xFF0284C7), width: 0.8),
                      ),
                      child: Text(
                        'EDITÁVEL',
                        style: GoogleFonts.inter(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF38BDF8)),
                      ),
                    ),
                  if (pageId == 'page_3' && !widget.isSolar)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: const Color(0xFF10B981), width: 0.8),
                      ),
                      child: Text(
                        'PORTFÓLIO & CASES',
                        style: GoogleFonts.inter(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF34D399)),
                      ),
                    ),
                  if (pageId == 'page_4' && !widget.isSolar)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: const Color(0xFF00E5FF), width: 0.8),
                      ),
                      child: Text(
                        'CARDS & CORES',
                        style: GoogleFonts.inter(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF00E5FF)),
                      ),
                    ),
                  if (isHidden)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'REMOVIDA DO PDF',
                        style: GoogleFonts.inter(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFF87171)),
                      ),
                    ),
                ],
              ),
              subtitle: Text(
                p['subtitle'] as String,
                style: GoogleFonts.inter(
                    fontSize: 11, color: const Color(0xFF94A3B8)),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (pageId == 'page_2')
                    IconButton(
                      tooltip: 'Editar Conteúdo da Página 2',
                      icon: const Icon(Icons.edit_note_rounded,
                          color: Color(0xFF38BDF8), size: 22),
                      onPressed: () {
                        widget.onSelectPage('page_2');
                        setState(() => _currentSection = 1);
                      },
                    ),
                  if (pageId == 'page_3' && !widget.isSolar)
                    IconButton(
                      tooltip: 'Personalizar Portfólio & Clientes da Página 3',
                      icon: const Icon(Icons.photo_library_outlined,
                          color: Color(0xFF34D399), size: 22),
                      onPressed: () {
                        widget.onSelectPage('page_3');
                        setState(() => _currentSection = 2);
                      },
                    ),
                  if (pageId == 'page_4' && !widget.isSolar)
                    IconButton(
                      tooltip: 'Personalizar Estilo & Cards da Página 4',
                      icon: const Icon(Icons.tune_rounded,
                          color: Color(0xFF00E5FF), size: 22),
                      onPressed: () {
                        widget.onSelectPage('page_4');
                        setState(() => _currentSection = 3);
                      },
                    ),
                  if (canDelete)
                    IconButton(
                      tooltip: isHidden
                          ? 'Restaurar Página no PDF'
                          : 'Remover Página do PDF',
                      icon: Icon(
                        isHidden
                            ? Icons.visibility_off_rounded
                            : Icons.delete_outline_rounded,
                        color: isHidden
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFFEF4444),
                        size: 20,
                      ),
                      onPressed: () => _toggleHidePage(pageId),
                    ),
                ],
              ),
            ),
          );
          if (widget.isSolar && pageId == 'page_1') {
            return Column(
              children: [
                card,
                _buildSolarPortfolioOverviewCard(),
              ],
            );
          }
          return card;
        }),

        // Páginas Personalizadas Adicionadas pelo Usuário
        if (!(widget.isSolar && widget.onUpdatePageOrder != null) &&
            widget.customPages.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Páginas Personalizadas Criadas (${widget.customPages.length})',
            style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF10B981)),
          ),
          const SizedBox(height: 8),
          ...widget.customPages.asMap().entries.map((entry) {
            final idx = entry.key;
            final cp = entry.value;
            final pageId = cp.id;
            final isSelected = widget.activePageId == pageId;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF064E3B)
                    : const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF10B981)
                      : const Color(0xFF334155),
                  width: isSelected ? 1.8 : 1,
                ),
              ),
              child: ListTile(
                onTap: () => widget.onSelectPage(pageId),
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF10B981)),
                  ),
                  child: Center(
                    child: Text(
                      'P${idx + 6}',
                      style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF10B981)),
                    ),
                  ),
                ),
                title: Text(
                  cp.title,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                subtitle: Text(
                  '${cp.cards.length} cards inseridos • Fundo: ${cp.bgType}',
                  style: GoogleFonts.inter(
                      fontSize: 11, color: const Color(0xFF94A3B8)),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Editar Página',
                      icon: const Icon(Icons.edit_rounded,
                          color: Color(0xFF10B981), size: 18),
                      onPressed: () => widget.onSelectPage(pageId),
                    ),
                    IconButton(
                      tooltip: 'Excluir Página',
                      icon: const Icon(Icons.delete_forever_rounded,
                          color: Color(0xFFEF4444), size: 20),
                      onPressed: () => _removeCustomPage(cp.id),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  void _toggleHidePage(String pageId) {
    final list = List<String>.from(widget.hiddenPageIds);
    if (list.contains(pageId)) {
      list.remove(pageId);
    } else {
      list.add(pageId);
    }
    widget.onUpdateHiddenPages(list);
  }

  void _addNewCustomPage() {
    final newId = 'custom_${DateTime.now().millisecondsSinceEpoch}';
    final newPage = ProposalCustomPage(
      id: newId,
      title: 'Página Personalizada ${widget.customPages.length + 1}',
      cards: [
        ProposalPageCard(
          id: 'card_${DateTime.now().millisecondsSinceEpoch}_1',
          title: 'Título do Card 1',
          description:
              'Descrição detalhada dos serviços ou diferenciais inseridos nesta página.',
          iconKey: widget.isSolar ? 'solar_power' : 'lightbulb',
          colorHex: '#0284C7',
          order: 0,
        ),
      ],
    );
    final updated = [...widget.customPages, newPage];
    widget.onUpdateCustomPages(updated);
    widget.onSelectPage(newId);
  }

  void _removeCustomPage(String id) {
    final updated = widget.customPages.where((p) => p.id != id).toList();
    widget.onUpdateCustomPages(updated);
    if (widget.activePageId == id) {
      widget.onSelectPage('page_1');
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // SEÇÃO 1: EDITOR DA PÁGINA 2 (CARDS, CORES, ÍCONES E ILUSTRAÇÃO INFERIOR)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildPage2EditorSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => setState(() => _currentSection = 0),
                  icon: const Icon(Icons.arrow_back_rounded, size: 16),
                  label: const Text('Todas Páginas'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF38BDF8),
                    side: const BorderSide(color: Color(0xFF0284C7)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Personalização da Página 2',
                      style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    Text(
                      'Edite textos, ícones, cores e mais',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: const Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: _addNewPage2Card,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('+ NOVO CARD'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── SEÇÃO: 20 TEMPLATES PRONTOS DA PÁGINA 2 (EMBUTIDO NA EDIÇÃO) ──
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: const Color(0xFF0284C7).withValues(alpha: 0.6),
                width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.dashboard_customize_rounded,
                            color: Color(0xFF38BDF8), size: 18),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '20 Templates Prontos da Página 2',
                            style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                          Text(
                            'Escolha um template profissional para reconfigurar os cards com 1 clique',
                            style: GoogleFonts.inter(
                                fontSize: 11, color: const Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  OutlinedButton.icon(
                    onPressed: () => setState(
                        () => _showPage2Templates = !_showPage2Templates),
                    icon: Icon(
                        _showPage2Templates
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: const Color(0xFF38BDF8),
                        size: 18),
                    label: Text(
                      _showPage2Templates
                          ? 'Ocultar Modelos'
                          : 'Ver 20 Modelos',
                      style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF38BDF8)),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF0284C7)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
              if (_showPage2Templates) ...[
                const SizedBox(height: 14),
                _build20Page2TemplatesGrid(),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Bloco de Controle da Ilustração Inferior
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.image_outlined,
                          color: Color(0xFF38BDF8), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Ilustração Tecnológica Inferior',
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                    ],
                  ),
                  Switch(
                    value: widget.page2ShowIllustration,
                    activeThumbColor: const Color(0xFF38BDF8),
                    onChanged: widget.onTogglePage2Illustration,
                  ),
                ],
              ),
              if (widget.page2ShowIllustration) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildIllustrationTypeChip(
                        'cyberDark', 'Infraestrutura Cibernética (Dark)'),
                    _buildIllustrationTypeChip(
                        'blueprint', 'Projeto Técnico (Blueprint)'),
                    _buildIllustrationTypeChip(
                        'luxuryGold', 'Padrão Alta Nobreza (Gold)'),
                    _buildIllustrationTypeChip(
                        'timeline', 'Jornada Turn-Key (Timeline)'),
                    _buildIllustrationTypeChip(
                        'solarFlow', 'Fluxo Solar Fotovoltaico'),
                    _buildIllustrationTypeChip(
                        'iotNetwork', 'Topologia Rede Mesh & IoT'),
                    _buildIllustrationTypeChip(
                        'greenEco', 'Eficiência Verde & CO2'),
                    _buildIllustrationTypeChip(
                        'banner', 'Mansão Conectada (Banner)'),
                    _buildIllustrationTypeChip(
                        'isometric', 'Corte Isométrico Ambientes'),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Lista de Cards da Página 2
        Text(
          'Cards de Apresentação & Escopo (${widget.page2Cards.length})',
          style: GoogleFonts.outfit(
              fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 10),

        ...widget.page2Cards.asMap().entries.map((entry) {
          final idx = entry.key;
          final card = entry.value;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: card.isVisible
                    ? const Color(0xFF334155)
                    : const Color(0xFF334155).withValues(alpha: 0.4),
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
                        color: Color(int.tryParse(
                                    card.colorHex.replaceAll('#', '0xFF')) ??
                                0xFF0284C7)
                            .withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Color(int.tryParse(
                                    card.colorHex.replaceAll('#', '0xFF')) ??
                                0xFF0284C7)),
                      ),
                      child: Center(
                        child: Icon(
                          _getIconData(card.iconKey),
                          size: 16,
                          color: Color(int.tryParse(
                                  card.colorHex.replaceAll('#', '0xFF')) ??
                              0xFF0284C7),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Card ${idx + 1}: ${card.title}',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: card.isVisible
                              ? Colors.white
                              : const Color(0xFF94A3B8),
                          decoration: card.isVisible
                              ? null
                              : TextDecoration.lineThrough,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Mudar Ícone',
                      icon: const Icon(Icons.touch_app_rounded,
                          size: 18, color: Color(0xFFEAB308)),
                      onPressed: () => _showCardIconPicker(idx),
                    ),
                    IconButton(
                      tooltip: card.isVisible ? 'Ocultar Card' : 'Exibir Card',
                      icon: Icon(
                        card.isVisible
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                        size: 18,
                        color: card.isVisible
                            ? const Color(0xFF38BDF8)
                            : const Color(0xFF94A3B8),
                      ),
                      onPressed: () => _toggleCardVisibility(idx),
                    ),
                    IconButton(
                      tooltip: 'Excluir Card',
                      icon: const Icon(Icons.delete_outline_rounded,
                          size: 18, color: Color(0xFFEF4444)),
                      onPressed: () => _removePage2Card(idx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Edição de Título Inline
                TextFormField(
                  initialValue: card.title,
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Título do Card',
                    labelStyle: GoogleFonts.inter(
                        fontSize: 11, color: const Color(0xFF94A3B8)),
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF334155))),
                  ),
                  onChanged: (val) => _updateCardField(idx, title: val),
                ),
                const SizedBox(height: 8),

                // Edição de Descrição Inline
                TextFormField(
                  initialValue: card.description,
                  style: GoogleFonts.inter(
                      fontSize: 11.5, color: const Color(0xFFCBD5E1)),
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Descrição / Texto do Card',
                    labelStyle: GoogleFonts.inter(
                        fontSize: 11, color: const Color(0xFF94A3B8)),
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF334155))),
                  ),
                  onChanged: (val) => _updateCardField(idx, description: val),
                ),
                const SizedBox(height: 8),

                // Seletor de Cores Rápidas do Card
                Row(
                  children: [
                    Text('Cor do Card: ',
                        style: GoogleFonts.inter(
                            fontSize: 11, color: const Color(0xFF94A3B8))),
                    const SizedBox(width: 6),
                    ...[
                      '#0284C7',
                      '#2563EB',
                      '#10B981',
                      '#F59E0B',
                      '#6366F1',
                      '#EF4444',
                      '#0F172A'
                    ].map((hex) {
                      final isSelected =
                          card.colorHex.toUpperCase() == hex.toUpperCase();
                      final cVal = Color(
                          int.tryParse(hex.replaceAll('#', '0xFF')) ??
                              0xFF0284C7);
                      return InkWell(
                        onTap: () => _updateCardField(idx, colorHex: hex),
                        child: Container(
                          margin: const EdgeInsets.only(right: 6),
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: cVal,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(Icons.check,
                                  size: 10, color: Colors.white)
                              : null,
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildIllustrationTypeChip(String type, String label) {
    final isSelected =
        widget.page2IllustrationType.toLowerCase() == type.toLowerCase();
    return InkWell(
      onTap: () => widget.onSelectPage2IllustrationType(type),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: isSelected
                  ? const Color(0xFF38BDF8)
                  : const Color(0xFF475569)),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
          ),
        ),
      ),
    );
  }

  void _addNewPage2Card() {
    final newCard = ProposalPageCard(
      id: 'card_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Novo Diferencial',
      description: 'Descrição do diferencial adicionado à proposta.',
      iconKey: widget.isSolar ? 'solar_power' : 'lightbulb',
      colorHex: '#0284C7',
      order: widget.page2Cards.length,
    );
    widget.onUpdatePage2Cards([...widget.page2Cards, newCard]);
  }

  void _removePage2Card(int index) {
    final list = List<ProposalPageCard>.from(widget.page2Cards);
    if (index >= 0 && index < list.length) {
      list.removeAt(index);
      widget.onUpdatePage2Cards(list);
    }
  }

  void _toggleCardVisibility(int index) {
    final list = List<ProposalPageCard>.from(widget.page2Cards);
    if (index >= 0 && index < list.length) {
      list[index] = list[index].copyWith(isVisible: !list[index].isVisible);
      widget.onUpdatePage2Cards(list);
    }
  }

  void _updateCardField(int index,
      {String? title, String? description, String? colorHex, String? iconKey}) {
    final list = List<ProposalPageCard>.from(widget.page2Cards);
    if (index >= 0 && index < list.length) {
      list[index] = list[index].copyWith(
        title: title,
        description: description,
        colorHex: colorHex,
        iconKey: iconKey,
      );
      widget.onUpdatePage2Cards(list);
    }
  }

  void _showCardIconPicker(int cardIndex) {
    final availableIcons = [
      {
        'key': 'lightbulb',
        'name': 'Lâmpada / Luz',
        'icon': Icons.lightbulb_outline_rounded
      },
      {'key': 'shield', 'name': 'Segurança', 'icon': Icons.shield_outlined},
      {'key': 'eco', 'name': 'Eficiência / Verde', 'icon': Icons.eco_outlined},
      {'key': 'home', 'name': 'Residência', 'icon': Icons.home_outlined},
      {
        'key': 'blueprint',
        'name': 'Engenharia',
        'icon': Icons.architecture_rounded
      },
      {
        'key': 'phone',
        'name': 'Aplicativo / Voz',
        'icon': Icons.smartphone_rounded
      },
      {'key': 'award', 'name': 'Homologação', 'icon': Icons.verified_rounded},
      {
        'key': 'handshake',
        'name': 'Instalação / Suporte',
        'icon': Icons.handshake_outlined
      },
      {
        'key': 'solar_power',
        'name': 'Painel Solar',
        'icon': Icons.solar_power_rounded
      },
      {'key': 'bolt', 'name': 'Energia / Raio', 'icon': Icons.bolt_rounded},
      {
        'key': 'coins',
        'name': 'Economia Financeira',
        'icon': Icons.monetization_on_outlined
      },
      {
        'key': 'chart',
        'name': 'Retorno / Gráfico',
        'icon': Icons.trending_up_rounded
      },
      {'key': 'wifi', 'name': 'Rede Mesh / Wi-Fi', 'icon': Icons.wifi_rounded},
      {
        'key': 'music',
        'name': 'Áudio / Multiroom',
        'icon': Icons.music_note_rounded
      },
      {
        'key': 'thermostat',
        'name': 'Climatização',
        'icon': Icons.thermostat_rounded
      },
      {
        'key': 'camera',
        'name': 'Câmera / CFTV',
        'icon': Icons.videocam_outlined
      },
      {
        'key': 'lock',
        'name': 'Fechadura / Acesso',
        'icon': Icons.lock_outline_rounded
      },
    ];

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF334155))),
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Selecione o Ícone do Card',
                      style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const Divider(color: Color(0xFF334155)),
              const SizedBox(height: 12),
              SizedBox(
                height: 300,
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: availableIcons.length,
                  itemBuilder: (c, i) {
                    final item = availableIcons[i];
                    return InkWell(
                      onTap: () {
                        _updateCardField(cardIndex,
                            iconKey: item['key'] as String);
                        Navigator.pop(ctx);
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(item['icon'] as IconData,
                                color: const Color(0xFF38BDF8), size: 26),
                            const SizedBox(height: 4),
                            Text(
                              item['name'] as String,
                              style: GoogleFonts.inter(
                                  fontSize: 10, color: Colors.white70),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // SEÇÃO 2: OS 20 TEMPLATES PRONTOS DE PÁGINA 2
  // ───────────────────────────────────────────────────────────────────────────
  Widget _build20Page2TemplatesGrid() {
    final templates = ProposalPage2TemplateInfo.getAllTemplates();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Catálogo de 20 Templates para a Página 2',
          style: GoogleFonts.outfit(
              fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        Text(
          'Selecione um template pronto para reconfigurar a disposição dos cards, ícones e ilustrações.',
          style:
              GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.6,
          ),
          itemCount: templates.length,
          itemBuilder: (ctx, idx) {
            final tpl = templates[idx];
            final isSelected = widget.selectedPage2TemplateId == tpl.id;

            return InkWell(
              onTap: () {
                widget.onSelectPage2Template(tpl);
                widget.onSelectPage('page_2');
              },
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF0C4A6E)
                      : const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF38BDF8)
                        : const Color(0xFF334155),
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                              color: const Color(0xFF0284C7)
                                  .withValues(alpha: 0.3),
                              blurRadius: 10)
                        ]
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Color(int.tryParse(tpl.defaultPrimaryColor
                                        .replaceAll('#', '0xFF')) ??
                                    0xFF0284C7)
                                .withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(tpl.icon,
                              color: Color(int.tryParse(tpl.defaultPrimaryColor
                                      .replaceAll('#', '0xFF')) ??
                                  0xFF0284C7),
                              size: 18),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            tpl.title,
                            style: GoogleFonts.outfit(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? const Color(0xFF38BDF8)
                                  : Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle_rounded,
                              color: Color(0xFF38BDF8), size: 16),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tpl.description,
                      style: GoogleFonts.inter(
                          fontSize: 10.5,
                          color: const Color(0xFF94A3B8),
                          height: 1.25),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            tpl.category.toUpperCase(),
                            style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFCBD5E1)),
                          ),
                        ),
                        Text(
                          isSelected ? 'APLICADO' : 'APLICAR ->',
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? const Color(0xFF38BDF8)
                                : const Color(0xFF0284C7),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  IconData _getIconData(String key) {
    switch (key.toLowerCase()) {
      case 'lightbulb':
      case 'light':
        return Icons.lightbulb_outline_rounded;
      case 'shield':
        return Icons.shield_outlined;
      case 'eco':
        return Icons.eco_outlined;
      case 'home':
        return Icons.home_outlined;
      case 'blueprint':
      case 'engineering':
        return Icons.architecture_rounded;
      case 'phone':
        return Icons.smartphone_rounded;
      case 'award':
        return Icons.verified_rounded;
      case 'handshake':
        return Icons.handshake_outlined;
      case 'solar_power':
        return Icons.solar_power_rounded;
      case 'bolt':
        return Icons.bolt_rounded;
      case 'coins':
        return Icons.monetization_on_outlined;
      case 'chart':
        return Icons.trending_up_rounded;
      case 'wifi':
        return Icons.wifi_rounded;
      case 'music':
        return Icons.music_note_rounded;
      case 'thermostat':
        return Icons.thermostat_rounded;
      case 'camera':
        return Icons.videocam_outlined;
      case 'lock':
        return Icons.lock_outline_rounded;
      default:
        return Icons.star_border_rounded;
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // SEÇÃO 4: EDITOR DE PORTFÓLIO & CLIENTES DA PÁGINA 3
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildPage3PortfolioEditor() {
    final items = widget.page3PortfolioItems.isNotEmpty
        ? widget.page3PortfolioItems
        : AutomationPortfolioItem.defaultItems();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── CABEÇALHO DA SEÇÃO ──
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.photo_library_rounded,
                            color: Color(0xFF10B981), size: 20),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Editor da Página 3: Portfólio & Clientes',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Faça upload de fotos reais dos ambientes/obras executadas e detalhe o que foi feito para cada cliente.',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: const Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  onPressed: () => setState(() => _currentSection = 0),
                  icon: const Icon(Icons.arrow_back_rounded,
                      size: 14, color: Color(0xFF38BDF8)),
                  label: Text(
                    'Voltar a Todas as Páginas',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF38BDF8)),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF0284C7)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    widget.onResetPage3Items?.call();
                    widget.onUpdatePage3PortfolioItems
                        ?.call(AutomationPortfolioItem.defaultItems());
                  },
                  icon: const Icon(Icons.restart_alt_rounded,
                      size: 15, color: Color(0xFF38BDF8)),
                  label: Text(
                    'Restaurar Cases Padrão',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF38BDF8)),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF0284C7)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    final newId =
                        'case_${DateTime.now().millisecondsSinceEpoch}';
                    final newItem = AutomationPortfolioItem(
                      id: newId,
                      title: 'Novo Projeto Residencial',
                      clientOrLocation: 'Condomínio Residencial • Cidade - UF',
                      description:
                          'Especificação técnica do projeto: detalhamento dos circuitos de iluminação, sistemas de som, climatização e conforto entregues.',
                      tags:
                          'Iluminação Cênica • Climatização VRF • Som Multiroom',
                      completionDate: 'Obra Entregue • 2025',
                      order: items.length,
                    );
                    widget.onUpdatePage3PortfolioItems
                        ?.call([...items, newItem]);
                  },
                  icon: const Icon(Icons.add_photo_alternate_rounded, size: 16),
                  label: Text(
                    '+ NOVO PROJETO',
                    style: GoogleFonts.inter(
                        fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 18),

        // ── TÍTULO E SUBTÍTULO DO TOPO DA FOLHA A4 ──
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CABEÇALHO DA SEÇÃO NA FOLHA A4',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFCBD5E1),
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Título Superior',
                            style: GoogleFonts.inter(
                                fontSize: 11, color: const Color(0xFF94A3B8))),
                        const SizedBox(height: 4),
                        TextFormField(
                          key: ValueKey('page3_title_${widget.page3Title}'),
                          initialValue: widget.page3Title,
                          onChanged: (val) =>
                              widget.onUpdatePage3Title?.call(val),
                          style: GoogleFonts.inter(
                              fontSize: 12.5, color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'PORTFÓLIO & CLIENTES',
                            hintStyle: GoogleFonts.inter(
                                fontSize: 12, color: const Color(0xFF64748B)),
                            filled: true,
                            fillColor: const Color(0xFF1E293B),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none),
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
                        Text('Subtítulo Descritivo',
                            style: GoogleFonts.inter(
                                fontSize: 11, color: const Color(0xFF94A3B8))),
                        const SizedBox(height: 4),
                        TextFormField(
                          key: ValueKey('page3_sub_${widget.page3Subtitle}'),
                          initialValue: widget.page3Subtitle,
                          onChanged: (val) =>
                              widget.onUpdatePage3Subtitle?.call(val),
                          style: GoogleFonts.inter(
                              fontSize: 12.5, color: Colors.white),
                          decoration: InputDecoration(
                            hintText:
                                'Projetos executados com excelência e tecnologia de ponta',
                            hintStyle: GoogleFonts.inter(
                                fontSize: 12, color: const Color(0xFF64748B)),
                            filled: true,
                            fillColor: const Color(0xFF1E293B),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none),
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

        const SizedBox(height: 18),

        // ── CARDS DOS PROJETOS DE PORTFÓLIO ──
        Text(
          'CASES DE PROJETOS E OBRAS (${items.length})',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: const Color(0xFFCBD5E1),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),

        ...items.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top bar do Card
                Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: const BoxDecoration(
                        color: Color(0xFF0284C7),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${idx + 1}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.title.isNotEmpty
                            ? item.title
                            : 'Projeto #${idx + 1}',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color:
                                const Color(0xFF10B981).withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        'CASE NO PDF',
                        style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF34D399)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: Color(0xFFEF4444), size: 20),
                      tooltip: 'Excluir Este Case',
                      onPressed: () {
                        final updated =
                            items.where((it) => it.id != item.id).toList();
                        widget.onUpdatePage3PortfolioItems?.call(updated);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Seção da Foto do Case
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Preview da Foto
                    InkWell(
                      onTap: () async {
                        try {
                          final files = await FilePicker.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
                          );
                          if (files.isNotEmpty) {
                            final bytes = await files.first.readAsBytes();
                            final b64 = base64Encode(bytes);
                            final updated = items.map((it) {
                              if (it.id == item.id) {
                                return it.copyWith(imageBase64: b64);
                              }
                              return it;
                            }).toList();
                            widget.onUpdatePage3PortfolioItems?.call(updated);
                          }
                        } catch (_) {}
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 140,
                        height: 95,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: item.imageBase64 != null
                                ? const Color(0xFF38BDF8)
                                : const Color(0xFF475569),
                            width: 1.2,
                          ),
                        ),
                        child: item.imageBase64 != null &&
                                item.imageBase64!.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(9),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Builder(builder: (ctx) {
                                      try {
                                        return Image.memory(
                                          base64Decode(
                                              item.imageBase64!.contains(',')
                                                  ? item.imageBase64!
                                                      .split(',')
                                                      .last
                                                  : item.imageBase64!),
                                          fit: BoxFit.cover,
                                        );
                                      } catch (_) {
                                        return const Icon(
                                            Icons.broken_image_rounded,
                                            color: Colors.white38);
                                      }
                                    }),
                                    Positioned(
                                      bottom: 0,
                                      left: 0,
                                      right: 0,
                                      child: Container(
                                        color: Colors.black
                                            .withValues(alpha: 0.65),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 2),
                                        child: Text(
                                          'TROCAR FOTO',
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.inter(
                                              fontSize: 8.5,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.add_photo_alternate_rounded,
                                      color: Color(0xFF38BDF8), size: 26),
                                  const SizedBox(height: 4),
                                  Text(
                                    'SUBIR FOTO',
                                    style: GoogleFonts.inter(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF38BDF8)),
                                  ),
                                  Text(
                                    'JPG / PNG',
                                    style: GoogleFonts.inter(
                                        fontSize: 8,
                                        color: const Color(0xFF94A3B8)),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Inputs de Texto (Título e Localização)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Nome do Projeto / Obra',
                              style: GoogleFonts.inter(
                                  fontSize: 10.5,
                                  color: const Color(0xFF94A3B8))),
                          const SizedBox(height: 3),
                          TextFormField(
                            key: ValueKey('title_${item.id}_${item.title}'),
                            initialValue: item.title,
                            onChanged: (val) {
                              final updated = items.map((it) {
                                if (it.id == item.id) {
                                  return it.copyWith(title: val);
                                }
                                return it;
                              }).toList();
                              widget.onUpdatePage3PortfolioItems?.call(updated);
                            },
                            style: GoogleFonts.inter(
                                fontSize: 12, color: Colors.white),
                            decoration: InputDecoration(
                              hintText:
                                  'Ex: Mansão Alphaville • Automação Full',
                              hintStyle: GoogleFonts.inter(
                                  fontSize: 11, color: const Color(0xFF64748B)),
                              filled: true,
                              fillColor: const Color(0xFF1E293B),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: BorderSide.none),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                flex: 6,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Cliente / Localização',
                                        style: GoogleFonts.inter(
                                            fontSize: 10,
                                            color: const Color(0xFF94A3B8))),
                                    const SizedBox(height: 3),
                                    TextFormField(
                                      key: ValueKey(
                                          'loc_${item.id}_${item.clientOrLocation}'),
                                      initialValue: item.clientOrLocation,
                                      onChanged: (val) {
                                        final updated = items.map((it) {
                                          if (it.id == item.id) {
                                            return it.copyWith(
                                                clientOrLocation: val);
                                          }
                                          return it;
                                        }).toList();
                                        widget.onUpdatePage3PortfolioItems
                                            ?.call(updated);
                                      },
                                      style: GoogleFonts.inter(
                                          fontSize: 11.5, color: Colors.white),
                                      decoration: InputDecoration(
                                        hintText: 'Ex: Barueri / SP',
                                        hintStyle: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: const Color(0xFF64748B)),
                                        filled: true,
                                        fillColor: const Color(0xFF1E293B),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 8),
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            borderSide: BorderSide.none),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 4,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Status / Data',
                                        style: GoogleFonts.inter(
                                            fontSize: 10,
                                            color: const Color(0xFF94A3B8))),
                                    const SizedBox(height: 3),
                                    TextFormField(
                                      key: ValueKey(
                                          'date_${item.id}_${item.completionDate}'),
                                      initialValue: item.completionDate,
                                      onChanged: (val) {
                                        final updated = items.map((it) {
                                          if (it.id == item.id) {
                                            return it.copyWith(
                                                completionDate: val);
                                          }
                                          return it;
                                        }).toList();
                                        widget.onUpdatePage3PortfolioItems
                                            ?.call(updated);
                                      },
                                      style: GoogleFonts.inter(
                                          fontSize: 11.5, color: Colors.white),
                                      decoration: InputDecoration(
                                        hintText: 'Obra Entregue • 2024',
                                        hintStyle: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: const Color(0xFF64748B)),
                                        filled: true,
                                        fillColor: const Color(0xFF1E293B),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 8),
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            borderSide: BorderSide.none),
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
                const SizedBox(height: 10),

                // Tags de Tecnologias
                Text('Tags de Tecnologias (separadas por marcador)',
                    style: GoogleFonts.inter(
                        fontSize: 10, color: const Color(0xFF94A3B8))),
                const SizedBox(height: 3),
                TextFormField(
                  key: ValueKey('tags_${item.id}_${item.tags}'),
                  initialValue: item.tags,
                  onChanged: (val) {
                    final updated = items.map((it) {
                      if (it.id == item.id) return it.copyWith(tags: val);
                      return it;
                    }).toList();
                    widget.onUpdatePage3PortfolioItems?.call(updated);
                  },
                  style: GoogleFonts.inter(fontSize: 11.5, color: Colors.white),
                  decoration: InputDecoration(
                    hintText:
                        'Ex: Iluminação Cênica • Climatização VRF • Som Multiroom',
                    hintStyle: GoogleFonts.inter(
                        fontSize: 11, color: const Color(0xFF64748B)),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 8),

                // Especificação Técnica Detalhada do que foi feito
                Text('Especificação Detalhada do que foi feito para o Cliente',
                    style: GoogleFonts.inter(
                        fontSize: 10, color: const Color(0xFF94A3B8))),
                const SizedBox(height: 3),
                TextFormField(
                  key: ValueKey('desc_${item.id}_${item.description}'),
                  initialValue: item.description,
                  maxLines: 3,
                  onChanged: (val) {
                    final updated = items.map((it) {
                      if (it.id == item.id) {
                        return it.copyWith(description: val);
                      }
                      return it;
                    }).toList();
                    widget.onUpdatePage3PortfolioItems?.call(updated);
                  },
                  style: GoogleFonts.inter(
                      fontSize: 12, color: Colors.white, height: 1.3),
                  decoration: InputDecoration(
                    hintText:
                        'Descreva a infraestrutura, circuitos, equipamentos instalados e a experiência entregue...',
                    hintStyle: GoogleFonts.inter(
                        fontSize: 11, color: const Color(0xFF64748B)),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
          );
        }),

        const SizedBox(height: 18),

        // ── PALETAS RÁPIDAS DE CORES ──
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.palette_rounded,
                      color: Color(0xFF38BDF8), size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'PALETAS RÁPIDAS DA PÁGINA 3',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFCBD5E1),
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildPage3PresetChip(
                    title: 'Dark Navy & Cyan (Padrão)',
                    bgHex: '#0B132B',
                    cardHex: '#111C38',
                    borderHex: '#38BDF8',
                    titleHex: '#FFFFFF',
                    subHex: '#94A3B8',
                    accentHex: '#38BDF8',
                  ),
                  _buildPage3PresetChip(
                    title: 'Black Cyber & Emerald',
                    bgHex: '#050811',
                    cardHex: '#0D1527',
                    borderHex: '#10B981',
                    titleHex: '#FFFFFF',
                    subHex: '#64748B',
                    accentHex: '#10B981',
                  ),
                  _buildPage3PresetChip(
                    title: 'Grafite & Ouro Nobre',
                    bgHex: '#0F172A',
                    cardHex: '#1E293B',
                    borderHex: '#F59E0B',
                    titleHex: '#FFFFFF',
                    subHex: '#94A3B8',
                    accentHex: '#F59E0B',
                  ),
                  _buildPage3PresetChip(
                    title: 'Clean Executive Light',
                    bgHex: '#F8FAFC',
                    cardHex: '#FFFFFF',
                    borderHex: '#0284C7',
                    titleHex: '#0F172A',
                    subHex: '#64748B',
                    accentHex: '#0284C7',
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // ── SELETORES INDIVIDUAIS DE CORES DA PÁGINA 3 ──
        Text(
          'CORES DA FOLHA E DOS CARDS DA PÁGINA 3',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF94A3B8),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),

        CoverColorPickerTile(
          label: 'Fundo da Folha A4 da Página 3',
          currentColorHex: widget.page3BgColor,
          defaultHint: '#0B132B (Azul Escuro Padrão)',
          onColorSelected: (c) =>
              widget.onUpdatePage3BgColor?.call(c.isEmpty ? '#0B132B' : c),
        ),

        CoverColorPickerTile(
          label: 'Fundo dos Cards de Portfólio',
          currentColorHex: widget.page3CardBgColor,
          defaultHint: '#111C38 (Card Escuro)',
          onColorSelected: (c) =>
              widget.onUpdatePage3CardBgColor?.call(c.isEmpty ? '#111C38' : c),
        ),

        CoverColorPickerTile(
          label: 'Cor de Borda e Destaques dos Cards',
          currentColorHex: widget.page3BorderColor,
          defaultHint: '#38BDF8 (Ciano / Azul Claro)',
          onColorSelected: (c) =>
              widget.onUpdatePage3BorderColor?.call(c.isEmpty ? '#38BDF8' : c),
        ),

        CoverColorPickerTile(
          label: 'Títulos dos Projetos',
          currentColorHex: widget.page3TitleColor,
          defaultHint: '#FFFFFF (Branco)',
          onColorSelected: (c) =>
              widget.onUpdatePage3TitleColor?.call(c.isEmpty ? '#FFFFFF' : c),
        ),

        CoverColorPickerTile(
          label: 'Especificações Técnicas e Localização',
          currentColorHex: widget.page3SubtitleColor,
          defaultHint: '#94A3B8 (Slate / Cinza Elegante)',
          onColorSelected: (c) => widget.onUpdatePage3SubtitleColor
              ?.call(c.isEmpty ? '#94A3B8' : c),
        ),

        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildPage3PresetChip({
    required String title,
    required String bgHex,
    required String cardHex,
    required String borderHex,
    required String titleHex,
    required String subHex,
    required String accentHex,
  }) {
    final isSelected = widget.page3BgColor == bgHex &&
        widget.page3CardBgColor == cardHex &&
        widget.page3BorderColor == borderHex;

    return InkWell(
      onTap: () {
        widget.onUpdatePage3BgColor?.call(bgHex);
        widget.onUpdatePage3CardBgColor?.call(cardHex);
        widget.onUpdatePage3BorderColor?.call(borderHex);
        widget.onUpdatePage3TitleColor?.call(titleHex);
        widget.onUpdatePage3SubtitleColor?.call(subHex);
        widget.onUpdatePage3AccentColor?.call(accentHex);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color:
                isSelected ? const Color(0xFF38BDF8) : const Color(0xFF475569),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: Color(int.parse(bgHex.replaceFirst('#', '0xFF'))),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white54, width: 1),
              ),
            ),
            const SizedBox(width: 4),
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: Color(int.parse(borderHex.replaceFirst('#', '0xFF'))),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white54, width: 1),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // SEÇÃO 5: EDITOR DE ESTILO DA PÁGINA 4 (AMBIENTES & CARDS DA PROPOSTA WEB)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildPage4EditorSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cabeçalho da Seção
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF00E5FF).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.tune_rounded,
                            color: Color(0xFF00E5FF), size: 20),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Editor da Página 4 (Ambientes & Produtos)',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Personalize o fundo da folha, a cor dos cards, bordas e tipografia da listagem de equipamentos.',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: const Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  onPressed: () => setState(() => _currentSection = 0),
                  icon: const Icon(Icons.arrow_back_rounded,
                      size: 14, color: Color(0xFF38BDF8)),
                  label: Text(
                    'Voltar a Todas as Páginas',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF38BDF8)),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF0284C7)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    widget.onResetPage4Colors?.call();
                    widget.onUpdatePage4BgColor?.call('#0B132B');
                    widget.onUpdatePage4CardBgColor?.call('#111C38');
                    widget.onUpdatePage4BorderColor?.call('#00E5FF');
                    widget.onUpdatePage4TitleColor?.call('#FFFFFF');
                    widget.onUpdatePage4SubtitleColor?.call('#94A3B8');
                    widget.onUpdatePage4AccentColor?.call('#00E5FF');
                  },
                  icon: const Icon(Icons.restart_alt_rounded,
                      size: 15, color: Color(0xFF38BDF8)),
                  label: Text(
                    'Restaurar Padrão',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF38BDF8)),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF0284C7)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 18),

        // ── PRESETS VISUAIS DE 1 CLIQUE ──
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded,
                      color: Color(0xFFF59E0B), size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'PALETAS RÁPIDAS DE 1 CLIQUE',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFCBD5E1),
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildPage4PresetChip(
                    title: 'Padrão Proposta Web (Imagem 1)',
                    bgHex: '#0B132B',
                    cardHex: '#111C38',
                    borderHex: '#00E5FF',
                    titleHex: '#FFFFFF',
                    subHex: '#94A3B8',
                    accentHex: '#00E5FF',
                  ),
                  _buildPage4PresetChip(
                    title: 'Deep Midnight & Gold',
                    bgHex: '#090D16',
                    cardHex: '#131B2E',
                    borderHex: '#F59E0B',
                    titleHex: '#FFFFFF',
                    subHex: '#94A3B8',
                    accentHex: '#F59E0B',
                  ),
                  _buildPage4PresetChip(
                    title: 'Cyber Emerald Tech',
                    bgHex: '#061A14',
                    cardHex: '#0B2920',
                    borderHex: '#10B981',
                    titleHex: '#FFFFFF',
                    subHex: '#94A3B8',
                    accentHex: '#10B981',
                  ),
                  _buildPage4PresetChip(
                    title: 'Clean Minimalist Light',
                    bgHex: '#F8FAFC',
                    cardHex: '#FFFFFF',
                    borderHex: '#0284C7',
                    titleHex: '#0F172A',
                    subHex: '#64748B',
                    accentHex: '#0284C7',
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ── SELETORES INDIVIDUAIS DE CORES ──
        Text(
          'CORES DA FOLHA E DOS CARDS',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF94A3B8),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),

        CoverColorPickerTile(
          label: 'Fundo da Folha A4 da Página 4',
          currentColorHex: widget.page4BgColor,
          defaultHint: '#0B132B (Azul Escuro Padrão)',
          onColorSelected: (c) =>
              widget.onUpdatePage4BgColor?.call(c.isEmpty ? '#0B132B' : c),
        ),

        CoverColorPickerTile(
          label: 'Fundo dos Cards de Ambiente',
          currentColorHex: widget.page4CardBgColor,
          defaultHint: '#111C38 (Card Escuro)',
          onColorSelected: (c) =>
              widget.onUpdatePage4CardBgColor?.call(c.isEmpty ? '#111C38' : c),
        ),

        CoverColorPickerTile(
          label: 'Cor de Borda e Destaques dos Cards',
          currentColorHex: widget.page4BorderColor,
          defaultHint: '#00E5FF (Ciano Neon)',
          onColorSelected: (c) =>
              widget.onUpdatePage4BorderColor?.call(c.isEmpty ? '#00E5FF' : c),
        ),

        const SizedBox(height: 18),

        Text(
          'TIPOGRAFIA & VALORES DOS CARDS',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF94A3B8),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),

        CoverColorPickerTile(
          label: 'Títulos dos Ambientes e Equipamentos',
          currentColorHex: widget.page4TitleColor,
          defaultHint: '#FFFFFF (Branco)',
          onColorSelected: (c) =>
              widget.onUpdatePage4TitleColor?.call(c.isEmpty ? '#FFFFFF' : c),
        ),

        CoverColorPickerTile(
          label: 'Subtítulos, Descrições e Marcas',
          currentColorHex: widget.page4SubtitleColor,
          defaultHint: '#94A3B8 (Slate / Cinza Elegante)',
          onColorSelected: (c) => widget.onUpdatePage4SubtitleColor
              ?.call(c.isEmpty ? '#94A3B8' : c),
        ),

        CoverColorPickerTile(
          label: 'Subtotal e Destaque Financeiro',
          currentColorHex: widget.page4AccentColor,
          defaultHint: '#00E5FF (Ciano Neon)',
          onColorSelected: (c) =>
              widget.onUpdatePage4AccentColor?.call(c.isEmpty ? '#00E5FF' : c),
        ),

        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildPage4PresetChip({
    required String title,
    required String bgHex,
    required String cardHex,
    required String borderHex,
    required String titleHex,
    required String subHex,
    required String accentHex,
  }) {
    final isSelected = widget.page4BgColor == bgHex &&
        widget.page4CardBgColor == cardHex &&
        widget.page4BorderColor == borderHex;

    return InkWell(
      onTap: () {
        widget.onUpdatePage4BgColor?.call(bgHex);
        widget.onUpdatePage4CardBgColor?.call(cardHex);
        widget.onUpdatePage4BorderColor?.call(borderHex);
        widget.onUpdatePage4TitleColor?.call(titleHex);
        widget.onUpdatePage4SubtitleColor?.call(subHex);
        widget.onUpdatePage4AccentColor?.call(accentHex);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color:
                isSelected ? const Color(0xFF38BDF8) : const Color(0xFF475569),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: Color(int.parse(bgHex.replaceFirst('#', '0xFF'))),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white54, width: 1),
              ),
            ),
            const SizedBox(width: 4),
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: Color(int.parse(borderHex.replaceFirst('#', '0xFF'))),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white54, width: 1),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSolarReorderablePagesList() {
    final order = widget.pageOrder.isNotEmpty
        ? List<String>.from(widget.pageOrder)
        : List<String>.from(SolarSettingsModel.defaultPageOrder);
    for (final cp in widget.customPages) {
      if (!order.contains(cp.id)) order.add(cp.id);
    }

    void moveItem(int idx, int delta) {
      final target = idx + delta;
      if (target < 0 || target >= order.length) return;
      final next = List<String>.from(order);
      final moved = next.removeAt(idx);
      next.insert(target, moved);
      widget.onUpdatePageOrder?.call(next);
    }

    Widget buildMoveButtons(int idx) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Mover página para cima',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            icon: Icon(
              Icons.arrow_upward_rounded,
              size: 18,
              color: idx > 0 ? const Color(0xFF38BDF8) : Colors.white24,
            ),
            onPressed: idx > 0 ? () => moveItem(idx, -1) : null,
          ),
          IconButton(
            tooltip: 'Mover página para baixo',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            icon: Icon(
              Icons.arrow_downward_rounded,
              size: 18,
              color: idx < order.length - 1 ? const Color(0xFF38BDF8) : Colors.white24,
            ),
            onPressed: idx < order.length - 1 ? () => moveItem(idx, 1) : null,
          ),
        ],
      );
    }

    final coverSelected = widget.activePageId == 'page_1';
    final widgets = <Widget>[
      Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: coverSelected ? const Color(0xFF0C4A6E) : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: coverSelected ? const Color(0xFF38BDF8) : const Color(0xFF334155),
            width: coverSelected ? 1.8 : 1,
          ),
        ),
        child: ListTile(
          onTap: () => widget.onSelectPage('page_1'),
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              shape: BoxShape.circle,
              border: Border.all(color: coverSelected ? const Color(0xFF38BDF8) : const Color(0xFF475569)),
            ),
            child: Center(
              child: Text('1', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
          title: Row(
            children: [
              Text('Capa Oficial', style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('FIXA 1ª', style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFF38BDF8))),
              ),
            ],
          ),
          subtitle: Text(
            'Capa executiva, logo, foto da usina e dados da proposta solar',
            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
          ),
        ),
      ),
    ];

    final metaMap = <String, Map<String, String>>{
      'page_2': {
        'title': 'Escopo & Diferenciais',
        'subtitle': 'Componentes da usina, tecnologia dos módulos e diferenciais',
      },
      'page_3': {
        'title': 'Sua Usina Solar',
        'subtitle': 'Ficha técnica, potência estimada, geração mensal e área',
      },
      'page_4': {
        'title': 'Estudo de Telhado & Sombreamento (3D)',
        'subtitle': 'Incluída automaticamente quando houver estudo solar vinculado',
      },
      'page_5': {
        'title': 'Itens da Usina & Pagamento',
        'subtitle': 'Equipamentos detalhados, investimento e condições comerciais',
      },
      'page_6': {
        'title': 'Análise de Investimento (20 Anos)',
        'subtitle': 'Gráfico de retorno, payback e projeção de economia anual',
      },
      'page_7': {
        'title': 'Financiamento & Condições',
        'subtitle': 'Simulação de parcelas bancárias e opções de cartão',
      },
    };

    for (int i = 0; i < order.length; i++) {
      final key = order[i];
      final posNumber = i + 2;

      if (key == 'portfolio') {
        widgets.add(
          _buildSolarPortfolioOverviewCard(
            positionNumber: posNumber,
            moveControls: buildMoveButtons(i),
          ),
        );
        continue;
      }

      final cpMatch = widget.customPages.where((c) => c.id == key);
      if (cpMatch.isNotEmpty) {
        final cp = cpMatch.first;
        final isSelected = widget.activePageId == cp.id;
        widgets.add(
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF064E3B) : const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? const Color(0xFF10B981) : const Color(0xFF334155),
                width: isSelected ? 1.8 : 1,
              ),
            ),
            child: ListTile(
              onTap: () => widget.onSelectPage(cp.id),
              leading: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF10B981)),
                ),
                child: Center(
                  child: Text('$posNumber', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF10B981))),
                ),
              ),
              title: Text(cp.title, style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.white)),
              subtitle: Text('${cp.cards.length} cards inseridos • Fundo: ${cp.bgType}', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)), maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  buildMoveButtons(i),
                  IconButton(
                    tooltip: 'Remover Página Personalizada',
                    icon: const Icon(Icons.delete_forever_rounded, color: Color(0xFFEF4444), size: 20),
                    onPressed: () {
                      final updated = List<ProposalCustomPage>.from(widget.customPages)..removeWhere((c) => c.id == cp.id);
                      widget.onUpdateCustomPages(updated);
                      final nextOrder = List<String>.from(order)..remove(cp.id);
                      widget.onUpdatePageOrder?.call(nextOrder);
                      if (widget.activePageId == cp.id) widget.onSelectPage('page_1');
                    },
                  ),
                ],
              ),
            ),
          ),
        );
        continue;
      }

      final meta = metaMap[key];
      if (meta == null) continue;
      final isHidden = widget.hiddenPageIds.contains(key);
      final isSelected = widget.activePageId == key;

      widgets.add(
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0C4A6E) : const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF38BDF8)
                  : isHidden
                      ? const Color(0xFF475569).withValues(alpha: 0.5)
                      : const Color(0xFF334155),
              width: isSelected ? 1.8 : 1,
            ),
          ),
          child: ListTile(
            onTap: () => widget.onSelectPage(key),
            leading: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isHidden ? const Color(0xFF334155) : const Color(0xFF1E293B),
                shape: BoxShape.circle,
                border: Border.all(color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF475569)),
              ),
              child: Center(
                child: Text(
                  '$posNumber',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isHidden ? const Color(0xFF94A3B8) : Colors.white,
                  ),
                ),
              ),
            ),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    meta['title']!,
                    style: GoogleFonts.outfit(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: isHidden ? const Color(0xFF94A3B8) : Colors.white,
                      decoration: isHidden ? TextDecoration.lineThrough : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (key == 'page_2') ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('EDITÁVEL', style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFF38BDF8))),
                  ),
                ],
                if (isHidden) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('OCULTA', style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFFF87171))),
                  ),
                ],
              ],
            ),
            subtitle: Text(
              meta['subtitle']!,
              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                buildMoveButtons(i),
                if (key == 'page_2')
                  IconButton(
                    tooltip: 'Editar Conteúdo da Página',
                    icon: const Icon(Icons.edit_note_rounded, color: Color(0xFF38BDF8), size: 22),
                    onPressed: () {
                      widget.onSelectPage('page_2');
                      setState(() => _currentSection = 1);
                    },
                  ),
                IconButton(
                  tooltip: isHidden ? 'Restaurar Página no PDF' : 'Ocultar Página do PDF',
                  icon: Icon(
                    isHidden ? Icons.visibility_off_rounded : Icons.delete_outline_rounded,
                    color: isHidden ? const Color(0xFF94A3B8) : const Color(0xFFEF4444),
                    size: 20,
                  ),
                  onPressed: () => _toggleHidePage(key),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  Widget _buildSolarPortfolioOverviewCard({
    int positionNumber = 2,
    Widget? moveControls,
  }) {
    final active = widget.showSolarPortfolio;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF064E3B).withValues(alpha: 0.35) : const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active ? const Color(0xFF10B981) : const Color(0xFF334155),
          width: active ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        onTap: () => setState(() => _currentSection = 4),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: active ? const Color(0xFF059669) : const Color(0xFF1E293B),
            shape: BoxShape.circle,
            border: Border.all(color: active ? const Color(0xFF34D399) : const Color(0xFF475569)),
          ),
          child: Center(
            child: Text(
              '$positionNumber',
              style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                'Portfólio de Clientes',
                style: GoogleFonts.outfit(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: (active ? const Color(0xFF10B981) : const Color(0xFF64748B)).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                active ? 'ATIVA (${widget.solarPortfolioItems.length} OBRAS)' : 'DESATIVADA',
                style: GoogleFonts.inter(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  color: active ? const Color(0xFF34D399) : const Color(0xFF94A3B8),
                ),
              ),
            ),
          ],
        ),
        subtitle: Text(
          'Segunda página após a capa. Ative para enviar fotos de obras e textos (cliente, potência, geração, placas, inversores).',
          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (moveControls != null) moveControls,
            IconButton(
              tooltip: 'Editar Fotos e Textos do Portfólio',
              icon: const Icon(Icons.edit_note_rounded, color: Color(0xFF34D399), size: 22),
              onPressed: () => setState(() => _currentSection = 4),
            ),
            Switch.adaptive(
              value: active,
              activeTrackColor: const Color(0xFF10B981),
              onChanged: (val) {
                widget.onToggleSolarPortfolio?.call(val);
                if (val && widget.solarPortfolioItems.isEmpty) {
                  setState(() => _currentSection = 4);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSolarPortfolioEditorSection() {
    final items = widget.solarPortfolioItems;

    void updateItems(List<SolarPortfolioItem> next) {
      widget.onUpdateSolarPortfolioItems?.call(next);
    }

    Future<void> pickPhotoForItem(int index) async {
      try {
        final files = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
        );
        if (files.isEmpty) return;
        final bytes = await files.first.readAsBytes();
        final b64 = SolarSettingsService.compressImageBytesForFirestore(
          bytes,
          maxWidth: 800,
          maxBase64Chars: 120000,
        );
        final next = List<SolarPortfolioItem>.from(items);
        next[index] = next[index].copyWith(imageBase64: b64);
        updateItems(next);
      } catch (e) {
        debugPrint('[CoverPagesManagerTab] Erro ao enviar foto do portfólio: $e');
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Editor da Página de Portfólio (2ª Página do PDF)',
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Text(
                    'Ative a página, envie fotos reais das suas obras e preencha apenas os dados que desejar exibir (até 6 cards por página).',
                    style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () {
                final next = List<SolarPortfolioItem>.from(items)
                  ..add(
                    SolarPortfolioItem(
                      id: DateTime.now().microsecondsSinceEpoch.toString(),
                      title: 'Projeto ${items.length + 1}',
                    ),
                  );
                updateItems(next);
                if (!widget.showSolarPortfolio) {
                  widget.onToggleSolarPortfolio?.call(true);
                }
              },
              icon: const Icon(Icons.add_photo_alternate_rounded, size: 16),
              label: const Text('ADICIONAR OBRA'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: widget.showSolarPortfolio ? const Color(0xFF10B981) : const Color(0xFF334155)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mostrar Página de Portfólio no PDF (após a Capa)',
                      style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      'Desativada por padrão em novas contas até você ativar aqui.',
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: widget.showSolarPortfolio,
                activeTrackColor: const Color(0xFF10B981),
                onChanged: (val) => widget.onToggleSolarPortfolio?.call(val),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TEXTOS DO BANNER E RODAPÉ DO PORTFÓLIO',
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF38BDF8), letterSpacing: 0.8),
              ),
              const SizedBox(height: 10),
              _buildDarkTextField(
                label: 'Título do Banner',
                initialValue: widget.solarPortfolioTitle,
                hint: 'Ex: Portfólio de clientes',
                onChanged: (v) => widget.onSolarPortfolioTitleChanged?.call(v),
              ),
              const SizedBox(height: 10),
              _buildDarkTextField(
                label: 'Subtítulo do Banner',
                initialValue: widget.solarPortfolioSubtitle,
                hint: 'Ex: Instalações residenciais, comerciais e rurais',
                onChanged: (v) => widget.onSolarPortfolioSubtitleChanged?.call(v),
              ),
              const SizedBox(height: 10),
              _buildDarkTextField(
                label: 'Nota de Rodapé da Página',
                initialValue: widget.solarPortfolioFooterNote,
                hint: 'Ex: Projetos executados com engenharia própria e homologação completa.',
                onChanged: (v) => widget.onSolarPortfolioFooterNoteChanged?.call(v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'PROJETOS / OBRAS NO PORTFÓLIO (${items.length})',
          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFFCBD5E1), letterSpacing: 0.8),
        ),
        const SizedBox(height: 10),
        if (items.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Center(
              child: Text(
                'Nenhuma obra cadastrada ainda. Clique em "ADICIONAR OBRA" acima para enviar fotos e dados dos seus clientes.',
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          ...items.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            return Container(
              key: ValueKey('solar_portfolio_card_${item.id}'),
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 13,
                        backgroundColor: const Color(0xFF0284C7),
                        child: Text('${idx + 1}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.title.isNotEmpty ? item.title : 'Obra #${idx + 1}',
                          style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remover Obra',
                        icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
                        onPressed: () {
                          final next = List<SolarPortfolioItem>.from(items)..removeAt(idx);
                          updateItems(next);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        width: 110,
                        height: 72,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: (item.imageBase64 != null && item.imageBase64!.isNotEmpty)
                            ? Image.memory(base64Decode(item.imageBase64!), fit: BoxFit.cover)
                            : const Icon(Icons.solar_power_rounded, color: Colors.white38, size: 28),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => pickPhotoForItem(idx),
                              icon: const Icon(Icons.upload_rounded, size: 15),
                              label: Text(item.imageBase64 != null ? 'TROCAR FOTO' : 'ENVIAR FOTO'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0284C7),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                            if (item.imageBase64 != null && item.imageBase64!.isNotEmpty)
                              OutlinedButton.icon(
                                onPressed: () {
                                  final next = List<SolarPortfolioItem>.from(items);
                                  next[idx] = next[idx].copyWith(clearImage: true);
                                  updateItems(next);
                                },
                                icon: const Icon(Icons.close_rounded, size: 15, color: Color(0xFFF87171)),
                                label: const Text('REMOVER FOTO', style: TextStyle(color: Color(0xFFF87171))),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Color(0xFFEF4444)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: _buildDarkTextField(
                          fieldKey: ValueKey('sp_title_${item.id}'),
                          label: 'Cliente / Nome da Obra',
                          initialValue: item.title,
                          hint: 'Ex: Residência Almeida',
                          onChanged: (v) {
                            final next = List<SolarPortfolioItem>.from(items);
                            next[idx] = next[idx].copyWith(title: v);
                            updateItems(next);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: _buildDarkTextField(
                          fieldKey: ValueKey('sp_power_${item.id}'),
                          label: 'Potência (Badge)',
                          initialValue: item.powerBadge,
                          hint: 'Ex: 13,64 kWp',
                          onChanged: (v) {
                            final next = List<SolarPortfolioItem>.from(items);
                            next[idx] = next[idx].copyWith(powerBadge: v);
                            updateItems(next);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDarkTextField(
                          fieldKey: ValueKey('sp_mod_${item.id}'),
                          label: 'Placas / Módulos',
                          initialValue: item.modules,
                          hint: 'Ex: 22 × Osda N-Type 620 W',
                          onChanged: (v) {
                            final next = List<SolarPortfolioItem>.from(items);
                            next[idx] = next[idx].copyWith(modules: v);
                            updateItems(next);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildDarkTextField(
                          fieldKey: ValueKey('sp_inv_${item.id}'),
                          label: 'Inversor(es)',
                          initialValue: item.inverter,
                          hint: 'Ex: Auxsol 10 kW',
                          onChanged: (v) {
                            final next = List<SolarPortfolioItem>.from(items);
                            next[idx] = next[idx].copyWith(inverter: v);
                            updateItems(next);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDarkTextField(
                          fieldKey: ValueKey('sp_gen_${item.id}'),
                          label: 'Geração (opcional)',
                          initialValue: item.generation,
                          hint: 'Ex: 1.650 kWh/mês',
                          onChanged: (v) {
                            final next = List<SolarPortfolioItem>.from(items);
                            next[idx] = next[idx].copyWith(generation: v);
                            updateItems(next);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildDarkTextField(
                          fieldKey: ValueKey('sp_ext_${item.id}'),
                          label: 'Local / Detalhes (opcional)',
                          initialValue: item.extraInfo,
                          hint: 'Ex: Goiânia - GO',
                          onChanged: (v) {
                            final next = List<SolarPortfolioItem>.from(items);
                            next[idx] = next[idx].copyWith(extraInfo: v);
                            updateItems(next);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildDarkTextField({
    Key? fieldKey,
    required String label,
    required String initialValue,
    required String hint,
    required ValueChanged<String> onChanged,
  }) {
    return TextFormField(
      key: fieldKey,
      initialValue: initialValue,
      onChanged: onChanged,
      style: GoogleFonts.inter(fontSize: 12.5, color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF94A3B8)),
        hintText: hint,
        hintStyle: GoogleFonts.inter(fontSize: 11.5, color: Colors.white24),
        isDense: true,
        filled: true,
        fillColor: const Color(0xFF1E293B),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF38BDF8)),
        ),
      ),
    );
  }
}
