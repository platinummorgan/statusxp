import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:statusxp/ui/screens/auth/auth_gate.dart';
import 'package:statusxp/ui/screens/auth/reset_password_screen.dart';
import 'package:statusxp/ui/screens/new_dashboard_screen.dart';
import 'package:statusxp/ui/screens/games_list_screen.dart';
import 'package:statusxp/ui/screens/unified_games_list_screen.dart';
import 'package:statusxp/ui/screens/game_achievements_screen.dart';
import 'package:statusxp/ui/screens/game_browser_screen.dart';
import 'package:statusxp/ui/screens/leaderboard_screen.dart';
import 'package:statusxp/ui/screens/flex_room_screen.dart';
import 'package:statusxp/ui/screens/achievements_screen.dart';
import 'package:statusxp/ui/screens/psn/psn_sync_screen.dart';
import 'package:statusxp/ui/screens/xbox/xbox_sync_screen.dart';
import 'package:statusxp/ui/screens/status_poster_screen.dart';
import 'package:statusxp/ui/screens/settings_screen.dart';
import 'package:statusxp/ui/screens/landing_page_screen.dart';
import 'package:statusxp/ui/screens/premium_success_screen.dart';
import 'package:statusxp/ui/screens/coop_partners_screen.dart';
import 'package:statusxp/ui/screens/trophy_help_request_details_screen.dart';
import 'package:statusxp/ui/screens/achievement_comments_screen.dart';
import 'package:statusxp/ui/screens/premium_analytics_screen.dart';

/// StatusXP App Router Configuration
/// 
/// Declarative routing using GoRouter for web-compatible navigation.
/// Supports deep linking and browser back/forward navigation.

