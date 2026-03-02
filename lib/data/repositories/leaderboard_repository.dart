import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:statusxp/domain/hall_of_fame_entry.dart';
import 'package:statusxp/domain/leaderboard_entry.dart';
import 'package:statusxp/domain/seasonal_leaderboard_entry.dart';
import 'package:statusxp/domain/seasonal_user_breakdown.dart';
import 'package:statusxp/ui/screens/leaderboard_screen.dart';

/// Leaderboard Repository - Fetches global rankings
class LeaderboardRepository {
  final SupabaseClient _client;

  LeaderboardRepository(this._client);

  /// Fetch StatusXP leaderboard (all platforms combined) with rank movement
  Future<List<LeaderboardEntry>> getStatusXPLeaderboard({
    int limit = 100,
  }) async {
    try {
      // Use new RPC function that includes rank movement tracking
      final response = await _client.rpc(
        'get_leaderboard_with_movement',
        params: {'limit_count': limit, 'offset_count': 0},
      );

      if ((response as List).isEmpty) {
        return [];
      }

      // Convert response to LeaderboardEntry objects
      final entries = <LeaderboardEntry>[];

      for (final row in response) {
        final userId = row['user_id'] as String;
        final displayName = row['display_name'] as String? ?? 'Unknown';
        final avatarUrl = row['avatar_url'] as String?;
        final statusxp = ((row['total_statusxp'] as num?)?.toDouble() ?? 0.0)
            .toInt();
        final potentialStatusXP =
            ((row['potential_statusxp'] as num?)?.toDouble() ?? 0.0).toInt();
        final gameCount = (row['total_game_entries'] as int?) ?? 0;
        final previousRank = row['previous_rank'] as int?;
        final rankChange = (row['rank_change'] as int?) ?? 0;
        final isNew = (row['is_new'] as bool?) ?? false;

        entries.add(
          LeaderboardEntry.fromJson({
            'user_id': userId,
            'display_name': displayName,
            'avatar_url': avatarUrl,
            'score': statusxp,
            'potential_score': potentialStatusXP,
            'games_count': gameCount,
            'previous_rank': previousRank,
            'rank_change': rankChange,
            'is_new': isNew,
          }),
        );
      }

      return entries;
    } catch (e) {
      rethrow;
    }
  }

  /// Fetch Platinum trophy leaderboard (PSN only) with rank movement
  Future<List<LeaderboardEntry>> getPlatinumLeaderboard({
    int limit = 100,
  }) async {
    try {
      // Use new RPC function that includes rank movement tracking
      final response = await _client.rpc(
        'get_psn_leaderboard_with_movement',
        params: {'limit_count': limit, 'offset_count': 0},
      );

      if ((response as List).isEmpty) {
        return [];
      }

      // Convert response to LeaderboardEntry objects
      final entries = <LeaderboardEntry>[];

      for (final row in response) {
        final userId = row['user_id'] as String;
        final displayName = row['display_name'] as String? ?? 'Unknown';
        final avatarUrl = row['avatar_url'] as String?;
        final platinumCount = (row['platinum_count'] as int?) ?? 0;
        final goldCount = (row['gold_count'] as int?) ?? 0;
        final silverCount = (row['silver_count'] as int?) ?? 0;
        final bronzeCount = (row['bronze_count'] as int?) ?? 0;
        final totalTrophies = (row['total_trophies'] as int?) ?? 0;
        final possiblePlatinum = (row['possible_platinum'] as int?) ?? 0;
        final possibleGold = (row['possible_gold'] as int?) ?? 0;
        final possibleSilver = (row['possible_silver'] as int?) ?? 0;
        final possibleBronze = (row['possible_bronze'] as int?) ?? 0;
        final gameCount = (row['total_games'] as int?) ?? 0;
        final previousRank = row['previous_rank'] as int?;
        final rankChange = (row['rank_change'] as int?) ?? 0;
        final isNew = (row['is_new'] as bool?) ?? false;

        entries.add(
          LeaderboardEntry.fromJson({
            'user_id': userId,
            'display_name': displayName,
            'avatar_url': avatarUrl,
            'score': platinumCount,
            'platinum_count': platinumCount,
            'gold_count': goldCount,
            'silver_count': silverCount,
            'bronze_count': bronzeCount,
            'total_trophies': totalTrophies,
            'possible_platinum': possiblePlatinum,
            'possible_gold': possibleGold,
            'possible_silver': possibleSilver,
            'possible_bronze': possibleBronze,
            'games_count': gameCount,
            'previous_rank': previousRank,
            'rank_change': rankChange,
            'is_new': isNew,
          }),
        );
      }

      return entries;
    } catch (e) {
      // Fallback to old method if RPC doesn't exist yet
      return _getPlatinumLeaderboardFallback(limit: limit);
    }
  }

