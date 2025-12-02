import 'package:flutter/material.dart';
import 'package:statusxp/theme/colors.dart';
import 'package:statusxp/theme/typography.dart' as app_typography;

/// StatusXP Main Theme Configuration
/// 
/// Dark theme with neon accents for a modern gaming aesthetic.
/// Designed for mobile-first with web compatibility.

final ThemeData statusXPTheme = ThemeData(
  // Use Material 3
  useMaterial3: true,

  // Color scheme
  colorScheme: const ColorScheme.dark(
    primary: accentPrimary,
    secondary: accentSecondary,
    surface: surfaceLight,
    error: accentWarning,
    onPrimary: backgroundDark,
    onSecondary: textPrimary,
    onSurface: textPrimary,
  ),

  // Scaffold background
  scaffoldBackgroundColor: backgroundDark,
  canvasColor: backgroundDark,

  // Typography
  textTheme: const TextTheme(
    displayLarge: app_typography.displayLarge,
    displayMedium: app_typography.displayMedium,
    headlineLarge: app_typography.headlineLarge,
    headlineMedium: app_typography.headlineMedium,
    titleLarge: app_typography.titleLarge,
    titleMedium: app_typography.titleMedium,
    titleSmall: app_typography.titleSmall,
    bodyLarge: app_typography.bodyLarge,
    bodyMedium: app_typography.bodyMedium,
    bodySmall: app_typography.bodySmall,
    labelLarge: app_typography.labelLarge,
    labelMedium: app_typography.labelMedium,
    labelSmall: app_typography.labelSmall,
  ),

  // Card theme
  cardTheme: CardThemeData(
    color: surfaceLight,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  ),

  // AppBar theme
  appBarTheme: const AppBarTheme(
    backgroundColor: backgroundDark,
    elevation: 0,
    centerTitle: false,
    titleTextStyle: app_typography.headlineMedium,
    iconTheme: IconThemeData(color: textPrimary),
  ),

  // Button themes
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: accentPrimary,
      foregroundColor: backgroundDark,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      textStyle: app_typography.labelLarge.copyWith(
        fontWeight: FontWeight.bold,
        color: backgroundDark,
      ),
    ),
  ),

  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: accentPrimary,
      foregroundColor: backgroundDark,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      textStyle: app_typography.labelLarge.copyWith(
        fontWeight: FontWeight.bold,
        color: backgroundDark,
      ),
    ),
  ),

  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: accentPrimary,
      side: const BorderSide(color: accentPrimary, width: 2),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      textStyle: app_typography.labelLarge.copyWith(
        fontWeight: FontWeight.bold,
        color: accentPrimary,
      ),
    ),
  ),

  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: accentPrimary,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      textStyle: app_typography.labelLarge.copyWith(
        fontWeight: FontWeight.w600,
        color: accentPrimary,
      ),
    ),
  ),

  // Input decoration theme
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: surfaceDark,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: surfaceLight, width: 1),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: surfaceLight, width: 1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: accentPrimary, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: accentWarning, width: 1),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: accentWarning, width: 2),
    ),
    labelStyle: app_typography.bodyMedium.copyWith(color: textSecondary),
    hintStyle: app_typography.bodyMedium.copyWith(color: textMuted),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  ),

  // Icon theme
  iconTheme: const IconThemeData(
    color: textPrimary,
    size: 24,
  ),

  // Divider theme
  dividerTheme: const DividerThemeData(
    color: surfaceLight,
    thickness: 1,
    space: 1,
  ),

  // Remove splash effects for cleaner neon aesthetic
  splashFactory: NoSplash.splashFactory,
  highlightColor: Colors.transparent,
  splashColor: Colors.transparent,
);
