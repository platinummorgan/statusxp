import 'dart:developer' as developer;
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
      print('DEBUG: Fetching games for user: $userId');
      
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
            game_titles!inner(
              name, 
              cover_url
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
      
      print('DEBUG: Fetching platinum rarity for ${gameTitleIds.length} games');
      
      final Map<int, double> platinumRarityMap = {};
      final Map<int, DateTime> lastTrophyMap = {};
      
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
            print('DEBUG: Game title $gameTitleId has platinum rarity: $rarity');
          }
        }
        
        print('DEBUG: Platinum rarity map has ${platinumRarityMap.length} entries');
        
        // Fetch last trophy earned date for each game
        try {
          developer.log('DEBUG: Fetching last trophy dates...');
          final lastTrophyResponse = await _client
              .from('user_achievements')
              .select('achievement_id, earned_at, achievements!inner(game_title_id)')
              .not('earned_at', 'is', null)
              .order('earned_at', ascending: false);
          
          developer.log('DEBUG: Got response type: ${lastTrophyResponse.runtimeType}');
          developer.log('DEBUG: Response: $lastTrophyResponse');
          
          if (lastTrophyResponse is List) {
            developer.log('DEBUG: Got ${lastTrophyResponse.length} achievement records');
            
            // Group by game_title_id and take the most recent
            for (final row in lastTrophyResponse) {
              try {
                final achievementData = row['achievements'];
                developer.log('DEBUG: Achievement data: $achievementData, type: ${achievementData.runtimeType}');
                
                final gameTitleId = achievementData['game_title_id'] as int;
                final earnedAtStr = row['earned_at'] as String?;
                
                if (earnedAtStr != null && !lastTrophyMap.containsKey(gameTitleId)) {
                  final earnedAt = DateTime.tryParse(earnedAtStr);
                  if (earnedAt != null) {
                    lastTrophyMap[gameTitleId] = earnedAt;
                    developer.log('DEBUG: Added game $gameTitleId with date $earnedAt');
                  }
                }
              } catch (rowError) {
                developer.log('ERROR parsing row: $rowError');
              }
            }
          }
          
          developer.log('DEBUG: Last trophy map has ${lastTrophyMap.length} entries');
        } catch (e, stackTrace) {
          developer.log('ERROR fetching last trophy dates: $e');
          developer.log('Stack trace: $stackTrace');
        }
      }

      final games = (response as List).map((row) {
        final gameTitle = row['game_titles'] as Map<String, dynamic>;
        final platform = row['platforms'] as Map<String, dynamic>?;
        final gameTitleId = row['game_title_id'] as int;
        
        // Get platinum rarity from our map
        final platinumRarity = platinumRarityMap[gameTitleId];
        
        if (platinumRarity != null) {
          print('DEBUG: ${gameTitle['name']} has platinum rarity: $platinumRarity');
        }
        
        // Get last trophy earned date from our map
        final updatedAt = lastTrophyMap[gameTitleId];
        
        return Game(
          id: gameTitleId.toString(), // Use game_title_id, not user_games.id
          name: gameTitle['name'] as String? ?? 'Unknown Game',
          platform: platform?['code'] as String? ?? 'Unknown',
          totalTrophies: row['total_trophies'] as int? ?? 0,
          earnedTrophies: row['earned_trophies'] as int? ?? 0,
          hasPlatinum: row['has_platinum'] as bool? ?? false,
          rarityPercent: (row['completion_percent'] as num?)?.toDouble() ?? 0.0,
          platinumRarity: platinumRarity,
          cover: gameTitle['cover_url'] as String? ?? '',
          bronzeTrophies: row['bronze_trophies'] as int? ?? 0,
          silverTrophies: row['silver_trophies'] as int? ?? 0,
          goldTrophies: row['gold_trophies'] as int? ?? 0,
          platinumTrophies: row['platinum_trophies'] as int? ?? 0,
          updatedAt: updatedAt,
        );
      }).toList();

      return games;
    } catch (e, stackTrace) {
      print('ERROR fetching games: $e');
      print('Stack trace: $stackTrace');
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
}
