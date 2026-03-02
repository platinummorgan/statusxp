import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:statusxp/data/repositories/leaderboard_repository.dart';
import 'package:statusxp/domain/seasonal_leaderboard_entry.dart';
import 'package:statusxp/domain/seasonal_user_breakdown.dart';
import 'package:statusxp/theme/cyberpunk_theme.dart';
import 'package:statusxp/ui/screens/unified_games_list_screen.dart';

class SeasonalUserBreakdownScreen extends ConsumerWidget {
  final String targetUserId;
  final String targetDisplayName;
  final String? targetAvatarUrl;
  final SeasonalBoardType boardType;
  final LeaderboardPeriodType periodType;

  const SeasonalUserBreakdownScreen({
    super.key,
    required this.targetUserId,
    required this.targetDisplayName,
    required this.targetAvatarUrl,
    required this.boardType,
    required this.periodType,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = SeasonalUserBreakdownQuery(
      targetUserId: targetUserId,
      boardType: boardType,
      periodType: periodType,
    );
    final breakdownAsync = ref.watch(seasonalUserBreakdownProvider(query));

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Seasonal Breakdown',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF0A0E27),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: CyberpunkTheme.gradientBackground(),
        child: breakdownAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.redAccent,
                    size: 42,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Failed to load seasonal breakdown.\n$error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      ref.invalidate(seasonalUserBreakdownProvider(query));
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
          data: (data) {
            final periodLabel =
                '${DateFormat('MMM d').format(data.periodStart.toLocal())} - '
                '${DateFormat('MMM d, y').format(data.periodEnd.toLocal())}';
            final gainSuffix = _gainSuffix(boardType);

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(seasonalUserBreakdownProvider(query));
                await Future<void>.delayed(const Duration(milliseconds: 300));
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildHeaderCard(
                    periodLabel: periodLabel,
                    totalGain: data.totalGain,
                    gainSuffix: gainSuffix,
                  ),
                  const SizedBox(height: 12),
                  _buildPublicGamesAction(context),
                  const SizedBox(height: 12),
                  if (data.contributions.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A0E27).withOpacity(0.82),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: CyberpunkTheme.neonCyan.withOpacity(0.3),
                        ),
                      ),
                      child: const Text(
                        'No earned progress for this player in the selected seasonal window yet.',
                        style: TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    ...data.contributions.map(
                      (row) => _buildContributionCard(
                        row: row,
                        gainSuffix: gainSuffix,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPublicGamesAction(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => UnifiedGamesListScreen(
                targetUserId: targetUserId,
                targetDisplayName: targetDisplayName,
              ),
            ),
          );
        },
        icon: const Icon(Icons.view_list_rounded),
        label: const Text('View Full Game History'),
        style: OutlinedButton.styleFrom(
          foregroundColor: CyberpunkTheme.neonCyan,
          side: BorderSide(color: CyberpunkTheme.neonCyan.withOpacity(0.55)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard({
    required String periodLabel,
    required int totalGain,
    required String gainSuffix,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0E27).withOpacity(0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CyberpunkTheme.neonGreen.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundImage: targetAvatarUrl != null
                ? NetworkImage(targetAvatarUrl!)
                : null,
            backgroundColor: CyberpunkTheme.neonCyan.withOpacity(0.2),
            child: targetAvatarUrl == null
                ? const Icon(Icons.person, color: CyberpunkTheme.neonCyan)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  targetDisplayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_boardLabel(boardType)} • $periodLabel',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.72),
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
                'TOTAL GAIN',
                style: TextStyle(
                  color: CyberpunkTheme.neonGreen,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '+$totalGain $gainSuffix',
                style: const TextStyle(
                  color: CyberpunkTheme.neonGreen,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContributionCard({
    required SeasonalGameContribution row,
    required String gainSuffix,
  }) {
    final platformLabel = _platformLabel(row.platformId);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0E27).withOpacity(0.82),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CyberpunkTheme.neonCyan.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          if (row.coverUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                row.coverUrl!,
                width: 44,
                height: 58,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _coverFallback(),
              ),
            )
          else
            _coverFallback(),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.gameName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: CyberpunkTheme.neonPurple.withOpacity(0.5),
                        ),
                      ),
                      child: Text(
                        platformLabel,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${row.earnedCount} unlocks',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.65),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '+${row.periodGain} $gainSuffix',
            style: const TextStyle(
              color: CyberpunkTheme.neonGreen,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _coverFallback() {
    return Container(
      width: 44,
      height: 58,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.black.withOpacity(0.25),
      ),
      child: const Icon(Icons.videogame_asset, color: Colors.white38, size: 18),
    );
  }

  String _boardLabel(SeasonalBoardType type) {
    switch (type) {
      case SeasonalBoardType.statusXP:
        return 'StatusXP';
      case SeasonalBoardType.platinums:
        return 'Platinums';
      case SeasonalBoardType.xbox:
        return 'Xbox';
      case SeasonalBoardType.steam:
        return 'Steam';
    }
  }

  String _gainSuffix(SeasonalBoardType type) {
    switch (type) {
      case SeasonalBoardType.statusXP:
        return 'XP';
      case SeasonalBoardType.platinums:
        return 'plats';
      case SeasonalBoardType.xbox:
        return 'GS';
      case SeasonalBoardType.steam:
        return 'ach';
    }
  }

  String _platformLabel(int platformId) {
    if ([1, 2, 5, 9].contains(platformId)) return 'PlayStation';
    if ([10, 11, 12].contains(platformId)) return 'Xbox';
    if (platformId == 4) return 'Steam';
    return 'Other';
  }
}
