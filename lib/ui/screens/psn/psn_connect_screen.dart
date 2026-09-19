import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/ui/screens/psn/psn_webview_login_screen.dart';
import 'package:url_launcher/url_launcher.dart';

/// Screen for connecting PlayStation Network account
class PSNConnectScreen extends ConsumerStatefulWidget {
  const PSNConnectScreen({super.key});

  @override
  ConsumerState<PSNConnectScreen> createState() => _PSNConnectScreenState();
}

class _PSNConnectScreenState extends ConsumerState<PSNConnectScreen> {
  final TextEditingController _webNpssoController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  String? _successMessage;

  @override
  void dispose() {
    _webNpssoController.dispose();
    super.dispose();
  }

  Future<void> _openSonyPage(String url) async {
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
    if (!opened && mounted) {
      setState(() {
        _error = 'Could not open Sony sign-in. Allow pop-ups and try again.';
      });
    }
  }

  Future<void> _submitWebNpsso() async {
    await _linkAccount(_webNpssoController.text.trim());
  }

  Future<void> _signInWithPlayStation() async {
    if (kIsWeb) return;

    // Open WebView login screen
    final npsso = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (context) => const PSNWebViewLoginScreen()),
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

      // Check if confirmation is required
      if (result.requiresConfirmation) {
        if (!mounted) return;

        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Link Existing Account?'),
            content: Text(
              result.message ??
                  'This PSN account is already connected to another account. Do you want to link it to this account?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Link Account'),
              ),
            ],
          ),
        );

        if (confirmed == true && result.credentials != null) {
          // User confirmed - perform the merge
          await psnService.confirmMerge(
            result.existingUserId!,
            result.credentials!,
          );

          if (mounted) {
            setState(() {
              _isLoading = false;
              _successMessage =
                  'Account linked successfully! Your gaming data has been merged.';
            });

            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) {
                Navigator.of(context).pop(true);
              }
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        }
        return;
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _successMessage =
              'Successfully linked PSN account!\n'
              'Trophy Level: ${result.trophyLevel}\n'
              'Total Trophies: ${result.totalTrophies}';
        });

        // Navigate to sync screen after successful link
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            context.go('/psn-sync');
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
      appBar: AppBar(title: const Text('Connect PlayStation Network')),
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
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            const Text(
              'Sign in with your PlayStation Network credentials to automatically import your trophies and gaming stats.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            if (kIsWeb) ...[
              const Text(
                'Web connection requires a one-time PlayStation authentication token.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton.icon(
                    onPressed: () =>
                        _openSonyPage('https://www.playstation.com/'),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('1. Sign in to PlayStation'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _openSonyPage(
                      'https://ca.account.sony.com/api/v1/ssocookie',
                    ),
                    icon: const Icon(Icons.key),
                    label: const Text('2. Get authentication token'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _webNpssoController,
                enabled: !_isLoading,
                autocorrect: false,
                enableSuggestions: false,
                maxLength: 64,
                obscureText: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: '3. Paste the 64-character token',
                  helperText: 'Copy only the value inside the npsso quotes.',
                ),
                onSubmitted: _isLoading ? null : (_) => _submitWebNpsso(),
              ),
              const SizedBox(height: 16),
            ],
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
                  onPressed: _isLoading
                      ? null
                      : kIsWeb
                      ? _submitWebNpsso
                      : _signInWithPlayStation,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Icon(Icons.login),
                  label: Text(
                    _isLoading
                        ? 'Connecting...'
                        : kIsWeb
                        ? 'Link PlayStation account'
                        : 'Sign in with PlayStation',
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
              kIsWeb
                  ? 'The token is sensitive and is sent only to StatusXP to establish your PlayStation connection. Never share it with anyone.'
                  : 'Your credentials are entered securely on Sony\'s official website. StatusXP never sees your password.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
