import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Clipper da Janela de Foto Orgânica do Estilo Corporate Wave
class CorporateWavePhotoClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path();

    // Inicia na lateral esquerda abaixo da onda superior
    path.moveTo(0, h * 0.38);

    // Curva superior orgânica descendo e subindo pelo centro
    path.cubicTo(
      w * 0.22, h * 0.34,
      w * 0.42, h * 0.44,
      w * 0.70, h * 0.38,
    );

    // Contorna pelo lado direito até encontrar a onda do rodapé
    path.cubicTo(
      w * 0.76, h * 0.48,
      w * 0.68, h * 0.64,
      w * 0.60, h * 0.76,
    );

    // Curva inferior que acompanha a onda do rodapé
    path.cubicTo(
      w * 0.45, h * 0.84,
      w * 0.20, h * 0.86,
      0, h * 0.90,
    );

    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Painter decorativo do estilo Corporate Wave (Onda do Topo com Pontilhado e Onda do Rodapé)
class CorporateWaveDecorationPainter extends CustomPainter {
  final Color primaryColor;
  final Color secondaryColor;
  final Color darkColor;

  CorporateWaveDecorationPainter({
    required this.primaryColor,
    Color? secondaryColor,
    Color? darkColor,
  })  : secondaryColor = secondaryColor ?? primaryColor.withValues(alpha: 0.65),
        darkColor = darkColor ?? const Color(0xFF0F172A);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ─────────────────────────────────────────────────────────────────────────
    // 1. ONDA SUPERIOR ESQUERDA (AZUL PRIMÁRIO + SEGUNDA CAMADA + PONTILHADO)
    // ─────────────────────────────────────────────────────────────────────────
    // Camada Secundária (Lighter/Cyan) de fundo da onda superior
    final topSubPath = Path();
    topSubPath.moveTo(0, 0);
    topSubPath.lineTo(w * 0.52, 0);
    topSubPath.cubicTo(
      w * 0.46, h * 0.12,
      w * 0.32, h * 0.22,
      w * 0.36, h * 0.32,
    );
    topSubPath.cubicTo(
      w * 0.38, h * 0.36,
      w * 0.20, h * 0.38,
      0, h * 0.42,
    );
    topSubPath.close();

