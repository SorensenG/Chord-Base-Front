import 'package:flutter/material.dart';

class AppColors {
  static const ink = Color(0xFF0B1117);
  static const surface = Color(0xFF111A22);
  static const surface2 = Color(0xFF17222B);
  static const line = Color(0xFF263541);
  static const muted = Color(0xFF93A1AD);
  static const text = Color(0xFFF7FAFC);
  static const coral = Color(0xFFFF5A4D);
  static const teal = Color(0xFF19C7BA);
  static const gold = Color(0xFFF6B83F);
  static const blue = Color(0xFF248CF0);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.teal,
    brightness: Brightness.dark,
    surface: AppColors.surface,
    primary: AppColors.teal,
    secondary: AppColors.coral,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.ink,
    fontFamily: 'SF Pro Display',
    cardTheme: CardThemeData(
      elevation: 0,
      color: AppColors.surface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.line),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.ink,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.teal, width: 1.5),
      ),
    ),
  );
}
