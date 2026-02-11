import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:statusxp/domain/premium_features_data.dart';

class PremiumFeaturesRepository {
  final SupabaseClient _client;

  const PremiumFeaturesRepository(this._client);

  Future<GoalsPaceData> getGoalsPaceData(
    String userId, {
    required GoalsMetric metric,
  }) async {
    final currentValueFuture = _getCurrentValue(userId, metric);
    final weeklyFuture = _getPaceWindow(userId, 'weekly', metric);
    final monthlyFuture = _getPaceWindow(userId, 'monthly', metric);

    return GoalsPaceData(
      currentValue: await currentValueFuture,
      weekly: await weeklyFuture,
      monthly: await monthlyFuture,
    );
  }

  Future<PaceWindowInsight> getGoalsRangeData(
    String userId, {
    required GoalsMetric metric,
    required DateTime start,
    required DateTime end,
  }) async {
    final startUtc = DateTime.utc(start.year, start.month, start.day);
    final endExclusive = DateTime.utc(
      end.year,
      end.month,
      end.day,
    ).add(const Duration(days: 1));

    if (!endExclusive.isAfter(startUtc)) {
      throw Exception('Invalid date range');
    }

    final metricColumn = _snapshotMetricColumn(metric);

    try {
      final endRow = await _client
          .from('user_stat_snapshots')
          .select('$metricColumn, synced_at')
          .eq('user_id', userId)
          .lt('synced_at', endExclusive.toIso8601String())
          .order('synced_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (endRow == null) {
        return PaceWindowInsight(
          periodLabel: 'Custom',
          periodStart: startUtc,
          periodEnd: endExclusive,
          currentGain: 0,
          projectedGain: 0,
          rank: 0,
          totalPlayers: 0,
          gapToFirst: 0,
        );
      }

      final endValue = (endRow[metricColumn] as num?)?.toInt() ?? 0;

      final baselineRow = await _client
          .from('user_stat_snapshots')
          .select(metricColumn)
          .eq('user_id', userId)
          .lt('synced_at', startUtc.toIso8601String())
          .order('synced_at', ascending: false)
          .limit(1)
          .maybeSingle();

      int baselineValue;
      if (baselineRow != null) {
        baselineValue = (baselineRow[metricColumn] as num?)?.toInt() ?? 0;
      } else {
        final firstInRange = await _client
            .from('user_stat_snapshots')
            .select(metricColumn)
            .eq('user_id', userId)
            .gte('synced_at', startUtc.toIso8601String())
            .lt('synced_at', endExclusive.toIso8601String())
            .order('synced_at', ascending: true)
            .limit(1)
            .maybeSingle();

        baselineValue =
            (firstInRange?[metricColumn] as num?)?.toInt() ?? endValue;
      }

      final gain = (endValue - baselineValue).clamp(0, 1 << 30);
      final totalDays = _periodDays(startUtc, endExclusive);
      final elapsedDays = _elapsedDays(startUtc, endExclusive);
      final projectedGain = elapsedDays > 0
          ? ((gain / elapsedDays) * totalDays).round()
          : gain;

      return PaceWindowInsight(
        periodLabel: 'Custom',
        periodStart: startUtc,
        periodEnd: endExclusive,
        currentGain: gain,
        projectedGain: projectedGain,
        rank: 0,
        totalPlayers: 0,
        gapToFirst: 0,
      );
    } catch (_) {
      return PaceWindowInsight(
        periodLabel: 'Custom',
        periodStart: startUtc,
        periodEnd: endExclusive,
        currentGain: 0,
        projectedGain: 0,
        rank: 0,
        totalPlayers: 0,
        gapToFirst: 0,
      );
    }
  }

