import 'package:statusxp/domain/unified_game.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository for fetching unified cross-platform game data
class UnifiedGamesRepository {
  final SupabaseClient _client;

  UnifiedGamesRepository(this._client);

  /// Fetch all games for a user, grouped by achievement similarity (>90% match)
  Future<List<UnifiedGame>> getUnifiedGames(String userId) async {
    try {
      // Use new achievement-matching grouping function
      final response = await _client.rpc('get_user_grouped_games', params: {
        'p_user_id': userId,
      });

      final List<dynamic> data = response as List;
      
      if (data.isEmpty) {
        return [];
      }

      // Convert to UnifiedGame objects
      final List<UnifiedGame> unifiedGames = [];
      
      for (final group in data) {
        final title = group['name'] as String;
        final coverUrl = (group['proxied_cover_url'] ?? group['cover_url']) as String?;
        final platformsData = (group['platforms'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        
        // Create PlatformGameData for each platform in the group
        final List<PlatformGameData> platforms = [];
        
        for (final platformData in platformsData) {
          final platform = platformData['code'] as String? ?? 'unknown';
          final completion = (platformData['completion'] as num?)?.toDouble() ?? 0.0;
          final statusXP = ((platformData['statusxp'] as num?)?.toDouble() ?? 0.0).toInt();
          final gameTitleId = (platformData['game_title_id'] as int?)?.toString() ?? '';
          
          // Get trophy/achievement counts based on platform
          final int bronze = (platformData['bronze_trophies'] as int?) ?? 0;
          final int silver = (platformData['silver_trophies'] as int?) ?? 0;
          final int gold = (platformData['gold_trophies'] as int?) ?? 0;
          final int platinum = (platformData['platinum_trophies'] as int?) ?? 0;
          
          // All platforms use earned_trophies/total_trophies for display counts
          // Xbox/Steam also populate xbox_achievements_earned/xbox_total_achievements for compatibility
          final int earnedCount = (platformData['earned_trophies'] as int?) ?? 
                                  (platformData['xbox_achievements_earned'] as int?) ?? 0;
          final int totalCount = (platformData['total_trophies'] as int?) ?? 
                                 (platformData['xbox_total_achievements'] as int?) ?? 0;
          
          platforms.add(PlatformGameData(
            platform: platform,
            gameId: gameTitleId,
            achievementsEarned: earnedCount,
            achievementsTotal: totalCount,
            completion: completion,
            rarestAchievementRarity: null, // Available in detailed view
            hasPlatinum: platinum > 0,
            bronzeCount: bronze,
            silverCount: silver,
            goldCount: gold,
            platinumCount: platinum,
            statusXP: statusXP,
            lastPlayedAt: null, // Available in group-level data
            lastTrophyEarnedAt: null,
          ));
        }
        
        // Calculate overall completion
        final overallCompletion = platforms.isNotEmpty
            ? platforms.map((p) => p.completion).reduce((a, b) => a + b) / platforms.length
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
      rethrow;
    }
  }
}
