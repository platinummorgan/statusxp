import 'dart:async';
import 'dart:convert';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:statusxp/config/supabase_config.dart';
import 'package:statusxp/data/auth/biometric_auth_service.dart';
import 'package:statusxp/services/auth_refresh_service.dart';
import 'package:statusxp/services/subscription_service.dart';
import 'package:statusxp/services/sync_resume_service.dart';
import 'package:statusxp/theme/theme.dart';
import 'package:statusxp/ui/navigation/app_router.dart';
import 'package:statusxp/utils/html.dart' as html;
import 'package:statusxp/utils/statusxp_logger.dart';

late final AuthRefreshService authRefreshService;
final BiometricAuthService _biometric = BiometricAuthService();

class _AppLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;

    Future.delayed(const Duration(seconds: 1), () {
      authRefreshService.refreshIfNeededOnResume().catchError((e) {
        _safeLog('Token refresh on resume failed (will retry later): ${_safeStr(e)}');
      });
    });
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    _safeLog('FlutterError caught: ${_safeStr(details.exception)}');
    _safeLog('Stack: ${_safeStr(details.stack)}');
    
    // Enhanced logging for null check operator errors
    if (_safeStr(details.exception).contains('Null check operator')) {
      _safeLog('🔍 NULL CHECK ERROR DETAILS:');
      _safeLog('Exception type: ${details.exception.runtimeType}');
      _safeLog('Library: ${details.library}');
      _safeLog('Context: ${details.context}');
      if (details.stack != null) {
        final stackLines = details.stack.toString().split('\n');
        _safeLog('Stack breakdown:');
        for (int i = 0; i < stackLines.length && i < 10; i++) {
          _safeLog('  Frame $i: ${stackLines[i]}');
        }
      }
    }
  };

  runZonedGuarded(
    () async => _initializeApp(),
    (error, stack) async {
      // IMPORTANT: never let logging crash the error handler
      final errStr = _safeStr(error);
      
      // Enhanced null check error debugging
      if (errStr.contains('Null check operator') || errStr.contains('null value')) {
        _safeLog('🚨 CRITICAL NULL CHECK ERROR:');
        _safeLog('Error: $errStr');
        _safeLog('Error type: ${error.runtimeType}');
        _safeLog('Stack trace:');
        final stackLines = stack.toString().split('\n');
        for (int i = 0; i < stackLines.length && i < 15; i++) {
          _safeLog('  $i: ${stackLines[i]}');
        }
              
        // Try to capture additional runtime context
        _safeLog('Runtime context:');
        _safeLog('  - kIsWeb: $kIsWeb');
        try {
          _safeLog('  - Error occurred during app initialization');
        } catch (e) {
          _safeLog('  - Could not get additional context: ${_safeStr(e)}');
        }
      }
      final stackStr = _safeStr(stack);

      _safeLog('Uncaught error in zone: $errStr');
      _safeLog('Stack: $stackStr');

      if (!kIsWeb) return;

      // This is your current loop trigger. Try targeted cleanup before “nuke”.
      final looksLikeNullCrash =
          errStr.contains('Null check operator') || errStr.contains("reading 'toString'");
      if (!looksLikeNullCrash) return;

      await _attemptWebStorageRecovery();
    },
  );
}

