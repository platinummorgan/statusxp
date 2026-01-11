import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:statusxp/data/auth/biometric_auth_service.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/ui/screens/auth/sign_in_screen.dart';
import 'package:statusxp/ui/screens/auth/biometric_login_screen.dart';
import 'package:statusxp/ui/screens/onboarding_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html;

/// Authentication gate that controls access to the main app.
/// 
/// Flow:
/// 1. Check if onboarding is needed (first launch)
/// 2. Check if user has biometric auth enabled with valid refresh token
/// 3. If yes, show BiometricLoginScreen for instant unlock
/// 4. If no, check if user is authenticated
/// 5. Show appropriate screen based on auth state
class AuthGate extends ConsumerStatefulWidget {
  final Widget child;

  const AuthGate({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> with WidgetsBindingObserver {
  bool _needsOnboarding = false;
  bool _checkingOnboarding = true;
  bool _isAuthenticated = false;
  bool _isBiometricUnlocked = false;
  bool _hasBiometricToken = false;
  bool _checkingBiometric = true;
  final BiometricAuthService _biometricService = BiometricAuthService();
  DateTime? _lastPausedTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkOnboardingStatus();
    _checkInitialAuthStatus();
    _checkBiometricToken();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Only lock when app actually goes to background, not when just switching apps
    if (state == AppLifecycleState.paused) {
      // Record when app went to background
      _lastPausedTime = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      // When returning to app, only lock if it's been in background for more than 1 minute
      if (_lastPausedTime != null) {
        final duration = DateTime.now().difference(_lastPausedTime!);
        if (duration.inMinutes >= 1) {
          setState(() {
            _isBiometricUnlocked = false;
          });
        }
      }
      _lastPausedTime = null;
    }
  }

  Future<void> _checkOnboardingStatus() async {
    bool onboardingComplete = false;
    
    // On web, check cookie; on mobile check SharedPreferences
    if (kIsWeb) {
      final cookies = html.document.cookie?.split(';') ?? [];
      onboardingComplete = cookies.any((cookie) => cookie.trim().startsWith('onboarding_complete=true'));
    } else {
      final prefs = await SharedPreferences.getInstance();
      onboardingComplete = prefs.getBool('onboarding_complete') ?? false;
    }
    
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
  
  /// Check if user has a valid biometric refresh token stored
  Future<void> _checkBiometricToken() async {
    final hasToken = await _biometricService.hasStoredRefreshToken();
    final isExpired = await _biometricService.isRefreshTokenExpired();
    
    setState(() {
      _hasBiometricToken = hasToken && !isExpired;
      _checkingBiometric = false;
    });
  }

  Widget _buildMainAppOrLock() {
    final lockRequested = ref.watch(biometricLockRequestedProvider);
    final unlockGranted = ref.watch(biometricUnlockGrantedProvider);

    if (unlockGranted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(biometricUnlockGrantedProvider.notifier).state = false;
        if (mounted) {
          setState(() {
            _isBiometricUnlocked = true;
          });
        }
      });
    }
    
    return FutureBuilder<bool>(
      future: _biometricService.isBiometricEnabled(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final biometricEnabled = snapshot.data ?? false;

        if (_isAuthenticated && lockRequested) {
          return SignInScreen(
            autoPromptBiometric: biometricEnabled,
          );
        }

        if (biometricEnabled && _isAuthenticated && !_isBiometricUnlocked) {
          return const SignInScreen(
            autoPromptBiometric: true,
          );
        }

        if (_isAuthenticated) {
          return widget.child;
        }

        // Not authenticated - show sign-in (biometric sign-in handled there)
        return SignInScreen(
          autoPromptBiometric: biometricEnabled,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Still checking initial state
    if (_checkingOnboarding || _checkingBiometric) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // First time user - show onboarding
    if (_needsOnboarding) {
      return const OnboardingScreen();
    }

    // User has biometric token and is not authenticated yet - show biometric login
    if (_hasBiometricToken && !_isAuthenticated) {
      return const BiometricLoginScreen();
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
          return _buildMainAppOrLock();
        }
        
        // No user and not a sign out event - check cached state
        if (_isAuthenticated) {
          // We were authenticated before, keep showing the app
          return _buildMainAppOrLock();
        }
        
        // Initial state with no user - show sign-in
        return const SignInScreen();
      },
      loading: () {
        // During loading, check if we already have a cached user
        // This prevents flashing to loading screen during token refresh
        final currentUser = Supabase.instance.client.auth.currentUser;
        if (currentUser != null) {
          return _buildMainAppOrLock();
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
