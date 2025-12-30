import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:statusxp/domain/user_stats.dart';

/// Supabase-based implementation of user statistics persistence.
/// 
/// Fetches and updates user stats from the Supabase `user_stats` table.
class SupabaseUserStatsRepository {
  final SupabaseClient _client;
  
  SupabaseUserStatsRepository(this._client);

  /// Load user statistics for a specific user.
  /// 
  /// Calculates stats from user_games table using PSN's earnedTrophies summary data.
  Future<UserStats> getUserStats(String userId) async {
    try {
      // Get all games to calculate stats
      final gamesResponse = await _client
          .from('user_games')
          .select('has_platinum, bronze_trophies, silver_trophies, gold_trophies, platinum_trophies')
          .eq('user_id', userId);
      
      final games = gamesResponse as List;
      final totalGames = games.length;
      final totalPlatinums = games.where((g) => g['has_platinum'] == true).length;
      
      // Sum trophy counts from each game's PSN summary data
      int bronzeCount = 0;
      int silverCount = 0;
      int goldCount = 0;
      int platinumCount = 0;
      
      for (final game in games) {
        bronzeCount += (game['bronze_trophies'] as int? ?? 0);
        silverCount += (game['silver_trophies'] as int? ?? 0);
        goldCount += (game['gold_trophies'] as int? ?? 0);
        platinumCount += (game['platinum_trophies'] as int? ?? 0);
      }
      
      final totalTrophies = bronzeCount + silverCount + goldCount + platinumCount;
      // Get username from profiles
      final profileResponse = await _client
          .from('profiles')
          .select('username, psn_online_id, psn_avatar_url, psn_is_plus')
          .eq('id', userId)
          .maybeSingle();
      
      final username = profileResponse?['psn_online_id'] as String? ?? 
                      profileResponse?['username'] as String? ?? 
                      'Player';
      final avatarUrl = profileResponse?['psn_avatar_url'] as String?;
      final isPsPlus = profileResponse?['psn_is_plus'] as bool? ?? false;
      
      return UserStats(
        username: username,
        avatarUrl: avatarUrl,
        isPsPlus: isPsPlus,
        totalPlatinums: totalPlatinums,
        totalGamesTracked: totalGames,
        totalTrophies: totalTrophies,
        bronzeTrophies: bronzeCount,
        silverTrophies: silverCount,
        goldTrophies: goldCount,
        platinumTrophies: platinumCount,
        hardestPlatGame: 'None',
        rarestTrophyName: 'None',
        rarestTrophyRarity: 0.0,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Update user statistics.
  /// 
  /// Upserts (insert or update) the user_stats record.
  Future<void> updateUserStats(String userId, UserStats stats) async {
    try {
      await _client.from('user_stats').upsert({
        'user_id': userId,
        'total_platinums': stats.totalPlatinums,
        'total_games': stats.totalGamesTracked,
        'total_trophies': stats.totalTrophies,
        'bronze_trophies': stats.bronzeTrophies,
        'silver_trophies': stats.silverTrophies,
        'gold_trophies': stats.goldTrophies,
        'platinum_trophies': stats.platinumTrophies,
        'hardest_platinum_game': stats.hardestPlatGame,
        'rarest_trophy_name': stats.rarestTrophyName,
        'rarest_trophy_rarity': stats.rarestTrophyRarity,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      rethrow;
    }
  }
}
