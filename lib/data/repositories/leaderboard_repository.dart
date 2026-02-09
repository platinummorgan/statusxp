import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:statusxp/domain/hall_of_fame_entry.dart';
import 'package:statusxp/domain/leaderboard_entry.dart';
import 'package:statusxp/domain/seasonal_leaderboard_entry.dart';
import 'package:statusxp/ui/screens/leaderboard_screen.dart';

/// Leaderboard Repository - Fetches global rankings
class LeaderboardRepository {
  final SupabaseClient _client;

  LeaderboardRepository(this._client);

  /// Fetch StatusXP leaderboard (all platforms combined) with rank movement
  Future<List<LeaderboardEntry>> getStatusXPLeaderboard({int limit = 100}) async {
    try {
      // Use new RPC function that includes rank movement tracking
      final response = await _client
          .rpc('get_leaderboard_with_movement', params: {
            'limit_count': limit,
            'offset_count': 0,
          });

      if ((response as List).isEmpty) {
        return [];
      }

      // Convert response to LeaderboardEntry objects
      final entries = <LeaderboardEntry>[];
      
      for (final row in response) {
        final userId = row['user_id'] as String;
        final displayName = row['display_name'] as String? ?? 'Unknown';
        final avatarUrl = row['avatar_url'] as String?;
        final statusxp = ((row['total_statusxp'] as num?)?.toDouble() ?? 0.0).toInt();
        final potentialStatusXP = ((row['potential_statusxp'] as num?)?.toDouble() ?? 0.0).toInt();
        final gameCount = (row['total_game_entries'] as int?) ?? 0;
        final previousRank = row['previous_rank'] as int?;
        final rankChange = (row['rank_change'] as int?) ?? 0;
        final isNew = (row['is_new'] as bool?) ?? false;

        entries.add(LeaderboardEntry.fromJson({
          'user_id': userId,
          'display_name': displayName,
          'avatar_url': avatarUrl,
          'score': statusxp,
          'potential_score': potentialStatusXP,
          'games_count': gameCount,
          'previous_rank': previousRank,
          'rank_change': rankChange,
          'is_new': isNew,
        }));
      }

      return entries;
    } catch (e) {
      rethrow;
    }
  }

