import 'package:flutter/material.dart';
import 'package:statusxp/theme/colors.dart';

/// A hero card displaying the user's platinum trophy count as the main focal point.
/// 
/// Features a gradient background and large, prominent display of platinum count
/// to emphasize it as the ultimate achievement metric.
class PlatinumHeroCard extends StatelessWidget {
  /// The number of platinum trophies earned
  final int platinumCount;
  
  /// The total number of games tracked (optional, for completion percentage)
  final int? totalGames;

  const PlatinumHeroCard({
    super.key,
    required this.platinumCount,
    this.totalGames,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accentPrimary.withValues(alpha: 0.2),
            accentSecondary.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accentPrimary.withValues(alpha: 0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: accentPrimary.withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Trophy icon and label
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentPrimary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.emoji_events,
                  color: accentPrimary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Platinum Trophies',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: accentPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Your ultimate flex',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Platinum count - big and bold
          Text(
            platinumCount.toString(),
            style: theme.textTheme.displayLarge?.copyWith(
              fontSize: 72,
              color: accentPrimary,
              fontWeight: FontWeight.w900,
              height: 1,
              shadows: [
                Shadow(
                  color: accentPrimary.withValues(alpha: 0.5),
                  blurRadius: 20,
                ),
              ],
            ),
          ),
          
          // Platinum rate stat
          if (totalGames != null && (totalGames ?? 0) > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: surfaceDark.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Platinum rate',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: textSecondary,
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    '${((platinumCount / (totalGames ?? 1)) * 100).toStringAsFixed(1)}% of games platinumed',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: accentPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
