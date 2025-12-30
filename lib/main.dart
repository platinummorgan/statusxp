import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:statusxp/config/supabase_config.dart';
import 'package:statusxp/theme/theme.dart';
import 'package:statusxp/ui/screens/auth/auth_gate.dart';
import 'package:statusxp/ui/screens/auth/reset_password_screen.dart';
import 'package:statusxp/services/subscription_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: '.env');

  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );

  // Initialize subscription service
  await SubscriptionService().initialize();

  runApp(const ProviderScope(child: StatusXPApp()));
}

class StatusXPApp extends ConsumerStatefulWidget {
  const StatusXPApp({super.key});

  @override
  ConsumerState<StatusXPApp> createState() => _StatusXPAppState();
}

class _StatusXPAppState extends ConsumerState<StatusXPApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late AppLinks _appLinks;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    // Handle deep links when app is already running
    _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });

    // Check if app was opened with a deep link
    try {
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        _handleDeepLink(initialLink);
      }
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _handleDeepLink(Uri uri) async {
    print('Deep link received: $uri');
    print('Fragment: ${uri.fragment}');
    
    // Check if this is a recovery/password reset link
    final fullUrl = uri.toString();
    if (fullUrl.contains('type=recovery') || fullUrl.contains('reset-password')) {
      try {
        print('Password reset link detected');
        
        // Extract the session from URL (this logs them in with recovery session)
        await Supabase.instance.client.auth.getSessionFromUrl(Uri.parse(fullUrl));
        
        print('Recovery session established, showing reset password screen');
        
        // Immediately show reset password screen
        if (mounted) {
          await Future.delayed(const Duration(milliseconds: 300));
          _navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => const ResetPasswordScreen(),
            ),
            (route) => false, // Clear all previous routes
          );
        }
      } catch (e, stackTrace) {
        print('Error handling password reset: $e');
        print('Stack trace: $stackTrace');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'StatusXP',
      debugShowCheckedModeBanner: false,
      theme: statusXPTheme,
      home: const AuthGate(),
    );
  }
}