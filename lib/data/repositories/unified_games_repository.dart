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
          final gameTitleId = platformData['game_title_id']?.toString() ?? '';
          final currentScore = ((platformData['current_score'] as num?)?.toDouble() ?? 0.0).toInt();
          final totalScore = ((platformData['total_score'] as num?)?.toDouble() ?? 0.0).toInt();
          
          // V2 composite keys
          final platformId = platformData['platform_id'] as int?;
          final platformGameId = platformData['platform_game_id']?.toString();
          
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
          
          // Parse timestamps
          final lastPlayedAtStr = platformData['last_played_at'] as String?;
          final lastTrophyEarnedAtStr = platformData['last_trophy_earned_at'] as String?;
          
          DateTime? lastPlayedAt;
          DateTime? lastTrophyEarnedAt;
          
          if (lastPlayedAtStr != null) {
            try {
              lastPlayedAt = DateTime.parse(lastPlayedAtStr);
            } catch (e) {
              print('Error parsing last_played_at: $e');
            }
          }
          
          if (lastTrophyEarnedAtStr != null) {
            try {
              lastTrophyEarnedAt = DateTime.parse(lastTrophyEarnedAtStr);
            } catch (e) {
              print('Error parsing last_trophy_earned_at: $e');
            }
          }
          
          // Get rarest achievement rarity
          final rarestRarity = (platformData['rarest_achievement_rarity'] as num?)?.toDouble();
          
          platforms.add(PlatformGameData(
            platform: platform,
            gameId: gameTitleId,
            platformId: platformId,
            platformGameId: platformGameId,
            achievementsEarned: earnedCount,
            achievementsTotal: totalCount,
            completion: completion,
            rarestAchievementRarity: rarestRarity,
            hasPlatinum: platinum > 0,
            bronzeCount: bronze,
            silverCount: silver,
            goldCount: gold,
            platinumCount: platinum,
            statusXP: statusXP,
            currentScore: currentScore,
            totalScore: totalScore,
            lastPlayedAt: lastPlayedAt,
            lastTrophyEarnedAt: lastTrophyEarnedAt,
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
