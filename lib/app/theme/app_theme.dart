import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_decorations.dart';

/// Configuração Principal do Tema ThemeData do Mavis CRM
/// Altere as chamadas do GoogleFonts aqui para trocar a fonte de todo o sistema!
abstract class AppTheme {
  /// Fonte padrão do sistema (Altere para GoogleFonts.poppins, GoogleFonts.inter, etc.)
  static TextStyle font({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
  }) {
    return GoogleFonts.roboto(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,

      // --- ESQUEMA DE CORES ---
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        error: AppColors.error,
        onPrimary: AppColors.textOnPrimary,
        onSurface: AppColors.textPrimary,
      ),

      // --- TIPOGRAFIA DA APLICAÇÃO (ROBOTO) ---
      textTheme: GoogleFonts.robotoTextTheme().copyWith(
        headlineLarge: font(
          color: AppColors.textPrimary,
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: font(
          color: AppColors.textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: font(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: font(
          color: AppColors.textPrimary,
          fontSize: 16,
        ),
        bodyMedium: font(
          color: AppColors.textSecondary,
          fontSize: 14,
        ),
      ),

      // --- ESTILIZAÇÃO DOS CAMPOS DE TEXTO (INPUT TEXT) ---
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputFill,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        hintStyle: font(
          color: AppColors.textMuted,
          fontSize: 14,
        ),
        labelStyle: font(
          color: AppColors.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        border: OutlineInputBorder(
          borderRadius: AppDecorations.radiusMedium,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppDecorations.radiusMedium,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppDecorations.radiusMedium,
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppDecorations.radiusMedium,
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppDecorations.radiusMedium,
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
      ),

      // --- ESTILIZAÇÃO DOS BOTÕES PRIMÁRIOS (ELEVATED BUTTON) ---
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnPrimary,
          elevation: 0,
          minimumSize: const Size(64, 44),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: font(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: AppDecorations.radiusMedium,
          ),
        ),
      ),

      // --- ESTILIZAÇÃO DOS BOTÕES SECUNDÁRIOS / BORDA (OUTLINED BUTTON) ---
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(64, 44),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          textStyle: font(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: AppDecorations.radiusMedium,
          ),
        ),
      ),

      // --- ESTILIZAÇÃO DOS BOTÕES DE TEXTO (TEXT BUTTON) ---
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: font(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: AppDecorations.radiusSmall,
          ),
        ),
      ),

      // --- ESTILIZAÇÃO DE CARDS ---
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppDecorations.radiusMedium,
          side: const BorderSide(color: AppColors.border),
        ),
      ),
    );
  }
}
