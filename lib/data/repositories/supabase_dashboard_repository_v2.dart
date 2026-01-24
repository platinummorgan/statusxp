import 'package:statusxp/domain/dashboard_stats.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository for fetching dashboard statistics from Supabase (V2 Schema)
class SupabaseDashboardRepository {
  final SupabaseClient _client;

  SupabaseDashboardRepository(this._client);

  /// Fetches dashboard statistics for a user
  /// 
  /// Gets StatusXP totals, platform-specific achievement counts, and user profile info
  Future<DashboardStats> getDashboardStats(String userId) async {
    // Fetch all data in parallel for performance
    final results = await Future.wait([
      _getStatusXPTotal(userId),
      _getPlatformStats(userId, 1), // PSN
      _getPlatformStats(userId, 2, xboxPlatforms: [2, 3, 4]), // Xbox (includes 360, One, Series X)
      _getPlatformStats(userId, 5), // Steam
      _getUserProfile(userId),
    ]);

    final totalStatusXP = results[0] as double;
    final psnStats = results[1] as PlatformStats;
    final xboxStats = results[2] as PlatformStats;
    final steamStats = results[3] as PlatformStats;
    final profile = results[4];

    return DashboardStats(
      displayName: profile['displayName'] as String,
      displayPlatform: profile['displayPlatform'] as String,
      avatarUrl: profile['avatarUrl'] as String?,
      isPsPlus: profile['isPsPlus'] as bool? ?? false,
      totalStatusXP: totalStatusXP,
      psnStats: psnStats,
      xboxStats: xboxStats,
      steamStats: steamStats,
    );
  }

  /// Gets total StatusXP from leaderboard_cache (same source as leaderboard)
  Future<double> _getStatusXPTotal(String userId) async {
    final response = await _client
        .from('leaderboard_cache')
        .select('total_statusxp')
        .eq('user_id', userId)
        .maybeSingle();

    if (response == null) {
      return 0.0;
    }

    return ((response['total_statusxp'] as num?)?.toDouble() ?? 0.0);
  }

  /// Gets platform-specific stats
  Future<PlatformStats> _getPlatformStats(
    String userId, 
    int platformId, 
    {List<int>? xboxPlatforms}
  ) async {
    // Determine which platform IDs to query
    final platformIds = xboxPlatforms ?? [platformId];
    
    // Get achievement count for platform using V2 schema
    final achievementsResponse = await _client
        .from('user_achievements')
        .select('platform_achievement_id')
        .eq('user_id', userId)
        .inFilter('platform_id', platformIds)
        .count();

    final achievementsCount = achievementsResponse.count;

    // Get StatusXP from user_games table which has the calculated statusxp_earned field
    final gamesResponse = await _client
        .from('user_games')
        .select('platform_id, statusxp_earned, completion_percent, platinum_trophies, bronze_trophies, silver_trophies, gold_trophies, earned_trophies')
        .eq('user_id', userId)
        .inFilter('platform_id', platformIds);

    final games = gamesResponse as List;
    final gamesCount = games.length;
    
    // Sum up StatusXP and other stats
    double platformStatusXP = 0.0;
    int platinums = 0;
    int gamerscore = 0;
    
    for (final game in games) {
      // Use the pre-calculated statusxp_earned from user_games
      final statusXpEarned = ((game['statusxp_earned'] as num?)?.toDouble() ?? 0.0);
      platformStatusXP += statusXpEarned;
      
      if (platformId == 1) {
        // PSN: Count platinums
        platinums += (game['platinum_trophies'] as int?) ?? 0;
      } else if (xboxPlatforms != null) {
        // Xbox: Sum gamerscore (stored in user_progress)
        // Need to get current_score from user_progress for Xbox
        final progressResponse = await _client
            .from('user_progress')
            .select('current_score')
            .eq('user_id', userId)
            .eq('platform_id', game['platform_id'])
            .maybeSingle();
        
        if (progressResponse != null) {
          final score = (progressResponse['current_score'] as int?) ?? 0;
          gamerscore += score;
        }
      }
    }

    return PlatformStats(
      platinums: platinums,
      achievementsUnlocked: achievementsCount,
      gamerscore: gamerscore,
      gamesCount: gamesCount,
      statusXP: platformStatusXP,
    );
  }

  /// Gets user profile information
  Future<Map<String, dynamic>> _getUserProfile(String userId) async {
    // Get profile data from profiles table
    final profile = await _client
        .from('profiles')
        .select('psn_online_id, psn_avatar_url, psn_is_plus, steam_display_name, steam_avatar_url, xbox_gamertag, xbox_avatar_url, preferred_display_platform, display_name, username')
        .eq('id', userId)
        .maybeSingle();

    if (profile == null) {
      return {
        'displayName': 'Player',
        'displayPlatform': 'psn',
        'avatarUrl': null,
        'isPsPlus': false,
      };
    }

    final preferredPlatform = profile['preferred_display_platform'] as String? ?? 'psn';
    
    String displayName;
    String? avatarUrl;
    
    // Determine display name and avatar based on preferred platform
    switch (preferredPlatform) {
      case 'psn':
        displayName = profile['psn_online_id'] as String? ?? 
                      profile['display_name'] as String? ?? 
                      profile['username'] as String? ?? 
                      'Player';
        avatarUrl = profile['psn_avatar_url'] as String?;
        break;
      case 'xbox':
        displayName = profile['xbox_gamertag'] as String? ?? 
                      profile['display_name'] as String? ?? 
                      profile['username'] as String? ?? 
                      'Player';
        avatarUrl = profile['xbox_avatar_url'] as String?;
        break;
      case 'steam':
        displayName = profile['steam_display_name'] as String? ?? 
                      profile['display_name'] as String? ?? 
                      profile['username'] as String? ?? 
                      'Player';
        avatarUrl = profile['steam_avatar_url'] as String?;
        break;
      default:
        displayName = profile['display_name'] as String? ?? 
                      profile['username'] as String? ?? 
                      'Player';
        avatarUrl = null;
    }

    return {
      'displayName': displayName,
      'displayPlatform': preferredPlatform,
      'avatarUrl': avatarUrl,
      'isPsPlus': profile['psn_is_plus'] as bool? ?? false,
    };
  }
}
