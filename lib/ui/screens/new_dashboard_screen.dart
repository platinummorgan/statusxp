import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:statusxp/domain/dashboard_stats.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/theme/cyberpunk_theme.dart';
import 'package:statusxp/ui/widgets/psn_avatar.dart';

/// New Dashboard Screen - Cross-Platform Overview
///
/// Displays StatusXP unified score and platform-specific stats
class NewDashboardScreen extends ConsumerStatefulWidget {
  const NewDashboardScreen({super.key});

  @override
  ConsumerState<NewDashboardScreen> createState() => _NewDashboardScreenState();
}

class _NewDashboardScreenState extends ConsumerState<NewDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dashboardStatsAsync = ref.watch(dashboardStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'StatusXP',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
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
      body: dashboardStatsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading dashboard: $error'),
            ],
          ),
        ),
        data: (stats) => stats == null
            ? const Center(child: Text('No data available'))
            : _buildDashboardContent(context, theme, stats),
      ),
    );
  }

  Widget _buildDashboardContent(
    BuildContext context,
    ThemeData theme,
    DashboardStats stats,
  ) {
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
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Username header with avatar
                  _buildUserHeader(context, theme, stats),

                  const SizedBox(height: 32),

                  // StatusXP large circle (center top)
                  _buildStatusXPCircle(stats.totalStatusXP),

                  const SizedBox(height: 32),

                  // Platform circles row
                  _buildPlatformCircles(stats),

                  const SizedBox(height: 40),

                  // Quick Actions
                  _buildQuickActions(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserHeader(
    BuildContext context,
    ThemeData theme,
    DashboardStats stats,
  ) {
    return Row(
      children: [
        // Platform Avatar (only show PS Plus badge when platform is PSN)
        PsnAvatar(
          avatarUrl: stats.avatarUrl,
          isPsPlus: stats.displayPlatform == 'psn' ? stats.isPsPlus : false,
          size: 64,
          borderColor: CyberpunkTheme.neonCyan,
        ),

        const SizedBox(width: 16),

        // Username with platform indicator
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stats.displayName,
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
                  ],
                ),
              ),
              const SizedBox(height: 6),
              // Platform indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _getPlatformColor(
                    stats.displayPlatform,
                  ).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: _getPlatformColor(stats.displayPlatform),
                    width: 1,
                  ),
                ),
                child: Text(
                  stats.displayPlatform.toUpperCase(),
                  style: TextStyle(
                    color: _getPlatformColor(stats.displayPlatform),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusXPCircle(int totalStatusXP) {
    return Container(
      width: 220,
      height: 220,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: CyberpunkTheme.neonPurple, width: 4),
        boxShadow: [
          BoxShadow(
            color: CyberpunkTheme.neonPurple.withOpacity(0.5),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'StatusXP',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatNumber(totalStatusXP),
            style: TextStyle(
              color: CyberpunkTheme.neonPurple,
              fontSize: 48,
              fontWeight: FontWeight.w900,
              height: 1.0,
              shadows: [
                ...CyberpunkTheme.neonGlow(
                  color: CyberpunkTheme.neonPurple,
                  blurRadius: 12,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformCircles(DashboardStats stats) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // PSN Circle
        _buildPlatformCircle(
          label: 'Platinums',
          value: stats.psnStats.platinums.toString(),
          subtitle: '${stats.psnStats.gamesCount} Games',
          bottomLabel:
              '${stats.psnStats.averagePerGame.toStringAsFixed(0)} AVG/GAME',
          color: const Color(0xFF00A8E1), // PlayStation Blue
        ),

        // Xbox Circle
        _buildPlatformCircle(
          label: 'Xbox Achievs',
          value: stats.xboxStats.achievementsUnlocked.toString(),
          subtitle: '${stats.xboxStats.gamesCount} Games',
          bottomLabel:
              '${stats.xboxStats.averagePerGame.toStringAsFixed(0)} AVG/GAME',
          color: const Color(0xFF107C10), // Xbox Green
        ),

        // Steam Circle
        _buildPlatformCircle(
          label: 'Steam Achievs',
          value: stats.steamStats.achievementsUnlocked.toString(),
          subtitle: '${stats.steamStats.gamesCount} Games',
          bottomLabel:
              '${stats.steamStats.averagePerGame.toStringAsFixed(0)} AVG/GAME',
          color: const Color(0xFF66C0F4), // Steam Blue
        ),
      ],
    );
  }

  Widget _buildPlatformCircle({
    required String label,
    required String value,
    required String subtitle,
    required String bottomLabel,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 3),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 15,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                  shadows: [
                    Shadow(color: color.withOpacity(0.6), blurRadius: 8),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // AVG/GAME label below circle
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withOpacity(0.3), width: 1),
          ),
          child: Column(
            children: [
              Text(
                'AVG/GAME',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                bottomLabel.split(' ')[0], // Just the number
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'QUICK ACTIONS',
          style: TextStyle(
            color: Colors.white.withOpacity(0.55),
            letterSpacing: 2.5,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),

        const SizedBox(height: 16),

        _buildActionButton(
          label: 'View Games',
          icon: Icons.videogame_asset,
          onTap: () {
            HapticFeedback.lightImpact();
            context.push('/unified-games');
          },
        ),

        const SizedBox(height: 12),

        _buildActionButton(
          label: 'Status Poster',
          icon: Icons.image,
          onTap: () {
            HapticFeedback.lightImpact();
            context.push('/poster');
          },
        ),

        const SizedBox(height: 12),

        _buildActionButton(
          label: 'Flex Room',
          icon: Icons.emoji_events,
          onTap: () {
            HapticFeedback.lightImpact();
            context.push('/flex-room');
          },
        ),

        const SizedBox(height: 12),

        _buildActionButton(
          label: 'Achievements',
          icon: Icons.stars,
          onTap: () {
            HapticFeedback.lightImpact();
            context.push('/achievements');
          },
        ),

        const SizedBox(height: 12),

        _buildActionButton(
          label: 'Leaderboards',
          icon: Icons.leaderboard,
          onTap: () {
            HapticFeedback.lightImpact();
            context.push('/leaderboards');
          },
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: CyberpunkTheme.glassLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: CyberpunkTheme.neonCyan.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: CyberpunkTheme.neonCyan, size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios,
              color: CyberpunkTheme.neonCyan.withOpacity(0.5),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Color _getPlatformColor(String platform) {
    switch (platform) {
      case 'psn':
        return const Color(0xFF00A8E1);
      case 'xbox':
        return const Color(0xFF107C10);
      case 'steam':
        return const Color(0xFF66C0F4);
      default:
        return CyberpunkTheme.neonCyan;
    }
  }

  String _formatNumber(int number) {
    // Show full number with comma separators
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}
