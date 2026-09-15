import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:statusxp/domain/game.dart';

import 'package:statusxp/utils/statusxp_logger.dart';

/// Supabase-based implementation of game data persistence.
///
/// Fetches and updates games from the Supabase `user_games` table,
/// joining with `game_titles` for game metadata.
class SupabaseGameRepository {
  final SupabaseClient _client;

  SupabaseGameRepository(this._client);

  /// Load all games for a specific user.
  ///
  /// Fetches from user_games and joins game_titles for name/cover data.
  /// Returns empty list if user has no games.
  Future<List<Game>> getGamesForUser(String userId) async {
    try {
      final response = await _client
          .from('user_games')
          .select('''
            id,
            user_id,
            game_title_id,
            platform_id,
            total_trophies,
            earned_trophies,
            has_platinum,
            completion_percent,
            bronze_trophies,
            silver_trophies,
            gold_trophies,
            platinum_trophies,
            last_played_at,
            last_trophy_earned_at,
            game_titles!inner(
              name, 
              cover_url,
              proxied_cover_url
            ),
            platforms(code)
          ''')
          .eq('user_id', userId);

      statusxpLog(
        'DEBUG: Got ${(response as List).length} games from database',
      );

      // Fetch platinum rarity for ALL games (don't filter by has_platinum flag)
      // because the flag may be outdated
      final gameTitleIds = (response as List)
          .map((row) => row['game_title_id'] as int)
          .toList();
      final Map<int, double> platinumRarityMap = {};

      if (gameTitleIds.isNotEmpty) {
        final rarityResponse = await _client
            .from('trophies')
            .select('game_title_id, rarity_global')
            .eq('tier', 'platinum')
            .inFilter('game_title_id', gameTitleIds);

        statusxpLog(
          'DEBUG: Got ${(rarityResponse as List).length} platinum trophy rarity records',
        );

        for (final row in (rarityResponse as List)) {
          final gameTitleId = row['game_title_id'] as int;
          final rarity = row['rarity_global'] as num?;
          if (rarity != null) {
            platinumRarityMap[gameTitleId] = rarity.toDouble();
          }
        }
      }

      final games = (response as List).map((row) {
        final gameTitle = row['game_titles'] as Map<String, dynamic>;
        final platform = row['platforms'] as Map<String, dynamic>?;
        final gameTitleId = row['game_title_id'] as int;

        // Get platinum rarity from our map
        final platinumRarity = platinumRarityMap[gameTitleId];

        if (platinumRarity != null) {}

        // Use last_trophy_earned_at from database, fallback to last_played_at
        final lastTrophyStr = row['last_trophy_earned_at'] as String?;
        statusxpLog(
          'DEBUG REPO: Game ${gameTitle['name']} - last_trophy_earned_at from DB: $lastTrophyStr',
        );
        DateTime? updatedAt = lastTrophyStr != null
            ? DateTime.tryParse(lastTrophyStr)
            : null;

        if (updatedAt == null) {
          final lastPlayedStr = row['last_played_at'] as String?;
          statusxpLog('DEBUG REPO: Fallback to last_played_at: $lastPlayedStr');
          updatedAt = lastPlayedStr != null
              ? DateTime.tryParse(lastPlayedStr)
              : null;
        }

        statusxpLog(
          'DEBUG REPO: Final updatedAt for ${gameTitle['name']}: $updatedAt',
        );

        return Game(
          id: gameTitleId.toString(), // Use game_title_id, not user_games.id
          name: gameTitle['name'] as String? ?? 'Unknown Game',
          platform: platform?['code'] as String? ?? 'Unknown',
          totalTrophies: row['total_trophies'] as int? ?? 0,
          earnedTrophies: row['earned_trophies'] as int? ?? 0,
          hasPlatinum: row['has_platinum'] as bool? ?? false,
          rarityPercent: (row['completion_percent'] as num?)?.toDouble() ?? 0.0,
          platinumRarity: platinumRarity,
          cover: kIsWeb
              ? (gameTitle['proxied_cover_url'] ?? gameTitle['cover_url'])
                        as String? ??
                    ''
              : (gameTitle['cover_url'] as String? ?? ''),
          bronzeTrophies: row['bronze_trophies'] as int? ?? 0,
          silverTrophies: row['silver_trophies'] as int? ?? 0,
          goldTrophies: row['gold_trophies'] as int? ?? 0,
          platinumTrophies: row['platinum_trophies'] as int? ?? 0,
          updatedAt: updatedAt,
        );
      }).toList();

      return games;
    } catch (e) {
      rethrow; // Don't swallow the error
    }
  }

