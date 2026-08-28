import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Decorações, Sombras e Raios de Borda Reutilizáveis
abstract class AppDecorations {
  // --- ARREDONDAMENTO DE BORDAS ---
  static const double radiusSmallValue = 8.0;
  static const double radiusMediumValue = 14.0;
  static const double radiusLargeValue = 20.0;

  static final BorderRadius radiusSmall = BorderRadius.circular(radiusSmallValue);
  static final BorderRadius radiusMedium = BorderRadius.circular(radiusMediumValue);
  static final BorderRadius radiusLarge = BorderRadius.circular(radiusLargeValue);
  static final BorderRadius radiusFull = BorderRadius.circular(999.0);

  // --- SOMBRAS (BOX SHADOWS) ---
  static final List<BoxShadow> shadowSoft = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];

  static final List<BoxShadow> shadowElevated = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  static final List<BoxShadow> shadowPrimaryGlow = [
    BoxShadow(
      color: AppColors.primary.withValues(alpha: 0.35),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];
}
