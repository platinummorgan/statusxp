import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:statusxp/state/security_reconnect_provider.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/ui/screens/psn/psn_connect_screen.dart';
import 'package:statusxp/ui/screens/xbox/xbox_connect_screen.dart';
import 'package:statusxp/ui/screens/steam/steam_configure_screen.dart';

/// Every authenticated route waits for the server's reconnect requirements.
/// Connection forms are opened over this gate; closing a form never unlocks it.
class SecurityReconnectGate extends ConsumerStatefulWidget {
  const SecurityReconnectGate({super.key, required this.child, this.onConnect});
  final Widget child;
  final Future<bool?> Function(SecurityReconnectRequirement)? onConnect;

  @override
  ConsumerState<SecurityReconnectGate> createState() =>
      _SecurityReconnectGateState();
}

class _SecurityReconnectGateState extends ConsumerState<SecurityReconnectGate>
    with WidgetsBindingObserver {
  String? _busyPlatform;
  String? _error;
  Timer? _syncPoller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _syncPoller?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _busyPlatform == null) {
      ref.invalidate(securityReconnectRequirementsProvider);
    }
  }

  Future<void> _connect(SecurityReconnectRequirement requirement) async {
    setState(() {
      _busyPlatform = requirement.platform;
      _error = null;
    });
    try {
      final connected = widget.onConnect != null
          ? await widget.onConnect!(requirement)
          : await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => switch (requirement.platform) {
                  'psn' => const PSNConnectScreen(securityReconnect: true),
                  'xbox' => const XboxConnectScreen(),
                  'steam' => SteamConfigureScreen(
                    initialSteamId: requirement.accountId,
                  ),
                  _ => throw StateError('Unsupported reconnect platform'),
                },
              ),
            );
      if (connected == true && requirement.platform == 'steam') {
        await ref.read(securityReconnectRepositoryProvider).verifySteam();
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Reconnect could not be verified. Use a fresh sign-in or a new Steam key, then try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busyPlatform = null);
        ref.invalidate(securityReconnectRequirementsProvider);
      }
    }
  }

  Future<void> _reportReset(SecurityReconnectRequirement requirement) async {
    setState(() {
      _busyPlatform = requirement.platform;
      _error = null;
    });
    try {
      await ref
          .read(securityReconnectRepositoryProvider)
          .reportReset(requirement.platform);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not save that step. Try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _busyPlatform = null);
        ref.invalidate(securityReconnectRequirementsProvider);
      }
    }
  }

  Future<void> _stopSync(SecurityReconnectRequirement requirement) async {
    setState(() {
      _busyPlatform = requirement.platform;
      _error = null;
    });
    try {
      await ref
          .read(securityReconnectRepositoryProvider)
          .stopSync(requirement.platform);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not stop the sync. Try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _busyPlatform = null);
        ref.invalidate(securityReconnectRequirementsProvider);
      }
    }
  }

  Future<void> _openProvider(SecurityReconnectRequirement requirement) async {
    final url = switch (requirement.platform) {
      'psn' => 'https://www.playstation.com/en-us/support/account/sign-in/',
      'xbox' => 'https://account.live.com/consent/Manage',
      'steam' => 'https://steamcommunity.com/dev/apikey',
      _ => throw StateError('Unsupported reconnect platform'),
    };
    try {
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
      if (!opened && mounted) {
        setState(() => _error = 'Could not open account security. Try again.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not open account security. Try again.');
      }
    }
  }

  Widget _retryScreen({required bool loading}) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              const CircularProgressIndicator()
            else ...[
              const Text('We could not check your account connections.'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () =>
                    ref.invalidate(securityReconnectRequirementsProvider),
                child: const Text('Try again'),
              ),
              TextButton(
                onPressed: () => ref.read(authServiceProvider).signOut(),
                child: const Text('Sign out'),
              ),
            ],
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return ref
        .watch(securityReconnectRequirementsProvider)
        .when(
          skipLoadingOnRefresh: false,
          loading: () => _retryScreen(loading: true),
          error: (_, _) => _retryScreen(loading: false),
          data: (requirements) {
            if (requirements.any((r) => r.syncActive)) {
              _syncPoller ??= Timer.periodic(const Duration(seconds: 4), (_) {
                if (mounted && _busyPlatform == null) {
                  ref.invalidate(securityReconnectRequirementsProvider);
                }
              });
            } else {
              _syncPoller?.cancel();
              _syncPoller = null;
            }
            if (requirements.isEmpty) return widget.child;
            return PopScope(
              canPop: false,
              child: Scaffold(
                appBar: AppBar(
                  automaticallyImplyLeading: false,
                  title: const Text('Reconnect your accounts'),
                ),
                body: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        const Text(
                          'A security update requires you to reconnect your gaming accounts before continuing.',
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Your saved games, achievements and stats will stay. Reconnect the same accounts.',
                        ),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Text(
                              _error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        for (final requirement in requirements)
                          _card(requirement),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: _busyPlatform == null
                              ? () => ref.invalidate(
                                  securityReconnectRequirementsProvider,
                                )
                              : null,
                          child: const Text('Check progress'),
                        ),
                        TextButton(
                          onPressed: _busyPlatform == null
                              ? () => ref.read(authServiceProvider).signOut()
                              : null,
                          child: const Text('Sign out'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
  }

  Widget _card(SecurityReconnectRequirement requirement) {
    final instruction = switch (requirement.platform) {
      'psn' =>
        'Open PlayStation account security and choose Sign Out on All Devices. Then return here and use a fresh PlayStation sign-in.',
      'xbox' =>
        'Open Microsoft app permissions and remove StatusXP access. Then return here and sign in to the same Xbox account again. If you cannot remove access, use Microsoft account support before continuing.',
      'steam' =>
        'Open Steam API-key settings, revoke the old key and create a new one. Then return here and enter the replacement key for the same Steam account.',
      _ => throw StateError('Unsupported reconnect platform'),
    };
    final enabled = _busyPlatform == null;
    return Card(
      margin: const EdgeInsets.only(top: 24),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              requirement.label,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(instruction),
            const SizedBox(height: 12),
            if (requirement.syncActive) ...[
              const Text(
                'Stop the current sync before reconnecting. Check progress once it has stopped.',
              ),
              TextButton(
                onPressed: enabled ? () => _stopSync(requirement) : null,
                child: const Text('Stop sync'),
              ),
            ] else ...[
              TextButton(
                onPressed: enabled ? () => _openProvider(requirement) : null,
                child: const Text('Open account security'),
              ),
              if (!requirement.resetReported)
                OutlinedButton(
                  onPressed: enabled ? () => _reportReset(requirement) : null,
                  child: const Text('I completed the security steps'),
                ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: enabled && requirement.resetReported
                    ? () => _connect(requirement)
                    : null,
                child: Text('Reconnect ${requirement.label}'),
              ),
            ],
            if (_busyPlatform == requirement.platform)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: LinearProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}
