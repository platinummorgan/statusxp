import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:statusxp/data/twitch_service.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:html' as html show window, Location;

/// Screen for connecting Twitch account (WEB ONLY)
/// 
/// OAuth flow for linking Twitch accounts to unlock premium access for subscribers
class TwitchConnectScreen extends ConsumerStatefulWidget {
  const TwitchConnectScreen({super.key});

  @override
  ConsumerState<TwitchConnectScreen> createState() => _TwitchConnectScreenState();
}

class _TwitchConnectScreenState extends ConsumerState<TwitchConnectScreen> {
  static const String _clientId = String.fromEnvironment(
    'TWITCH_CLIENT_ID',
    defaultValue: 'wugdu8pbxckurjet128o523dll87f7',
  );

  bool _isLoading = false;
  String? _error;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    // Check if we're returning from OAuth callback
    if (kIsWeb) {
      _checkForOAuthCallback();
    }
  }

  Future<void> _checkForOAuthCallback() async {
    if (!kIsWeb) return;

    final uri = Uri.parse(html.window.location.href);
    final code = uri.queryParameters['code'];
    final error = uri.queryParameters['error'];

    if (error != null) {
      setState(() {
        _error = 'OAuth error: $error';
      });
      // Clean URL
      html.window.history.replaceState(null, '', '/settings');
      return;
    }

    if (code != null) {
      // Clean URL immediately
      html.window.history.replaceState(null, '', '/settings');
      
      // Process the OAuth code
      await _linkAccount(code);
    }
  }

  Future<void> _startOAuthFlow() async {
    if (!kIsWeb) {
      setState(() {
        _error = 'Twitch linking is only available on web';
      });
      return;
    }

    final redirectUri = '${html.window.location.origin}/settings';
    const scope = 'user:read:subscriptions';

    final authUrl = Uri.https('id.twitch.tv', '/oauth2/authorize', {
      'client_id': _clientId,
      'redirect_uri': redirectUri,
      'response_type': 'code',
      'scope': scope,
      'state': 'statusxp_twitch_auth',
    });

    // Redirect to Twitch OAuth page
    html.window.location.assign(authUrl.toString());
  }

  Future<void> _linkAccount(String code) async {
    if (!kIsWeb) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _successMessage = null;
    });

    try {
      final twitchService = ref.read(twitchServiceProvider);
      final redirectUri = '${html.window.location.origin}/settings';
      
      final result = await twitchService.linkAccount(code, redirectUri);

      if (mounted) {
        setState(() {
          _isLoading = false;
          if (result.isSubscribed) {
            _successMessage = 
                'Successfully linked Twitch account!\n'
                'Premium access granted! 🎉\n\n'
                'Your Twitch subscription unlocks all premium features.';
          } else {
            _successMessage = 
                'Successfully linked Twitch account!\n\n'
                'Subscribe to the StatusXP Twitch channel to unlock premium access!';
          }
        });

        // Auto-close after delay
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            Navigator.of(context).pop(true);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Connect Twitch'),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Twitch linking is only available on the web version.\n\n'
              'Please visit statusxp.app on your browser to link your Twitch account.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect Twitch'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Twitch logo
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFF9146FF), // Twitch purple
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.stream,
                size: 60,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 32),

            const Text(
              'Link Your Twitch Account',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            const Text(
              'Connect your Twitch account to automatically unlock premium access when you subscribe!',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),

            // Error message
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade900),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(color: Colors.red.shade900),
                      ),
                    ),
                  ),
                ),
              ),

            // Success message
            if (_successMessage != null)
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline, color: Colors.green.shade900),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _successMessage!,
                        style: TextStyle(color: Colors.green.shade900),
                      ),
                    ),
                  ],
                ),
              ),

            // Sign in button
            if (_successMessage == null)
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: _isLoading ? null : _startOAuthFlow,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF9146FF),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Sign in with Twitch',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),

            const SizedBox(height: 24),

            // Info text
            const Text(
              '💡 Subscribers to the StatusXP Twitch channel get automatic premium access!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
