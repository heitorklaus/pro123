import 'package:flutter/material.dart';

/// Logo Horizontal completa para AppBar e Barras de Navegação — usa a
/// imagem oficial da marca já composta (ícone + TAOS + CRM), sem nenhum
/// desenho ou montagem programática.
class TaosLogo extends StatelessWidget {
  final double height;
  final MainAxisSize mainAxisSize;
  final bool isDarkBackground;

  const TaosLogo({
    super.key,
    this.height = 38,
    this.mainAxisSize = MainAxisSize.min,
    this.isDarkBackground = true,
  });

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final assetPath = isDarkBackground
        ? 'assets/images/taos_logo_dark_bg.png'
        : 'assets/images/taos_logo_light_bg.png';
    return Image.asset(
      assetPath,
      height: height,
      fit: BoxFit.contain,
      alignment: Alignment.centerLeft,
      filterQuality: FilterQuality.high,
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
    final assetPath = isDarkBackground
        ? 'assets/images/taos_logo_dark_bg.png'
        : 'assets/images/taos_logo_light_bg.png';
    return Image.asset(
      assetPath,
      width: width,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      cacheWidth: (width * dpr).round(),
    );
  }
}
