import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:statusxp/domain/analytics_data.dart';

/// Repository for fetching analytics data
class AnalyticsRepository {
  final SupabaseClient _client;

  AnalyticsRepository(this._client);

  /// Fetch complete analytics data for a user
  Future<AnalyticsData> getAnalyticsData(String userId) async {
    final timelineFuture = _getTimelineData(userId);
    final platformDistributionFuture = _getPlatformDistribution(userId);
    final rarityDistributionFuture = _getRarityDistribution(userId);
    final trophyTypeBreakdownFuture = _getTrophyTypeBreakdown(userId);
    final monthlyActivityFuture = _getMonthlyActivity(userId);
    final recentActivityRowsFuture = _getRecentActivityRows(userId);
    final seasonalPaceFuture = _getSeasonalPaceData(userId);

    final timelineData = await timelineFuture;
    final platformDistribution = await platformDistributionFuture;
    final rarityDistribution = await rarityDistributionFuture;
    final trophyTypeBreakdown = await trophyTypeBreakdownFuture;
    final monthlyActivity = await monthlyActivityFuture;
    final recentActivityRows = await recentActivityRowsFuture;
    final seasonalPaceData = await seasonalPaceFuture;

    return AnalyticsData(
      timelineData: timelineData,
      platformDistribution: platformDistribution,
      rarityDistribution: rarityDistribution,
      trophyTypeBreakdown: trophyTypeBreakdown,
      monthlyActivity: monthlyActivity,
      dailyTrendData: _buildDailyTrendData(recentActivityRows),
      platformSplitTrend: _buildPlatformSplitTrend(recentActivityRows),
      seasonalPaceData: seasonalPaceData,
    );
  }

  /// Get trophy timeline data - cumulative trophies over time
  Future<TrophyTimelineData> _getTimelineData(String userId) async {
    try {
      final countResponse = await _client
          .from('user_achievements')
          .select('user_id')
          .eq('user_id', userId)
          .count();

      final totalCount = countResponse.count;

      if (totalCount == 0) {
        return const TrophyTimelineData(
          psnPoints: [],
          xboxPoints: [],
          steamPoints: [],
          totalTrophies: 0,
        );
      }

      final List<Map<String, dynamic>> allData = [];
      const batchSize = 1000;
      int offset = 0;

      while (offset < totalCount) {
        final batch = await _client
            .from('user_achievements')
            .select('earned_at, achievements!inner(platform_id)')
            .eq('user_id', userId)
            .order('earned_at')
            .range(offset, offset + batchSize - 1);

        allData.addAll((batch as List).cast<Map<String, dynamic>>());
        offset += batchSize;
      }

      final List<DateTime> psnDates = [];
      final List<DateTime> xboxDates = [];
      final List<DateTime> steamDates = [];
      DateTime? firstDate;
      DateTime? lastDate;

      for (final row in allData) {
        final dateStr = row['earned_at'] as String;
        final date = DateTime.parse(dateStr);
        final platformId = row['achievements']['platform_id'] as int?;
        final platform = _mapPlatformIdToBucket(platformId);

        if (firstDate == null || date.isBefore(firstDate)) {
          firstDate = date;
        }
        if (lastDate == null || date.isAfter(lastDate)) {
          lastDate = date;
        }

        switch (platform) {
          case 'psn':
            psnDates.add(date);
            break;
          case 'xbox':
            xboxDates.add(date);
            break;
          case 'steam':
            steamDates.add(date);
            break;
        }
      }

      final psnPoints = _buildTimelinePoints(psnDates);
      final xboxPoints = _buildTimelinePoints(xboxDates);
      final steamPoints = _buildTimelinePoints(steamDates);

      return TrophyTimelineData(
        psnPoints: psnPoints,
        xboxPoints: xboxPoints,
        steamPoints: steamPoints,
        totalTrophies: totalCount,
        firstTrophy: firstDate,
        lastTrophy: lastDate,
      );
    } catch (_) {
      return const TrophyTimelineData(
        psnPoints: [],
        xboxPoints: [],
        steamPoints: [],
        totalTrophies: 0,
      );
    }
  }

  /// Build timeline points from dates with sampling
  List<TimelinePoint> _buildTimelinePoints(List<DateTime> dates) {
    if (dates.isEmpty) return [];

    dates.sort();

    final List<TimelinePoint> points = [];
    final sampleRate = dates.length > 100 ? (dates.length / 100).ceil() : 1;

    for (int i = 0; i < dates.length; i += sampleRate) {
      points.add(TimelinePoint(date: dates[i], cumulativeCount: i + 1));
    }

    if (points.isEmpty || points.last.cumulativeCount != dates.length) {
      points.add(
        TimelinePoint(date: dates.last, cumulativeCount: dates.length),
      );
    }

    return points;
  }