  /// Fetch Platinum trophy leaderboard (PSN only) with rank movement
  Future<List<LeaderboardEntry>> getPlatinumLeaderboard({int limit = 100}) async {
    try {
      // Use new RPC function that includes rank movement tracking
      final response = await _client
          .rpc('get_psn_leaderboard_with_movement', params: {
            'limit_count': limit,
            'offset_count': 0,
          });

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

        entries.add(LeaderboardEntry.fromJson({
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
        }));
      }

      return entries;
    } catch (e) {
      // Fallback to old method if RPC doesn't exist yet
      return _getPlatinumLeaderboardFallback(limit: limit);
    }
  }

  Future<List<LeaderboardEntry>> _getPlatinumLeaderboardFallback({int limit = 100}) async {
    // First get platinum counts
    final response = await _client
        .from('user_achievements')
        .select('''
          user_id,
          profiles!inner(psn_online_id, psn_avatar_url, show_on_leaderboard),
          achievements!inner(game_title_id, platform, psn_trophy_type)
        ''')
        .eq('achievements.platform', 'psn')
        .eq('achievements.psn_trophy_type', 'platinum')
        .eq('profiles.show_on_leaderboard', true);

    if ((response as List).isEmpty) {
      return [];
    }

    // Group by user_id and count platinums
    final Map<String, Map<String, dynamic>> userMap = {};

    for (final row in response) {
      final userId = row['user_id'] as String;
      final profile = row['profiles'] as Map<String, dynamic>?;
      final achievement = row['achievements'] as Map<String, dynamic>?;

      if (achievement?['psn_trophy_type'] == 'platinum') {
        if (userMap.containsKey(userId)) {
          userMap[userId]!['score'] = (userMap[userId]!['score'] as int) + 1;
        } else {
          // Use PSN-specific name and avatar
          final displayName = profile?['psn_online_id'] as String? ?? 'Unknown';
          final avatarUrl = profile?['psn_avatar_url'] as String?;

          userMap[userId] = {
            'user_id': userId,
            'display_name': displayName,
            'avatar_url': avatarUrl,
            'score': 1,
          };
        }
      }
    }

    // Get total games count for each user
    for (final userId in userMap.keys) {
      final gamesResponse = await _client
          .from('user_games')
          .select('game_title_id')
          .eq('user_id', userId);
      
      final uniqueGames = (gamesResponse as List)
          .map((row) => row['game_title_id'] as int)
          .toSet();
      
      userMap[userId]!['games'] = uniqueGames.length;
    }

    // Convert to entries
    final entries = userMap.entries.map((entry) {
      final data = entry.value;
      return LeaderboardEntry.fromJson({
        'user_id': entry.key,
        'display_name': data['display_name'],
        'avatar_url': data['avatar_url'],
        'score': data['score'],
        'games_count': data['games'],
      });
    }).toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    return entries.take(limit).toList();
  }

  /// Fetch Xbox achievement leaderboard with rank movement
  Future<List<LeaderboardEntry>> getXboxLeaderboard({int limit = 100}) async {
    try {
      // Use new RPC function that includes rank movement tracking
      final response = await _client
          .rpc('get_xbox_leaderboard_with_movement', params: {
            'limit_count': limit,
            'offset_count': 0,
          });

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
        final achievementCount = (row['achievement_count'] as int?) ?? 0;
        final gameCount = (row['total_games'] as int?) ?? 0;
        final previousRank = row['previous_rank'] as int?;
        final rankChange = (row['rank_change'] as int?) ?? 0;
        final isNew = (row['is_new'] as bool?) ?? false;

        entries.add(LeaderboardEntry.fromJson({
          'user_id': userId,
          'display_name': displayName,
          'avatar_url': avatarUrl,
          'score': gamerscore,
          'potential_score': potentialGamerscore,
          'games_count': gameCount,
          'previous_rank': previousRank,
          'rank_change': rankChange,
          'is_new': isNew,
        }));
      }

      return entries;
    } catch (e) {
      print('❌ Xbox leaderboard error: $e');
      // Fallback to old method if RPC doesn't exist yet
      return _getXboxLeaderboardFallback(limit: limit);
    }
  }

  Future<List<LeaderboardEntry>> _getXboxLeaderboardFallback({int limit = 100}) async {
    try {
      final response = await _client
          .from('user_achievements')
          .select('''
            user_id,
            profiles!inner(xbox_gamertag, xbox_avatar_url, show_on_leaderboard),
            achievements!inner(game_title_id, platform)
          ''')
          .eq('achievements.platform', 'xbox')
          .eq('profiles.show_on_leaderboard', true);

      if ((response as List).isEmpty) {
        return [];
      }

      // Group by user_id and count achievements
      final Map<String, Map<String, dynamic>> userMap = {};

      for (final row in response) {
        final userId = row['user_id'] as String;
        final profile = row['profiles'] as Map<String, dynamic>?;
        final achievement = row['achievements'] as Map<String, dynamic>?;

        if (userMap.containsKey(userId)) {
          userMap[userId]!['score'] = (userMap[userId]!['score'] as int) + 1;
          // Track unique games
          final games = userMap[userId]!['games'] as Set<int>;
          games.add(achievement?['game_title_id'] as int);
        } else {
          // Use Xbox-specific gamertag
          final displayName = profile?['xbox_gamertag'] as String? ?? 'Unknown';

          userMap[userId] = {
            'user_id': userId,
            'display_name': displayName,
            'avatar_url': profile?['xbox_avatar_url'] as String?,
            'score': 1,
            'games': {achievement?['game_title_id'] as int},
          };
        }
      }

      // Convert to entries
      final entries = userMap.entries.map((entry) {
        final data = entry.value;
        return LeaderboardEntry.fromJson({
          'user_id': entry.key,
          'display_name': data['display_name'],
          'avatar_url': data['avatar_url'],
          'score': data['score'],
          'games_count': (data['games'] as Set).length,
        });
      }).toList()
        ..sort((a, b) => b.score.compareTo(a.score));

      return entries.take(limit).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Fetch Steam achievement leaderboard with rank movement
  Future<List<LeaderboardEntry>> getSteamLeaderboard({int limit = 100}) async {
    try {
      // Use new RPC function that includes rank movement tracking
      final response = await _client
          .rpc('get_steam_leaderboard_with_movement', params: {
            'limit_count': limit,
            'offset_count': 0,
          });

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
        final potentialAchievements = (row['potential_achievements'] as int?) ?? 0;
        final gameCount = (row['total_games'] as int?) ?? 0;
        final previousRank = row['previous_rank'] as int?;
        final rankChange = (row['rank_change'] as int?) ?? 0;
        final isNew = (row['is_new'] as bool?) ?? false;

        entries.add(LeaderboardEntry.fromJson({
          'user_id': userId,
          'display_name': displayName,
          'avatar_url': avatarUrl,
          'score': achievementCount,
          'potential_score': potentialAchievements,
          'games_count': gameCount,
          'previous_rank': previousRank,
          'rank_change': rankChange,
          'is_new': isNew,
        }));
      }

      return entries;
    } catch (e) {
      // Fallback to old method if RPC doesn't exist yet
      return _getSteamLeaderboardFallback(limit: limit);
    }
  }

  Future<List<LeaderboardEntry>> _getSteamLeaderboardFallback({int limit = 100}) async {
    try {
      final response = await _client
          .from('user_achievements')
          .select('''
            user_id,
            profiles!inner(steam_display_name, steam_avatar_url, show_on_leaderboard),
            achievements!inner(game_title_id, platform)
          ''')
          .eq('achievements.platform', 'steam')
          .eq('profiles.show_on_leaderboard', true);

      if ((response as List).isEmpty) {
        return [];
      }

      // Group by user_id and count achievements
      final Map<String, Map<String, dynamic>> userMap = {};

      for (final row in response) {
        final userId = row['user_id'] as String;
        final profile = row['profiles'] as Map<String, dynamic>?;
        final achievement = row['achievements'] as Map<String, dynamic>?;

        if (userMap.containsKey(userId)) {
          userMap[userId]!['score'] = (userMap[userId]!['score'] as int) + 1;
          // Track unique games
          final games = userMap[userId]!['games'] as Set<int>;
          games.add(achievement?['game_title_id'] as int);
        } else {
          // Use Steam-specific display name
          final displayName = profile?['steam_display_name'] as String? ?? 'Unknown';

          userMap[userId] = {
            'user_id': userId,
            'display_name': displayName,
            'avatar_url': profile?['steam_avatar_url'] as String?,
            'score': 1,
            'games': {achievement?['game_title_id'] as int},
          };
        }
      }

      // Convert to entries
      final entries = userMap.entries.map((entry) {
        final data = entry.value;
        return LeaderboardEntry.fromJson({
          'user_id': entry.key,
          'display_name': data['display_name'],
          'avatar_url': data['avatar_url'],
          'score': data['score'],
          'games_count': (data['games'] as Set).length,
        });
      }).toList()
        ..sort((a, b) => b.score.compareTo(a.score));

      return entries.take(limit).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<SeasonalLeaderboardEntry>> getStatusXPSeasonalLeaderboard({
    required LeaderboardPeriodType periodType,
    int limit = 100,
    int offset = 0,
  }) async {
    final response = await _client.rpc('get_statusxp_period_leaderboard', params: {
      'p_period_type': _periodTypeToSql(periodType),
      'limit_count': limit,
      'offset_count': offset,
    });

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
    final response = await _client.rpc('get_psn_period_leaderboard', params: {
      'p_period_type': _periodTypeToSql(periodType),
      'limit_count': limit,
      'offset_count': offset,
    });

    return (response as List).map((row) {
      final platinumCount = (row['platinum_count'] as num?)?.toInt() ?? 0;
      return SeasonalLeaderboardEntry(
        userId: row['user_id'] as String,
        displayName: row['display_name'] as String? ?? 'Player',
        avatarUrl: row['avatar_url'] as String?,
        periodGain: (row['period_gain'] as num?)?.toInt() ?? 0,
        currentScore: platinumCount,
        baselineScore: platinumCount - ((row['period_gain'] as num?)?.toInt() ?? 0),
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
    final response = await _client.rpc('get_xbox_period_leaderboard', params: {
      'p_period_type': _periodTypeToSql(periodType),
      'limit_count': limit,
      'offset_count': offset,
    });

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
    final response = await _client.rpc('get_steam_period_leaderboard', params: {
      'p_period_type': _periodTypeToSql(periodType),
      'limit_count': limit,
      'offset_count': offset,
    });

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

  Future<List<HallOfFameEntry>> getHallOfFame({
    required LeaderboardPeriodType periodType,
    SeasonalBoardType? boardType,
    int limit = 200,
  }) async {
    final response = await _client.rpc('get_leaderboard_hall_of_fame', params: {
      'p_period_type': _periodTypeToSql(periodType),
      'p_leaderboard_type': boardType != null ? _boardTypeToSql(boardType) : null,
      'limit_count': limit,
    });

    return (response as List).map(_mapHallOfFameRow).toList();
  }

  Future<List<HallOfFameEntry>> getLatestPeriodWinners({
    required LeaderboardPeriodType periodType,
  }) async {
    final response = await _client.rpc('get_latest_period_winners', params: {
      'p_period_type': _periodTypeToSql(periodType),
    });
    return (response as List).map(_mapHallOfFameRow).toList();
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
final leaderboardProvider = FutureProvider.family<List<LeaderboardEntry>, LeaderboardType>(
  (ref, type) async {
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
  },
);

final seasonalLeaderboardProvider = FutureProvider.family<List<SeasonalLeaderboardEntry>, SeasonalLeaderboardQuery>(
  (ref, query) async {
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
  },
);

final hallOfFameProvider = FutureProvider.family<List<HallOfFameEntry>, LeaderboardPeriodType>(
  (ref, periodType) async {
    final repository = ref.watch(leaderboardRepositoryProvider);
    return repository.getHallOfFame(periodType: periodType, limit: 400);
  },
);

final latestPeriodWinnersProvider = FutureProvider.family<List<HallOfFameEntry>, LeaderboardPeriodType>(
  (ref, periodType) async {
    final repository = ref.watch(leaderboardRepositoryProvider);
    return repository.getLatestPeriodWinners(periodType: periodType);
  },
);