  Future<List<LeaderboardEntry>> _getPlatinumLeaderboardFallback({
    int limit = 100,
  }) async {
    final response = await _client
        .from('psn_leaderboard_cache')
        .select(
          'user_id,display_name,avatar_url,platinum_count,gold_count,silver_count,bronze_count,total_trophies,total_games',
        )
        .order('platinum_count', ascending: false)
        .order('gold_count', ascending: false)
        .order('silver_count', ascending: false)
        .order('bronze_count', ascending: false)
        .limit(limit);

    if ((response as List).isEmpty) {
      return [];
    }

    final entries = (response as List).map((row) {
      return LeaderboardEntry.fromJson({
        'user_id': row['user_id'],
        'display_name': row['display_name'],
        'avatar_url': row['avatar_url'],
        'score': (row['platinum_count'] as num?)?.toInt() ?? 0,
        'platinum_count': (row['platinum_count'] as num?)?.toInt() ?? 0,
        'gold_count': (row['gold_count'] as num?)?.toInt() ?? 0,
        'silver_count': (row['silver_count'] as num?)?.toInt() ?? 0,
        'bronze_count': (row['bronze_count'] as num?)?.toInt() ?? 0,
        'total_trophies': (row['total_trophies'] as num?)?.toInt() ?? 0,
        'games_count': (row['total_games'] as num?)?.toInt() ?? 0,
      });
    }).toList();

    return entries;
  }

  /// Fetch Xbox achievement leaderboard with rank movement
  Future<List<LeaderboardEntry>> getXboxLeaderboard({int limit = 100}) async {
    try {
      // Use new RPC function that includes rank movement tracking
      final response = await _client.rpc(
        'get_xbox_leaderboard_with_movement',
        params: {'limit_count': limit, 'offset_count': 0},
      );

      if ((response as List).isEmpty) {
        print('⚠️ Xbox leaderboard cache is empty');
        return [];
      }

      print('✅ Xbox leaderboard: ${response.length} entries loaded');

      // Convert response to LeaderboardEntry objects
      final entries = <LeaderboardEntry>[];

      for (final row in response) {
        final userId = row['user_id'] as String;
        final displayName = row['display_name'] as String? ?? 'Unknown';
        final avatarUrl = row['avatar_url'] as String?;
        final gamerscore = (row['gamerscore'] as int?) ?? 0;
        final potentialGamerscore = (row['potential_gamerscore'] as int?) ?? 0;
        final gameCount = (row['total_games'] as int?) ?? 0;
        final previousRank = row['previous_rank'] as int?;
        final rankChange = (row['rank_change'] as int?) ?? 0;
        final isNew = (row['is_new'] as bool?) ?? false;

        entries.add(
          LeaderboardEntry.fromJson({
            'user_id': userId,
            'display_name': displayName,
            'avatar_url': avatarUrl,
            'score': gamerscore,
            'potential_score': potentialGamerscore,
            'games_count': gameCount,
            'previous_rank': previousRank,
            'rank_change': rankChange,
            'is_new': isNew,
          }),
        );
      }

      return entries;
    } catch (e) {
      print('❌ Xbox leaderboard error: $e');
      // Fallback to old method if RPC doesn't exist yet
      return _getXboxLeaderboardFallback(limit: limit);
    }
  }