  /// Get platform distribution
  Future<PlatformDistribution> _getPlatformDistribution(String userId) async {
    try {
      final response = await _client.rpc(
        'get_platform_achievement_counts',
        params: {'p_user_id': userId},
      );

      final platforms = response as List<dynamic>;

      int psnCount = 0;
      int xboxCount = 0;
      int steamCount = 0;

      for (final platform in platforms) {
        final code = (platform['platform_code'] as String).toUpperCase();
        final count = platform['earned_rows'] as int;

        if (['PS5', 'PS4', 'PS3', 'PSVITA'].contains(code)) {
          psnCount += count;
        } else if (['XBOX360', 'XBOXONE', 'XBOXSERIESX'].contains(code)) {
          xboxCount += count;
        } else if (code == 'STEAM') {
          steamCount += count;
        }
      }

      return PlatformDistribution(
        psnCount: psnCount,
        xboxCount: xboxCount,
        steamCount: steamCount,
      );
    } catch (_) {
      return const PlatformDistribution(
        psnCount: 0,
        xboxCount: 0,
        steamCount: 0,
      );
    }
  }

  /// Get rarity distribution
  Future<RarityDistribution> _getRarityDistribution(String userId) async {
    try {
      final countResponse = await _client
          .from('user_achievements')
          .select('user_id')
          .eq('user_id', userId)
          .count();

      final totalCount = countResponse.count;

      int ultraRare = 0;
      int veryRare = 0;
      int rare = 0;
      int uncommon = 0;
      int common = 0;
      int veryCommon = 0;

      const batchSize = 1000;
      int offset = 0;

      while (offset < totalCount) {
        final batch = await _client
            .from('user_achievements')
            .select('achievements!inner(rarity_global)')
            .eq('user_id', userId)
            .range(offset, offset + batchSize - 1);

        for (final row in batch as List) {
          final achievement = row['achievements'] as Map<String, dynamic>?;
          final rarity = (achievement?['rarity_global'] as num?)?.toDouble();
          if (rarity == null) continue;

          if (rarity < 1) {
            ultraRare++;
          } else if (rarity < 5) {
            veryRare++;
          } else if (rarity < 10) {
            rare++;
          } else if (rarity < 25) {
            uncommon++;
          } else if (rarity < 50) {
            common++;
          } else {
            veryCommon++;
          }
        }

        offset += batchSize;
      }

      return RarityDistribution(
        ultraRare: ultraRare,
        veryRare: veryRare,
        rare: rare,
        uncommon: uncommon,
        common: common,
        veryCommon: veryCommon,
      );
    } catch (_) {
      return const RarityDistribution(
        ultraRare: 0,
        veryRare: 0,
        rare: 0,
        uncommon: 0,
        common: 0,
        veryCommon: 0,
      );
    }
  }

  /// Get trophy type breakdown (PSN only)
  Future<TrophyTypeBreakdown> _getTrophyTypeBreakdown(String userId) async {
    try {
      final countResponse = await _client
          .from('user_achievements')
          .select('user_id')
          .eq('user_id', userId)
          .inFilter('platform_id', [1, 2, 5, 9])
          .count();

      final psnCount = countResponse.count;

      int bronze = 0;
      int silver = 0;
      int gold = 0;
      int platinum = 0;

      const batchSize = 1000;
      int offset = 0;

      while (offset < psnCount) {
        final batch = await _client
            .from('user_achievements')
            .select('achievements!inner(psn_trophy_type)')
            .eq('user_id', userId)
            .inFilter('platform_id', [1, 2, 5, 9])
            .range(offset, offset + batchSize - 1);

        for (final row in batch as List) {
          final achievement = row['achievements'] as Map<String, dynamic>?;
          final tier = achievement?['psn_trophy_type'] as String?;

          switch (tier) {
            case 'bronze':
              bronze++;
              break;
            case 'silver':
              silver++;
              break;
            case 'gold':
              gold++;
              break;
            case 'platinum':
              platinum++;
              break;
          }
        }

        offset += batchSize;
      }

      return TrophyTypeBreakdown(
        bronze: bronze,
        silver: silver,
        gold: gold,
        platinum: platinum,
      );
    } catch (_) {
      return const TrophyTypeBreakdown(
        bronze: 0,
        silver: 0,
        gold: 0,
        platinum: 0,
      );
    }
  }