Future<void> _initializeApp() async {
  if (kIsWeb) {
    GoRouter.optionURLReflectsImperativeAPIs = true;
    usePathUrlStrategy();
  }

  // Optional local env
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}

  // Don't proactively clean storage - only clean on actual errors
  // This prevents interfering with active OAuth flows

  try {
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        autoRefreshToken: true,
      ),
      realtimeClientOptions: const RealtimeClientOptions(eventsPerSecond: 2),
    );
    
    if (kIsWeb) {
      try {
        if (Supabase.instance.client.auth.currentSession != null) {
          html.window.localStorage.remove('statusxp_logged_out');
        }
      } catch (e) {
        _safeLog('Error clearing logout flag: ${_safeStr(e)}');
      }
    }
    
    // Check if we have a session but it's invalid (corrupt refresh token)
    if (Supabase.instance.client.auth.currentSession != null) {
      try {
        // Try to refresh to validate the session
        await Supabase.instance.client.auth.refreshSession();
      } catch (e) {
        // If refresh fails with invalid token error, clear the corrupt session
        if (e.toString().contains('refresh_token_not_found') || 
            e.toString().contains('Invalid Refresh Token')) {
          _safeLog('🔄 Detected corrupt refresh token, clearing session...');
          try {
            await Supabase.instance.client.auth.signOut();
          } catch (signOutError) {
            _safeLog('Error during forced sign out: ${_safeStr(signOutError)}');
          }
        }
      }
    }

    authRefreshService = AuthRefreshService(Supabase.instance.client);

    if (Supabase.instance.client.auth.currentSession != null) {
      authRefreshService.startPeriodicRefresh();
    }

    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      try {
        final event = data.event;
        final session = data.session;

        if (event == AuthChangeEvent.signedIn && session != null) {
          authRefreshService.startPeriodicRefresh();
          _syncBiometricSessionIfNeeded(session);
        } else if (event == AuthChangeEvent.signedOut) {
          authRefreshService.stopPeriodicRefresh();
        }
        // ignore tokenRefreshed to avoid loops
      } catch (e, stack) {
        _safeLog('⚠️ Error in auth state change listener: ${_safeStr(e)}');
        _safeLog('Stack: ${_safeStr(stack)}');
      }
    });
  } catch (e) {
    _safeLog('Supabase initialization error (likely corrupt session): ${_safeStr(e)}');
    // Clear ALL storage and force clean restart
    if (kIsWeb) {
      try {
        html.window.localStorage.clear();
        _safeLog('Cleared all storage due to initialization error - page will reload');
      } catch (clearError) {
        _safeLog('Failed to clear storage: ${_safeStr(clearError)}');
      }
    }
    // App will continue to load without authentication - user will see login screen
    _safeLog('App loading without session - user will need to login');
  }

  if (!kIsWeb) {
    await SubscriptionService().initialize();
  }

  WidgetsBinding.instance.addObserver(_AppLifecycleObserver());

  runApp(const ProviderScope(child: StatusXPApp()));
}

class StatusXPApp extends ConsumerStatefulWidget {
  const StatusXPApp({super.key});

  @override
  ConsumerState<StatusXPApp> createState() => _StatusXPAppState();
}

class _StatusXPAppState extends ConsumerState<StatusXPApp> {
  AppLinks? _appLinks;
  StreamSubscription<Uri>? _sub;
  bool _hasCheckedInterruptedSyncs = false;

  @override
  void initState() {
    super.initState();

    if (kIsWeb) {
      _handleWebAuthCallback();
    } else {
      _initDeepLinks();
    }
    
    // Check for interrupted syncs after a short delay to allow providers to initialize
    Future.delayed(const Duration(seconds: 2), () {
      _checkForInterruptedSyncs();
    });
  }
  
  Future<void> _checkForInterruptedSyncs() async {
    if (_hasCheckedInterruptedSyncs) return;
    _hasCheckedInterruptedSyncs = true;
    
    try {
      // Only check if user is authenticated
      if (Supabase.instance.client.auth.currentSession == null) {
        return;
      }
      
      final syncResumeService = ref.read(syncResumeServiceProvider);
      await syncResumeService.checkAndResumeInterruptedSyncs();
    } catch (e) {
      _safeLog('Error checking for interrupted syncs: ${_safeStr(e)}');
      // Don't crash the app if sync resume fails
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _handleWebAuthCallback() async {
    try {
      final uri = Uri.base;
      final hasAuthStuff = uri.fragment.isNotEmpty || uri.queryParameters.containsKey('code');

      if (!hasAuthStuff) return;

      try {
        await Supabase.instance.client.auth.getSessionFromUrl(uri);
      } finally {
        final cleanUri = uri.replace(query: '', fragment: '');
        html.window.history.replaceState(null, '', cleanUri.toString());
      }
    } catch (e) {
      _safeLog('Error handling OAuth callback: ${_safeStr(e)}');
    }
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    _sub = _appLinks!.uriLinkStream.listen(
      (uri) => _handleDeepLink(uri),
      onError: (e) => _safeLog('Deep link stream error: ${_safeStr(e)}'),
    );

    try {
      final initial = await _appLinks!.getInitialLink();
      if (initial != null) await _handleDeepLink(initial);
    } catch (e) {
      _safeLog('Initial deep link read error: ${_safeStr(e)}');
    }
  }

  Future<void> _handleDeepLink(Uri uri) async {
    _safeLog('Deep link received: $uri');

    final fullUrl = uri.toString();
    final isRecovery =
        fullUrl.contains('type=recovery') || fullUrl.contains('reset-password');

    if (!isRecovery) return;

    try {
      _safeLog('Password reset link detected');

      await Supabase.instance.client.auth.getSessionFromUrl(Uri.parse(fullUrl));

      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 300));
      appRouter.go('/reset-password');
    } catch (e, stack) {
      _safeLog('Error handling password reset: ${_safeStr(e)}');
      _safeLog('Stack: ${_safeStr(stack)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = MaterialApp.router(
      title: 'StatusXP',
      debugShowCheckedModeBanner: false,
      theme: statusXPTheme,
      routerConfig: appRouter,
    );

    // Web: Center app with max-width constraint (looks like mobile app in browser)
    if (kIsWeb) {
      return Container(
        color: const Color(0xFF0A0A0F), // backgroundDark
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            child: app,
          ),
        ),
      );
    }

