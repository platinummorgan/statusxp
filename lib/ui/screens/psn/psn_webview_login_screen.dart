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
  bool _isLoading = true;
  String? _error;
  String? _detectedRegion; // Track user's region (ca, us, eu, jp, etc.)

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() {
              _isLoading = true;
            });
            
            // Detect region from Sony account URL (e.g., ca.account.sony.com → "ca")
            final regionMatch = RegExp(r'https://([a-z]{2})\.account\.sony\.com').firstMatch(url);
            if (regionMatch != null) {
              setState(() {
                _detectedRegion = regionMatch.group(1);
              });
              print('[PSN Login] Detected region: $_detectedRegion');
            }
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
      )
      ..loadRequest(
        Uri.parse('https://www.playstation.com/'),
      );
  }

  Future<void> _extractNPSSO() async {
    try {
      // Get the page content (which should be JSON with the NPSSO)
      final content = await _controller.runJavaScriptReturningResult(
        'document.body.innerText',
      ) as String;

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
    }
  }

  void _navigateToNPSSOPage() {
    // Use detected region if available (e.g., ca, us, eu, jp)
    // Otherwise fall back to global endpoint
    final region = _detectedRegion ?? '';
    final prefix = region.isNotEmpty ? '$region.' : '';
    final url = 'https://${prefix}account.sony.com/api/v1/ssocookie';
    
    print('[PSN Login] Navigating to: $url');
    _controller.loadRequest(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign in with PlayStation'),
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _navigateToNPSSOPage,
              child: const Text('Complete Sign In'),
            ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
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
              color: Colors.black.withOpacity(0.1),
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
