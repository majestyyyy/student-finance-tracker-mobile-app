import 'package:flutter/material.dart';

/// Student-first design tokens: high contrast, energetic, dark-mode friendly.
class AppTheme {
  AppTheme._();

  static const Color backgroundDark = Color(0xFF0F1117);
  static const Color surfaceDark = Color(0xFF1A1D27);
  static const Color surfaceElevated = Color(0xFF242836);
  static const Color textPrimary = Color(0xFFF5F7FF);
  static const Color textSecondary = Color(0xFFB4BDD0);
  static const Color accentLime = Color(0xFF7CFF6B);
  static const Color accentCyan = Color(0xFF4DE8FF);
  static const Color accentOrange = Color(0xFFFF9F43);
  static const Color accentRed = Color(0xFFFF5C7A);
  static const Color accentPurple = Color(0xFFB388FF);

  static ThemeData dark() {
    final colorScheme = ColorScheme.dark(
      primary: accentCyan,
      secondary: accentLime,
      surface: surfaceDark,
      error: accentRed,
      onPrimary: backgroundDark,
      onSecondary: backgroundDark,
      onSurface: textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: backgroundDark,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: textPrimary,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accentCyan,
        foregroundColor: backgroundDark,
        elevation: 6,
        shape: StadiumBorder(),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return accentCyan.withValues(alpha: 0.25);
            }
            return surfaceElevated;
          }),
          foregroundColor: WidgetStateProperty.all(textPrimary),
          side: WidgetStateProperty.all(
            BorderSide(color: textSecondary.withValues(alpha: 0.3)),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }
}
