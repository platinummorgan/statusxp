import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:statusxp/domain/sync_intelligence_data.dart';

class SyncIntelligenceRepository {
  final SupabaseClient _client;
  static const int _pageSize = 1000;

  const SyncIntelligenceRepository(this._client);

  Future<SyncIntelligenceData> getSyncIntelligence(String userId) async {
    final profileFuture = _getProfile(userId);
    final userGamesFuture = _getUserGames(userId);
    final dbProgressFuture = _getDbProgress(userId);

    final profile = await profileFuture;
    final userGames = await userGamesFuture;
    final dbProgress = await dbProgressFuture;

    final missingGames = _buildMissingGames(userGames, dbProgress);
    final platformGapMap = _aggregatePlatformGaps(missingGames);
    final platformStates = await _buildPlatformStates(
      profile,
      platformGapMap,
      userId,
    );
    final recommendation = _buildRecommendation(platformStates);

    return SyncIntelligenceData(
      platforms: platformStates,
      topMissingGames: missingGames.take(20).toList(),
      recommendation: recommendation,
    );
  }

  Future<Map<String, dynamic>> _getProfile(String userId) async {
    final profile = await _client
        .from('profiles')
        .select(
          'psn_online_id, xbox_gamertag, steam_id, '
          'psn_sync_status, xbox_sync_status, steam_sync_status, '
          'last_psn_sync_at, last_xbox_sync_at, last_steam_sync_at, '
          'psn_token_expires_at, xbox_token_expires_at, '
          'psn_sync_error, xbox_sync_error, steam_sync_error',
        )
        .eq('id', userId)
        .single();

    return profile;
  }

  Future<List<Map<String, dynamic>>> _getUserGames(String userId) async {
    final rows = <Map<String, dynamic>>[];
    var from = 0;
    while (true) {
      final page = await _client
          .from('user_progress')
          .select(
            'platform_id, platform_game_id, achievements_earned, current_score, games(name)',
          )
          .eq('user_id', userId)
          .order('platform_id')
          .order('platform_game_id')
          .range(from, from + _pageSize - 1);

      final pageRows = (page as List).cast<Map<String, dynamic>>();
      rows.addAll(pageRows);
      if (pageRows.length < _pageSize) break;
      from += _pageSize;
    }

    return rows.map((row) {
      final gamesRelation = row['games'];
      String? gameName;
      if (gamesRelation is Map<String, dynamic>) {
        gameName = gamesRelation['name']?.toString();
      } else if (gamesRelation is List && gamesRelation.isNotEmpty) {
        final first = gamesRelation.first;
        if (first is Map<String, dynamic>) {
          gameName = first['name']?.toString();
        }
      }

      return {
        'platform_id': row['platform_id'],
        'platform_game_id': row['platform_game_id'],
        'earned_trophies': row['achievements_earned'] ?? 0,
        'current_score': row['current_score'] ?? 0,
        'name': gameName ?? 'Unknown Game',
      };
    }).toList();
  }

  Future<_DbProgressIndex> _getDbProgress(String userId) async {
    final rows = <Map<String, dynamic>>[];
    var from = 0;
    while (true) {
      final page = await _client
          .from('user_achievements')
          .select(
            // LEFT embed so earned-row counts are never dropped by join mismatches.
            'platform_id, platform_game_id, platform_achievement_id, achievements(score_value)',
          )
          .eq('user_id', userId)
          .order('platform_id')
          .order('platform_game_id')
          .order('platform_achievement_id')
          .range(from, from + _pageSize - 1);

      final pageRows = (page as List).cast<Map<String, dynamic>>();
      rows.addAll(pageRows);
      if (pageRows.length < _pageSize) break;
      from += _pageSize;
    }

    final exactProgress = <String, _DbProgress>{};
    final bucketProgress = <String, _DbProgress>{};
    for (final row in rows) {
      final platformId = (row['platform_id'] as num?)?.toInt();
      final platformGameId = row['platform_game_id']?.toString();
      if (platformId == null || platformGameId == null) continue;

      final key = '$platformId::$platformGameId';
      final bucket = _mapPlatformIdToBucket(platformId);
      final bucketKey = '$bucket::$platformGameId';
      final achievementsRelation = row['achievements'];
      int scoreValue = 0;
      if (achievementsRelation is Map<String, dynamic>) {
        scoreValue = (achievementsRelation['score_value'] as num?)?.toInt() ?? 0;
      } else if (achievementsRelation is List &&
          achievementsRelation.isNotEmpty) {
        final first = achievementsRelation.first;
        if (first is Map<String, dynamic>) {
          scoreValue = (first['score_value'] as num?)?.toInt() ?? 0;
        }
      }

      final existing = exactProgress[key];
      if (existing == null) {
        exactProgress[key] = _DbProgress(count: 1, score: scoreValue);
      } else {
        exactProgress[key] = _DbProgress(
          count: existing.count + 1,
          score: existing.score + scoreValue,
        );
      }

      final existingBucket = bucketProgress[bucketKey];
      if (existingBucket == null) {
        bucketProgress[bucketKey] = _DbProgress(count: 1, score: scoreValue);
      } else {
        bucketProgress[bucketKey] = _DbProgress(
          count: existingBucket.count + 1,
          score: existingBucket.score + scoreValue,
        );
      }
    }

    return _DbProgressIndex(exact: exactProgress, byBucket: bucketProgress);
  }

