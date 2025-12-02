import 'package:flutter/material.dart';

/// SectionHeader - Reusable section header widget
/// 
/// A simple, consistent header for separating content sections.
/// Provides standard spacing and typography.
class SectionHeader extends StatelessWidget {
  /// The header text to display
  final String title;

  /// Optional action widget (e.g., "See All" button)
  final Widget? action;

  const SectionHeader({
    super.key,
    required this.title,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(
        top: 24,
        bottom: 12,
        left: 16,
        right: 16,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: theme.textTheme.headlineMedium,
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}
