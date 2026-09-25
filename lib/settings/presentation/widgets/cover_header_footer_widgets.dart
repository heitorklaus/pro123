import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/models/proposal_pages_models.dart';

/// Modelo de metadados para os estilos de Cabeçalho
class HeaderStyleMeta {
  final int id;
  final String name;
  final String description;
  final IconData icon;

  const HeaderStyleMeta({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
  });
}

/// Modelo de metadados para os estilos de Rodapé
class FooterStyleMeta {
  final int id;
  final String name;
  final String description;
  final IconData icon;

  const FooterStyleMeta({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
  });
}

/// Catálogo dos 10 estilos de Cabeçalho e 10 estilos de Rodapé
class CoverHeaderFooterCatalog {
  static const List<HeaderStyleMeta> headerStyles = [
    HeaderStyleMeta(
      id: 1,
      name: 'Modern Minimalist',
      description: 'Logo/Título à esquerda com linha divisória fina e data/código à direita.',
      icon: Icons.horizontal_rule_rounded,
    ),
    HeaderStyleMeta(
      id: 2,
      name: 'Faixa Executiva Escura',
      description: 'Barra escura elegante com logo, departamento e contatos em linha.',
      icon: Icons.view_headline_rounded,
    ),
    HeaderStyleMeta(
      id: 3,
      name: 'Gradiente Tecnológico',
      description: 'Destaque futurista com linha inferior em destaque e indicador.',
      icon: Icons.linear_scale_rounded,
    ),
    HeaderStyleMeta(
      id: 4,
      name: 'Corporate Clean',
      description: 'Razão social e subtítulo com badge arredondado de código do documento.',
      icon: Icons.badge_outlined,
    ),
    HeaderStyleMeta(
      id: 5,
      name: 'Dupla Linha com Tagline',
      description: 'Título e data no nível superior, linhas duplas e slogan corporativo.',
      icon: Icons.menu_open_rounded,
    ),
    HeaderStyleMeta(
      id: 6,
      name: 'Card Flutuante Glass',
      description: 'Card translúcido com efeito vidro escuro, borda suave e cantos redondos.',
      icon: Icons.filter_none_rounded,
    ),
    HeaderStyleMeta(
      id: 7,
      name: 'Bilateral com Validade',
      description: 'Identificação do projeto à esquerda e badge em destaque com prazo de validade.',
      icon: Icons.event_available_rounded,
    ),
    HeaderStyleMeta(
      id: 8,
      name: 'Cyber Grid Futurista',
      description: 'Marcadores angulares cibernéticos, status do projeto e carimbo técnico.',
      icon: Icons.grid_view_rounded,
    ),
    HeaderStyleMeta(
      id: 9,
      name: 'Compacto Discreto (Micro)',
      description: 'Linha única ultra slim com dados essenciais separados por marcadores sutis.',
      icon: Icons.reorder_rounded,
    ),
    HeaderStyleMeta(
      id: 10,
      name: 'Bold Accent Banner',
      description: 'Faixa sólida com a cor de destaque da empresa e tipografia de alto contraste.',
      icon: Icons.view_stream_rounded,
    ),
  ];

  static const List<FooterStyleMeta> footerStyles = [
    FooterStyleMeta(
      id: 1,
      name: 'Institucional Completo',
      description: 'Barra com slogan corporativo, telefone, e-mail, site e nota de validade.',
      icon: Icons.horizontal_split_rounded,
    ),
    FooterStyleMeta(
      id: 2,
      name: 'Slogan & Badges Centralizados',
      description: 'Slogan em destaque e chips de canais de atendimento centralizados.',
      icon: Icons.stars_rounded,
    ),
    FooterStyleMeta(
      id: 3,
      name: 'Faixa Legal Compacta',
      description: 'Barra formal discreta com aviso de confidencialidade e dados de registro.',
      icon: Icons.gavel_rounded,
    ),
    FooterStyleMeta(
      id: 4,
      name: 'Minimalista Paginação',
      description: 'Linha superior ultrafina com contatos à esquerda e numeração à direita.',
      icon: Icons.looks_one_outlined,
    ),
    FooterStyleMeta(
      id: 5,
      name: 'Duas Colunas Executivas',
      description: 'Dados da empresa na coluna esquerda e canais comerciais/web na direita.',
      icon: Icons.view_column_rounded,
    ),
    FooterStyleMeta(
      id: 6,
      name: 'Aviso Legal & Validade',
      description: 'Card discreto com termo de confidencialidade e garantia de preços.',
      icon: Icons.description_outlined,
    ),
    FooterStyleMeta(
      id: 7,
      name: 'Borda Superior Neon & Social',
      description: 'Linha neon superior com ícones de redes sociais e canais de contato.',
      icon: Icons.share_rounded,
    ),
    FooterStyleMeta(
      id: 8,
      name: 'Sustentabilidade & Futuro',
      description: 'Citação inspiradora de energia sustentável/tecnologia com ícone temático.',
      icon: Icons.eco_outlined,
    ),
    FooterStyleMeta(
      id: 9,
      name: 'Compact Contacts (Central)',
      description: 'Ícones em círculos escuros com telefone e site alinhados ao centro.',
      icon: Icons.phone_in_talk_outlined,
    ),
    FooterStyleMeta(
      id: 10,
      name: 'Autenticação & Hash Digital',
      description: 'Selo de segurança digital com código verificador e carimbo eletrônico.',
      icon: Icons.fingerprint_rounded,
    ),
  ];
}

/// Helper para conversão segura de cor Hexadecimal
Color? parseCoverColor(String? hexStr) {
  if (hexStr == null || hexStr.trim().isEmpty) return null;
  final clean = hexStr.replaceAll('#', '').trim();
  if (clean.length == 6) {
    final val = int.tryParse('FF$clean', radix: 16);
    return val != null ? Color(val) : null;
  }
  if (clean.length == 8) {
    final val = int.tryParse(clean, radix: 16);
    return val != null ? Color(val) : null;
  }
  return null;
}

/// Widget para Renderização do Cabeçalho no Canvas A4
class CoverHeaderWidget extends StatelessWidget {
  final int styleId;
  final String text1;
  final String text2;
  final String text3;
  final Color accentColor;
  final double scale;
  final Widget? logoWidget;
  final String? customBgColorHex;
  final String? customTextColorHex;
  final String? customIconColorHex;

  const CoverHeaderWidget({
    super.key,
    required this.styleId,
    required this.text1,
    required this.text2,
    required this.text3,
    required this.accentColor,
    required this.scale,
    this.logoWidget,
    this.customBgColorHex,
    this.customTextColorHex,
    this.customIconColorHex,
  });

