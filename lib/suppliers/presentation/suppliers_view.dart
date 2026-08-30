import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../app/theme/app_colors.dart';
import '../../auth/data/repositories/auth_repository.dart';
import '../../auth/domain/models/user_model.dart';
import '../../products/presentation/category_dialogs.dart';
import '../data/repositories/supplier_repository.dart';
import '../domain/models/supplier_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ENTRY POINT: Inserido diretamente no miolo do DashboardPage (SPA Container)
// ─────────────────────────────────────────────────────────────────────────────
class SuppliersView extends StatefulWidget {
  final UserModel? currentUser;

  const SuppliersView({super.key, this.currentUser});

  @override
  State<SuppliersView> createState() => _SuppliersViewState();
}

class _SuppliersViewState extends State<SuppliersView> {
  bool _showForm = false;
  SupplierModel? _editingSupplier;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_showForm) {
          return SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: SizedBox(
                  width: 760,
                  child: _SupplierFormCard(
                    supplier: _editingSupplier,
                    onBack: () => setState(() {
                      _showForm = false;
                      _editingSupplier = null;
                    }),
                    onSuccess: () => setState(() {
                      _showForm = false;
                      _editingSupplier = null;
                    }),
                  ),
                ),
              ),
            ),
          );
        }

        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: _SupplierTableView(
            currentUser: widget.currentUser,
            onAddNew: () => setState(() {
              _editingSupplier = null;
              _showForm = true;
            }),
            onEdit: (supplier) => setState(() {
              _editingSupplier = supplier;
              _showForm = true;
            }),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. TABELA DE FORNECEDORES
// ─────────────────────────────────────────────────────────────────────────────
class _SupplierTableView extends StatefulWidget {
  final UserModel? currentUser;
  final VoidCallback onAddNew;
  final ValueChanged<SupplierModel> onEdit;

  const _SupplierTableView({
    this.currentUser,
    required this.onAddNew,
    required this.onEdit,
  });

  @override
  State<_SupplierTableView> createState() => _SupplierTableViewState();
}

class _SupplierTableViewState extends State<_SupplierTableView> {
  late final SupplierRepository _repo;
  late final AuthRepository _authRepo;
  StreamSubscription<UserModel?>? _userSub;
  final _searchCtrl = TextEditingController();
  String _query = '';
  SupplierStatus? _filterStatus;
  String? _companyId;
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    try {
      _repo = Modular.get<SupplierRepository>();
    } catch (_) {
      _repo = SupplierRepository();
    }
    try {
      _authRepo = Modular.get<AuthRepository>();
    } catch (_) {
      _authRepo = AuthRepository();
    }
    _currentUser = widget.currentUser;
    _userSub = _authRepo.getCurrentUserStream().listen((user) {
      if (mounted) {
        setState(() {
          _currentUser = user;
          _companyId = user?.effectiveCompanyId ?? _companyId;
        });
      }
    });
    _loadCompanyId();
  }

  Future<void> _loadCompanyId() async {
    try {
      final user = await _authRepo.getCurrentUser();
      final cid = user?.effectiveCompanyId ?? await _authRepo.getCurrentCompanyId();
      if (mounted) {
        setState(() {
          _currentUser = user;
          _companyId = cid;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _userSub?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showDeleteDialog(SupplierModel supplier) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 24),
            const SizedBox(width: 8),
            Text(
              'Excluir Fornecedor',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Deseja realmente remover "${supplier.displayName}"?\nEsta ação não poderá ser desfeita.',
          style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'CANCELAR',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                Navigator.pop(ctx);
                await _repo.deleteSupplier(supplier.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Fornecedor removido com sucesso!'),
                    backgroundColor: Color(0xFF10B981),
                    behavior: SnackBarBehavior.floating,
                  ));
                }
              },
              borderRadius: BorderRadius.circular(10),
              child: Ink(
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Text(
                  'EXCLUIR',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Padding(
      padding: EdgeInsets.all(isMobile ? 14 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Cabeçalho do Painel ───────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gestão de Fornecedores',
                      style: GoogleFonts.outfit(
                        fontSize: isMobile ? 20 : 24,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Cadastro de distribuidores e parceiros comerciais',
                      style: GoogleFonts.inter(fontSize: isMobile ? 12 : 13, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),

              // Botão Novo Fornecedor
              if (widget.currentUser?.canCreateSuppliers ?? _currentUser?.canCreateSuppliers ?? false) ...[
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
                      padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 14 : 20, vertical: isMobile ? 9 : 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            isMobile ? 'NOVO' : 'NOVO FORNECEDOR',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: isMobile ? 12 : 13,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),

          SizedBox(height: isMobile ? 14 : 24),

          // ── Barra de Busca & Filtros ──────────────────────────────────────
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: isMobile ? double.infinity : 360,
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: isMobile ? 'Buscar fornecedor...' : 'Buscar por nome, razão social, CNPJ ou e-mail...',
                    hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
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
                      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                  ),
                ),
              ),

              // Filtro por Status
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<SupplierStatus?>(
                    value: _filterStatus,
                    hint: Text(
                      'Status: Todos',
                      style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text('Todos os Status', style: GoogleFonts.inter(fontSize: 13)),
                      ),
                      ...SupplierStatus.values.map(
                        (s) => DropdownMenuItem(
                          value: s,
                          child: Text(s.label, style: GoogleFonts.inter(fontSize: 13)),
                        ),
                      ),
                    ],
                    onChanged: (val) => setState(() => _filterStatus = val),
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: isMobile ? 12 : 20),

          // ── Tabela (Desktop) / Lista de Cards (Mobile) ───────────────────
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isMobile ? Colors.transparent : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: isMobile ? null : Border.all(color: AppColors.border),
                boxShadow: isMobile
                    ? null
                    : [
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
                    if (!isMobile) ...[
                      const _SupplierTableHeader(),
                      const Divider(height: 1, color: AppColors.divider),
                    ],
                    Expanded(
                      child: StreamBuilder<List<SupplierModel>>(
                        stream: _repo.getSuppliersStream(companyId: _companyId),
                        builder: (ctx, snap) {
                          if (_companyId == null || snap.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                          }
                          if (snap.hasError) {
                            return Center(
                              child: Text(
                                'Erro ao carregar fornecedores:\n${snap.error}',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(color: const Color(0xFF64748B)),
                              ),
                            );
                          }

                          final all = snap.data ?? [];
                          final filtered = all.where((s) {
                            final matchesQuery = _query.isEmpty ||
                                s.corporateName.toLowerCase().contains(_query) ||
                                s.tradeName.toLowerCase().contains(_query) ||
                                (s.cnpj?.contains(_query) ?? false) ||
                                s.email.toLowerCase().contains(_query);

                            final matchesStatus = _filterStatus == null || s.status == _filterStatus;
                            return matchesQuery && matchesStatus;
                          }).toList();

                          if (filtered.isEmpty) {
                            return _SupplierEmptyState(
                              isEmpty: all.isEmpty,
                              onAdd: widget.onAddNew,
                            );
                          }

                          if (isMobile) {
                            return ListView.builder(
                              itemCount: filtered.length,
                              padding: EdgeInsets.zero,
                              itemBuilder: (_, i) => _SupplierMobileCard(
                                supplier: filtered[i],
                                onEdit: () => widget.onEdit(filtered[i]),
                                onDelete: () => _showDeleteDialog(filtered[i]),
                              ),
                            );
                          }

                          return ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.divider),
                            itemBuilder: (_, i) => _SupplierRow(
                              supplier: filtered[i],
                              onEdit: () => widget.onEdit(filtered[i]),
                              onDelete: () => _showDeleteDialog(filtered[i]),
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPONENTES DA TABELA
// ─────────────────────────────────────────────────────────────────────────────
class _SupplierTableHeader extends StatelessWidget {
  const _SupplierTableHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          _cell('FORNECEDOR / RAZÃO SOCIAL', flex: 4),
          _cell('CONTATO / REPRESENTANTE', flex: 3),
          _cell('RAMO / CATEGORIA', flex: 2),
          _cell('LOCALIZAÇÃO', flex: 2),
          _cell('STATUS', flex: 2),
          const SizedBox(width: 88, child: Text('AÇÕES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
        ],
      ),
    );
  }

  Widget _cell(String title, {required int flex}) {
    return Expanded(
      flex: flex,
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF64748B),
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _SupplierRow extends StatelessWidget {
  final SupplierModel supplier;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SupplierRow({
    required this.supplier,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          // 1. Fornecedor
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.local_shipping_rounded, color: Color(0xFF0284C7), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        supplier.displayName,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                      ),
                      Text(
                        supplier.corporateName.isNotEmpty && supplier.corporateName != supplier.displayName
                            ? supplier.corporateName
                            : (supplier.cnpj != null && supplier.cnpj!.isNotEmpty ? 'CNPJ: ${supplier.cnpj!}' : 'Fornecedor Cadastrado'),
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. Contato
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(supplier.email, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF0F172A))),
                Text(
                  supplier.contactPerson?.isNotEmpty == true
                      ? '${supplier.phone} (${supplier.contactPerson!})'
                      : supplier.phone,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                ),
              ],
            ),
          ),

          // 3. Ramo / Categoria
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  supplier.category?.isNotEmpty == true ? supplier.category! : 'Geral',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF6366F1)),
                ),
              ),
            ),
          ),

          // 4. Localização
          Expanded(
            flex: 2,
            child: Text(
              supplier.city?.isNotEmpty == true ? '${supplier.city!} - ${supplier.state ?? ''}' : 'Não informado',
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF475569)),
            ),
          ),

          // 5. Status
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _SupplierStatusBadge(status: supplier.status),
            ),
          ),

          // 6. Ações
          SizedBox(
            width: 88,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Editar',
                  icon: const Icon(Icons.edit_outlined, color: Color(0xFF6366F1), size: 18),
                  onPressed: onEdit,
                ),
                IconButton(
                  tooltip: 'Excluir',
                  icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 18),
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
// Card Mobile de Fornecedor
// ─────────────────────────────────────────────────────────────────────────────
class _SupplierMobileCard extends StatelessWidget {
  final SupplierModel supplier;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SupplierMobileCard({
    required this.supplier,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.business_rounded, color: Color(0xFF6366F1), size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            supplier.displayName,
                            style: GoogleFonts.inter(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (supplier.cnpj != null && supplier.cnpj!.isNotEmpty)
                            Text(
                              supplier.cnpj!,
                              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                            ),
                        ],
                      ),
                    ),
                    _SupplierStatusBadge(status: supplier.status),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(height: 1, color: AppColors.divider),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (supplier.phone.isNotEmpty) ...[
                      const Icon(Icons.phone_outlined, size: 12, color: Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Text(
                        supplier.phone,
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF475569)),
                      ),
                      const SizedBox(width: 10),
                    ],
                    if (supplier.city != null && supplier.city!.isNotEmpty) ...[
                      const Icon(Icons.location_on_outlined, size: 12, color: Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${supplier.city}${supplier.state != null ? "/${supplier.state}" : ""}',
                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF475569)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ] else
                      const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF6366F1)),
                      onPressed: onEdit,
                      tooltip: 'Editar',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                      onPressed: onDelete,
                      tooltip: 'Excluir',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SupplierStatusBadge extends StatelessWidget {
  final SupplierStatus status;
  const _SupplierStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: status.bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: status.textColor,
        ),
      ),
    );
  }
}