  Future<RivalCompareData> getRivalCompareData(
    String userId, {
    int leaderboardLimit = 40,
  }) async {
    final allTimeRaw =
        await _client.rpc(
              'get_leaderboard_with_movement',
              params: {'limit_count': leaderboardLimit, 'offset_count': 0},
            )
            as List<dynamic>;

    final weeklyRaw =
        await _client.rpc(
              'get_statusxp_period_leaderboard',
              params: {
                'p_period_type': 'weekly',
                'limit_count': leaderboardLimit,
                'offset_count': 0,
              },
            )
            as List<dynamic>;

    final monthlyRaw =
        await _client.rpc(
              'get_statusxp_period_leaderboard',
              params: {
                'p_period_type': 'monthly',
                'limit_count': leaderboardLimit,
                'offset_count': 0,
              },
            )
            as List<dynamic>;

    final weeklyByUser = <String, int>{};
    final monthlyByUser = <String, int>{};

    for (final row in weeklyRaw) {
      final id = row['user_id']?.toString();
      if (id == null) continue;
      weeklyByUser[id] = (row['period_gain'] as num?)?.toInt() ?? 0;
    }

    for (final row in monthlyRaw) {
      final id = row['user_id']?.toString();
      if (id == null) continue;
      monthlyByUser[id] = (row['period_gain'] as num?)?.toInt() ?? 0;
    }

    int yourScore = 0;
    final entries = <RivalCompareEntry>[];

    for (int index = 0; index < allTimeRaw.length; index++) {
      final row = allTimeRaw[index] as Map<String, dynamic>;
      final id = row['user_id']?.toString();
      if (id == null) continue;

      final score = (row['total_statusxp'] as num?)?.toInt() ?? 0;
      if (id == userId) {
        yourScore = score;
      }

      entries.add(
        RivalCompareEntry(
          userId: id,
          displayName: row['display_name']?.toString() ?? 'Player',
          avatarUrl: row['avatar_url']?.toString(),
          allTimeRank: index + 1,
          allTimeScore: score,
          weeklyGain: weeklyByUser[id] ?? 0,
          monthlyGain: monthlyByUser[id] ?? 0,
          gapToYou: 0, // patched below once your score is known
          isYou: id == userId,
        ),
      );
    }

    if (entries.isNotEmpty && yourScore == 0) {
      final maybeYou = entries.where((entry) => entry.isYou).toList();
      if (maybeYou.isNotEmpty) {
        yourScore = maybeYou.first.allTimeScore;
      }
    }

    final patched = entries
        .map(
          (entry) => RivalCompareEntry(
            userId: entry.userId,
            displayName: entry.displayName,
            avatarUrl: entry.avatarUrl,
            allTimeRank: entry.allTimeRank,
            allTimeScore: entry.allTimeScore,
            weeklyGain: entry.weeklyGain,
            monthlyGain: entry.monthlyGain,
            gapToYou: entry.allTimeScore - yourScore,
            isYou: entry.isYou,
          ),
        )
        .toList();

    return RivalCompareData(
      userId: userId,
      yourAllTimeScore: yourScore,
      entries: patched,
    );
  }

  Future<AchievementRadarData> getAchievementRadarData(String userId) async {
    final rows =
        await _client
                .from('user_progress')
                .select(
                  'platform_id, platform_game_id, achievements_earned, total_achievements, completion_percentage, current_score, last_played_at, last_achievement_earned_at, synced_at, games(name)',
                )
                .eq('user_id', userId)
            as List<dynamic>;

    final games = rows
        .map((row) => _toRadarGame(row as Map<String, dynamic>))
        .whereType<RadarGameInsight>()
        .toList();

    final nearCompletion =
        games
            .where(
              (game) =>
                  game.totalCount > 0 &&
                  game.completionPercent >= 70 &&
                  game.completionPercent < 100,
            )
            .toList()
          ..sort((a, b) {
            final completionCompare = b.completionPercent.compareTo(
              a.completionPercent,
            );
            if (completionCompare != 0) return completionCompare;
            return a.remainingCount.compareTo(b.remainingCount);
          });

    final staleCutoff = DateTime.now().toUtc().subtract(
      const Duration(days: 30),
    );
    final staleProgress =
        games.where((game) {
          final anchor =
              game.lastAchievementAt ?? game.lastPlayedAt ?? game.lastSyncedAt;
          return game.earnedCount > 0 &&
              anchor != null &&
              anchor.isBefore(staleCutoff);
        }).toList()..sort((a, b) {
          final aAnchor =
              a.lastAchievementAt ?? a.lastPlayedAt ?? a.lastSyncedAt;
          final bAnchor =
              b.lastAchievementAt ?? b.lastPlayedAt ?? b.lastSyncedAt;
          if (aAnchor == null && bAnchor == null) return 0;
          if (aAnchor == null) return 1;
          if (bAnchor == null) return -1;
          return aAnchor.compareTo(bAnchor);
        });

    final highPotential =
        games
            .where(
              (game) =>
                  game.totalCount > 0 &&
                  game.remainingCount > 0 &&
                  game.completionPercent <= 85,
            )
            .toList()
          ..sort((a, b) {
            final remainingCompare = b.remainingCount.compareTo(
              a.remainingCount,
            );
            if (remainingCompare != 0) return remainingCompare;
            return a.completionPercent.compareTo(b.completionPercent);
          });

    return AchievementRadarData(
      nearCompletion: nearCompletion.take(12).toList(),
      staleProgress: staleProgress.take(12).toList(),
      highPotential: highPotential.take(12).toList(),
    );
  }

