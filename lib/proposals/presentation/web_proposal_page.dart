import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../settings/data/services/solar_settings_service.dart';
import '../../settings/domain/models/solar_settings_model.dart';
import '../data/repositories/proposal_repository.dart';
import '../data/services/solar_proposal_pdf_service.dart';
import '../domain/models/proposal_item_model.dart';
import '../domain/models/proposal_model.dart';

/// Página Pública e Interativa da Proposta Web de Usina Solar
class WebProposalPage extends StatefulWidget {
  final String proposalId;
  final ProposalModel? initialProposal;

  const WebProposalPage({
    super.key,
    required this.proposalId,
    this.initialProposal,
  });

  @override
  State<WebProposalPage> createState() => _WebProposalPageState();
}

class _WebProposalPageState extends State<WebProposalPage> {
  final _repository = ProposalRepository();
  final _currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  final _dateFormat = DateFormat('dd/MM/yyyy');

  bool _isLoading = true;
  String? _errorMessage;
  ProposalModel? _proposal;
  SolarSettingsModel _settings = SolarSettingsModel.initial();

  // Estados do Simulador de Financiamento
  SolarFinancingBank? _selectedBank;
  int _selectedInstallmentMonths = 60;
  bool _isGeneratingPdf = false;
  bool _isAccepting = false;
  bool _hasAccepted = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      ProposalModel? p = widget.initialProposal;
      if (p == null && widget.proposalId.isNotEmpty) {
        p = await _repository.getProposalById(widget.proposalId);
      }

