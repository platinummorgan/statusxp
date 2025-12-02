import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/user_stats.dart';

/// Supabase-based implementation of user statistics persistence.
/// 
/// Fetches and updates user stats from the Supabase `user_stats` table.
class SupabaseUserStatsRepository {
  final SupabaseClient _client;
  
  SupabaseUserStatsRepository(this._client);

  /// Load user statistics for a specific user.
  /// 
  /// Fetches from user_stats table and converts to UserStats model.
  /// Returns a default UserStats if no record exists yet.
  Future<UserStats> getUserStats(String userId) async {
    try {
      final response = await _client
          .from('user_stats')
          .select('''
            user_id,
            total_platinums,
            total_games,
            total_trophies,
            completion_percentage,
            hardest_platinum_game,
            rarest_trophy_name,
            rarest_trophy_rarity,
            profiles!inner(username)
          ''')
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
        // No stats yet, return default
        return const UserStats(
          username: 'Player',
          totalPlatinums: 0,
          totalGamesTracked: 0,
          totalTrophies: 0,
          hardestPlatGame: 'None',
          rarestTrophyName: 'None',
          rarestTrophyRarity: 0.0,
        );
      }

      final profile = response['profiles'] as Map<String, dynamic>;
      
      return UserStats(
        username: profile['username'] as String? ?? 'Player',
        totalPlatinums: response['total_platinums'] as int? ?? 0,
        totalGamesTracked: response['total_games'] as int? ?? 0,
        totalTrophies: response['total_trophies'] as int? ?? 0,
        hardestPlatGame: response['hardest_platinum_game'] as String? ?? 'None',
        rarestTrophyName: response['rarest_trophy_name'] as String? ?? 'None',
        rarestTrophyRarity: (response['rarest_trophy_rarity'] as num?)?.toDouble() ?? 0.0,
      );
    } catch (e) {
      // Return default stats on error
      return const UserStats(
        username: 'Player',
        totalPlatinums: 0,
        totalGamesTracked: 0,
        totalTrophies: 0,
        hardestPlatGame: 'None',
        rarestTrophyName: 'None',
        rarestTrophyRarity: 0.0,
      );
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
