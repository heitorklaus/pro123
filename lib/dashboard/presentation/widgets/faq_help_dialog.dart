import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class _FaqItem {
  final String category;
  final String question;
  final String answer;
  final IconData icon;
  final Color color;

  const _FaqItem({
    required this.category,
    required this.question,
    required this.answer,
    required this.icon,
    required this.color,
  });
}

/// Modal interativo de FAQ / Central de Ajuda do TAOS CRM com busca e categorias.
class FaqHelpDialog extends StatefulWidget {
  const FaqHelpDialog({super.key});

  @override
  State<FaqHelpDialog> createState() => _FaqHelpDialogState();
}

class _FaqHelpDialogState extends State<FaqHelpDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  String _selectedCategory = 'Todas';

  static const List<String> _categories = [
    'Todas',
    'Usinas & Catálogo',
    'Propostas',
    'IA & WhatsApp',
    'Clientes & Contratos',
    'Equipe & Permissões',
    'Meu Site & Suporte',
  ];

  static const List<_FaqItem> _items = [
    _FaqItem(
      category: 'Usinas & Catálogo',
      question: 'Como criar uma Usina Solar?',
      answer:
          'Clique no botão rápido "NOVA USINA" no topo do painel (ou acesse Usinas Solares → Montar Usina Solar). '
          'Informe a descrição, escolha o tipo de telhado (Cerâmico, Metálico, Fibrocimento, Solo, Laje, etc.), '
          'adicione os módulos e inversores, informe o valor do serviço/instalação e clique em Salvar.',
      icon: Icons.solar_power_rounded,
      color: Color(0xFFF59E0B),
    ),
    _FaqItem(
      category: 'Usinas & Catálogo',
      question: 'Como usar a I.A. para criar Usina ou Proposta a partir de uma cotação?',
      answer:
          'Dentro do formulário de Usina Solar, clique em "Importar com IA" e envie o PDF, foto ou texto da cotação do distribuidor. '
          'A IA lê potência (kWp), módulos, inversor, estrutura e valor automaticamente sem duplicar itens já cadastrados. '
          'Na tela de Propostas, você também pode usar o botão "Criar com IA" para montar o orçamento completo.',
      icon: Icons.auto_awesome_rounded,
      color: Color(0xFFF59E0B),
    ),
    _FaqItem(
      category: 'Propostas',
      question: 'Como criar uma Proposta Solar?',
      answer:
          'Clique em "NOVA PROPOSTA" no topo do sistema (ou em Propostas → Nova Proposta). '
          'Selecione ou cadastre o cliente, adicione uma Usina Solar (ou produtos/serviços), ajuste condições de pagamento e salve. '
          'Depois você pode gerar o PDF oficial de 6 páginas ou compartilhar o link da Proposta Web pelo WhatsApp.',
      icon: Icons.description_rounded,
      color: Color(0xFF818CF8),
    ),
    _FaqItem(
      category: 'Propostas',
      question: 'Como usar a Busca Rápida Gold (Ctrl + K)?',
      answer:
          'Clique na barra dourada "Busca rápida..." no topo da tela ou pressione Ctrl + K no teclado de qualquer módulo. '
          'Ela pesquisa instantaneamente clientes, propostas, usinas e contratos visíveis para o seu perfil e leva direto para a tela desejada.',
      icon: Icons.search_rounded,
      color: Color(0xFFFBBF24),
    ),
    _FaqItem(
      category: 'Propostas',
      question: 'Como funciona o Funil Kanban e a Proposta Web?',
      answer:
          'Na tela Propostas, você pode alternar entre a visão em Tabela e o Funil Kanban para acompanhar o status de cada orçamento '
          '(Em Aprovação, Aprovada, etc.). O link da Proposta Web permite que seu cliente visualize o orçamento online no celular e aprove direto.',
      icon: Icons.view_kanban_rounded,
      color: Color(0xFF818CF8),
    ),
    _FaqItem(
      category: 'Propostas',
      question: 'Como fazer estudo de telhado por satélite?',
      answer:
          'Na tela Propostas (botão "Telhado Satélite") ou dentro de Usinas Solares, abra o designer de satélite, '
          'localize o endereço do cliente, posicione as placas sobre o telhado e vincule o estudo diretamente à proposta.',
      icon: Icons.satellite_alt_rounded,
      color: Color(0xFF06B6D4),
    ),
    _FaqItem(
      category: 'IA & WhatsApp',
      question: 'Como adicionar o Agente de IA na minha conta (WhatsApp)?',
      answer:
          '1) Cadastre seu número de WhatsApp no seu usuário (em Usuários → editar telefone).\n'
          '2) Acesse Configurações → Agente de IA do Gemini e defina as regras padrão da empresa (fator de geração, margem de serviço, telhado padrão, validade) e salve.\n'
          '3) A partir desse número cadastrado, basta enviar mensagens, áudios ou arquivos para o WhatsApp do Agente.',
      icon: Icons.smart_toy_rounded,
      color: Color(0xFF10B981),
    ),
    _FaqItem(
      category: 'IA & WhatsApp',
      question: 'O que posso pedir para o Agente no WhatsApp?',
      answer:
          '• Por texto: ex. "Monta uma proposta com 15 placas de 615W e inversor de 8kW para o cliente Paulo" (também aceita só inversor ou só módulos).\n'
          '• Por arquivos: envie cotação em PDF, documento (CNH/CNPJ) ou conta de energia.\n'
          '• Por áudio: fale os dados da proposta que o agente transcreve e compila o PDF na hora.\n'
          '• Consultas: envie "listar propostas" ou "buscar [nome do cliente]".',
      icon: Icons.chat_rounded,
      color: Color(0xFF10B981),
    ),
    _FaqItem(
      category: 'Clientes & Contratos',
      question: 'Como cadastrar cliente rápido usando Conta de Luz (IA) ou CEP?',
      answer:
          'Clique em "NOVO CLIENTE" no topo (ou em Clientes). Clique em "Importar Conta com IA" e envie PDF ou foto da fatura para preencher '
          'nome, CPF/CNPJ, endereço, UC e média de consumo em kWh. Se preferir preencher manual, basta digitar o CEP para autocompletar o endereço via ViaCEP.',
      icon: Icons.person_add_alt_1_rounded,
      color: Color(0xFF38BDF8),
    ),
    _FaqItem(
      category: 'Clientes & Contratos',
      question: 'Como emitir e editar Contratos Jurídicos?',
      answer:
          'Acesse Contratos → NOVO CONTRATO, selecione uma proposta para puxar automaticamente os dados do cliente, valores e potência, '
          'personalize as cláusulas no editor visual e gere o PDF A4 pronto para assinatura.',
      icon: Icons.gavel_rounded,
      color: Color(0xFF8B5CF6),
    ),
    _FaqItem(
      category: 'Clientes & Contratos',
      question: 'Como cadastrar Fornecedores?',
      answer:
          'Acesse Fornecedores → Novo Fornecedor, informe Razão Social/Nome Fantasia, CNPJ, contato, condições de pagamento e CEP (autocompletado). '
          'Depois você pode vincular fornecedores aos produtos do catálogo.',
      icon: Icons.local_shipping_rounded,
      color: Color(0xFF059669),
    ),
    _FaqItem(
      category: 'Equipe & Permissões',
      question: 'Como gerenciar vendedores, gerentes e permissões de acesso?',
      answer:
          'Em Usuários → NOVO USUÁRIO, cadastre gerentes ou vendedores. Por padrão, cada gerente ou vendedor visualiza apenas o que ele mesmo criou. '
          'Clique no ícone de engrenagem na linha do usuário para liberar permissões (como "Ver Todos os Clientes", "Ver Todas as Propostas", etc.) '
          'ou no ícone de gráfico para abrir o Dossiê 360º de Desempenho.',
      icon: Icons.manage_accounts_rounded,
      color: Color(0xFF6366F1),
    ),
    _FaqItem(
      category: 'Equipe & Permissões',
      question: 'Como compartilhar uma usina, cliente ou proposta com outro usuário?',
      answer:
          'Quando Admin ou Gerente cria ou edita um registro (Usina, Proposta, Cliente, Fornecedor), aparece o card "Visibilidade & Compartilhamento". '
          'Você pode marcar "Tornar público para toda a empresa" ou selecionar exatamente quais gerentes e vendedores podem visualizar aquele item.',
      icon: Icons.share_rounded,
      color: Color(0xFF6366F1),
    ),
    _FaqItem(
      category: 'Meu Site & Suporte',
      question: 'Como criar o site da minha empresa (Meu Site One-Page)?',
      answer:
          'Acesse "Meu Site" no menu lateral, escolha um dos 20 templates, personalize cores, textos, serviços e projetos entregues com Preview ao Vivo '
          'e clique em "Salvar & Publicar". Seu link público terá um Simulador de Economia que envia os leads direto para a tela de Clientes.',
      icon: Icons.web_rounded,
      color: Color(0xFFF59E0B),
    ),
    _FaqItem(
      category: 'Meu Site & Suporte',
      question: 'Como falar com o Suporte Técnico?',
      answer:
          'Clique no botão flutuante "Suporte" no canto inferior direito de qualquer tela para enviar texto, imagens ou áudio em tempo real para nossa equipe. '
          'Você também pode clicar no botão de soltar janela no topo do chat para mover e redimensionar enquanto continua usando o sistema.',
      icon: Icons.support_agent_rounded,
      color: Color(0xFF10B981),
    ),
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final q = _query.trim().toLowerCase();

    final filtered = _items.where((item) {
      final matchesCat =
          _selectedCategory == 'Todas' || item.category == _selectedCategory;
      final matchesQuery = q.isEmpty ||
          item.question.toLowerCase().contains(q) ||
          item.answer.toLowerCase().contains(q) ||
          item.category.toLowerCase().contains(q);
      return matchesCat && matchesQuery;
    }).toList();

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: 720,
        height: 620,
        child: Column(
          children: [
            // Cabeçalho
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(
                      Icons.help_outline_rounded,
                      color: Color(0xFF818CF8),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Central de Ajuda & FAQ • TAOS CRM',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Tire suas dúvidas rápidas sobre usinas, propostas, IA, WhatsApp e permissões',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF94A3B8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fechar',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  ),
                ],
              ),
            ),

            // Busca e Categorias
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _searchCtrl,
                    autofocus: true,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText:
                          'Buscar dúvida... (ex: usina, proposta, PDF, WhatsApp, contrato)',
                      prefixIcon: const Icon(Icons.search_rounded),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _categories.map((cat) {
                        final selected = _selectedCategory == cat;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(
                              cat,
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                            selected: selected,
                            selectedColor:
                                const Color(0xFF6366F1).withValues(alpha: 0.2),
                            onSelected: (_) =>
                                setState(() => _selectedCategory = cat),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),

            // Lista de Perguntas
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'Nenhuma pergunta encontrada para "$_query".',
                        style: GoogleFonts.inter(
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        return Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E293B).withValues(alpha: 0.7)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Theme(
                            data: Theme.of(context)
                                .copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              tilePadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 2),
                              childrenPadding: const EdgeInsets.fromLTRB(
                                  14, 0, 14, 14),
                              leading: CircleAvatar(
                                radius: 16,
                                backgroundColor:
                                    item.color.withValues(alpha: 0.16),
                                child: Icon(item.icon,
                                    color: item.color, size: 17),
                              ),
                              title: Text(
                                item.question,
                                style: GoogleFonts.inter(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                item.category,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: item.color,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              children: [
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    item.answer,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      height: 1.5,
                                      color: isDark
                                          ? const Color(0xFFCBD5E1)
                                          : const Color(0xFF334155),
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
    );
  }
}
