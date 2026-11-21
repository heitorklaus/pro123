import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/repositories/solar_site_repository.dart';
import '../../domain/models/solar_site_model.dart';

/// Renderizador One-Page reutilizado tanto no Preview ao Vivo quanto na Página Pública.
class SolarSiteOnePage extends StatefulWidget {
  final SolarSiteConfig config;
  final bool isPreview;

  const SolarSiteOnePage({
    super.key,
    required this.config,
    this.isPreview = false,
  });

  @override
  State<SolarSiteOnePage> createState() => _SolarSiteOnePageState();
}

class _SolarSiteOnePageState extends State<SolarSiteOnePage> {
  final _heroKey = GlobalKey();
  final _calcKey = GlobalKey();
  final _servicesKey = GlobalKey();
  final _clientsKey = GlobalKey();
  final _contactKey = GlobalKey();

  final _billCtrl = TextEditingController(text: '650');
  final _leadNameCtrl = TextEditingController();
  final _leadPhoneCtrl = TextEditingController();
  final _leadEmailCtrl = TextEditingController();
  final _leadCityCtrl = TextEditingController();
  bool _submittingLead = false;
  bool _leadSent = false;

  final _brlFmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  @override
  void dispose() {
    _billCtrl.dispose();
    _leadNameCtrl.dispose();
    _leadPhoneCtrl.dispose();
    _leadEmailCtrl.dispose();
    _leadCityCtrl.dispose();
    super.dispose();
  }

  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    }
  }

  double get _monthlyBill {
    final raw = _billCtrl.text
        .replaceAll('R\$', '')
        .replaceAll('.', '')
        .replaceAll(',', '.')
        .trim();
    return (double.tryParse(raw) ?? 650.0).clamp(100.0, 200000.0);
  }

  double get _estimatedKwp => (_monthlyBill / 0.95) / 115.0;
  double get _annualSavings => _monthlyBill * 0.92 * 12;

  Future<void> _openWhatsApp() async {
    final digits = widget.config.whatsappPhone.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return;
    final phone = digits.startsWith('55') ? digits : '55$digits';
    final msg = Uri.encodeComponent(
      'Olá! Vim pelo site da ${widget.config.companyName} e gostaria de simular um projeto solar (conta média ${_brlFmt.format(_monthlyBill)}).',
    );
    await launchUrl(Uri.parse('https://wa.me/$phone?text=$msg'));
  }

  Future<void> _submitLead() async {
    if (widget.isPreview) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Modo Preview: no site publicado este botão envia o lead direto para o CRM!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final name = _leadNameCtrl.text.trim();
    final phone = _leadPhoneCtrl.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe seu nome e WhatsApp para receber o orçamento.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() => _submittingLead = true);
    try {
      await SolarSiteRepository().submitLeadFromSite(
        companyId: widget.config.companyId,
        name: name,
        phone: phone,
        email: _leadEmailCtrl.text.trim(),
        city: _leadCityCtrl.text.trim(),
        monthlyBillRs: _monthlyBill,
        estimatedKwp: _estimatedKwp,
      );
      if (mounted) {
        setState(() => _leadSent = true);
        _leadNameCtrl.clear();
        _leadPhoneCtrl.clear();
        _leadEmailCtrl.clear();
        _leadCityCtrl.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao enviar solicitação: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submittingLead = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg = widget.config;
    final primary = Color(cfg.primaryColorValue);
    final accent = Color(cfg.accentColorValue);
    final isDark = cfg.isDarkTheme;
    final bgColor = isDark ? const Color(0xFF0B1120) : const Color(0xFFF8FAFC);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subTextColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    final borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bgColor,
      floatingActionButton: cfg.whatsappPhone.trim().isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _openWhatsApp,
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.chat_rounded),
              label: Text(
                'Falar no WhatsApp',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
            )
          : null,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 760;

          return Column(
            children: [
              // ── NAVBAR FIXA ─────────────────────────────────────────────
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 14 : 32,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0F172A).withValues(alpha: 0.96)
                      : Colors.white,
                  border: Border(bottom: BorderSide(color: borderColor)),
                ),
                child: Row(
                  children: [
                    if (cfg.logoUrl != null && cfg.logoUrl!.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          cfg.logoUrl!,
                          height: 36,
                          width: 110,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.solar_power_rounded,
                            color: primary,
                            size: 28,
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.solar_power_rounded,
                            color: primary, size: 22),
                      ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        cfg.companyName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          color: textColor,
                          fontSize: isCompact ? 15 : 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (!isCompact) ...[
                      _NavLink('Início', textColor, () => _scrollTo(_heroKey)),
                      if (cfg.showCalculator)
                        _NavLink(
                            'Simulador', textColor, () => _scrollTo(_calcKey)),
                      if (cfg.showServices)
                        _NavLink(
                            'Serviços', textColor, () => _scrollTo(_servicesKey)),
                      if (cfg.showClients)
                        _NavLink(
                            'Clientes', textColor, () => _scrollTo(_clientsKey)),
                      _NavLink(
                          'Contato', textColor, () => _scrollTo(_contactKey)),
                      const SizedBox(width: 12),
                    ],
                    ElevatedButton(
                      onPressed: () => _scrollTo(
                        cfg.showCalculator ? _calcKey : _contactKey,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: isCompact ? 12 : 18,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'Orçamento',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── CONTEÚDO ONE-PAGE SCROLLÁVEL ─────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. HERO COM IMAGEM DE FUNDO DO TEMPLATE
                      Container(
                        key: _heroKey,
                        constraints: const BoxConstraints(minHeight: 420),
                        decoration: BoxDecoration(
                          image: DecorationImage(
                            image: AssetImage(cfg.template.bgImagePath),
                            fit: BoxFit.cover,
                          ),
                        ),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isCompact ? 20 : 48,
                            vertical: isCompact ? 48 : 72,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                const Color(0xFF0F172A).withValues(alpha: 0.88),
                                const Color(0xFF0F172A).withValues(alpha: 0.72),
                                primary.withValues(alpha: 0.38),
                              ],
                            ),
                          ),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 960),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: accent.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                          color: accent.withValues(alpha: 0.6)),
                                    ),
                                    child: Text(
                                      '☀️ ${cfg.template.category.toUpperCase()} • ENERGIA SOLAR FOTOVOLTAICA',
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  Text(
                                    cfg.heroTitle,
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontSize: isCompact ? 28 : 44,
                                      fontWeight: FontWeight.w800,
                                      height: 1.12,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 680),
                                    child: Text(
                                      cfg.heroSubtitle,
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFFE2E8F0),
                                        fontSize: isCompact ? 14 : 16.5,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 28),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: () => _scrollTo(
                                          cfg.showCalculator
                                              ? _calcKey
                                              : _contactKey,
                                        ),
                                        icon: const Icon(Icons.bolt_rounded),
                                        label: Text(
                                          cfg.heroCtaText,
                                          style: GoogleFonts.inter(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: primary,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 24, vertical: 16),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                        ),
                                      ),
                                      if (cfg.showServices)
                                        OutlinedButton.icon(
                                          onPressed: () =>
                                              _scrollTo(_servicesKey),
                                          icon: const Icon(
                                              Icons.design_services_rounded),
                                          label: Text(
                                            'Conhecer Serviços',
                                            style: GoogleFonts.inter(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                            ),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.white,
                                            side: const BorderSide(
                                                color: Colors.white54),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 22, vertical: 16),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // 2. SIMULADOR DE ECONOMIA SOLAR (CAPTAÇÃO DE LEADS)
                      if (cfg.showCalculator)
                        Container(
                          key: _calcKey,
                          padding: EdgeInsets.symmetric(
                            horizontal: isCompact ? 16 : 48,
                            vertical: 48,
                          ),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 960),
                              child: Container(
                                padding: EdgeInsets.all(isCompact ? 20 : 32),
                                decoration: BoxDecoration(
                                  color: cardColor,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: primary.withValues(alpha: 0.45)),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.12),
                                      blurRadius: 24,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Simule sua Economia em Segundos',
                                      style: GoogleFonts.outfit(
                                        color: textColor,
                                        fontSize: isCompact ? 22 : 26,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Informe quanto você paga hoje de energia e receba uma estimativa imediata.',
                                      style: GoogleFonts.inter(
                                          color: subTextColor, fontSize: 13.5),
                                    ),
                                    const SizedBox(height: 20),
                                    Wrap(
                                      spacing: 20,
                                      runSpacing: 16,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: isCompact ? double.infinity : 260,
                                          child: TextField(
                                            controller: _billCtrl,
                                            keyboardType: TextInputType.number,
                                            onChanged: (_) => setState(() {}),
                                            style: GoogleFonts.inter(
                                              color: textColor,
                                              fontWeight: FontWeight.w700,
                                            ),
                                            decoration: InputDecoration(
                                              labelText:
                                                  'Valor médio da conta (R\$/mês)',
                                              prefixIcon: Icon(
                                                Icons.receipt_long_rounded,
                                                color: primary,
                                              ),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                          ),
                                        ),
                                        _SimMetricChip(
                                          label: 'Potência Estimada',
                                          value:
                                              '${_estimatedKwp.toStringAsFixed(2)} kWp',
                                          color: primary,
                                          isDark: isDark,
                                        ),
                                        _SimMetricChip(
                                          label: 'Economia Anual',
                                          value: _brlFmt.format(_annualSavings),
                                          color: accent,
                                          isDark: isDark,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 22),
                                    if (_leadSent)
                                      Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: accent.withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(color: accent),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.check_circle_rounded,
                                                color: accent),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                'Solicitação enviada! Nossa equipe de engenharia entrará em contato pelo WhatsApp.',
                                                style: GoogleFonts.inter(
                                                  color: textColor,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    else
                                      Wrap(
                                        spacing: 12,
                                        runSpacing: 12,
                                        children: [
                                          SizedBox(
                                            width: isCompact
                                                ? double.infinity
                                                : 220,
                                            child: TextField(
                                              controller: _leadNameCtrl,
                                              style: GoogleFonts.inter(
                                                  color: textColor),
                                              decoration: InputDecoration(
                                                hintText: 'Seu nome completo',
                                                isDense: true,
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: isCompact
                                                ? double.infinity
                                                : 180,
                                            child: TextField(
                                              controller: _leadPhoneCtrl,
                                              style: GoogleFonts.inter(
                                                  color: textColor),
                                              decoration: InputDecoration(
                                                hintText: 'WhatsApp (com DDD)',
                                                isDense: true,
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: isCompact
                                                ? double.infinity
                                                : 180,
                                            child: TextField(
                                              controller: _leadCityCtrl,
                                              style: GoogleFonts.inter(
                                                  color: textColor),
                                              decoration: InputDecoration(
                                                hintText: 'Cidade / UF',
                                                isDense: true,
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                              ),
                                            ),
                                          ),
                                          ElevatedButton.icon(
                                            onPressed: _submittingLead
                                                ? null
                                                : _submitLead,
                                            icon: _submittingLead
                                                ? const SizedBox(
                                                    width: 16,
                                                    height: 16,
                                                    child:
                                                        CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white,
                                                    ),
                                                  )
                                                : const Icon(
                                                    Icons.send_rounded),
                                            label: Text(
                                              'Receber Orçamento',
                                              style: GoogleFonts.inter(
                                                  fontWeight: FontWeight.w700),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: accent,
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 20,
                                                      vertical: 14),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                      // 3. SERVIÇOS
                      if (cfg.showServices && cfg.services.isNotEmpty)
                        Container(
                          key: _servicesKey,
                          padding: EdgeInsets.symmetric(
                            horizontal: isCompact ? 16 : 48,
                            vertical: 44,
                          ),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 960),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Nossos Serviços',
                                    style: GoogleFonts.outfit(
                                      color: textColor,
                                      fontSize: isCompact ? 24 : 30,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Soluções completas do dimensionamento à homologação.',
                                    style: GoogleFonts.inter(
                                        color: subTextColor, fontSize: 14),
                                  ),
                                  const SizedBox(height: 24),
                                  Wrap(
                                    spacing: 16,
                                    runSpacing: 16,
                                    children: cfg.services.map((srv) {
                                      return Container(
                                        width: isCompact
                                            ? double.infinity
                                            : 228,
                                        padding: const EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          color: cardColor,
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          border:
                                              Border.all(color: borderColor),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: primary.withValues(
                                                    alpha: 0.15),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Icon(srv.iconData,
                                                  color: primary, size: 24),
                                            ),
                                            const SizedBox(height: 14),
                                            Text(
                                              srv.title,
                                              style: GoogleFonts.outfit(
                                                color: textColor,
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              srv.description,
                                              style: GoogleFonts.inter(
                                                color: subTextColor,
                                                fontSize: 12.5,
                                                height: 1.45,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                      // 4. CLIENTES & PROJETOS
                      if (cfg.showClients && cfg.clients.isNotEmpty)
                        Container(
                          key: _clientsKey,
                          padding: EdgeInsets.symmetric(
                            horizontal: isCompact ? 16 : 48,
                            vertical: 44,
                          ),
                          color: isDark
                              ? const Color(0xFF0F172A)
                              : const Color(0xFFF1F5F9),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 960),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Clientes & Projetos Entregues',
                                    style: GoogleFonts.outfit(
                                      color: textColor,
                                      fontSize: isCompact ? 24 : 30,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Quem já gera a própria energia e economiza todos os meses.',
                                    style: GoogleFonts.inter(
                                        color: subTextColor, fontSize: 14),
                                  ),
                                  const SizedBox(height: 24),
                                  Wrap(
                                    spacing: 16,
                                    runSpacing: 16,
                                    children: cfg.clients.map((cl) {
                                      return Container(
                                        width: isCompact
                                            ? double.infinity
                                            : 308,
                                        padding: const EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          color: cardColor,
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          border:
                                              Border.all(color: borderColor),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    cl.name,
                                                    style: GoogleFonts.outfit(
                                                      color: textColor,
                                                      fontSize: 15.5,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: accent.withValues(
                                                        alpha: 0.16),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                  child: Text(
                                                    cl.powerKwp,
                                                    style: GoogleFonts.inter(
                                                      color: accent,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              cl.location,
                                              style: GoogleFonts.inter(
                                                color: primary,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            Text(
                                              '"${cl.quote}"',
                                              style: GoogleFonts.inter(
                                                color: subTextColor,
                                                fontSize: 12.5,
                                                fontStyle: FontStyle.italic,
                                                height: 1.45,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                      // 5. COMO FUNCIONA
                      if (cfg.showHowItWorks)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isCompact ? 16 : 48,
                            vertical: 44,
                          ),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 960),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Como Funciona em 4 Passos',
                                    style: GoogleFonts.outfit(
                                      color: textColor,
                                      fontSize: isCompact ? 24 : 30,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Wrap(
                                    spacing: 16,
                                    runSpacing: 16,
                                    children: const [
                                      ('1', 'Análise da Fatura',
                                          'Avaliamos seu consumo e telhado para dimensionar a usina ideal.'),
                                      ('2', 'Projeto & Aprovação',
                                          'Cuidamos da engenharia e da homologação na concessionária.'),
                                      ('3', 'Instalação Rápida',
                                          'Equipe certificada instala tudo com segurança e limpeza.'),
                                      ('4', 'Economia Imediata',
                                          'Você acompanha a geração pelo app e reduz até 95% da conta.'),
                                    ].map((step) {
                                      return Container(
                                        width: isCompact
                                            ? double.infinity
                                            : 228,
                                        padding: const EdgeInsets.all(18),
                                        decoration: BoxDecoration(
                                          color: cardColor,
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          border:
                                              Border.all(color: borderColor),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            CircleAvatar(
                                              radius: 15,
                                              backgroundColor: primary,
                                              child: Text(
                                                step.$1,
                                                style: GoogleFonts.inter(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              step.$2,
                                              style: GoogleFonts.outfit(
                                                color: textColor,
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              step.$3,
                                              style: GoogleFonts.inter(
                                                color: subTextColor,
                                                fontSize: 12,
                                                height: 1.4,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                      // 6. RODAPÉ / CONTATO
                      Container(
                        key: _contactKey,
                        padding: EdgeInsets.symmetric(
                          horizontal: isCompact ? 16 : 48,
                          vertical: 36,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          border: Border(
                              top: BorderSide(
                                  color: primary.withValues(alpha: 0.4))),
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 960),
                            child: Wrap(
                              spacing: 32,
                              runSpacing: 16,
                              alignment: WrapAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      cfg.companyName,
                                      style: GoogleFonts.outfit(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (cfg.cnpj.isNotEmpty)
                                      Text(
                                        'CNPJ: ${cfg.cnpj}',
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFF94A3B8),
                                          fontSize: 12,
                                        ),
                                      ),
                                    if (cfg.address.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          cfg.address,
                                          style: GoogleFonts.inter(
                                            color: const Color(0xFFCBD5E1),
                                            fontSize: 12.5,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (cfg.whatsappPhone.isNotEmpty)
                                      Text(
                                        '📱 WhatsApp: ${cfg.whatsappPhone}',
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    if (cfg.email.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          '✉️ ${cfg.email}',
                                          style: GoogleFonts.inter(
                                            color: const Color(0xFFCBD5E1),
                                            fontSize: 12.5,
                                          ),
                                        ),
                                      ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Tecnologia TAOS CRM',
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFF64748B),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _NavLink(this.label, this.color, this.onTap);

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: color.withValues(alpha: 0.88),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SimMetricChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _SimMetricChip({
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
