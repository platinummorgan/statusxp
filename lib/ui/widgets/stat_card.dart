import 'package:flutter/material.dart';
import 'package:statusxp/theme/colors.dart';

/// StatCard - Reusable stats display widget
/// 
/// A modern card widget for displaying game statistics with optional neon glow.
/// Features rounded corners and a clean, gaming-inspired aesthetic.
class StatCard extends StatelessWidget {
  /// The title/label for the stat (e.g., "Total Platinums")
  final String title;

  /// The main value to display (e.g., "7")
  final String value;

  /// Optional subtitle text for additional context
  final String? subtitle;

  /// Whether to show the neon glow effect
  final bool showGlow;

  /// Custom accent color (defaults to accentPrimary)
  final Color? accentColor;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.showGlow = true,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final glowColor = accentColor ?? accentPrimary;

    return Container(
      decoration: BoxDecoration(
        color: surfaceLight,
        borderRadius: BorderRadius.circular(16),
        boxShadow: showGlow
            ? [
                BoxShadow(
                  color: glowColor.withValues(alpha: 0.2),
                  blurRadius: 12,
                  spreadRadius: 0,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title
          Text(
            title,
            style: theme.textTheme.labelSmall?.copyWith(
              color: textSecondary,
              letterSpacing: 1,
              textBaseline: TextBaseline.alphabetic,
            ),
          ),
          const SizedBox(height: 8),
          // Value
          Text(
            value,
            style: theme.textTheme.displayMedium?.copyWith(
              color: glowColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          // Optional subtitle
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
