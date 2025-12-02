import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:statusxp/data/sample_data.dart';
import 'package:statusxp/theme/colors.dart';
import 'package:statusxp/ui/widgets/stat_card.dart';
import 'package:statusxp/ui/widgets/section_header.dart';

/// Dashboard Screen - Main home screen
/// 
/// Displays user stats overview and navigation to other screens.
/// This is the entry point of the app.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('StatusXP'),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome header
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back,',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    sampleStats.username,
                    style: theme.textTheme.displayMedium?.copyWith(
                      color: accentPrimary,
                    ),
                  ),
                ],
              ),
            ),

            // Stats section
            const SectionHeader(title: 'Your Stats'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  // Top stat - Platinums (most important)
                  StatCard(
                    title: 'TOTAL PLATINUMS',
                    value: '${sampleStats.totalPlatinums}',
                    accentColor: accentPrimary,
                  ),
                  const SizedBox(height: 12),

                  // Two-column layout for secondary stats
                  Row(
                    children: [
                      Expanded(
                        child: StatCard(
                          title: 'GAMES',
                          value: '${sampleStats.totalGamesTracked}',
                          showGlow: false,
                          accentColor: accentSecondary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatCard(
                          title: 'TROPHIES',
                          value: '${sampleStats.totalTrophies}',
                          showGlow: false,
                          accentColor: accentSuccess,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Achievement highlights
                  StatCard(
                    title: 'HARDEST PLATINUM',
                    value: sampleStats.hardestPlatGame,
                    showGlow: false,
                    accentColor: accentWarning,
                  ),
                  const SizedBox(height: 12),
                  StatCard(
                    title: 'RAREST TROPHY',
                    value: sampleStats.rarestTrophyName,
                    subtitle: '${sampleStats.rarestTrophyRarity}% of players',
                    showGlow: false,
                    accentColor: accentPrimary,
                  ),
                ],
              ),
            ),

            // Navigation section
            const SectionHeader(title: 'Quick Actions'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    onPressed: () => context.go('/games'),
                    icon: const Icon(Icons.videogame_asset),
                    label: const Text('View All Games'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/poster'),
                    icon: const Icon(Icons.photo),
                    label: const Text('View Status Poster'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
