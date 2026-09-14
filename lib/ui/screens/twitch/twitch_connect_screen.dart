import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/services/twitch_oauth_state.dart';
// Conditional import for web-only features
import 'package:statusxp/utils/web_utils.dart'
    if (dart.library.io) 'package:statusxp/utils/web_utils_stub.dart';

/// Screen for connecting Twitch account (WEB ONLY)
///
/// OAuth flow for linking Twitch accounts to unlock premium access for subscribers
class TwitchConnectScreen extends ConsumerStatefulWidget {
  const TwitchConnectScreen({super.key});

  @override
  ConsumerState<TwitchConnectScreen> createState() =>
      _TwitchConnectScreenState();
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

  static const _redirectUri = 'https://statusxp.com/twitch-callback';
  final _oauthState = TwitchOAuthState(
    read: WebUtils.readSessionValue,
    write: WebUtils.writeSessionValue,
    remove: WebUtils.removeSessionValue,
  );

  String? get _sessionBinding {
    final session = ref.read(supabaseClientProvider).auth.currentSession;
    return TwitchOAuthState.sessionBinding(
      session?.user.id,
      session?.accessToken,
    );
  }

  Future<void> _checkForOAuthCallback() async {
    final uri = Uri.parse(WebUtils.getCurrentUrl());
    if (uri.path != '/twitch-callback' &&
        !uri.queryParameters.containsKey('code') &&
        !uri.queryParameters.containsKey('error')) {
      return;
    }

    // Remove provider values from history before any asynchronous work.
    WebUtils.replaceUrl('/settings');
    try {
      final code = _oauthState.consumeCallback(uri, _sessionBinding);
      await _linkAccount(code);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error is StateError
              ? error.message.toString()
              : 'Unable to verify Twitch authorization. Enable browser storage and try again.';
        });
      }
    }
  }

  Future<void> _startOAuthFlow() async {
    if (!kIsWeb || _isLoading) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      if (Uri.parse(WebUtils.getCurrentUrl()).origin !=
          Uri.parse(_redirectUri).origin) {
        throw StateError(
          'Open statusxp.com and sign in there to connect Twitch.',
        );
      }
      final state = _oauthState.begin(_sessionBinding);
      final authUrl = Uri.https('id.twitch.tv', '/oauth2/authorize', {
        'client_id': _clientId,
        'redirect_uri': _redirectUri,
        'response_type': 'code',
        'scope': 'user:read:subscriptions',
        'state': state,
      });
      WebUtils.redirectTo(authUrl.toString());
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = error is StateError
              ? error.message.toString()
              : 'Unable to start Twitch authorization. Enable browser storage and try again.';
        });
      }
    }
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
      final result = await twitchService.linkAccount(code, _redirectUri);

      if (mounted) {
        setState(() {
          _isLoading = false;
          if (result.subscriptionCheckPending) {
            _successMessage =
                'Twitch account linked. Subscription verification is temporarily unavailable. '
                'Check your subscription again from Settings.';
          } else if (result.isSubscribed) {
            _successMessage =
                'Successfully linked Twitch account!\n'
                'Twitch subscription detected! 🎉\n\n'
                'Your premium status will be automatically managed based on your subscription.';
          } else {
            _successMessage =
                'Successfully linked Twitch account!\n\n'
                'Subscribe to the Platinum Morgan Twitch channel to unlock premium access!';
          }
        });

        // Return to Settings after the callback route finishes linking.
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            context.go('/settings');
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
        appBar: AppBar(title: const Text('Connect Twitch')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Twitch linking is only available on the web version.\n\n'
              'Please visit statusxp.com on your browser to link your Twitch account.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Connect Twitch')),
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
                color: const Color(0xFF9146FF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.stream, size: 60, color: Colors.white),
            ),
            const SizedBox(height: 32),

            const Text(
              'Link Your Twitch Account',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
                  ],
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
                    Icon(
                      Icons.check_circle_outline,
                      color: Colors.green.shade900,
                    ),
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
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
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
              style: TextStyle(fontSize: 14, color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
