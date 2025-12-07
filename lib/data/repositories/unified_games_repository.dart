import 'package:statusxp/domain/unified_game.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository for fetching unified cross-platform game data
class UnifiedGamesRepository {
  final SupabaseClient _client;

  UnifiedGamesRepository(this._client);

  /// Fetch all games for a user, grouped by title across platforms
  Future<List<UnifiedGame>> getUnifiedGames(String userId) async {
    try {
      // Use the exact same query pattern as supabase_game_repository.dart
      final response = await _client
          .from('user_games')
          .select('''
            id,
            game_title_id,
            total_trophies,
            earned_trophies,
            has_platinum,
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

      final List<dynamic> data = response as List;
      
      if (data.isEmpty) {
        return [];
      }

      // Group games by title
      final Map<String, List<Map<String, dynamic>>> gamesByTitle = {};
      
      for (final row in data) {
        final gameTitle = row['game_titles'] as Map<String, dynamic>?;
        if (gameTitle == null) continue;
        
        final title = gameTitle['name'] as String?;
        if (title == null) continue;
        
        if (!gamesByTitle.containsKey(title)) {
          gamesByTitle[title] = [];
        }
        
        gamesByTitle[title]!.add(row as Map<String, dynamic>);
      }

      // Convert to UnifiedGame objects
      final List<UnifiedGame> unifiedGames = [];
      
      for (final entry in gamesByTitle.entries) {
        final title = entry.key;
        final platformGames = entry.value;
        
        // Get cover URL from first game (they should all be the same title)
        final gameTitle = platformGames.first['game_titles'] as Map<String, dynamic>;
        final coverUrl = gameTitle['cover_url'] as String?;
      
      // Create PlatformGameData for each platform
      final List<PlatformGameData> platforms = [];
      double totalCompletion = 0;
      
      for (final game in platformGames) {
        final platformData = game['platforms'] as Map<String, dynamic>?;
        final platform = platformData?['code'] as String? ?? 'unknown';
        final totalTrophies = game['total_trophies'] as int? ?? 0;
        final earnedTrophies = game['earned_trophies'] as int? ?? 0;
        final completion = totalTrophies > 0 
            ? (earnedTrophies / totalTrophies) * 100 
            : 0.0;
        
        totalCompletion += completion;
        
        platforms.add(PlatformGameData(
          platform: platform,
          gameId: game['id'].toString(),
          achievementsEarned: earnedTrophies,
          achievementsTotal: totalTrophies,
          completion: completion,
          hasPlatinum: game['has_platinum'] as bool? ?? false,
          bronzeCount: game['bronze_trophies'] as int? ?? 0,
          silverCount: game['silver_trophies'] as int? ?? 0,
          goldCount: game['gold_trophies'] as int? ?? 0,
          platinumCount: game['platinum_trophies'] as int? ?? 0,
        ));
      }
      
      final overallCompletion = platforms.isNotEmpty 
          ? totalCompletion / platforms.length 
          : 0.0;
      
      unifiedGames.add(UnifiedGame(
        title: title,
        coverUrl: coverUrl,
        platforms: platforms,
        overallCompletion: overallCompletion,
      ));
    }

    return unifiedGames;
    } catch (e) {
      print('Error fetching unified games: $e');
      rethrow;
    }
  }
}
