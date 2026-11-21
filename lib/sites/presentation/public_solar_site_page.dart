import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/repositories/solar_site_repository.dart';
import '../domain/models/solar_site_model.dart';
import 'widgets/solar_site_one_page.dart';

/// Página pública do Site One-Page da empresa (`/#/site/:slug`), sem exigir login.
class PublicSolarSitePage extends StatelessWidget {
  final String slug;

  const PublicSolarSitePage({super.key, required this.slug});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SolarSiteConfig?>(
      future: SolarSiteRepository().getSiteBySlug(slug),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF0F172A),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFFF59E0B)),
            ),
          );
        }
        final cfg = snap.data;
        if (cfg == null) {
          return Scaffold(
            backgroundColor: const Color(0xFF0F172A),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.public_off_rounded,
                      color: Color(0xFF94A3B8), size: 54),
                  const SizedBox(height: 14),
                  Text(
                    'Site não encontrado ou não publicado.',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return SolarSiteOnePage(config: cfg, isPreview: false);
      },
    );
  }
}
