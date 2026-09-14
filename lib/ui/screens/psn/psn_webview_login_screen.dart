import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// WebView screen for PSN OAuth login flow
///
/// This screen opens Sony's login page in a WebView, allows the user to authenticate,
/// then automatically extracts the NPSSO token from the cookie.
class PSNWebViewLoginScreen extends StatefulWidget {
  const PSNWebViewLoginScreen({super.key});

  @override
  State<PSNWebViewLoginScreen> createState() => _PSNWebViewLoginScreenState();
}

class _PSNWebViewLoginScreenState extends State<PSNWebViewLoginScreen> {
  late final WebViewController _controller;
  final WebViewCookieManager _cookieManager = WebViewCookieManager();
  bool _isLoading = true;
  bool _isExtracting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  Future<void> _initializeWebView() async {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (url) async {
            setState(() {
              _isLoading = false;
            });

            // Check if we're on the NPSSO cookie page
            if (url.contains('ssocookie')) {
              await _extractNPSSO();
            }
          },
          onWebResourceError: (error) {
            // Don't show error overlay for minor resource failures
            // Page may still be functional even if some assets fail to load
            setState(() {
              _isLoading = false;
            });
          },
        ),
      );

    // Android WebView state is shared between visits. Clear it before a new
    // link attempt so an expired NPSSO response cannot be submitted again.
    await _cookieManager.clearCookies();
    await _controller.clearCache();
    await _controller.clearLocalStorage();

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _isExtracting = false;
      _error = null;
    });
    await _controller.loadRequest(Uri.parse('https://www.playstation.com/'));
  }

  Future<void> _extractNPSSO() async {
    if (_isExtracting) return;
    setState(() {
      _isExtracting = true;
      _error = null;
    });

    try {
      // Get the page content (which should be JSON with the NPSSO)
      final content =
          await _controller.runJavaScriptReturningResult(
                'document.body.innerText',
              )
              as String;

      // Remove outer quotes that JavaScript adds
      var cleanContent = content;
      if (cleanContent.startsWith('"') && cleanContent.endsWith('"')) {
        cleanContent = cleanContent.substring(1, cleanContent.length - 1);
      }

      // Unescape any escaped characters
      cleanContent = cleanContent.replaceAll(r'\"', '"');
      cleanContent = cleanContent.replaceAll(r'\n', '');
      cleanContent = cleanContent.replaceAll(r'\r', '');

      // Try to parse as JSON
      try {
        final json = jsonDecode(cleanContent);
        if (json is Map && json.containsKey('npsso')) {
          final npsso = json['npsso'] as String;
          if (npsso.isNotEmpty && mounted) {
            // Return the NPSSO token to the previous screen
            Navigator.of(context).pop(npsso);
          }
          return;
        }
      } catch (e) {
        // If JSON parsing fails, try to extract NPSSO directly with regex
        final regExp = RegExp(r'"npsso"\s*:\s*"([^"]+)"');
        final match = regExp.firstMatch(cleanContent);
        if (match != null && mounted) {
          final npsso = match.group(1);
          if (npsso != null && npsso.isNotEmpty) {
            Navigator.of(context).pop(npsso);
            return;
          }
        }
      }

      // If we get here, extraction failed
      if (mounted) {
        setState(() {
          _error = 'Could not find authentication token. Please try again.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to extract authentication token: ${e.toString()}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExtracting = false;
        });
      }
    }
  }

  Future<void> _navigateToNPSSOPage() async {
    if (_isExtracting) return;

    // Always use Canada endpoint - works globally and accepts tokens from any regional login
    // User logs in on their regional Sony site, but NPSSO extraction works from any endpoint
    final cacheBuster = DateTime.now().millisecondsSinceEpoch;
    await _controller.loadRequest(
      Uri.parse(
        'https://ca.account.sony.com/api/v1/ssocookie?statusxp=$cacheBuster',
      ),
      headers: const {
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        'Pragma': 'no-cache',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign in with PlayStation'),
        actions: [
          if (!_isLoading && !_isExtracting)
            TextButton(
              onPressed: _navigateToNPSSOPage,
              child: const Text('Complete Sign In'),
            ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading || _isExtracting)
            const Center(child: CircularProgressIndicator()),
          if (_error != null)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(_error!),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _error = null;
                      });
                      _initializeWebView();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How to connect:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              '1. Sign in with your PlayStation credentials\n'
              '2. Tap "Complete Sign In" when done\n'
              '3. Your trophies will sync automatically',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