  Color get _effectiveAccent => parseCoverColor(customIconColorHex) ?? accentColor;
  Color? get _customBg => parseCoverColor(customBgColorHex);
  Color? get _customText => parseCoverColor(customTextColorHex);
  bool _isDark(Color c) => c.computeLuminance() < 0.55;

  @override
  Widget build(BuildContext context) {
    if (styleId <= 0) return const SizedBox.shrink();

    switch (styleId) {
      case 1:
        return _buildModernMinimalist();
      case 2:
        return _buildDarkExecutiveBar();
      case 3:
        return _buildTechGradient();
      case 4:
        return _buildCorporateClean();
      case 5:
        return _buildDualLineTagline();
      case 6:
        return _buildGlassCard();
      case 7:
        return _buildBilateralValidity();
      case 8:
        return _buildCyberGrid();
      case 9:
        return _buildCompactMicro();
      case 10:
        return _buildBoldAccentBanner();
      default:
        return _buildModernMinimalist();
    }
  }

  // 1. Modern Minimalist
  Widget _buildModernMinimalist() {
    final bg = _customBg ?? Colors.white.withValues(alpha: 0.96);
    final isDark = _isDark(bg);
    final txt = _customText ?? (isDark ? Colors.white : const Color(0xFF0F172A));
    final subTxt = _customText?.withValues(alpha: 0.8) ?? (isDark ? Colors.white70 : const Color(0xFF475569));

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20 * scale, vertical: 12 * scale),
      decoration: BoxDecoration(
        color: bg,
        border: Border(bottom: BorderSide(color: _effectiveAccent, width: 2.5 * scale)),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (logoWidget != null) ...[logoWidget!, SizedBox(width: 8 * scale)],
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    text1,
                    style: GoogleFonts.outfit(
                      fontSize: 12 * scale,
                      fontWeight: FontWeight.w800,
                      color: txt,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (text2.isNotEmpty)
                    Text(
                      text2,
                      style: GoogleFonts.inter(
                        fontSize: 8.5 * scale,
                        fontWeight: FontWeight.w600,
                        color: subTxt,
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (text3.isNotEmpty)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 3 * scale),
              decoration: BoxDecoration(
                color: _customBg != null ? _effectiveAccent.withValues(alpha: 0.2) : const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(4 * scale),
                border: Border.all(color: _effectiveAccent.withValues(alpha: 0.4)),
              ),
              child: Text(
                text3,
                style: GoogleFonts.inter(
                  fontSize: 7.5 * scale,
                  fontWeight: FontWeight.bold,
                  color: _customText ?? (_customBg != null ? txt : Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 2. Faixa Executiva Escura
  Widget _buildDarkExecutiveBar() {
    final bg = _customBg ?? const Color(0xFF0F172A);
    final txt = _customText ?? Colors.white;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20 * scale, vertical: 10 * scale),
      decoration: BoxDecoration(
        color: bg,
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 3 * scale,
                height: 24 * scale,
                color: _effectiveAccent,
              ),
              SizedBox(width: 8 * scale),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    text1,
                    style: GoogleFonts.outfit(
                      fontSize: 11 * scale,
                      fontWeight: FontWeight.w900,
                      color: txt,
                      letterSpacing: 1.0,
                    ),
                  ),
                  if (text2.isNotEmpty)
                    Text(
                      text2,
                      style: GoogleFonts.inter(
                        fontSize: 8 * scale,
                        fontWeight: FontWeight.w600,
                        color: _effectiveAccent,
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (text3.isNotEmpty)
            Text(
              text3,
              style: GoogleFonts.inter(
                fontSize: 8 * scale,
                fontWeight: FontWeight.w500,
                color: _customText?.withValues(alpha: 0.8) ?? const Color(0xFF94A3B8),
              ),
            ),
        ],
      ),
    );
  }

  // 3. Gradiente Tecnológico
  Widget _buildTechGradient() {
    final bg = _customBg ?? const Color(0xFF0B1120);
    final txt = _customText ?? Colors.white;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20 * scale, vertical: 12 * scale),
      decoration: BoxDecoration(
        color: bg,
        border: Border(bottom: BorderSide(color: _effectiveAccent, width: 2.5 * scale)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.bolt_rounded, size: 16 * scale, color: _effectiveAccent),
              SizedBox(width: 6 * scale),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    text1,
                    style: GoogleFonts.outfit(
                      fontSize: 11.5 * scale,
                      fontWeight: FontWeight.w900,
                      color: txt,
                      letterSpacing: 1.2,
                    ),
                  ),
                  if (text2.isNotEmpty)
                    Text(
                      text2,
                      style: GoogleFonts.inter(
                        fontSize: 8 * scale,
                        fontWeight: FontWeight.bold,
                        color: _effectiveAccent,
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (text3.isNotEmpty)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 3 * scale),
              decoration: BoxDecoration(
                color: _effectiveAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4 * scale),
                border: Border.all(color: _effectiveAccent.withValues(alpha: 0.4)),
              ),
              child: Text(
                text3,
                style: GoogleFonts.inter(
                  fontSize: 7.5 * scale,
                  fontWeight: FontWeight.bold,
                  color: _customText ?? _effectiveAccent,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 4. Corporate Clean
  Widget _buildCorporateClean() {
    final bg = _customBg ?? Colors.white;
    final isDark = _customBg != null ? _isDark(bg) : false;
    final txt = _customText ?? (isDark ? Colors.white : const Color(0xFF0F172A));
    final subTxt = _customText?.withValues(alpha: 0.7) ?? (isDark ? Colors.white70 : const Color(0xFF64748B));

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20 * scale, vertical: 10 * scale),
      decoration: BoxDecoration(
        color: bg,
        border: Border(bottom: BorderSide(color: isDark ? _effectiveAccent : const Color(0xFFE2E8F0), width: 1.5 * scale)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                text1,
                style: GoogleFonts.outfit(
                  fontSize: 11 * scale,
                  fontWeight: FontWeight.w800,
                  color: txt,
                ),
              ),
              if (text2.isNotEmpty)
                Text(
                  text2,
                  style: GoogleFonts.inter(
                    fontSize: 8 * scale,
                    color: subTxt,
                  ),
                ),
            ],
          ),
          if (text3.isNotEmpty)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 4 * scale),
              decoration: BoxDecoration(
                color: isDark ? Colors.white12 : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(4 * scale),
                border: Border.all(color: isDark ? _effectiveAccent : const Color(0xFFCBD5E1)),
              ),
              child: Text(
                text3,
                style: GoogleFonts.inter(
                  fontSize: 7.5 * scale,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : txt,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 5. Dupla Linha com Tagline
  Widget _buildDualLineTagline() {
    final bg = _customBg ?? Colors.white.withValues(alpha: 0.95);
    final isDark = _customBg != null ? _isDark(bg) : false;
    final txt = _customText ?? (isDark ? Colors.white : const Color(0xFF0F172A));
    final subTxt = _customText?.withValues(alpha: 0.7) ?? (isDark ? Colors.white70 : const Color(0xFF64748B));

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20 * scale, vertical: 8 * scale),
      decoration: BoxDecoration(
        color: bg,
        border: Border(bottom: BorderSide(color: _effectiveAccent, width: 2 * scale)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            text1,
            style: GoogleFonts.outfit(fontSize: 11 * scale, fontWeight: FontWeight.w800, color: txt),
          ),
          if (text3.isNotEmpty)
            Text(
              text3,
              style: GoogleFonts.inter(fontSize: 8 * scale, fontWeight: FontWeight.bold, color: subTxt),
            ),
        ],
      ),
    );
  }

  // 6. Card Flutuante Glass
  Widget _buildGlassCard() {
    final bg = _customBg ?? const Color(0xFF0F172A).withValues(alpha: 0.90);
    final txt = _customText ?? Colors.white;

    return Container(
      margin: EdgeInsets.all(12 * scale),
      padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 10 * scale),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8 * scale),
        border: Border.all(color: _effectiveAccent.withValues(alpha: 0.3)),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, size: 15 * scale, color: _effectiveAccent),
              SizedBox(width: 8 * scale),
              Text(
                text1,
                style: GoogleFonts.outfit(fontSize: 10.5 * scale, fontWeight: FontWeight.bold, color: txt),
              ),
            ],
          ),
          if (text2.isNotEmpty)
            Text(
              text2,
              style: GoogleFonts.inter(fontSize: 8 * scale, fontWeight: FontWeight.w600, color: _effectiveAccent),
            ),
        ],
      ),
    );
  }

  // 7. Bilateral com Validade
  Widget _buildBilateralValidity() {
    final bg = _customBg ?? const Color(0xFF1E293B);
    final txt = _customText ?? Colors.white;
    final subTxt = _customText?.withValues(alpha: 0.75) ?? const Color(0xFF94A3B8);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20 * scale, vertical: 8 * scale),
      color: bg,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(text1, style: GoogleFonts.outfit(fontSize: 10.5 * scale, fontWeight: FontWeight.bold, color: txt)),
              if (text2.isNotEmpty)
                Text(text2, style: GoogleFonts.inter(fontSize: 7.5 * scale, color: subTxt)),
            ],
          ),
          if (text3.isNotEmpty)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 4 * scale),
              decoration: BoxDecoration(
                color: _effectiveAccent,
                borderRadius: BorderRadius.circular(4 * scale),
              ),
              child: Text(
                text3,
                style: GoogleFonts.inter(fontSize: 8 * scale, fontWeight: FontWeight.bold, color: Colors.black),
              ),
            ),
        ],
      ),
    );
  }

  // 8. Cyber Grid Futurista
  Widget _buildCyberGrid() {
    final bg = _customBg ?? const Color(0xFF030712);
    final txt = _customText ?? _effectiveAccent;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20 * scale, vertical: 8 * scale),
      decoration: BoxDecoration(
        color: bg,
        border: Border(bottom: BorderSide(color: _effectiveAccent, width: 2 * scale)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '[SYS] $text1',
            style: GoogleFonts.robotoMono(fontSize: 10.5 * scale, fontWeight: FontWeight.bold, color: txt),
          ),
          if (text3.isNotEmpty)
            Text(
              'AUTH: $text3',
              style: GoogleFonts.robotoMono(fontSize: 8 * scale, color: _customText ?? Colors.white70),
            ),
        ],
      ),
    );
  }

  // 9. Compacto Micro
  Widget _buildCompactMicro() {
    final bg = _customBg ?? const Color(0xFF0F172A);
    final isDark = _customBg != null ? _isDark(bg) : true;
    final txt = _customText ?? (isDark ? Colors.white : const Color(0xFF334155));
    final subTxt = _customText?.withValues(alpha: 0.8) ?? (isDark ? Colors.white70 : const Color(0xFF64748B));

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20 * scale, vertical: 6 * scale),
      color: bg,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(text1, style: GoogleFonts.inter(fontSize: 8 * scale, fontWeight: FontWeight.bold, color: txt)),
          if (text2.isNotEmpty)
            Text(text2, style: GoogleFonts.inter(fontSize: 8 * scale, color: subTxt)),
          if (text3.isNotEmpty)
            Text(text3, style: GoogleFonts.inter(fontSize: 8 * scale, fontWeight: FontWeight.bold, color: isDark ? Colors.white : _effectiveAccent)),
        ],
      ),
    );
  }

  // 10. Bold Accent Banner
  Widget _buildBoldAccentBanner() {
    final bg = _customBg ?? _effectiveAccent;
    final isDark = _isDark(bg);
    final txt = _customText ?? (isDark ? Colors.white : const Color(0xFF0F172A));

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20 * scale, vertical: 10 * scale),
      decoration: BoxDecoration(
        color: bg,
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                text1,
                style: GoogleFonts.outfit(
                  fontSize: 12 * scale,
                  fontWeight: FontWeight.w900,
                  color: txt,
                  letterSpacing: 0.5,
                ),
              ),
              if (text2.isNotEmpty)
                Text(
                  text2,
                  style: GoogleFonts.inter(fontSize: 8.5 * scale, fontWeight: FontWeight.bold, color: txt.withValues(alpha: 0.8)),
                ),
            ],
          ),
          if (text3.isNotEmpty)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 3 * scale),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(4 * scale),
              ),
              child: Text(
                text3,
                style: GoogleFonts.inter(fontSize: 8 * scale, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

/// Widget para Renderização do Rodapé no Canvas A4
class CoverFooterWidget extends StatelessWidget {
  final int styleId;
  final String text1;
  final String text2;
  final String text3;
  final String text4;
  final Color accentColor;
  final double scale;
  final String? customBgColorHex;
  final String? customTextColorHex;
  final String? customIconColorHex;

  const CoverFooterWidget({
    super.key,
    required this.styleId,
    required this.text1,
    required this.text2,
    required this.text3,
    required this.text4,
    required this.accentColor,
    required this.scale,
    this.customBgColorHex,
    this.customTextColorHex,
    this.customIconColorHex,
  });

  Color get _effectiveAccent => parseCoverColor(customIconColorHex) ?? accentColor;
  Color? get _customBg => parseCoverColor(customBgColorHex);
  Color? get _customText => parseCoverColor(customTextColorHex);
  bool _isDark(Color c) => c.computeLuminance() < 0.55;

  @override
  Widget build(BuildContext context) {
    if (styleId <= 0) return const SizedBox.shrink();

    switch (styleId) {
      case 1:
        return _buildInstitucionalCompleto();
      case 2:
        return _buildSloganBadges();
      case 3:
        return _buildFaixaLegal();
      case 4:
        return _buildMinimalistaPaginacao();
      case 5:
        return _buildDuasColunas();
      case 6:
        return _buildAvisoLegal();
      case 7:
        return _buildBordaNeonSocial();
      case 8:
        return _buildSustentabilidadeFuturo();
      case 9:
        return _buildCompactContacts();
      case 10:
        return _buildAutenticacaoHash();
      default:
        return _buildInstitucionalCompleto();
    }
  }

  // 1. Institucional Completo
  Widget _buildInstitucionalCompleto() {
    final bg = _customBg ?? const Color(0xFF0F172A);
    final txt = _customText ?? const Color(0xFFCBD5E1);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20 * scale, vertical: 10 * scale),
      decoration: BoxDecoration(
        color: bg,
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, -2))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (text1.isNotEmpty)
            Text(
              text1,
              style: GoogleFonts.outfit(
                fontSize: 9 * scale,
                fontWeight: FontWeight.w800,
                color: _effectiveAccent,
                letterSpacing: 0.8,
              ),
            ),
          if (text2.isNotEmpty || text3.isNotEmpty) ...[
            SizedBox(height: 3 * scale),
            Text(
              [text2, text3].where((s) => s.isNotEmpty).join('  •  '),
              style: GoogleFonts.inter(
                fontSize: 7.5 * scale,
                fontWeight: FontWeight.w500,
                color: txt,
              ),
            ),
          ],
          if (text4.isNotEmpty) ...[
            SizedBox(height: 2 * scale),
            Text(
              text4,
              style: GoogleFonts.inter(
                fontSize: 6.8 * scale,
                color: _customText?.withValues(alpha: 0.7) ?? const Color(0xFF94A3B8),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 2. Slogan & Badges
  Widget _buildSloganBadges() {
    final bg = _customBg ?? const Color(0xFF1E293B);
    final txt = _customText ?? const Color(0xFFCBD5E1);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20 * scale, vertical: 10 * scale),
      color: bg,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (text1.isNotEmpty)
            Text(
              text1,
              style: GoogleFonts.outfit(fontSize: 9.5 * scale, fontWeight: FontWeight.bold, color: _effectiveAccent),
            ),
          SizedBox(height: 4 * scale),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (text2.isNotEmpty)
                Text(text2, style: GoogleFonts.inter(fontSize: 7.5 * scale, color: txt)),
              if (text2.isNotEmpty && text3.isNotEmpty)
                Text('  |  ', style: TextStyle(color: _effectiveAccent, fontSize: 8 * scale)),
              if (text3.isNotEmpty)
                Text(text3, style: GoogleFonts.inter(fontSize: 7.5 * scale, color: txt)),
            ],
          ),
          if (text4.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 2 * scale),
              child: Text(text4, style: GoogleFonts.inter(fontSize: 6.5 * scale, color: _customText?.withValues(alpha: 0.6) ?? const Color(0xFF94A3B8))),
            ),
        ],
      ),
    );
  }

  // 3. Faixa Legal
  Widget _buildFaixaLegal() {
    final bg = _customBg ?? const Color(0xFF0B1120);
    final txt = _customText ?? const Color(0xFF94A3B8);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20 * scale, vertical: 8 * scale),
      color: bg,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              text1.isNotEmpty ? text1 : text2,
              style: GoogleFonts.inter(fontSize: 7.5 * scale, color: txt),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (text4.isNotEmpty)
            Text(
              text4,
              style: GoogleFonts.inter(fontSize: 7.5 * scale, fontWeight: FontWeight.bold, color: _effectiveAccent),
            ),
        ],
      ),
    );
  }

  // 4. Minimalista Paginação
  Widget _buildMinimalistaPaginacao() {
    final bg = _customBg ?? Colors.white.withValues(alpha: 0.95);
    final isDark = _customBg != null ? _isDark(bg) : false;
    final txt = _customText ?? (isDark ? Colors.white70 : const Color(0xFF64748B));

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20 * scale, vertical: 10 * scale),
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: isDark ? _effectiveAccent : const Color(0xFFE2E8F0), width: 1.5 * scale)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(text1.isNotEmpty ? text1 : text2, style: GoogleFonts.inter(fontSize: 8 * scale, color: txt)),
          if (text3.isNotEmpty)
            Text(text3, style: GoogleFonts.inter(fontSize: 8 * scale, fontWeight: FontWeight.bold, color: _effectiveAccent)),
        ],
      ),
    );
  }

  // 5. Duas Colunas
  Widget _buildDuasColunas() {
    final bg = _customBg ?? const Color(0xFF0F172A);
    final txt = _customText ?? Colors.white;
    final subTxt = _customText?.withValues(alpha: 0.75) ?? const Color(0xFF94A3B8);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20 * scale, vertical: 10 * scale),
      color: bg,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (text1.isNotEmpty)
                Text(text1, style: GoogleFonts.outfit(fontSize: 8.5 * scale, fontWeight: FontWeight.bold, color: txt)),
              if (text2.isNotEmpty)
                Text(text2, style: GoogleFonts.inter(fontSize: 7 * scale, color: subTxt)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (text3.isNotEmpty)
                Text(text3, style: GoogleFonts.inter(fontSize: 8 * scale, fontWeight: FontWeight.bold, color: _effectiveAccent)),
              if (text4.isNotEmpty)
                Text(text4, style: GoogleFonts.inter(fontSize: 7 * scale, color: subTxt)),
            ],
          ),
        ],
      ),
    );
  }

  // 6. Aviso Legal & Validade
  Widget _buildAvisoLegal() {
    final bg = _customBg ?? const Color(0xFFF8FAFC);
    final txt = _customText ?? const Color(0xFF0F172A);
    final subTxt = _customText?.withValues(alpha: 0.75) ?? const Color(0xFF475569);

    return Container(
      margin: EdgeInsets.all(12 * scale),
      padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 8 * scale),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6 * scale),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              text4.isNotEmpty ? text4 : text1,
              style: GoogleFonts.inter(fontSize: 7 * scale, color: subTxt),
              maxLines: 2,
            ),
          ),
          if (text2.isNotEmpty)
            Text(text2, style: GoogleFonts.inter(fontSize: 7.5 * scale, fontWeight: FontWeight.bold, color: txt)),
        ],
      ),
    );
  }

  // 7. Borda Superior Neon & Social
  Widget _buildBordaNeonSocial() {
    final bg = _customBg ?? const Color(0xFF0F172A);
    final txt = _customText ?? Colors.white;
    final subTxt = _customText?.withValues(alpha: 0.75) ?? const Color(0xFF94A3B8);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20 * scale, vertical: 10 * scale),
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: _effectiveAccent, width: 2.5 * scale)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (text1.isNotEmpty)
            Text(text1, style: GoogleFonts.outfit(fontSize: 8.5 * scale, fontWeight: FontWeight.bold, color: txt)),
          Text('$text2  ${text3.isNotEmpty ? "• $text3" : ""}', style: GoogleFonts.inter(fontSize: 7.5 * scale, color: subTxt)),
        ],
      ),
    );
  }

  // 8. Sustentabilidade & Futuro
  Widget _buildSustentabilidadeFuturo() {
    final bg = _customBg ?? const Color(0xFF064E3B);
    final txt = _customText ?? Colors.white;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20 * scale, vertical: 10 * scale),
      color: bg,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.eco_rounded, size: 14 * scale, color: _effectiveAccent),
              SizedBox(width: 6 * scale),
              Text(
                text1.isNotEmpty ? text1 : 'ENERGIA SUSTENTÁVEL PARA O FUTURO',
                style: GoogleFonts.outfit(fontSize: 8.5 * scale, fontWeight: FontWeight.bold, color: txt),
              ),
            ],
          ),
          if (text2.isNotEmpty || text3.isNotEmpty)
            Text(
              [text2, text3].where((s) => s.isNotEmpty).join(' • '),
              style: GoogleFonts.inter(fontSize: 7 * scale, color: _customText ?? const Color(0xFFA7F3D0)),
            ),
        ],
      ),
    );
  }

  // 9. Compact Contacts (Central)
  Widget _buildCompactContacts() {
    final bg = _customBg ?? const Color(0xFF0F172A);
    final txt = _customText ?? Colors.white;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20 * scale, vertical: 8 * scale),
      color: bg,
      child: Center(
        child: Text(
          [text1, text2, text3].where((s) => s.isNotEmpty).join('   •   '),
          style: GoogleFonts.inter(fontSize: 7.5 * scale, fontWeight: FontWeight.w600, color: txt),
        ),
      ),
    );
  }

  // 10. Autenticação & Hash Digital
  Widget _buildAutenticacaoHash() {
    final bg = _customBg ?? const Color(0xFF030712);
    final txt = _customText ?? const Color(0xFF94A3B8);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20 * scale, vertical: 8 * scale),
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: _effectiveAccent, width: 1.5 * scale)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.verified_user_outlined, size: 12 * scale, color: _effectiveAccent),
              SizedBox(width: 6 * scale),
              Text(
                'DOCUMENTO AUTENTICADO DIGITALMENTE',
                style: GoogleFonts.robotoMono(fontSize: 7.5 * scale, fontWeight: FontWeight.bold, color: _effectiveAccent),
              ),
            ],
          ),
          if (text4.isNotEmpty || text3.isNotEmpty)
            Text(
              text4.isNotEmpty ? text4 : text3,
              style: GoogleFonts.robotoMono(fontSize: 7 * scale, color: txt),
            ),
        ],
      ),
    );
  }
}

