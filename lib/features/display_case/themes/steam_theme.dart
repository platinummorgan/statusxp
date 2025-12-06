import 'package:flutter/material.dart';
import 'package:statusxp/features/display_case/themes/display_case_theme.dart';

/// Steam-themed Display Case
///
/// Clean, neutral theme for Steam achievements.
/// TODO: Implement Steam theme styling when Steam integration is added.
class SteamTheme extends DisplayCaseTheme {
  @override
  String get id => 'steam';

  @override
  String get name => 'Steam';

  @override
  Color get backgroundColor => const Color(0xFF1B2838); // Steam dark blue

  @override
  Color get shelfColor => const Color(0x40FFFFFF);

  @override
  Color get shelfAccentColor => const Color(0xFF66C0F4); // Steam blue

  @override
  Color get primaryAccent => const Color(0xFF66C0F4); // Steam blue

  @override
  Color get secondaryAccent => const Color(0xFFC7D5E0); // Light grey

  @override
  Color get textColor => Colors.white;

  @override
  Color get shelfShadowColor => const Color(0x80000000);

  @override
  Color get slotHighlightColor => const Color(0x4066C0F4);

  @override
  LinearGradient get backgroundGradient => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF1B2838),
          Color(0xFF2A475E),
          Color(0xFF1B2838),
        ],
        stops: [0.0, 0.5, 1.0],
      );

  @override
  Color getTierColor(String tier) {
    // TODO: Map Steam achievement rarities when Steam integration is added.
    // Steam doesn't have tiers, but we can use rarity-like colors.
    switch (tier.toLowerCase()) {
      case 'platinum': // Rare achievements
        return const Color(0xFFB4A7D6); // Purple
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
