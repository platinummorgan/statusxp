import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:statusxp/services/analytics_service.dart';
import 'package:statusxp/services/referral_service.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/theme/cyberpunk_theme.dart';

class FirstSyncResultsScreen extends ConsumerStatefulWidget {
  const FirstSyncResultsScreen({required this.platform, super.key});

  final String platform;

  @override
  ConsumerState<FirstSyncResultsScreen> createState() =>
      _FirstSyncResultsScreenState();
}

class _FirstSyncResultsScreenState
    extends ConsumerState<FirstSyncResultsScreen> {
  @override
  void initState() {
    super.initState();
    AnalyticsService().logCustomEvent(
      eventName: 'first_sync_results_viewed',
      parameters: {'platform': widget.platform},
    );
    Future.microtask(() async {
      try {
        await ReferralService(
          ref.read(supabaseClientProvider),
        ).finalizeAfterFirstSync();
      } catch (_) {
        // Referral finalization must never interrupt the sync celebration.
      }
    });
  }

  void _open(String route, String action) {
    AnalyticsService().logCustomEvent(
      eventName: 'first_sync_results_action',
      parameters: {'platform': widget.platform, 'action': action},
    );
    context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(dashboardStatsProvider);
    final userStatsAsync = ref.watch(userStatsProvider);
    final platformName = switch (widget.platform.toLowerCase()) {
      'psn' => 'PlayStation',
      'xbox' => 'Xbox',
      'steam' => 'Steam',
      _ => 'gaming',
    };

    return Scaffold(
      backgroundColor: const Color(0xFF050816),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 30, 20, 32),
          children: [
            const Icon(
              Icons.celebration,
              size: 70,
              color: CyberpunkTheme.neonCyan,
            ),
            const SizedBox(height: 18),
            const Text(
              'YOUR GAMING STORY IS LIVE',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 25,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$platformName sync complete. Here is what StatusXP discovered.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),
            const SizedBox(height: 26),
            dashboardAsync.when(
              data: (stats) {
                final platforms = [
                  stats?.psnStats,
                  stats?.xboxStats,
                  stats?.steamStats,
                ];
                final games = platforms.fold<int>(
                  0,
                  (total, item) => total + (item?.gamesCount ?? 0),
                );
                final achievements = platforms.fold<int>(
                  0,
                  (total, item) => total + (item?.achievementsUnlocked ?? 0),
                );
                return Row(
                  children: [
                    Expanded(
                      child: _ResultTile(
                        value: games.toString(),
                        label: 'Games',
                        icon: Icons.sports_esports,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ResultTile(
                        value: achievements.toString(),
                        label: 'Unlocks',
                        icon: Icons.emoji_events,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ResultTile(
                        value: (stats?.totalStatusXP ?? 0).round().toString(),
                        label: 'StatusXP',
                        icon: Icons.bolt,
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const _ResultsSettlingCard(),
            ),
            const SizedBox(height: 18),
            userStatsAsync.when(
              data: (stats) {
                final hasRarest = stats.rarestTrophyName.trim().isNotEmpty;
                return _HighlightCard(
                  title: hasRarest ? 'RAREST UNLOCK FOUND' : 'PROFILE CREATED',
                  value: hasRarest
                      ? stats.rarestTrophyName
                      : '${stats.totalTrophies} achievements tracked',
                  detail: hasRarest && stats.rarestTrophyRarity > 0
                      ? '${stats.rarestTrophyRarity.toStringAsFixed(1)}% of players unlocked this'
                      : 'Your progress will get richer with every sync.',
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: () => _open('/', 'view_dashboard'),
              icon: const Icon(Icons.dashboard),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text('VIEW MY DASHBOARD'),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              color: CyberpunkTheme.neonCyan.withValues(alpha: 0.10),
              child: InkWell(
                onTap: () {
                  AnalyticsService().logCustomEvent(
                    eventName: 'referral_prompt_accepted',
                    parameters: {'source': 'first_sync_results'},
                  );
                  context.push('/invite?source=first_sync_results');
                },
                borderRadius: BorderRadius.circular(12),
                child: const Padding(
                  padding: EdgeInsets.all(17),
                  child: Row(
                    children: [
                      Icon(
                        Icons.group_add,
                        color: CyberpunkTheme.neonGreen,
                        size: 32,
                      ),
                      SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bring an achievement hunter',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Give 10 AI guides and earn 10 after their first sync.',
                              style: TextStyle(color: Colors.white60),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: Colors.white54),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              color: CyberpunkTheme.neonPurple.withValues(alpha: 0.14),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    const Icon(
                      Icons.insights,
                      color: CyberpunkTheme.neonPurple,
                      size: 32,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Go deeper with Premium',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Turn your imported history into advanced insights, goals, pace coaching, and achievement radar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => _open(
                        '/premium-subscription?source=first_sync_results',
                        'preview_premium',
                      ),
                      child: const Text('EXPLORE PREMIUM'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0E27),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: CyberpunkTheme.neonCyan.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: CyberpunkTheme.neonCyan, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(label, style: const TextStyle(color: Colors.white60)),
        ],
      ),
    );
  }
}

class _HighlightCard extends StatelessWidget {
  const _HighlightCard({
    required this.title,
    required this.value,
    required this.detail,
  });

  final String title;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF0A0E27),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: CyberpunkTheme.neonCyan,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(detail, style: const TextStyle(color: Colors.white60)),
          ],
        ),
      ),
    );
  }
}

class _ResultsSettlingCard extends StatelessWidget {
  const _ResultsSettlingCard();

  @override
  Widget build(BuildContext context) {
    return const _HighlightCard(
      title: 'SYNC COMPLETE',
      value: 'Your results are being finalized',
      detail: 'Your dashboard will refresh automatically.',
    );
  }
}
