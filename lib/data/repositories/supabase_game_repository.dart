import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:statusxp/domain/game.dart';

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

      print('DEBUG: Got ${(response as List).length} games from database');

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
        
        print('DEBUG: Got ${(rarityResponse as List).length} platinum trophy rarity records');
        
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
        
        if (platinumRarity != null) {
        }
        
        // Use last_trophy_earned_at from database, fallback to last_played_at
        final lastTrophyStr = row['last_trophy_earned_at'] as String?;
        DateTime? updatedAt = lastTrophyStr != null ? DateTime.tryParse(lastTrophyStr) : null;
        
        if (updatedAt == null) {
          final lastPlayedStr = row['last_played_at'] as String?;
          updatedAt = lastPlayedStr != null ? DateTime.tryParse(lastPlayedStr) : null;
        }
        
        return Game(
          id: gameTitleId.toString(), // Use game_title_id, not user_games.id
          name: gameTitle['name'] as String? ?? 'Unknown Game',
          platform: platform?['code'] as String? ?? 'Unknown',
          totalTrophies: row['total_trophies'] as int? ?? 0,
          earnedTrophies: row['earned_trophies'] as int? ?? 0,
          hasPlatinum: row['has_platinum'] as bool? ?? false,
          rarityPercent: (row['completion_percent'] as num?)?.toDouble() ?? 0.0,
          platinumRarity: platinumRarity,
          cover: (gameTitle['proxied_cover_url'] ?? gameTitle['cover_url']) as String? ?? '',
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
        rarityPercent: (response['rarest_trophy_rarity'] as num?)?.toDouble() ?? 0.0,
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
        'game_title_id': int.parse(game.id), // Assumes game.id maps to game_title_id
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
      await _client
          .from('user_games')
          .delete()
          .eq('id', id);
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
      // Use pre-computed achievement-matching grouping function for speed
      final response = await _client.rpc('get_grouped_games_fast', params: {
        'search_query': searchQuery,
        'platform_filter': platformFilter,
        'result_limit': limit,
        'result_offset': offset,
        'sort_by': sortBy,
      });

      final games = (response as List).map((game) {
        final platforms = (game['platforms'] as List?)?.cast<String>() ?? [];
        
        // Determine primary platform for display
        String? primaryPlatform;
        if (platforms.isNotEmpty) {
          if (platformFilter != null && platforms.contains(platformFilter)) {
            primaryPlatform = platformFilter;
          } else if (platforms.contains('steam')) {
            primaryPlatform = 'steam';
          } else if (platforms.contains('xbox')) {
            primaryPlatform = 'xbox';
          } else {
            primaryPlatform = 'psn';
          }
        }

        return {
          'id': game['primary_game_id'], // Use primary game ID from group
          'group_id': game['group_id'],
          'name': game['name'],
          'cover_url': game['proxied_cover_url'] ?? game['cover_url'],
          'platforms': primaryPlatform != null 
              ? {'code': primaryPlatform, 'name': primaryPlatform}
              : null,
          'all_platforms': platforms,
          'game_title_ids': game['game_title_ids'], // All game_title IDs in group
          'total_achievements': game['total_achievements'],
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
      dynamic query = _client
          .from('game_titles')
          .select('*');

      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.ilike('name', '%$searchQuery%');
      }

      if (platformFilter != null && platformFilter.isNotEmpty) {
        final platformResponse = await _client
            .from('platforms')
            .select('id')
            .eq('code', platformFilter)
            .maybeSingle();
        
        if (platformResponse != null) {
          query = query.eq('platform_id', platformResponse['id']);
        }
      }

      final response = await query;
      return (response as List).length;
    } catch (e) {
      return 0;
    }
  }
}
