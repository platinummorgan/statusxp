import 'package:flutter/material.dart';
import 'package:statusxp/theme/cyberpunk_theme.dart';

/// Hero identity bar showing user info and inline trophy counts
/// 
/// Compact horizontal bar with username, rank, and trophy tier counts
class HeroIdentityBar extends StatelessWidget {
  final String username;
  final int bronze;
  final int silver;
  final int gold;
  final int platinum;
  final int total;
  
  const HeroIdentityBar({
    super.key,
    required this.username,
    required this.bronze,
    required this.silver,
    required this.gold,
    required this.platinum,
    required this.total,
  });
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Username with neon underline
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              username,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
                shadows: CyberpunkTheme.neonGlow(
                  color: CyberpunkTheme.neonCyan,
                  blurRadius: 4,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 60,
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    CyberpunkTheme.neonCyan,
                    CyberpunkTheme.neonCyan.withOpacity(0),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: CyberpunkTheme.neonCyan.withOpacity(0.6),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Inline trophy counts
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            _TrophyCount(
              icon: Icons.emoji_events,
              count: bronze,
              color: CyberpunkTheme.bronzeNeon,
            ),
            _TrophyCount(
              icon: Icons.emoji_events,
              count: silver,
              color: CyberpunkTheme.silverNeon,
            ),
            _TrophyCount(
              icon: Icons.emoji_events,
              count: gold,
              color: CyberpunkTheme.goldNeon,
            ),
            _TrophyCount(
              icon: Icons.emoji_events,
              count: platinum,
              color: CyberpunkTheme.platinumNeon,
            ),
            _TrophyCount(
              icon: Icons.stars,
              count: total,
              color: Colors.white.withOpacity(0.7),
              label: 'TOTAL',
            ),
          ],
        ),
      ],
    );
  }
}

/// Individual trophy count with icon
class _TrophyCount extends StatelessWidget {
  final IconData icon;
  final int count;
  final Color color;
  final String? label;
  
  const _TrophyCount({
    required this.icon,
    required this.count,
    required this.color,
    this.label,
  });
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          count.toString(),
          style: theme.textTheme.labelLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 13,
          ),
        ),
        if (label != null) ...[
          const SizedBox(width: 4),
          Text(
            label!,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color.withOpacity(0.6),
              fontSize: 9,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ],
    );
  }
}
