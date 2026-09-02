import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:statusxp/domain/dashboard_stats.dart';
import 'package:statusxp/domain/unified_game.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/theme/colors.dart';

/// Content-dense dashboard designed specifically for a desktop browser.
class WebDesktopDashboard extends ConsumerWidget {
  const WebDesktopDashboard({super.key});

  static final _number = NumberFormat.decimalPattern();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(dashboardStatsProvider);
    final games = ref.watch(unifiedGamesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF090D1D),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardStatsProvider);
          ref.invalidate(unifiedGamesProvider);
          await Future.wait([
            ref.read(dashboardStatsProvider.future),
            ref.read(unifiedGamesProvider.future),
          ]);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(30, 28, 30, 60),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1240),
              child: stats.when(
                loading: () => const SizedBox(
                  height: 500,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => _ErrorPanel(
                  onRetry: () => ref.invalidate(dashboardStatsProvider),
                ),
                data: (value) => value == null
                    ? const _EmptyPanel()
                    : _DashboardBody(stats: value, games: games),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.stats, required this.games});
  final DashboardStats stats;
  final AsyncValue<List<UnifiedGame>> games;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _ProfileHeader(stats: stats),
      const SizedBox(height: 18),
      _SummaryStrip(stats: stats),
      const SizedBox(height: 24),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 7,
            child: Column(
              children: [
                _Panel(
                  title: 'Platform overview',
                  action: TextButton(
                    onPressed: () => context.go('/analytics'),
                    child: const Text('View analytics'),
                  ),
                  child: _PlatformTable(stats: stats),
                ),
                const SizedBox(height: 20),
                _Panel(
                  title: 'Recently played',
                  action: TextButton(
                    onPressed: () => context.go('/games'),
                    child: const Text('View all games'),
                  ),
                  child: games.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(36),
                      child: CircularProgressIndicator(),
                    ),
                    error: (_, _) => const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Games could not be loaded.'),
                    ),
                    data: (items) =>
                        _RecentGames(games: items.take(6).toList()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            flex: 3,
            child: Column(
              children: [
                _Panel(
                  title: 'Quick links',
                  child: Column(
                    children: [
                      _QuickLink(
                        icon: Icons.leaderboard,
                        label: 'Global leaderboards',
                        onTap: () => context.go('/leaderboards'),
                      ),
                      _QuickLink(
                        icon: Icons.radar,
                        label: 'Achievement radar',
                        onTap: () => context.go('/achievement-radar'),
                        premium: true,
                      ),
                      _QuickLink(
                        icon: Icons.flag,
                        label: 'Goals & pace',
                        onTap: () => context.go('/goals-pace'),
                        premium: true,
                      ),
                      _QuickLink(
                        icon: Icons.people_alt_outlined,
                        label: 'Find co-op partners',
                        onTap: () => context.go('/coop-partners'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _Panel(
                  title: 'Your library',
                  child: _LibraryFacts(games: games.valueOrNull ?? const []),
                ),
              ],
            ),
          ),
        ],
      ),
    ],
  );
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.stats});
  final DashboardStats stats;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: const Color(0xFF141A30),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.white.withValues(alpha: .09)),
    ),
    child: Row(
      children: [
        CircleAvatar(
          radius: 34,
          backgroundColor: surfaceLight,
          backgroundImage: stats.avatarUrl == null
              ? null
              : NetworkImage(stats.avatarUrl!),
          child: stats.avatarUrl == null
              ? const Icon(Icons.person, size: 34)
              : null,
        ),
        const SizedBox(width: 18),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              stats.displayName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 25,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '${stats.displayPlatform.toUpperCase()} profile · ${_totalGames(stats)} games tracked',
              style: const TextStyle(color: textSecondary, fontSize: 13),
            ),
          ],
        ),
        const Spacer(),
        OutlinedButton.icon(
          onPressed: () => context.go('/settings'),
          icon: const Icon(Icons.sync, size: 18),
          label: const Text('Manage accounts'),
        ),
      ],
    ),
  );

  int _totalGames(DashboardStats s) =>
      s.psnStats.gamesCount + s.xboxStats.gamesCount + s.steamStats.gamesCount;
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.stats});
  final DashboardStats stats;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: const Color(0xFF11162B),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.white.withValues(alpha: .08)),
    ),
    child: Row(
      children: [
        _Stat(
          label: 'STATUSXP',
          value: WebDesktopDashboard._number.format(
            stats.totalStatusXP.round(),
          ),
          color: accentPrimary,
        ),
        _Stat(
          label: 'PLATINUMS',
          value: WebDesktopDashboard._number.format(stats.psnStats.platinums),
        ),
        _Stat(
          label: 'XBOX GAMERSCORE',
          value: WebDesktopDashboard._number.format(stats.xboxStats.gamerscore),
        ),
        _Stat(
          label: 'STEAM ACHIEVEMENTS',
          value: WebDesktopDashboard._number.format(
            stats.steamStats.achievementsUnlocked,
          ),
        ),
      ],
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    this.color = Colors.white,
  });
  final String label;
  final String value;
  final Color color;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 19),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Colors.white.withValues(alpha: .08)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 25,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child, this.action});
  final String title;
  final Widget child;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: const Color(0xFF11162B),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.white.withValues(alpha: .08)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 10, 10),
          child: Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              if (action != null) action!,
            ],
          ),
        ),
        Divider(height: 1, color: Colors.white.withValues(alpha: .08)),
        child,
      ],
    ),
  );
}

