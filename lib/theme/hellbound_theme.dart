import 'package:flutter/material.dart';

/// Colors sampled from the UI screenshots in the supplied project document.
/// Keep the original Hellbound palette when refining the interface.
abstract final class HellboundColors {
  static const background = Color(0xFF0C011F);
  static const surface = Color(0xFF2B0128);
  static const accent = Color(0xFFEC0123);
  static const accentSurface = Color(0xFF6D0122);
  static const text = Color(0xFFFFF4EF);
  static const muted = Color(0xFFCBA6B6);
  static const outline = Color(0xFF693449);
  static const error = Color(0xFFFF8798);
}

/// Shared visual foundation; screen structure and assets follow Figma.
abstract final class HellboundTheme {
  static const pagePadding = 24.0;
  static const controlRadius = 12.0;
  static const panelRadius = 20.0;
  static const transitionDuration = Duration(milliseconds: 200);

  static ThemeData get dark {
    const colors = ColorScheme.dark(
      primary: HellboundColors.accent,
      onPrimary: Colors.white,
      primaryContainer: HellboundColors.accentSurface,
      onPrimaryContainer: HellboundColors.text,
      secondary: HellboundColors.muted,
      onSecondary: HellboundColors.background,
      surface: HellboundColors.surface,
      onSurface: HellboundColors.text,
      onSurfaceVariant: HellboundColors.muted,
      outline: HellboundColors.outline,
      error: HellboundColors.error,
      onError: HellboundColors.background,
    );
    final base = ThemeData(useMaterial3: true, colorScheme: colors);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(controlRadius),
    );
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(controlRadius),
      borderSide: const BorderSide(color: HellboundColors.outline),
    );

    return base.copyWith(
      scaffoldBackgroundColor: HellboundColors.background,
      textTheme: base.textTheme.copyWith(
        headlineLarge: const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          height: 1.15,
          letterSpacing: -0.8,
          color: HellboundColors.text,
        ),
        headlineMedium: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          height: 1.2,
          letterSpacing: -0.5,
          color: HellboundColors.text,
        ),
        titleLarge: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          height: 1.3,
          color: HellboundColors.text,
        ),
        bodyLarge: const TextStyle(
          fontSize: 16,
          height: 1.5,
          color: HellboundColors.text,
        ),
        bodyMedium: const TextStyle(
          fontSize: 14,
          height: 1.5,
          color: HellboundColors.muted,
        ),
        labelLarge: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: HellboundColors.text,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: HellboundColors.background,
        foregroundColor: HellboundColors.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: shape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: HellboundColors.text,
          minimumSize: const Size(48, 52),
          side: const BorderSide(color: HellboundColors.outline),
          shape: shape,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: HellboundColors.background,
        contentPadding: const EdgeInsets.all(16),
        border: fieldBorder,
        enabledBorder: fieldBorder,
        focusedBorder: fieldBorder.copyWith(
          borderSide: const BorderSide(color: HellboundColors.accent, width: 2),
        ),
        errorBorder: fieldBorder.copyWith(
          borderSide: const BorderSide(color: HellboundColors.error),
        ),
        errorMaxLines: 3,
        labelStyle: const TextStyle(color: HellboundColors.muted),
      ),
      cardTheme: CardThemeData(
        color: HellboundColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(panelRadius),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: HellboundColors.surface,
        indicatorColor: HellboundColors.accentSurface,
        surfaceTintColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      dividerTheme: const DividerThemeData(
        color: HellboundColors.outline,
        thickness: 1,
        space: 32,
      ),
    );
  }
}
