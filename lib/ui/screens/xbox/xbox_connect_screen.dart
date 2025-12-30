import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/ui/screens/xbox/xbox_webview_login_screen.dart';

/// Screen for connecting Xbox Live account
class XboxConnectScreen extends ConsumerStatefulWidget {
  const XboxConnectScreen({super.key});

  @override
  ConsumerState<XboxConnectScreen> createState() => _XboxConnectScreenState();
}

class _XboxConnectScreenState extends ConsumerState<XboxConnectScreen> {
  bool _isLoading = false;
  String? _error;
  String? _successMessage;

  Future<void> _signInWithXbox() async {
    // Open WebView login screen for Microsoft OAuth
    final accessToken = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => const XboxWebViewLoginScreen(),
      ),
    );

    // User canceled login
    if (accessToken == null || !mounted) {
      return;
    }

    // Process the access token
    await _linkAccount(accessToken);
  }

  Future<void> _linkAccount(String accessToken) async {
    if (accessToken.isEmpty) {
      setState(() {
        _error = 'Invalid authentication token received';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _successMessage = null;
    });

    try {
      final xboxService = ref.read(xboxServiceProvider);
      final result = await xboxService.linkAccount(accessToken);

      if (mounted) {
        setState(() {
          _isLoading = false;
          _successMessage = 
              'Successfully linked Xbox account!\n'
              'Gamertag: ${result.gamertag}\n'
              'Gamerscore: ${result.gamerscore}\n'
              'Achievements: ${result.totalAchievements}';
        });

        // Navigate back after a short delay
        Future.delayed(const Duration(seconds: 2), () {
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect Xbox Live'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Xbox logo
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFF107C10), // Xbox green
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.videogame_asset,
                size: 60,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            
            const Text(
              'Link Your Xbox Account',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            
            const Text(
              'Sign in with your Microsoft account to automatically import your Xbox achievements and gaming stats.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
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
                    Icon(Icons.check_circle, color: Colors.green.shade900),
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
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _signInWithXbox,
                icon: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.login),
                label: Text(
                  _isLoading ? 'Connecting...' : 'Sign in with Microsoft',
                  style: const TextStyle(fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF107C10), // Xbox green
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Help text
            Text(
              'By connecting your Xbox account, you agree to allow StatusXP to access your achievement data.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
