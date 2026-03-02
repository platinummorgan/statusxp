import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/main.dart';
import 'package:statusxp/domain/game.dart';
import 'package:statusxp/domain/user_stats.dart';

final sampleGames = <Game>[
  Game(
    id: 'game-1',
    name: 'Sample Game',
    platform: 'PS5',
    totalTrophies: 50,
    earnedTrophies: 10,
    hasPlatinum: true,
    rarityPercent: 12.5,
    cover: 'sample_cover.png',
    bronzeTrophies: 8,
    silverTrophies: 2,
    goldTrophies: 0,
    platinumTrophies: 0,
    updatedAt: DateTime.now(),
  ),
];

const sampleStats = UserStats(
  username: 'Test User',
  avatarUrl: null,
  isPsPlus: false,
  totalPlatinums: 0,
  totalGamesTracked: 1,
  totalTrophies: 10,
  bronzeTrophies: 8,
  silverTrophies: 2,
  goldTrophies: 0,
  platinumTrophies: 0,
  hardestPlatGame: 'N/A',
  rarestTrophyName: 'N/A',
  rarestTrophyRarity: 0.0,
);

/// Get standard provider overrides for tests with a mock authenticated user.
///
/// This sets up a test environment where:
/// - User is authenticated (not in demo mode)
/// - currentUserIdProvider returns a test-specific user ID
/// - Games and stats providers return sample data
List<Override> getTestProviderOverrides() {
  return [
    // Mock auth state with authenticated user.
    authStateProvider.overrideWith((ref) {
      return Stream.value(
        AuthState(
          AuthChangeEvent.signedIn,
          Session(
            accessToken: 'test-token',
            tokenType: 'bearer',
            user: User(
              id: 'test-user-id',
              appMetadata: const {},
              userMetadata: const {},
              aud: 'authenticated',
              createdAt: DateTime.now().toIso8601String(),
            ),
          ),
        ),
      );
    }),

    // Override currentUserIdProvider to return test user ID.
    // This ensures tests run with authenticated user, not demo mode.
    currentUserIdProvider.overrideWith((ref) => 'test-user-id'),

    // Sample data providers.
    gamesProvider.overrideWith((ref) async => sampleGames),
    userStatsProvider.overrideWith((ref) async => sampleStats),
  ];
}

/// Get provider overrides for testing demo mode (unauthenticated).
///
/// This sets up a test environment where:
/// - No user is authenticated (demo mode)
/// - currentUserIdProvider will fall back to demo user ID internally
/// - Games and stats providers return sample data
List<Override> getDemoModeProviderOverrides() {
  return [
    // Mock auth state with no authenticated user.
    authStateProvider.overrideWith((ref) {
      return Stream.value(
        const AuthState(
          AuthChangeEvent.signedOut,
          null, // No session
        ),
      );
    }),

    // currentUserIdProvider will automatically return the demo user ID
    // when auth service has no current user (no override needed here).
    gamesProvider.overrideWith((ref) async => sampleGames),
    userStatsProvider.overrideWith((ref) async => sampleStats),
  ];
}

/// Get the test app - goes through the REAL app flow including AuthGate.
///
/// Auth state and migration service are mocked, but the widget tree is real.
Widget getTestApp() {
  return ProviderScope(
    overrides: getTestProviderOverrides(),
    child: const StatusXPApp(),
  );
}
