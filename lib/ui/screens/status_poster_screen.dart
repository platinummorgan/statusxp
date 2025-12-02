import 'package:flutter/material.dart';
import 'package:statusxp/data/sample_data.dart';
import 'package:statusxp/theme/colors.dart';

/// Status Poster Screen
/// 
/// Displays a shareable visual card showcasing gaming achievements.
/// This is a preview/placeholder for the future export functionality.
class StatusPosterScreen extends StatelessWidget {
  const StatusPosterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Status Poster'),
        actions: [
          // TODO: Add export/share button in future milestone
          IconButton(
            onPressed: () {
              // Placeholder for future export functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Export feature coming soon!'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            icon: const Icon(Icons.share),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              backgroundDark,
              surfaceDark,
              accentPrimary.withValues(alpha: 0.1),
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                decoration: BoxDecoration(
                  color: surfaceLight,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: accentPrimary.withValues(alpha: 0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accentPrimary.withValues(alpha: 0.3),
                      blurRadius: 32,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Profile header
                    Text(
                      'StatusXP',
                      style: theme.textTheme.labelSmall?.copyWith(
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      sampleStats.username,
                      style: theme.textTheme.displayLarge?.copyWith(
                        color: accentPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 32),

                    // Main stats grid
                    Row(
                      children: [
                        Expanded(
                          child: _PosterStatItem(
                            label: 'PLATINUMS',
                            value: '${sampleStats.totalPlatinums}',
                            color: accentPrimary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _PosterStatItem(
                            label: 'GAMES',
                            value: '${sampleStats.totalGamesTracked}',
                            color: accentSecondary,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    _PosterStatItem(
                      label: 'TOTAL TROPHIES',
                      value: '${sampleStats.totalTrophies}',
                      color: accentSuccess,
                    ),

                    const SizedBox(height: 32),

                    // Divider
                    Container(
                      height: 1,
                      color: surfaceDark,
                    ),

                    const SizedBox(height: 24),

                    // Achievement highlights
                    _PosterHighlight(
                      icon: Icons.emoji_events,
                      label: 'Hardest Platinum',
                      value: sampleStats.hardestPlatGame,
                    ),

                    const SizedBox(height: 16),

                    _PosterHighlight(
                      icon: Icons.stars,
                      label: 'Rarest Trophy',
                      value: sampleStats.rarestTrophyName,
                      subtitle: '${sampleStats.rarestTrophyRarity}% rarity',
                    ),

                    const SizedBox(height: 24),

                    // Footer
                    Text(
                      'Level up your gaming identity',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Poster stat item widget
class _PosterStatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _PosterStatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.displayMedium?.copyWith(
              color: color,
              fontSize: 28,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Poster highlight widget
class _PosterHighlight extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;

  const _PosterHighlight({
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(
          icon,
          color: accentWarning,
          size: 32,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall,
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: accentWarning,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
