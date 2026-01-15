import 'package:flutter/material.dart';
import 'package:statusxp/theme/colors.dart';

/// A compact chip displaying a trophy tier count in the breakdown row.
/// 
/// Used in the dashboard to show bronze, silver, gold, platinum, and total trophy counts
/// in a horizontal HUD-style strip.
class TrophyBreakdownChip extends StatelessWidget {
  /// The label for this trophy tier (e.g., 'BRONZE', 'SILVER', etc.)
  final String label;
  
  /// The count of trophies for this tier
  final int count;
  
  /// The accent color for this trophy tier
  final Color accentColor;
  
  /// Whether to show a subtle glow effect
  final bool showGlow;
  
  /// Total trophies for calculating proportion (optional, for mini-bar)
  final int? totalTrophies;

  const TrophyBreakdownChip({
    super.key,
    required this.label,
    required this.count,
    required this.accentColor,
    this.showGlow = false,
    this.totalTrophies,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final proportion = totalTrophies != null && (totalTrophies ?? 0) > 0
        ? count / (totalTrophies ?? 1)
        : 0.0;
    
    return Container(
      height: 100,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: showGlow
            ? [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.3),
                  blurRadius: 12,
                  spreadRadius: 0,
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Label (small, uppercase)
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: textSecondary,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
              fontSize: 9,
            ),
          ),
          
          // Count (big and bold)
          Text(
            count.toString(),
            style: theme.textTheme.headlineMedium?.copyWith(
              color: textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 28,
              height: 1,
            ),
          ),
          
          // Mini progress bar (proportional to total)
          if (totalTrophies != null && (totalTrophies ?? 0) > 0)
            Container(
              height: 3,
              decoration: BoxDecoration(
                color: surfaceDark,
                borderRadius: BorderRadius.circular(2),
              ),
              child: FractionallySizedBox(
                widthFactor: proportion.clamp(0.0, 1.0),
                alignment: Alignment.centerLeft,
                child: Container(
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            )
          else
            const SizedBox(height: 3),
        ],
      ),
    );
  }
}