    return app;
  }
}

/// --------------------
/// Web storage cleanup
/// --------------------

bool _isSupabaseAuthStorageKey(String key) {
  if (key.startsWith('sb-') && key.endsWith('-auth-token')) return true;
  return key.contains('supabase') && key.contains('auth');
}

bool _isOAuthFlowKey(String key) {
  // Preserve OAuth PKCE flow keys - these are needed during active login
  return key.contains('code-verifier') || 
         key.contains('code_challenge') ||
         key.contains('oauth-state');
}

Map<String, dynamic>? _tryDecodeMap(String raw) {
  try {
    final parsed = jsonDecode(raw);
    return parsed is Map<String, dynamic> ? parsed : null;
  } catch (_) {
    return null;
  }
}

Future<void> _attemptWebStorageRecovery() async {
  // Prevent infinite loops
  const flagKey = 'statusxp_already_recovered_storage';
  try {
    final storage = html.window.localStorage;
    final already = storage[flagKey] == 'true';
    if (already) {
      _safeLog('Already recovered storage once - not reloading again.');
      return;
    }

    _safeLog('Attempting targeted storage recovery...');
    storage[flagKey] = 'true';

    // First: only remove Supabase auth keys (but preserve OAuth flow keys)
    final keys = storage.keys.toList(growable: false);
    for (final k in keys) {
      if (_isSupabaseAuthStorageKey(k) && !_isOAuthFlowKey(k)) {
        storage.remove(k);
      }
    }

    // If you still want the nuclear option, do it *after* targeted cleanup:
    // storage.clear(); storage[flagKey] = 'true';

    // Force page reload (commented out due to Location API compatibility issues)
    // TODO: Fix page reload for production recovery
    _safeLog('Storage recovery complete - please refresh the page manually');
  } catch (e) {
    _safeLog('Storage recovery failed: ${_safeStr(e)}');
  }
}

/// --------------------
/// Biometrics (mobile)
/// --------------------

Future<void> _syncBiometricSessionIfNeeded(Session session) async {
  if (kIsWeb) return;

  final enabled = await _biometric.isBiometricEnabled();
  if (!enabled) return;

  // With refresh token flow, we don’t need to re-sync if already stored
  final hasToken = await _biometric.hasStoredRefreshToken();
  if (hasToken) return;

  final refreshToken = session.refreshToken;
  final expiresAtSec = session.expiresAt;

  if (refreshToken != null && expiresAtSec != null) {
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(expiresAtSec * 1000);
    await _biometric.storeRefreshToken(
      refreshToken: refreshToken,
      userId: session.user.id,
      expiresAt: expiresAt,
    );
  }
}

/// --------------------
/// “Logging that never crashes”
/// --------------------

void _safeLog(String message) {
  try {
    statusxpLog(message);
  } catch (_) {
    // last-ditch fallback: never crash because logging failed
    // ignore
  }
}

String _safeStr(Object? o) {
  try {
    return o?.toString() ?? 'null';
  } catch (_) {
    return 'unprintable';
  }
}
