import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:statusxp/domain/user_stats.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/theme/cyberpunk_theme.dart';
import 'package:statusxp/ui/widgets/glass_panel.dart';
import 'package:statusxp/ui/widgets/neon_action_chip.dart';
import 'package:statusxp/ui/widgets/neon_ring.dart';
import 'package:statusxp/ui/widgets/psn_avatar.dart';

/// Dashboard Screen - Cyberpunk HUD Main Screen
/// 
/// Displays user stats in a futuristic glassmorphic layout with neon accents
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userStatsAsync = ref.watch(userStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: userStatsAsync.maybeWhen(
          data: (stats) => Text(
            stats.username.isNotEmpty 
              ? stats.username
              : 'StatusXP',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          orElse: () => const Text('StatusXP'),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () {
              context.push('/settings');
            },
          ),
        ],
      ),
      body: userStatsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading stats: $error'),
            ],
          ),
        ),
        data: (stats) => _buildDashboardContent(context, theme, stats),
      ),
    );
  }

  Widget _buildDashboardContent(BuildContext context, ThemeData theme, UserStats stats) {
    final platinumRate = stats.totalGamesTracked > 0 
        ? stats.platinumTrophies / stats.totalGamesTracked 
        : 0.0;
    
    return Container(
      decoration: CyberpunkTheme.gradientBackground(),
      child: RefreshIndicator(
        onRefresh: () async {
          ref.refreshCoreData();
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar + Username section
                  Row(
                    children: [
                      // PSN Avatar with Plus badge
                      PsnAvatar(
                        avatarUrl: stats.avatarUrl,
                        isPsPlus: stats.isPsPlus,
                        size: 64,
                        borderColor: CyberpunkTheme.neonCyan,
                      ),
                      
                      const SizedBox(width: 16),
                      
                      // Username with neon underline
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stats.username,
                              style: theme.textTheme.headlineMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                                fontSize: 28,
                                height: 1.1,
                                shadows: [
                                  ...CyberpunkTheme.neonGlow(
                                    color: CyberpunkTheme.neonCyan,
                                    blurRadius: 6,
                                  ),
                                  Shadow(
                                    color: CyberpunkTheme.neonCyan.withOpacity(0.2),
                                    blurRadius: 16,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              width: 70,
                              height: 3,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    CyberpunkTheme.neonCyan,
                                    CyberpunkTheme.neonCyan.withOpacity(0),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: CyberpunkTheme.neonCyan.withOpacity(0.7),
                                    blurRadius: 10,
                                  ),
                                  BoxShadow(
                                    color: CyberpunkTheme.neonCyan.withOpacity(0.3),
                                    blurRadius: 20,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 18),
                  
                  // Trophy tier counts (bronze, silver, gold only)
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      _TrophyCount(
                        icon: Icons.emoji_events,
                        count: stats.bronzeTrophies,
                        color: CyberpunkTheme.bronzeNeon,
                      ),
                      _TrophyCount(
                        icon: Icons.emoji_events,
                        count: stats.silverTrophies,
                        color: CyberpunkTheme.silverNeon,
                      ),
                      _TrophyCount(
                        icon: Icons.emoji_events,
                        count: stats.goldTrophies,
                        color: CyberpunkTheme.goldNeon,
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 36),
                  
                  // Platinum Dominance Ring
                  Center(
                    child: NeonRing(
                      value: stats.platinumTrophies,
                      label: 'Platinums',
                      progress: platinumRate.clamp(0.0, 1.0),
                      subtitle: '${(platinumRate * 100).toStringAsFixed(1)}% completion rate',
                      color: CyberpunkTheme.platinumNeon,
                      size: 230,
                    ),
                  ),
                  
                  const SizedBox(height: 36),
                  
                  // Futuristic Stats Grid
                  Row(
                    children: [
                      Expanded(
                        child: GlassPanel(
                          padding: const EdgeInsets.all(14),
                          borderColor: CyberpunkTheme.neonPurple,
                          child: GlassStat(
                            label: 'Games',
                            value: '${stats.totalGamesTracked}',
                            accentColor: CyberpunkTheme.neonPurple,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GlassPanel(
                          padding: const EdgeInsets.all(14),
                          borderColor: CyberpunkTheme.neonGreen,
                          child: GlassStat(
                            label: 'Avg/Game',
                            value: stats.totalGamesTracked > 0
                                ? (stats.totalTrophies / stats.totalGamesTracked).toStringAsFixed(0)
                                : '0',
                            accentColor: CyberpunkTheme.neonGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  GlassPanel(
                    padding: const EdgeInsets.all(14),
                    borderColor: CyberpunkTheme.neonCyan,
                    child: GlassStat(
                      label: 'Total Trophies',
                      value: '${stats.totalTrophies}',
                      accentColor: CyberpunkTheme.neonCyan,
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Achievement highlights
                  if (stats.hardestPlatGame != 'None' || stats.rarestTrophyName != 'None') ...[
                    Text(
                      'ACHIEVEMENTS',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.white.withOpacity(0.55),
                        letterSpacing: 2.5,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                  
                  if (stats.hardestPlatGame != 'None') ...[
                    GlassPanel(
                      borderColor: CyberpunkTheme.neonOrange,
                      child: Row(
                        children: [
                          const Icon(
                            Icons.emoji_events,
                            color: CyberpunkTheme.neonOrange,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'HARDEST PLATINUM',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: Colors.white.withOpacity(0.5),
                                    letterSpacing: 1,
                                    fontSize: 9,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  stats.hardestPlatGame,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: CyberpunkTheme.neonOrange,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  
                  if (stats.rarestTrophyName != 'None') ...[
                    GlassPanel(
                      borderColor: CyberpunkTheme.neonPink,
                      child: Row(
                        children: [
                          const Icon(
                            Icons.stars,
                            color: CyberpunkTheme.neonPink,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'RAREST TROPHY',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: Colors.white.withOpacity(0.5),
                                    letterSpacing: 1,
                                    fontSize: 9,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  stats.rarestTrophyName,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: CyberpunkTheme.neonPink,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${stats.rarestTrophyRarity}% rarity',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.white.withOpacity(0.4),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  
                  const SizedBox(height: 32),
                  
                  // Quick Actions
                  Text(
                    'QUICK ACTIONS',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: Colors.white.withOpacity(0.55),
                      letterSpacing: 2.5,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  
                  const SizedBox(height: 18),
                  
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      NeonActionChip(
                        label: 'Sync PSN',
                        icon: Icons.cloud_sync,
                        isPrimary: true,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          context.push('/psn-sync');
                        },
                      ),
                      NeonActionChip(
                        label: 'Display Case',
                        icon: Icons.emoji_events,
                        accentColor: CyberpunkTheme.neonPurple,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          context.push('/display-case');
                        },
                      ),
                      NeonActionChip(
                        label: 'Achievements',
                        icon: Icons.stars,
                        accentColor: CyberpunkTheme.neonOrange,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          context.push('/achievements');
                        },
                      ),
                      NeonActionChip(
                        label: 'View Games',
                        icon: Icons.videogame_asset,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          context.push('/games');
                        },
                      ),
                      NeonActionChip(
                        label: 'Status Poster',
                        icon: Icons.image,
                        accentColor: CyberpunkTheme.neonGreen,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          context.push('/poster');
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Individual trophy count with icon
class _TrophyCount extends StatelessWidget {
  final IconData icon;
  final int count;
  final Color color;
  
  const _TrophyCount({
    required this.icon,
    required this.count,
    required this.color,
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
      ],
    );
  }
}
