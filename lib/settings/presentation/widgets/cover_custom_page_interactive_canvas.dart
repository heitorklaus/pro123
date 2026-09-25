import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/models/proposal_pages_models.dart';
import 'cover_header_footer_widgets.dart';

/// Canvas Interativo A4 para Páginas Personalizadas criadas pelo usuário
class CoverCustomPageInteractiveCanvas extends StatelessWidget {
  final double width;
  final double height;
  final double scale;
  final ProposalCustomPage page;
  final Color primaryColor;
  final bool showHeader;
  final int headerStyle;
  final String headerText1;
  final String headerText2;
  final String headerText3;
  final String headerBgColor;
  final String headerTextColor;
  final String headerIconColor;
  final bool showFooter;
  final int footerStyle;
  final String footerText1;
  final String footerText2;
  final String footerText3;
  final String footerText4;
  final String footerBgColor;
  final String footerTextColor;
  final String footerIconColor;

  const CoverCustomPageInteractiveCanvas({
    super.key,
    required this.width,
    required this.height,
    required this.scale,
    required this.page,
    required this.primaryColor,
    required this.showHeader,
    required this.headerStyle,
    required this.headerText1,
    required this.headerText2,
    required this.headerText3,
    required this.headerBgColor,
    required this.headerTextColor,
    required this.headerIconColor,
    required this.showFooter,
    required this.footerStyle,
    required this.footerText1,
    required this.footerText2,
    required this.footerText3,
    required this.footerText4,
    required this.footerBgColor,
    required this.footerTextColor,
    required this.footerIconColor,
  });

  @override
  Widget build(BuildContext context) {
    Color pageBgColor = Colors.white;
    if (page.bgType == 'color') {
      pageBgColor = Color(int.tryParse(page.bgColorHex.replaceAll('#', '0xFF')) ?? 0xFFFFFFFF);
    }

    return Container(
      width: width,
      height: height,
      color: pageBgColor,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Imagem de fundo se houver
          if (page.bgType == 'image' && page.bgImage != null && page.bgImage!.isNotEmpty)
            Opacity(
              opacity: 0.25,
              child: _buildBgImage(page.bgImage!),
            ),

          // Layout Estruturado com Cabeçalho, Miolo e Rodapé
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showHeader)
                CoverHeaderWidget(
                  styleId: headerStyle,
                  text1: headerText1.isNotEmpty ? headerText1 : 'PROPOSTA PERSONALIZADA',
                  text2: headerText2.isNotEmpty ? headerText2 : page.title,
                  text3: headerText3,
                  scale: scale,
                  accentColor: primaryColor,
                  customBgColorHex: headerBgColor,
                  customTextColorHex: headerTextColor,
                  customIconColorHex: headerIconColor,
                ),

              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24 * scale, vertical: 16 * scale),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        page.title,
                        style: GoogleFonts.outfit(
                          fontSize: 14 * scale,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      if (page.subtitle.isNotEmpty) ...[
                        SizedBox(height: 3 * scale),
                        Text(
                          page.subtitle,
                          style: GoogleFonts.inter(fontSize: 9 * scale, color: const Color(0xFF64748B)),
                        ),
                      ],
                      SizedBox(height: 12 * scale),

                      // Cards da Página Customizada
                      if (page.cards.isNotEmpty)
                        Expanded(
                          child: GridView.builder(
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 10 * scale,
                              mainAxisSpacing: 10 * scale,
                              childAspectRatio: 1.5,
                            ),
                            itemCount: page.cards.length,
                            itemBuilder: (ctx, idx) {
                              final card = page.cards[idx];
                              final cardColor = Color(int.tryParse(card.colorHex.replaceAll('#', '0xFF')) ?? 0xFF0284C7);

                              return Container(
                                padding: EdgeInsets.all(10 * scale),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8 * scale),
                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 4 * scale,
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.check_circle_outline_rounded, size: 14 * scale, color: cardColor),
                                        SizedBox(width: 6 * scale),
                                        Expanded(
                                          child: Text(
                                            card.title,
                                            style: GoogleFonts.inter(fontSize: 9 * scale, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 4 * scale),
                                    Expanded(
                                      child: Text(
                                        card.description,
                                        style: GoogleFonts.inter(fontSize: 7.5 * scale, color: const Color(0xFF64748B), height: 1.25),
                                        overflow: TextOverflow.fade,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              if (showFooter)
                CoverFooterWidget(
                  styleId: footerStyle,
                  text1: footerText1,
                  text2: footerText2,
                  text3: footerText3,
                  text4: footerText4,
                  scale: scale,
                  accentColor: primaryColor,
                  customBgColorHex: footerBgColor,
                  customTextColorHex: footerTextColor,
                  customIconColorHex: footerIconColor,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBgImage(String source) {
    if (source.startsWith('assets/')) {
      return Image.asset(source, fit: BoxFit.cover);
    }
    if (source.startsWith('http://') || source.startsWith('https://')) {
      return Image.network(source, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink());
    }
    try {
      final clean = source.contains(',') ? source.split(',').last : source;
      final bytes = base64Decode(clean);
      return Image.memory(bytes, fit: BoxFit.cover);
    } catch (_) {
      return const SizedBox.shrink();
    }
  }
}
