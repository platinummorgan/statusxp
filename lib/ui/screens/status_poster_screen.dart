import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:screenshot/screenshot.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/theme/colors.dart';

/// Status Poster Screen
/// 
/// Displays a shareable visual card showcasing gaming achievements.
/// This is a preview/placeholder for the future export functionality.
class StatusPosterScreen extends ConsumerStatefulWidget {
  const StatusPosterScreen({super.key});

  @override
  ConsumerState<StatusPosterScreen> createState() => _StatusPosterScreenState();
}

class _StatusPosterScreenState extends ConsumerState<StatusPosterScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();

  Future<void> _sharePoster() async {
    HapticFeedback.lightImpact();
    try {
      final bytes = await _screenshotController.capture();
      if (bytes == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not capture poster')),
          );
        }
        return;
      }

      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/statusxp_poster.png');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'My gaming status on StatusXP 🎮',
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to share poster')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userStatsAsync = ref.watch(userStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Status Poster'),
        leading: BackButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            context.pop();
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _sharePoster,
          ),
        ],
      ),
      body: userStatsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error loading stats: $error'),
        ),
        data: (stats) => Container(
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
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 420,
                  ),
                  child: Screenshot(
                    controller: _screenshotController,
                    child: Container(
                      decoration: BoxDecoration(
                        color: surfaceLight,
                        borderRadius: BorderRadius.circular(16),
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
                      padding: const EdgeInsets.all(24),
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
                        const SizedBox(height: 12),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            stats.username,
                            style: theme.textTheme.displayLarge?.copyWith(
                              color: accentPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.visible,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Main stats grid
                        Row(
                          children: [
                            Expanded(
                              child: _PosterStatItem(
                                label: 'PLATINUMS',
                                value: '${stats.totalPlatinums}',
                                color: accentPrimary,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _PosterStatItem(
                                label: 'GAMES',
                                value: '${stats.totalGamesTracked}',
                                color: accentSecondary,
                              ),
                            ),
                          ],
                        ),

                    const SizedBox(height: 16),

                    _PosterStatItem(
                      label: 'TOTAL TROPHIES',
                      value: '${stats.totalTrophies}',
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
                      value: stats.hardestPlatGame,
                    ),

                    const SizedBox(height: 16),

                    _PosterHighlight(
                      icon: Icons.stars,
                      label: 'Rarest Trophy',
                      value: stats.rarestTrophyName,
                      subtitle: '${stats.rarestTrophyRarity}% rarity',
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
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: textMuted,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.displayMedium?.copyWith(
              color: color,
              fontSize: 28,
              fontWeight: FontWeight.bold,
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
                style: theme.textTheme.labelSmall?.copyWith(
                  color: textMuted,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: accentWarning,
                  fontWeight: FontWeight.bold,
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
