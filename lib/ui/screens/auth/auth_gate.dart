import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/ui/navigation/app_router.dart';
import 'package:statusxp/ui/screens/auth/sign_in_screen.dart';

/// Authentication gate that controls access to the main app.
/// 
/// Shows the sign-in screen when no user is authenticated,
/// and the main app when a user is logged in.
/// 
/// Also handles first-time data migration for new users.
class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  bool _migrationChecked = false;

  /// Run data migration for newly authenticated users.
  Future<void> _checkAndRunMigration(String userId) async {
    if (_migrationChecked) return;
    _migrationChecked = true;

    final migrationService = ref.read(dataMigrationServiceProvider);
    await migrationService.migrateInitialData(userId);
  }

  @override
  Widget build(BuildContext context) {
    final authStateAsync = ref.watch(authStateProvider);

    return authStateAsync.when(
      data: (state) {
        final user = state.session?.user;
        
        if (user == null) {
          // No authenticated user - show sign in screen
          _migrationChecked = false; // Reset for next login
          return const SignInScreen();
        }
        
        // User is authenticated - run migration if needed, then show main app
        _checkAndRunMigration(user.id);
        
        return const StatusXPMainApp();
      },
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stack) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                'Authentication error',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Main app shell that wraps the router after authentication.
class StatusXPMainApp extends StatelessWidget {
  const StatusXPMainApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Use the existing router configuration
    return MaterialApp.router(
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
