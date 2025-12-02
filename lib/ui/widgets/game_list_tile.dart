import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:statusxp/domain/game.dart';
import 'package:statusxp/theme/colors.dart';

/// GameListTile - Reusable widget for displaying a game in a list
/// 
/// Shows game name, platform, trophy progress, and platinum indicator.
/// Tappable to open the game detail screen for editing.
class GameListTile extends StatelessWidget {
  final Game game;
  final VoidCallback? onTap;

  const GameListTile({
    super.key,
    required this.game,
    this.onTap,
  });

  /// Formats completion percentage with proper clamping
  String _formatCompletionPercent(double value) {
    final clamped = value.clamp(0, 100);
    return '${clamped.toStringAsFixed(1)}% Complete';
  }

  /// Formats rarity percentage with proper label
  String _formatRarity(double value) {
    return 'Rarest: ${value.toStringAsFixed(1)}% of players';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = game.completionPercent;

    return InkWell(
      onTap: () {
        if (onTap != null) {
          HapticFeedback.lightImpact();
          onTap!();
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: surfaceLight,
          borderRadius: BorderRadius.circular(16),
          border: game.hasPlatinum
              ? Border.all(
                  color: accentPrimary.withValues(alpha: 0.3),
                  width: 2,
                )
              : null,
          boxShadow: game.hasPlatinum
              ? [
                  BoxShadow(
                    color: accentPrimary.withValues(alpha: 0.15),
                  blurRadius: 8,
                  spreadRadius: 0,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Game name and platform
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        game.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: game.hasPlatinum ? accentPrimary : textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: surfaceDark,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              game.platform,
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: 10,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                          if (game.hasPlatinum) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: accentPrimary.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: accentPrimary.withValues(alpha: 0.5),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.emoji_events,
                                    size: 10,
                                    color: accentPrimary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'PLATINUM',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontSize: 10,
                                      color: accentPrimary,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Trophy count
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${game.earnedTrophies}/${game.totalTrophies}',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: accentSecondary,
                      ),
                    ),
                    Text(
                      'TROPHIES',
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Progress bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress / 100,
                    minHeight: 6,
                    backgroundColor: surfaceDark,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      game.hasPlatinum ? accentPrimary : accentSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatCompletionPercent(progress),
                      style: theme.textTheme.labelSmall,
                    ),
                    if (game.rarityPercent > 0)
                      Text(
                        _formatRarity(game.rarityPercent),
                        style: theme.textTheme.labelSmall,
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    );
  }
}