  /// Get monthly activity data (last 12 months)
  Future<MonthlyActivity> _getMonthlyActivity(String userId) async {
    try {
      final now = DateTime.now();
      final twelveMonthsAgo = DateTime(now.year - 1, now.month, 1);

      final countResponse = await _client
          .from('user_achievements')
          .select('user_id')
          .eq('user_id', userId)
          .gte('earned_at', twelveMonthsAgo.toIso8601String())
          .count();

      final totalCount = countResponse.count;
      final Map<String, Map<String, int>> monthData = {};

      const batchSize = 1000;
      int offset = 0;

      while (offset < totalCount) {
        final batch = await _client
            .from('user_achievements')
            .select('earned_at, platform_id')
            .eq('user_id', userId)
            .gte('earned_at', twelveMonthsAgo.toIso8601String())
            .range(offset, offset + batchSize - 1);

        for (final row in batch as List) {
          final date = DateTime.parse(row['earned_at'] as String);
          final platform = _mapPlatformIdToBucket(row['platform_id'] as int?);
          final key = '${date.year}-${date.month.toString().padLeft(2, '0')}';

          monthData[key] ??= {'psn': 0, 'xbox': 0, 'steam': 0};
          if (platform != null) {
            monthData[key]![platform] = (monthData[key]![platform] ?? 0) + 1;
          }
        }

        offset += batchSize;
      }

      final List<MonthlyDataPoint> months = [];
      for (final entry in monthData.entries) {
        final parts = entry.key.split('-');
        months.add(
          MonthlyDataPoint(
            year: int.parse(parts[0]),
            month: int.parse(parts[1]),
            psnCount: entry.value['psn'] ?? 0,
            xboxCount: entry.value['xbox'] ?? 0,
            steamCount: entry.value['steam'] ?? 0,
          ),
        );
      }

      months.sort((a, b) {
        final yearCompare = a.year.compareTo(b.year);
        if (yearCompare != 0) return yearCompare;
        return a.month.compareTo(b.month);
      });

      return MonthlyActivity(months: months);
    } catch (_) {
      return const MonthlyActivity(months: []);
    }
  }

  Future<List<_RecentAchievementActivityRow>> _getRecentActivityRows(
    String userId,
  ) async {
    final now = DateTime.now().toUtc();
    final startDate = DateTime.utc(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 29));

    final countResponse = await _client
        .from('user_achievements')
        .select('user_id')
        .eq('user_id', userId)
        .gte('earned_at', startDate.toIso8601String())
        .count();

    final totalCount = countResponse.count;
    if (totalCount <= 0) return const [];

    const batchSize = 1000;
    int offset = 0;
    final rows = <_RecentAchievementActivityRow>[];

    while (offset < totalCount) {
      final batch = await _client
          .from('user_achievements')
          .select('earned_at, platform_id')
          .eq('user_id', userId)
          .gte('earned_at', startDate.toIso8601String())
          .range(offset, offset + batchSize - 1);

      for (final row in batch as List) {
        final earnedAt = DateTime.parse(row['earned_at'] as String).toUtc();
        final platformBucket = _mapPlatformIdToBucket(
          row['platform_id'] as int?,
        );
        if (platformBucket == null) continue;
        rows.add(
          _RecentAchievementActivityRow(
            date: earnedAt,
            platformBucket: platformBucket,
          ),
        );
      }
      offset += batchSize;
    }

