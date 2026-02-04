import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Analytics service for tracking user behavior and app usage
/// Automatically tracks screen views and custom events
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal() {
    _analytics = FirebaseAnalytics.instance;
    observer = FirebaseAnalyticsObserver(analytics: _analytics);
  }

  late final FirebaseAnalytics _analytics;
  late final FirebaseAnalyticsObserver observer;

  /// Initialize Firebase Analytics
  Future<void> initialize() async {
    // Analytics and observer already initialized in constructor
  }

  /// Log a screen view
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    await _analytics.logScreenView(
      screenName: screenName,
      screenClass: screenClass ?? screenName,
    );
  }

  /// Log when user syncs their data
  Future<void> logSync({
    required String platform, // 'psn', 'xbox', 'steam'
    bool isAutoSync = false,
  }) async {
    await _analytics.logEvent(
      name: 'sync_data',
      parameters: {
        'platform': platform,
        'is_auto_sync': isAutoSync,
      },
    );
  }

  /// Log when user views a game's achievements
  Future<void> logViewGame({
    required String gameName,
    required String platform,
  }) async {
    await _analytics.logEvent(
      name: 'view_game',
      parameters: {
        'game_name': gameName,
        'platform': platform,
      },
    );
  }

  /// Log when user unlocks an achievement guide (AI feature)
  Future<void> logUnlockGuide({
    required String achievementName,
    required String gameName,
  }) async {
    await _analytics.logEvent(
      name: 'unlock_guide',
      parameters: {
        'achievement_name': achievementName,
        'game_name': gameName,
      },
    );
  }

  /// Log when user shares their status poster
  Future<void> logSharePoster() async {
    await _analytics.logEvent(name: 'share_poster');
  }

  /// Log when user edits their Flex Room
  Future<void> logEditFlexRoom({
    required String section, // 'featured', 'superlatives'
  }) async {
    await _analytics.logEvent(
      name: 'edit_flex_room',
      parameters: {'section': section},
    );
  }

  /// Log when user views a leaderboard
  Future<void> logViewLeaderboard({
    required String leaderboardType, // 'statusxp', 'psn', 'xbox', 'steam'
  }) async {
    await _analytics.logEvent(
      name: 'view_leaderboard',
      parameters: {'type': leaderboardType},
    );
  }

  /// Log when user searches for games
  Future<void> logSearchGames({
    required String query,
    String? platform,
  }) async {
    await _analytics.logEvent(
      name: 'search_games',
      parameters: {
        'query': query,
        if (platform != null) 'platform': platform,
      },
    );
  }

  /// Log when user links a new gaming account
  Future<void> logLinkAccount({
    required String platform,
  }) async {
    await _analytics.logEvent(
      name: 'link_account',
      parameters: {'platform': platform},
    );
  }

  /// Log when user views another user's profile
  Future<void> logViewUserProfile({
    required String userId,
  }) async {
    await _analytics.logEvent(
      name: 'view_user_profile',
      parameters: {'viewed_user_id': userId},
    );
  }

  /// Log custom events for specific user actions
  Future<void> logCustomEvent({
    required String eventName,
    Map<String, dynamic>? parameters,
  }) async {
    await _analytics.logEvent(
      name: eventName,
      parameters: parameters?.cast<String, Object>(),
    );
  }

  /// Set user properties for analytics segmentation
  Future<void> setUserProperties({
    String? userId,
    bool? isPremium,
    int? platformCount,
  }) async {
    if (userId != null) {
      await _analytics.setUserId(id: userId);
    }
    
    if (isPremium != null) {
      await _analytics.setUserProperty(
        name: 'is_premium',
        value: isPremium.toString(),
      );
    }
    
    if (platformCount != null) {
      await _analytics.setUserProperty(
        name: 'linked_platforms',
        value: platformCount.toString(),
      );
    }
  }
}
