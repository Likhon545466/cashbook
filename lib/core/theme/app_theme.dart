import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData lightTheme({
    required Color seed,
    ColorScheme? dynamicScheme,
  }) {
    final scheme =
        (dynamicScheme ??
                ColorScheme.fromSeed(
                  seedColor: seed,
                  brightness: Brightness.light,
                ))
            .copyWith(
              surface: AppColors.lightCard,
              error: const Color(0xFFD34A4A),
            );

    return _base(
      scheme: scheme,
      background: AppColors.lightBackground,
      card: AppColors.lightCard,
      dark: false,
    );
  }

  static ThemeData darkTheme({
    required Color seed,
    ColorScheme? dynamicScheme,
  }) {
    final scheme =
        (dynamicScheme ??
                ColorScheme.fromSeed(
                  seedColor: seed,
                  brightness: Brightness.dark,
                ))
            .copyWith(
              surface: AppColors.darkCard,
              error: const Color(0xFFFF8484),
            );

    return _base(
      scheme: scheme,
      background: AppColors.darkBackground,
      card: AppColors.darkCard,
      dark: true,
    );
  }

  static ThemeData _base({
    required ColorScheme scheme,
    required Color background,
    required Color card,
    required bool dark,
  }) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      cardTheme: CardThemeData(
        elevation: 0,
        color: card,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
            color: dark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.04),
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: card,
        indicatorColor: scheme.primary.withValues(alpha: 0.13),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            fontSize: 12.5,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : dark
                ? const Color(0xFF96A19D)
                : const Color(0xFF6F7774),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: dark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.05),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.primary, width: 1.3),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: card,
        selectedColor: scheme.primary.withValues(alpha: 0.12),
        side: BorderSide(
          color: dark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.05),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      dividerColor: dark
          ? Colors.white.withValues(alpha: 0.07)
          : Colors.black.withValues(alpha: 0.06),
      textTheme: TextTheme(
        headlineSmall: const TextStyle(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.7,
        ),
        titleLarge: const TextStyle(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
        titleMedium: const TextStyle(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        titleSmall: const TextStyle(fontWeight: FontWeight.w700),
        bodySmall: TextStyle(
          color: dark ? const Color(0xFF96A19D) : const Color(0xFF6F7774),
        ),
      ),
    );
  }
}
