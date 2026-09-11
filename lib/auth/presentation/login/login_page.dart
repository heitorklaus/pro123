import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../settings/data/services/company_service.dart';
import '../../../settings/data/services/settings_service.dart';
import '../../data/repositories/auth_repository.dart';
import 'login_store.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final controller = Modular.get<LoginStore>();

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _isDevToolsExpanded = false;
  bool _isQuickLoading = false;

  @override
  void initState() {
    super.initState();
    // Preenche se já houver salvo no controller
    _emailCtrl.text = controller.email;
    _passwordCtrl.text = controller.password;
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ROTINAS DE DEV (TESTES RÁPIDOS)
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _handleQuickTestCnpj31() async {
    setState(() => _isQuickLoading = true);
    try {
      await CompanyService.deleteCompanyByCnpj('31965255000112');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('taos_onboarding_step', 1);
      await prefs.remove('taos_onboarding_sector');
      await prefs.remove('mavis_crm_has_completed_onboarding');
      await SettingsService.setCompletedOnboarding(false);

      final ts = DateTime.now().millisecondsSinceEpoch;
      final email = 'teste_cnpj31_$ts@mavis.com.br';
      final name = 'Empresa Teste 31';
      const password = '123456';

      final repo = AuthRepository();
      await repo.registerUser(
        name: name,
        email: email,
        password: password,
        role: 'admin',
      );

      if (mounted) {
        Modular.to.navigate('/dashboard/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao preparar teste com CNPJ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isQuickLoading = false);
    }
  }

  Future<void> _handleQuickRegister() async {
    setState(() => _isQuickLoading = true);
    try {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final email = 'teste_$ts@mavis.com.br';
      final name = 'Empresa Teste #${ts % 10000}';
      const password = '123456';

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('taos_onboarding_step', 1);
      await prefs.remove('taos_onboarding_sector');
      await prefs.remove('mavis_crm_has_completed_onboarding');
      await SettingsService.setCompletedOnboarding(false);

      final repo = AuthRepository();
      await repo.registerUser(
        name: name,
        email: email,
        password: password,
        role: 'admin',
      );

      if (mounted) {
        Modular.to.navigate('/dashboard/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao criar conta teste: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isQuickLoading = false);
    }
  }

  Future<void> _handleQuickLoginTeste2() async {
    setState(() => _isQuickLoading = true);
    try {
      _emailCtrl.text = 'teste2@teste2.com.br';
      _passwordCtrl.text = '130505';
      controller.setEmail('teste2@teste2.com.br');
      controller.setPassword('130505');
      final success = await controller.login();
      if (success && mounted) {
        Modular.to.navigate('/dashboard/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao logar como teste2: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isQuickLoading = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ESQUECI MINHA SENHA
  // ─────────────────────────────────────────────────────────────────────────
  void _handleForgotPassword() {
    final resetEmailCtrl = TextEditingController(text: _emailCtrl.text.trim());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.lock_reset_rounded, color: Color(0xFF00B4D8), size: 26),
            const SizedBox(width: 8),
            Text(
              'Recuperar Senha',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Informe o e-mail associado à sua conta para enviarmos as instruções de redefinição:',
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF475569)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: resetEmailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'E-mail cadastrado',
                hintText: 'seuemail@empresa.com.br',
                prefixIcon: const Icon(Icons.mail_outline_rounded, size: 18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'CANCELAR',
              style: GoogleFonts.inter(color: const Color(0xFF64748B), fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00B4D8),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final email = resetEmailCtrl.text.trim();
              if (email.isEmpty || !email.contains('@')) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Por favor, informe um e-mail válido.'),
                    backgroundColor: Colors.amber,
                  ),
                );
                return;
              }
              Navigator.of(ctx).pop();
              try {
                await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('E-mail de recuperação enviado para $email! Verifique sua caixa de entrada.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Erro ao enviar e-mail de recuperação: $e'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              }
            },
            child: const Text('ENVIAR LINK'),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD PRINCIPAL
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWidescreen = size.width >= 1080;

    return Scaffold(
      backgroundColor: const Color(0xFF060B17),
      body: Stack(
        children: [
          // ── FUNDO CIBERNÉTICO COM GRADE E GLOWS NEON ──
          Positioned.fill(
            child: CustomPaint(
              painter: _LoginCyberGridPainter(),
            ),
          ),

          // ── CONTEÚDO PRINCIPAL ──
          SafeArea(
            child: isWidescreen
                ? _buildDesktopLayout(size)
                : _buildResponsiveLayout(size),
          ),

          // ── JANELA FLUTUANTE MINIMIZÁVEL DE FERRAMENTAS DEV ──
          _buildDevFloatingWindow(),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LAYOUT DESKTOP WIDESCREEN (CENA HOLOGRÁFICA: MONITOR SAINDO DO CARD)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildDesktopLayout(Size size) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1620),
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── COLUNA 1: BRANDING, HEADLINE & FEATURES ──
            Expanded(
              flex: 36,
              child: _buildLeftBrandColumn(),
            ),

            const SizedBox(width: 20),

            // ── COLUNA 2: CENA 3D (MONITOR SAINDO DE DENTRO DO CARD DE LOGIN) ──
            Expanded(
              flex: 64,
              child: _buildHolographicScene(),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CENA HOLOGRÁFICA: MONITOR 3D EMERGINDO DO CARD DE LOGIN + BADGES FLUTUANTES
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildHolographicScene() {
    return SizedBox(
      height: 680,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.centerRight,
        children: [
          // 1. Feixes de Luz e Portal Holográfico emanando do Card de Login
          Positioned.fill(
            child: CustomPaint(
              painter: _HolographicPortalPainter(),
            ),
          ),

          // 2. Anotação Manuscrita no topo com seta curvada apontando
          Positioned(
            top: 15,
            left: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mais negócios.\nMais resultados.',
                  style: GoogleFonts.caveat(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF38BDF8),
                    height: 1.15,
                  ),
                ),
                const SizedBox(width: 10),
                CustomPaint(
                  size: const Size(44, 52),
                  painter: _CurvedArrowPainter(),
                ),
              ],
            ),
          ),

          // 3. O Monitor 3D Transparente Projetando-se para fora do Card de Login
          Positioned(
            top: 50,
            bottom: 50,
            left: 0,
            right: 220, // Passa por trás do card de login (largura 430), criando a sobreposição 3D
            child: Image.asset(
              'assets/images/login/crm_screen_transparent.png',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, __, ___) => Image.asset(
                'assets/images/login/93ddf6b7-f724-4855-b538-076d0f6a208e.png',
                fit: BoxFit.contain,
              ),
            ),
          ),

          // 4. Badge Flutuante 1 (Topo Esquerdo): Proposta Aprovada
          Positioned(
            top: 60,
            left: 20,
            child: _buildFloatingMetricBadge(
              icon: Icons.check_circle_rounded,
              iconColor: const Color(0xFF10B981),
              label: 'Proposta Aprovada',
              value: 'R\$ 28.900',
              valueColor: const Color(0xFF34D399),
              glowColor: const Color(0xFF10B981),
            ),
          ),

          // 5. Badge Flutuante 2 (Topo Centro): Crescimento de Vendas
          Positioned(
            top: 25,
            right: 360,
            child: _buildFloatingMetricBadge(
              icon: Icons.trending_up_rounded,
              iconColor: const Color(0xFF00E5FF),
              label: 'Vendas no mês',
              value: '+27% ↑',
              valueColor: const Color(0xFF00E5FF),
              glowColor: const Color(0xFF00B4D8),
            ),
          ),

          // 6. Card Holográfico 3D da IA do TAOS na base esquerda
          Positioned(
            bottom: 30,
            left: 20,
            width: 330,
            child: Image.asset(
              'assets/images/login/29737c2f-1068-4ae5-af99-4083fd807eec.png',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),

          // 7. Badge Flutuante 3 (Base Centro): IA Conectada
          Positioned(
            bottom: 35,
            right: 350,
            child: _buildFloatingMetricBadge(
              icon: Icons.auto_awesome_rounded,
              iconColor: const Color(0xFFF59E0B),
              label: 'IA Copilot',
              value: 'Análise Ativa ✦',
              valueColor: const Color(0xFFFCD34D),
              glowColor: const Color(0xFFF59E0B),
            ),
          ),

          // 8. O Card Branco de Login (Fica na frente, de onde os hologramas emergem)
          Positioned(
            right: 0,
            width: 430,
            child: _buildLoginCard(),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BADGES FLUTUANTES DE COMPOSIÇÃO HOLOGRÁFICA
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildFloatingMetricBadge({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required Color glowColor,
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF0A152B).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: glowColor.withValues(alpha: 0.55), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: glowColor.withValues(alpha: 0.28),
            blurRadius: 16,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 16),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: valueColor ?? Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LAYOUT RESPONSIVO (TABLETS E MOBILE)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildResponsiveLayout(Size size) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo no topo mobile
              Center(child: _buildBrandLogo(isDarkBackground: true)),
              const SizedBox(height: 24),

              // Card de Login no topo
              _buildLoginCard(),
              const SizedBox(height: 36),

              // Headline institucional
              Text(
                'Propostas que impressionam. Gestão que pensa com você.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Vendas, clientes, propostas e inteligência artificial em um só lugar.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 28),

              // 3 Features
              _buildFeaturesRow(),
              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // COLUNA ESQUERDA: BRANDING, HEADLINE, FEATURES E RODAPÉ
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildLeftBrandColumn() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Logo oficial TAOS CRM
        _buildBrandLogo(isDarkBackground: true),
        const SizedBox(height: 44),

        // Título de Alto Impacto
        RichText(
          text: TextSpan(
            style: GoogleFonts.outfit(
              fontSize: 42,
              height: 1.15,
              fontWeight: FontWeight.w800,
            ),
            children: const [
              TextSpan(
                text: 'Propostas que\n',
                style: TextStyle(color: Colors.white),
              ),
              TextSpan(
                text: 'impressionam.\n',
                style: TextStyle(color: Color(0xFF00E5FF)),
              ),
              TextSpan(
                text: 'Gestão que pensa\n',
                style: TextStyle(color: Colors.white),
              ),
              TextSpan(
                text: 'com você.',
                style: TextStyle(color: Color(0xFF00E5FF)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Subtítulo
        Text(
          'Vendas, clientes, propostas e inteligência\nartificial em um só lugar.',
          style: GoogleFonts.inter(
            fontSize: 15.5,
            color: const Color(0xFF94A3B8),
            height: 1.45,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 44),

        // 3 Ícones 3D com Legendas
        _buildFeaturesRow(),
        const SizedBox(height: 48),

        // Rodapé Institucional com Barra Neon Ciano
        Row(
          children: [
            Container(
              width: 3.5,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFF00E5FF),
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.6),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Text(
              'Tecnologia que impulsiona\nresultados reais.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF64748B),
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 3 FEATURES COM ÍCONES 3D
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildFeaturesRow() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFeatureItem(
          imagePath: 'assets/images/login/b69f61f1-663b-4cc4-981a-1b4f51844277.png',
          fallbackIcon: Icons.description_rounded,
          title: 'Propostas\nprofissionais',
        ),
        const SizedBox(width: 24),
        _buildFeatureItem(
          imagePath: 'assets/images/login/1c8a4419-fd65-4c57-8cb3-eef633a90ebc.png',
          fallbackIcon: Icons.psychology_rounded,
          title: 'IA integrada\n',
        ),
        const SizedBox(width: 24),
        _buildFeatureItem(
          imagePath: 'assets/images/login/2e695fb0-67d2-4269-a8c0-3cd8a94ed006.png',
          fallbackIcon: Icons.bar_chart_rounded,
          title: 'Gestão\ncompleta',
        ),
      ],
    );
  }

  Widget _buildFeatureItem({
    required String imagePath,
    required IconData fallbackIcon,
    required String title,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 56,
          height: 56,
          child: Image.asset(
            imagePath,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            errorBuilder: (_, __, ___) => Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0B162C),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.5)),
              ),
              child: Icon(fallbackIcon, color: const Color(0xFF00E5FF), size: 26),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          title,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFFE2E8F0),
            height: 1.25,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CARD BRANCO DE LOGIN (LADO DIREITO)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildLoginCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 48,
            offset: const Offset(0, 20),
          ),
          BoxShadow(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
            blurRadius: 30,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 38),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Logo TAOS CRM no topo do Card Branco
          Center(
            child: _buildBrandLogo(isDarkBackground: false),
          ),
          const SizedBox(height: 18),

          // Título e Subtítulo do Card
          Text(
            'Bem-vindo ao TAOS',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 23,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Acesse sua conta para continuar',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 24),

          // Alerta de Erro MobX
          Observer(
            builder: (_) {
              if (controller.errorMessage == null) {
                return const SizedBox.shrink();
              }
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        controller.errorMessage!,
                        style: GoogleFonts.inter(
                          color: const Color(0xFF991B1B),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Campo E-mail
          Text(
            'E-mail',
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _emailCtrl,
            onChanged: controller.setEmail,
            keyboardType: TextInputType.emailAddress,
            style: GoogleFonts.inter(color: const Color(0xFF0F172A), fontSize: 13.5),
            decoration: InputDecoration(
              hintText: 'seuemail@empresa.com.br',
              hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13),
              prefixIcon: const Icon(Icons.mail_outline_rounded, color: Color(0xFF64748B), size: 18),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF00B4D8), width: 1.8),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Campo Senha
          Text(
            'Senha',
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 6),
          Observer(
            builder: (_) => TextFormField(
              controller: _passwordCtrl,
              onChanged: controller.setPassword,
              obscureText: controller.obscurePassword,
              style: GoogleFonts.inter(color: const Color(0xFF0F172A), fontSize: 13.5),
              decoration: InputDecoration(
                hintText: 'Digite sua senha',
                hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13),
                prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF64748B), size: 18),
                suffixIcon: IconButton(
                  icon: Icon(
                    controller.obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: const Color(0xFF64748B),
                    size: 18,
                  ),
                  onPressed: controller.toggleObscurePassword,
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF00B4D8), width: 1.8),
                ),
              ),
            ),
          ),

          // Esqueci minha senha
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _handleForgotPassword,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Esqueci minha senha',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0284C7),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Botão ENTRAR com Gradiente Ciano -> Turquesa Esmeralda
          Observer(
            builder: (_) => Container(
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF00B4D8),
                    Color(0xFF00E5A3),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00B4D8).withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: (controller.isLoading || controller.isGoogleLoading || _isQuickLoading)
                    ? null
                    : () async {
                        final success = await controller.login();
                        if (success && context.mounted) {
                          Modular.to.navigate('/dashboard/');
                        }
                      },
                child: controller.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Entrar',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Divisor "ou continue com"
          Row(
            children: [
              const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'ou continue com',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ),
              const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
            ],
          ),
          const SizedBox(height: 16),

          // Botão Continuar com Google
          Observer(
            builder: (_) => Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: (controller.isLoading || controller.isGoogleLoading || _isQuickLoading)
                    ? null
                    : () async {
                        final success = await controller.loginWithGoogle();
                        if (success && context.mounted) {
                          Modular.to.navigate('/dashboard/');
                        }
                      },
                child: controller.isGoogleLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Color(0xFF00B4D8), strokeWidth: 2.2),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildGoogleIcon(),
                          const SizedBox(width: 10),
                          Text(
                            'Continuar com Google',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Rodapé do Card: "Ainda não tem uma conta? Criar conta grátis"
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Ainda não tem uma conta? ',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  color: const Color(0xFF64748B),
                ),
              ),
              GestureDetector(
                onTap: () => Modular.to.navigate('/auth/register'),
                child: Text(
                  'Criar conta grátis',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF00A3FF),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LOGO DO TAOS CRM
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildBrandLogo({required bool isDarkBackground}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Ícone quadrado escuro com o "T" em ciano
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF0A152B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF00E5FF).withValues(alpha: isDarkBackground ? 0.7 : 0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00E5FF).withValues(alpha: isDarkBackground ? 0.35 : 0.2),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Image.asset(
              'assets/images/taos_t_icon.png',
              width: 26,
              height: 26,
              color: const Color(0xFF00E5FF),
              colorBlendMode: BlendMode.srcIn,
              errorBuilder: (_, __, ___) => const Icon(Icons.bolt_rounded, color: Color(0xFF00E5FF), size: 26),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Palavra T Λ O S
        Text(
          'T Λ O S',
          style: GoogleFonts.outfit(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.6,
            color: isDarkBackground ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(width: 8),

        // Sigla CRM em Ciano Neon
        Text(
          'CRM',
          style: GoogleFonts.outfit(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            color: const Color(0xFF00B4D8),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ÍCONE OFICIAL MULTICOLOR DO GOOGLE
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildGoogleIcon() {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(
        painter: _GoogleLogoPainter(),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // JANELA FLUTUANTE MINIMIZÁVEL DE DEV TOOLS
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildDevFloatingWindow() {
    return Positioned(
      bottom: 20,
      left: 20,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: animation, alignment: Alignment.bottomLeft, child: child),
        ),
        child: _isDevToolsExpanded
            ? _buildExpandedDevWindow()
            : _buildMinimizedDevButton(),
      ),
    );
  }

  Widget _buildMinimizedDevButton() {
    return Material(
      key: const ValueKey('minimized_dev'),
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _isDevToolsExpanded = true),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFF59E0B), width: 1.4),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bug_report_rounded, color: Color(0xFFF59E0B), size: 16),
              const SizedBox(width: 8),
              Text(
                'DEV TOOLS',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFFCD34D),
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.keyboard_arrow_up_rounded, color: Color(0xFFFCD34D), size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedDevWindow() {
    return Material(
      key: const ValueKey('expanded_dev'),
      color: Colors.transparent,
      child: Container(
        width: 360,
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
              blurRadius: 18,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header da Janela Flutuante com Minimizar
            Row(
              children: [
                const Icon(Icons.terminal_rounded, size: 18, color: Color(0xFFF59E0B)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'DEV TOOLS • ATALHOS DE TESTE',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFFCD34D),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF94A3B8)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Minimizar janela',
                  onPressed: () => setState(() => _isDevToolsExpanded = false),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Botão 1: Testar Onboarding com CNPJ 31
            ElevatedButton.icon(
              onPressed: _isQuickLoading ? null : _handleQuickTestCnpj31,
              icon: _isQuickLoading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.rocket_launch_rounded, size: 15),
              label: Text(
                '⚡ TESTAR ONBOARDING (CNPJ 31)',
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
            ),
            const SizedBox(height: 8),

            // Botão 2: Cadastro Aleatório
            ElevatedButton.icon(
              onPressed: _isQuickLoading ? null : _handleQuickRegister,
              icon: _isQuickLoading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.flash_on_rounded, size: 15),
              label: Text(
                '⚡ CRIAR CADASTRO TESTE ALEATÓRIO',
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
            ),
            const SizedBox(height: 8),

            // Botão 3: Login Teste 2
            OutlinedButton.icon(
              onPressed: _isQuickLoading ? null : _handleQuickLoginTeste2,
              icon: const Icon(Icons.key_rounded, size: 15, color: Color(0xFF38BDF8)),
              label: Text(
                '🔑 ENTRAR COMO TESTE 2',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF38BDF8),
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
                side: const BorderSide(color: Color(0xFF0284C7), width: 1.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// PINTURA DO FUNDO CIBERNÉTICO (GRADE SUAVE E GLOWS NEON)
// ─────────────────────────────────────────────────────────────────────────
class _LoginCyberGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 1. Fundo Gradiente Espacial Profundo
    final bgPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.25, -0.1),
        radius: 1.2,
        colors: [
          Color(0xFF0B1B38),
          Color(0xFF060F22),
          Color(0xFF040A18),
        ],
        stops: [0.0, 0.55, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // 2. Glow Ciano Neon atrás do monitor central
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF00E5FF).withValues(alpha: 0.08),
          const Color(0xFF0284C7).withValues(alpha: 0.04),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * 0.46, size.height * 0.48),
        radius: size.width * 0.35,
      ));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), glowPaint);

    // 3. Grid Digital Sutil
    final gridPaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.028)
      ..strokeWidth = 1.0;

    const step = 48.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────
// PINTURA DA SETA CURVADA MANUSCRITA
// ─────────────────────────────────────────────────────────────────────────
class _CurvedArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.75)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Linha curva da seta
    final path = Path();
    path.moveTo(size.width * 0.1, size.height * 0.1);
    path.quadraticBezierTo(
      size.width * 0.75,
      size.height * 0.15,
      size.width * 0.82,
      size.height * 0.85,
    );
    canvas.drawPath(path, paint);

    // Ponta da seta
    final arrowHead = Path();
    arrowHead.moveTo(size.width * 0.65, size.height * 0.70);
    arrowHead.lineTo(size.width * 0.82, size.height * 0.85);
    arrowHead.lineTo(size.width * 0.95, size.height * 0.65);
    canvas.drawPath(arrowHead, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────
// LOGO MULTICOLOR VETORIAL DO GOOGLE
// ─────────────────────────────────────────────────────────────────────────
class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final paintBlue = Paint()..color = const Color(0xFF4285F4)..style = PaintingStyle.fill;
    final paintRed = Paint()..color = const Color(0xFFEA4335)..style = PaintingStyle.fill;
    final paintYellow = Paint()..color = const Color(0xFFFBBC05)..style = PaintingStyle.fill;
    final paintGreen = Paint()..color = const Color(0xFF34A853)..style = PaintingStyle.fill;

    // Segmento Vermelho (Topo)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi * 0.75,
      math.pi * 0.5,
      true,
      paintRed,
    );

    // Segmento Amarelo (Esquerda)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi * 1.25,
      math.pi * 0.5,
      true,
      paintYellow,
    );

    // Segmento Verde (Base)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi * 0.25,
      math.pi * 0.5,
      true,
      paintGreen,
    );

    // Segmento Azul (Direita)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi * 0.25,
      math.pi * 0.5,
      true,
      paintBlue,
    );

    // Centro Branco do "G"
    final whitePaint = Paint()..color = Colors.white;
    canvas.drawCircle(center, radius * 0.6, whitePaint);

    // Barra horizontal do "G"
    final barRect = Rect.fromLTWH(
      center.dx,
      center.dy - (radius * 0.2),
      radius,
      radius * 0.4,
    );
    canvas.drawRect(barRect, paintBlue);

    // Recorte do vão superior direito
    final cutoutPaint = Paint()..color = Colors.white;
    final cutoutRect = Rect.fromLTWH(
      center.dx,
      center.dy - (radius * 0.6),
      radius,
      radius * 0.4,
    );
    canvas.drawRect(cutoutRect, cutoutPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────
// PINTURA DO PORTAL HOLOGRÁFICO E FEIXES DE LUZ (SAINDO DO CARD DE LOGIN)
// ─────────────────────────────────────────────────────────────────────────
class _HolographicPortalPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Ponto focal de onde os hologramas emergem: borda esquerda do card de login
    final originX = size.width - 410;
    final originY = size.height * 0.50;

    // 1. Grande cone de feixe de luz ciano translúcido projetando-se para a esquerda
    final conePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerRight,
        end: Alignment.centerLeft,
        colors: [
          const Color(0xFF00E5FF).withValues(alpha: 0.16),
          const Color(0xFF0284C7).withValues(alpha: 0.08),
          const Color(0xFF00E5FF).withValues(alpha: 0.02),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 0.85, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final conePath = Path();
    conePath.moveTo(originX, originY - 180);
    conePath.lineTo(originX, originY + 180);
    conePath.lineTo(size.width * 0.05, size.height * 0.90);
    conePath.lineTo(size.width * 0.15, size.height * 0.08);
    conePath.close();
    canvas.drawPath(conePath, conePaint);

    // 2. Anéis / arcos holográficos de emissão luminosa em perspectiva
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..shader = SweepGradient(
        colors: [
          const Color(0xFF00E5FF).withValues(alpha: 0.35),
          const Color(0xFF0284C7).withValues(alpha: 0.10),
          Colors.transparent,
          const Color(0xFF00E5FF).withValues(alpha: 0.35),
        ],
      ).createShader(Rect.fromCircle(center: Offset(originX, originY), radius: 240));

    canvas.drawArc(
      Rect.fromCenter(center: Offset(originX - 40, originY), width: 140, height: 420),
      math.pi * 0.5,
      math.pi,
      false,
      ringPaint,
    );

    final ringPaint2 = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.20);

    canvas.drawArc(
      Rect.fromCenter(center: Offset(originX - 120, originY), width: 220, height: 500),
      math.pi * 0.55,
      math.pi * 0.9,
      false,
      ringPaint2,
    );

    // 3. Orbe de glow central na fresta entre o card e o monitor
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF00E5FF).withValues(alpha: 0.25),
          const Color(0xFF0284C7).withValues(alpha: 0.12),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(originX, originY), radius: 180));

    canvas.drawCircle(Offset(originX, originY), 180, glowPaint);

    // 4. Partículas / pontos flutuantes de dados no ar
    final particlePaint = Paint()..color = const Color(0xFF00E5FF).withValues(alpha: 0.65);
    final points = [
      Offset(originX - 60, originY - 140),
      Offset(originX - 110, originY + 90),
      Offset(originX - 190, originY - 50),
      Offset(originX - 280, originY + 130),
      Offset(originX - 350, originY - 110),
      Offset(size.width * 0.22, originY + 70),
      Offset(size.width * 0.35, originY - 180),
    ];

    for (final pt in points) {
      canvas.drawCircle(pt, 2.0, particlePaint);
      final pGlow = Paint()
        ..color = const Color(0xFF00E5FF).withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(pt, 5.0, pGlow);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}



