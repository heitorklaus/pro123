import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Logo Horizontal completa para AppBar e Barras de Navegação — usa a
/// imagem oficial da marca já composta (ícone + TAOS + CRM), sem nenhum
/// desenho ou montagem programática.
class TaosLogo extends StatelessWidget {
  final double height;
  final MainAxisSize mainAxisSize;

  const TaosLogo({
    super.key,
    this.height = 38,
    this.mainAxisSize = MainAxisSize.min,
  });

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    return Image.asset(
      'assets/images/logo_22.png',
      height: height,
      fit: BoxFit.contain,
      alignment: Alignment.centerLeft,
      filterQuality: FilterQuality.high,
      // Decodifica o bitmap já no tamanho de exibição (em vez de escalar em
      // tempo real um PNG de 2172px na GPU, o que aliasa/serrilha bastante
      // num downscale tão extremo).
      cacheHeight: (height * dpr).round(),
    );
  }
}

/// Logo Vertical Completa para Login e Cadastro (T no topo, TAOS abaixo e Slogan)
class TaosLoginLogo extends StatelessWidget {
  final double width;
  final bool isDarkBackground;

  const TaosLoginLogo({
    super.key,
    this.width = 220,
    this.isDarkBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset(
          'assets/images/taos_login_logo.png',
          width: width,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          cacheWidth: (width * dpr).round(),
          errorBuilder: (context, error, stackTrace) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/logo_22.png',
                  width: width,
                  filterQuality: FilterQuality.high,
                  cacheWidth: (width * dpr).round(),
                ),
                const SizedBox(height: 6),
                Text(
                  'TECHNOLOGY • AI • OPERATIONS • SALES',
                  style: GoogleFonts.inter(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                    color: const Color(0xFF475569),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
