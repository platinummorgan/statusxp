import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:statusxp/ui/screens/dashboard_screen.dart';
import 'package:statusxp/ui/screens/games_list_screen.dart';
import 'package:statusxp/ui/screens/status_poster_screen.dart';

/// StatusXP App Router Configuration
/// 
/// Declarative routing using GoRouter for web-compatible navigation.
/// Supports deep linking and browser back/forward navigation.

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    // Dashboard - Home screen
    GoRoute(
      path: '/',
      name: 'dashboard',
      builder: (context, state) => const DashboardScreen(),
    ),

    // Games List - View all tracked games
    GoRoute(
      path: '/games',
      name: 'games',
      builder: (context, state) => const GamesListScreen(),
    ),

    // Status Poster - Shareable achievement card
    GoRoute(
      path: '/poster',
      name: 'poster',
      builder: (context, state) => const StatusPosterScreen(),
    ),

    // TODO: Future nested routes
    // - Game detail screen: '/games/:id'
    // - Settings screen: '/settings'
    // - Profile screen: '/profile'
    // - Leaderboard screen: '/leaderboard' (Phase 2.0+)
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
