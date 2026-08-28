import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../app/theme/app_colors.dart';
import '../../auth/data/repositories/auth_repository.dart';
import '../data/repositories/client_repository.dart';
import '../domain/models/client_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ENTRY POINT: inserido diretamente no miolo do DashboardPage (sem Scaffold)
// ─────────────────────────────────────────────────────────────────────────────
class ClientsView extends StatefulWidget {
  const ClientsView({super.key});

  @override
  State<ClientsView> createState() => _ClientsViewState();
}

class _ClientsViewState extends State<ClientsView> {
  bool _showForm = false;
  ClientModel? _editingClient;

  @override
  Widget build(BuildContext context) {
    if (_showForm) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: SizedBox(
            width: 580,
            child: _ClientFormCard(
              client: _editingClient,
              onBack: () => setState(() {
                _showForm = false;
                _editingClient = null;
              }),
              onSuccess: () => setState(() {
                _showForm = false;
                _editingClient = null;
              }),
            ),
          ),
        ),
      );
    }

    return _ClientTableView(
      onAddNew: () => setState(() {
        _editingClient = null;
        _showForm = true;
      }),
      onEdit: (client) => setState(() {
        _editingClient = client;
        _showForm = true;
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TABELA: ocupa TODO o espaço disponível do miolo usando SizedBox.expand
// ─────────────────────────────────────────────────────────────────────────────
class _ClientTableView extends StatefulWidget {
  final VoidCallback onAddNew;
  final ValueChanged<ClientModel> onEdit;

  const _ClientTableView({required this.onAddNew, required this.onEdit});

  @override
  State<_ClientTableView> createState() => _ClientTableViewState();
}

class _ClientTableViewState extends State<_ClientTableView> {
  late final ClientRepository _repo;
  final _searchCtrl = TextEditingController();
  String _query = '';
  String? _companyId;

  @override
  void initState() {
    super.initState();
    try {
      _repo = Modular.get<ClientRepository>();
    } catch (_) {
      _repo = ClientRepository();
    }
    _loadCompanyId();
  }

  Future<void> _loadCompanyId() async {
    try {
      AuthRepository auth;
      try {
        auth = Modular.get<AuthRepository>();
      } catch (_) {
        auth = AuthRepository();
      }
      final cid = await auth.getCurrentCompanyId();
      if (mounted) setState(() => _companyId = cid);
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cabeçalho ───────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Gestão de Clientes',
                      style: GoogleFonts.outfit(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Cadastro e controle de clientes e prospectos',
                      style: GoogleFonts.inter(
                          fontSize: 14, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: widget.onAddNew,
                    borderRadius: BorderRadius.circular(12),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 11),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.person_add_rounded,
                                size: 18, color: Colors.white),
                            const SizedBox(width: 8),
                            Text(
                              'NOVO CLIENTE',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
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

            const SizedBox(height: 20),

            // ── Busca ─────────────────────────────────────────────────────
            SizedBox(
              width: 380,
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) =>
                    setState(() => _query = v.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Buscar por nome, e-mail ou empresa...',
                  hintStyle: GoogleFonts.inter(
                      fontSize: 13, color: const Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: Color(0xFF64748B), size: 20),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                        color: AppColors.primary, width: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Tabela ────────────────────────────────────────────────────
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    children: [
                      _ClientTableHeader(),
                      const Divider(height: 1, color: AppColors.divider),
                      Expanded(
                        child: StreamBuilder<List<ClientModel>>(
                          stream: _repo.getClientsStream(companyId: _companyId),
                          builder: (ctx, snap) {
                            if (_companyId == null ||
                                snap.connectionState ==
                                    ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(
                                    color: AppColors.primary),
                              );
                            }
                            if (snap.hasError) {
                              return Center(
                                child: Text(
                                  'Erro ao carregar clientes:\n${snap.error}',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                      color: const Color(0xFF64748B)),
                                ),
                              );
                            }

                            final all = snap.data ?? [];
                            final filtered = _query.isEmpty
                                ? all
                                : all
                                    .where((c) =>
                                        c.name
                                            .toLowerCase()
                                            .contains(_query) ||
                                        c.email
                                            .toLowerCase()
                                            .contains(_query) ||
                                        (c.company
                                                ?.toLowerCase()
                                                .contains(_query) ??
                                            false))
                                    .toList();

                            if (filtered.isEmpty) {
                              return _ClientEmptyState(
                                isEmpty: all.isEmpty,
                                onAdd: widget.onAddNew,
                              );
                            }

                            return ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const Divider(
                                  height: 1, color: AppColors.divider),
                              itemBuilder: (_, i) => _ClientRow(
                                client: filtered[i],
                                onEdit: () => widget.onEdit(filtered[i]),
                                onDelete: () =>
                                    _showDeleteDialog(filtered[i]),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(ClientModel client) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Color(0xFFEF4444), size: 26),
            const SizedBox(width: 10),
            Text('Excluir Cliente',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Remover "${client.name}"? Essa ação não pode ser desfeita.',
          style: GoogleFonts.inter(
              fontSize: 14, color: const Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CANCELAR',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final messenger = ScaffoldMessenger.of(context);
              try {
                await _repo.deleteClient(client.id);
                if (!mounted) return;
                messenger.showSnackBar(const SnackBar(
                  content: Text('Cliente removido com sucesso.'),
                  backgroundColor: Color(0xFF10B981),
                  behavior: SnackBarBehavior.floating,
                ));
              } catch (e) {
                if (!mounted) return;
                messenger.showSnackBar(SnackBar(
                  content: Text('Erro ao remover: $e'),
                  backgroundColor: const Color(0xFFEF4444),
                  behavior: SnackBarBehavior.floating,
                ));
              }
            },
            child: const Text('EXCLUIR'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cabeçalho da tabela
// ─────────────────────────────────────────────────────────────────────────────
class _ClientTableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      color: const Color(0xFFF8FAFC),
      child: Row(
        children: [
          _col('CLIENTE', flex: 3),
          _col('E-MAIL / TELEFONE', flex: 3),
          _col('TIPO', flex: 2),
          _col('STATUS', flex: 2),
          _col('CADASTRO', flex: 2),
          const SizedBox(width: 88),
        ],
      ),
    );
  }

  Widget _col(String label, {required int flex}) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontWeight: FontWeight.bold,
          fontSize: 11,
          color: const Color(0xFF64748B),
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Linha de cliente
// ─────────────────────────────────────────────────────────────────────────────
class _ClientRow extends StatelessWidget {
  final ClientModel client;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ClientRow({
    required this.client,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Row(
        children: [
          // Avatar + Nome
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: client.type == ClientType.company
                        ? const LinearGradient(
                            colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      client.name.isNotEmpty
                          ? client.name[0].toUpperCase()
                          : 'C',
                      style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        client.name,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF0F172A)),
                      ),
                      if (client.city != null && client.city!.isNotEmpty)
                        Text(
                          '${client.city}${client.state != null ? ' - ${client.state}' : ''}',
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFF94A3B8)),
                        )
                      else if (client.company != null)
                        Text(
                          client.company!,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFF94A3B8)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // E-mail + Telefone
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  client.email,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                      fontSize: 13, color: const Color(0xFF334155)),
                ),
                if (client.phone != null)
                  Text(
                    client.phone!,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        fontSize: 11, color: const Color(0xFF94A3B8)),
                  ),
              ],
            ),
          ),
          // Tipo
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _TypeBadge(type: client.type),
            ),
          ),
          // Status
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _ClientStatusBadge(status: client.status),
            ),
          ),
          // Data
          Expanded(
            flex: 2,
            child: Text(
              '${client.createdAt.day.toString().padLeft(2, '0')}/'
              '${client.createdAt.month.toString().padLeft(2, '0')}/'
              '${client.createdAt.year}',
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                  fontSize: 12, color: const Color(0xFF64748B)),
            ),
          ),
          // Ações
          SizedBox(
            width: 88,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Editar',
                  icon: const Icon(Icons.edit_outlined,
                      color: Color(0xFF6366F1), size: 18),
                  onPressed: onEdit,
                ),
                IconButton(
                  tooltip: 'Excluir',
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: Color(0xFFEF4444), size: 18),
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Badge de Tipo
// ─────────────────────────────────────────────────────────────────────────────
class _TypeBadge extends StatelessWidget {
  final ClientType type;

  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final isCompany = type == ClientType.company;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isCompany
            ? const Color(0xFFE0F2FE)
            : const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isCompany
              ? const Color(0xFF7DD3FC)
              : const Color(0xFFC7D2FE),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCompany ? Icons.business_rounded : Icons.person_rounded,
            size: 11,
            color: isCompany
                ? const Color(0xFF0284C7)
                : const Color(0xFF4F46E5),
          ),
          const SizedBox(width: 4),
          Text(
            type.label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isCompany
                  ? const Color(0xFF0284C7)
                  : const Color(0xFF4F46E5),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Badge de Status
// ─────────────────────────────────────────────────────────────────────────────
class _ClientStatusBadge extends StatelessWidget {
  final ClientStatus status;

  const _ClientStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, bg, border, icon) = switch (status) {
      ClientStatus.active => (
          const Color(0xFF059669),
          const Color(0xFFD1FAE5),
          const Color(0xFF6EE7B7),
          Icons.check_circle_outline_rounded,
        ),
      ClientStatus.prospect => (
          const Color(0xFFD97706),
          const Color(0xFFFEF3C7),
          const Color(0xFFFCD34D),
          Icons.star_outline_rounded,
        ),
      ClientStatus.inactive => (
          const Color(0xFF64748B),
          const Color(0xFFF1F5F9),
          const Color(0xFFCBD5E1),
          Icons.pause_circle_outline_rounded,
        ),
      ClientStatus.blocked => (
          const Color(0xFFDC2626),
          const Color(0xFFFEF2F2),
          const Color(0xFFFCA5A5),
          Icons.block_rounded,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Estado vazio
// ─────────────────────────────────────────────────────────────────────────────
class _ClientEmptyState extends StatelessWidget {
  final bool isEmpty;
  final VoidCallback onAdd;

  const _ClientEmptyState({required this.isEmpty, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
                color: Color(0xFFEEF2FF), shape: BoxShape.circle),
            child: const Icon(Icons.people_alt_outlined,
                color: AppColors.primary, size: 40),
          ),
          const SizedBox(height: 16),
          Text(
            isEmpty ? 'Nenhum cliente cadastrado' : 'Nenhum resultado',
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: const Color(0xFF1E293B)),
          ),
          const SizedBox(height: 6),
          Text(
            isEmpty
                ? 'Clique em "+ NOVO CLIENTE" para começar.'
                : 'Tente outro termo de busca.',
            style: GoogleFonts.inter(
                color: const Color(0xFF64748B), fontSize: 13),
          ),
          if (isEmpty) ...[
            const SizedBox(height: 20),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onAdd,
                borderRadius: BorderRadius.circular(12),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person_add_rounded,
                            size: 18, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          'Cadastrar Primeiro Cliente',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
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
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FORMULÁRIO DE CADASTRO / EDIÇÃO — busca de CEP automática via ViaCEP
// ─────────────────────────────────────────────────────────────────────────────
class _ClientFormCard extends StatefulWidget {
  final ClientModel? client; // null = novo, não-null = edição
  final VoidCallback onBack;
  final VoidCallback onSuccess;

  const _ClientFormCard({
    this.client,
    required this.onBack,
    required this.onSuccess,
  });

  @override
  State<_ClientFormCard> createState() => _ClientFormCardState();
}

class _ClientFormCardState extends State<_ClientFormCard> {
  late final ClientRepository _repo;

  // ── Controllers de dados básicos ─────────────────────────────────────────
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _documentCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();

  // ── Controllers de endereço estruturado ──────────────────────────────────
  final _zipCtrl = TextEditingController();
  final _streetCtrl = TextEditingController();
  final _numberCtrl = TextEditingController();
  final _complementCtrl = TextEditingController();
  final _neighborhoodCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();

  final _notesCtrl = TextEditingController();

  // Foco automático no campo número após busca de CEP
  final _numberFocus = FocusNode();

  ClientType _type = ClientType.person;
  ClientStatus _status = ClientStatus.active;
  bool _isLoading = false;
  bool _isCepLoading = false;
  String? _errorMessage;
  String? _cepError;

  // Quando true: logradouro/bairro/cidade/UF foram preenchidos pelo CEP
  // e ficam somente-leitura (fundo cinza), podendo ser desbloqueados pelo X
  bool _addressLocked = false;

  bool get _isEditing => widget.client != null;

  @override
  void initState() {
    super.initState();
    try {
      _repo = Modular.get<ClientRepository>();
    } catch (_) {
      _repo = ClientRepository();
    }

    if (_isEditing) {
      final c = widget.client!;
      _nameCtrl.text = c.name;
      _emailCtrl.text = c.email;
      _phoneCtrl.text = c.phone ?? '';
      _documentCtrl.text = c.document ?? '';
      _companyCtrl.text = c.company ?? '';
      _zipCtrl.text = c.zipCode ?? '';
      _streetCtrl.text = c.street ?? '';
      _numberCtrl.text = c.addressNumber ?? '';
      _complementCtrl.text = c.complement ?? '';
      _neighborhoodCtrl.text = c.neighborhood ?? '';
      _cityCtrl.text = c.city ?? '';
      _stateCtrl.text = c.state ?? '';
      _notesCtrl.text = c.notes ?? '';
      _type = c.type;
      _status = c.status;
      if (c.street != null && c.street!.isNotEmpty) {
        _addressLocked = true;
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _documentCtrl.dispose();
    _companyCtrl.dispose();
    _zipCtrl.dispose();
    _streetCtrl.dispose();
    _numberCtrl.dispose();
    _complementCtrl.dispose();
    _neighborhoodCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _notesCtrl.dispose();
    _numberFocus.dispose();
    super.dispose();
  }

  // ── Busca ViaCEP ─────────────────────────────────────────────────────────
  Future<void> _searchCep(String rawCep) async {
    final cep = rawCep.replaceAll(RegExp(r'\D'), '');
    if (cep.length != 8) return;

    setState(() {
      _isCepLoading = true;
      _cepError = null;
    });

    try {
      final uri = Uri.parse('https://viacep.com.br/ws/$cep/json/');
      final response = await http.get(uri);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        if (data.containsKey('erro') && data['erro'] == true) {
          setState(() => _cepError = 'CEP não encontrado.');
          return;
        }

        setState(() {
          _streetCtrl.text = data['logradouro'] as String? ?? '';
          _complementCtrl.text = data['complemento'] as String? ?? '';
          _neighborhoodCtrl.text = data['bairro'] as String? ?? '';
          _cityCtrl.text = data['localidade'] as String? ?? '';
          _stateCtrl.text = data['uf'] as String? ?? '';
          _addressLocked = true;
          _cepError = null;
        });

        // Mover foco para o campo Número
        _numberFocus.requestFocus();
      } else {
        setState(() =>
            _cepError = 'Erro ao consultar CEP (${response.statusCode}).');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _cepError = 'Sem conexão ou serviço indisponível.');
      }
    } finally {
      if (mounted) setState(() => _isCepLoading = false);
    }
  }

  void _clearAddress() {
    setState(() {
      _addressLocked = false;
      _zipCtrl.clear();
      _streetCtrl.clear();
      _numberCtrl.clear();
      _complementCtrl.clear();
      _neighborhoodCtrl.clear();
      _cityCtrl.clear();
      _stateCtrl.clear();
    });
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();

    if (name.isEmpty || email.isEmpty) {
      setState(() => _errorMessage = 'Nome e e-mail são obrigatórios.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final messenger = ScaffoldMessenger.of(context);

    String? n(String? v) =>
        (v == null || v.trim().isEmpty) ? null : v.trim();

    try {
      if (_isEditing) {
        await _repo.updateClient(widget.client!.copyWith(
          name: name,
          email: email,
          phone: n(_phoneCtrl.text),
          document: n(_documentCtrl.text),
          type: _type,
          status: _status,
          company: n(_companyCtrl.text),
          zipCode: n(_zipCtrl.text),
          street: n(_streetCtrl.text),
          addressNumber: n(_numberCtrl.text),
          complement: n(_complementCtrl.text),
          neighborhood: n(_neighborhoodCtrl.text),
          city: n(_cityCtrl.text),
          state: n(_stateCtrl.text),
          notes: n(_notesCtrl.text),
          updatedAt: DateTime.now(),
        ));
      } else {
        AuthRepository auth;
        try {
          auth = Modular.get<AuthRepository>();
        } catch (_) {
          auth = AuthRepository();
        }
        final companyId = await auth.getCurrentCompanyId();

        await _repo.createClient(
          name: name,
          email: email,
          phone: n(_phoneCtrl.text),
          document: n(_documentCtrl.text),
          type: _type,
          company: n(_companyCtrl.text),
          zipCode: n(_zipCtrl.text),
          street: n(_streetCtrl.text),
          addressNumber: n(_numberCtrl.text),
          complement: n(_complementCtrl.text),
          neighborhood: n(_neighborhoodCtrl.text),
          city: n(_cityCtrl.text),
          state: n(_stateCtrl.text),
          notes: n(_notesCtrl.text),
          companyId: companyId,
        );
      }

      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text(_isEditing
            ? 'Cliente atualizado com sucesso!'
            : 'Cliente cadastrado com sucesso!'),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ));
      widget.onSuccess();
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Erro: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Botão Voltar ──────────────────────────────────────────────────
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF64748B),
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 6),
              ),
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: Text('Voltar para a Lista',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ),
          const SizedBox(height: 12),

          // ── Cabeçalho ────────────────────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: _isEditing
                      ? const LinearGradient(
                          colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _isEditing
                      ? Icons.edit_note_rounded
                      : Icons.person_add_alt_1_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isEditing ? 'Editar Cliente' : 'Novo Cliente',
                      style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary),
                    ),
                    Text(
                      _isEditing
                          ? 'Atualize os dados do cliente'
                          : 'Preencha os dados do novo cliente',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: AppColors.divider),
          const SizedBox(height: 16),

          // ── Erro global ───────────────────────────────────────────────────
          if (_errorMessage != null) ...[
            _ErrorBanner(message: _errorMessage!),
            const SizedBox(height: 16),
          ],

          // ── Tipo de Cliente ───────────────────────────────────────────────
          _label('Tipo de Cliente'),
          const SizedBox(height: 8),
          Row(
            children: ClientType.values.map((t) {
              final selected = _type == t;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                      right: t == ClientType.person ? 8 : 0),
                  child: GestureDetector(
                    onTap: () => setState(() => _type = t),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary.withValues(alpha: 0.08)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : AppColors.border,
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            t == ClientType.person
                                ? Icons.person_rounded
                                : Icons.business_rounded,
                            size: 16,
                            color: selected
                                ? AppColors.primary
                                : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            t.label,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: selected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: selected
                                  ? AppColors.primary
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // ── Nome ──────────────────────────────────────────────────────────
          _label('Nome Completo *'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              hintText: 'Nome do cliente',
              prefixIcon:
                  Icon(Icons.person_outline, color: Color(0xFF64748B)),
            ),
          ),
          const SizedBox(height: 14),

          // ── E-mail ────────────────────────────────────────────────────────
          _label('E-mail *'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              hintText: 'cliente@exemplo.com',
              prefixIcon:
                  Icon(Icons.email_outlined, color: Color(0xFF64748B)),
            ),
          ),
          const SizedBox(height: 14),

          // ── Telefone + Documento ──────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Telefone'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        hintText: '(11) 99999-0000',
                        prefixIcon: Icon(Icons.phone_outlined,
                            color: Color(0xFF64748B)),
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
                    _label(_type == ClientType.person ? 'CPF' : 'CNPJ'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _documentCtrl,
                      decoration: InputDecoration(
                        hintText: _type == ClientType.person
                            ? '000.000.000-00'
                            : '00.000.000/0000-00',
                        prefixIcon: const Icon(Icons.badge_outlined,
                            color: Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Empresa (só PF) ───────────────────────────────────────────────
          if (_type == ClientType.person) ...[
            _label('Empresa (opcional)'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _companyCtrl,
              decoration: const InputDecoration(
                hintText: 'Nome da empresa onde trabalha',
                prefixIcon: Icon(Icons.business_outlined,
                    color: Color(0xFF64748B)),
              ),
            ),
            const SizedBox(height: 14),
          ],

          // ── Seção: Endereço ───────────────────────────────────────────────
          _SectionHeader(
            icon: Icons.location_on_rounded,
            title: 'Endereço',
            subtitle: 'Digite o CEP para preenchimento automático',
          ),
          const SizedBox(height: 12),

          // ── CEP + banner ──────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Campo CEP
              SizedBox(
                width: 190,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('CEP'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _zipCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 9,
                      onChanged: (v) {
                        final digits = v.replaceAll(RegExp(r'\D'), '');
                        if (digits.length == 8) _searchCep(digits);
                        if (digits.length < 8 && _addressLocked) {
                          setState(() => _addressLocked = false);
                        }
                      },
                      decoration: InputDecoration(
                        hintText: '00000-000',
                        counterText: '',
                        prefixIcon: const Icon(Icons.pin_drop_outlined,
                            color: Color(0xFF64748B)),
                        suffixIcon: _isCepLoading
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primary,
                                  ),
                                ),
                              )
                            : _addressLocked
                                ? Tooltip(
                                    message: 'Limpar endereço',
                                    child: IconButton(
                                      icon: const Icon(Icons.clear_rounded,
                                          size: 18,
                                          color: Color(0xFF94A3B8)),
                                      onPressed: _clearAddress,
                                    ),
                                  )
                                : null,
                      ),
                    ),
                    if (_cepError != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _cepError!,
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xFFEF4444)),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Banner de status do endereço
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 26),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: _addressLocked
                          ? const Color(0xFFD1FAE5)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _addressLocked
                            ? const Color(0xFF6EE7B7)
                            : AppColors.border,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _addressLocked
                              ? Icons.check_circle_rounded
                              : Icons.info_outline_rounded,
                          color: _addressLocked
                              ? const Color(0xFF059669)
                              : const Color(0xFF94A3B8),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _addressLocked
                                ? 'Endereço preenchido automaticamente'
                                : 'Digite o CEP para preencher',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: _addressLocked
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: _addressLocked
                                  ? const Color(0xFF065F46)
                                  : const Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Logradouro + Número ───────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Logradouro'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _streetCtrl,
                      readOnly: _addressLocked,
                      decoration: InputDecoration(
                        hintText: 'Rua, Avenida, Praça...',
                        filled: _addressLocked,
                        fillColor: _addressLocked
                            ? const Color(0xFFF1F5F9)
                            : null,
                        prefixIcon: const Icon(Icons.edit_road_rounded,
                            color: Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 100,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Número'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _numberCtrl,
                      focusNode: _numberFocus,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: 'Nº',
                        prefixIcon: Icon(Icons.tag_rounded,
                            color: Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Complemento + Bairro ──────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Complemento'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _complementCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Apto, Sala, Bloco...',
                        prefixIcon: Icon(Icons.layers_outlined,
                            color: Color(0xFF64748B)),
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
                    _label('Bairro'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _neighborhoodCtrl,
                      readOnly: _addressLocked,
                      decoration: InputDecoration(
                        hintText: 'Bairro',
                        filled: _addressLocked,
                        fillColor: _addressLocked
                            ? const Color(0xFFF1F5F9)
                            : null,
                        prefixIcon: const Icon(Icons.map_outlined,
                            color: Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Cidade + UF ───────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Cidade'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _cityCtrl,
                      readOnly: _addressLocked,
                      decoration: InputDecoration(
                        hintText: 'Cidade',
                        filled: _addressLocked,
                        fillColor: _addressLocked
                            ? const Color(0xFFF1F5F9)
                            : null,
                        prefixIcon: const Icon(Icons.location_city_rounded,
                            color: Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 80,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('UF'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _stateCtrl,
                      readOnly: _addressLocked,
                      maxLength: 2,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        hintText: 'SP',
                        counterText: '',
                        filled: _addressLocked,
                        fillColor: _addressLocked
                            ? const Color(0xFFF1F5F9)
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Status (só na edição) ─────────────────────────────────────────
          if (_isEditing) ...[
            _label('Status'),
            const SizedBox(height: 8),
            DropdownButtonFormField<ClientStatus>(
              initialValue: _status,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.toggle_on_outlined,
                    color: Color(0xFF64748B)),
              ),
              items: ClientStatus.values
                  .map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(s.label,
                            style: GoogleFonts.inter(fontSize: 14)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _status = v!),
            ),
            const SizedBox(height: 14),
          ],

          // ── Observações ───────────────────────────────────────────────────
          _label('Observações (opcional)'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _notesCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Anotações sobre o cliente...',
              prefixIcon:
                  Icon(Icons.notes_rounded, color: Color(0xFF64748B)),
            ),
          ),
          const SizedBox(height: 24),

          // ── Botão Salvar/Cadastrar ─────────────────────────────────────────
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 2,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _isLoading ? null : _submit,
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5),
                  )
                : Text(
                    _isEditing
                        ? 'SALVAR ALTERAÇÕES'
                        : 'CADASTRAR CLIENTE',
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF475569),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets auxiliares reutilizáveis
// ─────────────────────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFC7D2FE)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: const Color(0xFF4F46E5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline,
              color: Color(0xFFEF4444), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                color: const Color(0xFF991B1B),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
