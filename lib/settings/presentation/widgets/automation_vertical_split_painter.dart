import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/models/automation_settings_model.dart';
import '../../data/services/automation_settings_service.dart';

/// Helper de ícones para os badges e ícones customizáveis da capa de automação
IconData getCoverBadgeIcon(String key) {
  switch (key.toLowerCase()) {
    case 'bolt':
    case 'energia':
    case 'raio':
    case 'luz':
      return Icons.bolt_rounded;
    case 'light':
    case 'lampada':
    case 'iluminacao':
      return Icons.lightbulb_outline_rounded;
    case 'music':
    case 'som':
    case 'audio':
      return Icons.music_note_rounded;
    case 'temp':
    case 'clima':
    case 'temperatura':
    case 'hvac':
      return Icons.thermostat_rounded;
    case 'camera':
    case 'cftv':
    case 'seguranca':
      return Icons.videocam_outlined;
    case 'lock':
    case 'cadeado':
    case 'fechadura':
      return Icons.lock_outline_rounded;
    case 'wifi':
    case 'rede':
    case 'mesh':
      return Icons.wifi_rounded;
    case 'curtain':
    case 'cortina':
    case 'persiana':
      return Icons.blinds_rounded;
    case 'chart':
    case 'grafico':
    case 'valorizacao':
      return Icons.bar_chart_rounded;
    case 'shield':
    case 'garantia':
      return Icons.shield_outlined;
    case 'star':
    case 'estrela':
      return Icons.star_rounded;
    case 'home':
    case 'casa':
    case 'residencia':
      return Icons.home_outlined;
    case 'phone':
    case 'telefone':
    case 'whatsapp':
      return Icons.phone_rounded;
    default:
      return Icons.bolt_rounded;
  }
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

/// Clipper do corte do lado esquerdo (foto/wallpaper)
class AutomationVerticalSplitPhotoClipper extends CustomClipper<Path> {
  final int dividerType; // 0 = Diagonal, 1 = Raio Tech, 2 = Arco

  const AutomationVerticalSplitPhotoClipper({this.dividerType = 0});

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path();

    path.moveTo(0, 0);

    switch (dividerType) {
      case 1:
        path.lineTo(w * 0.68, 0);
        path.lineTo(w * 0.48, h * 0.32);
        path.lineTo(w * 0.65, h * 0.32);
        path.lineTo(w * 0.42, h * 0.65);
        path.lineTo(w * 0.54, h * 0.65);
        path.lineTo(w * 0.35, h);
        path.lineTo(0, h);
        break;

      case 2:
        path.lineTo(w * 0.35, 0);
        path.lineTo(w * 0.43, h * 0.22);
        final arcRect = Rect.fromCircle(center: Offset(w * 0.35, h * 0.48), radius: w * 0.36);
        path.arcTo(arcRect, -math.pi / 2.5, math.pi * 0.82, false);
        path.lineTo(w * 0.60, h);
        path.lineTo(0, h);
        break;

      case 0:
      default:
        path.lineTo(w * 0.66, 0);
        path.lineTo(w * 0.35, h);
        path.lineTo(0, h);
        break;
    }

    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant AutomationVerticalSplitPhotoClipper oldClipper) =>
      oldClipper.dividerType != dividerType;
}

/// Painter da divisória decorativa (Borda Ciano/Dourada)
class AutomationVerticalSplitPainter extends CustomPainter {
  final int dividerType;
  final Color accentColor;

