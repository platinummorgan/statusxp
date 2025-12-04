import 'package:flutter/material.dart';
import 'package:statusxp/features/display_case/themes/display_case_theme.dart';

/// PlayStation-themed Display Case
/// 
/// Blue/silver color scheme with PS trophy aesthetics
class PlayStationTheme extends DisplayCaseTheme {
  @override
  String get id => 'playstation';
  
  @override
  String get name => 'PlayStation';
  
  @override
  Color get backgroundColor => const Color(0xFF1A2332);
  
  @override
  Color get shelfColor => const Color(0x40FFFFFF); // Translucent white for glass
  
  @override
  Color get shelfAccentColor => const Color(0xFF4A90E2); // PS Blue
  
  @override
  Color get primaryAccent => const Color(0xFF00A8E1); // Bright PS Blue
  
  @override
  Color get secondaryAccent => const Color(0xFFFFFFFF); // Silver/White
  
  @override
  Color get textColor => Colors.white;
  
  @override
  Color get shelfShadowColor => const Color(0x80000000);
  
  @override
  Color get slotHighlightColor => const Color(0x4000A8E1);
  
  @override
  LinearGradient get backgroundGradient => const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF1A2332), // Dark blue-grey
      Color(0xFF2C3E50), // Slightly lighter blue-grey
      Color(0xFF1A2332), // Back to dark
    ],
    stops: [0.0, 0.5, 1.0],
  );
  
  @override
  Color getTierColor(String tier) {
    switch (tier.toLowerCase()) {
      case 'platinum':
        return const Color(0xFF7DD3F0); // Bright cyan/platinum
      case 'gold':
        return const Color(0xFFFFD700); // Gold
      case 'silver':
        return const Color(0xFFC0C0C0); // Silver
      case 'bronze':
        return const Color(0xFFCD7F32); // Bronze
      default:
        return Colors.white70;
    }
  }
  
  @override
  BoxDecoration getBackgroundDecoration() {
    return BoxDecoration(
      gradient: backgroundGradient,
      // Can add texture/pattern image here in the future
    );
  }
  
  @override
  BoxDecoration getShelfDecoration() {
    return BoxDecoration(
      color: shelfColor,
      border: Border(
        top: BorderSide(
          color: shelfAccentColor.withOpacity(0.3),
          width: 2,
        ),
        bottom: BorderSide(
          color: shelfAccentColor.withOpacity(0.1),
          width: 1,
        ),
      ),
      boxShadow: [
        BoxShadow(
          color: shelfShadowColor,
          offset: const Offset(0, 4),
          blurRadius: 8,
        ),
        BoxShadow(
          color: shelfAccentColor.withOpacity(0.1),
          offset: const Offset(0, -1),
          blurRadius: 4,
        ),
      ],
    );
  }
  
  @override
  List<Shadow> textGlow({Color? color, double blurRadius = 6}) {
    final glowColor = color ?? primaryAccent;
    return [
      Shadow(
        color: glowColor.withOpacity(0.8),
        blurRadius: blurRadius,
      ),
      Shadow(
        color: glowColor.withOpacity(0.4),
        blurRadius: blurRadius * 2,
      ),
    ];
  }
}