  Future<List<LeaderboardEntry>> _getXboxLeaderboardFallback({
    int limit = 100,
  }) async {
    try {
      final response = await _client
          .from('xbox_leaderboard_cache')
          .select(
            'user_id,display_name,avatar_url,gamerscore,achievement_count,total_games',
          )
          .order('gamerscore', ascending: false)
          .order('achievement_count', ascending: false)
          .limit(limit);

      if ((response as List).isEmpty) {
        return [];
      }

      final entries = (response as List).map((row) {
        return LeaderboardEntry.fromJson({
          'user_id': row['user_id'],
          'display_name': row['display_name'],
          'avatar_url': row['avatar_url'],
          'score': (row['gamerscore'] as num?)?.toInt() ?? 0,
          'games_count': (row['total_games'] as num?)?.toInt() ?? 0,
        });
      }).toList();

      return entries;
    } catch (e) {
      rethrow;
    }
  }

  /// Fetch Steam achievement leaderboard with rank movement
  Future<List<LeaderboardEntry>> getSteamLeaderboard({int limit = 100}) async {
    try {
      // Use new RPC function that includes rank movement tracking
      final response = await _client.rpc(
        'get_steam_leaderboard_with_movement',
        params: {'limit_count': limit, 'offset_count': 0},
      );

      if ((response as List).isEmpty) {
        return [];
      }

      // Convert response to LeaderboardEntry objects
      final entries = <LeaderboardEntry>[];

      for (final row in response) {
        final userId = row['user_id'] as String;
        final displayName = row['display_name'] as String? ?? 'Unknown';
        final avatarUrl = row['avatar_url'] as String?;
        final achievementCount = (row['achievement_count'] as int?) ?? 0;
        final potentialAchievements =
            (row['potential_achievements'] as int?) ?? 0;
        final gameCount = (row['total_games'] as int?) ?? 0;
        final previousRank = row['previous_rank'] as int?;
        final rankChange = (row['rank_change'] as int?) ?? 0;
        final isNew = (row['is_new'] as bool?) ?? false;

        entries.add(
          LeaderboardEntry.fromJson({
            'user_id': userId,
            'display_name': displayName,
            'avatar_url': avatarUrl,
            'score': achievementCount,
            'potential_score': potentialAchievements,
            'games_count': gameCount,
            'previous_rank': previousRank,
            'rank_change': rankChange,
            'is_new': isNew,
          }),
        );
      }

      return entries;
    } catch (e) {
      // Fallback to old method if RPC doesn't exist yet
      return _getSteamLeaderboardFallback(limit: limit);
    }
  }

