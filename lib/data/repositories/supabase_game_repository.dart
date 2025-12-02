import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/game.dart';

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
            rarest_trophy_rarity,
            game_titles!inner(id, name, cover_image),
            platforms!inner(id, code)
          ''')
          .eq('user_id', userId);

      final games = (response as List).map((row) {
        final gameTitle = row['game_titles'] as Map<String, dynamic>;
        final platform = row['platforms'] as Map<String, dynamic>;
        
        return Game(
          id: row['id'].toString(),
          name: gameTitle['name'] as String? ?? 'Unknown Game',
          platform: platform['code'] as String? ?? 'Unknown',
          totalTrophies: row['total_trophies'] as int? ?? 0,
          earnedTrophies: row['earned_trophies'] as int? ?? 0,
          hasPlatinum: row['has_platinum'] as bool? ?? false,
          rarityPercent: (row['rarest_trophy_rarity'] as num?)?.toDouble() ?? 0.0,
          cover: gameTitle['cover_image'] as String? ?? 'placeholder.png',
        );
      }).toList();

      return games;
    } catch (e) {
      // Log error in production, return empty list for now
      return [];
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
}
