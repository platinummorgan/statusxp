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

  // Microsoft OAuth configuration - Using Xbox Live public client (no Azure registration needed)
  static const String clientId = '000000004C12AE6F'; // Xbox Live public client ID
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

  void _checkForAuthCode(String url) {
    final uri = Uri.parse(url);
    
    // Debug: Print the URL we're checking
    // Check if we're at the redirect URI
    if (uri.host == 'login.live.com' && uri.path.contains('oauth20_desktop.srf')) {
      // Try query parameters first
      String? code = uri.queryParameters['code'];
      
      // If not in query params, check fragment
      if (code == null && uri.fragment.isNotEmpty) {
        final fragmentParams = Uri.splitQueryString(uri.fragment);
        code = fragmentParams['code'];
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
