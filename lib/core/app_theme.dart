import 'package:flutter/material.dart';

class AppColors {
  static const Color background = Color(0xFF0D0B1E);
  static const Color surface = Color(0xFF171331);
  static const Color card = Color(0xFF1F1A3F);
  static const Color primary = Color(0xFFCF3CFD);
  static const Color primaryNeon = Color(0xFFFF3DF0);
  static const Color accentPink = Color(0xFFE243C1);
  static const Color accentPurple = Color(0xFF8A4FFF);
  static const Color textPrimary = Color(0xFFEDEAF7);
  static const Color textSecondary = Color(0xFFB6B1D3);
  static const Color success = Color(0xFF2ECC71);
  static const Color warning = Color(0xFFF1C40F);
  static const Color danger = Color(0xFFE74C3C);
}

ThemeData buildDarkTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      brightness: Brightness.dark,
      primary: AppColors.primary,
      secondary: AppColors.accentPurple,
      surface: AppColors.surface,
      onPrimary: Colors.white,
      onSurface: AppColors.textPrimary,
    ),
    scaffoldBackgroundColor: AppColors.background,
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
    ),
    cardColor: AppColors.card,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.accentPink, width: 1.2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.accentPink, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primaryNeon, width: 1.6),
      ),
      hintStyle: const TextStyle(color: AppColors.textSecondary),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: Colors.transparent,
      selectedColor: AppColors.accentPink,
      secondarySelectedColor: AppColors.accentPink,
      labelStyle: const TextStyle(color: AppColors.textPrimary),
      shape: const StadiumBorder(
        side: BorderSide(color: AppColors.accentPink, width: 1.2),
      ),
    ),
  );
}
