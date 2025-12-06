import 'package:flutter/material.dart';

/// Cyberpunk/HUD theme colors and styles for StatusXP
/// 
/// Provides neon accent colors, glassmorphic effects, and futuristic styling
class CyberpunkTheme {
  // Neon accent colors
  static const Color neonCyan = Color(0xFF00F0FF);
  static const Color neonPink = Color(0xFFFF006E);
  static const Color neonPurple = Color(0xFFB026FF);
  static const Color neonGreen = Color(0xFF39FF14);
  static const Color neonOrange = Color(0xFFFF6B00);
  
  // Glass/frosted backgrounds
  static const Color glassLight = Color(0x1AFFFFFF);
  static const Color glassMedium = Color(0x26FFFFFF);
  static const Color glassDark = Color(0x0DFFFFFF);
  
  // Dark base colors
  static const Color deepBlack = Color(0xFF0A0E27);
  static const Color voidBlack = Color(0xFF050814);
  
  // Trophy tier neon variants
  static const Color bronzeNeon = Color(0xFFFF8C42);
  static const Color silverNeon = Color(0xFFE8E8E8);
  static const Color goldNeon = Color(0xFFFFD700);
  static const Color platinumNeon = Color(0xFF00F0FF);
  
  /// Glassmorphic container decoration
  static BoxDecoration glassBox({
    Color? borderColor,
    double borderWidth = 1,
    double borderRadius = 16,
    bool showGlow = false,
  }) {
    return BoxDecoration(
      color: glassLight,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor ?? neonCyan.withOpacity(0.3),
        width: borderWidth,
      ),
      boxShadow: showGlow
          ? [
              BoxShadow(
                color: (borderColor ?? neonCyan).withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: 0,
              ),
            ]
          : null,
    );
  }
  
  /// Neon text glow effect
  static List<Shadow> neonGlow({
    Color color = neonCyan,
    double blurRadius = 8,
  }) {
    return [
      Shadow(
        color: color.withOpacity(0.8),
        blurRadius: blurRadius,
      ),
      Shadow(
        color: color.withOpacity(0.4),
        blurRadius: blurRadius * 2,
      ),
    ];
  }
  
  /// Gradient background for dashboard
  static BoxDecoration gradientBackground() {
    return const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          voidBlack,
          deepBlack,
          Color(0xFF1A1F3A),
        ],
        stops: [0.0, 0.5, 1.0],
      ),
    );
  }
}
