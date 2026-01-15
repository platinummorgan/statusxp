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
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Game cover image
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: game.cover.isNotEmpty && game.cover.startsWith('http')
                  ? Image.network(
                      game.cover,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildPlaceholderCover();
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          width: 80,
                          height: 80,
                          color: surfaceDark,
                          child: const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(accentSecondary),
                              ),
                            ),
                          ),
                        );
                      },
                    )
                  : _buildPlaceholderCover(),
            ),
            
            const SizedBox(width: 12),
            
            // Game info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Game name with platinum rarity
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          game.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: game.hasPlatinum ? accentPrimary : textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (game.platinumRarity != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00CED1).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: const Color(0xFF00CED1).withValues(alpha: 0.4),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            '${(game.platinumRarity ?? 0).toStringAsFixed(1)}%',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF00CED1),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  
                  // Platform badge (only show if we have valid platform data)
                  if (game.platform.isNotEmpty && game.platform.toLowerCase() != 'unknown') ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: surfaceDark,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            game.platform.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 9,
                              color: textSecondary,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),

                  // Trophy breakdown pills
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      _TrophyPill(
                        icon: Icons.circle,
                        count: game.bronzeTrophies,
                        color: const Color(0xFFCD7F32),
                      ),
                      _TrophyPill(
                        icon: Icons.circle,
                        count: game.silverTrophies,
                        color: const Color(0xFFC0C0C0),
                      ),
                      _TrophyPill(
                        icon: Icons.circle,
                        count: game.goldTrophies,
                        color: const Color(0xFFFFD700),
                      ),
                      if (game.hasPlatinum)
                        _TrophyPill(
                          icon: Icons.emoji_events,
                          count: game.platinumTrophies,
                          color: accentPrimary,
                          label: 'PLAT',
                        ),
                    ],
                  ),
                  
                  const SizedBox(height: 8),

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
                            '${game.earnedTrophies}/${game.totalTrophies}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 11,
                              color: textSecondary,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: game.hasPlatinum 
                                ? accentPrimary.withValues(alpha: 0.15)
                                : surfaceDark,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: game.hasPlatinum
                                  ? accentPrimary.withValues(alpha: 0.3)
                                  : surfaceDark,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              '${progress.toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 10,
                                color: game.hasPlatinum ? accentPrimary : textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
  
  /// Builds a placeholder cover when image is unavailable
  Widget _buildPlaceholderCover() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: surfaceDark,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.videogame_asset,
        color: textSecondary.withValues(alpha: 0.3),
        size: 32,
      ),
    );
  }
}

class _TrophyPill extends StatelessWidget {
  final IconData icon;
  final int count;
  final Color color;
  final String? label;

  const _TrophyPill({
    required this.icon,
    required this.count,
    required this.color,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: color.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            label ?? count.toString(),
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
