import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:statusxp/ui/screens/dashboard_screen.dart';
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
import 'package:statusxp/ui/screens/trophy_room_screen.dart';
import 'package:statusxp/ui/screens/settings_screen.dart';
import 'package:statusxp/features/display_case/screens/display_case_screen.dart';

/// StatusXP App Router Configuration
/// 
/// Declarative routing using GoRouter for web-compatible navigation.
/// Supports deep linking and browser back/forward navigation.

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    // Dashboard - Home screen (NEW cross-platform version)
    GoRoute(
      path: '/',
      name: 'dashboard',
      builder: (context, state) => const NewDashboardScreen(),
    ),

    // Old Dashboard - Legacy single-platform view
    GoRoute(
      path: '/dashboard-legacy',
      name: 'dashboard-legacy',
      builder: (context, state) => const DashboardScreen(),
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
        
        return GameAchievementsScreen(
          gameId: gameId,
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

    // Trophy Room - Achievement showcase
    GoRoute(
      path: '/trophy-room',
      name: 'trophy-room',
      builder: (context, state) => const TrophyRoomScreen(),
    ),

    // Display Case - Trophy showcase and achievements display
    GoRoute(
      path: '/display-case',
      name: 'display-case',
      builder: (context, state) => const DisplayCaseScreen(),
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
