import 'package:flutter/material.dart';

class AppColors {
  static const ink = Color(0xFF070D12);
  static const surface = Color(0xFF0D151B);
  static const surface2 = Color(0xFF111B23);
  static const surface3 = Color(0xFF17232D);
  static const line = Color(0xFF24313B);
  static const lineStrong = Color(0xFF344550);
  static const muted = Color(0xFF9AA7B3);
  static const text = Color(0xFFF7FAFC);
  static const coral = Color(0xFFFF5A4D);
  static const teal = Color(0xFF19C7BA);
  static const gold = Color(0xFFF6B83F);
  static const blue = Color(0xFF248CF0);
}

class AppRadii {
  static const xs = 6.0;
  static const sm = 8.0;
  static const md = 10.0;
  static const lg = 12.0;
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
    dividerColor: AppColors.line,
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        fontSize: 30,
        height: 1.08,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        height: 1.12,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        height: 1.2,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
      titleMedium: TextStyle(
        fontSize: 15,
        height: 1.25,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
      bodyLarge: TextStyle(fontSize: 15, height: 1.35, letterSpacing: 0),
      bodyMedium: TextStyle(fontSize: 14, height: 1.35, letterSpacing: 0),
      labelLarge: TextStyle(
        fontSize: 13,
        height: 1.2,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
    ).apply(bodyColor: AppColors.text, displayColor: AppColors.text),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: AppColors.ink,
      foregroundColor: AppColors.text,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.text,
        fontSize: 18,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: AppColors.surface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        side: const BorderSide(color: AppColors.line),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        borderSide: const BorderSide(color: AppColors.teal, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.teal,
        foregroundColor: AppColors.ink,
        minimumSize: const Size(0, 44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w900),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.text,
        side: const BorderSide(color: AppColors.lineStrong),
        minimumSize: const Size(0, 44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.teal.withValues(alpha: 0.18),
      side: const BorderSide(color: AppColors.line),
      labelStyle: const TextStyle(
        color: AppColors.text,
        fontWeight: FontWeight.w700,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.teal.withValues(alpha: 0.15),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w900
              : FontWeight.w700,
          color: states.contains(WidgetState.selected)
              ? AppColors.text
              : AppColors.muted,
        ),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface2,
      modalBackgroundColor: AppColors.surface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
      ),
    ),
  );
}
