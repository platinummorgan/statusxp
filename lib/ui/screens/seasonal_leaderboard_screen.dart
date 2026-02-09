import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:statusxp/data/repositories/leaderboard_repository.dart';
import 'package:statusxp/domain/hall_of_fame_entry.dart';
import 'package:statusxp/domain/seasonal_leaderboard_entry.dart';
import 'package:statusxp/theme/cyberpunk_theme.dart';
import 'package:statusxp/ui/screens/flex_room_screen.dart';

class SeasonalLeaderboardScreen extends ConsumerStatefulWidget {
  const SeasonalLeaderboardScreen({super.key});

  @override
  ConsumerState<SeasonalLeaderboardScreen> createState() =>
      _SeasonalLeaderboardScreenState();
}

class _SeasonalLeaderboardScreenState
    extends ConsumerState<SeasonalLeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  SeasonalBoardType _selectedBoard = SeasonalBoardType.statusXP;
  LeaderboardPeriodType _selectedPeriod = LeaderboardPeriodType.weekly;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() {
        _selectedBoard = SeasonalBoardType.values[_tabController.index];
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
          preferredSize: const Size.fromHeight(96),
          child: Column(
            children: [
              _buildPeriodToggle(),
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
              },
            ),
          ),
        ],
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
            ref.invalidate(
              seasonalLeaderboardProvider(
                SeasonalLeaderboardQuery(
                  boardType: _selectedBoard,
                  periodType: _selectedPeriod,
                ),
              ),
            );
            ref.invalidate(latestPeriodWinnersProvider(_selectedPeriod));
            await Future.delayed(const Duration(milliseconds: 300));
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
            builder: (_) => FlexRoomScreen(viewerId: entry.userId),
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