class _SupplierEmptyState extends StatelessWidget {
  final bool isEmpty;
  final VoidCallback onAdd;

  const _SupplierEmptyState({required this.isEmpty, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.local_shipping_outlined, size: 40, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 16),
            Text(
              isEmpty ? 'Nenhum fornecedor cadastrado' : 'Nenhum resultado encontrado',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 17, color: const Color(0xFF0F172A)),
            ),
            const SizedBox(height: 6),
            Text(
              isEmpty ? 'Cadastre seus fornecedores para associá-los aos produtos do catálogo.' : 'Tente buscar por outro termo ou altere o filtro.',
              style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 13),
            ),
            if (isEmpty) ...[
              const SizedBox(height: 20),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onAdd,
                  borderRadius: BorderRadius.circular(10),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                    child: Text(
                      'CADASTRAR PRIMEIRO FORNECEDOR',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. FORMULÁRIO DE CADASTRO / EDIÇÃO DE FORNECEDOR (COM VIACEP AUTO)
// ─────────────────────────────────────────────────────────────────────────────
class _SupplierFormCard extends StatefulWidget {
  final SupplierModel? supplier;
  final VoidCallback onBack;
  final VoidCallback onSuccess;

  const _SupplierFormCard({
    this.supplier,
    required this.onBack,
    required this.onSuccess,
  });

  @override
  State<_SupplierFormCard> createState() => _SupplierFormCardState();
}

class _SupplierFormCardState extends State<_SupplierFormCard> {
  late final SupplierRepository _repo;

  final _tradeNameCtrl = TextEditingController();
  final _corpNameCtrl = TextEditingController();
  final _cnpjCtrl = TextEditingController();
  final _ieCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();

  // Endereço (ViaCEP)
  final _zipCtrl = TextEditingController();
  final _streetCtrl = TextEditingController();
  final _numCtrl = TextEditingController();
  final _compCtrl = TextEditingController();
  final _neighborhoodCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();

  final _numFocus = FocusNode();

  final _paymentTermsCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  SupplierStatus _status = SupplierStatus.active;
  bool _isLoading = false;
  bool _isSearchingZip = false;
  String? _zipError;
  String? _errorMessage;

  bool get _isEditing => widget.supplier != null;

  @override
  void initState() {
    super.initState();
    try {
      _repo = Modular.get<SupplierRepository>();
    } catch (_) {
      _repo = SupplierRepository();
    }

    if (_isEditing) {
      final s = widget.supplier!;
      _tradeNameCtrl.text = s.tradeName;
      _corpNameCtrl.text = s.corporateName;
      _cnpjCtrl.text = s.cnpj ?? '';
      _ieCtrl.text = s.stateRegistration ?? '';
      _categoryCtrl.text = s.category ?? '';
      _emailCtrl.text = s.email;
      _phoneCtrl.text = s.phone;
      _contactCtrl.text = s.contactPerson ?? '';
      _zipCtrl.text = s.zipCode ?? '';
      _streetCtrl.text = s.street ?? '';
      _numCtrl.text = s.addressNumber ?? '';
      _compCtrl.text = s.complement ?? '';
      _neighborhoodCtrl.text = s.neighborhood ?? '';
      _cityCtrl.text = s.city ?? '';
      _stateCtrl.text = s.state ?? '';
      _paymentTermsCtrl.text = s.paymentTerms ?? '';
      _notesCtrl.text = s.notes ?? '';
      _status = s.status;
    }
  }

  @override
  void dispose() {
    _tradeNameCtrl.dispose();
    _corpNameCtrl.dispose();
    _cnpjCtrl.dispose();
    _ieCtrl.dispose();
    _categoryCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _contactCtrl.dispose();
    _zipCtrl.dispose();
    _streetCtrl.dispose();
    _numCtrl.dispose();
    _compCtrl.dispose();
    _neighborhoodCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _paymentTermsCtrl.dispose();
    _notesCtrl.dispose();
    _numFocus.dispose();
    super.dispose();
  }

  /// Consulta automática assíncrona na API pública ViaCEP
  Future<void> _searchZipCode(String rawZip) async {
    final clean = rawZip.replaceAll(RegExp(r'\D'), '');
    if (clean.length != 8) return;

    setState(() {
      _isSearchingZip = true;
      _zipError = null;
    });

    try {
      final url = Uri.parse('https://viacep.com.br/ws/$clean/json/');
      final res = await http.get(url).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        if (data.containsKey('erro') && data['erro'] == true) {
          if (mounted) setState(() => _zipError = 'CEP não encontrado.');
          return;
        }

        if (mounted) {
          setState(() {
            _streetCtrl.text = data['logradouro'] ?? '';
            _neighborhoodCtrl.text = data['bairro'] ?? '';
            _cityCtrl.text = data['localidade'] ?? '';
            _stateCtrl.text = data['uf'] ?? '';
            if (data['complemento'] != null && (data['complemento'] as String).isNotEmpty) {
              _compCtrl.text = data['complemento'];
            }
          });
          _numFocus.requestFocus();
        }
      }
    } catch (_) {
      if (mounted) setState(() => _zipError = 'Não foi possível consultar o CEP.');
    } finally {
      if (mounted) setState(() => _isSearchingZip = false);
    }
  }

  void _openCategorySelectorDialog() {
    showDialog(
      context: context,
      builder: (ctx) => CategorySelectorDialog(
        onSelect: (selectedTitle) {
          setState(() {
            _categoryCtrl.text = selectedTitle;
          });
        },
      ),
    );
  }

  Future<void> _submit() async {
    final tradeName = _tradeNameCtrl.text.trim();
    final corpName = _corpNameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();

    if (tradeName.isEmpty && corpName.isEmpty) {
      setState(() => _errorMessage = 'Informe o Nome Fantasia ou Razão Social.');
      return;
    }
    if (email.isEmpty) {
      setState(() => _errorMessage = 'Informe o e-mail principal para contato.');
      return;
    }
    if (phone.isEmpty) {
      setState(() => _errorMessage = 'Informe o telefone/WhatsApp de contato.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    String? n(String? v) => (v == null || v.trim().isEmpty) ? null : v.trim();

    try {
      if (_isEditing) {
        final updated = widget.supplier!.copyWith(
          tradeName: tradeName.isNotEmpty ? tradeName : corpName,
          corporateName: corpName.isNotEmpty ? corpName : tradeName,
          cnpj: n(_cnpjCtrl.text),
          stateRegistration: n(_ieCtrl.text),
          category: n(_categoryCtrl.text),
          email: email,
          phone: phone,
          contactPerson: n(_contactCtrl.text),
          zipCode: n(_zipCtrl.text),
          street: n(_streetCtrl.text),
          addressNumber: n(_numCtrl.text),
          complement: n(_compCtrl.text),
          neighborhood: n(_neighborhoodCtrl.text),
          city: n(_cityCtrl.text),
          state: n(_stateCtrl.text),
          paymentTerms: n(_paymentTermsCtrl.text),
          notes: n(_notesCtrl.text),
          status: _status,
        );
        await _repo.updateSupplier(updated);
      } else {
        AuthRepository auth;
        try {
          auth = Modular.get<AuthRepository>();
        } catch (_) {
          auth = AuthRepository();
        }
        final companyId = await auth.getCurrentCompanyId();

        await _repo.createSupplier(
          tradeName: tradeName.isNotEmpty ? tradeName : corpName,
          corporateName: corpName.isNotEmpty ? corpName : tradeName,
          cnpj: n(_cnpjCtrl.text),
          stateRegistration: n(_ieCtrl.text),
          category: n(_categoryCtrl.text),
          email: email,
          phone: phone,
          contactPerson: n(_contactCtrl.text),
          zipCode: n(_zipCtrl.text),
          street: n(_streetCtrl.text),
          addressNumber: n(_numCtrl.text),
          complement: n(_compCtrl.text),
          neighborhood: n(_neighborhoodCtrl.text),
          city: n(_cityCtrl.text),
          state: n(_stateCtrl.text),
          paymentTerms: n(_paymentTermsCtrl.text),
          notes: n(_notesCtrl.text),
          status: _status,
          companyId: companyId,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isEditing ? 'Fornecedor atualizado com sucesso!' : 'Fornecedor cadastrado com sucesso!'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ));
        widget.onSuccess();
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Erro ao salvar fornecedor: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 36),
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
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onBack,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_back_rounded, size: 16, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Text(
                        'Voltar para a Lista',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Cabeçalho do Formulário ───────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.local_shipping_rounded, color: Color(0xFF0284C7), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isEditing ? 'Editar Fornecedor' : 'Novo Fornecedor',
                      style: GoogleFonts.outfit(fontSize: isMobile ? 18 : 20, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                    ),
                    Text(
                      'Preencha os dados cadastrais e endereço',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(color: AppColors.divider),
          const SizedBox(height: 16),

          if (_errorMessage != null) ...[
            _SupplierErrorBanner(message: _errorMessage!),
            const SizedBox(height: 16),
          ],

          // ── SEÇÃO 1: DADOS DA EMPRESA ─────────────────────────────────────
          _sectionHeader(Icons.business_rounded, 'Dados da Empresa', 'Identificação cadastral e fiscal'),
          const SizedBox(height: 14),

          if (isMobile) ...[
            _label('Nome Fantasia *'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _tradeNameCtrl,
              decoration: const InputDecoration(
                hintText: 'Ex: Distribuidora Paulista',
                prefixIcon: Icon(Icons.storefront_outlined, color: Color(0xFF64748B)),
              ),
            ),
            const SizedBox(height: 12),
            _label('Razão Social'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _corpNameCtrl,
              decoration: const InputDecoration(
                hintText: 'Ex: Paulista Comércio Ltda',
                prefixIcon: Icon(Icons.apartment_rounded, color: Color(0xFF64748B)),
              ),
            ),
            const SizedBox(height: 12),
            _label('CNPJ'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _cnpjCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: '00.000.000/0001-00',
                prefixIcon: Icon(Icons.badge_outlined, color: Color(0xFF64748B)),
              ),
            ),
            const SizedBox(height: 12),
            _label('Inscrição Estadual (IE)'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _ieCtrl,
              decoration: const InputDecoration(
                hintText: 'Isento ou número da IE',
                prefixIcon: Icon(Icons.receipt_outlined, color: Color(0xFF64748B)),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _label('Ramo / Categoria'),
                Text(
                  'clique em + p/ Lista!',
                  style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _categoryCtrl,
              decoration: InputDecoration(
                hintText: 'Ex: Produtos de Limpeza...',
                prefixIcon: const Icon(Icons.category_outlined, color: Color(0xFF64748B)),
                suffixIcon: Tooltip(
                  message: 'Selecionar Categoria / Ramo',
                  child: IconButton(
                    icon: const Icon(Icons.playlist_add_rounded, color: AppColors.primary, size: 22),
                    onPressed: _openCategorySelectorDialog,
                  ),
                ),
              ),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Nome Fantasia *'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _tradeNameCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Ex: Distribuidora Paulista',
                          prefixIcon: Icon(Icons.storefront_outlined, color: Color(0xFF64748B)),
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
                      _label('Razão Social'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _corpNameCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Ex: Paulista Comércio e Distribuição Ltda',
                          prefixIcon: Icon(Icons.apartment_rounded, color: Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('CNPJ'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _cnpjCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          hintText: '00.000.000/0001-00',
                          prefixIcon: Icon(Icons.badge_outlined, color: Color(0xFF64748B)),
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
                      _label('Inscrição Estadual (IE)'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _ieCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Isento ou número da IE',
                          prefixIcon: Icon(Icons.receipt_outlined, color: Color(0xFF64748B)),
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _label('Ramo / Categoria'),
                          Text(
                            'clique em + p/ Lista!',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _categoryCtrl,
                        decoration: InputDecoration(
                          hintText: 'Ex: Produtos de Limpeza, Embalagens...',
                          prefixIcon: const Icon(Icons.category_outlined, color: Color(0xFF64748B)),
                          suffixIcon: Tooltip(
                            message: 'Selecionar Categoria / Ramo (Popup com Ícones e Cores)',
                            child: IconButton(
                              icon: const Icon(Icons.playlist_add_rounded, color: AppColors.primary, size: 22),
                              onPressed: _openCategorySelectorDialog,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 20),

          // ── SEÇÃO 2: CONTATO & ATENDIMENTO ────────────────────────────────
          _sectionHeader(Icons.contact_phone_outlined, 'Contato & Atendimento', 'Canais de comunicação e pedidos'),
          const SizedBox(height: 14),

          if (isMobile) ...[
            _label('E-mail Principal *'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                hintText: 'pedidos@fornecedor.com.br',
                prefixIcon: Icon(Icons.email_outlined, color: Color(0xFF64748B)),
              ),
            ),
            const SizedBox(height: 12),
            _label('Telefone / WhatsApp *'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                hintText: '(11) 99999-0000',
                prefixIcon: Icon(Icons.phone_outlined, color: Color(0xFF64748B)),
              ),
            ),
            const SizedBox(height: 12),
            _label('Representante / Vendedor'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _contactCtrl,
              decoration: const InputDecoration(
                hintText: 'Nome do seu contato',
                prefixIcon: Icon(Icons.person_outline_rounded, color: Color(0xFF64748B)),
              ),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('E-mail Principal *'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          hintText: 'pedidos@fornecedor.com.br',
                          prefixIcon: Icon(Icons.email_outlined, color: Color(0xFF64748B)),
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
                      _label('Telefone / WhatsApp *'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          hintText: '(11) 99999-0000',
                          prefixIcon: Icon(Icons.phone_outlined, color: Color(0xFF64748B)),
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
                      _label('Representante / Vendedor'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _contactCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Nome do seu contato',
                          prefixIcon: Icon(Icons.person_outline_rounded, color: Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 20),

          // ── SEÇÃO 3: ENDEREÇO & LOCALIZAÇÃO (VIACEP AUTO) ─────────────────
          _sectionHeader(Icons.location_on_outlined, 'Endereço & Localização', 'Preenchimento automático ao digitar o CEP'),
          const SizedBox(height: 14),

          if (isMobile) ...[
            _label('CEP (Auto-busca)'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _zipCtrl,
              keyboardType: TextInputType.number,
              maxLength: 9,
              onChanged: _searchZipCode,
              decoration: InputDecoration(
                hintText: '00000-000',
                counterText: '',
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
                suffixIcon: _isSearchingZip
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                      )
                    : null,
              ),
            ),
            if (_zipError != null) ...[
              const SizedBox(height: 4),
              Text(_zipError!, style: GoogleFonts.inter(color: const Color(0xFFEF4444), fontSize: 11)),
            ],
            const SizedBox(height: 12),
            _label('Logradouro / Rua'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _streetCtrl,
              decoration: const InputDecoration(
                hintText: 'Rua, Avenida, Alameda...',
                prefixIcon: Icon(Icons.home_outlined, color: Color(0xFF64748B)),
              ),
            ),
            const SizedBox(height: 12),
            _label('Número'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _numCtrl,
              focusNode: _numFocus,
              decoration: const InputDecoration(hintText: '123'),
            ),
            const SizedBox(height: 12),
            _label('Complemento'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _compCtrl,
              decoration: const InputDecoration(hintText: 'Galpão 3, Sala 10...'),
            ),
            const SizedBox(height: 12),
            _label('Bairro'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _neighborhoodCtrl,
              decoration: const InputDecoration(hintText: 'Bairro'),
            ),
            const SizedBox(height: 12),
            _label('Cidade'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _cityCtrl,
              decoration: const InputDecoration(hintText: 'Cidade'),
            ),
            const SizedBox(height: 12),
            _label('UF'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _stateCtrl,
              textCapitalization: TextCapitalization.characters,
              maxLength: 2,
              decoration: const InputDecoration(hintText: 'SP', counterText: ''),
            ),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 220,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('CEP (Auto-busca)'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _zipCtrl,
                        keyboardType: TextInputType.number,
                        maxLength: 9,
                        onChanged: _searchZipCode,
                        decoration: InputDecoration(
                          hintText: '00000-000',
                          counterText: '',
                          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
                          suffixIcon: _isSearchingZip
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                                )
                              : null,
                        ),
                      ),
                      if (_zipError != null) ...[
                        const SizedBox(height: 4),
                        Text(_zipError!, style: GoogleFonts.inter(color: const Color(0xFFEF4444), fontSize: 11)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Logradouro / Rua'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _streetCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Rua, Avenida, Alameda...',
                          prefixIcon: Icon(Icons.home_outlined, color: Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 120,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Número'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _numCtrl,
                        focusNode: _numFocus,
                        decoration: const InputDecoration(hintText: '123'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Complemento'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _compCtrl,
                        decoration: const InputDecoration(hintText: 'Galpão 3, Sala 10, Bloco B...'),
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
                        decoration: const InputDecoration(hintText: 'Bairro'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Cidade'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _cityCtrl,
                        decoration: const InputDecoration(hintText: 'Cidade'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 90,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('UF'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _stateCtrl,
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 2,
                        decoration: const InputDecoration(hintText: 'SP', counterText: ''),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 20),

          // ── SEÇÃO 4: CONDIÇÕES COMERCIAIS & NOTAS ─────────────────────────
          _sectionHeader(Icons.handshake_outlined, 'Condições Comerciais & Observações', 'Prazos de pagamento e detalhes'),
          const SizedBox(height: 14),

          _label('Condições de Pagamento Padrão'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _paymentTermsCtrl,
            decoration: const InputDecoration(
              hintText: 'Ex: Boleto 30/60 dias, À vista 5% desc, Faturado',
              prefixIcon: Icon(Icons.payment_rounded, color: Color(0xFF64748B)),
            ),
          ),
          const SizedBox(height: 14),

          _label('Observações Gerais'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _notesCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'Anotações sobre pedido mínimo, frete (FOB/CIF), horários de entrega...',
              prefixIcon: Icon(Icons.notes_rounded, color: Color(0xFF64748B)),
            ),
          ),

          const SizedBox(height: 20),

          // ── Status (só na edição) ─────────────────────────────────────────
          if (_isEditing) ...[
            _label('Status do Fornecedor'),
            const SizedBox(height: 6),
            DropdownButtonFormField<SupplierStatus>(
              initialValue: _status,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.toggle_on_outlined, color: Color(0xFF64748B)),
              ),
              items: SupplierStatus.values
                  .map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(s.label, style: GoogleFonts.inter(fontSize: 14)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _status = v!),
            ),
            const SizedBox(height: 20),
          ],

          // ── Botão Salvar ──────────────────────────────────────────────────
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isLoading ? null : _submit,
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
                padding: const EdgeInsets.symmetric(vertical: 15),
                child: Center(
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : Text(
                          _isEditing ? 'SALVAR ALTERAÇÕES' : 'CADASTRAR FORNECEDOR',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: AppColors.primary),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: const Color(0xFF0F172A))),
            Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
          ],
        ),
      ],
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF334155),
      ),
    );
  }
}

class _SupplierErrorBanner extends StatelessWidget {
  final String message;
  const _SupplierErrorBanner({required this.message});

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
          const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 18),
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