  const AutomationVerticalSplitPainter({
    required this.dividerType,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final borderPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final borderPath = Path();

    switch (dividerType) {
      case 1:
        borderPath.moveTo(w * 0.68, 0);
        borderPath.lineTo(w * 0.48, h * 0.32);
        borderPath.lineTo(w * 0.65, h * 0.32);
        borderPath.lineTo(w * 0.42, h * 0.65);
        borderPath.lineTo(w * 0.54, h * 0.65);
        borderPath.lineTo(w * 0.35, h);
        canvas.drawPath(borderPath, borderPaint);
        break;

      case 2:
        borderPath.moveTo(w * 0.35, 0);
        borderPath.lineTo(w * 0.43, h * 0.22);
        final arcRect = Rect.fromCircle(center: Offset(w * 0.35, h * 0.48), radius: w * 0.36);
        borderPath.arcTo(arcRect, -math.pi / 2.5, math.pi * 0.82, false);
        borderPath.lineTo(w * 0.60, h);
        canvas.drawPath(borderPath, borderPaint);
        break;

      case 0:
      default:
        borderPath.moveTo(w * 0.66, 0);
        borderPath.lineTo(w * 0.35, h);
        canvas.drawPath(borderPath, borderPaint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant AutomationVerticalSplitPainter oldDelegate) =>
      oldDelegate.dividerType != dividerType || oldDelegate.accentColor != accentColor;
}

/// Widget completo da Capa de Automação com Estilo Vertical Split (Live Preview & Proporcional A4)
class AutomationVerticalSplitCoverView extends StatelessWidget {
  final AutomationSettingsModel settings;
  final String? customWebBgUrl;
  final double width;
  final double height;
  final String? clientName;
  final String? proposalNumber;

  static const double baseA4Width = 595.28;
  static const double baseA4Height = 841.89;

  const AutomationVerticalSplitCoverView({
    super.key,
    required this.settings,
    this.customWebBgUrl,
    required this.width,
    required this.height,
    this.clientName,
    this.proposalNumber,
  });

  @override
  Widget build(BuildContext context) {
    final bgUrl = customWebBgUrl ??
        (settings.webBackgroundTemplate.isNotEmpty
            ? AutomationSettingsService.getWebBackgroundUrl(settings.webBackgroundTemplate)
            : AutomationSettingsService.getWebBackgroundUrl('AdobeStock_1030854734.jpg'));

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
              // ── 1. Foto de Fundo Recortada à Esquerda ──────────────────────────
              ClipPath(
                clipper: AutomationVerticalSplitPhotoClipper(dividerType: divType),
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
                            child: CircularProgressIndicator(color: Color(0xFF38BDF8), strokeWidth: 3),
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFF0F172A),
                        child: const Center(
                          child: Icon(Icons.home_outlined, color: Colors.white38, size: 64),
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

                    // ── 2. Headline & Subheadline do Lado Esquerdo ─────────────
                    if (settings.verticalSplitShowHeadline)
                      Positioned(
                        left: effectiveHeadlineLeft,
                        top: effectiveHeadlineTop,
                        child: SizedBox(
                          width: baseA4Width * 0.44,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
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
                              if (settings.verticalSplitShowHeadlineDivider) ...[
                                const SizedBox(height: 8),
                                Container(
                                  width: settings.verticalSplitHeadlineDividerWidth,
                                  height: settings.verticalSplitHeadlineDividerHeight,
                                  decoration: BoxDecoration(
                                    color: Color(settings.verticalSplitHeadlineDividerColorValue),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ] else ...[
                                const SizedBox(height: 12),
                              ],
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
                                                  color: Color(settings.coverBadgesIconColorValue),
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
                                                  color: Color(settings.coverBadgesIconColorValue),
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

              // ── 4. Separador Geométrico ──────────────────────────────────────
              CustomPaint(
                size: const Size(baseA4Width, baseA4Height),
                painter: AutomationVerticalSplitPainter(
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
                        if (settings.verticalSplitShowRightDivider) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: settings.verticalSplitRightDividerWidth,
                            height: settings.verticalSplitRightDividerHeight,
                            decoration: BoxDecoration(
                              color: Color(settings.verticalSplitRightDividerColorValue),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 14),
                        ] else ...[
                          const SizedBox(height: 14),
                        ],
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
                      ],
                    ),
                  ),
                ),

              // ── 6. Logomarca da Empresa ───────────────────────────────────────
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

              // ── 7. Rodapé do Lado Direito ─────────────────────────────────────
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
                        Text(
                          settings.verticalSplitRightFooter,
                          style: getCoverTextStyle(
                            fontFamily: settings.coverFooterFont,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: Color(settings.coverFooterColorValue),
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${settings.companyName} • Soluções em Automação & Conforto',
                          style: GoogleFonts.inter(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF94A3B8),
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
    );
  }
}
