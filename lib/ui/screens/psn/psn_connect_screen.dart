import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/ui/screens/psn/psn_webview_login_screen.dart';

/// Screen for connecting PlayStation Network account
class PSNConnectScreen extends ConsumerStatefulWidget {
  const PSNConnectScreen({super.key});

  @override
  ConsumerState<PSNConnectScreen> createState() => _PSNConnectScreenState();
}

class _PSNConnectScreenState extends ConsumerState<PSNConnectScreen> {
  bool _isLoading = false;
  String? _error;
  String? _successMessage;

  Future<void> _signInWithPlayStation() async {
    // Open WebView login screen
    final npsso = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => const PSNWebViewLoginScreen(),
      ),
    );

    // User canceled login
    if (npsso == null || !mounted) {
      return;
    }

    // Process the NPSSO token
    await _linkAccount(npsso);
  }

  Future<void> _linkAccount(String npsso) async {
    if (npsso.isEmpty || npsso.length != 64) {
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
      final psnService = ref.read(psnServiceProvider);
      final result = await psnService.linkAccount(npsso);

      if (mounted) {
        setState(() {
          _isLoading = false;
          _successMessage = 
              'Successfully linked PSN account!\n'
              'Trophy Level: ${result.trophyLevel}\n'
              'Total Trophies: ${result.totalTrophies}';
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
        title: const Text('Connect PlayStation Network'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // PlayStation logo placeholder
            Icon(
              Icons.sports_esports,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 32),
            
            const Text(
              'Link Your PlayStation Account',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            
            const Text(
              'Sign in with your PlayStation Network credentials to automatically import your trophies and gaming stats.',
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
            if (_successMessage == null)
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _signInWithPlayStation,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.login),
                  label: Text(
                    _isLoading ? 'Connecting...' : 'Sign in with PlayStation',
                    style: const TextStyle(fontSize: 18),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
            
            const SizedBox(height: 24),
            
            // Privacy note
            Text(
              'Your credentials are entered securely on Sony\'s official website. '
              'StatusXP never sees your password.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
