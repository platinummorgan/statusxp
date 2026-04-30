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
  /// Calculates stats from V2 `user_progress` metadata for PSN platforms.
  Future<UserStats> getUserStats(String userId) async {
    try {
      const psnPlatformIds = [1, 2, 5, 9];

      // Read live per-game progress rows (same source sync updates).
      final gamesResponse = await _client
          .from('user_progress')
          .select('platform_id, metadata')
          .eq('user_id', userId);

      final games = gamesResponse as List;
      final psnGames = games.where((row) {
        final platformId = _toInt((row as Map)['platform_id']);
        return platformId != null && psnPlatformIds.contains(platformId);
      }).toList();
      final totalGames = psnGames.length;

      // Sum trophy counts from PSN metadata.
      int bronzeCount = 0;
      int silverCount = 0;
      int goldCount = 0;
      int platinumCount = 0;

      for (final game in psnGames) {
        final metadata = (game as Map)['metadata'];
        if (metadata is! Map) continue;
        bronzeCount += _toInt(metadata['bronze_trophies']) ?? 0;
        silverCount += _toInt(metadata['silver_trophies']) ?? 0;
        goldCount += _toInt(metadata['gold_trophies']) ?? 0;
        platinumCount += _toInt(metadata['platinum_trophies']) ?? 0;
      }

      final totalPlatinums = platinumCount;
      final totalTrophies =
          bronzeCount + silverCount + goldCount + platinumCount;
      // Get username from profiles
      final profileResponse = await _client
          .from('profiles')
          .select('username, psn_online_id, psn_avatar_url, psn_is_plus')
          .eq('id', userId)
          .maybeSingle();

      final username =
          profileResponse?['psn_online_id'] as String? ??
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

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
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
