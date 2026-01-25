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
      _getPlatformStats(userId, 1, psnPlatforms: [1, 2, 5, 9]), // PSN (PS5=1, PS4=2, PS3=5, PSVITA=9)
      _getPlatformStats(userId, 2, xboxPlatforms: [10, 11, 12]), // Xbox (360=10, One=11, Series X=12)
      _getPlatformStats(userId, 4), // Steam (platform_id=4)
      _getUserProfile(userId),
    ]);

    final totalStatusXP = results[0] as double;
    final psnStats = results[1] as PlatformStats;
    final xboxStats = results[2] as PlatformStats;
    final steamStats = results[3] as PlatformStats;
    final profile = results[4] as Map<String, dynamic>;

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
    {List<int>? xboxPlatforms, List<int>? psnPlatforms}
  ) async {
    // Determine which platform IDs to query
    final platformIds = psnPlatforms ?? xboxPlatforms ?? [platformId];
    
    // Get achievement count for platform using V2 schema
    final achievementsResponse = await _client
        .from('user_achievements')
        .select('platform_achievement_id')
        .eq('user_id', userId)
        .inFilter('platform_id', platformIds)
        .count();

    final achievementsCount = achievementsResponse.count;

    // Get game count for platform using V2 user_progress  
    final gamesResponseList = await _client
        .from('user_progress')
        .select('platform_game_id, current_score, metadata, platform_id')
        .eq('user_id', userId)
        .inFilter('platform_id', platformIds);

    print('[DASHBOARD] Platform IDs queried: $platformIds');
    print('[DASHBOARD] Games returned: ${gamesResponseList.length}');
    if (gamesResponseList.isEmpty) {
      print('[DASHBOARD] WARNING: No games found for user_id=$userId, platform_ids=$platformIds');
    }
    
    final gamesCount = gamesResponseList.length;
    
    // Calculate StatusXP using V2 function with stack multipliers
    double platformStatusXP = 0.0;
    int platinums = 0;
    int gamerscore = 0;
    
    try {
      // Get StatusXP from V2 calculation function
      final statusxpResponse = await _client.rpc('calculate_statusxp_with_stacks', params: {
        'p_user_id': userId,
      });
      
      print('Dashboard StatusXP response: $statusxpResponse');
      
      if (statusxpResponse is List) {
        print('Dashboard StatusXP response is List with ${statusxpResponse.length} items');
        for (final game in statusxpResponse) {
          final gamePlatformId = game['platform_id'] as int?;
          final effectiveXp = game['statusxp_effective'] as int?;
          
          print('Game: platform_id=$gamePlatformId, effective_xp=$effectiveXp');
          
          if (gamePlatformId != null && effectiveXp != null) {
            if (psnPlatforms != null && psnPlatforms.contains(gamePlatformId)) {
              platformStatusXP += effectiveXp.toDouble();
              print('Added $effectiveXp to PSN StatusXP, total now: $platformStatusXP');
            } else if (xboxPlatforms != null && xboxPlatforms.contains(gamePlatformId)) {
              platformStatusXP += effectiveXp.toDouble();
              print('Added $effectiveXp to Xbox StatusXP, total now: $platformStatusXP');
            } else if (platformId == gamePlatformId) {
              platformStatusXP += effectiveXp.toDouble();
              print('Added $effectiveXp to Steam StatusXP, total now: $platformStatusXP');
            }
          }
        }
      } else {
        print('Dashboard StatusXP response is not a List: ${statusxpResponse.runtimeType}');
      }
    } catch (e) {
      print('Error calling calculate_statusxp_with_stacks: $e');
      // Fallback to old calculation
      platformStatusXP = await _calculateStatusXPFallback(userId, platformIds);
    }
    
    print('[DASHBOARD] Calculated platformStatusXP for platform $platformId: $platformStatusXP');
    
    // Don't overwrite with cache if we got a valid calculation
    if (platformStatusXP == 0.0) {
      // Get StatusXP from main leaderboard_cache as fallback only
      print('[DASHBOARD] Using leaderboard cache as fallback');
      final statusxpCache = await _client
          .from('leaderboard_cache')
          .select('total_statusxp')
          .eq('user_id', userId)
          .maybeSingle();
      
      if (statusxpCache != null) {
        final totalStatusXP = ((statusxpCache['total_statusxp'] as int?) ?? 0).toDouble();
        platformStatusXP = totalStatusXP;
        print('[DASHBOARD] StatusXP from cache: $platformStatusXP');
      }
    }
    
    // Get platform-specific stats
    if (psnPlatforms != null) {
      // PSN: Get platinum count from psn_leaderboard_cache
      final psnCache = await _client
          .from('psn_leaderboard_cache')
          .select('platinum_count')
          .eq('user_id', userId)
          .maybeSingle();
      
      if (psnCache != null) {
        platinums = (psnCache['platinum_count'] as int?) ?? 0;
        print('[DASHBOARD] PSN platinums: $platinums');
      }
    } else if (xboxPlatforms != null) {
      // Xbox: Get gamerscore from xbox_leaderboard_cache
      final xboxCache = await _client
          .from('xbox_leaderboard_cache')
          .select('gamerscore')
          .eq('user_id', userId)
          .maybeSingle();
      
      if (xboxCache != null) {
        gamerscore = (xboxCache['gamerscore'] as int?) ?? 0;
        print('[DASHBOARD] Xbox gamerscore: $gamerscore');
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

  Future<double> _calculateStatusXPFallback(String userId, List<int> platformIds) async {
    // Fallback: sum base_status_xp from earned achievements (old method)
    final statusxpResult = await _client
        .from('user_achievements')
        .select('achievements!inner(base_status_xp)')
        .eq('user_id', userId)
        .inFilter('platform_id', platformIds);
    
    double totalXP = 0.0;
    for (final row in (statusxpResult as List)) {
      final achievement = row['achievements'] as Map<String, dynamic>;
      final baseXp = (achievement['base_status_xp'] as int?) ?? 0;
      totalXP += baseXp.toDouble();
    }
    return totalXP;
  }
}