  Future<int> _getCurrentValue(String userId, GoalsMetric metric) async {
    switch (metric) {
      case GoalsMetric.statusxp:
        final row = await _client
            .from('leaderboard_cache')
            .select('total_statusxp')
            .eq('user_id', userId)
            .maybeSingle();
        if (row == null) return 0;
        return (row['total_statusxp'] as num?)?.toInt() ?? 0;
      case GoalsMetric.platinums:
        final row = await _client
            .from('psn_leaderboard_cache')
            .select('platinum_count')
            .eq('user_id', userId)
            .maybeSingle();
        if (row == null) return 0;
        return (row['platinum_count'] as num?)?.toInt() ?? 0;
      case GoalsMetric.xboxGamerscore:
        final row = await _client
            .from('xbox_leaderboard_cache')
            .select('gamerscore')
            .eq('user_id', userId)
            .maybeSingle();
        if (row == null) return 0;
        return (row['gamerscore'] as num?)?.toInt() ?? 0;
      case GoalsMetric.steamAchievements:
        final row = await _client
            .from('steam_leaderboard_cache')
            .select('achievement_count')
            .eq('user_id', userId)
            .maybeSingle();
        if (row == null) return 0;
        return (row['achievement_count'] as num?)?.toInt() ?? 0;
    }
  }

  Future<PaceWindowInsight> _getPaceWindow(
    String userId,
    String periodType,
    GoalsMetric metric,
  ) async {
    final now = DateTime.now().toUtc();
    final defaultStart = periodType == 'monthly'
        ? DateTime.utc(now.year, now.month, 1)
        : DateTime.utc(
            now.year,
            now.month,
            now.day,
          ).subtract(Duration(days: now.weekday % 7));
    final defaultEnd = periodType == 'monthly'
        ? DateTime.utc(defaultStart.year, defaultStart.month + 1, 1)
        : defaultStart.add(const Duration(days: 7));

    try {
      final startRaw = await _client.rpc(
        'get_leaderboard_period_start',
        params: {'p_period_type': periodType},
      );
      final periodStart = DateTime.parse(startRaw.toString()).toUtc();
      final periodEnd = periodType == 'monthly'
          ? DateTime.utc(periodStart.year, periodStart.month + 1, 1)
          : periodStart.add(const Duration(days: 7));

      final rpcName = _periodRpc(metric);
      final rows =
          await _client.rpc(
                rpcName,
                params: {
                  'p_period_type': periodType,
                  'limit_count': 2000,
                  'offset_count': 0,
                },
              )
              as List<dynamic>;

      final index = rows.indexWhere(
        (row) => row['user_id']?.toString() == userId,
      );
      final yourGain = index >= 0
          ? (rows[index]['period_gain'] as num?)?.toInt() ?? 0
          : 0;
      final topGain = rows.isNotEmpty
          ? (rows.first['period_gain'] as num?)?.toInt() ?? 0
          : 0;
      final totalPlayers = rows.length;

      final totalDays = _periodDays(periodStart, periodEnd);
      final elapsedDays = _elapsedDays(periodStart, periodEnd);
      final projectedGain = elapsedDays > 0
          ? ((yourGain / elapsedDays) * totalDays).round()
          : yourGain;

      return PaceWindowInsight(
        periodLabel: periodType == 'monthly' ? 'Monthly' : 'Weekly',
        periodStart: periodStart,
        periodEnd: periodEnd,
        currentGain: yourGain,
        projectedGain: projectedGain,
        rank: index >= 0 ? index + 1 : 0,
        totalPlayers: totalPlayers,
        gapToFirst: (topGain - yourGain).clamp(0, 1 << 30),
      );
    } catch (_) {
      return PaceWindowInsight(
        periodLabel: periodType == 'monthly' ? 'Monthly' : 'Weekly',
        periodStart: defaultStart,
        periodEnd: defaultEnd,
        currentGain: 0,
        projectedGain: 0,
        rank: 0,
        totalPlayers: 0,
        gapToFirst: 0,
      );
    }
  }

