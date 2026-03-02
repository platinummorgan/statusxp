import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/widgets.dart';

/// Analytics service for tracking user behavior and app usage
/// Automatically tracks screen views and custom events
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal() {
    // Firebase might not be initialized yet (router is created at import time),
    // or it might fail in some contexts (e.g. widget tests). Analytics must
    // never crash the app. We always provide a stable observer instance and
    // attach the real Firebase observer once initialization succeeds.
    observer = _delegatingObserver;
    _ensureFirebaseAnalyticsReady();
  }

  final _DelegatingNavigatorObserver _delegatingObserver =
      _DelegatingNavigatorObserver();

  FirebaseAnalytics? _analytics;
  late final NavigatorObserver observer;

  /// Initialize Firebase Analytics
  Future<void> initialize() async {
    _ensureFirebaseAnalyticsReady();
  }

  void _ensureFirebaseAnalyticsReady() {
    if (_analytics != null && _delegatingObserver.hasDelegate) return;

    try {
      final analytics = FirebaseAnalytics.instance;
      _analytics = analytics;
      _delegatingObserver.setDelegate(
        FirebaseAnalyticsObserver(analytics: analytics),
      );
    } catch (_) {
      // Leave analytics disabled for now. Caller can retry later.
    }
  }

  /// Log a screen view
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    _ensureFirebaseAnalyticsReady();
    final analytics = _analytics;
    if (analytics == null) return;

    await analytics.logScreenView(
      screenName: screenName,
      screenClass: screenClass ?? screenName,
    );
  }

  /// Log when user syncs their data
  Future<void> logSync({
    required String platform, // 'psn', 'xbox', 'steam'
    bool isAutoSync = false,
  }) async {
    _ensureFirebaseAnalyticsReady();
    final analytics = _analytics;
    if (analytics == null) return;

    await analytics.logEvent(
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
    _ensureFirebaseAnalyticsReady();
    final analytics = _analytics;
    if (analytics == null) return;

    await analytics.logEvent(
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
    _ensureFirebaseAnalyticsReady();
    final analytics = _analytics;
    if (analytics == null) return;

    await analytics.logEvent(
      name: 'unlock_guide',
      parameters: {
        'achievement_name': achievementName,
        'game_name': gameName,
      },
    );
  }

  /// Log when user shares their status poster
  Future<void> logSharePoster() async {
    _ensureFirebaseAnalyticsReady();
    final analytics = _analytics;
    if (analytics == null) return;
    await analytics.logEvent(name: 'share_poster');
  }

  /// Log when user edits their Flex Room
  Future<void> logEditFlexRoom({
    required String section, // 'featured', 'superlatives'
  }) async {
    _ensureFirebaseAnalyticsReady();
    final analytics = _analytics;
    if (analytics == null) return;

    await analytics.logEvent(
      name: 'edit_flex_room',
      parameters: {'section': section},
    );
  }

  /// Log when user views a leaderboard
  Future<void> logViewLeaderboard({
    required String leaderboardType, // 'statusxp', 'psn', 'xbox', 'steam'
  }) async {
    _ensureFirebaseAnalyticsReady();
    final analytics = _analytics;
    if (analytics == null) return;

    await analytics.logEvent(
      name: 'view_leaderboard',
      parameters: {'type': leaderboardType},
    );
  }

  /// Log when user searches for games
  Future<void> logSearchGames({
    required String query,
    String? platform,
  }) async {
    _ensureFirebaseAnalyticsReady();
    final analytics = _analytics;
    if (analytics == null) return;

    await analytics.logEvent(
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
    _ensureFirebaseAnalyticsReady();
    final analytics = _analytics;
    if (analytics == null) return;

    await analytics.logEvent(
      name: 'link_account',
      parameters: {'platform': platform},
    );
  }

  /// Log when user views another user's profile
  Future<void> logViewUserProfile({
    required String userId,
  }) async {
    _ensureFirebaseAnalyticsReady();
    final analytics = _analytics;
    if (analytics == null) return;

    await analytics.logEvent(
      name: 'view_user_profile',
      parameters: {'viewed_user_id': userId},
    );
  }

  /// Log custom events for specific user actions
  Future<void> logCustomEvent({
    required String eventName,
    Map<String, dynamic>? parameters,
  }) async {
    _ensureFirebaseAnalyticsReady();
    final analytics = _analytics;
    if (analytics == null) return;

    await analytics.logEvent(
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
    _ensureFirebaseAnalyticsReady();
    final analytics = _analytics;
    if (analytics == null) return;

    if (userId != null) {
      await analytics.setUserId(id: userId);
    }
    
    if (isPremium != null) {
      await analytics.setUserProperty(
        name: 'is_premium',
        value: isPremium.toString(),
      );
    }
    
    if (platformCount != null) {
      await analytics.setUserProperty(
        name: 'linked_platforms',
        value: platformCount.toString(),
      );
    }
  }
}

class _DelegatingNavigatorObserver extends NavigatorObserver {
  NavigatorObserver? _delegate;

  bool get hasDelegate => _delegate != null;

  void setDelegate(NavigatorObserver delegate) {
    _delegate = delegate;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _delegate?.didPush(route, previousRoute);
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _delegate?.didPop(route, previousRoute);
    super.didPop(route, previousRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _delegate?.didRemove(route, previousRoute);
    super.didRemove(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _delegate?.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}
