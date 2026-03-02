import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:statusxp/domain/engagement_hub_data.dart';

class EngagementRepository {
  final SupabaseClient _client;

  const EngagementRepository(this._client);

  Future<EngagementSnapshot> getEngagementSnapshot(String userId) async {
    final response =
        await _client.rpc(
              'get_user_engagement_snapshot',
              params: {'p_user_id': userId},
            )
            as List<dynamic>;

    if (response.isEmpty) {
      return const EngagementSnapshot(
        currentStreak: 0,
        longestStreak: 0,
        todayUnlocks: 0,
        weeklyUnlocks: 0,
        todayStatusXp: 0,
        challenges: [],
        notificationPreferences: NotificationPreferences(
          pushEnabled: true,
          notifyRivalActivity: true,
          notifyStreakRisk: true,
          notifyDailyChallenges: true,
          notifyActivityHighlights: true,
          dailyDigestHour: 19,
        ),
      );
    }

    final row = response.first as Map<String, dynamic>;
    final challengesRaw = row['challenges'] as List<dynamic>? ?? const [];
    final preferencesRaw = row['notification_preferences'] is Map
        ? Map<String, dynamic>.from(row['notification_preferences'] as Map)
        : const <String, dynamic>{};

    return EngagementSnapshot(
      currentStreak: (row['current_streak'] as num?)?.toInt() ?? 0,
      longestStreak: (row['longest_streak'] as num?)?.toInt() ?? 0,
      todayUnlocks: (row['today_unlocks'] as num?)?.toInt() ?? 0,
      weeklyUnlocks: (row['weekly_unlocks'] as num?)?.toInt() ?? 0,
      todayStatusXp: (row['today_statusxp'] as num?)?.toDouble() ?? 0,
      challenges: challengesRaw
          .whereType<Map>()
          .map((entry) => _toChallenge(Map<String, dynamic>.from(entry)))
          .toList(),
      notificationPreferences: NotificationPreferences(
        pushEnabled: preferencesRaw['push_enabled'] as bool? ?? true,
        notifyRivalActivity:
            preferencesRaw['notify_rival_activity'] as bool? ?? true,
        notifyStreakRisk: preferencesRaw['notify_streak_risk'] as bool? ?? true,
        notifyDailyChallenges:
            preferencesRaw['notify_daily_challenges'] as bool? ?? true,
        notifyActivityHighlights:
            preferencesRaw['notify_activity_highlights'] as bool? ?? true,
        dailyDigestHour:
            (preferencesRaw['daily_digest_hour'] as num?)?.toInt() ?? 19,
      ),
    );
  }

  Future<List<SocialTarget>> getSocialTargets(
    String userId, {
    int limit = 30,
  }) async {
    final response =
        await _client.rpc(
              'get_social_graph_snapshot',
              params: {'p_user_id': userId, 'p_limit': limit},
            )
            as List<dynamic>;

    return response
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .map(
          (row) => SocialTarget(
            userId: row['user_id']?.toString() ?? '',
            displayName: row['display_name']?.toString() ?? 'Player',
            avatarUrl: row['avatar_url']?.toString(),
            totalStatusXp: (row['total_statusxp'] as num?)?.toInt() ?? 0,
            weeklyGain: (row['weekly_gain'] as num?)?.toInt() ?? 0,
            monthlyGain: (row['monthly_gain'] as num?)?.toInt() ?? 0,
            isFollowing: row['is_following'] as bool? ?? false,
            isRivalWatchlisted: row['is_rival_watchlisted'] as bool? ?? false,
          ),
        )
        .where((target) => target.userId.isNotEmpty)
        .toList();
  }

