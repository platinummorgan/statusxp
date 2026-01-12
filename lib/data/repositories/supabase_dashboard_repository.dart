import 'package:statusxp/domain/dashboard_stats.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository for fetching dashboard statistics from Supabase
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
      _getPlatformStats(userId, 'psn'),
      _getPlatformStats(userId, 'xbox'),
      _getPlatformStats(userId, 'steam'),
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
  Future<PlatformStats> _getPlatformStats(String userId, String platform) async {
    // Get achievement count for platform - need to join with achievements table
    final achievementsResponse = await _client
        .from('user_achievements')
        .select('id, achievements!inner(platform)')
        .eq('user_id', userId)
        .eq('achievements.platform', platform)
        .count();

    final achievementsCount = achievementsResponse.count;

    // Get game count for platform by joining with platforms table
    // Map platform codes: psn -> PS3,PS4,PS5,PSVITA,PSVR,PSVR2
    List<String> platformCodes;
    if (platform == 'psn') {
      platformCodes = ['PS3', 'PS4', 'PS5', 'PSVITA', 'PSVR', 'PSVR2'];
    } else if (platform == 'xbox') {
      platformCodes = ['XBOX360', 'XBOXONE', 'XBOXSERIESX'];
    } else {
      platformCodes = ['Steam'];
    }
    
    // Get game count and StatusXP for platform by joining with platforms table
    final gamesResponse = await _client
        .from('user_games')
        .select('id, statusxp_effective, platforms!inner(code)')
        .eq('user_id', userId)
        .inFilter('platforms.code', platformCodes);

    final gamesCount = (gamesResponse as List).length;
    
    // Sum statusXP for this platform
    double platformStatusXP = 0.0;
    for (final game in gamesResponse) {
      platformStatusXP += ((game['statusxp_effective'] as num?)?.toDouble() ?? 0.0);
    }

    // Get platinum count (PSN only) - need to join with achievements table
    int platinums = 0;
    if (platform == 'psn') {
      final platinumResponse = await _client
          .from('user_achievements')
          .select('id, achievements!inner(platform, psn_trophy_type)')
          .eq('user_id', userId)
          .eq('achievements.platform', 'psn')
          .eq('achievements.psn_trophy_type', 'platinum')
          .count();

      platinums = platinumResponse.count;
    }

    // Get gamerscore (Xbox only)
    int gamerscore = 0;
    if (platform == 'xbox') {
      final gamerscoreResponse = await _client
          .from('user_games')
          .select('xbox_current_gamerscore, platforms!inner(code)')
          .eq('user_id', userId)
          .inFilter('platforms.code', platformCodes);
      
      for (final game in (gamerscoreResponse as List)) {
        gamerscore += (game['xbox_current_gamerscore'] as int?) ?? 0;
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
        .select('psn_online_id, psn_avatar_url, psn_is_plus, steam_display_name, steam_avatar_url, xbox_gamertag, xbox_avatar_url, preferred_display_platform')
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

    // Determine display name based on preferred platform
    String displayName = 'Player';
    if (preferredPlatform == 'psn' && profile['psn_online_id'] != null) {
      displayName = profile['psn_online_id'] as String;
    } else if (preferredPlatform == 'steam' && profile['steam_display_name'] != null) {
      displayName = profile['steam_display_name'] as String;
    } else if (preferredPlatform == 'xbox' && profile['xbox_gamertag'] != null) {
      displayName = profile['xbox_gamertag'] as String;
    } else if (profile['psn_online_id'] != null) {
      // Fallback to PSN if preferred platform not available
      displayName = profile['psn_online_id'] as String;
    } else if (profile['steam_display_name'] != null) {
      // Fallback to Steam if PSN not available
      displayName = profile['steam_display_name'] as String;
    } else if (profile['xbox_gamertag'] != null) {
      // Fallback to Xbox if others not available
      displayName = profile['xbox_gamertag'] as String;
    }
    
    // If still "Player" (all names are NULL), try to use email
    if (displayName == 'Player') {
      try {
        final user = _client.auth.currentUser;
        final email = user?.email;
        if (email != null && email.isNotEmpty) {
          // Use first part of email before @
          displayName = email.split('@').first;
        }
      } catch (e) {
        // Ignore error, keep "Player" as fallback
      }
    }

    // Get avatar URL based on preferred platform
    String? avatarUrl;
    if (preferredPlatform == 'psn') {
      avatarUrl = profile['psn_avatar_url'] as String?;
    } else if (preferredPlatform == 'xbox') {
      avatarUrl = profile['xbox_avatar_url'] as String?;
    } else if (preferredPlatform == 'steam') {
      avatarUrl = profile['steam_avatar_url'] as String?;
    }
    // Fallback to PSN avatar if preferred platform avatar not available
    avatarUrl ??= profile['psn_avatar_url'] as String?;

    return {
      'displayName': displayName,
      'displayPlatform': preferredPlatform,
      'avatarUrl': avatarUrl,
      'isPsPlus': profile['psn_is_plus'] as bool? ?? false,
    };
  }
}