    final topSubPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          secondaryColor.withValues(alpha: 0.5),
          secondaryColor.withValues(alpha: 0.2),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w * 0.55, h * 0.45));
    canvas.drawPath(topSubPath, topSubPaint);

    // Camada Principal da Onda Superior
    final topMainPath = Path();
    topMainPath.moveTo(0, 0);
    topMainPath.lineTo(w * 0.44, 0);
    topMainPath.cubicTo(
      w * 0.38, h * 0.10,
      w * 0.24, h * 0.20,
      w * 0.28, h * 0.28,
    );
    topMainPath.cubicTo(
      w * 0.30, h * 0.32,
      w * 0.14, h * 0.34,
      0, h * 0.37,
    );
    topMainPath.close();

    final topMainPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          primaryColor,
          primaryColor.withValues(alpha: 0.85),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w * 0.45, h * 0.40));
    canvas.drawPath(topMainPath, topMainPaint);

    // Trama de Pontilhados Tecnológicos (Dot Matrix Pattern)
    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.28)
      ..style = PaintingStyle.fill;

    const double stepX = 14.0;
    const double stepY = 14.0;
    for (double dx = 12; dx < w * 0.48; dx += stepX) {
      for (double dy = 12; dy < h * 0.38; dy += stepY) {
        // Testa se o ponto está na área da onda ou transição
        if (dx < (w * 0.42 - (dy * 0.8)) || (dx < w * 0.36 && dy < h * 0.30)) {
          final dotR = 1.4 + (math.sin((dx + dy) * 0.05).abs() * 0.8);
          canvas.drawCircle(Offset(dx, dy), dotR, dotPaint);
        }
      }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 2. ONDA DO RODAPÉ E LATERAL DIREITA
    // ─────────────────────────────────────────────────────────────────────────
    // Camada Secundária (Fundo Lighter) da Onda Inferior
    final botSubPath = Path();
    botSubPath.moveTo(w, h * 0.26);
    botSubPath.cubicTo(
      w * 0.65, h * 0.46,
      w * 0.60, h * 0.62,
      w * 0.52, h * 0.74,
    );
    botSubPath.cubicTo(
      w * 0.40, h * 0.83,
      w * 0.18, h * 0.84,
      0, h * 0.87,
    );
    botSubPath.lineTo(0, h);
    botSubPath.lineTo(w, h);
    botSubPath.close();

    final botSubPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [
          secondaryColor.withValues(alpha: 0.45),
          secondaryColor.withValues(alpha: 0.20),
        ],
      ).createShader(Rect.fromLTWH(0, h * 0.26, w, h * 0.74));
    canvas.drawPath(botSubPath, botSubPaint);

    // Camada Principal da Onda Inferior
    final botMainPath = Path();
    botMainPath.moveTo(w, h * 0.32);
    botMainPath.cubicTo(
      w * 0.72, h * 0.48,
      w * 0.68, h * 0.64,
      w * 0.58, h * 0.76,
    );
    botMainPath.cubicTo(
      w * 0.46, h * 0.84,
      w * 0.22, h * 0.85,
      0, h * 0.90,
    );
    botMainPath.lineTo(0, h);
    botMainPath.lineTo(w, h);
    botMainPath.close();

    final botMainPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [
          primaryColor,
          Color.lerp(primaryColor, Colors.black, 0.25)!,
        ],
      ).createShader(Rect.fromLTWH(0, h * 0.32, w, h * 0.68));
    canvas.drawPath(botMainPath, botMainPaint);

    // Borda de realce sutil na curvatura da onda inferior
    final strokePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final botLinePath = Path();
    botLinePath.moveTo(w, h * 0.32);
    botLinePath.cubicTo(
      w * 0.72, h * 0.48,
      w * 0.68, h * 0.64,
      w * 0.58, h * 0.76,
    );
    botLinePath.cubicTo(
      w * 0.46, h * 0.84,
      w * 0.22, h * 0.85,
      0, h * 0.90,
    );
    canvas.drawPath(botLinePath, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CorporateWaveDecorationPainter oldDelegate) {
    return oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor ||
        oldDelegate.darkColor != darkColor;
  }
}

/// Widget Completo de Capa "Corporate Wave"
/// Renderiza a folha A4 com alta fidelidade ao modelo solicitado:
/// - Fundo branco premium
/// - Ondas orgânicas no topo e rodapé com pontilhado
/// - Janela central fluida com a foto em alta resolução
/// - Logomarca e Título da proposta no topo direito
/// - Rodapé curvo com contatos (Telefone, E-mail, Website)
class CorporateWaveCoverView extends StatelessWidget {
  final double width;
  final double height;
  final String title;
  final String subtitle;
  final String? clientName;
  final String? locationAndDate;
  final String? companyName;
  final String? companyPhone;
  final String? companyEmail;
  final String? companyWebsite;
  final String? companyLogoBase64;
  final String? photoUrl;
  final String? customPhotoBase64;
  final Color primaryColor;
  final Color? secondaryColor;

  static const double baseA4Width = 595.28;
  static const double baseA4Height = 841.89;