      if (p == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Proposta comercial não encontrada ou o link expirou.';
        });
        return;
      }

      final s = await SolarSettingsService.loadSettings(companyId: p.companyId);

      _proposal = p;
      _settings = s;
      _hasAccepted = p.status == ProposalStatus.closed;

      if (s.financingBanks.isNotEmpty) {
        _selectedBank = s.financingBanks.firstWhere(
          (b) => b.isActive,
          orElse: () => s.financingBanks.first,
        );
        if (_selectedBank!.enabledInstallments.isNotEmpty) {
          _selectedInstallmentMonths = _selectedBank!.enabledInstallments.contains(60)
              ? 60
              : _selectedBank!.enabledInstallments.last;
        }
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erro ao carregar proposta: $e';
      });
    }
  }

  ProposalItemModel? get _solarPlantItem {
    if (_proposal == null || _proposal!.items.isEmpty) return null;
    return _proposal!.items.firstWhere(
      (it) => (it.solarKilowatts != null && it.solarKilowatts! > 0) || it.isSolarPlant,
      orElse: () => _proposal!.items.first,
    );
  }

  Color get _primaryColor => Color(_proposal?.themeColorValue ?? _settings.themeColorValue);

  void _copyShareLink() {
    final uri = Uri.base.toString();
    Clipboard.setData(ClipboardData(text: uri));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white),
            SizedBox(width: 10),
            Text('Link da proposta copiado para a área de transferência!'),
          ],
        ),
        backgroundColor: Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openWhatsApp() async {
    final phone = _settings.companyPhone?.replaceAll(RegExp(r'\D'), '') ?? '';
    final propNum = _proposal?.proposalNumber ?? '';
    final clientName = _proposal?.clientName ?? '';
    final text = Uri.encodeComponent(
      'Olá! Estou visualizando a proposta solar $propNum para $clientName e gostaria de tirar dúvidas / dar andamento.',
    );
    final url = Uri.parse('https://wa.me/55$phone?text=$text');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _downloadPdf() async {
    if (_proposal == null) return;
    setState(() => _isGeneratingPdf = true);

    try {
      final bytes = await SolarProposalPdfService.generateSolarProposalPdf(_proposal!);

      final fileName = 'Proposta_${_proposal!.proposalNumber.replaceAll('/', '_')}.pdf';
      await Printing.sharePdf(bytes: bytes, filename: fileName);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao gerar PDF: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  void _showAcceptProposalDialog() {
    final nameCtrl = TextEditingController(text: _proposal?.clientName ?? '');
    final phoneCtrl = TextEditingController(text: _proposal?.clientPhone ?? '');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Aceitar Proposta Solar',
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                    ),
                    Text(
                      'Formalize seu interesse em 1 clique',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Investimento Total:', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                      Text(
                        _currencyFormat.format(_proposal?.totalAmount ?? 0),
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF059669)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text('Nome do Responsável / Titular:', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Seu nome completo',
                    prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                  ),
                ),
                const SizedBox(height: 12),
                Text('Telefone / WhatsApp de Contato:', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    hintText: '(00) 00000-0000',
                    prefixIcon: Icon(Icons.phone_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Ao confirmar, nosso time de engenharia entrará em contato para agendar a vistoria técnica e dar início ao parecer de acesso junto à concessionária.',
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B), height: 1.3),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCELAR', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton.icon(
              onPressed: _isAccepting
                  ? null
                  : () async {
                      setDlgState(() => _isAccepting = true);
                      try {
                        await _repository.updateStatus(_proposal!.id, ProposalStatus.closed);
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                        }
                        if (mounted) {
                          setState(() {
                            _hasAccepted = true;
                            _proposal = _proposal!.copyWith(status: ProposalStatus.closed);
                          });
                          _showSuccessAcceptanceDialog();
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Erro ao registrar aceite: $e'), backgroundColor: Colors.red),
                          );
                        }
                      } finally {
                        if (ctx.mounted) {
                          setDlgState(() => _isAccepting = false);
                        }
                      }
                    },
              icon: _isAccepting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.verified_rounded, size: 18),
              label: const Text('CONFIRMAR ACEITE'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSuccessAcceptanceDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 46),
            ),
            const SizedBox(height: 16),
            Text(
              'Parabéns! Proposta Aceita!',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            Text(
              'Sua usina solar foi reservada com sucesso. Nossa equipe de especialistas já recebeu sua solicitação e entrará em contato em breve.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF475569), height: 1.4),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _openWhatsApp();
              },
              icon: const Icon(Icons.chat_rounded, size: 18),
              label: const Text('FALAR NO WHATSAPP AGORA'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0B1120),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: CircularProgressIndicator(color: Color(0xFFF59E0B), strokeWidth: 3),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Carregando Proposta Solar Interativa...',
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null || _proposal == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0B1120),
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            padding: const EdgeInsets.all(32),
            margin: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 54),
                const SizedBox(height: 16),
                Text(
                  'Não foi possível abrir a proposta',
                  style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage ?? 'Link inválido ou expirado.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _loadData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('TENTAR NOVAMENTE'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final solarItem = _solarPlantItem!;
    final kwp = solarItem.solarKilowatts ?? solarItem.solarPowerKwp ?? (solarItem.quantity * (solarItem.effectiveModuleWatts ?? 550.0) / 1000.0);
    final moduleWatts = solarItem.effectiveModuleWatts ?? 615.0;
    int modulesCount = 0;
    String inverterModel = 'Inversor Solar Grid-Tie';
    double inverterKw = kwp > 0 ? (kwp * 0.9).clamp(3.0, 100.0) : 8.0;

    if (solarItem.solarComponents != null) {
      for (final comp in solarItem.solarComponents!) {
        final lower = comp.toLowerCase();
        if (lower.contains('módulo') || lower.contains('modulo') || lower.contains('painel') || lower.contains('placa')) {
          final match = RegExp(r'(\d+)\s*(?:x|un)?').firstMatch(comp);
          if (match != null) {
            modulesCount = int.tryParse(match.group(1)!) ?? modulesCount;
          }
        }
        if (lower.contains('inversor') || lower.contains('microinversor')) {
          inverterModel = comp;
        }
      }
    }
    if (modulesCount == 0 && kwp > 0 && moduleWatts > 0) {
      modulesCount = (kwp * 1000 / moduleWatts).round();
    }
    final roofType = solarItem.solarRoofType ?? 'Telhado Cerâmico';
    final generationMonthly = kwp > 0 ? (kwp * 115.0) : 990.0;
    final occupiedArea = modulesCount > 0 ? (modulesCount * 2.58) : 36.4;
    final annualSavings = generationMonthly * _settings.energyTariff * 12.0 * 0.92;
    final simulation = _settings.calculateYearlySimulation(monthlyKwh: generationMonthly, systemKwp: kwp);
    final bgImageName = _settings.webBackgroundTemplate;

    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      body: Stack(
        children: [
          // ── 1. Wallpaper de Fundo Selecionável (Firebase Storage) ────
          Positioned.fill(
            child: Image.network(
              SolarSettingsService.getWebBackgroundUrl(bgImageName),
              fit: BoxFit.cover,
              errorBuilder: (ctx, err, stack) => Container(
                color: const Color(0xFF0F172A),
              ),
            ),
          ),

          // ── 2. Overlay Escuro com Glassmorphism ─────────────────────────────
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF0B1120).withValues(alpha: 0.82),
                    const Color(0xFF0F172A).withValues(alpha: 0.90),
                    const Color(0xFF0B1120).withValues(alpha: 0.96),
                  ],
                ),
              ),
            ),
          ),

          // ── 3. Conteúdo Principal Rolável e Responsivo ─────────────────────
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 768;

                return SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 16 : 32,
                    vertical: 20,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1040),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ── Top Brand Bar ─────────────────────────────────
                          _buildTopNavBar(isMobile),
                          const SizedBox(height: 24),

                          // ── Hero Banner da Proposta ────────────────────────
                          _buildHeroBanner(isMobile),
                          const SizedBox(height: 20),

                          // ── 4 KPI Highlights ──────────────────────────────
                          _buildKpiGrid(
                            kwp: kwp,
                            generationMonthly: generationMonthly,
                            annualSavings: annualSavings,
                            isMobile: isMobile,
                          ),
                          const SizedBox(height: 24),

                          // ── Card 1: Ficha Técnica da Usina ────────────────
                          _buildTechnicalCard(
                            kwp: kwp,
                            modulesCount: modulesCount,
                            moduleWatts: moduleWatts,
                            inverterModel: inverterModel,
                            inverterKw: inverterKw,
                            roofType: roofType,
                            generationMonthly: generationMonthly,
                            occupiedArea: occupiedArea,
                            isMobile: isMobile,
                          ),
                          const SizedBox(height: 24),

                          // ── Card 2: Equipamentos & Escopo Turn-Key ─────────
                          _buildEquipmentsAndScopeCard(solarItem, isMobile),
                          const SizedBox(height: 24),

                          // ── Card 3: Análise Financeira & Economia 25 Anos ──
                          _buildFinancialSimulationCard(simulation, isMobile),
                          const SizedBox(height: 24),

                          // ── Card 4: Simulador de Formas de Pagamento ──────
                          _buildPaymentSimulatorCard(isMobile),
                          const SizedBox(height: 24),

                          // ── Card 5: Aceite Digital & Call to Action ───────
                          _buildAcceptanceCard(isMobile),
                          const SizedBox(height: 32),

                          // ── Footer ────────────────────────────────────────
                          _buildFooter(isMobile),
                          const SizedBox(height: 80), // Espaço para floating bar
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // ── 4. Floating Action Bar (Barra Fixa Inferior) ────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomStickyBar(),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // SEÇÃO: NAVBAR SUPERIOR
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildTopNavBar(bool isMobile) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo & Nome da Empresa
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_primaryColor, _primaryColor.withValues(alpha: 0.7)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Icon(Icons.solar_power_rounded, color: Colors.white, size: 22),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _settings.companyName ?? 'Mavis Solar',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    _settings.companySlogan ?? 'Energia que Transforma',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Botões de Ação Rápida
          Row(
            children: [
              IconButton(
                onPressed: _copyShareLink,
                tooltip: 'Compartilhar Link da Proposta',
                icon: const Icon(Icons.share_rounded, color: Color(0xFF94A3B8), size: 20),
              ),
              if (!isMobile) ...[
                const SizedBox(width: 6),
                OutlinedButton.icon(
                  onPressed: _isGeneratingPdf ? null : _downloadPdf,
                  icon: _isGeneratingPdf
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.picture_as_pdf_rounded, size: 16),
                  label: const Text('BAIXAR PDF'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF475569)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              ElevatedButton.icon(
                onPressed: _openWhatsApp,
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                label: Text(isMobile ? 'WHATSAPP' : 'FALAR NO WHATSAPP'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // SEÇÃO: HERO BANNER
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildHeroBanner(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 20 : 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1E293B).withValues(alpha: 0.95),
            const Color(0xFF0F172A).withValues(alpha: 0.98),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _primaryColor.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withValues(alpha: 0.15),
            blurRadius: 25,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _primaryColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _primaryColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt_rounded, size: 14, color: _primaryColor),
                    const SizedBox(width: 4),
                    Text(
                      'PROPOSTA COMERCIAL EXCLUSIVA',
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _hasAccepted
                      ? const Color(0xFF10B981).withValues(alpha: 0.2)
                      : const Color(0xFFF59E0B).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _hasAccepted ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                  ),
                ),
                child: Text(
                  _hasAccepted ? '✓ ACEITA PELO CLIENTE' : '● PROPOSTA ATIVA',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _hasAccepted ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _proposal!.title.isNotEmpty ? _proposal!.title : 'Usina Solar Fotovoltaica Conectada à Rede',
            style: GoogleFonts.outfit(
              fontSize: isMobile ? 22 : 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 20,
            runSpacing: 10,
            children: [
              _heroMetaItem(Icons.person_rounded, 'Cliente:', _proposal!.clientName),
              _heroMetaItem(Icons.tag_rounded, 'Proposta:', _proposal!.proposalNumber),
              _heroMetaItem(Icons.calendar_today_rounded, 'Emissão:', _dateFormat.format(_proposal!.createdAt)),
              if (_proposal!.clientAddress != null && _proposal!.clientAddress!.isNotEmpty)
                _heroMetaItem(Icons.location_on_rounded, 'Local:', _proposal!.clientAddress!),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroMetaItem(IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 5),
        Text(
          '$label ',
          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
        ),
        Text(
          value,
          style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // SEÇÃO: KPI HIGHLIGHTS
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildKpiGrid({
    required double kwp,
    required double generationMonthly,
    required double annualSavings,
    required bool isMobile,
  }) {
    final kpis = [
      {
        'title': 'Potência da Usina',
        'value': '${kwp.toStringAsFixed(2)} kWp',
        'subtitle': 'Alta Performance Tier 1',
        'icon': Icons.bolt_rounded,
        'color': const Color(0xFFF59E0B),
      },
      {
        'title': 'Geração Média',
        'value': '${generationMonthly.toStringAsFixed(0)} kWh/mês',
        'subtitle': 'Energia limpa e inesgotável',
        'icon': Icons.wb_sunny_rounded,
        'color': const Color(0xFF38BDF8),
      },
      {
        'title': 'Economia 1º Ano',
        'value': _currencyFormat.format(annualSavings),
        'subtitle': 'Retorno rápido do capital',
        'icon': Icons.trending_up_rounded,
        'color': const Color(0xFF10B981),
      },
      {
        'title': 'Redução na Conta',
        'value': 'Até 95%',
        'subtitle': 'Proteção contra inflação energética',
        'icon': Icons.shield_rounded,
        'color': const Color(0xFF8B5CF6),
      },
    ];

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final crossCount = constraints.maxWidth > 800 ? 4 : (constraints.maxWidth > 500 ? 2 : 1);
        final itemWidth = (constraints.maxWidth - ((crossCount - 1) * 14)) / crossCount;

        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: kpis.map((kpi) {
            final color = kpi['color'] as Color;
            return Container(
              width: itemWidth,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        kpi['title'] as String,
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF94A3B8)),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(kpi['icon'] as IconData, size: 16, color: color),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    kpi['value'] as String,
                    style: GoogleFonts.outfit(fontSize: 21, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    kpi['subtitle'] as String,
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // CARD 1: FICHA TÉCNICA
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildTechnicalCard({
    required double kwp,
    required int modulesCount,
    required double moduleWatts,
    required String inverterModel,
    required double inverterKw,
    required String roofType,
    required double generationMonthly,
    required double occupiedArea,
    required bool isMobile,
  }) {
    final specs = [
      {'label': 'Potência Total do Sistema', 'value': '${kwp.toStringAsFixed(2)} kWp', 'icon': Icons.bolt_rounded},
      {'label': 'Quantidade de Painéis', 'value': '$modulesCount módulos solares', 'icon': Icons.grid_view_rounded},
      {'label': 'Potência do Módulo Solar', 'value': '${moduleWatts.toStringAsFixed(0)} Watts Monocristalino Tier 1', 'icon': Icons.wb_sunny_outlined},
      {'label': 'Inversor / Microinversor', 'value': '$inverterModel ${inverterKw.toStringAsFixed(0)} kWp', 'icon': Icons.settings_input_component_rounded},
      {'label': 'Tipo de Estrutura & Fixação', 'value': roofType, 'icon': Icons.roofing_rounded},
      {'label': 'Geração Média Estimada', 'value': '${generationMonthly.toStringAsFixed(2)} kWh/mês', 'icon': Icons.show_chart_rounded},
      {'label': 'Área Estimada Ocupada', 'value': '${occupiedArea.toStringAsFixed(2)} m²', 'icon': Icons.straighten_rounded},
    ];

    return _cardWrapper(
      title: 'Sua Usina Solar Fotovoltaica',
      subtitle: 'Especificações técnicas dos equipamentos selecionados sob medida',
      icon: Icons.solar_power_rounded,
      child: Column(
        children: specs.map((spec) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF334155), width: 0.8)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _primaryColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(spec['icon'] as IconData, size: 16, color: _primaryColor),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      spec['label'] as String,
                      style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFFCBD5E1), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                Text(
                  spec['value'] as String,
                  style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // CARD 2: EQUIPAMENTOS & ESCOPO
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildEquipmentsAndScopeCard(ProposalItemModel solarItem, bool isMobile) {
    final components = solarItem.solarComponents ?? [];

    final scopeItems = [
      {
        'title': 'Projeto de Engenharia & ART',
        'desc': 'Engenheiro responsável com recolhimento oficial da ART.',
        'icon': Icons.architecture_rounded,
      },
      {
        'title': 'Homologação na Distribuidora',
        'desc': 'Trâmite completo até a emissão do Parecer de Acesso e troca do medidor.',
        'icon': Icons.verified_user_rounded,
      },
      {
        'title': 'Instalação e Montagem Turn-Key',
        'desc': 'Equipe técnica capacitada (NR-10 e NR-35) sem transtornos na sua obra.',
        'icon': Icons.handyman_rounded,
      },
      {
        'title': 'Monitoramento no Celular 24h',
        'desc': 'Aplicativo móvel em tempo real com acompanhamento diário da geração.',
        'icon': Icons.phone_android_rounded,
      },
    ];

    return _cardWrapper(
      title: 'Equipamentos Inclusos & Escopo Turn-Key',
      subtitle: 'Tudo incluso: do projeto e entrega até a ligação na rede elétrica',
      icon: Icons.checklist_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Lista de Equipamentos
          if (components.isNotEmpty) ...[
            Text('Equipamentos Fornecidos no Kit:', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 10),
            ...components.map((comp) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle_rounded, size: 16, color: _primaryColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        comp.toUpperCase(),
                        style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFFE2E8F0)),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 20),
            const Divider(color: Color(0xFF334155)),
            const SizedBox(height: 16),
          ],

          // Grid de Escopo
          Text('Escopo de Serviços Inclusos:', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (ctx, constraints) {
              final crossCount = constraints.maxWidth > 600 ? 2 : 1;
              final width = (constraints.maxWidth - ((crossCount - 1) * 12)) / crossCount;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: scopeItems.map((item) {
                  return Container(
                    width: width,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _primaryColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(item['icon'] as IconData, size: 20, color: _primaryColor),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['title'] as String,
                                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                item['desc'] as String,
                                style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF94A3B8), height: 1.25),
                              ),
                            ],
                          ),
                        ),
                      ],
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

  // ───────────────────────────────────────────────────────────────────────────
  // CARD 3: ANÁLISE FINANCEIRA & SIMULAÇÃO 25 ANOS
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildFinancialSimulationCard(List<EnergyBillYearItem> simulation, bool isMobile) {
    double totalSavings25 = 0.0;
    for (final item in simulation) {
      final avgWithSolar = (item.withSolarMin + item.withSolarMax) / 2.0;
      totalSavings25 += (item.withoutSolar - avgWithSolar) * 12.0;
    }

    return _cardWrapper(
      title: 'Análise de Economia & Retorno do Investimento',
      subtitle: 'Veja quanto você vai economizar ano a ano comparado à conta tradicional',
      icon: Icons.monetization_on_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner de Destaque da Economia Total
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF059669).withValues(alpha: 0.2), const Color(0xFF10B981).withValues(alpha: 0.1)],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Economia Estimada em 25 Anos',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF34D399)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currencyFormat.format(totalSavings25),
                      style: GoogleFonts.outfit(fontSize: isMobile ? 22 : 28, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'PAYBACK ~3 ANOS',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Tabela dos Primeiros 5 Anos de Simulação
          Text('Projeção das Contas nos Primeiros Anos:', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              children: [
                // Header da Tabela
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E293B),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
                  ),
                  child: Row(
                    children: [
                      Expanded(flex: 2, child: Text('ANO', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8)))),
                      Expanded(flex: 4, child: Text('COM SOLAR (MÊS)', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF34D399)))),
                      Expanded(flex: 4, child: Text('SEM SOLAR (MÊS)', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFF87171)))),
                      Expanded(flex: 4, child: Text('ECONOMIA ANUAL', textAlign: TextAlign.right, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white))),
                    ],
                  ),
                ),
                // Linhas dos Anos
                ...simulation.take(5).map((item) {
                  final avgWithSolar = (item.withSolarMin + item.withSolarMax) / 2.0;
                  final annualSaved = (item.withoutSolar - avgWithSolar) * 12.0;

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFF1E293B), width: 0.8)),
                    ),
                    child: Row(
                      children: [
                        Expanded(flex: 2, child: Text('${item.year}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white))),
                        Expanded(flex: 4, child: Text(_currencyFormat.format(avgWithSolar), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF34D399)))),
                        Expanded(flex: 4, child: Text(_currencyFormat.format(item.withoutSolar), style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFF87171)))),
                        Expanded(flex: 4, child: Text(_currencyFormat.format(annualSaved), textAlign: TextAlign.right, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white))),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // CARD 4: SIMULADOR DE FORMAS DE PAGAMENTO
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildPaymentSimulatorCard(bool isMobile) {
    final total = _proposal?.totalAmount ?? 0.0;
    final installmentVal = _selectedBank != null
        ? _selectedBank!.calculateInstallment(total, _selectedInstallmentMonths)
        : 0.0;

    return _cardWrapper(
      title: 'Condições de Pagamento & Simulador Financeiro',
      subtitle: 'Escolha a melhor modalidade: à vista com desconto ou parcelas que cabem no bolso',
      icon: Icons.account_balance_wallet_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Opção 1: À Vista ─────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF059669), width: 1.2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF059669).withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.pix_rounded, color: Color(0xFF10B981), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Pagamento À Vista (PIX ou TED)', style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.white)),
                        Text('Sem juros e com início imediato do projeto', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
                      ],
                    ),
                  ],
                ),
                Text(
                  _currencyFormat.format(total),
                  style: GoogleFonts.outfit(fontSize: 19, fontWeight: FontWeight.bold, color: const Color(0xFF34D399)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Opção 2: Financiamento Solar Bancário ──────────────────────────
          if (_settings.financingBanks.isNotEmpty) ...[
            Text('Simulação de Financiamento Solar Bancário:', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 10),

            // Seletor de Banco
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _settings.financingBanks.where((b) => b.isActive).map((bank) {
                  final isSelected = _selectedBank?.id == bank.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(bank.name),
                      selected: isSelected,
                      selectedColor: _primaryColor,
                      labelStyle: GoogleFonts.inter(
                        color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                      onSelected: (val) {
                        if (val) {
                          setState(() {
                            _selectedBank = bank;
                            if (!bank.enabledInstallments.contains(_selectedInstallmentMonths)) {
                              _selectedInstallmentMonths = bank.enabledInstallments.last;
                            }
                          });
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),

            // Seletor de Meses
            if (_selectedBank != null) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _selectedBank!.enabledInstallments.map((months) {
                  final isSel = _selectedInstallmentMonths == months;
                  final val = _selectedBank!.calculateInstallment(total, months);

                  return InkWell(
                    onTap: () => setState(() => _selectedInstallmentMonths = months),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSel ? _primaryColor.withValues(alpha: 0.25) : const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSel ? _primaryColor : const Color(0xFF334155),
                          width: isSel ? 1.8 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text('$months' 'x', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold, color: isSel ? Colors.white : const Color(0xFF94A3B8))),
                          const SizedBox(height: 2),
                          Text(_currencyFormat.format(val), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: isSel ? const Color(0xFF38BDF8) : Colors.white)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 16),

            // Card Resumo do Financiamento
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.energy_savings_leaf_rounded, color: Color(0xFF10B981), size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sua usina se paga sozinha!',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        Text(
                          'A parcela de ${_currencyFormat.format(installmentVal)} substitui sua conta de luz tradicional. Ao quitar, toda a energia gerada é 100% lucro para você!',
                          style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF94A3B8), height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // CARD 5: ACEITE DIGITAL & CALL TO ACTION
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildAcceptanceCard(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 22 : 30),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1E293B),
            const Color(0xFF0F172A),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.12),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 34),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _hasAccepted ? 'Proposta Aceita com Sucesso!' : 'Gostou da proposta? Vamos começar!',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: isMobile ? 22 : 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Text(
              _hasAccepted
                  ? 'Obrigado pela confiança! Nossa equipe de engenharia já está preparando o projeto executivo e entrará em contato.'
                  : 'Formalize seu interesse em 1 clique para garantirmos os equipamentos e iniciarmos a documentação técnica junto à concessionária de energia.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8), height: 1.4),
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 14,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              if (!_hasAccepted)
                ElevatedButton.icon(
                  onPressed: _showAcceptProposalDialog,
                  icon: const Icon(Icons.check_circle_rounded, size: 20),
                  label: const Text('ACEITAR ESTA PROPOSTA AGORA'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
                    textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ElevatedButton.icon(
                onPressed: _openWhatsApp,
                icon: const Icon(Icons.chat_rounded, size: 20),
                label: const Text('FALAR COM O CONSULTOR NO WHATSAPP'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  textStyle: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // SEÇÃO: FOOTER
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildFooter(bool isMobile) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFF334155), width: 0.8)),
      ),
      child: Column(
        children: [
          Text(
            _settings.companyName ?? 'Mavis CRM Solar',
            style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 4),
          if (_settings.companyDocument != null && _settings.companyDocument!.isNotEmpty)
            Text(
              'CNPJ: ${_settings.companyDocument}',
              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
            ),
          const SizedBox(height: 8),
          Text(
            '${_settings.companySlogan ?? 'Energia que Transforma'} • Gerado via Mavis Solar CRM',
            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF475569)),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // FLOATING BOTTOM DOCK
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildBottomStickyBar() {
    final total = _proposal?.totalAmount ?? 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.95),
        border: const Border(top: BorderSide(color: Color(0xFF334155), width: 1.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Investimento da Usina', style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF94A3B8))),
                  Text(
                    _currencyFormat.format(total),
                    style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF34D399)),
                  ),
                ],
              ),
              Row(
                children: [
                  if (!_hasAccepted)
                    ElevatedButton(
                      onPressed: _showAcceptProposalDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('ACEITAR PROPOSTA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _openWhatsApp,
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.chat_rounded, size: 18),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // HELPER: CARD WRAPPER
  // ───────────────────────────────────────────────────────────────────────────
  Widget _cardWrapper({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF334155)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _primaryColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: _primaryColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}
