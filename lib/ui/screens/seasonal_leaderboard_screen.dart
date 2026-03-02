import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:statusxp/data/repositories/leaderboard_repository.dart';
import 'package:statusxp/domain/hall_of_fame_entry.dart';
import 'package:statusxp/domain/seasonal_leaderboard_entry.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/theme/cyberpunk_theme.dart';
import 'package:statusxp/ui/screens/seasonal_user_breakdown_screen.dart';

class SeasonalLeaderboardScreen extends ConsumerStatefulWidget {
  const SeasonalLeaderboardScreen({super.key});

  @override
  ConsumerState<SeasonalLeaderboardScreen> createState() =>
      _SeasonalLeaderboardScreenState();
}

class _SeasonalLeaderboardScreenState
    extends ConsumerState<SeasonalLeaderboardScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  SeasonalBoardType _selectedBoard = SeasonalBoardType.statusXP;
  LeaderboardPeriodType _selectedPeriod = LeaderboardPeriodType.weekly;
  int _refreshGeneration = 0;
  static const _postSyncRetryDelays = [
    Duration(milliseconds: 1200),
    Duration(milliseconds: 2600),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() {
        _selectedBoard = SeasonalBoardType.values[_tabController.index];
      });
      _refreshSeasonalData();
    });
    // Trigger initial fetch after first frame so provider scope is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refreshSeasonalData(includeGuardedRetry: true);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshSeasonalData(includeGuardedRetry: true);
    }
  }

  Future<void> _refreshSeasonalData({bool includeGuardedRetry = false}) async {
    final generation = ++_refreshGeneration;
    final query = SeasonalLeaderboardQuery(
      boardType: _selectedBoard,
      periodType: _selectedPeriod,
    );
    ref.invalidate(seasonalLeaderboardProvider(query));
    ref.invalidate(latestPeriodWinnersProvider(_selectedPeriod));

    if (!includeGuardedRetry) return;

    final shouldRetry = await _shouldRunGuardedRetry();
    if (!mounted || generation != _refreshGeneration || !shouldRetry) return;

    for (final delay in _postSyncRetryDelays) {
      await Future<void>.delayed(delay);
      if (!mounted || generation != _refreshGeneration) return;
      ref.invalidate(seasonalLeaderboardProvider(query));
      ref.invalidate(latestPeriodWinnersProvider(_selectedPeriod));
    }
  }

  Future<bool> _shouldRunGuardedRetry() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return false;

    try {
      final row = await Supabase.instance.client
          .from('profiles')
          .select('last_psn_sync_at, last_xbox_sync_at, last_steam_sync_at')
          .eq('id', userId)
          .maybeSingle();

      if (row == null) return false;

      DateTime? parseTimestamp(dynamic value) {
        if (value == null) return null;
        try {
          return DateTime.parse(value.toString()).toUtc();
        } catch (_) {
          return null;
        }
      }

      bool isRecent(DateTime? timestamp) {
        if (timestamp == null) return false;
        final age = DateTime.now().toUtc().difference(timestamp);
        return age >= Duration.zero && age <= const Duration(minutes: 10);
      }

      return isRecent(parseTimestamp(row['last_psn_sync_at'])) ||
          isRecent(parseTimestamp(row['last_xbox_sync_at'])) ||
          isRecent(parseTimestamp(row['last_steam_sync_at']));
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final leaderboardAsync = ref.watch(
      seasonalLeaderboardProvider(
        SeasonalLeaderboardQuery(
          boardType: _selectedBoard,
          periodType: _selectedPeriod,
        ),
      ),
    );
    final winnersAsync = ref.watch(
      latestPeriodWinnersProvider(_selectedPeriod),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Seasonal Leaderboards',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF0A0E27),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: 'Hall of Fame',
            icon: const Icon(
              Icons.workspace_premium,
              color: CyberpunkTheme.goldNeon,
            ),
            onPressed: () => context.push('/leaderboards/hall-of-fame'),
          ),
        ],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(124),
          child: Column(
            children: [
              _buildPeriodToggle(),
              _buildActivePeriodLabel(),
              Container(
                color: const Color(0xFF0A0E27),
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: CyberpunkTheme.neonCyan,
                  labelColor: CyberpunkTheme.neonCyan,
                  unselectedLabelColor: Colors.white.withOpacity(0.6),
                  tabs: const [
                    Tab(text: 'StatusXP'),
                    Tab(text: 'Platinums'),
                    Tab(text: 'Xbox'),
                    Tab(text: 'Steam'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: Container(
        decoration: CyberpunkTheme.gradientBackground(),
        child: Column(
          children: [
            _buildWinnerSpotlight(winnersAsync),
            Expanded(child: _buildLeaderboardList(leaderboardAsync)),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodToggle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: SegmentedButton<LeaderboardPeriodType>(
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? CyberpunkTheme.neonCyan.withOpacity(0.2)
                      : Colors.black.withOpacity(0.25),
                ),
                foregroundColor: WidgetStateProperty.all(Colors.white),
              ),
              segments: const [
                ButtonSegment<LeaderboardPeriodType>(
                  value: LeaderboardPeriodType.weekly,
                  label: Text('Weekly'),
                ),
                ButtonSegment<LeaderboardPeriodType>(
                  value: LeaderboardPeriodType.monthly,
                  label: Text('Monthly'),
                ),
              ],
              selected: {_selectedPeriod},
              onSelectionChanged: (selection) {
                setState(() {
                  _selectedPeriod = selection.first;
                });
                _refreshSeasonalData();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivePeriodLabel() {
    final nowUtc = DateTime.now().toUtc();
    String label;

    if (_selectedPeriod == LeaderboardPeriodType.monthly) {
      final monthStartUtc = DateTime.utc(nowUtc.year, nowUtc.month, 1);
      label = DateFormat('MMM y').format(monthStartUtc.toLocal());
    } else {
      final startOfTodayUtc = DateTime.utc(
        nowUtc.year,
        nowUtc.month,
        nowUtc.day,
      );
      final daysSinceTuesday = (nowUtc.weekday - DateTime.tuesday + 7) % 7;
      final periodStartUtc = startOfTodayUtc.subtract(
        Duration(days: daysSinceTuesday),
      );
      final periodEndUtc = periodStartUtc.add(const Duration(days: 7));
      label =
          '${DateFormat('MMM d').format(periodStartUtc.toLocal())} - ${DateFormat('MMM d, y').format(periodEndUtc.toLocal())}';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.75),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }

  Widget _buildWinnerSpotlight(AsyncValue<List<HallOfFameEntry>> winnersAsync) {
    return winnersAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (winners) {
        HallOfFameEntry? winner;
        final matches = winners.where((w) => w.boardType == _selectedBoard);
        if (matches.isNotEmpty) {
          winner = matches.first;
        }
        if (winner == null) {
          return const SizedBox.shrink();
        }

        final periodLabel =
            '${DateFormat('MMM d').format(winner.periodStart.toLocal())} - ${DateFormat('MMM d, y').format(winner.periodEnd.toLocal())}';
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0E27).withOpacity(0.85),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: CyberpunkTheme.neonGreen.withOpacity(0.7),
            ),
            boxShadow: [
              BoxShadow(
                color: CyberpunkTheme.neonGreen.withOpacity(0.25),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(
                Icons.emoji_events,
                color: CyberpunkTheme.neonGreen,
                size: 28,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Champion Spotlight',
                      style: TextStyle(
                        color: CyberpunkTheme.neonGreen,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${winner.winnerDisplayName}  +${_fmt(winner.winnerGain)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      periodLabel,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.65),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLeaderboardList(
    AsyncValue<List<SeasonalLeaderboardEntry>> leaderboardAsync,
  ) {
    return leaderboardAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text(
          'Error loading seasonal leaderboard: $error',
          style: const TextStyle(color: Colors.white70),
          textAlign: TextAlign.center,
        ),
      ),
      data: (entries) {
        if (entries.isEmpty) {
          return const Center(
            child: Text(
              'No seasonal rankings yet',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            await _refreshSeasonalData();
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              return _buildEntryCard(entries[index], index + 1);
            },
          ),
        );
      },
    );
  }

  Widget _buildEntryCard(SeasonalLeaderboardEntry entry, int rank) {
    final subtitle = switch (_selectedBoard) {
      SeasonalBoardType.statusXP => 'Current: ${_fmt(entry.currentScore)} XP',
      SeasonalBoardType.platinums => 'Current: ${entry.currentScore} platinums',
      SeasonalBoardType.xbox => 'Current: ${_fmt(entry.currentScore)} GS',
      SeasonalBoardType.steam =>
        'Current: ${_fmt(entry.currentScore)} achievements',
    };

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SeasonalUserBreakdownScreen(
              targetUserId: entry.userId,
              targetDisplayName: entry.displayName,
              targetAvatarUrl: entry.avatarUrl,
              boardType: _selectedBoard,
              periodType: _selectedPeriod,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0E27).withOpacity(0.82),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: CyberpunkTheme.neonCyan.withOpacity(0.35)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: Text(
                '#$rank',
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
            CircleAvatar(
              radius: 22,
              backgroundImage: entry.avatarUrl != null
                  ? NetworkImage(entry.avatarUrl!)
                  : null,
              backgroundColor: CyberpunkTheme.neonCyan.withOpacity(0.2),
              child: entry.avatarUrl == null
                  ? const Icon(Icons.person, color: CyberpunkTheme.neonCyan)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.65),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'GAIN',
                  style: TextStyle(
                    color: CyberpunkTheme.neonGreen,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '+${_fmt(entry.periodGain)}',
                  style: const TextStyle(
                    color: CyberpunkTheme.neonGreen,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
    return value.toString();
  }
}
