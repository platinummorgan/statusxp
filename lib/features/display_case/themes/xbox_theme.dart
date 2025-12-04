import 'package:flutter/material.dart';
import 'package:statusxp/features/display_case/themes/display_case_theme.dart';

/// Xbox-themed Display Case
/// 
/// Green/black color scheme with Xbox achievement aesthetics
/// TODO: Implement Xbox theme colors and styling when Xbox integration is added
class XboxTheme extends DisplayCaseTheme {
  @override
  String get id => 'xbox';
  
  @override
  String get name => 'Xbox';
  
  @override
  Color get backgroundColor => const Color(0xFF0E1E0E); // Dark green-black
  
  @override
  Color get shelfColor => const Color(0x40FFFFFF);
  
  @override
  Color get shelfAccentColor => const Color(0xFF107C10); // Xbox Green
  
  @override
  Color get primaryAccent => const Color(0xFF107C10); // Xbox Green
  
  @override
  Color get secondaryAccent => const Color(0xFF000000); // Black
  
  @override
  Color get textColor => Colors.white;
  
  @override
  Color get shelfShadowColor => const Color(0x80000000);
  
  @override
  Color get slotHighlightColor => const Color(0x40107C10);
  
  @override
  LinearGradient get backgroundGradient => const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF0E1E0E),
      Color(0xFF1A2E1A),
      Color(0xFF0E1E0E),
    ],
    stops: [0.0, 0.5, 1.0],
  );
  
  @override
  Color getTierColor(String tier) {
    // TODO: Map Xbox achievement tiers when Xbox integration is added
    switch (tier.toLowerCase()) {
      case 'platinum': // Xbox equivalent
        return const Color(0xFF9B59B6); // Purple for rare achievements
      case 'gold':
        return const Color(0xFFFFD700);
      case 'silver':
        return const Color(0xFFC0C0C0);
      case 'bronze':
        return const Color(0xFFCD7F32);
      default:
        return Colors.white70;
    }
  }
  
  @override
  BoxDecoration getBackgroundDecoration() {
    return BoxDecoration(
      gradient: backgroundGradient,
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