class _PlatformTable extends StatelessWidget {
  const _PlatformTable({required this.stats});
  final DashboardStats stats;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      const _PlatformRow(
        platform: 'Platform',
        games: 'Games',
        unlocks: 'Unlocks',
        score: 'StatusXP',
        header: true,
      ),
      _PlatformRow(
        platform: 'PlayStation',
        games: '${stats.psnStats.gamesCount}',
        unlocks: '${stats.psnStats.achievementsUnlocked}',
        score: WebDesktopDashboard._number.format(
          stats.psnStats.statusXP.round(),
        ),
        color: const Color(0xFF4AA3FF),
      ),
      _PlatformRow(
        platform: 'Xbox',
        games: '${stats.xboxStats.gamesCount}',
        unlocks: '${stats.xboxStats.achievementsUnlocked}',
        score: WebDesktopDashboard._number.format(
          stats.xboxStats.statusXP.round(),
        ),
        color: const Color(0xFF65C466),
      ),
      _PlatformRow(
        platform: 'Steam',
        games: '${stats.steamStats.gamesCount}',
        unlocks: '${stats.steamStats.achievementsUnlocked}',
        score: WebDesktopDashboard._number.format(
          stats.steamStats.statusXP.round(),
        ),
        color: const Color(0xFF66C0F4),
      ),
    ],
  );
}

class _PlatformRow extends StatelessWidget {
  const _PlatformRow({
    required this.platform,
    required this.games,
    required this.unlocks,
    required this.score,
    this.header = false,
    this.color,
  });
  final String platform, games, unlocks, score;
  final bool header;
  final Color? color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
    decoration: BoxDecoration(
      border: Border(
        bottom: BorderSide(color: Colors.white.withValues(alpha: .06)),
      ),
    ),
    child: Row(
      children: [
        Expanded(
          flex: 4,
          child: Row(
            children: [
              if (!header)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              Text(
                platform,
                style: TextStyle(
                  color: header ? textMuted : Colors.white,
                  fontSize: header ? 11 : 14,
                  fontWeight: header ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Text(
            games,
            textAlign: TextAlign.right,
            style: TextStyle(color: header ? textMuted : textSecondary),
          ),
        ),
        Expanded(
          child: Text(
            unlocks,
            textAlign: TextAlign.right,
            style: TextStyle(color: header ? textMuted : textSecondary),
          ),
        ),
        Expanded(
          child: Text(
            score,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: header ? textMuted : Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _RecentGames extends StatelessWidget {
  const _RecentGames({required this.games});
  final List<UnifiedGame> games;
  @override
  Widget build(BuildContext context) {
    if (games.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text('No games synced yet.'),
      );
    }
    return Column(
      children: [
        for (final game in games)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 5,
            ),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Container(
                width: 46,
                height: 58,
                color: surfaceLight,
                child: game.coverUrl == null
                    ? const Icon(Icons.sports_esports)
                    : Image.network(
                        game.coverUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.sports_esports),
                      ),
              ),
            ),
            title: Text(
              game.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            subtitle: Text(
              game.platforms.map((p) => p.platform.toUpperCase()).join(' · '),
              style: const TextStyle(color: textMuted, fontSize: 11),
            ),
            trailing: SizedBox(
              width: 150,
              child: Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: game.overallCompletion / 100,
                      minHeight: 6,
                      backgroundColor: Colors.white10,
                      color: accentPrimary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 38,
                    child: Text(
                      '${game.overallCompletion.round()}%',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            onTap: () => context.go('/games'),
          ),
      ],
    );
  }
}

class _QuickLink extends StatelessWidget {
  const _QuickLink({
    required this.icon,
    required this.label,
    required this.onTap,
    this.premium = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool premium;
  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    leading: Icon(icon, color: accentPrimary, size: 20),
    title: Text(
      label,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    ),
    trailing: premium
        ? const Icon(Icons.workspace_premium, color: accentWarning, size: 15)
        : const Icon(Icons.chevron_right, color: textMuted),
    onTap: onTap,
  );
}

class _LibraryFacts extends StatelessWidget {
  const _LibraryFacts({required this.games});
  final List<UnifiedGame> games;
  @override
  Widget build(BuildContext context) {
    final completed = games.where((g) => g.overallCompletion >= 100).length;
    final average = games.isEmpty
        ? 0
        : games.fold<double>(0, (sum, g) => sum + g.overallCompletion) /
              games.length;
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          _Fact(label: 'Games tracked', value: '${games.length}'),
          _Fact(label: 'Completed', value: '$completed'),
          _Fact(label: 'Average completion', value: '${average.round()}%'),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Text(label, style: const TextStyle(color: textSecondary, fontSize: 13)),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => _Panel(
    title: 'Dashboard unavailable',
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Try again'),
        ),
      ),
    ),
  );
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel();
  @override
  Widget build(BuildContext context) => _Panel(
    title: 'Welcome to StatusXP',
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: FilledButton(
        onPressed: () => context.go('/get-started'),
        child: const Text('Connect a gaming account'),
      ),
    ),
  );
}
