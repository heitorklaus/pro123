import 'package:flutter/material.dart';

/// Arquivo Central de Cores do Aplicativo Mavis CRM
/// Altere as cores aqui para atualizar todo o sistema automaticamente.
abstract class AppColors {
  // --- CORES DE MARCA / PRINCIPAIS ---
  static const Color primary = Color(0xFF6366F1); // Indigo / Violeta Principal
  static const Color primaryDark = Color(0xFF4F46E5); // Indigo Escuro
  static const Color primaryLight = Color(0xFF818CF8); // Indigo Claro
  static const Color secondary = Color(0xFF0EA5E9); // Azul Celeste Secundário
  static const Color accent = Color(0xFFF59E0B); // Amarelo Destaque

  // --- NEUTROS & SUPERFÍCIES ---
  static const Color background = Color(0xFFF8FAFC); // Fundo Principal da Tela
  static const Color surface = Color(0xFFFFFFFF); // Superfícies e Cards
  static const Color card = Color(0xFFFFFFFF); // Fundo de Cards
  static const Color inputFill = Color(0xFFF8FAFC); // Fundo dos Input Texts
  static const Color border = Color(0xFFE2E8F0); // Bordas e Divisores
  static const Color divider = Color(0xFFF1F5F9); // Linhas Divisórias

  // --- CORES DE TEXTO ---
  static const Color textPrimary =
      Color(0xFF0F172A); // Texto Principal / Títulos
  static const Color textSecondary =
      Color(0xFF475569); // Subtítulos e Descrições
  static const Color textMuted = Color(0xFF94A3B8); // Textos Apagados / Hints
  static const Color textOnPrimary =
      Colors.white; // Texto sobre botões primários

  // --- STATUS & FEEDBACK ---
  static const Color success = Color(0xFF10B981); // Verde Sucesso
  static const Color error = Color(0xFFEF4444); // Vermelho Erro
  static const Color warning = Color(0xFFF59E0B); // Amarelo Alerta
  static const Color info = Color(0xFF3B82F6); // Azul Informação

  // --- GRADIENTES REUTILIZÁVEIS ---
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDark],
  );

  static const LinearGradient darkBackgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0F172A),
      Color(0xFF1E1B4B),
      Color(0xFF312E81),
    ],
  );
}
