import 'package:flutter/material.dart';
import 'package:statusxp/theme/colors.dart';

/// StatusXP Typography Scale
/// 
/// Modern gaming-inspired typography with clear hierarchy.

const String fontFamily = 'Inter'; // Will use system default until custom font added

/// Display styles - Large, bold headings
const TextStyle displayLarge = TextStyle(
  fontSize: 36,
  fontWeight: FontWeight.bold,
  color: textPrimary,
  height: 1.2,
  letterSpacing: -0.5,
);

const TextStyle displayMedium = TextStyle(
  fontSize: 32,
  fontWeight: FontWeight.bold,
  color: textPrimary,
  height: 1.2,
  letterSpacing: -0.5,
);

/// Headline styles - Section headers
const TextStyle headlineLarge = TextStyle(
  fontSize: 28,
  fontWeight: FontWeight.bold,
  color: textPrimary,
  height: 1.3,
);

const TextStyle headlineMedium = TextStyle(
  fontSize: 24,
  fontWeight: FontWeight.bold,
  color: textPrimary,
  height: 1.3,
);

/// Title styles - Card titles, important labels
const TextStyle titleLarge = TextStyle(
  fontSize: 22,
  fontWeight: FontWeight.w600,
  color: textPrimary,
  height: 1.4,
);

const TextStyle titleMedium = TextStyle(
  fontSize: 20,
  fontWeight: FontWeight.w600,
  color: textPrimary,
  height: 1.4,
);

const TextStyle titleSmall = TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w600,
  color: textPrimary,
  height: 1.4,
);

/// Body styles - Regular content
const TextStyle bodyLarge = TextStyle(
  fontSize: 18,
  fontWeight: FontWeight.normal,
  color: textPrimary,
  height: 1.5,
);

const TextStyle bodyMedium = TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.normal,
  color: textPrimary,
  height: 1.5,
);

const TextStyle bodySmall = TextStyle(
  fontSize: 14,
  fontWeight: FontWeight.normal,
  color: textSecondary,
  height: 1.5,
);

/// Label styles - Small text, captions
const TextStyle labelLarge = TextStyle(
  fontSize: 14,
  fontWeight: FontWeight.w500,
  color: textPrimary,
  height: 1.4,
);

const TextStyle labelMedium = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w500,
  color: textSecondary,
  height: 1.4,
);

const TextStyle labelSmall = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.normal,
  color: textMuted,
  height: 1.4,
  letterSpacing: 0.5,
);
