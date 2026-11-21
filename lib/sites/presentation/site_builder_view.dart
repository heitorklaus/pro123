import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../auth/domain/models/user_model.dart';
import '../../settings/data/services/company_service.dart';
import '../data/repositories/solar_site_repository.dart';
import '../domain/models/solar_site_model.dart';
import 'widgets/solar_site_one_page.dart';

/// Construtor de Sites One-Page para Integradores Solares (20 Templates + Cores + Preview ao Vivo).
class SiteBuilderView extends StatefulWidget {
  final UserModel? currentUser;

  const SiteBuilderView({super.key, required this.currentUser});

  @override
  State<SiteBuilderView> createState() => _SiteBuilderViewState();
}

class _SiteBuilderViewState extends State<SiteBuilderView>
    with SingleTickerProviderStateMixin {
  final _repo = SolarSiteRepository();
  late TabController _tabCtrl;

  SolarSiteConfig? _config;
  bool _loading = true;
  bool _saving = false;

  final _companyNameCtrl = TextEditingController();
  final _slugCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cnpjCtrl = TextEditingController();
  final _heroTitleCtrl = TextEditingController();
  final _heroSubCtrl = TextEditingController();
  final _heroCtaCtrl = TextEditingController();

  static const List<int> _paletteColors = [
    0xFFF59E0B, // Âmbar Solar
    0xFF6366F1, // Índigo TAOS
    0xFF10B981, // Esmeralda
    0xFF06B6D4, // Ciano
    0xFF2563EB, // Azul Corporativo
    0xFFEA580C, // Laranja Energia
    0xFF0F766E, // Verde Petróleo
    0xFF8B5CF6, // Roxo Tech
    0xFFEF4444, // Vermelho Destaque
    0xFF334155, // Slate Executivo
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _loadSite();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _companyNameCtrl.dispose();
    _slugCtrl.dispose();
    _whatsappCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _cnpjCtrl.dispose();
    _heroTitleCtrl.dispose();
    _heroSubCtrl.dispose();
    _heroCtaCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSite() async {
    final user = widget.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final companyId = user.effectiveCompanyId;
    var existing = await _repo.getSiteByCompanyId(companyId);

    if (existing == null) {
      final company = await CompanyService.getCompany(companyId: companyId);
      final bestName = (company?.tradeName?.isNotEmpty == true)
          ? company!.tradeName!
          : (company?.name.isNotEmpty == true ? company!.name : user.name);
      existing = SolarSiteConfig.defaultForCompany(
        companyId: companyId,
        companyName: bestName,
        whatsappPhone: company?.phone ?? user.phone ?? '',
        email: company?.email ?? user.email,
        address: company != null
            ? [
                if (company.street?.isNotEmpty == true) company.street!,
                if (company.city?.isNotEmpty == true)
                  '${company.city}${company.state?.isNotEmpty == true ? ' - ${company.state}' : ''}',
              ].join(', ')
            : '',
        cnpj: company?.document ?? '',
      ).copyWith(sector: company?.sector ?? 'solarPlant');
    }

    _syncControllers(existing);
    if (mounted) {
      setState(() {
        _config = existing;
        _loading = false;
      });
    }
  }

  void _syncControllers(SolarSiteConfig cfg) {
    _companyNameCtrl.text = cfg.companyName;
    _slugCtrl.text = cfg.slug;
    _whatsappCtrl.text = cfg.whatsappPhone;
    _emailCtrl.text = cfg.email;
    _addressCtrl.text = cfg.address;
    _cnpjCtrl.text = cfg.cnpj;
    _heroTitleCtrl.text = cfg.heroTitle;
    _heroSubCtrl.text = cfg.heroSubtitle;
    _heroCtaCtrl.text = cfg.heroCtaText;
  }

  String get _publicUrl {
    final slug = _config?.slug ?? '';
    final origin = Uri.base.origin;
    return '$origin/#/site/$slug';
  }

  Future<void> _saveSite() async {
    if (_config == null) return;
    setState(() => _saving = true);
    try {
      await _repo.saveSite(_config!.copyWith(updatedAt: DateTime.now()));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Site publicado e salvo com sucesso!'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar site: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _updateConfig(SolarSiteConfig next) {
    setState(() => _config = next);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_config == null) {
      return const Center(child: Text('Não foi possível carregar o editor.'));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cfg = _config!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 980;
        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: Column(
            children: [
              // ── BARRA SUPERIOR DO EDITOR ────────────────────────────────
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                child: Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B)
                                .withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.web_rounded,
                              color: Color(0xFFF59E0B), size: 20),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Meu Site (One-Page)',
                              style: GoogleFonts.outfit(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '20 Templates • Cores editáveis • Captação de Leads direto no CRM',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              cfg.isPublished ? 'Publicado' : 'Rascunho',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: cfg.isPublished
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF94A3B8),
                              ),
                            ),
                            Switch(
                              value: cfg.isPublished,
                              activeThumbColor: const Color(0xFF10B981),
                              onChanged: (v) =>
                                  _updateConfig(cfg.copyWith(isPublished: v)),
                            ),
                          ],
                        ),
                        OutlinedButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _publicUrl));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Link copiado: $_publicUrl'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          label: const Text('Copiar Link'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => launchUrl(Uri.parse(_publicUrl)),
                          icon: const Icon(Icons.open_in_new_rounded, size: 16),
                          label: const Text('Abrir Site'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _saving ? null : _saveSite,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 12),
                          ),
                          icon: _saving
                              ? const SizedBox(
                                  width: 15,
                                  height: 15,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save_rounded, size: 17),
                          label: Text(
                            _saving ? 'Salvando...' : 'Salvar & Publicar',
                            style:
                                GoogleFonts.inter(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── CORPO: EDITOR + PREVIEW AO VIVO ─────────────────────────
              Expanded(
                child: isMobile
                    ? Column(
                        children: [
                          SizedBox(
                            height: constraints.maxHeight * 0.45,
                            child: _buildEditorPanel(cfg, isDark),
                          ),
                          Expanded(
                            child: _buildLivePreview(cfg, isDark),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          SizedBox(
                            width: 410,
                            child: _buildEditorPanel(cfg, isDark),
                          ),
                          Expanded(
                            child: _buildLivePreview(cfg, isDark),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEditorPanel(SolarSiteConfig cfg, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(
          right: BorderSide(
            color:
                isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Column(
        children: [
          TabBar(
            controller: _tabCtrl,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: const Color(0xFFF59E0B),
            indicatorColor: const Color(0xFFF59E0B),
            tabs: const [
              Tab(text: '20 Templates'),
              Tab(text: 'Cores & Marca'),
              Tab(text: 'Textos & Seções'),
              Tab(text: 'Serviços & Clientes'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildTemplatesTab(cfg, isDark),
                _buildBrandAndColorsTab(cfg, isDark),
                _buildTextsTab(cfg),
                _buildServicesAndClientsTab(cfg),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplatesTab(SolarSiteConfig cfg, bool isDark) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.92,
      ),
      itemCount: SolarSiteTemplate.catalog.length,
      itemBuilder: (context, index) {
        final tpl = SolarSiteTemplate.catalog[index];
        final selected = cfg.templateId == tpl.id;
        return InkWell(
          onTap: () {
            _updateConfig(cfg.copyWith(
              templateId: tpl.id,
              primaryColorValue: tpl.defaultPrimaryColor,
              accentColorValue: tpl.defaultAccentColor,
              isDarkTheme: tpl.defaultDarkTheme,
            ));
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? const Color(0xFFF59E0B)
                    : (isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0)),
                width: selected ? 2.2 : 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(tpl.bgImagePath, fit: BoxFit.cover),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.7),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 6,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Color(tpl.defaultPrimaryColor),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${index + 1}',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      if (selected)
                        const Positioned(
                          right: 6,
                          top: 6,
                          child: CircleAvatar(
                            radius: 11,
                            backgroundColor: Color(0xFFF59E0B),
                            child: Icon(Icons.check_rounded,
                                size: 14, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tpl.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        tpl.category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBrandAndColorsTab(SolarSiteConfig cfg, bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Fundo Escuro (Dark Mode)',
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
          value: cfg.isDarkTheme,
          onChanged: (v) => _updateConfig(cfg.copyWith(isDarkTheme: v)),
        ),
        const SizedBox(height: 8),
        Text('Cor Principal',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _paletteColors.map((c) {
            final active = cfg.primaryColorValue == c;
            return GestureDetector(
              onTap: () => _updateConfig(cfg.copyWith(primaryColorValue: c)),
              child: CircleAvatar(
                radius: 15,
                backgroundColor: Color(c),
                child: active
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
        Text('Cor de Destaque (Botões / Selos)',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _paletteColors.map((c) {
            final active = cfg.accentColorValue == c;
            return GestureDetector(
              onTap: () => _updateConfig(cfg.copyWith(accentColorValue: c)),
              child: CircleAvatar(
                radius: 15,
                backgroundColor: Color(c),
                child: active
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _companyNameCtrl,
          decoration: const InputDecoration(
            labelText: 'Nome da Empresa no Site',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (v) => _updateConfig(cfg.copyWith(companyName: v)),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _slugCtrl,
          decoration: const InputDecoration(
            labelText: 'Slug da URL (ex: minha-empresa)',
            prefixText: '/#/site/',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (v) => _updateConfig(
            cfg.copyWith(
              slug: v.toLowerCase().replaceAll(RegExp(r'[^a-z0-9-]'), ''),
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _whatsappCtrl,
          decoration: const InputDecoration(
            labelText: 'WhatsApp de Atendimento',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (v) => _updateConfig(cfg.copyWith(whatsappPhone: v)),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _emailCtrl,
          decoration: const InputDecoration(
            labelText: 'E-mail de Contato',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (v) => _updateConfig(cfg.copyWith(email: v)),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _addressCtrl,
          decoration: const InputDecoration(
            labelText: 'Endereço',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (v) => _updateConfig(cfg.copyWith(address: v)),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _cnpjCtrl,
          decoration: const InputDecoration(
            labelText: 'CNPJ',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (v) => _updateConfig(cfg.copyWith(cnpj: v)),
        ),
      ],
    );
  }

  Widget _buildTextsTab(SolarSiteConfig cfg) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        TextField(
          controller: _heroTitleCtrl,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Título Principal (Capa)',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (v) => _updateConfig(cfg.copyWith(heroTitle: v)),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _heroSubCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Subtítulo (Capa)',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (v) => _updateConfig(cfg.copyWith(heroSubtitle: v)),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _heroCtaCtrl,
          decoration: const InputDecoration(
            labelText: 'Texto do Botão Principal',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (v) => _updateConfig(cfg.copyWith(heroCtaText: v)),
        ),
        const Divider(height: 24),
        Text('Seções Visíveis na One-Page',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Simulador de Economia (Gera Leads)'),
          value: cfg.showCalculator,
          onChanged: (v) => _updateConfig(cfg.copyWith(showCalculator: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Seção de Serviços'),
          value: cfg.showServices,
          onChanged: (v) => _updateConfig(cfg.copyWith(showServices: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Clientes & Projetos Entregues'),
          value: cfg.showClients,
          onChanged: (v) => _updateConfig(cfg.copyWith(showClients: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Como Funciona (4 Passos)'),
          value: cfg.showHowItWorks,
          onChanged: (v) => _updateConfig(cfg.copyWith(showHowItWorks: v)),
        ),
      ],
    );
  }

  Widget _buildServicesAndClientsTab(SolarSiteConfig cfg) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Serviços (${cfg.services.length})',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            TextButton.icon(
              onPressed: () => _addServiceDialog(cfg),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Adicionar'),
            ),
          ],
        ),
        ...cfg.services.asMap().entries.map((entry) {
          final i = entry.key;
          final s = entry.value;
          return ListTile(
            dense: true,
            leading: Icon(s.iconData, size: 18),
            title: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
              onPressed: () {
                final next = List<SolarSiteServiceItem>.from(cfg.services)
                  ..removeAt(i);
                _updateConfig(cfg.copyWith(services: next));
              },
            ),
          );
        }),
        const Divider(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Clientes / Projetos (${cfg.clients.length})',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            TextButton.icon(
              onPressed: () => _addClientDialog(cfg),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Adicionar'),
            ),
          ],
        ),
        ...cfg.clients.asMap().entries.map((entry) {
          final i = entry.key;
          final c = entry.value;
          return ListTile(
            dense: true,
            title: Text('${c.name} (${c.powerKwp})',
                maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(c.location),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
              onPressed: () {
                final next = List<SolarSiteClientItem>.from(cfg.clients)
                  ..removeAt(i);
                _updateConfig(cfg.copyWith(clients: next));
              },
            ),
          );
        }),
      ],
    );
  }

  Future<void> _addServiceDialog(SolarSiteConfig cfg) async {
    final tCtrl = TextEditingController();
    final dCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Novo Serviço'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: tCtrl,
              decoration: const InputDecoration(labelText: 'Título do serviço'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: dCtrl,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Descrição'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (tCtrl.text.trim().isEmpty) return;
              final next = List<SolarSiteServiceItem>.from(cfg.services)
                ..add(SolarSiteServiceItem(
                  title: tCtrl.text.trim(),
                  description: dCtrl.text.trim(),
                ));
              _updateConfig(cfg.copyWith(services: next));
              Navigator.pop(ctx);
            },
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
    tCtrl.dispose();
    dCtrl.dispose();
  }

  Future<void> _addClientDialog(SolarSiteConfig cfg) async {
    final nCtrl = TextEditingController();
    final lCtrl = TextEditingController();
    final pCtrl = TextEditingController();
    final qCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Novo Projeto / Cliente'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nCtrl,
              decoration: const InputDecoration(labelText: 'Nome do cliente'),
            ),
            TextField(
              controller: lCtrl,
              decoration: const InputDecoration(labelText: 'Cidade - UF'),
            ),
            TextField(
              controller: pCtrl,
              decoration: const InputDecoration(labelText: 'Potência (ex: 12,5 kWp)'),
            ),
            TextField(
              controller: qCtrl,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Depoimento'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nCtrl.text.trim().isEmpty) return;
              final next = List<SolarSiteClientItem>.from(cfg.clients)
                ..add(SolarSiteClientItem(
                  name: nCtrl.text.trim(),
                  location: lCtrl.text.trim(),
                  powerKwp: pCtrl.text.trim(),
                  quote: qCtrl.text.trim(),
                ));
              _updateConfig(cfg.copyWith(clients: next));
              Navigator.pop(ctx);
            },
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
    nCtrl.dispose();
    lCtrl.dispose();
    pCtrl.dispose();
    qCtrl.dispose();
  }

  Widget _buildLivePreview(SolarSiteConfig cfg, bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF020617) : const Color(0xFFE2E8F0),
      padding: const EdgeInsets.all(14),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // Barra simulada do navegador
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              child: Row(
                children: [
                  const CircleAvatar(radius: 5, backgroundColor: Color(0xFFEF4444)),
                  const SizedBox(width: 5),
                  const CircleAvatar(radius: 5, backgroundColor: Color(0xFFF59E0B)),
                  const SizedBox(width: 5),
                  const CircleAvatar(radius: 5, backgroundColor: Color(0xFF10B981)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : Colors.white,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _publicUrl,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SolarSiteOnePage(config: cfg, isPreview: true),
            ),
          ],
        ),
      ),
    );
  }
}
