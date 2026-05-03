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
      final results = await Future.wait([
        _client
            .from('profiles')
            .select('username, psn_online_id, psn_avatar_url, psn_is_plus')
            .eq('id', userId)
            .maybeSingle(),
        _client
            .from('psn_leaderboard_cache')
            .select(
              'platinum_count,gold_count,silver_count,bronze_count,total_trophies,total_games',
            )
            .eq('user_id', userId)
            .maybeSingle(),
      ]);

      final profileResponse = results[0];
      final psnCache = results[1];

      final int bronzeCount;
      final int silverCount;
      final int goldCount;
      final int platinumCount;
      final int totalGames;
      final int totalTrophies;

      if (psnCache != null) {
        bronzeCount = _toInt(psnCache['bronze_count']) ?? 0;
        silverCount = _toInt(psnCache['silver_count']) ?? 0;
        goldCount = _toInt(psnCache['gold_count']) ?? 0;
        platinumCount = _toInt(psnCache['platinum_count']) ?? 0;
        totalGames = _toInt(psnCache['total_games']) ?? 0;
        totalTrophies =
            _toInt(psnCache['total_trophies']) ??
            bronzeCount + silverCount + goldCount + platinumCount;
      } else {
        final legacy = await _getStatsFromUserGames(userId);
        bronzeCount = legacy.bronzeCount;
        silverCount = legacy.silverCount;
        goldCount = legacy.goldCount;
        platinumCount = legacy.platinumCount;
        totalGames = legacy.totalGames;
        totalTrophies = legacy.totalTrophies;
      }

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
        totalPlatinums: platinumCount,
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

  Future<_LegacyStats> _getStatsFromUserGames(String userId) async {
    const psnPlatformIds = [1, 2, 5, 9];

    final gamesResponse = await _client
        .from('user_games')
        .select(
          'platform_id, bronze_trophies, silver_trophies, gold_trophies, platinum_trophies',
        )
        .eq('user_id', userId);

    final games = gamesResponse as List;
    final psnGames = games.where((row) {
      final platformId = _toInt((row as Map)['platform_id']);
      return platformId != null && psnPlatformIds.contains(platformId);
    }).toList();

    int bronzeCount = 0;
    int silverCount = 0;
    int goldCount = 0;
    int platinumCount = 0;

    for (final game in psnGames) {
      final row = game as Map;
      bronzeCount += _toInt(row['bronze_trophies']) ?? 0;
      silverCount += _toInt(row['silver_trophies']) ?? 0;
      goldCount += _toInt(row['gold_trophies']) ?? 0;
      platinumCount += _toInt(row['platinum_trophies']) ?? 0;
    }

    return _LegacyStats(
      bronzeCount: bronzeCount,
      silverCount: silverCount,
      goldCount: goldCount,
      platinumCount: platinumCount,
      totalGames: psnGames.length,
      totalTrophies: bronzeCount + silverCount + goldCount + platinumCount,
    );
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

class _LegacyStats {
  final int bronzeCount;
  final int silverCount;
  final int goldCount;
  final int platinumCount;
  final int totalGames;
  final int totalTrophies;

  const _LegacyStats({
    required this.bronzeCount,
    required this.silverCount,
    required this.goldCount,
    required this.platinumCount,
    required this.totalGames,
    required this.totalTrophies,
  });
}
