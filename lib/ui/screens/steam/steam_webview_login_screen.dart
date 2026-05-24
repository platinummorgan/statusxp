import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// WebView screen for Steam OpenID login on mobile platforms.
class SteamWebViewLoginScreen extends StatefulWidget {
  final String authUrl;
  final String returnTo;

  const SteamWebViewLoginScreen({
    super.key,
    required this.authUrl,
    required this.returnTo,
  });

  @override
  State<SteamWebViewLoginScreen> createState() =>
      _SteamWebViewLoginScreenState();
}

class _SteamWebViewLoginScreenState extends State<SteamWebViewLoginScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  late final Uri _returnToUri;

  @override
  void initState() {
    super.initState();
    _returnToUri = Uri.parse(widget.returnTo);

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (mounted) {
              setState(() => _isLoading = true);
            }
            _tryHandleCallback(url);
          },
          onPageFinished: (url) {
            if (mounted) {
              setState(() => _isLoading = false);
            }
            _tryHandleCallback(url);
          },
          onNavigationRequest: (request) {
            if (_isSteamCallbackUrl(request.url)) {
              Navigator.of(context).pop(request.url);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.authUrl));
  }

  bool _isSteamCallbackUrl(String rawUrl) {
    Uri? uri;
    try {
      uri = Uri.parse(rawUrl);
    } catch (_) {
      return false;
    }

    if (uri.scheme != _returnToUri.scheme) return false;
    if (uri.host != _returnToUri.host) return false;
    if (uri.path != _returnToUri.path) return false;

    final expectedState = _returnToUri.queryParameters['steam_state'];
    if (expectedState == null || expectedState.isEmpty) return true;
    return uri.queryParameters['steam_state'] == expectedState;
  }

  void _tryHandleCallback(String rawUrl) {
    if (!_isSteamCallbackUrl(rawUrl)) return;
    Navigator.of(context).pop(rawUrl);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign in with Steam'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