  /// Get a single game by its ID.
  Future<Game?> getGameById(int id) async {
    try {
      final response = await _client
          .from('user_games')
          .select('''
            id,
            user_id,
            game_title_id,
            platform_id,
            total_trophies,
            earned_trophies,
            has_platinum,
            rarest_trophy_rarity,
            bronze_trophies,
            silver_trophies,
            gold_trophies,
            platinum_trophies,
            game_titles!inner(id, name, cover_image),
            platforms!inner(id, code)
          ''')
          .eq('id', id)
          .single();

      final gameTitle = response['game_titles'] as Map<String, dynamic>;
      final platform = response['platforms'] as Map<String, dynamic>;

      return Game(
        id: response['id'].toString(),
        name: gameTitle['name'] as String? ?? 'Unknown Game',
        platform: platform['code'] as String? ?? 'Unknown',
        totalTrophies: response['total_trophies'] as int? ?? 0,
        earnedTrophies: response['earned_trophies'] as int? ?? 0,
        hasPlatinum: response['has_platinum'] as bool? ?? false,
        rarityPercent:
            (response['rarest_trophy_rarity'] as num?)?.toDouble() ?? 0.0,
        cover: gameTitle['cover_image'] as String? ?? 'placeholder.png',
        bronzeTrophies: response['bronze_trophies'] as int? ?? 0,
        silverTrophies: response['silver_trophies'] as int? ?? 0,
        goldTrophies: response['gold_trophies'] as int? ?? 0,
        platinumTrophies: response['platinum_trophies'] as int? ?? 0,
      );
    } catch (e) {
      return null;
    }
  }

