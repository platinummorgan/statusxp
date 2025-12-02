import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/data/sample_data.dart';
import 'package:statusxp/ui/screens/auth/auth_gate.dart';

/// Get standard provider overrides for tests with mock authenticated user.
List<Override> getTestProviderOverrides() {
  return [
    // Mock auth state with authenticated user
    authStateProvider.overrideWith((ref) {
      return Stream.value(
        AuthState(
          AuthChangeEvent.signedIn,
          Session(
            accessToken: 'test-token',
            tokenType: 'bearer',
            user: User(
              id: 'test-user-id',
              appMetadata: {},
              userMetadata: {},
              aud: 'authenticated',
              createdAt: DateTime.now().toIso8601String(),
            ),
          ),
        ),
      );
    }),
    currentUserIdProvider.overrideWith((ref) => 'test-user-id'),
    gamesProvider.overrideWith((ref) async => sampleGames),
    userStatsProvider.overrideWith((ref) async => sampleStats),
  ];
}

/// Wrap the main app widget for testing, bypassing AuthGate.
Widget getTestApp() {
  return ProviderScope(
    overrides: getTestProviderOverrides(),
    child: const StatusXPMainApp(),
  );
}
