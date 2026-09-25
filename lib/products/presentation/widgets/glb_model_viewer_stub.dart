import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Implementação Fallback para Plataformas Não-Web
class GlbModelViewerWidget extends StatelessWidget {
  final String? glbUrl;
  final String? fallbackImageUrl;
  final bool autoRotate;
  final Color accentColor;
  final double glbScale;
  final double glbOrbitTheta;
  final double glbOrbitPhi;
  final bool enableCameraControls;
  final void Function(double thetaDeg, double phiDeg)? onCameraChange;

  const GlbModelViewerWidget({
    super.key,
    this.glbUrl,
    this.fallbackImageUrl,
    this.autoRotate = true,
    this.accentColor = const Color(0xFF00E5FF),
    this.glbScale = 1.2,
    this.glbOrbitTheta = 45.0,
    this.glbOrbitPhi = 65.0,
    this.enableCameraControls = true,
    this.onCameraChange,
  });

  static Map<String, double>? getCurrentCameraOrbit() => null;

  @override
  Widget build(BuildContext context) {
    if (fallbackImageUrl != null && fallbackImageUrl!.isNotEmpty) {
      if (fallbackImageUrl!.startsWith('assets/')) {
        return Image.asset(fallbackImageUrl!, fit: BoxFit.contain);
      }
      return Image.network(fallbackImageUrl!, fit: BoxFit.contain);
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.view_in_ar_rounded, size: 64, color: accentColor),
          const SizedBox(height: 12),
          Text(
            'Visualização 3D disponível na versão Web',
            style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
