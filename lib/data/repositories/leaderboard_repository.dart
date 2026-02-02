import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:statusxp/domain/leaderboard_entry.dart';
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
