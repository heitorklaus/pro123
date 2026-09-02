import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_colors.dart';
import 'app_decorations.dart';

/// Configuração Principal do Tema ThemeData do TAOS CRM
abstract class AppTheme {
  static const _themeModeKey = 'mavis_crm_theme_mode';

  /// Notificador reativo de Tema (Claro / Escuro) - PADRÃO DARK
  static final ValueNotifier<ThemeMode> themeModeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.dark);

  /// Retorna se o tema escuro está atualmente ativo
  static bool get isDarkMode => themeModeNotifier.value == ThemeMode.dark;

  /// Inicializa a preferência de tema salva no SharedPreferences (Padrão DARK)
  static Future<void> initThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMode = prefs.getString(_themeModeKey);
      if (savedMode == 'light') {
        themeModeNotifier.value = ThemeMode.light;
      } else {
        // Padrão: Tema Dark
        themeModeNotifier.value = ThemeMode.dark;
      }
    } catch (_) {
      themeModeNotifier.value = ThemeMode.dark;
    }
  }

  /// Alterna entre Tema Claro e Tema Escuro e persiste localmente
  static Future<void> toggleThemeMode() async {
    final nextMode =
        themeModeNotifier.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await setThemeMode(nextMode);
  }

  /// Define um tema específico e persiste no armazenamento local
  static Future<void> setThemeMode(ThemeMode mode) async {
    themeModeNotifier.value = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeModeKey, mode == ThemeMode.dark ? 'dark' : 'light');
    } catch (_) {}
  }

  /// Fonte padrão do sistema
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

  // ═════════════════════════════════════════════════════════════════════════════
  // ☀️ TEMA CLARO (LIGHT THEME)
  // ═════════════════════════════════════════════════════════════════════════════
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.surface,
      cardColor: AppColors.card,

      // --- ESQUEMA DE CORES ---
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        error: AppColors.error,
        onPrimary: AppColors.textOnPrimary,
        onSurface: AppColors.textPrimary,
      ),

      // --- TIPOGRAFIA ---
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
        headlineSmall: font(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: font(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: font(
          color: AppColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        titleSmall: font(
          color: AppColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: font(
          color: AppColors.textPrimary,
          fontSize: 16,
        ),
        bodyMedium: font(
          color: AppColors.textPrimary,
          fontSize: 14,
        ),
        bodySmall: font(
          color: AppColors.textSecondary,
          fontSize: 12,
        ),
        labelLarge: font(
          color: AppColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        labelMedium: font(
          color: AppColors.textSecondary,
          fontSize: 12,
        ),
        labelSmall: font(
          color: AppColors.textMuted,
          fontSize: 11,
        ),
      ),

      // --- DROPDOWN & MENU THEMES LIGHT ---
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: font(color: AppColors.textPrimary, fontSize: 14),
        menuStyle: const MenuStyle(
          backgroundColor: WidgetStatePropertyAll(AppColors.surface),
          surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
        ),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        textStyle: font(color: AppColors.textPrimary, fontSize: 14),
        labelTextStyle: WidgetStatePropertyAll(
          font(color: AppColors.textPrimary, fontSize: 14),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: AppDecorations.radiusMedium,
          side: const BorderSide(color: AppColors.border),
        ),
      ),

      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: const WidgetStatePropertyAll(AppColors.surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: AppDecorations.radiusMedium,
              side: const BorderSide(color: AppColors.border),
            ),
          ),
        ),
      ),

      menuButtonTheme: MenuButtonThemeData(
        style: MenuItemButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          textStyle: font(color: AppColors.textPrimary, fontSize: 14),
        ),
      ),

      // --- CAMPOS DE TEXTO (INPUT) ---
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        hintStyle: font(color: AppColors.textMuted, fontSize: 14),
        labelStyle: font(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w600),
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

      // --- BOTÕES ---
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnPrimary,
          elevation: 0,
          minimumSize: const Size(64, 44),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: font(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          shape: RoundedRectangleBorder(borderRadius: AppDecorations.radiusMedium),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(64, 44),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          textStyle: font(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          shape: RoundedRectangleBorder(borderRadius: AppDecorations.radiusMedium),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: font(fontSize: 14, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: AppDecorations.radiusSmall),
        ),
      ),

      // --- CARDS ---
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

  // ═════════════════════════════════════════════════════════════════════════════
  // 🌙 TEMA ESCURO (DARK THEME)
  // ═════════════════════════════════════════════════════════════════════════════
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBackground,
      canvasColor: AppColors.darkSurface,
      cardColor: AppColors.darkCard,

      // --- ESQUEMA DE CORES DARK ---
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.darkSurface,
        surfaceContainer: AppColors.darkSurface,
        surfaceContainerHigh: AppColors.darkSurface,
        surfaceContainerHighest: AppColors.darkSurface,
        error: AppColors.error,
        onPrimary: Colors.white,
        onSurface: AppColors.darkTextPrimary,
        onSurfaceVariant: AppColors.darkTextSecondary,
      ),

      // --- TIPOGRAFIA DARK (TEXTOS BRANCOS / CLAROS POR PADRÃO) ---
      textTheme: GoogleFonts.robotoTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: font(color: AppColors.darkTextPrimary),
        displayMedium: font(color: AppColors.darkTextPrimary),
        displaySmall: font(color: AppColors.darkTextPrimary),
        headlineLarge: font(
          color: AppColors.darkTextPrimary,
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: font(
          color: AppColors.darkTextPrimary,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        headlineSmall: font(
          color: AppColors.darkTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: font(
          color: AppColors.darkTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: font(
          color: AppColors.darkTextPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        titleSmall: font(
          color: AppColors.darkTextPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: font(
          color: AppColors.darkTextPrimary,
          fontSize: 16,
        ),
        bodyMedium: font(
          color: AppColors.darkTextPrimary,
          fontSize: 14,
        ),
        bodySmall: font(
          color: AppColors.darkTextSecondary,
          fontSize: 12,
        ),
        labelLarge: font(
          color: AppColors.darkTextPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        labelMedium: font(
          color: AppColors.darkTextSecondary,
          fontSize: 12,
        ),
        labelSmall: font(
          color: AppColors.darkTextMuted,
          fontSize: 11,
        ),
      ),

      // --- DROPDOWN & MENU THEMES DARK (TEXTOS BRANCOS) ---
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: font(color: AppColors.darkTextPrimary, fontSize: 14),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.darkInputFill,
          labelStyle: font(color: AppColors.darkTextSecondary, fontSize: 14),
          hintStyle: font(color: AppColors.darkTextMuted, fontSize: 14),
        ),
        menuStyle: const MenuStyle(
          backgroundColor: WidgetStatePropertyAll(AppColors.darkSurface),
          surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
        ),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.darkSurface,
        surfaceTintColor: Colors.transparent,
        textStyle: font(color: AppColors.darkTextPrimary, fontSize: 14),
        labelTextStyle: WidgetStatePropertyAll(
          font(color: AppColors.darkTextPrimary, fontSize: 14),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: AppDecorations.radiusMedium,
          side: const BorderSide(color: AppColors.darkBorder),
        ),
      ),

      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: const WidgetStatePropertyAll(AppColors.darkSurface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: AppDecorations.radiusMedium,
              side: const BorderSide(color: AppColors.darkBorder),
            ),
          ),
        ),
      ),

      menuButtonTheme: MenuButtonThemeData(
        style: MenuItemButton.styleFrom(
          foregroundColor: AppColors.darkTextPrimary,
          textStyle: font(color: AppColors.darkTextPrimary, fontSize: 14),
        ),
      ),

      iconTheme: const IconThemeData(
        color: AppColors.darkTextPrimary,
      ),

      // --- CAMPOS DE TEXTO DARK ---
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkInputFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        hintStyle: font(color: AppColors.darkTextMuted, fontSize: 14),
        labelStyle: font(color: AppColors.darkTextSecondary, fontSize: 14, fontWeight: FontWeight.w600),
        border: OutlineInputBorder(
          borderRadius: AppDecorations.radiusMedium,
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppDecorations.radiusMedium,
          borderSide: const BorderSide(color: AppColors.darkBorder),
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

      // --- BOTÕES DARK ---
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(64, 44),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: font(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          shape: RoundedRectangleBorder(borderRadius: AppDecorations.radiusMedium),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryLight,
          minimumSize: const Size(64, 44),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          side: const BorderSide(color: AppColors.primaryLight, width: 1.5),
          textStyle: font(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          shape: RoundedRectangleBorder(borderRadius: AppDecorations.radiusMedium),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryLight,
          textStyle: font(fontSize: 14, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: AppDecorations.radiusSmall),
        ),
      ),

      // --- CARDS DARK ---
      cardTheme: CardThemeData(
        color: AppColors.darkCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppDecorations.radiusMedium,
          side: const BorderSide(color: AppColors.darkBorder),
        ),
      ),

      // --- DIALOGS DARK ---
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.darkBorder),
        ),
      ),
    );
  }
}
