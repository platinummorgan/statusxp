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
      final response = await _client
          .from('user_games')
          .select('user_id, profiles!inner(display_name, psn_online_id, xbox_gamertag, steam_display_name, avatar_url)')
          .order('statusxp_effective', ascending: false)
          .limit(limit);

      if ((response as List).isEmpty) {
        return [];
      }

      // Group by user_id and sum statusxp_effective
      final Map<String, Map<String, dynamic>> userMap = {};
      
      for (final row in response) {
        final userId = row['user_id'] as String;
        final statusxp = (row['statusxp_effective'] as num?)?.toInt() ?? 0;
        final profile = row['profiles'] as Map<String, dynamic>?;

        if (userMap.containsKey(userId)) {
          userMap[userId]!['score'] = (userMap[userId]!['score'] as int) + statusxp;
          userMap[userId]!['games_count'] = (userMap[userId]!['games_count'] as int) + 1;
        } else {
          final displayName = profile?['display_name'] as String? ??
              profile?['psn_online_id'] as String? ??
              profile?['xbox_gamertag'] as String? ??
              profile?['steam_display_name'] as String? ??
              'Unknown';

          userMap[userId] = {
            'user_id': userId,
            'display_name': displayName,
            'avatar_url': profile?['avatar_url'] as String?,
            'score': statusxp,
            'games_count': 1,
          };
        }
      }

      // Convert to list and sort by score
      final entries = userMap.values
          .map((data) => LeaderboardEntry.fromJson(data))
          .toList()
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
    final response = await _client
        .from('user_achievements')
        .select('''
          user_id,
          profiles!inner(display_name, psn_online_id, avatar_url),
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
          // Track unique games
          final games = userMap[userId]!['games'] as Set<int>;
          games.add(achievement?['game_title_id'] as int);
        } else {
          final displayName = profile?['display_name'] as String? ??
              profile?['psn_online_id'] as String? ??
              'Unknown';

          userMap[userId] = {
            'user_id': userId,
            'display_name': displayName,
            'avatar_url': profile?['avatar_url'] as String?,
            'score': 1,
            'games': {achievement?['game_title_id'] as int},
          };
        }
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
  }

  /// Fetch Xbox achievement leaderboard
  Future<List<LeaderboardEntry>> getXboxLeaderboard({int limit = 100}) async {
    try {
      final response = await _client
          .from('user_achievements')
          .select('''
            user_id,
            profiles!inner(display_name, xbox_gamertag, avatar_url),
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
          final displayName = profile?['display_name'] as String? ??
              profile?['xbox_gamertag'] as String? ??
              'Unknown';

          userMap[userId] = {
            'user_id': userId,
            'display_name': displayName,
            'avatar_url': profile?['avatar_url'] as String?,
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
            profiles!inner(display_name, steam_display_name, avatar_url),
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
          final displayName = profile?['display_name'] as String? ??
              profile?['steam_display_name'] as String? ??
              'Unknown';

          userMap[userId] = {
            'user_id': userId,
            'display_name': displayName,
            'avatar_url': profile?['avatar_url'] as String?,
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