  List<MissingGameInsight> _buildMissingGames(
    List<Map<String, dynamic>> userGames,
    _DbProgressIndex dbProgress,
  ) {
    final missing = <MissingGameInsight>[];
    for (final game in userGames) {
      final platformId = (game['platform_id'] as num?)?.toInt();
      final platformGameId = game['platform_game_id']?.toString();
      if (platformId == null || platformGameId == null) continue;
      final platform = _mapPlatformIdToBucket(platformId);

      final apiEarned = (game['earned_trophies'] as num?)?.toInt() ?? 0;
      final apiScore = (game['current_score'] as num?)?.toInt() ?? 0;
      final db = platform == 'xbox'
          ? dbProgress.byBucket['xbox::$platformGameId']
          : dbProgress.exact['$platformId::$platformGameId'];

      final dbEarned = db?.count ?? 0;
      final dbScore = db?.score ?? 0;
      final missingAchievements = (apiEarned - dbEarned).clamp(0, 1 << 30).toInt();

      // Platform-specific gap logic:
      // - PSN/Steam: count-based progress is authoritative for diagnostics.
      // - Xbox: include score-based gap because Gamerscore is first-class.
      final missingScore = platform == 'xbox'
          ? (apiScore - dbScore).clamp(0, 1 << 30).toInt()
          : 0;

      if (missingAchievements <= 0 && missingScore <= 0) continue;

      missing.add(
        MissingGameInsight(
          platform: platform,
          platformGameId: platformGameId,
          gameTitle: game['name']?.toString() ?? 'Unknown Game',
          apiEarnedCount: apiEarned,
          dbEarnedCount: dbEarned,
          estimatedMissingAchievements: missingAchievements,
          estimatedMissingScore: missingScore,
        ),
      );
    }

    missing.sort((a, b) {
      final scoreCompare = b.estimatedMissingScore.compareTo(
        a.estimatedMissingScore,
      );
      if (scoreCompare != 0) return scoreCompare;
      return b.estimatedMissingAchievements.compareTo(
        a.estimatedMissingAchievements,
      );
    });

    return missing;
  }

  Map<String, _PlatformGap> _aggregatePlatformGaps(
    List<MissingGameInsight> missingGames,
  ) {
    final map = <String, _PlatformGap>{};
    for (final game in missingGames) {
      final existing =
          map[game.platform] ?? const _PlatformGap(score: 0, achievements: 0);
      map[game.platform] = _PlatformGap(
        score: existing.score + game.estimatedMissingScore,
        achievements: existing.achievements + game.estimatedMissingAchievements,
      );
    }
    return map;
  }

  Future<List<PlatformSyncIntelligence>> _buildPlatformStates(
    Map<String, dynamic> profile,
    Map<String, _PlatformGap> platformGapMap,
    String userId,
  ) async {
    final platforms = <String>['psn', 'xbox', 'steam'];
    final states = <PlatformSyncIntelligence>[];

    for (final platform in platforms) {
      final linked = _isLinked(profile, platform);
      final syncStatus =
          profile['${platform}_sync_status']?.toString() ?? 'never_synced';
      final lastSyncAt = _asDateTime(profile['last_${platform}_sync_at']);
      final tokenExpiresAt = _asDateTime(
        profile['${platform}_token_expires_at'],
      );
      final lastError = profile['${platform}_sync_error']?.toString();
      final gap =
          platformGapMap[platform] ??
          const _PlatformGap(score: 0, achievements: 0);

      bool canSyncNow = false;
      int waitSeconds = 0;
      String reason = linked ? 'Ready' : 'Not linked';

      if (linked) {
        try {
          final syncCheck =
              await _client.rpc(
                    'can_user_sync',
                    params: {'p_user_id': userId, 'p_platform': platform},
                  )
                  as Map<String, dynamic>;
          canSyncNow = syncCheck['can_sync'] as bool? ?? false;
          waitSeconds = (syncCheck['wait_seconds'] as num?)?.toInt() ?? 0;
          reason = syncCheck['reason']?.toString() ?? reason;
        } catch (_) {}
      }

      states.add(
        PlatformSyncIntelligence(
          platform: platform,
          linked: linked,
          syncStatus: syncStatus,
          lastSyncAt: lastSyncAt,
          tokenExpiresAt: tokenExpiresAt,
          lastError: lastError,
          canSyncNow: canSyncNow,
          waitSeconds: waitSeconds,
          syncReason: reason,
          estimatedGapScore: gap.score,
          estimatedGapAchievements: gap.achievements,
        ),
      );
    }

    return states;
  }

