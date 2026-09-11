import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class OnboardingNicheCard extends StatefulWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String imagePath;
  final VoidCallback onTap;

  const OnboardingNicheCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.imagePath,
    required this.onTap,
  });

  @override
  State<OnboardingNicheCard> createState() => _OnboardingNicheCardState();
}

class _OnboardingNicheCardState extends State<OnboardingNicheCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          width: 250,
          height: 360,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _isHovered
                  ? const Color(0xFF6366F1).withValues(alpha: 0.5)
                  : const Color(0xFFE2E8F0),
              width: _isHovered ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: _isHovered
                    ? const Color(0xFF0F172A).withValues(alpha: 0.12)
                    : const Color(0xFF0F172A).withValues(alpha: 0.04),
                blurRadius: _isHovered ? 24 : 12,
                offset: Offset(0, _isHovered ? 10 : 5),
                spreadRadius: _isHovered ? 1 : 0,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(17),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Information Section
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Ícone com fundo pastel arredondado
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: widget.iconBgColor,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: _isHovered
                              ? [
                                  BoxShadow(
                                    color: widget.iconColor.withValues(alpha: 0.25),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  )
                                ]
                              : [],
                        ),
                        child: Center(
                          child: Icon(
                            widget.icon,
                            size: 22,
                            color: widget.iconColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Título do Nicho (com altura consistente para manter alinhamento)
                      SizedBox(
                        height: 42,
                        child: Text(
                          widget.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            height: 1.18,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Descrição (com altura consistente)
                      SizedBox(
                        height: 48,
                        child: Text(
                          widget.description,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            height: 1.35,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Botão Circular com Seta (→)
                      AnimatedSlide(
                        duration: const Duration(milliseconds: 200),
                        offset: _isHovered ? const Offset(0.12, 0) : Offset.zero,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _isHovered
                                ? const Color(0xFF1E293B)
                                : const Color(0xFF0F172A),
                            shape: BoxShape.circle,
                            boxShadow: _isHovered
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF0F172A).withValues(alpha: 0.35),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    )
                                  ]
                                : [],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.arrow_forward_rounded,
                              size: 17,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Bottom Photographic Image - Dynamic Expanded to NEVER overflow
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(17),
                      bottomRight: Radius.circular(17),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Imagem de fundo com zoom suave (AnimatedScale)
                        AnimatedScale(
                          scale: _isHovered ? 1.07 : 1.0,
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeOutCubic,
                          child: Image.asset(
                            widget.imagePath,
                            fit: BoxFit.cover,
                            alignment: Alignment.center,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: widget.iconBgColor,
                                child: Center(
                                  child: Icon(
                                    widget.icon,
                                    size: 36,
                                    color: widget.iconColor.withValues(alpha: 0.5),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                        // Gradiente de transição do card para a imagem
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.white.withValues(alpha: 0.12),
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.08),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Efeito de Brilho, Luz e Contraste Sutil no Hover
                        AnimatedOpacity(
                          opacity: _isHovered ? 0.35 : 0.0,
                          duration: const Duration(milliseconds: 260),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withValues(alpha: 0.7),
                                  Colors.white.withValues(alpha: 0.2),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.4, 1.0],
                              ),
                            ),
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
      ),
    );
  }
}
