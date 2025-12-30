import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/ui/navigation/app_router.dart';
import 'package:statusxp/ui/screens/auth/sign_in_screen.dart';
import 'package:statusxp/ui/screens/onboarding_screen.dart';

/// Authentication gate that controls access to the main app.
/// 
/// Shows the onboarding screen on first launch, sign-in screen when no user is authenticated,
/// and the main app when a user is logged in.
class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  bool _needsOnboarding = false;
  bool _checkingOnboarding = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();
    _checkInitialAuthStatus();
  }

  Future<void> _checkOnboardingStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final onboardingComplete = prefs.getBool('onboarding_complete') ?? false;
    setState(() {
      _needsOnboarding = !onboardingComplete;
      _checkingOnboarding = false;
    });
  }
  
  Future<void> _checkInitialAuthStatus() async {
    final user = Supabase.instance.client.auth.currentUser;
    setState(() {
      _isAuthenticated = user != null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingOnboarding) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_needsOnboarding) {
      return const OnboardingScreen();
    }

    final authStateAsync = ref.watch(authStateProvider);

    return authStateAsync.when(
      data: (state) {
        final user = state.session?.user;
        final wasAuthenticated = _isAuthenticated;
        final isNowAuthenticated = user != null;
        
        // Update auth state only on actual changes
        if (wasAuthenticated != isNowAuthenticated) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _isAuthenticated = isNowAuthenticated;
              });
            }
          });
        }
        
        // Only react to explicit sign out, not token refreshes
        if (state.event == AuthChangeEvent.signedOut) {
          return const SignInScreen();
        }
        
        // Show app if user exists, regardless of the event type
        if (user != null) {
          return const StatusXPMainApp();
        }
        
        // No user and not a sign out event - check cached state
        if (_isAuthenticated) {
          // We were authenticated before, keep showing the app
          return const StatusXPMainApp();
        }
        
        // Initial state with no user
        return const SignInScreen();
      },
      loading: () {
        // During loading, check if we already have a cached user
        // This prevents flashing to loading screen during token refresh
        final currentUser = Supabase.instance.client.auth.currentUser;
        if (currentUser != null) {
          return const StatusXPMainApp();
        }
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
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