  /// Update an existing game's progress.
  ///
  /// Updates earned_trophies, has_platinum, and rarest_trophy_rarity.
  Future<void> updateGame(Game game) async {
    try {
      await _client
          .from('user_games')
          .update({
            'earned_trophies': game.earnedTrophies,
            'has_platinum': game.hasPlatinum,
            'rarest_trophy_rarity': game.rarityPercent,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', int.parse(game.id));
    } catch (e) {
      // Log error in production
      rethrow;
    }
  }

  /// Insert a new game for the user.
  ///
  /// Requires game_title_id and platform_id to be valid foreign keys.
  /// For now, this accepts a Game model and maps it.
  Future<void> insertGame(String userId, Game game) async {
    try {
      // Note: In a real implementation, you'd need to lookup or create
      // the game_title and platform first. For this migration, we'll
      // assume they already exist in the database.
      await _client.from('user_games').insert({
        'user_id': userId,
        'game_title_id': int.parse(
          game.id,
        ), // Assumes game.id maps to game_title_id
        'platform_id': 1, // Default platform, should be looked up
        'total_trophies': game.totalTrophies,
        'earned_trophies': game.earnedTrophies,
        'has_platinum': game.hasPlatinum,
        'rarest_trophy_rarity': game.rarityPercent,
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Delete a game by ID.
  Future<void> deleteGame(int id) async {
    try {
      await _client.from('user_games').delete().eq('id', id);
    } catch (e) {
      rethrow;
    }
  }

  /// Fetch ALL games from the catalog (not just user's games)
  ///
  /// Returns all game titles. Gets platform info from achievements.
  /// Useful for browsing/searching the full game database.
  /// Games are grouped by achievement similarity (>90% match = same game across platforms)
  Future<List<Map<String, dynamic>>> getAllGames({
    String? searchQuery,
    String? platformFilter,
    int limit = 100,
    int offset = 0,
    String? sortBy = 'name_asc',
  }) async {
    try {
      // Do not use grouped_games_cache here. Production exposes it as a
      // regular view, so querying it can regroup the full catalog and count
      // every achievement before applying LIMIT, regularly hitting 57014.
      // The browser only needs game metadata; detail pages load achievements.
      final platformRows = await _client
          .from('platforms')
          .select('id,code,name');
      final platformList = (platformRows as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      final filterPlatformIds = _platformIdsForFamily(
        platformList,
        platformFilter,
      );

      var query = _client
          .from('games')
          .select('platform_id,platform_game_id,name,cover_url');
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        query = query.ilike('name', '%${searchQuery.trim()}%');
      }
      if (platformFilter != null && platformFilter.isNotEmpty) {
        // An empty family must return no rows, never silently fall back to All.
        if (filterPlatformIds.isEmpty) return [];
        query = query.inFilter('platform_id', filterPlatformIds);
      }

      final response = await query
          .order('name', ascending: sortBy != 'name_desc')
          .range(offset, offset + limit - 1);

      final platformById = <int, Map<String, dynamic>>{
        for (final row in platformList)
          if (row['id'] is num) (row['id'] as num).toInt(): row,
      };

      final games = (response as List).map((game) {
        final platformId = (game['platform_id'] as num).toInt();
        final gameId = game['platform_game_id'].toString();
        final platform = platformById[platformId];
        final platformCode = platform?['code']?.toString() ?? 'unknown';

        return {
          'id': gameId,
          'platform_id': platformId,
          'platform_game_id': gameId,
          'group_id': '${game['name']}'.trim().toLowerCase(),
          'name': game['name'],
          'cover_url': game['cover_url'],
          'proxied_cover_url': game['cover_url'],
          'platforms': {
            'code': platformCode,
            'name': platform?['name'] ?? platformCode,
          },
          'all_platforms': [platformCode],
          'platform_names': [platform?['name']?.toString() ?? platformCode],
          'platform_ids': [platformId],
          'platform_game_ids': [gameId],
          'total_achievements': null,
        };
      }).toList();

      return games.cast<Map<String, dynamic>>();
    } catch (e) {
      rethrow;
    }
  }

  /// Get total count of games in catalog
  Future<int> getTotalGamesCount({
    String? searchQuery,
    String? platformFilter,
  }) async {
    try {
      PostgrestFilterBuilder query = _client
          .from('games')
          .select('platform_id');

      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.ilike('name', '%$searchQuery%');
      }

      if (platformFilter != null && platformFilter.isNotEmpty) {
        final rows = await _client.from('platforms').select('id,code,name');
        final platformIds = _platformIdsForFamily(
          (rows as List)
              .map((row) => Map<String, dynamic>.from(row as Map))
              .toList(),
          platformFilter,
        );
        if (platformIds.isEmpty) return 0;
        query = query.inFilter('platform_id', platformIds);
      }

      final response = await query;
      return (response as List).length;
    } catch (e) {
      return 0;
    }
  }

  List<int> _platformIdsForFamily(
    List<Map<String, dynamic>> platforms,
    String? family,
  ) {
    if (family == null || family.isEmpty) return const [];
    final normalizedFamily = family.toLowerCase();

    return platforms
        .where((platform) {
          final code = platform['code']?.toString().toLowerCase() ?? '';
          final name = platform['name']?.toString().toLowerCase() ?? '';
          return switch (normalizedFamily) {
            'psn' =>
              code.startsWith('ps') ||
                  code.contains('playstation') ||
                  name.contains('playstation'),
            'xbox' => code.contains('xbox') || name.contains('xbox'),
            'steam' => code.contains('steam') || name.contains('steam'),
            _ => code == normalizedFamily,
          };
        })
        .map((platform) => (platform['id'] as num).toInt())
        .toList();
  }
}