  SyncRecommendation _buildRecommendation(
    List<PlatformSyncIntelligence> platforms,
  ) {
    final linked = platforms.where((platform) => platform.linked).toList();
    if (linked.isEmpty) {
      return const SyncRecommendation(
        platform: 'none',
        canSyncNow: false,
        reason: 'No linked platforms found. Link PSN, Xbox, or Steam to begin.',
        actionLabel: 'Link a platform',
        waitSeconds: 0,
        estimatedGapScore: 0,
        estimatedGapAchievements: 0,
      );
    }

    final authIssue = linked.where((platform) {
      final error = (platform.lastError ?? '').toLowerCase();
      final hasAuthError =
          error.contains('token') ||
          error.contains('auth') ||
          error.contains('oauth') ||
          error.contains('invalid_grant') ||
          error.contains('expired') ||
          error.contains('refresh');

      return platform.syncStatus == 'error' &&
          (hasAuthError || platform.tokenExpired);
    });

    if (authIssue.isNotEmpty) {
      final target = authIssue.first;
      final error = (target.lastError ?? '').toLowerCase();
      final hasAuthError =
          error.contains('token') ||
          error.contains('auth') ||
          error.contains('oauth') ||
          error.contains('invalid_grant') ||
          error.contains('expired') ||
          error.contains('refresh');
      return SyncRecommendation(
        platform: target.platform,
        canSyncNow: target.canSyncNow,
        reason: target.tokenExpired
            ? '${target.displayName} token expired. Re-link to prevent sync failures.'
            : hasAuthError
            ? '${target.displayName} has an authentication error. Re-link to restore sync.'
            : '${target.displayName} token may be stale. Re-link if sync starts failing.',
        actionLabel: 'Open ${target.displayName} sync',
        waitSeconds: target.waitSeconds,
        estimatedGapScore: target.estimatedGapScore,
        estimatedGapAchievements: target.estimatedGapAchievements,
      );
    }

    final syncable = linked.where((platform) => platform.canSyncNow).toList();
    if (syncable.isNotEmpty) {
      syncable.sort((a, b) {
        final aPriority = _syncPriority(a);
        final bPriority = _syncPriority(b);
        return bPriority.compareTo(aPriority);
      });
      final target = syncable.first;
      return SyncRecommendation(
        platform: target.platform,
        canSyncNow: true,
        reason:
            '${target.displayName} has the highest unimported data gap (${target.estimatedGapScore} score).',
        actionLabel: 'Sync ${target.displayName} now',
        waitSeconds: 0,
        estimatedGapScore: target.estimatedGapScore,
        estimatedGapAchievements: target.estimatedGapAchievements,
      );
    }

    linked.sort((a, b) => a.waitSeconds.compareTo(b.waitSeconds));
    final target = linked.first;
    return SyncRecommendation(
      platform: target.platform,
      canSyncNow: false,
      reason:
          'Next available sync window is ${target.displayName}. ${target.syncReason}',
      actionLabel: 'Wait for ${target.displayName}',
      waitSeconds: target.waitSeconds,
      estimatedGapScore: target.estimatedGapScore,
      estimatedGapAchievements: target.estimatedGapAchievements,
    );
  }

  int _syncPriority(PlatformSyncIntelligence platform) {
    final staleHours = platform.lastSyncAt == null
        ? 96
        : DateTime.now().toUtc().difference(platform.lastSyncAt!).inHours;

    var priority = platform.estimatedGapScore;
    priority += platform.estimatedGapAchievements * 5;
    priority += staleHours.clamp(0, 240);
    if (platform.syncStatus == 'error') priority += 500;
    return priority;
  }

  bool _isLinked(Map<String, dynamic> profile, String platform) {
    switch (platform) {
      case 'psn':
        return (profile['psn_online_id']?.toString().isNotEmpty ?? false);
      case 'xbox':
        return (profile['xbox_gamertag']?.toString().isNotEmpty ?? false);
      case 'steam':
        return (profile['steam_id']?.toString().isNotEmpty ?? false);
      default:
        return false;
    }
  }

  DateTime? _asDateTime(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString())?.toUtc();
  }

  String _mapPlatformIdToBucket(int platformId) {
    if ([1, 2, 5, 9].contains(platformId)) return 'psn';
    if ([10, 11, 12].contains(platformId)) return 'xbox';
    if (platformId == 4) return 'steam';
    return 'unknown';
  }
}

class _DbProgress {
  final int count;
  final int score;

  const _DbProgress({required this.count, required this.score});
}

class _DbProgressIndex {
  final Map<String, _DbProgress> exact;
  final Map<String, _DbProgress> byBucket;

  const _DbProgressIndex({required this.exact, required this.byBucket});
}

class _PlatformGap {
  final int score;
  final int achievements;

  const _PlatformGap({required this.score, required this.achievements});
}