  Future<List<LeaderboardEntry>> _getSteamLeaderboardFallback({
    int limit = 100,
  }) async {
    try {
      final response = await _client
          .from('steam_leaderboard_cache')
          .select(
            'user_id,display_name,avatar_url,achievement_count,total_games',
          )
          .order('achievement_count', ascending: false)
          .order('total_games', ascending: false)
          .limit(limit);

      if ((response as List).isEmpty) {
        return [];
      }

      final entries = (response as List).map((row) {
        return LeaderboardEntry.fromJson({
          'user_id': row['user_id'],
          'display_name': row['display_name'],
          'avatar_url': row['avatar_url'],
          'score': (row['achievement_count'] as num?)?.toInt() ?? 0,
          'games_count': (row['total_games'] as num?)?.toInt() ?? 0,
        });
      }).toList();

      return entries;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<SeasonalLeaderboardEntry>> getStatusXPSeasonalLeaderboard({
    required LeaderboardPeriodType periodType,
    int limit = 100,
    int offset = 0,
  }) async {
    final response = await _client.rpc(
      'get_statusxp_period_leaderboard',
      params: {
        'p_period_type': _periodTypeToSql(periodType),
        'limit_count': limit,
        'offset_count': offset,
      },
    );

    return (response as List).map((row) {
      return SeasonalLeaderboardEntry(
        userId: row['user_id'] as String,
        displayName: row['display_name'] as String? ?? 'Player',
        avatarUrl: row['avatar_url'] as String?,
        periodGain: (row['period_gain'] as num?)?.toInt() ?? 0,
        currentScore: (row['current_total'] as num?)?.toInt() ?? 0,
        baselineScore: (row['baseline_total'] as num?)?.toInt() ?? 0,
        gamesCount: (row['total_game_entries'] as num?)?.toInt() ?? 0,
      );
    }).toList();
  }

  Future<List<SeasonalLeaderboardEntry>> getPSNSeasonalLeaderboard({
    required LeaderboardPeriodType periodType,
    int limit = 100,
    int offset = 0,
  }) async {
    final response = await _client.rpc(
      'get_psn_period_leaderboard',
      params: {
        'p_period_type': _periodTypeToSql(periodType),
        'limit_count': limit,
        'offset_count': offset,
      },
    );

    return (response as List).map((row) {
      final platinumCount = (row['platinum_count'] as num?)?.toInt() ?? 0;
      return SeasonalLeaderboardEntry(
        userId: row['user_id'] as String,
        displayName: row['display_name'] as String? ?? 'Player',
        avatarUrl: row['avatar_url'] as String?,
        periodGain: (row['period_gain'] as num?)?.toInt() ?? 0,
        currentScore: platinumCount,
        baselineScore:
            platinumCount - ((row['period_gain'] as num?)?.toInt() ?? 0),
        gamesCount: (row['total_games'] as num?)?.toInt() ?? 0,
        platinumCount: platinumCount,
        goldCount: (row['gold_count'] as num?)?.toInt() ?? 0,
        silverCount: (row['silver_count'] as num?)?.toInt() ?? 0,
        bronzeCount: (row['bronze_count'] as num?)?.toInt() ?? 0,
        totalTrophies: (row['total_trophies'] as num?)?.toInt() ?? 0,
      );
    }).toList();
  }

  Future<List<SeasonalLeaderboardEntry>> getXboxSeasonalLeaderboard({
    required LeaderboardPeriodType periodType,
    int limit = 100,
    int offset = 0,
  }) async {
    final response = await _client.rpc(
      'get_xbox_period_leaderboard',
      params: {
        'p_period_type': _periodTypeToSql(periodType),
        'limit_count': limit,
        'offset_count': offset,
      },
    );

    return (response as List).map((row) {
      final gamerscore = (row['gamerscore'] as num?)?.toInt() ?? 0;
      final gain = (row['period_gain'] as num?)?.toInt() ?? 0;
      return SeasonalLeaderboardEntry(
        userId: row['user_id'] as String,
        displayName: row['display_name'] as String? ?? 'Player',
        avatarUrl: row['avatar_url'] as String?,
        periodGain: gain,
        currentScore: gamerscore,
        baselineScore: gamerscore - gain,
        gamesCount: (row['total_games'] as num?)?.toInt() ?? 0,
        potentialScore: (row['potential_gamerscore'] as num?)?.toInt() ?? 0,
      );
    }).toList();
  }

  Future<List<SeasonalLeaderboardEntry>> getSteamSeasonalLeaderboard({
    required LeaderboardPeriodType periodType,
    int limit = 100,
    int offset = 0,
  }) async {
    final response = await _client.rpc(
      'get_steam_period_leaderboard',
      params: {
        'p_period_type': _periodTypeToSql(periodType),
        'limit_count': limit,
        'offset_count': offset,
      },
    );

    return (response as List).map((row) {
      final achievements = (row['achievement_count'] as num?)?.toInt() ?? 0;
      final gain = (row['period_gain'] as num?)?.toInt() ?? 0;
      return SeasonalLeaderboardEntry(
        userId: row['user_id'] as String,
        displayName: row['display_name'] as String? ?? 'Player',
        avatarUrl: row['avatar_url'] as String?,
        periodGain: gain,
        currentScore: achievements,
        baselineScore: achievements - gain,
        gamesCount: (row['total_games'] as num?)?.toInt() ?? 0,
        potentialScore: (row['potential_achievements'] as num?)?.toInt() ?? 0,
      );
    }).toList();
  }

  Future<SeasonalUserBreakdownData> getSeasonalUserBreakdown({
    required String targetUserId,
    required SeasonalBoardType boardType,
    required LeaderboardPeriodType periodType,
    int limit = 200,
    int offset = 0,
  }) async {
    final periodTypeSql = _periodTypeToSql(periodType);
    final boardTypeSql = _boardTypeToSql(boardType);

    final startRaw = await _client.rpc(
      'get_leaderboard_period_start',
      params: {'p_period_type': periodTypeSql},
    );

    final periodStart = DateTime.parse(startRaw.toString()).toUtc();
    final periodEnd = periodType == LeaderboardPeriodType.monthly
        ? DateTime.utc(periodStart.year, periodStart.month + 1, 1)
        : periodStart.add(const Duration(days: 7));

    final response = await _client.rpc(
      'get_user_seasonal_game_breakdown',
      params: {
        'p_target_user_id': targetUserId,
        'p_board_type': boardTypeSql,
        'p_period_type': periodTypeSql,
        'limit_count': limit,
        'offset_count': offset,
      },
    );

    final contributions = (response as List).map((row) {
      return SeasonalGameContribution(
        platformId: (row['platform_id'] as num?)?.toInt() ?? 0,
        platformGameId: row['platform_game_id'] as String? ?? '',
        gameName: row['game_name'] as String? ?? 'Unknown Game',
        coverUrl: row['cover_url'] as String?,
        periodGain: (row['period_gain'] as num?)?.toInt() ?? 0,
        earnedCount: (row['earned_count'] as num?)?.toInt() ?? 0,
      );
    }).toList();

    return SeasonalUserBreakdownData(
      periodStart: periodStart,
      periodEnd: periodEnd,
      contributions: contributions,
    );
  }

  Future<List<HallOfFameEntry>> getHallOfFame({
    required LeaderboardPeriodType periodType,
    SeasonalBoardType? boardType,
    int limit = 120,
  }) async {
    final response = await _client.rpc(
      'get_leaderboard_hall_of_fame',
      params: {
        'p_period_type': _periodTypeToSql(periodType),
        'p_leaderboard_type': boardType != null
            ? _boardTypeToSql(boardType)
            : null,
        'limit_count': limit,
      },
    );

    return (response as List).map(_mapHallOfFameRow).toList();
  }

  Future<List<HallOfFameEntry>> getLatestPeriodWinners({
    required LeaderboardPeriodType periodType,
  }) async {
    final response = await _client.rpc(
      'get_leaderboard_hall_of_fame',
      params: {
        'p_period_type': _periodTypeToSql(periodType),
        'p_leaderboard_type': null,
        'limit_count': 40,
      },
    );
    final entries = (response as List).map(_mapHallOfFameRow).toList();
    if (entries.isEmpty) return const [];

    final latestPeriodStart = entries.first.periodStart;
    return entries
        .where((entry) => entry.periodStart == latestPeriodStart)
        .toList();
  }

  HallOfFameEntry _mapHallOfFameRow(dynamic row) {
    return HallOfFameEntry(
      boardType: _boardTypeFromSql(row['leaderboard_type'] as String?),
      periodType: _periodTypeFromSql(row['period_type'] as String?),
      periodStart: DateTime.parse(row['period_start'] as String).toUtc(),
      periodEnd: DateTime.parse(row['period_end'] as String).toUtc(),
      winnerUserId: row['winner_user_id'] as String,
      winnerDisplayName: row['winner_display_name'] as String? ?? 'Player',
      winnerAvatarUrl: row['winner_avatar_url'] as String?,
      winnerGain: (row['winner_gain'] as num?)?.toInt() ?? 0,
      winnerCurrentScore: (row['winner_current_score'] as num?)?.toInt() ?? 0,
    );
  }

  String _periodTypeToSql(LeaderboardPeriodType periodType) {
    return periodType == LeaderboardPeriodType.monthly ? 'monthly' : 'weekly';
  }

  LeaderboardPeriodType _periodTypeFromSql(String? value) {
    if ((value ?? '').toLowerCase() == 'monthly') {
      return LeaderboardPeriodType.monthly;
    }
    return LeaderboardPeriodType.weekly;
  }

  String _boardTypeToSql(SeasonalBoardType boardType) {
    switch (boardType) {
      case SeasonalBoardType.statusXP:
        return 'statusxp';
      case SeasonalBoardType.platinums:
        return 'psn';
      case SeasonalBoardType.xbox:
        return 'xbox';
      case SeasonalBoardType.steam:
        return 'steam';
    }
  }

  SeasonalBoardType _boardTypeFromSql(String? value) {
    switch ((value ?? '').toLowerCase()) {
      case 'psn':
        return SeasonalBoardType.platinums;
      case 'xbox':
        return SeasonalBoardType.xbox;
      case 'steam':
        return SeasonalBoardType.steam;
      case 'statusxp':
      default:
        return SeasonalBoardType.statusXP;
    }
  }
}

/// Provider for leaderboard repository
final leaderboardRepositoryProvider = Provider<LeaderboardRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return LeaderboardRepository(client);
});

