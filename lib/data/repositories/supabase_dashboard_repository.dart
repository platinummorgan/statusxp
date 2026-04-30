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
    // Fetch expensive/shared inputs once, then fan out platform reads.
    final sharedResults = await Future.wait([
      _getStatusXpRows(userId),
      _getUserProfile(userId),
    ]);

    final statusXpRows = sharedResults[0] as List<Map<String, dynamic>>;
    final profile = sharedResults[1] as Map<String, dynamic>;

    final platformResults = await Future.wait([
      _getPlatformStats(
        userId,
        1,
        statusXpRows: statusXpRows,
        psnPlatforms: [1, 2, 5, 9],
      ), // PSN (PS5=1, PS4=2, PS3=5, PSVITA=9)
      _getPlatformStats(
        userId,
        2,
        statusXpRows: statusXpRows,
        xboxPlatforms: [10, 11, 12],
      ), // Xbox (360=10, One=11, Series X=12)
      _getPlatformStats(userId, 4, statusXpRows: statusXpRows), // Steam
    ]);

    // Prefer live StatusXP computation; fall back to cache only if RPC returned nothing.
    var totalStatusXP = _sumStatusXpRows(statusXpRows);
    if (totalStatusXP <= 0) {
      totalStatusXP = await _getStatusXPTotal(userId);
    }

    final psnStats = platformResults[0];
    final xboxStats = platformResults[1];
    final steamStats = platformResults[2];

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

  Future<List<Map<String, dynamic>>> _getStatusXpRows(String userId) async {
    try {
      final response = await _client.rpc(
        'calculate_statusxp_with_stacks',
        params: {'p_user_id': userId},
      );
      if (response is List) {
        return response
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
      }
      return const <Map<String, dynamic>>[];
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  double _sumStatusXpRows(List<Map<String, dynamic>> rows) {
    double total = 0;
    for (final row in rows) {
      total += _toDouble(row['statusxp_effective']);
    }
    return total;
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
    } catch (_) {
      return 0.0;
    }
  }

  /// Gets platform-specific stats
  Future<PlatformStats> _getPlatformStats(
    String userId,
    int platformId, {
    required List<Map<String, dynamic>> statusXpRows,
    List<int>? xboxPlatforms,
    List<int>? psnPlatforms,
  }) async {
    // Determine which platform IDs to query
    final platformIds = psnPlatforms ?? xboxPlatforms ?? [platformId];

    // Get achievement count for platform using V2 schema
    final achievementsResponse = await _client
        .from('user_achievements')
        .select('platform_achievement_id')
        .eq('user_id', userId)
        .inFilter('platform_id', platformIds)
        .count(CountOption.exact);

    final achievementsCount = achievementsResponse.count;
    final progressResponse = await _client
        .from('user_progress')
        .select('current_score, metadata')
        .eq('user_id', userId)
        .inFilter('platform_id', platformIds);

    final progressRows = progressResponse as List;
    final gamesCount = progressRows.length;
    double platformStatusXP = 0.0;
    int platinums = 0;
    int gamerscore = 0;

    // Calculate platform StatusXP from shared live rows.
    for (final row in statusXpRows) {
      final rowPlatformId = _toInt(row['platform_id']);
      if (rowPlatformId != null && platformIds.contains(rowPlatformId)) {
        platformStatusXP += _toDouble(row['statusxp_effective']);
      }
    }

    // Get platform-specific stats
    if (psnPlatforms != null) {
      // PSN: Sum per-game platinum trophies from live user_progress metadata.
      for (final row in progressRows) {
        final metadata = row is Map ? row['metadata'] : null;
        if (metadata is Map) {
          platinums += _toInt(metadata['platinum_trophies']) ?? 0;
        }
      }
    } else if (xboxPlatforms != null) {
      // Xbox: Sum live current_score from user_progress.
      for (final row in progressRows) {
        if (row is Map) {
          gamerscore += _toInt(row['current_score']) ?? 0;
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

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  /// Gets user profile information
  Future<Map<String, dynamic>> _getUserProfile(String userId) async {
    // Get profile data from profiles table
    final profile = await _client
        .from('profiles')
        .select(
          'psn_online_id, psn_avatar_url, psn_is_plus, steam_display_name, steam_avatar_url, xbox_gamertag, xbox_avatar_url, preferred_display_platform, display_name, username',
        )
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

    final preferredPlatform =
        profile['preferred_display_platform'] as String? ?? 'psn';

    String displayName;
    String? avatarUrl;

    // Determine display name and avatar based on preferred platform
    switch (preferredPlatform) {
      case 'psn':
        displayName =
            profile['psn_online_id'] as String? ??
            profile['display_name'] as String? ??
            profile['username'] as String? ??
            'Player';
        avatarUrl = profile['psn_avatar_url'] as String?;
        break;
      case 'xbox':
        displayName =
            profile['xbox_gamertag'] as String? ??
            profile['display_name'] as String? ??
            profile['username'] as String? ??
            'Player';
        avatarUrl = profile['xbox_avatar_url'] as String?;
        break;
      case 'steam':
        displayName =
            profile['steam_display_name'] as String? ??
            profile['display_name'] as String? ??
            profile['username'] as String? ??
            'Player';
        avatarUrl = profile['steam_avatar_url'] as String?;
        break;
      default:
        displayName =
            profile['display_name'] as String? ??
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