    return rows;
  }

  DailyTrendData _buildDailyTrendData(
    List<_RecentAchievementActivityRow> rows,
  ) {
    final now = DateTime.now().toUtc();
    final today = DateTime.utc(now.year, now.month, now.day);
    final start = today.subtract(const Duration(days: 29));

    final counters = <DateTime, Map<String, int>>{};
    for (int i = 0; i < 30; i++) {
      final day = start.add(Duration(days: i));
      counters[day] = {'psn': 0, 'xbox': 0, 'steam': 0};
    }

    for (final row in rows) {
      final key = DateTime.utc(row.date.year, row.date.month, row.date.day);
      final entry = counters[key];
      if (entry == null) continue;
      entry[row.platformBucket] = (entry[row.platformBucket] ?? 0) + 1;
    }

    final points = counters.entries.map((entry) {
      return DailyTrendPoint(
        date: entry.key,
        psnCount: entry.value['psn'] ?? 0,
        xboxCount: entry.value['xbox'] ?? 0,
        steamCount: entry.value['steam'] ?? 0,
      );
    }).toList()..sort((a, b) => a.date.compareTo(b.date));

    return DailyTrendData(points: points);
  }

  PlatformSplitTrend _buildPlatformSplitTrend(
    List<_RecentAchievementActivityRow> rows,
  ) {
    final now = DateTime.now().toUtc();
    final sevenDayStart = DateTime.utc(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 6));

    int psn7 = 0;
    int xbox7 = 0;
    int steam7 = 0;
    int psn30 = 0;
    int xbox30 = 0;
    int steam30 = 0;

    for (final row in rows) {
      switch (row.platformBucket) {
        case 'psn':
          psn30++;
          if (!row.date.isBefore(sevenDayStart)) psn7++;
          break;
        case 'xbox':
          xbox30++;
          if (!row.date.isBefore(sevenDayStart)) xbox7++;
          break;
        case 'steam':
          steam30++;
          if (!row.date.isBefore(sevenDayStart)) steam7++;
          break;
      }
    }

    return PlatformSplitTrend(
      last7Days: PlatformDistribution(
        psnCount: psn7,
        xboxCount: xbox7,
        steamCount: steam7,
      ),
      last30Days: PlatformDistribution(
        psnCount: psn30,
        xboxCount: xbox30,
        steamCount: steam30,
      ),
    );
  }

  Future<SeasonalPaceData> _getSeasonalPaceData(String userId) async {
    try {
      final weekly = await _getSeasonalPaceSnapshot(userId, 'weekly');
      final monthly = await _getSeasonalPaceSnapshot(userId, 'monthly');
      return SeasonalPaceData(weekly: weekly, monthly: monthly);
    } catch (_) {
      final now = DateTime.now().toUtc();
      return SeasonalPaceData(
        weekly: SeasonalPaceSnapshot(
          periodLabel: 'Weekly',
          periodStart: now,
          periodEnd: now.add(const Duration(days: 7)),
          currentRank: 0,
          totalPlayers: 0,
          currentGain: 0,
          projectedGain: 0,
          gapToFirst: 0,
        ),
        monthly: SeasonalPaceSnapshot(
          periodLabel: 'Monthly',
          periodStart: now,
          periodEnd: now.add(const Duration(days: 30)),
          currentRank: 0,
          totalPlayers: 0,
          currentGain: 0,
          projectedGain: 0,
          gapToFirst: 0,
        ),
      );
    }
  }

  Future<SeasonalPaceSnapshot> _getSeasonalPaceSnapshot(
    String userId,
    String periodType,
  ) async {
    final startRaw = await _client.rpc(
      'get_leaderboard_period_start',
      params: {'p_period_type': periodType},
    );
    final periodStart = DateTime.parse(startRaw.toString()).toUtc();

    final periodEnd = periodType == 'monthly'
        ? DateTime.utc(periodStart.year, periodStart.month + 1, 1)
        : periodStart.add(const Duration(days: 7));

    final response =
        await _client.rpc(
              'get_statusxp_period_leaderboard',
              params: {
                'p_period_type': periodType,
                'limit_count': 1000,
                'offset_count': 0,
              },
            )
            as List<dynamic>;

    final totalPlayers = response.length;
    final topGain = totalPlayers > 0
        ? (response.first['period_gain'] as num?)?.toInt() ?? 0
        : 0;
    final userIndex = response.indexWhere((row) => row['user_id'] == userId);
    final userGain = userIndex >= 0
        ? (response[userIndex]['period_gain'] as num?)?.toInt() ?? 0
        : 0;

    final elapsedDays = _calculateElapsedDays(periodStart, periodEnd);
    final totalDays = _calculateTotalDays(periodStart, periodEnd);
    final projected = elapsedDays > 0
        ? ((userGain / elapsedDays) * totalDays).round()
        : userGain;

    return SeasonalPaceSnapshot(
      periodLabel: periodType == 'monthly' ? 'Monthly' : 'Weekly',
      periodStart: periodStart,
      periodEnd: periodEnd,
      currentRank: userIndex >= 0 ? userIndex + 1 : 0,
      totalPlayers: totalPlayers,
      currentGain: userGain,
      projectedGain: projected,
      gapToFirst: (topGain - userGain).clamp(0, 1 << 30),
    );
  }

  int _calculateElapsedDays(DateTime start, DateTime end) {
    final now = DateTime.now().toUtc();
    if (now.isBefore(start)) return 0;
    if (now.isAfter(end)) return _calculateTotalDays(start, end);
    return (now.difference(start).inDays + 1).clamp(
      1,
      _calculateTotalDays(start, end),
    );
  }

  int _calculateTotalDays(DateTime start, DateTime end) {
    final total = end.difference(start).inDays;
    return total <= 0 ? 1 : total;
  }

  String? _mapPlatformIdToBucket(int? platformId) {
    if (platformId == null) return null;
    if ([1, 2, 5, 9].contains(platformId)) return 'psn';
    if ([10, 11, 12].contains(platformId)) return 'xbox';
    if (platformId == 4) return 'steam';
    return null;
  }
}

class _RecentAchievementActivityRow {
  final DateTime date;
  final String platformBucket;

  const _RecentAchievementActivityRow({
    required this.date,
    required this.platformBucket,
  });
}
