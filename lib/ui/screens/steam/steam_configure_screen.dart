import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/ui/screens/steam/steam_webview_login_screen.dart';
import 'package:url_launcher/url_launcher.dart';

/// Screen for connecting Steam via OpenID.
///
/// New flow:
/// - User taps "Sign in with Steam"
/// - We create a short-lived link session server-side
/// - User authenticates on Steam
/// - Callback is verified server-side and Steam ID is linked to profile
class SteamConfigureScreen extends ConsumerStatefulWidget {
  const SteamConfigureScreen({super.key});

  @override
  ConsumerState<SteamConfigureScreen> createState() =>
      _SteamConfigureScreenState();
}

class _SteamConfigureScreenState extends ConsumerState<SteamConfigureScreen> {
  bool _isLoading = false;
  String? _error;
  String? _successMessage;
  bool _handledWebCallback = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _autoHandleWebCallbackIfPresent();
      });
    }
  }

  Uri _buildReturnToUri() {
    if (kIsWeb) {
      return Uri.base.replace(
        path: '/steam-callback',
        query: null,
        fragment: null,
      );
    }
    return Uri.parse('https://statusxp.com/steam-callback');
  }

  bool _hasOpenIdCallbackParams(Uri uri) {
    if (!uri.queryParameters.containsKey('steam_state')) return false;
    return uri.queryParameters.keys.any((key) => key.startsWith('openid.'));
  }

  Future<void> _autoHandleWebCallbackIfPresent() async {
    if (_handledWebCallback || !mounted) return;
    final uri = Uri.base;
    if (!_hasOpenIdCallbackParams(uri)) return;
    _handledWebCallback = true;
    await _completeLinkWithCallback(
      uri.toString(),
      navigateToSettingsOnSuccess: true,
    );
  }

  Future<void> _startSteamLink() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _successMessage = null;
    });

    try {
      final steamService = ref.read(steamServiceProvider);
      final startResult = await steamService.startLink(
        returnTo: _buildReturnToUri().toString(),
      );

      if (!mounted) return;

      if (kIsWeb) {
        final launched = await launchUrl(
          Uri.parse(startResult.authUrl),
          webOnlyWindowName: '_self',
        );
        if (!launched && mounted) {
          setState(() {
            _isLoading = false;
            _error = 'Could not open Steam sign-in page.';
          });
        }
        return;
      }

      final callbackUrl = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (context) => SteamWebViewLoginScreen(
            authUrl: startResult.authUrl,
            returnTo: startResult.returnTo,
          ),
        ),
      );

      if (!mounted) return;

      if (callbackUrl == null || callbackUrl.isEmpty) {
        setState(() {
          _isLoading = false;
          _error = 'Steam sign-in was cancelled.';
        });
        return;
      }

      await _completeLinkWithCallback(callbackUrl, popOnSuccess: true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = _formatError(e);
      });
    }
  }

  Future<void> _completeLinkWithCallback(
    String callbackUrl, {
    bool popOnSuccess = false,
    bool navigateToSettingsOnSuccess = false,
  }) async {
    setState(() {
      _isLoading = true;
      _error = null;
      _successMessage = null;
    });

    try {
      final steamService = ref.read(steamServiceProvider);
      final result = await steamService.completeLink(callbackUrl: callbackUrl);

      if (!mounted) return;

      final displayName = result.steamDisplayName?.trim();
      final linkedAs = (displayName != null && displayName.isNotEmpty)
          ? displayName
          : result.steamId;

      setState(() {
        _isLoading = false;
        _successMessage = 'Steam connected as $linkedAs';
      });

      if (popOnSuccess) {
        Future.delayed(const Duration(milliseconds: 700), () {
          if (mounted) {
            Navigator.of(context).pop(true);
          }
        });
      } else if (navigateToSettingsOnSuccess) {
        Future.delayed(const Duration(milliseconds: 900), () {
          if (mounted) {
            context.go('/settings');
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = _formatError(e);
      });
    }
  }

  String _formatError(Object error) {
    final text = error.toString();
    if (text.startsWith('Exception: ')) {
      return text.substring('Exception: '.length);
    }
    return text;
  }

  @override
  Widget build(BuildContext context) {
    final showingCallbackState = kIsWeb && _hasOpenIdCallbackParams(Uri.base);
    final title = showingCallbackState
        ? 'Complete Steam Link'
        : 'Connect Steam';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.cloud, size: 72, color: Color(0xFF66C0F4)),
            const SizedBox(height: 16),
            const Text(
              'Link Your Steam Account',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'One-click Steam sign-in. No Steam ID or API key required.',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),

            if (_error != null) ...[
              _buildStatusCard(
                icon: Icons.error_outline,
                color: Colors.red,
                message: _error!,
              ),
              const SizedBox(height: 16),
            ],

            if (_successMessage != null) ...[
              _buildStatusCard(
                icon: Icons.check_circle_outline,
                color: Colors.green,
                message: _successMessage!,
              ),
              const SizedBox(height: 16),
            ],

            if (!_isLoading && _successMessage == null)
              ElevatedButton.icon(
                onPressed: _startSteamLink,
                icon: const Icon(Icons.login),
                label: const Text('Sign in with Steam'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B2838),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              ),

            const SizedBox(height: 28),

            Card(
              color: Colors.orange.withValues(alpha: 0.15),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.privacy_tip, color: Colors.orange),
                        SizedBox(width: 8),
                        Text(
                          'Privacy Requirement',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Steam profile Game details must be Public during sync, or Steam will hide your achievements.',
                    ),
                    SizedBox(height: 6),
                    Text(
                      'After sync finishes, you can switch back to Private.',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            Card(
              color: Colors.blue.withValues(alpha: 0.12),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.lightBlue),
                        SizedBox(width: 8),
                        Text(
                          'What Changed',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    Text('1. Tap Sign in with Steam'),
                    Text('2. Approve Steam login'),
                    Text('3. Return here automatically'),
                    Text('4. Start Steam sync from Settings'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard({
    required IconData icon,
    required Color color,
    required String message,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}
