import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/models/solar_settings_model.dart';
import '../../data/services/solar_settings_service.dart';

/// Helper de ícones para os badges e ícones customizáveis da capa
IconData getCoverBadgeIcon(String key) {
  switch (key.toLowerCase()) {
    case 'bolt':
    case 'energia':
    case 'raio':
      return Icons.bolt_rounded;
    case 'chart':
    case 'grafico':
    case 'valorizacao':
      return Icons.bar_chart_rounded;
    case 'coins':
    case 'moedas':
    case 'dinheiro':
      return Icons.monetization_on_outlined;
    case 'sun':
    case 'sol':
    case 'solar_power':
    case 'painel':
      return Icons.solar_power_rounded;
    case 'shield':
    case 'seguranca':
    case 'garantia':
      return Icons.shield_outlined;
    case 'verified':
    case 'check':
    case 'qualidade':
      return Icons.verified_rounded;
    case 'star':
    case 'estrela':
    case 'favorito':
      return Icons.star_rounded;
    case 'home':
    case 'casa':
    case 'residencia':
      return Icons.home_outlined;
    case 'phone':
    case 'telefone':
    case 'whatsapp':
    case 'contato':
      return Icons.phone_rounded;
    case 'location':
    case 'localizacao':
    case 'endereco':
    case 'map':
      return Icons.location_on_rounded;
    case 'mail':
    case 'email':
      return Icons.mail_outline_rounded;
    case 'lightbulb':
    case 'lampada':
    case 'ideia':
      return Icons.lightbulb_outline_rounded;
    case 'handshake':
    case 'parceria':
      return Icons.handshake_outlined;
    case 'award':
    case 'trofeu':
    case 'premio':
      return Icons.emoji_events_outlined;
    case 'engineering':
    case 'engenharia':
      return Icons.engineering_rounded;
    case 'leaf':
    case 'eco':
    case 'sustentabilidade':
    default:
      return Icons.eco_outlined;
  }
}

/// Clipper do lado esquerdo (Foto) para o Estilo Vertical Split
class SolarVerticalSplitPhotoClipper extends CustomClipper<Path> {
  final int dividerType; // 0 = Diagonal, 1 = Raio de Energia, 2 = Sol Radiante

  const SolarVerticalSplitPhotoClipper({this.dividerType = 0});

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path();

    path.moveTo(0, 0);

    switch (dividerType) {
      case 1:
        // ── Tipo 1: Raio de Energia (Zig-zag / Lightning) ─────────────
        path.lineTo(w * 0.68, 0);
        path.lineTo(w * 0.48, h * 0.32);
        path.lineTo(w * 0.65, h * 0.32); // ponta saliente para a direita
        path.lineTo(w * 0.42, h * 0.65);
        path.lineTo(w * 0.54, h * 0.65); // segunda ponta saliente
        path.lineTo(w * 0.35, h);
        path.lineTo(0, h);
        break;

      case 2:
        // ── Tipo 2: Sol Radiante (Sunburst Arc) ────────────────────────
        path.lineTo(w * 0.35, 0);
        path.lineTo(w * 0.43, h * 0.22);
        // Arco semicircular avançando na área branca
        final arcRect = Rect.fromCircle(center: Offset(w * 0.35, h * 0.48), radius: w * 0.36);
        path.arcTo(arcRect, -math.pi / 2.5, math.pi * 0.82, false);
        path.lineTo(w * 0.60, h);
        path.lineTo(0, h);
        break;

      case 0:
      default:
        // ── Tipo 0: Corte Diagonal Reto ────────────────────────────────
        path.lineTo(w * 0.66, 0);
        path.lineTo(w * 0.35, h);
        path.lineTo(0, h);
        break;
    }

    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant SolarVerticalSplitPhotoClipper oldClipper) =>
      oldClipper.dividerType != dividerType;
}

/// Painter da divisória decorativa (Borda Dourada / Watermark Sol)
class SolarVerticalSplitPainter extends CustomPainter {
  final int dividerType;
  final Color accentColor;

