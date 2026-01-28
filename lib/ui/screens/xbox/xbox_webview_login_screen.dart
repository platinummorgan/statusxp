import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// WebView screen for Xbox Live (Microsoft) OAuth authentication
class XboxWebViewLoginScreen extends StatefulWidget {
  const XboxWebViewLoginScreen({super.key});

  @override
  State<XboxWebViewLoginScreen> createState() => _XboxWebViewLoginScreenState();
}

class _XboxWebViewLoginScreenState extends State<XboxWebViewLoginScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  // Microsoft OAuth configuration
  // Override via --dart-define=XBOX_CLIENT_ID=... when needed
  static const String clientId = String.fromEnvironment(
    'XBOX_CLIENT_ID',
    defaultValue: 'f64fede5-9343-4dc9-a145-8daa499357a3',
  );
  static const String redirectUri = 'https://login.live.com/oauth20_desktop.srf';
  static const String scope = 'XboxLive.signin XboxLive.offline_access';
  
  @override
  void initState() {
    super.initState();
    
    // Microsoft OAuth URL
    final authUrl = Uri.https('login.live.com', '/oauth20_authorize.srf', {
      'client_id': clientId,
      'response_type': 'code',
      'redirect_uri': redirectUri,
      'scope': scope,
      'state': 'statusxp_xbox_auth',
    });

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) {
              setState(() => _isLoading = true);
            }
          },
          onPageFinished: (String url) async {
            if (mounted) {
              setState(() => _isLoading = false);
            }
            
            // Use JavaScript to get the actual URL (not sanitized)
            final actualUrl = await _controller.runJavaScriptReturningResult('window.location.href');
            final cleanUrl = actualUrl.toString().replaceAll('"', '');
            _checkForAuthCode(cleanUrl);
          },
          onNavigationRequest: (NavigationRequest request) {
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(authUrl);
  }

  String? _extractCodeFromUrl(String url) {
    final match = RegExp(r'[?&]code=([^&#]+)').firstMatch(url);
    if (match == null) return null;
    final rawCode = match.group(1);
    if (rawCode == null || rawCode.isEmpty) return null;
    return Uri.decodeComponent(rawCode);
  }

  void _checkForAuthCode(String url) {
    final uri = Uri.parse(url);
    
    // Debug: Print the URL we're checking
    // Check if we're at the redirect URI
    if (uri.host == 'login.live.com' && uri.path.contains('oauth20_desktop.srf')) {
      // Extract code without converting '+' to space
      String? code = _extractCodeFromUrl(url);
      if (code == null && uri.fragment.isNotEmpty) {
        code = _extractCodeFromUrl('?${uri.fragment}');
      }
      
      final error = uri.queryParameters['error'];
      if (error != null) {
        // OAuth error occurred
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Authentication failed: $error'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      if (code != null) {
        // Successfully got authorization code
        Navigator.of(context).pop(code);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign in with Microsoft'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
