import 'package:flutter/material.dart';

class AppTheme {
  // 🎨 Color Palette
  static const Color goldLight = Color(0xFFEABC5C);
  static const Color goldDark = Color(0xFFD7942E);
  static const Color background = Color(0xFF000000);
  static const Color darkContrast = Color(0xFF1A1A1A);

  // 🧭 ThemeData (This is what main.dart uses)
  static final ThemeData theme = ThemeData(
    scaffoldBackgroundColor: background,
    primaryColor: goldLight,
    colorScheme: const ColorScheme.dark(
      primary: goldLight,
      secondary: goldDark,
      background: background,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: background,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      iconTheme: IconThemeData(color: Colors.white),
    ),
    inputDecorationTheme: InputDecorationTheme(
      labelStyle: const TextStyle(color: Colors.white70),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.white24),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: goldLight, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
    ),
  );
}
