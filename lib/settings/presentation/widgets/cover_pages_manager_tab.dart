import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/models/proposal_pages_models.dart';

/// Aba "Páginas": Gerenciamento multipáginas, mini-previews, 20 templates de Página 2,
/// 20 presets de páginas internas e banco com 30 imagens curadas.
class CoverPagesManagerTab extends StatefulWidget {
  final bool isSolar;
  final String activePageId; // 'page_1', 'page_2', 'page_3', 'page_4', 'page_5', ou 'custom_...'
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
  });

  @override
  State<CoverPagesManagerTab> createState() => _CoverPagesManagerTabState();
}

class _CoverPagesManagerTabState extends State<CoverPagesManagerTab> {
  int _currentSection = 0; // 0: Todas as Páginas, 1: Editar Pág 2, 2: 20 Templates Pág 2, 3: 20 Presets Internos

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Sub-menu horizontal moderno com abas da seção
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
    final sections = [
      {'icon': Icons.auto_stories_rounded, 'label': 'Todas Páginas'},
      {'icon': Icons.edit_attributes_rounded, 'label': 'Editar Pág 2'},
      {'icon': Icons.dashboard_customize_rounded, 'label': '20 Templates Pág 2'},
      {'icon': Icons.palette_outlined, 'label': '20 Padrões Internos'},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(bottom: BorderSide(color: Color(0xFF334155))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(sections.length, (idx) {
            final isSelected = _currentSection == idx;
            final item = sections[idx];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: () {
                  setState(() => _currentSection = idx);
                  if (idx == 1) {
                    widget.onSelectPage('page_2');
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF334155),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item['icon'] as IconData,
                        size: 15,
                        color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        item['label'] as String,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
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
        return _build20Page2TemplatesGrid();
      case 3:
        return _build20InternalPresetsGrid();
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
        'subtitle': 'Capa holográfica, logo, título e nós de tecnologia',
        'icon': Icons.branding_watermark_rounded,
        'canDelete': false,
      },
      {
        'id': 'page_2',
        'number': 2,
        'title': 'Página 2: Escopo & Diferenciais',
        'subtitle': 'Cards de tecnologia, conforto, segurança e ilustração',
        'icon': Icons.grid_view_rounded,
        'canDelete': true,
      },
      {
        'id': 'page_3',
        'number': 3,
        'title': 'Página 3: Institucional & Sede',
        'subtitle': 'Dados da empresa, endereço, CNPJ e histórico',
        'icon': Icons.business_rounded,
        'canDelete': true,
      },
      {
        'id': 'page_4',
        'number': 4,
        'title': 'Página 4: Detalhamento de Equipamentos',
        'subtitle': 'Tabela técnica de componentes por ambiente',
        'icon': Icons.list_alt_rounded,
        'canDelete': true,
      },
      {
        'id': 'page_5',
        'number': 5,
        'title': 'Página 5: Resumo Financeiro & Garantias',
        'subtitle': 'Valores, mão de obra, termos e validade jurídica',
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
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Text(
                  'Selecione uma página para inspecionar, oculte páginas ou adicione novas.',
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Lista de Páginas Padrão
        ...standardPages.map((p) {
          final pageId = p['id'] as String;
          final isHidden = widget.hiddenPageIds.contains(pageId);
          final isSelected = widget.activePageId == pageId;
          final canDelete = p['canDelete'] as bool;

          return Container(
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
              onTap: () => widget.onSelectPage(pageId),
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
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF0284C7), width: 0.8),
                      ),
                      child: Text(
                        'EDITÁVEL',
                        style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFF38BDF8)),
                      ),
                    ),
                  if (isHidden)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'REMOVIDA DO PDF',
                        style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFFF87171)),
                      ),
                    ),
                ],
              ),
              subtitle: Text(
                p['subtitle'] as String,
                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (pageId == 'page_2')
                    IconButton(
                      tooltip: 'Editar Conteúdo da Página 2',
                      icon: const Icon(Icons.edit_note_rounded, color: Color(0xFF38BDF8), size: 22),
                      onPressed: () {
                        widget.onSelectPage('page_2');
                        setState(() => _currentSection = 1);
                      },
                    ),
                  if (canDelete)
                    IconButton(
                      tooltip: isHidden ? 'Restaurar Página no PDF' : 'Remover Página do PDF',
                      icon: Icon(
                        isHidden ? Icons.visibility_off_rounded : Icons.delete_outline_rounded,
                        color: isHidden ? const Color(0xFF94A3B8) : const Color(0xFFEF4444),
                        size: 20,
                      ),
                      onPressed: () => _toggleHidePage(pageId),
                    ),
                ],
              ),
            ),
          );
        }),

        // Páginas Personalizadas Adicionadas pelo Usuário
        if (widget.customPages.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Páginas Personalizadas Criadas (${widget.customPages.length})',
            style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
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
                color: isSelected ? const Color(0xFF064E3B) : const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? const Color(0xFF10B981) : const Color(0xFF334155),
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
                      style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
                    ),
                  ),
                ),
                title: Text(
                  cp.title,
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                subtitle: Text(
                  '${cp.cards.length} cards inseridos • Fundo: ${cp.bgType}',
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Editar Página',
                      icon: const Icon(Icons.edit_rounded, color: Color(0xFF10B981), size: 18),
                      onPressed: () => widget.onSelectPage(pageId),
                    ),
                    IconButton(
                      tooltip: 'Excluir Página',
                      icon: const Icon(Icons.delete_forever_rounded, color: Color(0xFFEF4444), size: 20),
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
          description: 'Descrição detalhada dos serviços ou diferenciais inseridos nesta página.',
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Personalização da Página 2',
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Text(
                  'Edite textos, ícones, cores e reposicione os cards da segunda folha.',
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
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
                      const Icon(Icons.image_outlined, color: Color(0xFF38BDF8), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Ilustração Tecnológica Inferior',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
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
                    _buildIllustrationTypeChip('cyberDark', 'Infraestrutura Cibernética (Dark)'),
                    _buildIllustrationTypeChip('blueprint', 'Projeto Técnico (Blueprint)'),
                    _buildIllustrationTypeChip('luxuryGold', 'Padrão Alta Nobreza (Gold)'),
                    _buildIllustrationTypeChip('timeline', 'Jornada Turn-Key (Timeline)'),
                    _buildIllustrationTypeChip('solarFlow', 'Fluxo Solar Fotovoltaico'),
                    _buildIllustrationTypeChip('iotNetwork', 'Topologia Rede Mesh & IoT'),
                    _buildIllustrationTypeChip('greenEco', 'Eficiência Verde & CO2'),
                    _buildIllustrationTypeChip('banner', 'Mansão Conectada (Banner)'),
                    _buildIllustrationTypeChip('isometric', 'Corte Isométrico Ambientes'),
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
          style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
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
                color: card.isVisible ? const Color(0xFF334155) : const Color(0xFF334155).withValues(alpha: 0.4),
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
                        color: Color(int.tryParse(card.colorHex.replaceAll('#', '0xFF')) ?? 0xFF0284C7).withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: Color(int.tryParse(card.colorHex.replaceAll('#', '0xFF')) ?? 0xFF0284C7)),
                      ),
                      child: Center(
                        child: Icon(
                          _getIconData(card.iconKey),
                          size: 16,
                          color: Color(int.tryParse(card.colorHex.replaceAll('#', '0xFF')) ?? 0xFF0284C7),
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
                          color: card.isVisible ? Colors.white : const Color(0xFF94A3B8),
                          decoration: card.isVisible ? null : TextDecoration.lineThrough,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Mudar Ícone',
                      icon: const Icon(Icons.touch_app_rounded, size: 18, color: Color(0xFFEAB308)),
                      onPressed: () => _showCardIconPicker(idx),
                    ),
                    IconButton(
                      tooltip: card.isVisible ? 'Ocultar Card' : 'Exibir Card',
                      icon: Icon(
                        card.isVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                        size: 18,
                        color: card.isVisible ? const Color(0xFF38BDF8) : const Color(0xFF94A3B8),
                      ),
                      onPressed: () => _toggleCardVisibility(idx),
                    ),
                    IconButton(
                      tooltip: 'Excluir Card',
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
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
                    labelStyle: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF334155))),
                  ),
                  onChanged: (val) => _updateCardField(idx, title: val),
                ),
                const SizedBox(height: 8),

                // Edição de Descrição Inline
                TextFormField(
                  initialValue: card.description,
                  style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFFCBD5E1)),
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Descrição / Texto do Card',
                    labelStyle: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF334155))),
                  ),
                  onChanged: (val) => _updateCardField(idx, description: val),
                ),
                const SizedBox(height: 8),

                // Seletor de Cores Rápidas do Card
                Row(
                  children: [
                    Text('Cor do Card: ', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
                    const SizedBox(width: 6),
                    ...['#0284C7', '#2563EB', '#10B981', '#F59E0B', '#6366F1', '#EF4444', '#0F172A'].map((hex) {
                      final isSelected = card.colorHex.toUpperCase() == hex.toUpperCase();
                      final cVal = Color(int.tryParse(hex.replaceAll('#', '0xFF')) ?? 0xFF0284C7);
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
                              color: isSelected ? Colors.white : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: isSelected ? const Icon(Icons.check, size: 10, color: Colors.white) : null,
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
    final isSelected = widget.page2IllustrationType.toLowerCase() == type.toLowerCase();
    return InkWell(
      onTap: () => widget.onSelectPage2IllustrationType(type),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF475569)),
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

  void _updateCardField(int index, {String? title, String? description, String? colorHex, String? iconKey}) {
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
      {'key': 'lightbulb', 'name': 'Lâmpada / Luz', 'icon': Icons.lightbulb_outline_rounded},
      {'key': 'shield', 'name': 'Segurança', 'icon': Icons.shield_outlined},
      {'key': 'eco', 'name': 'Eficiência / Verde', 'icon': Icons.eco_outlined},
      {'key': 'home', 'name': 'Residência', 'icon': Icons.home_outlined},
      {'key': 'blueprint', 'name': 'Engenharia', 'icon': Icons.architecture_rounded},
      {'key': 'phone', 'name': 'Aplicativo / Voz', 'icon': Icons.smartphone_rounded},
      {'key': 'award', 'name': 'Homologação', 'icon': Icons.verified_rounded},
      {'key': 'handshake', 'name': 'Instalação / Suporte', 'icon': Icons.handshake_outlined},
      {'key': 'solar_power', 'name': 'Painel Solar', 'icon': Icons.solar_power_rounded},
      {'key': 'bolt', 'name': 'Energia / Raio', 'icon': Icons.bolt_rounded},
      {'key': 'coins', 'name': 'Economia Financeira', 'icon': Icons.monetization_on_outlined},
      {'key': 'chart', 'name': 'Retorno / Gráfico', 'icon': Icons.trending_up_rounded},
      {'key': 'wifi', 'name': 'Rede Mesh / Wi-Fi', 'icon': Icons.wifi_rounded},
      {'key': 'music', 'name': 'Áudio / Multiroom', 'icon': Icons.music_note_rounded},
      {'key': 'thermostat', 'name': 'Climatização', 'icon': Icons.thermostat_rounded},
      {'key': 'camera', 'name': 'Câmera / CFTV', 'icon': Icons.videocam_outlined},
      {'key': 'lock', 'name': 'Fechadura / Acesso', 'icon': Icons.lock_outline_rounded},
    ];

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFF334155))),
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
                  Text('Selecione o Ícone do Card', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  IconButton(icon: const Icon(Icons.close, color: Colors.white70), onPressed: () => Navigator.pop(ctx)),
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
                        _updateCardField(cardIndex, iconKey: item['key'] as String);
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
                            Icon(item['icon'] as IconData, color: const Color(0xFF38BDF8), size: 26),
                            const SizedBox(height: 4),
                            Text(
                              item['name'] as String,
                              style: GoogleFonts.inter(fontSize: 10, color: Colors.white70),
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
          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        Text(
          'Selecione um template pronto para reconfigurar a disposição dos cards, ícones e ilustrações.',
          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
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
                  color: isSelected ? const Color(0xFF0C4A6E) : const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF334155),
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [BoxShadow(color: const Color(0xFF0284C7).withValues(alpha: 0.3), blurRadius: 10)]
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
                            color: Color(int.tryParse(tpl.defaultPrimaryColor.replaceAll('#', '0xFF')) ?? 0xFF0284C7).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(tpl.icon, color: Color(int.tryParse(tpl.defaultPrimaryColor.replaceAll('#', '0xFF')) ?? 0xFF0284C7), size: 18),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            tpl.title,
                            style: GoogleFonts.outfit(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? const Color(0xFF38BDF8) : Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle_rounded, color: Color(0xFF38BDF8), size: 16),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tpl.description,
                      style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF94A3B8), height: 1.25),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            tpl.category.toUpperCase(),
                            style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFFCBD5E1)),
                          ),
                        ),
                        Text(
                          isSelected ? 'APLICADO' : 'APLICAR ->',
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
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

  // ───────────────────────────────────────────────────────────────────────────
  // SEÇÃO 3: OS 20 PRESETS DE PÁGINAS INTERNAS (CABEÇALHO, RODAPÉ E CORES)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _build20InternalPresetsGrid() {
    final presets = InternalPagesLayoutPreset.getAllPresets();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '20 Padrões de Design para Páginas Internas',
          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        Text(
          'Aplique um padrão visual harmonioso com 1 clique a todas as páginas internas da proposta.',
          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
        ),
        const SizedBox(height: 16),

        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.1,
          ),
          itemCount: presets.length,
          itemBuilder: (ctx, idx) {
            final p = presets[idx];
            final isSelected = widget.selectedInternalPresetId == p.id;
            final colorVal = Color(int.tryParse(p.primaryColorHex.replaceAll('#', '0xFF')) ?? 0xFF0284C7);

            return InkWell(
              onTap: () => widget.onSelectInternalPreset(p),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF0C4A6E) : const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF334155),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 14,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        color: colorVal,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            p.title,
                            style: GoogleFonts.outfit(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? const Color(0xFF38BDF8) : Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            p.subtitle,
                            style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF38BDF8), size: 18),
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
}
