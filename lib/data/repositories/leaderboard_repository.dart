import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:statusxp/domain/leaderboard_entry.dart';
import 'package:statusxp/ui/screens/leaderboard_screen.dart';

/// Leaderboard Repository - Fetches global rankings
class LeaderboardRepository {
  final SupabaseClient _client;

  LeaderboardRepository(this._client);

  /// Fetch StatusXP leaderboard (all platforms combined)
  Future<List<LeaderboardEntry>> getStatusXPLeaderboard({int limit = 100}) async {
    try {
      // Get all user_games data with profiles
      final response = await _client
          .from('user_games')
          .select('''
            user_id,
            game_title_id,
            statusxp_effective,
            profiles!inner(
              display_name,
              preferred_display_platform,
              psn_online_id,
              psn_avatar_url,
              xbox_gamertag,
              xbox_avatar_url,
              steam_display_name,
              steam_avatar_url
            )
          ''');

      if ((response as List).isEmpty) {
        return [];
      }

      // Group by user_id and aggregate
      final Map<String, Map<String, dynamic>> userMap = {};
      
      for (final row in response) {
        final userId = row['user_id'] as String;
        final gameId = row['game_title_id'] as int;
        final statusxp = ((row['statusxp_effective'] as num?)?.toDouble() ?? 0.0).toInt();
        final profile = row['profiles'] as Map<String, dynamic>?;

        if (userMap.containsKey(userId)) {
          // Add statusxp
          userMap[userId]!['score'] = (userMap[userId]!['score'] as int) + statusxp;
          // Track unique games (count ALL games, even if statusxp is 0)
          final games = userMap[userId]!['games'] as Set<int>;
          games.add(gameId);
        } else {
          // Get display name based on user's chosen platform
          final displayPlatform = profile?['preferred_display_platform'] as String?;
          String displayName;
          String? avatarUrl;

          if (displayPlatform == 'psn') {
            displayName = profile?['psn_online_id'] as String? ?? profile?['display_name'] as String? ?? 'Unknown';
            avatarUrl = profile?['psn_avatar_url'] as String?;
          } else if (displayPlatform == 'xbox') {
            displayName = profile?['xbox_gamertag'] as String? ?? profile?['display_name'] as String? ?? 'Unknown';
            avatarUrl = profile?['xbox_avatar_url'] as String?;
          } else if (displayPlatform == 'steam') {
            displayName = profile?['steam_display_name'] as String? ?? profile?['display_name'] as String? ?? 'Unknown';
            avatarUrl = profile?['steam_avatar_url'] as String?;
          } else {
            // Fallback
            displayName = profile?['display_name'] as String? ??
                profile?['psn_online_id'] as String? ??
                profile?['xbox_gamertag'] as String? ??
                profile?['steam_display_name'] as String? ??
                'Unknown';
            avatarUrl = profile?['psn_avatar_url'] as String? ?? profile?['xbox_avatar_url'] as String? ?? profile?['steam_avatar_url'] as String?;
          }

          userMap[userId] = {
            'user_id': userId,
            'display_name': displayName,
            'avatar_url': avatarUrl,
            'score': statusxp,
            'games': {gameId},
          };
        }
      }

      // Convert to entries with correct games count
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
      print('[LeaderboardRepository] Error fetching StatusXP leaderboard: $e');
      rethrow;
    }
  }

  /// Fetch Platinum trophy leaderboard (PSN only)
  Future<List<LeaderboardEntry>> getPlatinumLeaderboard({int limit = 100}) async {
    try {
      final response = await _client.rpc(
        'get_platinum_leaderboard',
        params: {'limit_count': limit},
      );

      if (response == null || (response as List).isEmpty) {
        // Fallback to direct query if RPC doesn't exist
        return _getPlatinumLeaderboardFallback(limit: limit);
      }

      return (response)
          .map((row) => LeaderboardEntry.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('[LeaderboardRepository] Error fetching platinum leaderboard: $e');
      // Fallback to direct query
      return _getPlatinumLeaderboardFallback(limit: limit);
    }
  }

  Future<List<LeaderboardEntry>> _getPlatinumLeaderboardFallback({int limit = 100}) async {
    // First get platinum counts
    final response = await _client
        .from('user_achievements')
        .select('''
          user_id,
          profiles!inner(psn_online_id, psn_avatar_url),
          achievements!inner(game_title_id, platform, psn_trophy_type)
        ''')
        .eq('achievements.platform', 'psn')
        .eq('achievements.psn_trophy_type', 'platinum');

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

  /// Fetch Xbox achievement leaderboard
  Future<List<LeaderboardEntry>> getXboxLeaderboard({int limit = 100}) async {
    try {
      final response = await _client
          .from('user_achievements')
          .select('''
            user_id,
            profiles!inner(xbox_gamertag, xbox_avatar_url),
            achievements!inner(game_title_id, platform)
          ''')
          .eq('achievements.platform', 'xbox');

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
      print('[LeaderboardRepository] Error fetching Xbox leaderboard: $e');
      rethrow;
    }
  }

  /// Fetch Steam achievement leaderboard
  Future<List<LeaderboardEntry>> getSteamLeaderboard({int limit = 100}) async {
    try {
      final response = await _client
          .from('user_achievements')
          .select('''
            user_id,
            profiles!inner(steam_display_name, steam_avatar_url),
            achievements!inner(game_title_id, platform)
          ''')
          .eq('achievements.platform', 'steam');

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
      print('[LeaderboardRepository] Error fetching Steam leaderboard: $e');
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
