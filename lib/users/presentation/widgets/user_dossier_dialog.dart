import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../app/theme/app_colors.dart';
import '../../../auth/domain/models/user_model.dart';
import '../../../clients/data/repositories/client_repository.dart';
import '../../../clients/domain/models/client_model.dart';
import '../../../contracts/data/repositories/contract_repository.dart';
import '../../../contracts/data/services/contract_pdf_service.dart';
import '../../../contracts/domain/models/contract_model.dart';
import '../../../products/data/repositories/product_repository.dart';
import '../../../products/domain/models/product_model.dart';
import '../../../proposals/data/repositories/proposal_repository.dart';
import '../../../proposals/domain/models/proposal_model.dart';
import '../../../proposals/presentation/widgets/proposal_pdf_preview_dialog.dart';
import '../../../proposals/presentation/web_proposal_page.dart';

/// Modal executivo completo: Dossiê 360º de Performance do Vendedor/Operador
class UserDossierDialog extends StatefulWidget {
  final UserModel user;
  final UserModel? currentUser;

  const UserDossierDialog({
    super.key,
    required this.user,
    this.currentUser,
  });

  @override
  State<UserDossierDialog> createState() => _UserDossierDialogState();
}

class _UserDossierDialogState extends State<UserDossierDialog> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  final _dateFormat = DateFormat('dd/MM/yyyy');

  final _proposalRepo = ProposalRepository();
  final _productRepo = ProductRepository();
  final _contractRepo = ContractRepository();
  final _clientRepo = ClientRepository();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final user = widget.user;
    final isSuper = user.isSuperAdmin;
    final companyId = user.effectiveCompanyId;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 32,
        vertical: isMobile ? 16 : 24,
      ),
      child: Container(
        width: 1040,
        height: 760,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── 1. CABEÇALHO DO DOSSIÊ ────────────────────────────────────
              Container(
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Avatar grande
                    CircleAvatar(
                      radius: isMobile ? 24 : 30,
                      backgroundColor: isSuper
                          ? const Color(0xFF9333EA)
                          : (user.isAdmin ? const Color(0xFFF59E0B) : const Color(0xFF6366F1)),
                      child: Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                        style: GoogleFonts.outfit(
                          fontSize: isMobile ? 20 : 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Dados do Usuário
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  user.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                    fontSize: isMobile ? 18 : 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (isSuper ? const Color(0xFF9333EA) : const Color(0xFF6366F1))
                                      .withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isSuper ? const Color(0xFFA855F7) : const Color(0xFF818CF8),
                                  ),
                                ),
                                child: Text(
                                  user.role.toUpperCase(),
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isSuper ? const Color(0xFFD8B4FE) : const Color(0xFFA5B4FC),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 12,
                            runSpacing: 4,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.mail_outline_rounded, size: 14, color: Color(0xFF94A3B8)),
                                  const SizedBox(width: 4),
                                  Text(
                                    user.email,
                                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                                  ),
                                ],
                              ),
                              if (user.phone != null && user.phone!.isNotEmpty)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.phone_outlined, size: 14, color: Color(0xFF10B981)),
                                    const SizedBox(width: 4),
                                    Text(
                                      user.phone!,
                                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF10B981)),
                                    ),
                                  ],
                                ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.calendar_today_outlined, size: 13, color: Color(0xFF94A3B8)),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Desde ${_dateFormat.format(user.createdAt)}',
                                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Botão Fechar
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Fechar Dossiê',
                    ),
                  ],
                ),
              ),

              // ── 2. KPIS EM TEMPO REAL ────────────────────────────────────
              Expanded(
                child: StreamBuilder<List<ProposalModel>>(
                  stream: _proposalRepo.getProposalsStream(
                    companyId: companyId,
                    isSuperAdmin: true,
                    isAllProposalsVisible: true,
                  ),
                  builder: (context, propSnap) {
                    return StreamBuilder<List<ProductModel>>(
                      stream: _productRepo.getProductsStream(
                        companyId: companyId,
                        isSuperAdmin: true,
                      ),
                      builder: (context, prodSnap) {
                        return StreamBuilder<List<ContractModel>>(
                          stream: _contractRepo.getContractsStream(
                            companyId: companyId,
                            isSuperAdmin: true,
                          ),
                          builder: (context, contSnap) {
                            return StreamBuilder<List<ClientModel>>(
                              stream: _clientRepo.getClientsStream(
                                companyId: companyId,
                                isSuperAdmin: true,
                              ),
                              builder: (context, cliSnap) {
                                // Filtrar tudo pelo ID do vendedor
                                final userProposals = (propSnap.data ?? [])
                                    .where((p) => p.createdByUserId == user.uid || (p.createdByUserId == null && p.createdByUserName == user.name))
                                    .toList();

                                final userProducts = (prodSnap.data ?? [])
                                    .where((p) => p.createdByUserId == user.uid || (p.createdByUserId == null && p.createdByUserName == user.name))
                                    .toList();

                                final userSolarPlants = userProducts
                                    .where((p) => p.sector == ProductSector.solarPlant || p.isSolarPlantKit)
                                    .toList();

                                final userContracts = (contSnap.data ?? [])
                                    .where((c) => c.createdByUserId == user.uid || (c.createdByUserId == null && c.createdByUserName == user.name))
                                    .toList();

                                final userClients = (cliSnap.data ?? [])
                                    .where((c) => c.createdByUserId == user.uid || (c.createdByUserId == null && c.createdByUserName == user.name))
                                    .toList();

                                // Cálculos de KPIs
                                final totalProposalsValue = userProposals.fold<double>(0.0, (sum, p) => sum + p.totalAmount);
                                final closedProposals = userProposals.where((p) => p.status == ProposalStatus.closed).toList();
                                final closedProposalsValue = closedProposals.fold<double>(0.0, (sum, p) => sum + p.totalAmount);
                                final conversionRate = userProposals.isEmpty ? 0.0 : (closedProposals.length / userProposals.length) * 100;
                                final totalOfferedKwp = userSolarPlants.fold<double>(0.0, (sum, p) => sum + (p.solarKilowatts ?? 0.0));
                                final signedContractsCount = userContracts.where((c) => c.status == ContractStatus.signed).length;

                                return Column(
                                  children: [
                                    // Grid de Cards KPI
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: 14),
                                      color: const Color(0xFFF8FAFC),
                                      child: LayoutBuilder(builder: (context, constraints) {
                                        final isCompact = constraints.maxWidth < 700;
                                        if (isCompact) {
                                          return Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              _buildKpiCard('TOTAL PROPOSTAS', _currency.format(totalProposalsValue), '${userProposals.length} emitidas', Icons.receipt_long_rounded, const Color(0xFF6366F1), 160),
                                              _buildKpiCard('VENDAS FECHADAS', _currency.format(closedProposalsValue), '${closedProposals.length} fechadas', Icons.verified_rounded, const Color(0xFF10B981), 160),
                                              _buildKpiCard('CONVERSÃO', '${conversionRate.toStringAsFixed(1)}%', 'de aprovação', Icons.trending_up_rounded, const Color(0xFF0284C7), 160),
                                              _buildKpiCard('POTÊNCIA OFERTADA', '${totalOfferedKwp.toStringAsFixed(1)} kWp', '${userSolarPlants.length} usinas', Icons.solar_power_rounded, const Color(0xFFF59E0B), 160),
                                              _buildKpiCard('CONTRATOS', '${userContracts.length}', '$signedContractsCount assinados', Icons.history_edu_rounded, const Color(0xFF8B5CF6), 160),
                                            ],
                                          );
                                        }
                                        return Row(
                                          children: [
                                            Expanded(child: _buildKpiCard('TOTAL PROPOSTAS', _currency.format(totalProposalsValue), '${userProposals.length} orçamentos', Icons.receipt_long_rounded, const Color(0xFF6366F1))),
                                            const SizedBox(width: 10),
                                            Expanded(child: _buildKpiCard('VENDAS FECHADAS', _currency.format(closedProposalsValue), '${closedProposals.length} fechadas', Icons.verified_rounded, const Color(0xFF10B981))),
                                            const SizedBox(width: 10),
                                            Expanded(child: _buildKpiCard('CONVERSÃO', '${conversionRate.toStringAsFixed(1)}%', 'taxa de sucesso', Icons.trending_up_rounded, const Color(0xFF0284C7))),
                                            const SizedBox(width: 10),
                                            Expanded(child: _buildKpiCard('POTÊNCIA USINAS', '${totalOfferedKwp.toStringAsFixed(1)} kWp', '${userSolarPlants.length} kits criados', Icons.solar_power_rounded, const Color(0xFFF59E0B))),
                                            const SizedBox(width: 10),
                                            Expanded(child: _buildKpiCard('CONTRATOS', '${userContracts.length}', '$signedContractsCount assinados', Icons.history_edu_rounded, const Color(0xFF8B5CF6))),
                                          ],
                                        );
                                      }),
                                    ),

                                    // ── 3. TAB BAR COM ABAS ──────────────────
                                    Container(
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                                      ),
                                      child: TabBar(
                                        controller: _tabController,
                                        labelColor: const Color(0xFF6366F1),
                                        unselectedLabelColor: const Color(0xFF64748B),
                                        indicatorColor: const Color(0xFF6366F1),
                                        indicatorWeight: 3,
                                        labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                                        tabs: [
                                          Tab(
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.description_outlined, size: 16),
                                                const SizedBox(width: 6),
                                                Text('Propostas (${userProposals.length})'),
                                              ],
                                            ),
                                          ),
                                          Tab(
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.solar_power_outlined, size: 16),
                                                const SizedBox(width: 6),
                                                Text('Usinas Solares (${userSolarPlants.length})'),
                                              ],
                                            ),
                                          ),
                                          Tab(
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.history_edu_outlined, size: 16),
                                                const SizedBox(width: 6),
                                                Text('Contratos (${userContracts.length})'),
                                              ],
                                            ),
                                          ),
                                          Tab(
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.people_alt_outlined, size: 16),
                                                const SizedBox(width: 6),
                                                Text('Clientes (${userClients.length})'),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // ── 4. CONTEÚDO DAS ABAS ─────────────────
                                    Expanded(
                                      child: TabBarView(
                                        controller: _tabController,
                                        children: [
                                          _buildProposalsTab(userProposals),
                                          _buildSolarPlantsTab(userSolarPlants),
                                          _buildContractsTab(userContracts),
                                          _buildClientsTab(userClients),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        );
                      },
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

  // ── KPI CARD WIDGET ────────────────────────────────────────────────────────
  Widget _buildKpiCard(String title, String value, String subtitle, IconData icon, Color color, [double? width]) {
    final card = Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  subtitle,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return card;
  }

  // ── ABA 1: PROPOSTAS ───────────────────────────────────────────────────────
  Widget _buildProposalsTab(List<ProposalModel> proposals) {
    if (proposals.isEmpty) {
      return _buildEmptyTab(
        icon: Icons.receipt_long_outlined,
        title: 'Nenhuma proposta emitida',
        subtitle: 'Este operador ainda não gerou propostas comerciais.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: proposals.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final p = proposals[i];
        final themeColor = Color(p.themeColorValue);

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: themeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Icon(Icons.description_outlined, color: themeColor, size: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            p.proposalNumber,
                            style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF334155)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            p.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFF0F172A)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Cliente: ${p.clientName}',
                      style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: p.status.bgColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  p.status.label,
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: p.status.textColor),
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _currency.format(p.totalAmount),
                    style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF059669)),
                  ),
                  Text(
                    _dateFormat.format(p.createdAt),
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              IconButton(
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 18, color: Color(0xFFDC2626)),
                tooltip: 'Visualizar PDF',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => ProposalPdfPreviewDialog(proposal: p),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.language_rounded, size: 18, color: Color(0xFF059669)),
                tooltip: 'Ver Proposta Web',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (ctx) => WebProposalPage(proposalId: p.id),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ── ABA 2: USINAS SOLARES ──────────────────────────────────────────────────
  Widget _buildSolarPlantsTab(List<ProductModel> plants) {
    if (plants.isEmpty) {
      return _buildEmptyTab(
        icon: Icons.solar_power_outlined,
        title: 'Nenhuma usina solar montada',
        subtitle: 'Este operador ainda não cadastrou usinas ou kits solares.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: plants.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final p = plants[i];
        final kwp = p.solarKilowatts ?? 0.0;
        final kitItems = p.solarKitItems;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                ),
                child: const Center(
                  child: Icon(Icons.solar_power_rounded, color: Color(0xFFD97706), size: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 6,
                      children: [
                        if (p.solarRoofType != null)
                          Text('🏠 ${p.solarRoofType}', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                        Text('📦 ${kitItems.length} equipamentos', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF059669))),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${kwp.toStringAsFixed(2)} kWp',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFB45309)),
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _currency.format(p.salePrice),
                    style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                  ),
                  Text(
                    _dateFormat.format(p.createdAt),
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ── ABA 3: CONTRATOS ───────────────────────────────────────────────────────
  Widget _buildContractsTab(List<ContractModel> contracts) {
    if (contracts.isEmpty) {
      return _buildEmptyTab(
        icon: Icons.history_edu_outlined,
        title: 'Nenhum contrato gerado',
        subtitle: 'Este operador ainda não emitiu contratos jurídicos.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: contracts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final c = contracts[i];

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Icon(Icons.gavel_rounded, color: Color(0xFF6366F1), size: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            c.contractNumber,
                            style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF4F46E5)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            c.clientName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFF0F172A)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ref. Proposta: ${c.proposalNumber.isNotEmpty ? c.proposalNumber : "—"}',
                      style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: c.status.bgColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  c.status.label,
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: c.status.textColor),
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _currency.format(c.totalAmount),
                    style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
                  ),
                  Text(
                    _dateFormat.format(c.createdAt),
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              IconButton(
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 18, color: Color(0xFFDC2626)),
                tooltip: 'Imprimir Contrato PDF',
                onPressed: () async {
                  await ContractPdfService.printContract(contract: c);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ── ABA 4: CLIENTES ────────────────────────────────────────────────────────
  Widget _buildClientsTab(List<ClientModel> clients) {
    if (clients.isEmpty) {
      return _buildEmptyTab(
        icon: Icons.people_outline_rounded,
        title: 'Nenhum cliente cadastrado',
        subtitle: 'Este operador ainda não cadastrou clientes na carteira.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: clients.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final c = clients[i];

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFFEEF2FF),
                child: Text(
                  c.name.isNotEmpty ? c.name[0].toUpperCase() : 'C',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 12),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      c.email,
                      style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              if (c.phone != null && c.phone!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.phone_rounded, size: 12, color: Color(0xFF10B981)),
                      const SizedBox(width: 4),
                      Text(c.phone!, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF334155))),
                    ],
                  ),
                ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    c.city != null && c.city!.isNotEmpty ? '${c.city} - ${c.state ?? ""}' : '—',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF475569)),
                  ),
                  Text(
                    _dateFormat.format(c.createdAt),
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ── EMPTY TAB STATE ────────────────────────────────────────────────────────
  Widget _buildEmptyTab({required IconData icon, required String title, required String subtitle}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: const Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }
}
