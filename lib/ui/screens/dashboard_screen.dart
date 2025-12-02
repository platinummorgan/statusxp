import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/theme/colors.dart';
import 'package:statusxp/ui/widgets/stat_card.dart';
import 'package:statusxp/ui/widgets/section_header.dart';

/// Dashboard Screen - Main home screen
/// 
/// Displays user stats overview and navigation to other screens.
/// This is the entry point of the app.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    // Immediately show content (animation happens via setState)
    _isVisible = true;
    
    // Trigger rebuild after first frame for smooth enter animation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _showAboutDialog(BuildContext context) {
    HapticFeedback.lightImpact();
    showAboutDialog(
      context: context,
      applicationName: 'StatusXP',
      applicationVersion: '0.1.0 (Prototype)',
      applicationLegalese: 'Your gaming identity, leveled up.\n\nThis is a local prototype using sample data only. Platform integrations (PSN, Xbox, Steam, etc.) are planned for future releases.',
      children: [
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userStatsAsync = ref.watch(userStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('StatusXP'),
        centerTitle: false,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'about') {
                _showAboutDialog(context);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'about',
                child: Text('About StatusXP'),
              ),
            ],
          ),
        ],
      ),
      body: userStatsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error loading stats: $error'),
        ),
        data: (stats) => SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
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
                      stats.username,
                      style: theme.textTheme.displayMedium?.copyWith(
                        color: accentPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: surfaceLight,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: accentPrimary.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'Demo Mode · Sample data only',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Stats section
              const SectionHeader(title: 'Your Stats'),
              AnimatedOpacity(
                opacity: _isVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOut,
                child: AnimatedSlide(
                  offset: _isVisible ? Offset.zero : const Offset(0, 0.05),
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOut,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                  children: [
                    // Top stat - Platinums (most important)
                    StatCard(
                      title: 'TOTAL PLATINUMS',
                      value: '${stats.totalPlatinums}',
                      accentColor: accentPrimary,
                    ),
                    const SizedBox(height: 12),

                    // Two-column layout for secondary stats
                    Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            title: 'GAMES',
                            value: '${stats.totalGamesTracked}',
                            showGlow: false,
                            accentColor: accentSecondary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: StatCard(
                            title: 'TROPHIES',
                            value: '${stats.totalTrophies}',
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
                      value: stats.hardestPlatGame,
                      showGlow: false,
                      accentColor: accentWarning,
                    ),
                    const SizedBox(height: 12),
                    StatCard(
                      title: 'RAREST TROPHY',
                      value: stats.rarestTrophyName,
                      subtitle: '${stats.rarestTrophyRarity}% of players',
                      showGlow: false,
                      accentColor: accentPrimary,
                    ),
                  ],
                ),
              ),
            ),
          ),

              // Navigation section
              const SectionHeader(title: 'Quick Actions'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        context.push('/games');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentPrimary,
                        foregroundColor: backgroundDark,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.emoji_events, color: backgroundDark),
                          const SizedBox(width: 8),
                          Text(
                            'View All Games',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: backgroundDark,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        context.push('/poster');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: surfaceLight,
                        foregroundColor: accentSecondary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: accentSecondary.withValues(alpha: 0.5),
                            width: 2,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.image, color: accentSecondary),
                          const SizedBox(width: 8),
                          Text(
                            'View Status Poster',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: accentSecondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