/// Widget que Renderiza a Página Interna de Demonstração (Canvas A4)
class CoverInternalPageDemo extends StatelessWidget {
  final double width;
  final double height;
  final double scale;
  final bool showHeader;
  final int headerStyleId;
  final String headerText1;
  final String headerText2;
  final String headerText3;
  final String headerBgColor;
  final String headerTextColor;
  final String headerIconColor;
  final bool showFooter;
  final int footerStyleId;
  final String footerText1;
  final String footerText2;
  final String footerText3;
  final String footerText4;
  final String footerBgColor;
  final String footerTextColor;
  final String footerIconColor;
  final Color accentColor;
  final String? bgImageUrl;
  final Uint8List? bgImageBytes;

  const CoverInternalPageDemo({
    super.key,
    required this.width,
    required this.height,
    required this.scale,
    required this.showHeader,
    required this.headerStyleId,
    required this.headerText1,
    required this.headerText2,
    required this.headerText3,
    required this.headerBgColor,
    required this.headerTextColor,
    required this.headerIconColor,
    required this.showFooter,
    required this.footerStyleId,
    required this.footerText1,
    required this.footerText2,
    required this.footerText3,
    required this.footerText4,
    required this.footerBgColor,
    required this.footerTextColor,
    required this.footerIconColor,
    required this.accentColor,
    this.bgImageUrl,
    this.bgImageBytes,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: Colors.white,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── FUNDO BRANCO LIMPO (APENAS A CAPA TEM IMAGEM DE FUNDO) ──
          // ── MARCA D'ÁGUA / ESTRUTURA DEMONSTRATIVA DE PÁGINA INTERNA ──
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24 * scale, vertical: 60 * scale),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badge Indicadora de Página Interna
                  Center(
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 14 * scale, vertical: 6 * scale),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20 * scale),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_stories_rounded, size: 14 * scale, color: const Color(0xFF64748B)),
                          SizedBox(width: 6 * scale),
                          Text(
                            'PÁGINA INTERNA DEMONSTRATIVA (PÁG 2 DE 8)',
                            style: GoogleFonts.inter(
                              fontSize: 8.5 * scale,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF475569),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 24 * scale),

                  // Título de Seção Interna
                  Row(
                    children: [
                      Container(
                        width: 4 * scale,
                        height: 20 * scale,
                        decoration: BoxDecoration(
                          color: accentColor,
                          borderRadius: BorderRadius.circular(2 * scale),
                        ),
                      ),
                      SizedBox(width: 8 * scale),
                      Text(
                        '1. ESPECIFICAÇÕES TÉCNICAS DO SISTEMA',
                        style: GoogleFonts.outfit(
                          fontSize: 14 * scale,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16 * scale),

                  // 3 Cards Simulados de Métricas
                  Row(
                    children: [
                      Expanded(child: _buildMetricPlaceholder('Potência Estimada', '8.61 kWp', Icons.bolt_rounded)),
                      SizedBox(width: 10 * scale),
                      Expanded(child: _buildMetricPlaceholder('Geração Mensal', '1.150 kWh/mês', Icons.solar_power_rounded)),
                      SizedBox(width: 10 * scale),
                      Expanded(child: _buildMetricPlaceholder('Economia Anual', 'R\$ 14.850,00', Icons.savings_outlined)),
                    ],
                  ),
                  SizedBox(height: 20 * scale),

                  // Tabela Simulada
                  Container(
                    padding: EdgeInsets.all(12 * scale),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8 * scale),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        _buildTableRow('Módulos Fotovoltaicos Tier-1', '14x 615W N-Type Bifacial', true),
                        Divider(height: 12 * scale, color: const Color(0xFFE2E8F0)),
                        _buildTableRow('Inversor String On-Grid', '1x 8.0 kW 220V MPPT Duplo', false),
                        Divider(height: 12 * scale, color: const Color(0xFFE2E8F0)),
                        _buildTableRow('Estrutura de Fixação Alumínio', 'Telhado Cerâmico c/ Grampos Inox', false),
                        Divider(height: 12 * scale, color: const Color(0xFFE2E8F0)),
                        _buildTableRow('String Box CC/CA & DPS', 'Proteção Integrada Classe II', false),
                      ],
                    ),
                  ),
                  SizedBox(height: 18 * scale),

                  // Gráfico Simulado Wireframe
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.all(14 * scale),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9).withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8 * scale),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PROJEÇÃO DE GERAÇÃO ENERGÉTICA E RETORNO (MÊS A MÊS)',
                            style: GoogleFonts.inter(
                              fontSize: 9 * scale,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          SizedBox(height: 10 * scale),
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                for (double h in [0.45, 0.60, 0.75, 0.85, 0.90, 0.70, 0.80, 0.95, 0.88, 0.72, 0.65, 0.55])
                                  Container(
                                    width: 14 * scale,
                                    height: 120 * scale * h,
                                    decoration: BoxDecoration(
                                      color: accentColor.withValues(alpha: 0.8),
                                      borderRadius: BorderRadius.circular(3 * scale),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── CABEÇALHO NO TOPO (PÁGINA INTERNA) ──
          if (showHeader)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: CoverHeaderWidget(
                styleId: headerStyleId,
                text1: headerText1,
                text2: headerText2,
                text3: headerText3,
                accentColor: accentColor,
                scale: scale,
                customBgColorHex: headerBgColor,
                customTextColorHex: headerTextColor,
                customIconColorHex: headerIconColor,
              ),
            ),

          // ── RODAPÉ NA BASE (PÁGINA INTERNA) ──
          if (showFooter)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: CoverFooterWidget(
                styleId: footerStyleId,
                text1: footerText1,
                text2: footerText2,
                text3: footerText3,
                text4: footerText4,
                accentColor: accentColor,
                scale: scale,
                customBgColorHex: footerBgColor,
                customTextColorHex: footerTextColor,
                customIconColorHex: footerIconColor,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMetricPlaceholder(String title, String value, IconData icon) {
    return Container(
      padding: EdgeInsets.all(10 * scale),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8 * scale),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13 * scale, color: accentColor),
              SizedBox(width: 4 * scale),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(fontSize: 7.5 * scale, color: const Color(0xFF64748B)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 4 * scale),
          Text(
            value,
            style: GoogleFonts.outfit(fontSize: 11 * scale, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
          ),
        ],
      ),
    );
  }

  Widget _buildTableRow(String label, String value, bool isHighlight) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          flex: 5,
          child: Text(
            label,
            style: GoogleFonts.inter(fontSize: 8.5 * scale, color: const Color(0xFF475569)),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(width: 6 * scale),
        Flexible(
          flex: 4,
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: GoogleFonts.inter(fontSize: 8.5 * scale, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Seletor de Cores com Presets Rápidos e Campo Hexadecimal
class CoverColorPickerTile extends StatelessWidget {
  final String label;
  final String currentColorHex;
  final ValueChanged<String> onColorSelected;
  final String defaultHint;

  const CoverColorPickerTile({
    super.key,
    required this.label,
    required this.currentColorHex,
    required this.onColorSelected,
    this.defaultHint = 'Padrão do Estilo',
  });

  static const List<Map<String, String>> presets = [
    {'name': 'Padrão', 'hex': ''},
    {'name': 'Azul Royal', 'hex': '#2563EB'},
    {'name': 'Azul Corporativo', 'hex': '#0284C7'},
    {'name': 'Azul Noturno', 'hex': '#1E3A8A'},
    {'name': 'Navy Blue', 'hex': '#0B1120'},
    {'name': 'Ciano Tech', 'hex': '#38BDF8'},
    {'name': 'Índigo Modern', 'hex': '#6366F1'},
    {'name': 'Dark Slate', 'hex': '#0F172A'},
    {'name': 'Cyber Black', 'hex': '#030712'},
    {'name': 'Branco Puro', 'hex': '#FFFFFF'},
    {'name': 'Cinza Platina', 'hex': '#F1F5F9'},
    {'name': 'Dourado Solar', 'hex': '#EAB308'},
    {'name': 'Esmeralda', 'hex': '#10B981'},
    {'name': 'Laranja Bold', 'hex': '#F97316'},
    {'name': 'Rose Red', 'hex': '#EF4444'},
  ];

  @override
  Widget build(BuildContext context) {
    final parsed = parseCoverColor(currentColorHex);
    final isCustom = currentColorHex.trim().isNotEmpty && parsed != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: isCustom ? parsed : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white30, width: 1.5),
                ),
                child: !isCustom
                    ? const Icon(Icons.palette_outlined, size: 14, color: Colors.white70)
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              if (isCustom)
                InkWell(
                  onTap: () => onColorSelected(''),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF334155),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Restaurar Padrão',
                      style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8)),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Presets de Cores
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: presets.map((p) {
                final hex = p['hex']!;
                final isSelected = currentColorHex.toUpperCase() == hex.toUpperCase();
                final pColor = parseCoverColor(hex);

                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Tooltip(
                    message: p['name']!,
                    child: InkWell(
                      onTap: () => onColorSelected(hex),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: pColor ?? Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? Colors.white : Colors.white24,
                            width: isSelected ? 2.5 : 1.2,
                          ),
                          boxShadow: isSelected
                              ? [BoxShadow(color: (pColor ?? Colors.white).withValues(alpha: 0.4), blurRadius: 6)]
                              : null,
                        ),
                        child: hex.isEmpty
                            ? const Icon(Icons.block, size: 14, color: Colors.white54)
                            : null,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Hex:',
                style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 90,
                height: 28,
                child: TextField(
                  controller: TextEditingController(text: currentColorHex)
                    ..selection = TextSelection.collapsed(offset: currentColorHex.length),
                  onSubmitted: (val) {
                    final clean = val.trim();
                    if (clean.isEmpty) {
                      onColorSelected('');
                    } else {
                      final withHash = clean.startsWith('#') ? clean : '#$clean';
                      onColorSelected(withHash);
                    }
                  },
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 11),
                  decoration: InputDecoration(
                    hintText: '#000000',
                    hintStyle: GoogleFonts.inter(color: Colors.white30, fontSize: 10),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Color(0xFF334155))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Color(0xFF334155))),
                  ),
                ),
              ),
              if (isCustom) ...[
                const SizedBox(width: 8),
                Text(
                  currentColorHex.toUpperCase(),
                  style: GoogleFonts.inter(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.bold),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Conteúdo completo da Aba "Cabeçalho & Rodapé"
class CoverHeaderFooterTabContent extends StatelessWidget {
  final bool showHeader;
  final ValueChanged<bool> onToggleHeader;
  final int headerStyle;
  final ValueChanged<int> onSelectHeaderStyle;
  final TextEditingController headerText1Ctrl;
  final TextEditingController headerText2Ctrl;
  final TextEditingController headerText3Ctrl;

  // Cores do Cabeçalho
  final String headerBgColor;
  final ValueChanged<String> onHeaderBgColorChanged;
  final String headerTextColor;
  final ValueChanged<String> onHeaderTextColorChanged;
  final String headerIconColor;
  final ValueChanged<String> onHeaderIconColorChanged;

  final bool showFooter;
  final ValueChanged<bool> onToggleFooter;
  final int footerStyle;
  final ValueChanged<int> onSelectFooterStyle;
  final TextEditingController footerText1Ctrl;
  final TextEditingController footerText2Ctrl;
  final TextEditingController footerText3Ctrl;
  final TextEditingController footerText4Ctrl;

  // Cores do Rodapé
  final String footerBgColor;
  final ValueChanged<String> onFooterBgColorChanged;
  final String footerTextColor;
  final ValueChanged<String> onFooterTextColorChanged;
  final String footerIconColor;
  final ValueChanged<String> onFooterIconColorChanged;

  final Color accentColor;
  final String? selectedInternalPresetId;
  final ValueChanged<InternalPagesLayoutPreset>? onSelectInternalPreset;

  const CoverHeaderFooterTabContent({
    super.key,
    required this.showHeader,
    required this.onToggleHeader,
    required this.headerStyle,
    required this.onSelectHeaderStyle,
    required this.headerText1Ctrl,
    required this.headerText2Ctrl,
    required this.headerText3Ctrl,
    required this.headerBgColor,
    required this.onHeaderBgColorChanged,
    required this.headerTextColor,
    required this.onHeaderTextColorChanged,
    required this.headerIconColor,
    required this.onHeaderIconColorChanged,
    required this.showFooter,
    required this.onToggleFooter,
    required this.footerStyle,
    required this.onSelectFooterStyle,
    required this.footerText1Ctrl,
    required this.footerText2Ctrl,
    required this.footerText3Ctrl,
    required this.footerText4Ctrl,
    required this.footerBgColor,
    required this.onFooterBgColorChanged,
    required this.footerTextColor,
    required this.onFooterTextColorChanged,
    required this.footerIconColor,
    required this.onFooterIconColorChanged,
    this.accentColor = const Color(0xFFEAB308),
    this.selectedInternalPresetId,
    this.onSelectInternalPreset,
  });

  @override
  Widget build(BuildContext context) {
    final presets = InternalPagesLayoutPreset.getAllPresets();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Informativo: Cabeçalho & Rodapé apenas nas páginas internas
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: accentColor.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: accentColor, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'O cabeçalho e rodapé são aplicados exclusivamente nas páginas internas da proposta (a capa permanece limpa com sua foto e título). A prévia à esquerda simula uma página interna.',
                    style: GoogleFonts.inter(fontSize: 11.5, color: Colors.white70, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── SEÇÃO 0: 20 PADRÕES PRONTOS DE DESIGN (1 CLIQUE) ──
          if (onSelectInternalPreset != null) ...[
            _buildSectionHeader(
              '20 Padrões Prontos de Design (1 Clique)',
              'Aplique combinações perfeitas de cabeçalho, rodapé e paleta de cores para todas as páginas internas',
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 2.3,
                    ),
                    itemCount: presets.length,
                    itemBuilder: (ctx, idx) {
                      final p = presets[idx];
                      final isSelected = selectedInternalPresetId == p.id;
                      final colorVal = Color(int.tryParse(p.primaryColorHex.replaceAll('#', '0xFF')) ?? 0xFF0284C7);

                      return InkWell(
                        onTap: () => onSelectInternalPreset?.call(p),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF1E293B) : const Color(0xFF1E293B).withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? colorVal : const Color(0xFF334155),
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: colorVal.withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    )
                                  ]
                                : null,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: colorVal,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      p.title,
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isSelected)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: colorVal,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text('ATIVO', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white)),
                                    ),
                                ],
                              ),
                              Text(
                                p.subtitle,
                                style: GoogleFonts.inter(fontSize: 9.5, color: const Color(0xFF94A3B8)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Topo: Estilo ${p.headerStyle} • Base: Estilo ${p.footerStyle}',
                                    style: GoogleFonts.inter(fontSize: 8.5, color: const Color(0xFF64748B)),
                                  ),
                                  Text(
                                    isSelected ? 'APLICADO' : 'APLICAR ->',
                                    style: GoogleFonts.inter(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? colorVal : const Color(0xFF94A3B8),
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
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // ── SEÇÃO 1: CABEÇALHO DA PROPOSTA ──
          _buildSectionHeader(
            'Cabeçalho das Páginas Internas (10 Modelos)',
            'Escolha o layout superior e personalize textos e cores em tempo real',
          ),
          const SizedBox(height: 12),

          // Switch Ativar Cabeçalho
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Row(
              children: [
                Switch.adaptive(
                  value: showHeader,
                  activeTrackColor: accentColor,
                  onChanged: onToggleHeader,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Exibir cabeçalho nas páginas internas',
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

          if (showHeader) ...[
            const SizedBox(height: 16),
            Text(
              'SELECIONE O ESTILO VISUAL DO CABEÇALHO',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF94A3B8), letterSpacing: 0.8),
            ),
            const SizedBox(height: 10),

            // Grade Responsiva dos 10 Modelos de Cabeçalho (Zero RenderFlex Overflow)
            LayoutBuilder(
              builder: (ctx, constraints) {
                final availableW = constraints.maxWidth;
                final isTwoCols = availableW >= 360;
                final cardW = isTwoCols ? (availableW - 10) / 2 : availableW;

                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: CoverHeaderFooterCatalog.headerStyles.map((item) {
                    final isSelected = headerStyle == item.id;

                    return SizedBox(
                      width: cardW,
                      child: InkWell(
                        onTap: () => onSelectHeaderStyle(item.id),
                        borderRadius: BorderRadius.circular(10),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? accentColor : const Color(0xFF334155),
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: isSelected
                                ? [BoxShadow(color: accentColor.withValues(alpha: 0.25), blurRadius: 6, offset: const Offset(0, 2))]
                                : null,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Icon(item.icon, size: 16, color: isSelected ? accentColor : Colors.white70),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '#${item.id}. ${item.name}',
                                      style: GoogleFonts.inter(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected ? Colors.white : Colors.white70,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.description,
                                style: GoogleFonts.inter(fontSize: 9.5, color: const Color(0xFF94A3B8), height: 1.25),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 18),

            // Campos de Texto Editáveis do Cabeçalho
            Text(
              'TEXTOS DO CABEÇALHO',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF94A3B8), letterSpacing: 0.8),
            ),
            const SizedBox(height: 10),
            _buildField('Título Principal (Linha 1)', headerText1Ctrl, 'ex: PROPOSTA COMERCIAL'),
            const SizedBox(height: 10),
            _buildField('Subtítulo / Departamento (Linha 2)', headerText2Ctrl, 'ex: ENERGIA SOLAR FOTOVOLTAICA'),
            const SizedBox(height: 10),
            _buildField('Data / Validade / Código (Linha 3)', headerText3Ctrl, 'ex: SOLUÇÕES DE ALTA PERFORMANCE'),

            const SizedBox(height: 18),
            // Cores do Cabeçalho
            Text(
              'CORES DO CABEÇALHO',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF94A3B8), letterSpacing: 0.8),
            ),
            const SizedBox(height: 10),
            CoverColorPickerTile(
              label: 'Cor do Fundo do Cabeçalho',
              currentColorHex: headerBgColor,
              onColorSelected: onHeaderBgColorChanged,
            ),
            CoverColorPickerTile(
              label: 'Cor dos Textos do Cabeçalho',
              currentColorHex: headerTextColor,
              onColorSelected: onHeaderTextColorChanged,
            ),
            CoverColorPickerTile(
              label: 'Cor dos Ícones / Linha de Destaque',
              currentColorHex: headerIconColor,
              onColorSelected: onHeaderIconColorChanged,
            ),
          ],

          const SizedBox(height: 28),
          const Divider(color: Color(0xFF334155)),
          const SizedBox(height: 20),

          // ── SEÇÃO 2: RODAPÉ DA PROPOSTA ──
          _buildSectionHeader(
            'Rodapé das Páginas Internas (10 Modelos)',
            'Escolha o layout inferior e personalize contatos, slogan e cores',
          ),
          const SizedBox(height: 12),

          // Switch Ativar Rodapé
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Row(
              children: [
                Switch.adaptive(
                  value: showFooter,
                  activeTrackColor: accentColor,
                  onChanged: onToggleFooter,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Exibir rodapé nas páginas internas',
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

          if (showFooter) ...[
            const SizedBox(height: 16),
            Text(
              'SELECIONE O ESTILO VISUAL DO RODAPÉ',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF94A3B8), letterSpacing: 0.8),
            ),
            const SizedBox(height: 10),

            // Grade Responsiva dos 10 Modelos de Rodapé (Zero RenderFlex Overflow)
            LayoutBuilder(
              builder: (ctx, constraints) {
                final availableW = constraints.maxWidth;
                final isTwoCols = availableW >= 360;
                final cardW = isTwoCols ? (availableW - 10) / 2 : availableW;

                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: CoverHeaderFooterCatalog.footerStyles.map((item) {
                    final isSelected = footerStyle == item.id;

                    return SizedBox(
                      width: cardW,
                      child: InkWell(
                        onTap: () => onSelectFooterStyle(item.id),
                        borderRadius: BorderRadius.circular(10),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? accentColor : const Color(0xFF334155),
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: isSelected
                                ? [BoxShadow(color: accentColor.withValues(alpha: 0.25), blurRadius: 6, offset: const Offset(0, 2))]
                                : null,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Icon(item.icon, size: 16, color: isSelected ? accentColor : Colors.white70),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '#${item.id}. ${item.name}',
                                      style: GoogleFonts.inter(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected ? Colors.white : Colors.white70,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.description,
                                style: GoogleFonts.inter(fontSize: 9.5, color: const Color(0xFF94A3B8), height: 1.25),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 18),

            // Campos de Texto Editáveis do Rodapé
            Text(
              'TEXTOS DO RODAPÉ',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF94A3B8), letterSpacing: 0.8),
            ),
            const SizedBox(height: 10),
            _buildField('Slogan / Frase Principal (Linha 1)', footerText1Ctrl, 'ex: ENERGIA LIMPA • ECONOMIA REAL'),
            const SizedBox(height: 10),
            _buildField('Telefone / WhatsApp / Endereço (Linha 2)', footerText2Ctrl, 'ex: (11) 99999-9999 • contato@empresa.com.br'),
            const SizedBox(height: 10),
            _buildField('E-mail / Website Oficial (Linha 3)', footerText3Ctrl, 'ex: www.suaempresa.com.br'),
            const SizedBox(height: 10),
            _buildField('Aviso Legal / Validade (Linha 4)', footerText4Ctrl, 'ex: Proposta válida por 10 dias corridos.'),

            const SizedBox(height: 18),
            // Cores do Rodapé
            Text(
              'CORES DO RODAPÉ',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF94A3B8), letterSpacing: 0.8),
            ),
            const SizedBox(height: 10),
            CoverColorPickerTile(
              label: 'Cor do Fundo do Rodapé',
              currentColorHex: footerBgColor,
              onColorSelected: onFooterBgColorChanged,
            ),
            CoverColorPickerTile(
              label: 'Cor dos Textos do Rodapé',
              currentColorHex: footerTextColor,
              onColorSelected: onFooterTextColorChanged,
            ),
            CoverColorPickerTile(
              label: 'Cor dos Ícones / Linha de Destaque',
              currentColorHex: footerIconColor,
              onColorSelected: onFooterIconColorChanged,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF94A3B8)),
        ),
      ],
    );
  }

  Widget _buildField(String label, TextEditingController controller, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFCBD5E1)),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 12),
            filled: true,
            fillColor: const Color(0xFF0F172A),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF334155))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF334155))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: accentColor)),
          ),
        ),
      ],
    );
  }
}

