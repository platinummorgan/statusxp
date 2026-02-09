import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository for fetching Trophy Room data
/// 
/// Provides aggregated trophy statistics for showcase features like
/// rarest platinums, newest platinums, ultra-rare trophies, and recent unlocks.
class TrophyRoomRepository {
  final SupabaseClient _client;

  TrophyRoomRepository(this._client);

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.parse(value.toString());
  }

  Future<Map<int, Map<String, dynamic>>> _loadTrophiesById(List<dynamic> trophyIds) async {
    if (trophyIds.isEmpty) return {};

    final response = await _client
        .from('trophies')
        .select('''
          id,
          name,
          tier,
          rarity_global,
          game_title_id,
          icon_url,
          proxied_icon_url
        ''')
        .inFilter('id', trophyIds);

    final map = <int, Map<String, dynamic>>{};
    for (final row in (response as List)) {
      map[_toInt(row['id'])] = row as Map<String, dynamic>;
    }
    return map;
  }

  Future<Map<int, Map<String, dynamic>>> _loadGamesById(List<int> gameTitleIds) async {
    if (gameTitleIds.isEmpty) return {};

    final response = await _client
        .from('game_titles')
        .select('id, name, cover_url, proxied_cover_url')
        .inFilter('id', gameTitleIds);

    final map = <int, Map<String, dynamic>>{};
    for (final row in (response as List)) {
      map[_toInt(row['id'])] = row as Map<String, dynamic>;
    }
    return map;
  }

  /// Get all platinum trophies earned by the user with game details
  Future<List<Map<String, dynamic>>> getPlatinumTrophies(String userId) async {
    try {
      final unlocks = await _client
          .from('user_trophies')
          .select('id, trophy_id, earned_at')
          .eq('user_id', userId)
          .order('earned_at', ascending: false);

      final unlockRows = (unlocks as List).cast<Map<String, dynamic>>();
      if (unlockRows.isEmpty) return [];

      final trophyIds = unlockRows.map((row) => row['trophy_id']).toList();
      final trophiesById = await _loadTrophiesById(trophyIds);

      final gameTitleIds = trophiesById.values
          .map((trophy) => _toInt(trophy['game_title_id']))
          .toSet()
          .toList();
      final gamesById = await _loadGamesById(gameTitleIds);

      final results = <Map<String, dynamic>>[];
      for (final row in unlockRows) {
        final trophyId = _toInt(row['trophy_id']);
        final trophy = trophiesById[trophyId];
        if (trophy == null) continue;
        if ((trophy['tier'] as String?)?.toLowerCase() != 'platinum') continue;

        final gameTitleId = _toInt(trophy['game_title_id']);
        final gameTitle = gamesById[gameTitleId];
        if (gameTitle == null) continue;

        results.add({
          'trophy_id': trophy['id'],
          'trophy_name': trophy['name'],
          'game_name': gameTitle['name'],
          'cover_url': kIsWeb
              ? (gameTitle['proxied_cover_url'] ?? gameTitle['cover_url'])
              : gameTitle['cover_url'],
          'rarity': (trophy['rarity_global'] as num?)?.toDouble() ?? 100.0,
          'earned_at': row['earned_at'],
          'icon_url': kIsWeb
              ? (trophy['proxied_icon_url'] ?? trophy['icon_url'])
              : trophy['icon_url'],
        });
      }

      return results;
    } catch (e) {
      return [];
    }
  }

  /// Get ultra-rare trophies (earned and rarity < 2%)
  Future<List<Map<String, dynamic>>> getUltraRareTrophies(String userId, {int limit = 5}) async {
    try {
      final unlocks = await _client
          .from('user_trophies')
          .select('id, trophy_id, earned_at')
          .eq('user_id', userId)
          .order('earned_at', ascending: false);

      final unlockRows = (unlocks as List).cast<Map<String, dynamic>>();
      if (unlockRows.isEmpty) return [];

      final trophyIds = unlockRows.map((row) => row['trophy_id']).toList();
      final trophiesById = await _loadTrophiesById(trophyIds);

      final gameTitleIds = trophiesById.values
          .map((trophy) => _toInt(trophy['game_title_id']))
          .toSet()
          .toList();
      final gamesById = await _loadGamesById(gameTitleIds);

      final ultraRare = <Map<String, dynamic>>[];
      for (final row in unlockRows) {
        final trophyId = _toInt(row['trophy_id']);
        final trophy = trophiesById[trophyId];
        if (trophy == null) continue;

        final rarity = (trophy['rarity_global'] as num?)?.toDouble() ?? 100.0;
        if (rarity >= 2.0) continue;

        final gameTitleId = _toInt(trophy['game_title_id']);
        final gameTitle = gamesById[gameTitleId];
        if (gameTitle == null) continue;

        ultraRare.add({
          'trophy_id': trophy['id'],
          'trophy_name': trophy['name'],
          'game_name': gameTitle['name'],
          'tier': trophy['tier'],
          'rarity': rarity,
          'earned_at': row['earned_at'],
          'icon_url': kIsWeb
              ? (trophy['proxied_icon_url'] ?? trophy['icon_url'])
              : trophy['icon_url'],
        });
      }

      ultraRare.sort((a, b) {
        final rarityA = (a['rarity'] as num?)?.toDouble() ?? 100.0;
        final rarityB = (b['rarity'] as num?)?.toDouble() ?? 100.0;
        return rarityA.compareTo(rarityB);
      });

      return ultraRare.take(limit).toList();
    } catch (e) {
      return [];
    }
  }

  /// Get recent trophies (last N earned across all games)
  Future<List<Map<String, dynamic>>> getRecentTrophies(String userId, {int limit = 10}) async {
    try {
      final unlocks = await _client
          .from('user_trophies')
          .select('id, trophy_id, earned_at')
          .eq('user_id', userId)
          .order('earned_at', ascending: false)
          .limit(limit);

      final unlockRows = (unlocks as List).cast<Map<String, dynamic>>();
      if (unlockRows.isEmpty) return [];

      final trophyIds = unlockRows.map((row) => row['trophy_id']).toList();
      final trophiesById = await _loadTrophiesById(trophyIds);

      final gameTitleIds = trophiesById.values
          .map((trophy) => _toInt(trophy['game_title_id']))
          .toSet()
          .toList();
      final gamesById = await _loadGamesById(gameTitleIds);

      final recent = <Map<String, dynamic>>[];
      for (final row in unlockRows) {
        final trophyId = _toInt(row['trophy_id']);
        final trophy = trophiesById[trophyId];
        if (trophy == null) continue;

        final gameTitleId = _toInt(trophy['game_title_id']);
        final gameTitle = gamesById[gameTitleId];
        if (gameTitle == null) continue;

        recent.add({
          'trophy_id': trophy['id'],
          'trophy_name': trophy['name'],
          'game_name': gameTitle['name'],
          'tier': trophy['tier'],
          'earned_at': row['earned_at'],
          'icon_url': kIsWeb
              ? (trophy['proxied_icon_url'] ?? trophy['icon_url'])
              : trophy['icon_url'],
        });
      }

      return recent;
    } catch (e) {
      return [];
    }
  }
}