  int _periodDays(DateTime start, DateTime end) {
    final days = end.difference(start).inDays;
    return days <= 0 ? 1 : days;
  }

  int _elapsedDays(DateTime start, DateTime end) {
    final now = DateTime.now().toUtc();
    final total = _periodDays(start, end);
    if (now.isBefore(start)) return 0;
    if (now.isAfter(end)) return total;
    return (now.difference(start).inDays + 1).clamp(1, total);
  }

  RadarGameInsight? _toRadarGame(Map<String, dynamic> row) {
    final platformId = (row['platform_id'] as num?)?.toInt();
    final platformGameId = row['platform_game_id']?.toString();
    if (platformId == null || platformGameId == null) return null;

    final gameRelation = row['games'];
    String gameTitle = 'Unknown Game';
    if (gameRelation is Map<String, dynamic>) {
      gameTitle = gameRelation['name']?.toString() ?? gameTitle;
    } else if (gameRelation is List && gameRelation.isNotEmpty) {
      final first = gameRelation.first;
      if (first is Map<String, dynamic>) {
        gameTitle = first['name']?.toString() ?? gameTitle;
      }
    }

    final earned = (row['achievements_earned'] as num?)?.toInt() ?? 0;
    final total = (row['total_achievements'] as num?)?.toInt() ?? 0;
    final completion = (row['completion_percentage'] as num?)?.toDouble() ?? 0;
    final remaining = (total - earned).clamp(0, 1 << 30);
    final currentScore = (row['current_score'] as num?)?.toInt() ?? 0;

    return RadarGameInsight(
      platformId: platformId,
      platformLabel: _platformLabel(platformId),
      platformGameId: platformGameId,
      gameTitle: gameTitle,
      earnedCount: earned,
      totalCount: total,
      remainingCount: remaining,
      completionPercent: completion,
      currentScore: currentScore,
      lastPlayedAt: _asUtc(row['last_played_at']),
      lastAchievementAt: _asUtc(row['last_achievement_earned_at']),
      lastSyncedAt: _asUtc(row['synced_at']),
    );
  }

  DateTime? _asUtc(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString())?.toUtc();
  }

  String _platformLabel(int platformId) {
    if ([1, 2, 5, 9].contains(platformId)) return 'PSN';
    if ([10, 11, 12].contains(platformId)) return 'XBOX';
    if (platformId == 4) return 'STEAM';
    return 'UNKNOWN';
  }

  String _periodRpc(GoalsMetric metric) {
    switch (metric) {
      case GoalsMetric.statusxp:
        return 'get_statusxp_period_leaderboard';
      case GoalsMetric.platinums:
        return 'get_psn_period_leaderboard';
      case GoalsMetric.xboxGamerscore:
        return 'get_xbox_period_leaderboard';
      case GoalsMetric.steamAchievements:
        return 'get_steam_period_leaderboard';
    }
  }

  String _snapshotMetricColumn(GoalsMetric metric) {
    switch (metric) {
      case GoalsMetric.statusxp:
        return 'total_statusxp';
      case GoalsMetric.platinums:
        return 'platinum_count';
      case GoalsMetric.xboxGamerscore:
        return 'gamerscore';
      case GoalsMetric.steamAchievements:
        return 'steam_achievement_count';
    }
  }
}