/// Supabase client provider (imported from statusxp_providers)
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Provider for specific leaderboard type
final leaderboardProvider =
    FutureProvider.family<List<LeaderboardEntry>, LeaderboardType>((
      ref,
      type,
    ) async {
      final repository = ref.watch(leaderboardRepositoryProvider);

      switch (type) {
        case LeaderboardType.statusXP:
          return repository.getStatusXPLeaderboard();
        case LeaderboardType.platinums:
          return repository.getPlatinumLeaderboard();
        case LeaderboardType.xboxAchievements:
          return repository.getXboxLeaderboard();
        case LeaderboardType.steamAchievements:
          return repository.getSteamLeaderboard();
      }
    });

final seasonalLeaderboardProvider =
    FutureProvider.family<
      List<SeasonalLeaderboardEntry>,
      SeasonalLeaderboardQuery
    >((ref, query) async {
      final repository = ref.watch(leaderboardRepositoryProvider);

      switch (query.boardType) {
        case SeasonalBoardType.statusXP:
          return repository.getStatusXPSeasonalLeaderboard(
            periodType: query.periodType,
            limit: query.limit,
            offset: query.offset,
          );
        case SeasonalBoardType.platinums:
          return repository.getPSNSeasonalLeaderboard(
            periodType: query.periodType,
            limit: query.limit,
            offset: query.offset,
          );
        case SeasonalBoardType.xbox:
          return repository.getXboxSeasonalLeaderboard(
            periodType: query.periodType,
            limit: query.limit,
            offset: query.offset,
          );
        case SeasonalBoardType.steam:
          return repository.getSteamSeasonalLeaderboard(
            periodType: query.periodType,
            limit: query.limit,
            offset: query.offset,
          );
      }
    });

final seasonalUserBreakdownProvider =
    FutureProvider.family<
      SeasonalUserBreakdownData,
      SeasonalUserBreakdownQuery
    >((ref, query) async {
      final repository = ref.watch(leaderboardRepositoryProvider);
      return repository.getSeasonalUserBreakdown(
        targetUserId: query.targetUserId,
        boardType: query.boardType,
        periodType: query.periodType,
        limit: query.limit,
        offset: query.offset,
      );
    });

final hallOfFameProvider =
    FutureProvider.family<List<HallOfFameEntry>, LeaderboardPeriodType>((
      ref,
      periodType,
    ) async {
      final repository = ref.watch(leaderboardRepositoryProvider);
      return repository.getHallOfFame(periodType: periodType, limit: 120);
    });

final latestPeriodWinnersProvider =
    FutureProvider.family<List<HallOfFameEntry>, LeaderboardPeriodType>((
      ref,
      periodType,
    ) async {
      final repository = ref.watch(leaderboardRepositoryProvider);
      return repository.getLatestPeriodWinners(periodType: periodType);
    });