  const CorporateWaveCoverView({
    super.key,
    required this.width,
    required this.height,
    this.title = 'PROPOSTA\nDE SERVIÇO',
    this.subtitle = 'ENGENHARIA & TECNOLOGIA',
    this.clientName,
    this.locationAndDate = 'Brasil • 2026',
    this.companyName,
    this.companyPhone = '(11) 98765-4321',
    this.companyEmail = 'contato@empresa.com.br',
    this.companyWebsite = 'www.empresa.com.br',
    this.companyLogoBase64,
    this.photoUrl,
    this.customPhotoBase64,
    this.primaryColor = const Color(0xFF0284C7),
    this.secondaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: FittedBox(
        fit: BoxFit.contain,
        alignment: Alignment.center,
        child: Container(
          width: baseA4Width,
          height: baseA4Height,
          color: Colors.white,
          child: Stack(
            clipBehavior: Clip.none,
            fit: StackFit.expand,
            children: [
              // 1. JANELA CENTRAL DE FOTO ORGÂNICA (CLIPPED)
              Positioned.fill(
                child: ClipPath(
                  clipper: CorporateWavePhotoClipper(),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (customPhotoBase64 != null && customPhotoBase64!.isNotEmpty)
                        Image.memory(
                          base64Decode(customPhotoBase64!.contains(',')
                              ? customPhotoBase64!.split(',').last
                              : customPhotoBase64!),
                          fit: BoxFit.cover,
                          width: baseA4Width,
                          height: baseA4Height,
                        )
                      else if (photoUrl != null && photoUrl!.isNotEmpty)
                        Image.network(
                          photoUrl!,
                          fit: BoxFit.cover,
                          width: baseA4Width,
                          height: baseA4Height,
                          loadingBuilder: (ctx, child, progress) {
                            if (progress == null) return child;
                            return Container(
                              color: const Color(0xFF0F172A),
                              child: Center(
                                child: CircularProgressIndicator(color: primaryColor, strokeWidth: 3),
                              ),
                            );
                          },
                          errorBuilder: (_, __, ___) => Container(
                            color: const Color(0xFF0F172A),
                            child: const Center(
                              child: Icon(Icons.broken_image_rounded, color: Colors.white38, size: 64),
                            ),
                          ),
                        )
                      else
                        Container(color: const Color(0xFF0F172A)),

                      // Gradiente sutil sobre a foto para integração perfeita com a moldura
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.10),
                              Colors.black.withValues(alpha: 0.35),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. ONDAS VETORIAIS DECORATIVAS (TOPO E RODAPÉ)
              Positioned.fill(
                child: CustomPaint(
                  size: const Size(baseA4Width, baseA4Height),
                  painter: CorporateWaveDecorationPainter(
                    primaryColor: primaryColor,
                    secondaryColor: secondaryColor ?? const Color(0xFF38BDF8),
                  ),
                ),
              ),

              // 3. CABEÇALHO DIREITO (LOGO + TÍTULO DA PROPOSTA + SUBTÍTULO + DATA)
              Positioned(
                top: 50,
                right: 45,
                left: 230,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Logomarca da Empresa
                    if (companyLogoBase64 != null && companyLogoBase64!.isNotEmpty)
                      Image.memory(
                        base64Decode(companyLogoBase64!.contains(',')
                            ? companyLogoBase64!.split(',').last
                            : companyLogoBase64!),
                        height: 52,
                        fit: BoxFit.contain,
                      )
                    else
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.business_center_rounded, size: 36, color: primaryColor),
                          const SizedBox(width: 8),
                          Text(
                            companyName?.isNotEmpty == true ? companyName!.toUpperCase() : 'SUA EMPRESA',
                            style: GoogleFonts.outfit(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF0F172A),
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 38),

                    // Título em Destaque Navy Blue
                    Text(
                      title.toUpperCase(),
                      textAlign: TextAlign.right,
                      style: GoogleFonts.outfit(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0F172A),
                        height: 1.1,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Subtítulo / Nicho
                    Text(
                      subtitle.toUpperCase(),
                      textAlign: TextAlign.right,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: primaryColor,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Cliente / Localização / Data
                    if (clientName != null && clientName!.isNotEmpty) ...[
                      Text(
                        'Cliente: $clientName',
                        textAlign: TextAlign.right,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(height: 3),
                    ],
                    Text(
                      locationAndDate ?? 'Brasil • 2026',
                      textAlign: TextAlign.right,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),

              // 4. RODAPÉ INFERIOR (BARRA DE CONTATOS EMBUTIDA NA ONDA AZUL)
              Positioned(
                bottom: 26,
                left: 36,
                right: 36,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Telefone / WhatsApp
                    if (companyPhone != null && companyPhone!.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.phone_in_talk_rounded, color: Colors.white, size: 13),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            companyPhone!,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),

                    // E-mail Institucional
                    if (companyEmail != null && companyEmail!.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.email_outlined, color: Colors.white, size: 13),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            companyEmail!,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),

                    // Website / Portal
                    if (companyWebsite != null && companyWebsite!.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.language_rounded, color: Colors.white, size: 13),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            companyWebsite!,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
