import 'package:flutter/material.dart';

/// Palette TuniZit (inspirée du prototype : vert forêt, menthe, lime, ambre).
class AppColors {
  static const bg = Color(0xFFEAF6E8);
  static const surface = Colors.white;
  static const forest = Color(0xFF0E4429);
  static const leaf = Color(0xFF2E7D4F);
  static const lime = Color(0xFFC9F0AE);
  static const tile = Color(0xFFEFF8EC);
  static const tileBorder = Color(0xFFD7EBD3);
  static const amber = Color(0xFFFFE2A8);
  static const amberText = Color(0xFF7A4B00);
  static const ink = Color(0xFF14261B);
  static const muted = Color(0xFF5E7466);
  static const danger = Color(0xFFB3261E);
  static const dangerSoft = Color(0xFFFDECEA);
  static const warn = Color(0xFFC25E00);
}

class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.forest,
      primary: AppColors.forest,
      surface: AppColors.surface,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.bg,
      textTheme: ThemeData.light().textTheme.apply(
            bodyColor: AppColors.ink,
            displayColor: AppColors.ink,
          ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: AppColors.lime,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.forest,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}