  Future<List<SocialHighlight>> getSocialHighlights(
    String userId, {
    int limit = 25,
  }) async {
    final response =
        await _client.rpc(
              'get_social_activity_highlights',
              params: {'p_user_id': userId, 'p_limit': limit},
            )
            as List<dynamic>;

    return response
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .map(
          (row) => SocialHighlight(
            id: (row['id'] as num?)?.toInt() ?? 0,
            actorUserId: row['actor_user_id']?.toString() ?? '',
            actorDisplayName: row['actor_display_name']?.toString() ?? 'Player',
            actorAvatarUrl: row['actor_avatar_url']?.toString(),
            storyText: row['story_text']?.toString() ?? '',
            eventType: row['event_type']?.toString() ?? 'activity',
            gameTitle: row['game_title']?.toString(),
            createdAt:
                DateTime.tryParse(row['created_at']?.toString() ?? '') ??
                DateTime.now().toUtc(),
            isFollowing: row['is_following'] as bool? ?? false,
            isRivalWatchlisted: row['is_rival_watchlisted'] as bool? ?? false,
          ),
        )
        .where((highlight) => highlight.id > 0)
        .toList();
  }

  Future<List<PlayNextRecommendation>> getPlayNextRecommendations(
    String userId, {
    int limit = 18,
  }) async {
    final response =
        await _client.rpc(
              'get_play_next_recommendations',
              params: {'p_user_id': userId, 'p_limit': limit},
            )
            as List<dynamic>;

    return response
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .map(
          (row) => PlayNextRecommendation(
            recommendationType:
                row['recommendation_type']?.toString() ?? 'unknown',
            platformId: (row['platform_id'] as num?)?.toInt() ?? 0,
            platformGameId: row['platform_game_id']?.toString() ?? '',
            gameTitle: row['game_title']?.toString() ?? 'Unknown Game',
            completionPercentage:
                (row['completion_percentage'] as num?)?.toDouble() ?? 0,
            remainingAchievements:
                (row['remaining_achievements'] as num?)?.toInt() ?? 0,
            remainingStatusXp:
                (row['remaining_statusxp'] as num?)?.toDouble() ?? 0,
            estimatedHours: (row['estimated_hours'] as num?)?.toDouble() ?? 0,
            xpPerHour: (row['xp_per_hour'] as num?)?.toDouble() ?? 0,
            reason: row['reason']?.toString() ?? '',
          ),
        )
        .where((recommendation) => recommendation.platformGameId.isNotEmpty)
        .toList();
  }

  Future<void> setFollowing({
    required String currentUserId,
    required String targetUserId,
    required bool enabled,
  }) async {
    if (enabled) {
      await _client.from('user_follows').upsert({
        'follower_user_id': currentUserId,
        'followed_user_id': targetUserId,
      });
      return;
    }

    await _client
        .from('user_follows')
        .delete()
        .eq('follower_user_id', currentUserId)
        .eq('followed_user_id', targetUserId);
  }

  Future<void> setRivalWatchlisted({
    required String currentUserId,
    required String targetUserId,
    required bool enabled,
  }) async {
    if (enabled) {
      await _client.from('user_rival_watchlist').upsert({
        'user_id': currentUserId,
        'rival_user_id': targetUserId,
        'notify_on_activity': true,
      });
      return;
    }

    await _client
        .from('user_rival_watchlist')
        .delete()
        .eq('user_id', currentUserId)
        .eq('rival_user_id', targetUserId);
  }

  Future<void> updateNotificationPreferences({
    required String userId,
    required NotificationPreferences preferences,
  }) async {
    await _client.from('user_notification_preferences').upsert({
      'user_id': userId,
      'push_enabled': preferences.pushEnabled,
      'notify_rival_activity': preferences.notifyRivalActivity,
      'notify_streak_risk': preferences.notifyStreakRisk,
      'notify_daily_challenges': preferences.notifyDailyChallenges,
      'notify_activity_highlights': preferences.notifyActivityHighlights,
      'daily_digest_hour': preferences.dailyDigestHour,
    });
  }

  ChallengeProgress _toChallenge(Map<String, dynamic> row) {
    return ChallengeProgress(
      id: row['id']?.toString() ?? 'challenge',
      title: row['title']?.toString() ?? 'Challenge',
      description: row['description']?.toString() ?? '',
      target: (row['target'] as num?)?.toInt() ?? 0,
      progress: (row['progress'] as num?)?.toInt() ?? 0,
      rewardXp: (row['reward_xp'] as num?)?.toInt() ?? 0,
      completed: row['completed'] as bool? ?? false,
    );
  }
}
