import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../app/theme/app_colors.dart';
import '../../auth/domain/models/user_model.dart';
import '../../settings/data/services/ai_usage_telemetry_service.dart';
import '../../settings/data/services/system_settings_service.dart';
import '../../settings/domain/models/global_system_config.dart';

/// Painel Master exclusivo (`heitorklaus@hotmail.com`) para:
/// - Visão em tempo real de tokens e custo aproximado em R$ (Web + WhatsApp)
/// - Gráfico de consumo por usuário dono da empresa
/// - Gestão de Grupos de Cota: PREMIUM (default), GOLD e DIAMOND
/// - Aba Ajuda com tabela dinâmica de conversão USD -> R$ e dimensionamento
class MasterAiQuotasView extends StatefulWidget {
  final UserModel? currentUser;

  const MasterAiQuotasView({super.key, this.currentUser});

  @override
  State<MasterAiQuotasView> createState() => _MasterAiQuotasViewState();
}

class _MasterAiQuotasViewState extends State<MasterAiQuotasView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  GlobalSystemConfig _config = GlobalSystemConfig.defaultConfig();
  bool _isLoadingConfig = true;
  bool _isSaving = false;
  bool _isFetchingDollar = false;

  late TextEditingController _usdRateCtrl;
  late TextEditingController _inputUsdCtrl;
  late TextEditingController _outputUsdCtrl;
  late TextEditingController _premiumTokensCtrl;
  late TextEditingController _goldTokensCtrl;
  late TextEditingController _diamondTokensCtrl;
  late TextEditingController _premiumBrlCtrl;
  late TextEditingController _goldBrlCtrl;
  late TextEditingController _diamondBrlCtrl;

  int _aiAnalysesQuota = 25;
  int _maxSellers = 5;
  double _supportMediaLimitMb = 10.0;
  int _supportTextQuota = 100;
  String _companySortMode = 'recent'; // 'recent' | 'top_today' | 'top_month'

  final _brlFmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  final _numFmt = NumberFormat.decimalPattern('pt_BR');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _usdRateCtrl = TextEditingController(text: '5.80');
    _inputUsdCtrl = TextEditingController(text: '0.30');
    _outputUsdCtrl = TextEditingController(text: '2.50');
    _premiumTokensCtrl = TextEditingController(text: '300000');
    _goldTokensCtrl = TextEditingController(text: '750000');
    _diamondTokensCtrl = TextEditingController(text: '2000000');
    _premiumBrlCtrl = TextEditingController(text: '0.00');
    _goldBrlCtrl = TextEditingController(text: '0.00');
    _diamondBrlCtrl = TextEditingController(text: '0.00');
    _loadConfig();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _usdRateCtrl.dispose();
    _inputUsdCtrl.dispose();
    _outputUsdCtrl.dispose();
    _premiumTokensCtrl.dispose();
    _goldTokensCtrl.dispose();
    _diamondTokensCtrl.dispose();
    _premiumBrlCtrl.dispose();
    _goldBrlCtrl.dispose();
    _diamondBrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    final cfg = await SystemSettingsService.getGlobalConfig();
    if (!mounted) return;
    setState(() {
      _config = cfg;
      _aiAnalysesQuota = cfg.defaultDailyAiQuota;
      _maxSellers = cfg.defaultMaxSellersPerCompany;
      _supportMediaLimitMb = cfg.supportDailyMediaLimitMb;
      _supportTextQuota = cfg.supportDailyTextQuota;
      _usdRateCtrl.text = cfg.usdToBrlRate.toStringAsFixed(2);
      _inputUsdCtrl.text = cfg.geminiInputUsdPer1M.toStringAsFixed(2);
      _outputUsdCtrl.text = cfg.geminiOutputUsdPer1M.toStringAsFixed(2);
      _premiumTokensCtrl.text = cfg.premiumDailyTokens.toString();
      _goldTokensCtrl.text = cfg.goldDailyTokens.toString();
      _diamondTokensCtrl.text = cfg.diamondDailyTokens.toString();
      _premiumBrlCtrl.text = cfg.premiumDailyBrl.toStringAsFixed(2);
      _goldBrlCtrl.text = cfg.goldDailyBrl.toStringAsFixed(2);
      _diamondBrlCtrl.text = cfg.diamondDailyBrl.toStringAsFixed(2);
      _isLoadingConfig = false;
    });
  }

  double get _currentUsdRate =>
      double.tryParse(_usdRateCtrl.text.replaceAll(',', '.')) ??
      _config.usdToBrlRate;
  double get _currentInUsd =>
      double.tryParse(_inputUsdCtrl.text.replaceAll(',', '.')) ??
      _config.geminiInputUsdPer1M;
  double get _currentOutUsd =>
      double.tryParse(_outputUsdCtrl.text.replaceAll(',', '.')) ??
      _config.geminiOutputUsdPer1M;

  /// Média ponderada realista do Mavis (~82% entrada / ~18% saída)
  double get _avgUsdPer1M => (_currentInUsd * 0.82) + (_currentOutUsd * 0.18);
  double get _avgBrlPer1M => _avgUsdPer1M * _currentUsdRate;

  Future<void> _fetchDollarRate() async {
    setState(() => _isFetchingDollar = true);
    final live = await AiUsageTelemetryService.fetchLiveUsdToBrlRate();
    if (!mounted) return;
    setState(() => _isFetchingDollar = false);
    if (live != null) {
      setState(() {
        _usdRateCtrl.text = live.toStringAsFixed(2);
      });
      await _saveConfig(silentToast: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Cotação atualizada: US\$ 1,00 = R\$ ${live.toStringAsFixed(2)}',
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível buscar a cotação automática agora. Você pode digitar manualmente.',
          ),
          backgroundColor: Color(0xFFF59E0B),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _saveConfig({bool silentToast = false}) async {
    setState(() => _isSaving = true);
    try {
      final updated = _config.copyWith(
        defaultDailyAiQuota: _aiAnalysesQuota,
        defaultMaxSellersPerCompany: _maxSellers,
        supportDailyMediaLimitMb: _supportMediaLimitMb,
        supportDailyTextQuota: _supportTextQuota,
        usdToBrlRate: _currentUsdRate,
        geminiInputUsdPer1M: _currentInUsd,
        geminiOutputUsdPer1M: _currentOutUsd,
        premiumDailyTokens:
            int.tryParse(_premiumTokensCtrl.text.trim()) ?? 300000,
        goldDailyTokens: int.tryParse(_goldTokensCtrl.text.trim()) ?? 750000,
        diamondDailyTokens:
            int.tryParse(_diamondTokensCtrl.text.trim()) ?? 2000000,
        premiumDailyBrl:
            double.tryParse(_premiumBrlCtrl.text.replaceAll(',', '.')) ?? 0.0,
        goldDailyBrl:
            double.tryParse(_goldBrlCtrl.text.replaceAll(',', '.')) ?? 0.0,
        diamondDailyBrl:
            double.tryParse(_diamondBrlCtrl.text.replaceAll(',', '.')) ?? 0.0,
      );
      await SystemSettingsService.saveGlobalConfig(
        updated,
        updatedBy: widget.currentUser?.email ?? 'heitorklaus@hotmail.com',
      );
      if (mounted) {
        setState(() => _config = updated);
        if (!silentToast) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Configurações de tokens, dólar e grupos (PREMIUM/GOLD/DIAMOND) salvas!',
              ),
              backgroundColor: Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar configurações: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _updateUserTier(UserModel owner, String newTier) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(owner.uid)
          .update({'aiPlanTier': newTier});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${owner.name.isNotEmpty ? owner.name : owner.email} atualizado para ${newTier.toUpperCase()}!',
            ),
            backgroundColor: const Color(0xFF6366F1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao alterar grupo: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final monthKey = DateFormat('yyyy-MM').format(DateTime.now());

    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: Column(
            children: [
              // ── CABEÇALHO MASTER ───────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                  border: Border(
                    bottom: BorderSide(
                      color: isDark
                          ? const Color(0xFF1E293B)
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
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6366F1), Color(0xFF10B981)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.auto_graph_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Consumo de IA, Tokens & Grupos',
                                    style: GoogleFonts.outfit(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981)
                                          .withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: const Color(0xFF10B981)
                                            .withValues(alpha: 0.4),
                                      ),
                                    ),
                                    child: Text(
                                      'EXCLUSIVO MASTER',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF10B981),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Monitoramento em tempo real (WhatsApp + Sistema Web), custo aproximado em R\$ e cotas PREMIUM / GOLD / DIAMOND.',
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _isFetchingDollar ? null : _fetchDollarRate,
                          icon: _isFetchingDollar
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.currency_exchange_rounded,
                                  size: 16),
                          label: Text(
                            'USD: R\$ ${_currentUsdRate.toStringAsFixed(2)}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      labelColor: const Color(0xFF6366F1),
                      unselectedLabelColor: isDark
                          ? AppColors.darkTextSecondary
                          : const Color(0xFF64748B),
                      indicatorColor: const Color(0xFF6366F1),
                      labelStyle: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                      tabs: const [
                        Tab(
                          icon: Icon(Icons.analytics_outlined, size: 18),
                          text: 'Consumo & Gráfico Real-Time',
                        ),
                        Tab(
                          icon: Icon(Icons.workspace_premium_outlined, size: 18),
                          text: 'Grupos (PREMIUM / GOLD / DIAMOND)',
                        ),
                        Tab(
                          icon: Icon(Icons.help_outline_rounded, size: 18),
                          text: 'Ajuda & Tabela de Custos',
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── CONTEÚDO DAS ABAS ──────────────────────────────────────────
              Expanded(
                child: _isLoadingConfig
                    ? const Center(child: CircularProgressIndicator())
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildRealtimeTab(isDark, todayKey, monthKey),
                          _buildGroupsTab(isDark),
                          _buildHelpTab(isDark),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ABA 1: CONSUMO & GRÁFICO REAL-TIME
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildRealtimeTab(bool isDark, String todayKey, String monthKey) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('ai_system_totals')
          .doc('global')
          .snapshots(),
      builder: (context, globalSnap) {
        final gData = globalSnap.data?.data() ?? <String, dynamic>{};
        final sameDay = gData['todayDate'] == todayKey;
        final sameMonth = gData['monthKey'] == monthKey;

        final todayBrl =
            sameDay ? ((gData['todayCostBrl'] as num?)?.toDouble() ?? 0.0) : 0.0;
        final todayUsd =
            sameDay ? ((gData['todayCostUsd'] as num?)?.toDouble() ?? 0.0) : 0.0;
        final monthBrl = sameMonth
            ? ((gData['monthCostBrl'] as num?)?.toDouble() ?? 0.0)
            : 0.0;
        final monthUsd = sameMonth
            ? ((gData['monthCostUsd'] as num?)?.toDouble() ?? 0.0)
            : 0.0;
        final todayTokens =
            sameDay ? ((gData['todayTokens'] as num?)?.toInt() ?? 0) : 0;
        final todayWebReqs =
            sameDay ? ((gData['todayWebRequests'] as num?)?.toInt() ?? 0) : 0;
        final todayBotReqs =
            sameDay ? ((gData['todayBotRequests'] as num?)?.toInt() ?? 0) : 0;
        final today429 =
            sameDay ? ((gData['today429Errors'] as num?)?.toInt() ?? 0) : 0;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── INTERRUPTORES RÁPIDOS MASTER (LIGA / DESLIGA) ────────────────
              _buildMasterSwitchesBar(isDark),
              const SizedBox(height: 20),

              // KPIs Globais
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _KpiCard(
                    title: 'Gasto Aproximado Hoje',
                    value: _brlFmt.format(todayBrl),
                    subtitle: 'US\$ ${todayUsd.toStringAsFixed(4)} • Tempo real',
                    icon: Icons.today_rounded,
                    color: const Color(0xFF10B981),
                    isDark: isDark,
                  ),
                  _KpiCard(
                    title: 'Gasto Acumulado no Mês',
                    value: _brlFmt.format(monthBrl),
                    subtitle: 'US\$ ${monthUsd.toStringAsFixed(4)} • Mês $monthKey',
                    icon: Icons.calendar_month_rounded,
                    color: const Color(0xFF6366F1),
                    isDark: isDark,
                  ),
                  _KpiCard(
                    title: 'Tokens Consumidos Hoje',
                    value: _numFmt.format(todayTokens),
                    subtitle: 'Web: $todayWebReqs reqs | WhatsApp: $todayBotReqs reqs',
                    icon: Icons.token_rounded,
                    color: const Color(0xFF0EA5E9),
                    isDark: isDark,
                  ),
                  _KpiCard(
                    title: 'Alertas Cota Google (429)',
                    value: '$today429',
                    subtitle: today429 == 0
                        ? 'Nenhuma chave bloqueada hoje'
                        : 'Atenção: erro 429 detectado hoje!',
                    icon: Icons.warning_amber_rounded,
                    color: today429 == 0
                        ? const Color(0xFF64748B)
                        : const Color(0xFFEF4444),
                    isDark: isDark,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Gráfico por Dono da Empresa
              _buildCompanyUsageChartSection(isDark, todayKey, monthKey),
              const SizedBox(height: 24),

              // Últimas chamadas registradas
              _buildRecentLogsSection(isDark),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMasterSwitchesBar(bool isDark) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _buildSwitchCard(
          isDark: isDark,
          title: 'IA Global para Usuários',
          subtitle: _config.aiEnabledForUsers
              ? 'LIGADA • Todos usam conforme cota do grupo'
              : 'DESLIGADA • Apenas heitorklaus@hotmail.com usa IA',
          value: _config.aiEnabledForUsers,
          activeColor: const Color(0xFF10B981),
          inactiveColor: const Color(0xFFEF4444),
          icon: Icons.smart_toy_rounded,
          onChanged: (val) async {
            final updated = _config.copyWith(aiEnabledForUsers: val);
            setState(() => _config = updated);
            await SystemSettingsService.saveGlobalConfig(
              updated,
              updatedBy: widget.currentUser?.email ?? 'heitorklaus@hotmail.com',
            );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(val
                      ? 'IA liberada para todos os usuários!'
                      : 'IA pausada! Apenas heitorklaus@hotmail.com pode usar agora.'),
                  backgroundColor:
                      val ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
        ),
        _buildSwitchCard(
          isDark: isDark,
          title: 'Cadastros de Novos Usuários',
          subtitle: _config.allowPublicRegistration
              ? 'HABILITADO • Novos usuários podem se cadastrar'
              : 'DESABILITADO • Novos cadastros públicos bloqueados',
          value: _config.allowPublicRegistration,
          activeColor: const Color(0xFF6366F1),
          inactiveColor: const Color(0xFFF59E0B),
          icon: Icons.person_add_alt_1_rounded,
          onChanged: (val) async {
            final updated = _config.copyWith(allowPublicRegistration: val);
            setState(() => _config = updated);
            await SystemSettingsService.saveGlobalConfig(
              updated,
              updatedBy: widget.currentUser?.email ?? 'heitorklaus@hotmail.com',
            );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(val
                      ? 'Novos cadastros de usuários HABILITADOS!'
                      : 'Novos cadastros de usuários DESABILITADOS!'),
                  backgroundColor:
                      val ? const Color(0xFF6366F1) : const Color(0xFFF59E0B),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildSwitchCard({
    required bool isDark,
    required String title,
    required String subtitle,
    required bool value,
    required Color activeColor,
    required Color inactiveColor,
    required IconData icon,
    required ValueChanged<bool> onChanged,
  }) {
    final color = value ? activeColor : inactiveColor;
    return Container(
      width: 420,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 1.4),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: activeColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyUsageChartSection(
      bool isDark, String todayKey, String monthKey) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Consumo de Tokens & Custo por Usuário Dono da Empresa',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Soma automaticamente todas as chamadas feitas pelo dono, vendedores da equipe e agente WhatsApp da empresa.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Último uso'),
                    selected: _companySortMode == 'recent',
                    onSelected: (_) =>
                        setState(() => _companySortMode = 'recent'),
                  ),
                  ChoiceChip(
                    label: const Text('Mais usados (Hoje)'),
                    selected: _companySortMode == 'top_today',
                    onSelected: (_) =>
                        setState(() => _companySortMode = 'top_today'),
                  ),
                  ChoiceChip(
                    label: const Text('Mais usados (Mês)'),
                    selected: _companySortMode == 'top_month',
                    onSelected: (_) =>
                        setState(() => _companySortMode = 'top_month'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('users').snapshots(),
            builder: (context, usersSnap) {
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('ai_company_usage')
                    .snapshots(),
                builder: (context, usageSnap) {
                  if (!usersSnap.hasData) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  final allUsers = usersSnap.data!.docs
                      .map((d) => UserModel.fromMap(d.data(), d.id))
                      .toList();

                  // Identifica donos de empresa (incluindo Master, role admin ou companyId == uid ou sem companyId)
                  final owners = allUsers
                      .where((u) =>
                          u.isSuperAdmin ||
                          u.role.toLowerCase() == 'admin' ||
                          u.companyId == null ||
                          u.companyId!.isEmpty ||
                          u.companyId == u.uid)
                      .toList();

                  final usageByCompany = <String, Map<String, dynamic>>{};
                  for (final doc in usageSnap.data?.docs ?? const []) {
                    usageByCompany[doc.id] = doc.data();
                  }

                  final rows = owners.map((owner) {
                    final u = usageByCompany[owner.effectiveCompanyId] ?? {};
                    final sameDay = u['todayDate'] == todayKey;
                    final sameMonth = u['monthKey'] == monthKey;
                    final todayTokens = sameDay
                        ? ((u['todayTokens'] as num?)?.toInt() ?? 0)
                        : 0;
                    final todayBrl = sameDay
                        ? ((u['todayCostBrl'] as num?)?.toDouble() ?? 0.0)
                        : 0.0;
                    final monthTokens = sameMonth
                        ? ((u['monthTokens'] as num?)?.toInt() ?? 0)
                        : 0;
                    final monthBrl = sameMonth
                        ? ((u['monthCostBrl'] as num?)?.toDouble() ?? 0.0)
                        : 0.0;
                    final limitTokens =
                        AiUsageTelemetryService.getEffectiveDailyTokenQuota(
                      owner,
                      _config,
                    );
                    final updatedAt =
                        (u['updatedAt'] as Timestamp?)?.toDate();
                    final lastSource = u['lastSource'] as String?;
                    return (
                      owner: owner,
                      todayTokens: todayTokens,
                      todayBrl: todayBrl,
                      monthTokens: monthTokens,
                      monthBrl: monthBrl,
                      limitTokens: limitTokens,
                      updatedAt: updatedAt,
                      lastSource: lastSource,
                    );
                  }).toList()
                    ..sort((a, b) {
                      if (_companySortMode == 'recent') {
                        final aTime = a.updatedAt?.millisecondsSinceEpoch ?? 0;
                        final bTime = b.updatedAt?.millisecondsSinceEpoch ?? 0;
                        if (bTime != aTime) return bTime.compareTo(aTime);
                        return b.todayTokens.compareTo(a.todayTokens);
                      } else if (_companySortMode == 'top_month') {
                        final cmp = b.monthTokens.compareTo(a.monthTokens);
                        return cmp != 0
                            ? cmp
                            : b.todayTokens.compareTo(a.todayTokens);
                      }
                      final cmp = b.todayTokens.compareTo(a.todayTokens);
                      return cmp != 0
                          ? cmp
                          : b.monthTokens.compareTo(a.monthTokens);
                    });

                  if (rows.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Nenhum dono de empresa encontrado ainda.',
                        style: GoogleFonts.inter(
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : const Color(0xFF64748B),
                        ),
                      ),
                    );
                  }

                  final maxTokensInChart = rows
                      .map((r) => r.todayTokens)
                      .fold<int>(1, (a, b) => a > b ? a : b);

                  return Column(
                    children: rows.map((r) {
                      final isMaster = r.owner.isSuperAdmin;
                      final ratio = isMaster
                          ? 0.0
                          : (r.todayTokens / r.limitTokens).clamp(0.0, 1.0);
                      final chartBarRatio = (r.todayTokens / maxTokensInChart)
                          .clamp(0.02, 1.0);
                      final tier = isMaster
                          ? 'MASTER'
                          : r.owner.aiPlanTier.toUpperCase();
                      final tierColor = isMaster
                          ? const Color(0xFF10B981)
                          : _tierColor(tier);
                      final isOver = !isMaster && r.todayTokens >= r.limitTokens;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E293B).withValues(alpha: 0.45)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isOver
                                ? const Color(0xFFEF4444).withValues(alpha: 0.5)
                                : (isDark
                                    ? const Color(0xFF334155)
                                    : const Color(0xFFE2E8F0)),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Text(
                                        r.owner.name.isNotEmpty
                                            ? r.owner.name
                                            : r.owner.email,
                                        style: GoogleFonts.inter(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: isDark
                                              ? Colors.white
                                              : const Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: tierColor.withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          border: Border.all(
                                              color: tierColor
                                                  .withValues(alpha: 0.4)),
                                        ),
                                        child: Text(
                                          tier,
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: tierColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  isMaster
                                      ? 'Hoje: ${_numFmt.format(r.todayTokens)} tokens (${_brlFmt.format(r.todayBrl)}) • Ilimitado'
                                      : 'Hoje: ${_numFmt.format(r.todayTokens)} / ${_numFmt.format(r.limitTokens)} tokens (${_brlFmt.format(r.todayBrl)})',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isOver
                                        ? const Color(0xFFEF4444)
                                        : (isDark
                                            ? Colors.white
                                            : const Color(0xFF0F172A)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Barra proporcional do gráfico
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: r.todayTokens == 0
                                    ? 0.0
                                    : chartBarRatio,
                                minHeight: 10,
                                backgroundColor: isDark
                                    ? const Color(0xFF0F172A)
                                    : const Color(0xFFE2E8F0),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isOver
                                      ? const Color(0xFFEF4444)
                                      : tierColor,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  () {
                                    final lastStr = r.updatedAt != null
                                        ? '  •  Último uso: ${DateFormat('dd/MM HH:mm').format(r.updatedAt!)}${r.lastSource != null ? ' (${r.lastSource})' : ''}'
                                        : '';
                                    if (isMaster) {
                                      return 'Conta Master (sem limite)  •  Mês atual: ${_numFmt.format(r.monthTokens)} tokens (${_brlFmt.format(r.monthBrl)})$lastStr';
                                    }
                                    return 'Uso da cota diária: ${(ratio * 100).toStringAsFixed(1)}%  •  Mês atual: ${_numFmt.format(r.monthTokens)} tokens (${_brlFmt.format(r.monthBrl)})$lastStr';
                                  }(),
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                                if (!isMaster)
                                  DropdownButton<String>(
                                    value: ['premium', 'gold', 'diamond']
                                            .contains(r.owner.aiPlanTier
                                                .toLowerCase())
                                        ? r.owner.aiPlanTier.toLowerCase()
                                        : 'premium',
                                    isDense: true,
                                    underline: const SizedBox.shrink(),
                                    items: const [
                                      DropdownMenuItem(
                                          value: 'premium',
                                          child: Text('PREMIUM')),
                                      DropdownMenuItem(
                                          value: 'gold', child: Text('GOLD')),
                                      DropdownMenuItem(
                                          value: 'diamond',
                                          child: Text('DIAMOND')),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) {
                                        _updateUserTier(r.owner, val);
                                      }
                                    },
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRecentLogsSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Últimas Chamadas de IA Registradas',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('ai_usage_logs')
                .orderBy('createdAt', descending: true)
                .limit(15)
                .snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snap.data!.docs;
              if (docs.isEmpty) {
                return Text(
                  'Ainda não há chamadas registradas após a ativação da telemetria.',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : const Color(0xFF64748B),
                  ),
                );
              }
              return Column(
                children: docs.map((d) {
                  final data = d.data();
                  final channel = data['channel'] ?? 'web';
                  final source = data['source'] ?? 'ia';
                  final userName = data['userName'] ?? 'Sistema';
                  final totalTokens =
                      (data['totalTokens'] as num?)?.toInt() ?? 0;
                  final costBrl =
                      (data['costBrl'] as num?)?.toDouble() ?? 0.0;
                  final is429 = data['isQuotaError429'] == true;

                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: (is429
                              ? const Color(0xFFEF4444)
                              : (channel == 'whatsapp'
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF6366F1)))
                          .withValues(alpha: 0.15),
                      child: Icon(
                        is429
                            ? Icons.error_outline
                            : (channel == 'whatsapp'
                                ? Icons.chat_rounded
                                : Icons.web_rounded),
                        size: 16,
                        color: is429
                            ? const Color(0xFFEF4444)
                            : (channel == 'whatsapp'
                                ? const Color(0xFF10B981)
                                : const Color(0xFF6366F1)),
                      ),
                    ),
                    title: Text(
                      '$userName • $source',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    subtitle: Text(
                      '${data['model'] ?? 'gemini'} • ${_numFmt.format(totalTokens)} tokens',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : const Color(0xFF64748B),
                      ),
                    ),
                    trailing: Text(
                      is429 ? 'ERRO 429' : _brlFmt.format(costBrl),
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: is429
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF10B981),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ABA 2: GRUPOS (PREMIUM / GOLD / DIAMOND) & LIMITES
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildGroupsTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dólar e Preços Base
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cotação do Dólar & Tarifa Google Gemini',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 16,
                  runSpacing: 14,
                  children: [
                    SizedBox(
                      width: 210,
                      child: TextField(
                        controller: _usdRateCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Cotação Dólar (USD → R\$)',
                          prefixText: 'R\$ ',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 230,
                      child: TextField(
                        controller: _inputUsdCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Entrada (US\$ por 1M tokens)',
                          prefixText: 'US\$ ',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 230,
                      child: TextField(
                        controller: _outputUsdCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Saída (US\$ por 1M tokens)',
                          prefixText: 'US\$ ',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Cards dos 3 Grupos: PREMIUM, GOLD, DIAMOND
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildTierConfigCard(
                isDark: isDark,
                title: 'PREMIUM (Padrão)',
                badge: 'DEFAULT',
                color: const Color(0xFF6366F1),
                description:
                    'Todos os usuários novos ou existentes entram aqui por padrão (~15 arquivos + ~100 msgs WhatsApp/dia).',
                tokensCtrl: _premiumTokensCtrl,
                brlCtrl: _premiumBrlCtrl,
              ),
              _buildTierConfigCard(
                isDark: isDark,
                title: 'GOLD',
                badge: 'INTERMEDIÁRIO',
                color: const Color(0xFFF59E0B),
                description:
                    'Para integradores com maior volume de propostas, contas UC e atendimento no WhatsApp.',
                tokensCtrl: _goldTokensCtrl,
                brlCtrl: _goldBrlCtrl,
              ),
              _buildTierConfigCard(
                isDark: isDark,
                title: 'DIAMOND',
                badge: 'ALTA ESCALA',
                color: const Color(0xFF06B6D4),
                description:
                    'Para grandes operações com múltiplos vendedores simultâneos e alto volume de arquivos.',
                tokensCtrl: _diamondTokensCtrl,
                brlCtrl: _diamondBrlCtrl,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Limite de análises e vendedores (migrado do card antigo)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: Wrap(
              spacing: 24,
              runSpacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _CounterChip(
                  label: 'Análises de IA / dia (contagem)',
                  valueText: '$_aiAnalysesQuota / dia',
                  onMinus: () {
                    if (_aiAnalysesQuota > 1) {
                      setState(() => _aiAnalysesQuota--);
                    }
                  },
                  onPlus: () => setState(() => _aiAnalysesQuota++),
                ),
                _CounterChip(
                  label: 'Vendedores / Empresa (padrão)',
                  valueText: '$_maxSellers vagas',
                  onMinus: () {
                    if (_maxSellers > 1) setState(() => _maxSellers--);
                  },
                  onPlus: () => setState(() => _maxSellers++),
                ),
                _CounterChip(
                  label: 'Mídia Suporte / dia (MB)',
                  valueText: '${_supportMediaLimitMb.toStringAsFixed(0)} MB/dia',
                  onMinus: () {
                    if (_supportMediaLimitMb > 1) {
                      setState(() => _supportMediaLimitMb -= 1);
                    }
                  },
                  onPlus: () => setState(() => _supportMediaLimitMb += 1),
                ),
                _CounterChip(
                  label: 'Texto Suporte / dia (msgs)',
                  valueText: '$_supportTextQuota msgs/dia',
                  onMinus: () {
                    if (_supportTextQuota > 10) {
                      setState(() => _supportTextQuota -= 10);
                    }
                  },
                  onPlus: () => setState(() => _supportTextQuota += 10),
                ),
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : () => _saveConfig(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_rounded, size: 18),
                  label: Text(
                    'SALVAR GRUPOS & CONFIGURAÇÕES',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTierConfigCard({
    required bool isDark,
    required String title,
    required String badge,
    required Color color,
    required String description,
    required TextEditingController tokensCtrl,
    required TextEditingController brlCtrl,
  }) {
    final tokens = int.tryParse(tokensCtrl.text.trim()) ?? 0;
    final approxDailyBrl = (tokens / 1000000.0) * _avgBrlPer1M;
    final approxMonthlyBrl = approxDailyBrl * 30.0;

    return Container(
      width: 340,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.workspace_premium_rounded, color: color, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge,
                  style: GoogleFonts.inter(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: tokensCtrl,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Limite diário de Tokens',
              border: OutlineInputBorder(),
              suffixText: 'tokens/dia',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: brlCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Teto opcional em R\$/dia (0 = sem trava)',
              prefixText: 'R\$ ',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Custo máx. estimado se usar 100%:\n• ${_brlFmt.format(approxDailyBrl)}/dia  •  ${_brlFmt.format(approxMonthlyBrl)}/mês',
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ABA 3: AJUDA & TABELA DE CUSTOS (EXPLICAÇÃO SOLICITADA PELO USUÁRIO)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildHelpTab(bool isDark) {
    final inBrl1M = _currentInUsd * _currentUsdRate;
    final outBrl1M = _currentOutUsd * _currentUsdRate;
    final avgBrl1M = _avgBrlPer1M;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '1. Quanto custa 1 token em Reais (Tabela Atualizada com o Dólar)',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Valores calculados automaticamente com a cotação configurada no painel: US\$ 1,00 = R\$ ${_currentUsdRate.toStringAsFixed(2)} (Gemini Flash).',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                      const Color(0xFF6366F1).withValues(alpha: 0.12),
                    ),
                    columns: const [
                      DataColumn(label: Text('Tipo de Token')),
                      DataColumn(label: Text('Preço Google (1M tokens)')),
                      DataColumn(label: Text('Em Reais (1M tokens)')),
                      DataColumn(label: Text('Custo por 1.000 tokens')),
                    ],
                    rows: [
                      DataRow(cells: [
                        const DataCell(Text('Entrada (Input: texto, PDF, foto, áudio)')),
                        DataCell(Text('US\$ ${_currentInUsd.toStringAsFixed(2)}')),
                        DataCell(Text(_brlFmt.format(inBrl1M))),
                        DataCell(Text('R\$ ${(inBrl1M / 1000).toStringAsFixed(4)}')),
                      ]),
                      DataRow(cells: [
                        const DataCell(Text('Saída (Output: resposta/JSON da IA)')),
                        DataCell(Text('US\$ ${_currentOutUsd.toStringAsFixed(2)}')),
                        DataCell(Text(_brlFmt.format(outBrl1M))),
                        DataCell(Text('R\$ ${(outBrl1M / 1000).toStringAsFixed(4)}')),
                      ]),
                      DataRow(cells: [
                        const DataCell(Text('Média real no Mavis (~82% entrada / ~18% saída)')),
                        DataCell(Text('US\$ ${_avgUsdPer1M.toStringAsFixed(2)}')),
                        DataCell(Text(_brlFmt.format(avgBrl1M))),
                        DataCell(Text('R\$ ${(avgBrl1M / 1000).toStringAsFixed(4)}')),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    'Resumo rápido: A cada 100.000 tokens gastos no Mavis, seu custo aproximado é de R\$ ${(avgBrl1M / 10).toStringAsFixed(2)} (e 1.000.000 de tokens ≈ ${_brlFmt.format(avgBrl1M)}).',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '2. Dimensionamento: Quantos tokens o usuário PREMIUM precisa por dia?',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 12),
                _HelpBullet(
                  isDark: isDark,
                  title: '15 arquivos/dia (CNH, Conta de Luz UC, Pedido/Cotação de Usina):',
                  body:
                      'Cada arquivo envia prompt + PDF/imagem (1 a 3 páginas) + devolve JSON estruturado ≈ 4.000 tokens/arquivo → 15 × 4.000 = ~60.000 tokens/dia.',
                ),
                const SizedBox(height: 10),
                _HelpBullet(
                  isDark: isDark,
                  title: '~100 interações/mensagens no WhatsApp/dia (texto + áudios):',
                  body:
                      'Cada chamada envia instruções do bot + mensagem/áudio + devolve JSON ≈ 1.800 tokens/interação → 100 × 1.800 = ~180.000 tokens/dia.',
                ),
                const SizedBox(height: 10),
                _HelpBullet(
                  isDark: isDark,
                  title: 'Total recomendado com margem de segurança: 300.000 tokens/dia',
                  body:
                      'Se o usuário usar 100% da cota PREMIUM (300k/dia), custa cerca de ${_brlFmt.format((300000 / 1000000.0) * avgBrl1M)}/dia (máx. ${_brlFmt.format((300000 / 1000000.0) * avgBrl1M * 30)}/mês). Na prática, quem usa menos dias custa bem menos.',
                ),
                const SizedBox(height: 10),
                _HelpBullet(
                  isDark: isDark,
                  title: 'Como os grupos PREMIUM, GOLD e DIAMOND funcionam:',
                  body:
                      'Todo usuário novo ou sem grupo definido entra automaticamente em PREMIUM. Na aba "Grupos" ou na aba "Usuários", você pode promover qualquer dono de empresa para GOLD ou DIAMOND, ou alterar o limite global de tokens de cada grupo para todos de uma vez.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _tierColor(String tier) {
    switch (tier.toUpperCase()) {
      case 'DIAMOND':
        return const Color(0xFF06B6D4);
      case 'GOLD':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF6366F1);
    }
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}

class _CounterChip extends StatelessWidget {
  final String label;
  final String valueText;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  const _CounterChip({
    required this.label,
    required this.valueText,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: onMinus,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Text(
              valueText,
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              onPressed: onPlus,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
      ],
    );
  }
}

class _HelpBullet extends StatelessWidget {
  final bool isDark;
  final String title;
  final String body;

  const _HelpBullet({
    required this.isDark,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          body,
          style: GoogleFonts.inter(
            fontSize: 12.5,
            height: 1.45,
            color: isDark
                ? AppColors.darkTextSecondary
                : const Color(0xFF475569),
          ),
        ),
      ],
    );
  }
}