  const SolarVerticalSplitPainter({
    required this.dividerType,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Watermark sutil do Sol no canto inferior direito — EXCLUSIVO do Tipo 2 (Sol Radiante)
    if (dividerType == 2) {
      final watermarkPaint = Paint()
        ..color = const Color(0xFFF1F5F9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 24.0
        ..strokeCap = StrokeCap.round;

      final sunCenter = Offset(w * 0.98, h * 0.88);
      final sunRadius = w * 0.42;
      canvas.drawCircle(sunCenter, sunRadius, watermarkPaint);

      // Raios do watermark do Sol
      final rayPaint = Paint()
        ..color = const Color(0xFFF1F5F9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14.0
        ..strokeCap = StrokeCap.round;

      for (int i = 0; i < 7; i++) {
        final angle = math.pi + (i * (math.pi / 7));
        final p1 = Offset(
          sunCenter.dx + (sunRadius + 18) * math.cos(angle),
          sunCenter.dy + (sunRadius + 18) * math.sin(angle),
        );
        final p2 = Offset(
          sunCenter.dx + (sunRadius + 44) * math.cos(angle),
          sunCenter.dy + (sunRadius + 44) * math.sin(angle),
        );
        canvas.drawLine(p1, p2, rayPaint);
      }
    }

    // 2. Traçado da Borda Dourada / Amarela do Divisor
    final borderPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final borderPath = Path();

    switch (dividerType) {
      case 1:
        // Linha zig-zag do raio
        borderPath.moveTo(w * 0.68, 0);
        borderPath.lineTo(w * 0.48, h * 0.32);
        borderPath.lineTo(w * 0.65, h * 0.32);
        borderPath.lineTo(w * 0.42, h * 0.65);
        borderPath.lineTo(w * 0.54, h * 0.65);
        borderPath.lineTo(w * 0.35, h);
        canvas.drawPath(borderPath, borderPaint);
        break;

      case 2:
        // Arco do Sol Radiante
        borderPath.moveTo(w * 0.35, 0);
        borderPath.lineTo(w * 0.43, h * 0.22);
        final arcRect = Rect.fromCircle(center: Offset(w * 0.35, h * 0.48), radius: w * 0.36);
        borderPath.arcTo(arcRect, -math.pi / 2.5, math.pi * 0.82, false);
        borderPath.lineTo(w * 0.60, h);
        canvas.drawPath(borderPath, borderPaint);

        // Raios da auréola do sol (pills estilizados)
        final rayOutlinePaint = Paint()
          ..color = accentColor.withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;

        for (int i = 0; i < 5; i++) {
          final rayAngle = -math.pi / 3.2 + (i * (math.pi / 7.2));
          final r1 = Offset(
            w * 0.35 + (w * 0.40) * math.cos(rayAngle),
            h * 0.48 + (w * 0.40) * math.sin(rayAngle),
          );
          final r2 = Offset(
            w * 0.35 + (w * 0.55) * math.cos(rayAngle),
            h * 0.48 + (w * 0.55) * math.sin(rayAngle),
          );
          canvas.drawLine(r1, r2, rayOutlinePaint);
        }
        break;

      case 0:
      default:
        // Linha diagonal reta
        borderPath.moveTo(w * 0.66, 0);
        borderPath.lineTo(w * 0.35, h);
        canvas.drawPath(borderPath, borderPaint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant SolarVerticalSplitPainter oldDelegate) =>
      oldDelegate.dividerType != dividerType || oldDelegate.accentColor != accentColor;
}

/// Helper para obter o TextStyle dinâmico com a fonte do Google Fonts selecionada pelo usuário
TextStyle getCoverTextStyle({
  required String fontFamily,
  required double fontSize,
  FontWeight fontWeight = FontWeight.normal,
  Color color = Colors.white,
  double? letterSpacing,
  double? height,
  List<Shadow>? shadows,
}) {
  switch (fontFamily.toLowerCase()) {
    case 'roboto':
      return GoogleFonts.roboto(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
        shadows: shadows,
      );
    case 'inter':
      return GoogleFonts.inter(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
        shadows: shadows,
      );
    case 'outfit':
      return GoogleFonts.outfit(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
        shadows: shadows,
      );
    case 'oswald':
      return GoogleFonts.oswald(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
        shadows: shadows,
      );
    case 'poppins':
      return GoogleFonts.poppins(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
        shadows: shadows,
      );
    case 'playfair display':
    case 'playfair':
      return GoogleFonts.playfairDisplay(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
        shadows: shadows,
      );
    case 'montserrat':
    default:
      return GoogleFonts.montserrat(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
        shadows: shadows,
      );
  }
}

/// Widget completo da Capa com Estilo Vertical Split (Live Preview & Proporcional A4)
class SolarVerticalSplitCoverView extends StatelessWidget {
  final SolarSettingsModel settings;
  final String? customWebBgUrl;
  final double width;
  final double height;
  final String? clientName;
  final String? proposalNumber;
  final String? kwp;

  // Dimensões Canônicas da Folha A4 Padrão (595.28 x 841.89)
  static const double baseA4Width = 595.28;
  static const double baseA4Height = 841.89;

  const SolarVerticalSplitCoverView({
    super.key,
    required this.settings,
    this.customWebBgUrl,
    required this.width,
    required this.height,
    this.clientName,
    this.proposalNumber,
    this.kwp,
  });

  @override
  Widget build(BuildContext context) {
    final bgUrl = customWebBgUrl ??
        (settings.webBackgroundTemplate.isNotEmpty
            ? SolarSettingsService.getWebBackgroundUrl(settings.webBackgroundTemplate)
            : SolarSettingsService.getWebBackgroundUrl('AdobeStock_1030854734.jpg'));

    final accentColor = Color(settings.verticalSplitAccentColorValue);
    final divType = settings.verticalSplitDividerType;
    final badges = settings.verticalSplitFooterBadges;

    final double effectiveRightBlockTop = settings.verticalSplitRightBlockTop * baseA4Height;
    final double effectiveRightBlockRight = settings.verticalSplitRightBlockRight * baseA4Width;
    final double effectiveHeadlineTop = settings.verticalSplitHeadlineTop * baseA4Height;
    final double effectiveHeadlineLeft = settings.verticalSplitHeadlineLeft * baseA4Width;
    final double effectiveLeftFooterBottom = settings.verticalSplitLeftFooterBottom * baseA4Height;
    final double effectiveLeftFooterLeft = settings.verticalSplitLeftFooterLeft * baseA4Width;
    final double effectiveRightFooterBottom = settings.verticalSplitRightFooterBottom * baseA4Height;
    final double effectiveRightFooterRight = settings.verticalSplitRightFooterRight * baseA4Width;

    return SizedBox(
      width: width,
      height: height,
      child: FittedBox(
        fit: BoxFit.contain,
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        child: Container(
          width: baseA4Width,
          height: baseA4Height,
          color: Colors.white,
          child: Stack(
            clipBehavior: Clip.none,
            fit: StackFit.expand,
            children: [
              // ── 1. Foto Solar Recortada à Esquerda ────────────────────────────
              ClipPath(
                clipper: SolarVerticalSplitPhotoClipper(dividerType: divType),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      bgUrl,
                      fit: BoxFit.cover,
                      width: baseA4Width,
                      height: baseA4Height,
                      loadingBuilder: (ctx, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          color: const Color(0xFF0F172A),
                          child: const Center(
                            child: CircularProgressIndicator(color: Color(0xFFEAB308), strokeWidth: 3),
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFF0F172A),
                        child: const Center(
                          child: Icon(Icons.solar_power_rounded, color: Colors.white38, size: 64),
                        ),
                      ),
                    ),

                    // Gradiente escuro para legibilidade perfeita dos textos brancos
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.65),
                            Colors.black.withValues(alpha: 0.20),
                            Colors.black.withValues(alpha: 0.75),
                          ],
                        ),
                      ),
                    ),

                    // ── 2. Headline & Subheadline do Lado Esquerdo (Foto) ─────────
                    if (settings.verticalSplitShowHeadline)
                      Positioned(
                        left: effectiveHeadlineLeft,
                        top: effectiveHeadlineTop,
                        child: SizedBox(
                          width: baseA4Width * 0.44,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Headline Principal (ex: O SOL TRABALHA POR VOCÊ)
                              Text(
                                settings.verticalSplitHeadline,
                                style: getCoverTextStyle(
                                  fontFamily: settings.coverHeadlineFont,
                                  fontSize: 24.0,
                                  fontWeight: FontWeight.w900,
                                  color: Color(settings.coverHeadlineColorValue),
                                  height: 1.15,
                                  letterSpacing: 1.0,
                                  shadows: const [
                                    Shadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 2)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Barra sob o título
                              Container(
                                width: 48,
                                height: 4.0,
                                decoration: BoxDecoration(
                                  color: accentColor,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Subheadline (ex: MAIS ECONOMIA. MAIS SUSTENTABILIDADE...)
                              Text(
                                settings.verticalSplitSubheadline,
                                style: getCoverTextStyle(
                                  fontFamily: settings.coverHeadlineFont,
                                  fontSize: 11.0,
                                  fontWeight: FontWeight.w700,
                                  color: Color(settings.coverHeadlineColorValue).withValues(alpha: 0.95),
                                  height: 1.35,
                                  letterSpacing: 0.8,
                                  shadows: const [
                                    Shadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 1)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // ── 3. Rodapé do Lado Esquerdo ─────────────────────────────
                    if (settings.verticalSplitShowLeftFooter)
                      Positioned(
                        left: effectiveLeftFooterLeft,
                        bottom: effectiveLeftFooterBottom,
                        child: SizedBox(
                          width: baseA4Width * settings.verticalSplitLeftFooterWidth.clamp(0.20, 0.95),
                          child: divType == 2
                              ? Text(
                                  settings.verticalSplitLeftFooter,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white.withValues(alpha: 0.85),
                                    letterSpacing: 0.6,
                                  ),
                                )
                              : settings.verticalSplitBadgesLayout == 'vertical'
                                  ? Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        for (int i = 0; i < badges.length; i++)
                                          Padding(
                                            padding: const EdgeInsets.only(bottom: 6),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  getCoverBadgeIcon(badges[i].iconKey),
                                                  color: accentColor,
                                                  size: 16.0,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  badges[i].label,
                                                  style: getCoverTextStyle(
                                                    fontFamily: settings.coverHeadlineFont,
                                                    fontSize: 9.0,
                                                    fontWeight: FontWeight.w800,
                                                    color: Color(settings.coverBadgesTextColorValue),
                                                    letterSpacing: 0.8,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    )
                                  : settings.verticalSplitBadgesLayout == 'wrap'
                                      ? Wrap(
                                          spacing: 10,
                                          runSpacing: 6,
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          children: [
                                            for (int i = 0; i < badges.length; i++) ...[
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    getCoverBadgeIcon(badges[i].iconKey),
                                                    color: accentColor,
                                                    size: 16.0,
                                                  ),
                                                  const SizedBox(width: 5),
                                                  Text(
                                                    badges[i].label,
                                                    style: getCoverTextStyle(
                                                      fontFamily: settings.coverHeadlineFont,
                                                      fontSize: 9.0,
                                                      fontWeight: FontWeight.w800,
                                                      color: Color(settings.coverBadgesTextColorValue),
                                                      letterSpacing: 0.8,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              if (i < badges.length - 1)
                                                Container(
                                                  width: 1.5,
                                                  height: 12,
                                                  color: Colors.white30,
                                                  margin: const EdgeInsets.symmetric(horizontal: 2),
                                                ),
                                            ],
                                          ],
                                        )
                                      : SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          physics: const NeverScrollableScrollPhysics(),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            children: [
                                              for (int i = 0; i < badges.length; i++) ...[
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      getCoverBadgeIcon(badges[i].iconKey),
                                                      color: accentColor,
                                                      size: 16.0,
                                                    ),
                                                    const SizedBox(width: 5),
                                                    Text(
                                                      badges[i].label,
                                                      style: getCoverTextStyle(
                                                        fontFamily: settings.coverHeadlineFont,
                                                        fontSize: 9.0,
                                                        fontWeight: FontWeight.w800,
                                                        color: Color(settings.coverBadgesTextColorValue),
                                                        letterSpacing: 0.8,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                if (i < badges.length - 1)
                                                  Container(
                                                    width: 1.5,
                                                    height: 12,
                                                    color: Colors.white30,
                                                    margin: const EdgeInsets.symmetric(horizontal: 6),
                                                  ),
                                              ],
                                            ],
                                          ),
                                        ),
                        ),
                      ),
                  ],
                ),
              ),

              // ── 4. Separador Geométrico & Watermark ───────────────────────────
              CustomPaint(
                size: const Size(baseA4Width, baseA4Height),
                painter: SolarVerticalSplitPainter(
                  dividerType: divType,
                  accentColor: accentColor,
                ),
              ),

              // ── 5. Lado Direito (Área Institucional Limpa) ────────────────────
              if (settings.verticalSplitShowRightBlock)
                Positioned(
                  right: effectiveRightBlockRight,
                  top: effectiveRightBlockTop,
                  child: SizedBox(
                    width: baseA4Width * 0.42,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // PROPOSTA (Espaçado em Montserrat)
                        Text(
                          settings.verticalSplitRightTitle,
                          style: getCoverTextStyle(
                            fontFamily: settings.coverRightBlockFont,
                            fontSize: 18.0,
                            fontWeight: FontWeight.w700,
                            color: Color(settings.coverRightTitleColorValue),
                            letterSpacing: 5.5,
                          ),
                        ),
                        const SizedBox(height: 3),

                        // SOLAR (Bold Grande Escuro em Montserrat)
                        Text(
                          settings.verticalSplitRightSubtitle,
                          style: getCoverTextStyle(
                            fontFamily: settings.coverRightBlockFont,
                            fontSize: 46.0,
                            fontWeight: FontWeight.w900,
                            color: Color(settings.coverRightSubtitleColorValue),
                            letterSpacing: 2.0,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Barra Dourada (única, diretamente abaixo de SOLAR)
                        Container(
                          width: 54,
                          height: 4.5,
                          decoration: BoxDecoration(
                            color: accentColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Tagline Direita (ex: ENERGIA INTELIGENTE PARA UM AMANHÃ MELHOR.)
                        Text(
                          settings.verticalSplitRightTagline,
                          style: getCoverTextStyle(
                            fontFamily: settings.coverRightBlockFont,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Color(settings.coverRightTaglineColorValue),
                            letterSpacing: 0.8,
                            height: 1.35,
                          ),
                        ),

                        // Se Tipo 2 (Sol Radiante), exibe os badges como cartões verticais na área branca
                        if (divType == 2 && badges.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          for (final badge in badges) ...[
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10.0),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    getCoverBadgeIcon(badge.iconKey),
                                    color: accentColor,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    badge.label,
                                    style: getCoverTextStyle(
                                      fontFamily: settings.coverHeadlineFont,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(settings.coverRightSubtitleColorValue),
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),

              // ── 6. Logomarca da Empresa (se habilitada) ───────────────────────
              if (settings.coverShowLogo &&
                  settings.companyLogoBase64 != null &&
                  settings.companyLogoBase64!.isNotEmpty)
                Positioned(
                  left: baseA4Width * settings.coverLogoPositionX,
                  top: baseA4Height * settings.coverLogoPositionY,
                  child: Image.network(
                    'data:image/png;base64,${settings.companyLogoBase64}',
                    width: settings.coverLogoWidth,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),

              // ── 7. Rodapé do Lado Direito (Somente texto, sem segunda barra) ─
              if (settings.verticalSplitShowRightFooter)
                Positioned(
                  right: effectiveRightFooterRight,
                  bottom: effectiveRightFooterBottom,
                  child: SizedBox(
                    width: baseA4Width * 0.40,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Texto do rodapé direito (ex: ENERGIA HOJE. MAIS POSSIBILIDADES AMANHÃ.)
                        Text(
                          settings.verticalSplitRightFooter,
                          style: getCoverTextStyle(
                            fontFamily: settings.coverFooterFont,
                            fontSize: 10.0,
                            fontWeight: FontWeight.w700,
                            color: Color(settings.coverFooterColorValue),
                            letterSpacing: 0.6,
                            height: 1.25,
                          ),
                        ),

                        if (clientName != null && clientName!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Cliente: $clientName',
                            style: GoogleFonts.montserrat(
                              fontSize: 10.0,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

              // ── 8. Textos Personalizados Extras Adicionados pelo Usuário ────
              for (final textItem in settings.customTextItems)
                Positioned(
                  left: textItem.x * baseA4Width,
                  top: textItem.y * baseA4Height,
                  child: Text(
                    textItem.text,
                    style: GoogleFonts.montserrat(
                      fontSize: textItem.fontSize,
                      fontWeight: textItem.isBold ? FontWeight.w800 : FontWeight.w500,
                      color: Color(textItem.colorValue),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),

              // ── 9. Ícones Personalizados Extras Adicionados pelo Usuário ────
              for (final iconItem in settings.customIconItems)
                Positioned(
                  left: iconItem.x * baseA4Width,
                  top: iconItem.y * baseA4Height,
                  child: Icon(
                    getCoverBadgeIcon(iconItem.iconKey),
                    size: iconItem.size,
                    color: Color(iconItem.colorValue),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