final GoRouter appRouter = GoRouter(
  debugLogDiagnostics: kDebugMode,
  routes: [
    // Landing Page - Public marketing page
    GoRoute(
      path: '/landing',
      name: 'landing',
      builder: (context, state) => const LandingPageScreen(),
    ),

    // Password Reset - Deep link entry point
    GoRoute(
      path: '/reset-password',
      name: 'reset-password',
      builder: (context, state) => const ResetPasswordScreen(),
    ),

    // Premium Success - Stripe payment success redirect
    GoRoute(
      path: '/premium/success',
      name: 'premium-success',
      builder: (context, state) => const PremiumSuccessScreen(),
    ),

    ShellRoute(
      builder: (context, state, child) => AuthGate(child: child),
      routes: [
        // Dashboard - Home screen
        GoRoute(
          path: '/',
          name: 'dashboard',
          builder: (context, state) => const NewDashboardScreen(),
        ),

        // Games List - View all tracked games
        GoRoute(
          path: '/games',
          name: 'games',
          builder: (context, state) => const GamesListScreen(),
        ),

        // Unified Games List - Cross-platform game view with filters
        GoRoute(
          path: '/unified-games',
          name: 'unified-games',
          builder: (context, state) => const UnifiedGamesListScreen(),
        ),

        // Game Browser - Browse ALL games in database (catalog)
        GoRoute(
          path: '/games/browse',
          name: 'game-browser',
          builder: (context, state) => const GameBrowserScreen(),
        ),

        // Game detail shortcut - redirects to achievements
        GoRoute(
          path: '/game/:gameId',
          name: 'game-detail',
          redirect: (context, state) {
            final gameId = state.pathParameters['gameId'];
            return '/game/$gameId/achievements';
          },
        ),

        // Game Achievements - View achievements/trophies for a specific game
        GoRoute(
          path: '/game/:gameId/achievements',
          name: 'game-achievements',
          builder: (context, state) {
            final gameId = state.pathParameters['gameId']!;
            final gameName = state.uri.queryParameters['name'] ?? 'Game';
            final platform = state.uri.queryParameters['platform'] ?? 'unknown';
            final coverUrl = state.uri.queryParameters['cover'];
            final platformIdStr = state.uri.queryParameters['platform_id'];
            final platformGameId = state.uri.queryParameters['platform_game_id'];
            
            // Parse platform_id if provided
            int? platformId;
            if (platformIdStr != null) {
              platformId = int.tryParse(platformIdStr);
            }
            
            return GameAchievementsScreen(
              platformId: platformId,
              platformGameId: platformGameId ?? gameId, // Fallback to gameId for V1 compatibility
              gameName: gameName,
              platform: platform,
              coverUrl: coverUrl,
            );
          },
        ),

        // Status Poster - Shareable achievement card
        GoRoute(
          path: '/poster',
          name: 'poster',
          builder: (context, state) => const StatusPosterScreen(),
        ),

        // PSN Sync - PlayStation Network integration
        GoRoute(
          path: '/psn-sync',
          name: 'psn-sync',
          builder: (context, state) => const PSNSyncScreen(),
        ),

        // Xbox Sync - Xbox Live integration
        GoRoute(
          path: '/xbox-sync',
          name: 'xbox-sync',
          builder: (context, state) => const XboxSyncScreen(),
        ),

        // Flex Room - Cross-platform achievement showcase
        GoRoute(
          path: '/flex-room',
          name: 'flex-room',
          builder: (context, state) => const FlexRoomScreen(),
        ),

        // Achievements - View all meta-achievements and progress
        GoRoute(
          path: '/achievements',
          name: 'achievements',
          builder: (context, state) => const AchievementsScreen(),
        ),

        // Co-op Partners - Find help for multiplayer/co-op trophies
        GoRoute(
          path: '/coop-partners',
          name: 'coop-partners',
          builder: (context, state) => const CoopPartnersScreen(),
        ),

        // Trophy Help Request Details
        GoRoute(
          path: '/coop-partners/:requestId',
          name: 'trophy-help-details',
          builder: (context, state) {
            final requestId = state.pathParameters['requestId']!;
            return TrophyHelpRequestDetailsScreen(requestId: requestId);
          },
        ),

        // Achievement Comments - Community tips and coordination
        GoRoute(
          path: '/achievement-comments/:achievementId',
          name: 'achievement-comments',
          builder: (context, state) {
            final achievementId = int.parse(state.pathParameters['achievementId']!);
            final achievementName = state.uri.queryParameters['name'] ?? 'Achievement';
            final achievementIconUrl = state.uri.queryParameters['icon'];
            final platformId = int.parse(state.uri.queryParameters['platformId'] ?? '0');
            final platformGameId = state.uri.queryParameters['platformGameId'] ?? '';
            final platformAchievementId = state.uri.queryParameters['platformAchievementId'] ?? '';
            return AchievementCommentsScreen(
              achievementId: achievementId,
              achievementName: achievementName,
              achievementIconUrl: achievementIconUrl,
              platformId: platformId,
              platformGameId: platformGameId,
              platformAchievementId: platformAchievementId,
            );
          },
        ),

        // Leaderboards - Global rankings
        GoRoute(
          path: '/leaderboards',
          name: 'leaderboards',
          builder: (context, state) => const LeaderboardScreen(),
        ),

        // Settings - Platform connections and app configuration
        GoRoute(
          path: '/settings',
          name: 'settings',
          builder: (context, state) => const SettingsScreen(),
        ),

        // Premium Analytics - Comprehensive statistics and insights
        GoRoute(
          path: '/analytics',
          name: 'analytics',
          builder: (context, state) => const PremiumAnalyticsScreen(),
        ),
      ],
    ),

    // TODO: Future nested routes
    // - Game detail screen: '/games/:id'
  ],

  // Error/404 handler
  errorBuilder: (context, state) => Scaffold(
    appBar: AppBar(
      title: const Text('Page Not Found'),
    ),
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.white38,
          ),
          const SizedBox(height: 16),
          Text(
            '404 - Page Not Found',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'The page "${state.uri}" does not exist.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => context.go('/'),
            child: const Text('Go to Dashboard'),
          ),
        ],
      ),
    ),
  ),
);
