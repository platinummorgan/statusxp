import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:statusxp/data/repositories/leaderboard_repository.dart';
import 'package:statusxp/domain/hall_of_fame_entry.dart';
import 'package:statusxp/domain/seasonal_leaderboard_entry.dart';
import 'package:statusxp/theme/cyberpunk_theme.dart';
import 'package:statusxp/ui/screens/flex_room_screen.dart';

class HallOfFameScreen extends ConsumerStatefulWidget {
  const HallOfFameScreen({super.key});

  @override
  ConsumerState<HallOfFameScreen> createState() => _HallOfFameScreenState();
}

class _HallOfFameScreenState extends ConsumerState<HallOfFameScreen> {
  LeaderboardPeriodType _selectedPeriod = LeaderboardPeriodType.weekly;
  SeasonalBoardType _selectedBoard = SeasonalBoardType.statusXP;

  @override
  Widget build(BuildContext context) {
    final hallOfFameAsync = ref.watch(hallOfFameProvider(_selectedPeriod));
    final winnersAsync = ref.watch(
      latestPeriodWinnersProvider(_selectedPeriod),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Hall of Fame',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF0A0E27),
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
      ),
      body: Container(
        decoration: CyberpunkTheme.gradientBackground(),
        child: Column(
          children: [
            _buildPeriodToggle(),
            _buildBoardFilter(),
            _buildChampionCallout(winnersAsync),
            Expanded(child: _buildHistoryList(hallOfFameAsync)),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodToggle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
    );
  }

  Widget _buildBoardFilter() {
    final options = <SeasonalBoardType>[
      SeasonalBoardType.statusXP,
      SeasonalBoardType.platinums,
      SeasonalBoardType.xbox,
      SeasonalBoardType.steam,
    ];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final value = options[index];
          final selected = value == _selectedBoard;
          return ChoiceChip(
            label: Text(_boardLabel(value)),
            selected: selected,
            onSelected: (_) {
              setState(() {
                _selectedBoard = value;
              });
            },
            labelStyle: TextStyle(
              color: selected ? Colors.black : Colors.white,
              fontWeight: FontWeight.w700,
            ),
            selectedColor: CyberpunkTheme.neonGreen,
            backgroundColor: Colors.black.withOpacity(0.35),
            side: BorderSide(
              color: selected
                  ? CyberpunkTheme.neonGreen.withOpacity(0.8)
                  : CyberpunkTheme.neonCyan.withOpacity(0.35),
            ),
          );
        },
      ),
    );
  }

  Widget _buildChampionCallout(AsyncValue<List<HallOfFameEntry>> winnersAsync) {
    return winnersAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (winners) {
        HallOfFameEntry? champion;
        final matches = winners.where((w) => w.boardType == _selectedBoard);
        if (matches.isNotEmpty) {
          champion = matches.first;
        }

        if (champion == null) {
          return const SizedBox.shrink();
        }

        final dateLabel =
            '${DateFormat('MMM d').format(champion.periodStart.toLocal())} - ${DateFormat('MMM d, y').format(champion.periodEnd.toLocal())}';

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0E27).withOpacity(0.9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: CyberpunkTheme.goldNeon.withOpacity(0.9),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: CyberpunkTheme.goldNeon.withOpacity(0.25),
                blurRadius: 14,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(
                Icons.workspace_premium,
                color: CyberpunkTheme.goldNeon,
                size: 30,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Champion Spotlight',
                      style: TextStyle(
                        color: CyberpunkTheme.goldNeon,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${champion.winnerDisplayName} won ${_boardLabel(champion.boardType)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '+${_fmt(champion.winnerGain)}  |  $dateLabel',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.75),
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

  Widget _buildHistoryList(AsyncValue<List<HallOfFameEntry>> hallOfFameAsync) {
    return hallOfFameAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Error loading Hall of Fame: $error',
            style: const TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ),
      ),
      data: (entries) {
        final filtered = entries
            .where((e) => e.boardType == _selectedBoard)
            .toList();

        if (filtered.isEmpty) {
          return const Center(
            child: Text(
              'No winners recorded yet for this selection',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(hallOfFameProvider(_selectedPeriod));
            ref.invalidate(latestPeriodWinnersProvider(_selectedPeriod));
            await Future.delayed(const Duration(milliseconds: 300));
          },
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            itemCount: filtered.length,
            itemBuilder: (context, index) => _buildHistoryCard(filtered[index]),
          ),
        );
      },
    );
  }

  Widget _buildHistoryCard(HallOfFameEntry entry) {
    final periodLabel =
        '${DateFormat('MMM d').format(entry.periodStart.toLocal())} - ${DateFormat('MMM d, y').format(entry.periodEnd.toLocal())}';

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => FlexRoomScreen(viewerId: entry.winnerUserId),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0E27).withOpacity(0.82),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: CyberpunkTheme.neonCyan.withOpacity(0.35)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundImage: entry.winnerAvatarUrl != null
                  ? NetworkImage(entry.winnerAvatarUrl!)
                  : null,
              backgroundColor: CyberpunkTheme.neonCyan.withOpacity(0.2),
              child: entry.winnerAvatarUrl == null
                  ? const Icon(Icons.person, color: CyberpunkTheme.neonCyan)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.winnerDisplayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_boardLabel(entry.boardType)}  |  $periodLabel',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'WIN GAIN',
                  style: TextStyle(
                    color: CyberpunkTheme.neonGreen,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '+${_fmt(entry.winnerGain)}',
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

  String _boardLabel(SeasonalBoardType boardType) {
    switch (boardType) {
      case SeasonalBoardType.statusXP:
        return 'StatusXP';
      case SeasonalBoardType.platinums:
        return 'PSN';
      case SeasonalBoardType.xbox:
        return 'Xbox';
      case SeasonalBoardType.steam:
        return 'Steam';
    }
  }

  String _fmt(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
    return value.toString();
  }
}
