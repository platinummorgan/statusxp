import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:statusxp/domain/analytics_data.dart';

/// Repository for fetching analytics data
class AnalyticsRepository {
  final SupabaseClient _client;

  AnalyticsRepository(this._client);

  /// Fetch complete analytics data for a user
  Future<AnalyticsData> getAnalyticsData(String userId) async {
    final results = await Future.wait([
      _getTimelineData(userId),
      _getPlatformDistribution(userId),
      _getRarityDistribution(userId),
      _getTrophyTypeBreakdown(userId),
      _getMonthlyActivity(userId),
    ]);

    return AnalyticsData(
      timelineData: results[0] as TrophyTimelineData,
      platformDistribution: results[1] as PlatformDistribution,
      rarityDistribution: results[2] as RarityDistribution,
      trophyTypeBreakdown: results[3] as TrophyTypeBreakdown,
      monthlyActivity: results[4] as MonthlyActivity,
    );
  }

  /// Get trophy timeline data - cumulative trophies over time
  Future<TrophyTimelineData> _getTimelineData(String userId) async {
    try {
      // Get total count first
      final countResponse = await _client
          .from('user_achievements')
          .select('id')
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

      // Fetch ALL records with platform info in batches
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

      // Separate by platform and sort
      final List<DateTime> psnDates = [];
      final List<DateTime> xboxDates = [];
      final List<DateTime> steamDates = [];
      DateTime? firstDate;
      DateTime? lastDate;

      for (final row in allData) {
        final dateStr = row['earned_at'] as String;
        final date = DateTime.parse(dateStr);
        final platformId = row['achievements']['platform_id'] as int?;
        String? platform;
        if (platformId != null) {
          if ([1, 2, 5, 9].contains(platformId)) { // PS5=1, PS4=2, PS3=5, Vita=9
            platform = 'psn';
          } else if ([10, 11, 12].contains(platformId)) {
            platform = 'xbox';
          } else if (platformId == 4) { // Steam=4
            platform = 'steam';
          }
        }
        
        firstDate ??= date;
        lastDate = date;

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

      // Build timeline points for each platform
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
    } catch (e) {
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
      points.add(TimelinePoint(
        date: dates[i],
        cumulativeCount: i + 1,
      ));
    }

    // Always include the last point
    if (points.isEmpty || points.last.cumulativeCount != dates.length) {
      points.add(TimelinePoint(
        date: dates.last,
        cumulativeCount: dates.length,
      ));
    }

    return points;
  }

  /// Get platform distribution
  Future<PlatformDistribution> _getPlatformDistribution(String userId) async {
    try {
      // Single query with JOIN to get platform names
      final response = await _client
          .rpc('get_platform_achievement_counts', params: {
            'p_user_id': userId,
          });

      // Parse results - response contains platform_code and earned_rows
      final platforms = response as List<dynamic>;
      
      int psnCount = 0;
      int xboxCount = 0;
      int steamCount = 0;
      
      for (final platform in platforms) {
        final code = (platform['platform_code'] as String).toUpperCase();
        final count = platform['earned_rows'] as int;
        
        // Map platform codes to categories
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
    } catch (e) {
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
      // Get total count
      final countResponse = await _client
          .from('user_achievements')
          .select('id')
          .eq('user_id', userId)
          .count();
      
      final totalCount = countResponse.count;
      
      int ultraRare = 0;
      int veryRare = 0;
      int rare = 0;
      int uncommon = 0;
      int common = 0;
      int veryCommon = 0;

      // Fetch in batches
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
    } catch (e) {
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
      // Get PSN count
      final countResponse = await _client
          .from('user_achievements')
          .select('id')
          .eq('user_id', userId)
          .inFilter('platform_id', [1, 2, 5, 9])
          .count();
      
      final psnCount = countResponse.count;
      
      int bronze = 0;
      int silver = 0;
      int gold = 0;
      int platinum = 0;

      // Fetch in batches
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
    } catch (e) {
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
      // Calculate date 12 months ago
      final now = DateTime.now();
      final twelveMonthsAgo = DateTime(now.year - 1, now.month, 1);
      
      // Get count for last 12 months
      final countResponse = await _client
          .from('user_achievements')
          .select('id')
          .eq('user_id', userId)
          .gte('earned_at', twelveMonthsAgo.toIso8601String())
          .count();
      
      final totalCount = countResponse.count;
      
      // Track by month and platform
      final Map<String, Map<String, int>> monthData = {};

      // Fetch in batches
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
          final platformId = row['platform_id'] as int?;
          String? platform;
          if (platformId != null) {
            if ([1, 2, 5, 9].contains(platformId)) { // PS5=1, PS4=2, PS3=5, Vita=9
              platform = 'psn';
            } else if ([10, 11, 12].contains(platformId)) {
              platform = 'xbox';
            } else if (platformId == 4) { // Steam=4
              platform = 'steam';
            }
          }
          final key = '${date.year}-${date.month.toString().padLeft(2, '0')}';
          
          monthData[key] ??= {'psn': 0, 'xbox': 0, 'steam': 0};
          
          if (platform == 'psn') {
            monthData[key]!['psn'] = (monthData[key]!['psn'] ?? 0) + 1;
          } else if (platform == 'xbox') {
            monthData[key]!['xbox'] = (monthData[key]!['xbox'] ?? 0) + 1;
          } else if (platform == 'steam') {
            monthData[key]!['steam'] = (monthData[key]!['steam'] ?? 0) + 1;
          }
        }
        
        offset += batchSize;
      }

      // Convert to list and sort
      final List<MonthlyDataPoint> months = [];
      for (final entry in monthData.entries) {
        final parts = entry.key.split('-');
        months.add(MonthlyDataPoint(
          year: int.parse(parts[0]),
          month: int.parse(parts[1]),
          psnCount: entry.value['psn'] ?? 0,
          xboxCount: entry.value['xbox'] ?? 0,
          steamCount: entry.value['steam'] ?? 0,
        ));
      }

      months.sort((a, b) {
        final yearCompare = a.year.compareTo(b.year);
        if (yearCompare != 0) return yearCompare;
        return a.month.compareTo(b.month);
      });

      return MonthlyActivity(months: months);
    } catch (e) {
      return const MonthlyActivity(months: []);
    }
  }
}
