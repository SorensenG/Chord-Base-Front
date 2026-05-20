import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum AppThemePreference {
  system('Sistema', ThemeMode.system),
  light('Claro', ThemeMode.light),
  dark('Escuro', ThemeMode.dark);

  const AppThemePreference(this.label, this.themeMode);

  final String label;
  final ThemeMode themeMode;

  static AppThemePreference fromStorage(String? value) {
    return AppThemePreference.values.firstWhere(
      (item) => item.name == value,
      orElse: () => AppThemePreference.system,
    );
  }
}

final themeModeControllerProvider =
    StateNotifierProvider<ThemeModeController, AppThemePreference>((ref) {
      const storage = FlutterSecureStorage(
        aOptions: AndroidOptions(),
        webOptions: WebOptions(
          dbName: 'chordbase_secure',
          publicKey: 'chordbase',
        ),
      );
      return ThemeModeController(storage);
    });

class ThemeModeController extends StateNotifier<AppThemePreference> {
  ThemeModeController(this._storage) : super(AppThemePreference.system) {
    _restoreFuture = _restore();
    unawaited(_restoreFuture);
  }

  static const _themeModeKey = 'chordbase.themeMode';

  final FlutterSecureStorage _storage;
  late final Future<void> _restoreFuture;

  Future<void> setPreference(AppThemePreference preference) async {
    await _restoreFuture;
    state = preference;
    await _storage.write(key: _themeModeKey, value: preference.name);
  }

  Future<void> _restore() async {
    final stored = await _storage.read(key: _themeModeKey);
    state = AppThemePreference.fromStorage(stored);
  }
}

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

class AppThemeColors extends ThemeExtension<AppThemeColors> {
  const AppThemeColors({
    required this.ink,
    required this.surface,
    required this.surface2,
    required this.surface3,
    required this.line,
    required this.lineStrong,
    required this.muted,
    required this.text,
  });

  final Color ink;
  final Color surface;
  final Color surface2;
  final Color surface3;
  final Color line;
  final Color lineStrong;
  final Color muted;
  final Color text;

  static const dark = AppThemeColors(
    ink: AppColors.ink,
    surface: AppColors.surface,
    surface2: AppColors.surface2,
    surface3: AppColors.surface3,
    line: AppColors.line,
    lineStrong: AppColors.lineStrong,
    muted: AppColors.muted,
    text: AppColors.text,
  );

  static const light = AppThemeColors(
    ink: Color(0xFFF6F8FA),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFFFFFFF),
    surface3: Color(0xFFEFF3F6),
    line: Color(0xFFDDE5EA),
    lineStrong: Color(0xFFC5D0D8),
    muted: Color(0xFF60717F),
    text: Color(0xFF13202A),
  );

  static AppThemeColors forBrightness(Brightness brightness) {
    return brightness == Brightness.dark ? dark : light;
  }

  @override
  AppThemeColors copyWith({
    Color? ink,
    Color? surface,
    Color? surface2,
    Color? surface3,
    Color? line,
    Color? lineStrong,
    Color? muted,
    Color? text,
  }) {
    return AppThemeColors(
      ink: ink ?? this.ink,
      surface: surface ?? this.surface,
      surface2: surface2 ?? this.surface2,
      surface3: surface3 ?? this.surface3,
      line: line ?? this.line,
      lineStrong: lineStrong ?? this.lineStrong,
      muted: muted ?? this.muted,
      text: text ?? this.text,
    );
  }

  @override
  AppThemeColors lerp(ThemeExtension<AppThemeColors>? other, double t) {
    if (other is! AppThemeColors) return this;
    return AppThemeColors(
      ink: Color.lerp(ink, other.ink, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surface2: Color.lerp(surface2, other.surface2, t)!,
      surface3: Color.lerp(surface3, other.surface3, t)!,
      line: Color.lerp(line, other.line, t)!,
      lineStrong: Color.lerp(lineStrong, other.lineStrong, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      text: Color.lerp(text, other.text, t)!,
    );
  }
}

extension AppThemeContext on BuildContext {
  AppThemeColors get appColors =>
      Theme.of(this).extension<AppThemeColors>() ??
      AppThemeColors.forBrightness(Theme.of(this).brightness);
}

class AppRadii {
  static const xs = 6.0;
  static const sm = 8.0;
  static const md = 10.0;
  static const lg = 12.0;
}

ThemeData buildTheme(Brightness brightness) {
  final colors = AppThemeColors.forBrightness(brightness);
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.teal,
    brightness: brightness,
    surface: colors.surface,
    primary: AppColors.teal,
    secondary: AppColors.coral,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    extensions: <ThemeExtension<dynamic>>[colors],
    scaffoldBackgroundColor: colors.ink,
    fontFamily: 'SF Pro Display',
    dividerColor: colors.line,
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
    ).apply(bodyColor: colors.text, displayColor: colors.text),
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: colors.ink,
      foregroundColor: colors.text,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: colors.text,
        fontSize: 18,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: colors.surface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        side: BorderSide(color: colors.line),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        borderSide: BorderSide(color: colors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        borderSide: BorderSide(color: colors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        borderSide: const BorderSide(color: AppColors.teal, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.teal,
        foregroundColor: brightness == Brightness.dark
            ? AppColors.ink
            : Colors.white,
        minimumSize: const Size(0, 44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w900),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.text,
        side: BorderSide(color: colors.lineStrong),
        minimumSize: const Size(0, 44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: colors.surface,
      selectedColor: AppColors.teal.withValues(alpha: 0.18),
      side: BorderSide(color: colors.line),
      labelStyle: TextStyle(color: colors.text, fontWeight: FontWeight.w700),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colors.surface,
      indicatorColor: AppColors.teal.withValues(alpha: 0.15),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w900
              : FontWeight.w700,
          color: states.contains(WidgetState.selected)
              ? colors.text
              : colors.muted,
        ),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colors.surface2,
      modalBackgroundColor: colors.surface2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
      ),
    ),
  );
}
