import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/theme/app_colors.dart';
import '../../../auth/domain/models/user_model.dart';
import '../../../settings/data/services/system_settings_service.dart';
import '../../../settings/domain/models/company_model.dart';
import '../../../settings/domain/models/global_system_config.dart';

/// Card Executivo Master de Gestão de Cotas de IA & Limite de Vendedores por Integrador (Exclusivo SuperAdmin)
class MasterSystemConfigCard extends StatefulWidget {
  final UserModel currentUser;
  final List<UserModel> allUsers;

  const MasterSystemConfigCard({
    super.key,
    required this.currentUser,
    required this.allUsers,
  });

  @override
  State<MasterSystemConfigCard> createState() => _MasterSystemConfigCardState();
}

class _MasterSystemConfigCardState extends State<MasterSystemConfigCard> {
  int _aiQuota = 25;
  int _maxSellers = 5;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _showCompanyList = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final config = await SystemSettingsService.getGlobalConfig();
    if (mounted) {
      setState(() {
        _aiQuota = config.defaultDailyAiQuota;
        _maxSellers = config.defaultMaxSellersPerCompany;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveGlobalConfig() async {
    setState(() => _isSaving = true);
    try {
      final updated = GlobalSystemConfig(
        defaultDailyAiQuota: _aiQuota,
        defaultMaxSellersPerCompany: _maxSellers,
        updatedAt: DateTime.now(),
        updatedBy: widget.currentUser.email,
      );

      await SystemSettingsService.saveGlobalConfig(
        updated,
        updatedBy: widget.currentUser.email,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text(
                  'Configurações Master salvas: $_aiQuota análises IA/dia e $_maxSellers vendedores por empresa!',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar configurações master: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _openCompanyLimitDialog(CompanyModel company, int currentSellersCount) {
    int localMaxSellers = company.maxSellers ?? _maxSellers;
    int localAiQuota = company.maxDailyAiAnalyses ?? _aiQuota;
    bool isSavingCompany = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Container(
              width: 480,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.business_rounded, color: Color(0xFF818CF8), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              company.name,
                              style: GoogleFonts.outfit(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'CNPJ/CPF: ${company.document} • $currentSellersCount vendedores ativos',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Color(0xFF334155), height: 1),
                  const SizedBox(height: 20),

                  // Limite de Vendedores da Empresa
                  Text(
                    'Limite de Vendedores desta Empresa',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Quantidade máxima de operadores que este integrador pode cadastrar:',
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _counterButton(
                        icon: Icons.remove_rounded,
                        onTap: () {
                          if (localMaxSellers > 1) {
                            setDialogState(() => localMaxSellers--);
                          }
                        },
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF475569)),
                        ),
                        child: Text(
                          '$localMaxSellers vagas',
                          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF818CF8)),
                        ),
                      ),
                      _counterButton(
                        icon: Icons.add_rounded,
                        onTap: () {
                          setDialogState(() => localMaxSellers++);
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Cota Diária de IA da Empresa
                  Text(
                    'Cota Diária de Análises de IA (por vendedor)',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Limite diário de leitura de faturas e cotações para cada operador desta empresa:',
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _counterButton(
                        icon: Icons.remove_rounded,
                        onTap: () {
                          if (localAiQuota > 5) {
                            setDialogState(() => localAiQuota -= 5);
                          }
                        },
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF475569)),
                        ),
                        child: Text(
                          '$localAiQuota análises/dia',
                          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
                        ),
                      ),
                      _counterButton(
                        icon: Icons.add_rounded,
                        onTap: () {
                          setDialogState(() => localAiQuota += 5);
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text('CANCELAR', style: GoogleFonts.inter(color: const Color(0xFF94A3B8))),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: isSavingCompany
                            ? null
                            : () async {
                                setDialogState(() => isSavingCompany = true);
                                try {
                                  await SystemSettingsService.saveCompanyCustomLimits(
                                    companyId: company.id,
                                    maxSellers: localMaxSellers,
                                    maxDailyAiAnalyses: localAiQuota,
                                  );
                                  if (context.mounted) {
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Limites da empresa "${company.name}" atualizados com sucesso!'),
                                        backgroundColor: const Color(0xFF10B981),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  setDialogState(() => isSavingCompany = false);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(
                          isSavingCompany ? 'SALVANDO...' : 'SALVAR LIMITES',
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12.5),
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
    );
  }

  Widget _counterButton({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF334155),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: Colors.white),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox.shrink();
    }

    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      padding: EdgeInsets.all(isMobile ? 18 : 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF334155), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header do Card Master ──────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.tune_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Controle de Cotas & Limites do Sistema',
                          style: GoogleFonts.outfit(
                            fontSize: isMobile ? 17 : 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            'PAINEL MASTER',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF34D399),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Configure a cota diária padrão de IA por usuário e a quantidade máxima de vendedores por integrador cadastrado.',
                      style: GoogleFonts.inter(
                        fontSize: isMobile ? 12 : 13,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          const Divider(color: Color(0xFF334155), height: 1),
          const SizedBox(height: 24),

          // ── Controles Globais de Cotas ────────────────────────────────────
          Wrap(
            spacing: 20,
            runSpacing: 20,
            children: [
              // 1. Cota Diária de Análises de IA
              Container(
                width: isMobile ? double.infinity : 360,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome_rounded, color: Color(0xFF818CF8), size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Cota Diária de IA por Usuário',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Análises de faturas, leitura de PDFs de usinas e orçamentos IA por vendedor a cada dia:',
                      style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF94A3B8)),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            _counterButton(
                              icon: Icons.remove_rounded,
                              onTap: () {
                                if (_aiQuota > 5) {
                                  setState(() => _aiQuota -= 5);
                                }
                              },
                            ),
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF6366F1)),
                              ),
                              child: Text(
                                '$_aiQuota / dia',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFA5B4FC),
                                ),
                              ),
                            ),
                            _counterButton(
                              icon: Icons.add_rounded,
                              onTap: () {
                                setState(() => _aiQuota += 5);
                              },
                            ),
                          ],
                        ),
                        Text(
                          'Renovação: 00:00',
                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 2. Limite Padrão de Vendedores por Integrador
              Container(
                width: isMobile ? double.infinity : 360,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.people_alt_rounded, color: Color(0xFF34D399), size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Limite de Vendedores / Empresa',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Quantidade padrão de vendedores que cada conta de integrador pode cadastrar:',
                      style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF94A3B8)),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            _counterButton(
                              icon: Icons.remove_rounded,
                              onTap: () {
                                if (_maxSellers > 1) {
                                  setState(() => _maxSellers--);
                                }
                              },
                            ),
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF10B981)),
                              ),
                              child: Text(
                                '$_maxSellers vendedores',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF6EE7B7),
                                ),
                              ),
                            ),
                            _counterButton(
                              icon: Icons.add_rounded,
                              onTap: () {
                                setState(() => _maxSellers++);
                              },
                            ),
                          ],
                        ),
                        Text(
                          'Padrão: 5 vagas',
                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Botões de Ação do Painel Master ───────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Toggle de Lista de Empresas Integradoras
              OutlinedButton.icon(
                onPressed: () => setState(() => _showCompanyList = !_showCompanyList),
                icon: Icon(
                  _showCompanyList ? Icons.expand_less_rounded : Icons.apartment_rounded,
                  size: 18,
                  color: const Color(0xFF818CF8),
                ),
                label: Text(
                  _showCompanyList ? 'OCULTAR EMPRESAS' : 'GERENCIAR EMPRESAS & VAGAS',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: const Color(0xFF818CF8),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF4F46E5)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),

              // Botão Salvar
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveGlobalConfig,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded, size: 18, color: Colors.white),
                label: Text(
                  _isSaving ? 'SALVANDO...' : 'SALVAR COTAS GLOBAIS',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                    letterSpacing: 0.5,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 4,
                ),
              ),
            ],
          ),

          // ── Lista Dinâmica de Empresas / Integradores com Cotas Individuais ──
          if (_showCompanyList) ...[
            const SizedBox(height: 24),
            const Divider(color: Color(0xFF334155), height: 1),
            const SizedBox(height: 16),
            Text(
              'Empresas & Integradores Cadastrados no Ecossistema',
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              'Visualize as vagas de vendedores ocupadas por cada empresa e altere os limites individualmente:',
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 14),

            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('companies').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final companies = snapshot.data!.docs
                    .map((doc) => CompanyModel.fromMap(doc.data(), doc.id))
                    .toList();

                if (companies.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Nenhuma empresa cadastrada ainda.',
                      style: GoogleFonts.inter(color: const Color(0xFF64748B)),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: companies.length,
                  separatorBuilder: (_, __) => const Divider(color: Color(0xFF1E293B), height: 1),
                  itemBuilder: (context, index) {
                    final comp = companies[index];
                    final sellersCount = widget.allUsers.where((u) => u.companyId == comp.id && !u.isAdmin).length;
                    final effectiveMaxSellers = comp.maxSellers ?? _maxSellers;
                    final effectiveAiQuota = comp.maxDailyAiAnalyses ?? _aiQuota;
                    final isFull = sellersCount >= effectiveMaxSellers;

                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isFull ? const Color(0xFFEF4444).withValues(alpha: 0.5) : const Color(0xFF334155),
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: const Color(0xFF1E293B),
                            child: const Icon(Icons.business_rounded, color: Color(0xFF818CF8), size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  comp.name,
                                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                                ),
                                Text(
                                  'CNPJ: ${comp.document.isNotEmpty ? comp.document : "Não inf."} • Cota IA: $effectiveAiQuota/dia',
                                  style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 11.5),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isFull ? const Color(0xFFEF4444).withValues(alpha: 0.15) : const Color(0xFF10B981).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isFull ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isFull ? Icons.group_off_rounded : Icons.people_rounded,
                                  size: 14,
                                  color: isFull ? const Color(0xFFF87171) : const Color(0xFF34D399),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '$sellersCount / $effectiveMaxSellers vendedores',
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: isFull ? const Color(0xFFF87171) : const Color(0xFF34D399),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          IconButton(
                            icon: const Icon(Icons.settings_outlined, color: Color(0xFF818CF8), size: 20),
                            tooltip: 'Ajustar Limites desta Empresa',
                            onPressed: () => _openCompanyLimitDialog(comp, sellersCount),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
