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
    try {
      final response = await _client
          .from('leaderboard_cache')
          .select('total_statusxp')
          .eq('user_id', userId)
          .maybeSingle();

      return ((response?['total_statusxp'] as num?)?.toDouble() ?? 0.0);
    } catch (e) {
      print('[DASHBOARD] Error getting total StatusXP: $e');
      return 0.0;
    }
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
        .count(CountOption.exact);

    final achievementsCount = achievementsResponse.count ?? 0;

    // Calculate StatusXP using V2 function with stack multipliers
    double platformStatusXP = 0.0;
    int platinums = 0;
    int gamerscore = 0;
    int platformGamesCount = 0;
    
    try {
      // Get StatusXP from V2 calculation function
      final statusxpResponse = await _client.rpc('calculate_statusxp_with_stacks', params: {
        'p_user_id': userId,
      });
      
      print('[DASHBOARD] StatusXP RPC response: $statusxpResponse');
      
      if (statusxpResponse is List) {
        print('[DASHBOARD] StatusXP response is List with ${statusxpResponse.length} items');
        for (final game in statusxpResponse) {
          final rawPlatformId = game['platform_id'];
          final rawEffectiveXp = game['statusxp_effective'];

          int? gamePlatformId;
          if (rawPlatformId is int) {
            gamePlatformId = rawPlatformId;
          } else if (rawPlatformId is num) {
            gamePlatformId = rawPlatformId.toInt();
          } else if (rawPlatformId is String) {
            gamePlatformId = int.tryParse(rawPlatformId);
          }

          double? effectiveXp;
          if (rawEffectiveXp is int) {
            effectiveXp = rawEffectiveXp.toDouble();
          } else if (rawEffectiveXp is num) {
            effectiveXp = rawEffectiveXp.toDouble();
          } else if (rawEffectiveXp is String) {
            effectiveXp = double.tryParse(rawEffectiveXp);
          }
          
          // Only count this game if it belongs to one of the requested platforms
          if (gamePlatformId != null && effectiveXp != null && platformIds.contains(gamePlatformId)) {
            platformStatusXP += effectiveXp;
            platformGamesCount += 1;
            print('[DASHBOARD] Game platform_id=$gamePlatformId added $effectiveXp to StatusXP, total now: $platformStatusXP');
          }
        }
      } else {
        print('[DASHBOARD] ERROR: StatusXP response is not a List: ${statusxpResponse.runtimeType}');
      }
    } catch (e) {
      print('[DASHBOARD] Error calling calculate_statusxp_with_stacks: $e');
      platformStatusXP = 0.0;
    }
    
    final gamesCount = platformGamesCount;
    print('[DASHBOARD] Final platformStatusXP for platforms $platformIds: $platformStatusXP');
    
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
