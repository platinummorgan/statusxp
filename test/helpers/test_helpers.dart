import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/data/sample_data.dart';
import 'package:statusxp/data/data_migration_service.dart';
import 'package:statusxp/main.dart';

/// Test double that short-circuits Supabase migration logic.
///
/// We implement the interface instead of extending the real service
/// so no SupabaseClient is required in widget tests. This allows tests
/// to exercise the full app widget tree (StatusXPApp → AuthGate → StatusXPMainApp)
/// without initializing Supabase.
class _MockDataMigrationService implements DataMigrationService {
  @override
  Future<bool> isMigrationComplete(String userId) async => true;

  @override
  Future<void> migrateInitialData(String userId) async {
    // No-op in tests - sample data already provided via provider overrides.
  }
}

/// Get standard provider overrides for tests with a mock authenticated user.
///
/// This sets up a test environment where:
/// - User is authenticated (not in demo mode)
/// - currentUserIdProvider returns a test-specific user ID
/// - Migration service is mocked to skip data seeding
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

    // Mock migration service.
    dataMigrationServiceProvider.overrideWith(
      (ref) => _MockDataMigrationService(),
    ),

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
    dataMigrationServiceProvider.overrideWith(
      (ref) => _MockDataMigrationService(),
    ),
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
