import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:statusxp/data/auth/biometric_auth_service.dart';
import 'package:statusxp/services/subscription_service.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/theme/colors.dart';
import 'package:statusxp/ui/screens/premium_subscription_screen.dart';
import 'package:statusxp/ui/screens/psn/psn_connect_screen.dart';
import 'package:statusxp/ui/screens/steam/steam_configure_screen.dart';
import 'package:statusxp/ui/screens/steam/steam_sync_screen.dart';
import 'package:statusxp/ui/screens/updates_screen.dart';
import 'package:statusxp/ui/screens/xbox/xbox_connect_screen.dart';
import 'package:statusxp/ui/screens/twitch/twitch_connect_screen.dart';

/// Settings Screen - Platform connections and app configuration
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isLoadingProfile = true;
  Map<String, dynamic>? _profile;
  bool _showOnLeaderboard = true;

  final BiometricAuthService _biometricService = BiometricAuthService();
  String _appVersion = '...';

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _appVersion = packageInfo.version);
    } catch (_) {
      // ignore
    }
  }

  Future<void> _loadProfile() async {
    if (!mounted) return;
    setState(() => _isLoadingProfile = true);

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) {
        if (!mounted) return;
        setState(() {
          _profile = null;
          _isLoadingProfile = false;
        });
        return;
      }

      final data = await supabase
          .from('profiles')
          .select(
            'psn_account_id, psn_online_id, xbox_xuid, xbox_gamertag, '
            'steam_id, steam_api_key, steam_display_name, preferred_display_platform, '
            'last_psn_sync_at, last_xbox_sync_at, last_steam_sync_at, show_on_leaderboard, '
            'xbox_sync_status, xbox_sync_error, twitch_user_id',
          )
          .eq('id', userId)
          .single();

      if (!mounted) return;
      setState(() {
        _profile = data;
        _showOnLeaderboard = data['show_on_leaderboard'] ?? true;
        _isLoadingProfile = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingProfile = false);
    }
  }

  Future<void> _disconnectPlatform(String platform) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Disconnect $platform?'),
        content: Text(
          'This will remove the connection to your $platform account. '
          'Your synced data will remain, but you won\'t be able to sync new achievements until you reconnect.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      Map<String, dynamic> updates = {};

      if (platform == 'PlayStation') {
        updates = {
          'psn_account_id': null,
          'psn_online_id': null,
          'psn_npsso_token': null,
          'psn_access_token': null,
          'psn_refresh_token': null,
          'psn_token_expires_at': null,
          'psn_sync_status': 'never_synced',
        };
      } else if (platform == 'Xbox') {
        updates = {
          'xbox_xuid': null,
          'xbox_gamertag': null,
          'xbox_access_token': null,
          'xbox_refresh_token': null,
          'xbox_token_expires_at': null,
          'xbox_sync_status': 'never_synced',
        };
      } else if (platform == 'Steam') {
        updates = {
          'steam_id': null,
          'steam_api_key': null,
          'steam_sync_status': 'never_synced',
        };
      } else if (platform == 'Twitch') {
        updates = {
          'twitch_user_id': null,
        };
      }

      await supabase.from('profiles').update(updates).eq('id', userId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$platform disconnected successfully')),
      );
      _loadProfile();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to disconnect: $e'),
        ),
      );
    }
  }

  Future<void> _showTwitchStatusDialog() async {
    try {
      final twitchService = ref.read(twitchServiceProvider);
      
      // Show loading
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      final status = await twitchService.checkSubscription();

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.stream, color: Color(0xFF9146FF)),
              SizedBox(width: 12),
              Text('Twitch Connection'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (status.isSubscribed) ...[
                const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 8),
                    Text(
                      'Active Subscription',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('You have an active Twitch subscription!'),
                const SizedBox(height: 8),
                const Text('Premium features are unlocked. 🎉'),
                if (status.tier != null) ...[
                  const SizedBox(height: 12),
                  Text('Tier: ${status.tier}'),
                ],
              ] else ...[
                const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange),
                    SizedBox(width: 8),
                    Text(
                      'No Active Subscription',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Your Twitch account is linked, but you don\'t have an active subscription.'),
                const SizedBox(height: 8),
                const Text('Subscribe to unlock premium features!'),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            if (!status.isSubscribed)
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // TODO: Link to Twitch channel
                },
                child: const Text('Subscribe on Twitch'),
              ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading if shown
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to check Twitch status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _openUrl(String urlString) async {
    HapticFeedback.lightImpact();
    try {
      final url = Uri.parse(urlString);
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening link: $e')),
      );
    }
  }

  Future<void> _showSupportDialog() async {
    HapticFeedback.lightImpact();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.favorite, color: Colors.pink, size: 28),
            SizedBox(width: 12),
            Expanded(child: Text('Support Development')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Thanks for considering supporting StatusXP! 🙏',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This app is built with passion and zero ads. Your support helps keep it that way and motivates continued development!',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Choose your preferred method:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () async {
                final url = Uri.parse('https://paypal.me/platinummorgan');
                try {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                  if (context.mounted) Navigator.pop(context);
                } catch (_) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not open PayPal link')),
                  );
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0070BA), Color(0xFF1546A0)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text(
                          'P',
                          style: TextStyle(
                            color: Color(0xFF0070BA),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PayPal',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'One-time tip via PayPal',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.open_in_new, color: Colors.white70, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _signOut() async {
    HapticFeedback.lightImpact();
    try {
      final authService = ref.read(authServiceProvider);
      await authService.signOut();
      ref.read(biometricLockRequestedProvider.notifier).state = false;
      ref.read(biometricUnlockGrantedProvider.notifier).state = false;

      if (!mounted) return;
      context.go('/');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to sign out: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _lockApp() async {
    ref.read(biometricUnlockGrantedProvider.notifier).state = false;
    ref.read(biometricLockRequestedProvider.notifier).state = true;

    if (!mounted) return;
    context.go('/');
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text(
          'This will permanently delete your account and ALL your data:\n\n'
          '• Your profile and gaming identity\n'
          '• All achievements and trophies\n'
          '• Game library and stats\n'
          '• Flex room and display case\n'
          '• Premium status and purchases\n\n'
          'This action CANNOT be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final finalConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Are you absolutely sure?'),
        content: const Text(
          'Enter "DELETE" below to confirm account deletion.\n\n'
          'This action is permanent and cannot be reversed.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final input = await showDialog<String>(
                context: context,
                builder: (context) {
                  final controller = TextEditingController();
                  return AlertDialog(
                    title: const Text('Type DELETE'),
                    content: TextField(
                      controller: controller,
                      decoration: const InputDecoration(hintText: 'Type DELETE here'),
                      autofocus: true,
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, controller.text),
                        style: FilledButton.styleFrom(backgroundColor: Colors.red),
                        child: const Text('Confirm'),
                      ),
                    ],
                  );
                },
              );

              Navigator.pop(context, input == 'DELETE');
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );

    if (finalConfirm != true) return;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Deleting account...'),
          ],
        ),
      ),
    );

    try {
      final authService = ref.read(authServiceProvider);
      await authService.deleteAccount();

      if (!mounted) return;
      Navigator.pop(context); // close loading dialog
      context.go('/');
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete account: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final psnSyncStatus = ref.watch(psnSyncStatusProvider);
    final xboxSyncStatus = ref.watch(xboxSyncStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
      ),
      body: _isLoadingProfile
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                _buildSectionHeader('Platform Connections'),

                // PlayStation
                _buildPlatformTile(
                  icon: Icons.sports_esports,
                  iconColor: const Color(0xFF0070CC),
                  title: 'PlayStation',
                  subtitle: _profile?['psn_account_id'] != null
                      ? (_profile?['psn_online_id'] != null
                          ? 'Connected as ${_profile!['psn_online_id']}'
                          : 'Connected (sync needed)')
                      : 'Not connected',
                  isConnected: _profile?['psn_account_id'] != null,
                  syncStatus: psnSyncStatus.maybeWhen(
                    data: (status) => status.isLinked ? status.status : null,
                    orElse: () => null,
                  ),
                  lastSyncAt: _profile?['last_psn_sync_at'] != null
                      ? DateTime.parse(_profile!['last_psn_sync_at'])
                      : null,
                  onTap: () async {
                    if (_profile?['psn_account_id'] != null) {
                      await context.push('/psn-sync');
                      _loadProfile();
                    } else {
                      final result = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(builder: (context) => const PSNConnectScreen()),
                      );
                      if (result == true) _loadProfile();
                    }
                  },
                  onDisconnect: _profile?['psn_account_id'] != null
                      ? () => _disconnectPlatform('PlayStation')
                      : null,
                ),

                const Divider(height: 1),

                // Xbox
                _buildPlatformTile(
                  icon: Icons.videogame_asset,
                  iconColor: const Color(0xFF107C10),
                  title: 'Xbox',
                  subtitle: _profile?['xbox_gamertag'] != null
                      ? 'Connected as ${_profile!['xbox_gamertag']}'
                      : 'Not connected',
                  isConnected: _profile?['xbox_xuid'] != null,
                  syncStatus: xboxSyncStatus.maybeWhen(
                    data: (status) => status.isLinked ? status.status : null,
                    orElse: () => null,
                  ),
                  lastSyncAt: _profile?['last_xbox_sync_at'] != null
                      ? DateTime.parse(_profile!['last_xbox_sync_at'])
                      : null,
                  onTap: () async {
                    if (_profile?['xbox_xuid'] != null) {
                      context.push('/xbox-sync');
                    } else {
                      final result = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(builder: (context) => const XboxConnectScreen()),
                      );
                      if (result == true) _loadProfile();
                    }
                  },
                  onDisconnect: _profile?['xbox_xuid'] != null
                      ? () => _disconnectPlatform('Xbox')
                      : null,
                ),

                if ((_profile?['xbox_sync_status'] == 'error') &&
                    (_profile?['xbox_sync_error'] != null) &&
                    _profile!['xbox_sync_error']
                        .toString()
                        .toLowerCase()
                        .contains('relink'))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.withOpacity(0.4)),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.orange),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Xbox needs relinking. Disconnect then reconnect to restore syncing.',
                              style: TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const Divider(height: 1),

                // Steam
                _buildPlatformTile(
                  icon: Icons.cloud,
                  iconColor: const Color(0xFF66C0F4),
                  title: 'Steam',
                  subtitle: _profile?['steam_id'] != null
                      ? 'Connected as ${_profile?['steam_display_name'] ?? 'Unknown'}'
                      : 'Not connected',
                  isConnected: _profile?['steam_id'] != null,
                  syncStatus: _profile?['steam_id'] != null ? 'success' : null,
                  lastSyncAt: _profile?['last_steam_sync_at'] != null
                      ? DateTime.parse(_profile!['last_steam_sync_at'])
                      : null,
                  onTap: () async {
                    if (_profile?['steam_id'] != null) {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SteamSyncScreen()),
                      );
                      _loadProfile();
                    } else {
                      final result = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(builder: (context) => const SteamConfigureScreen()),
                      );
                      if (result == true) _loadProfile();
                    }
                  },
                  onDisconnect: _profile?['steam_id'] != null
                      ? () => _disconnectPlatform('Steam')
                      : null,
                ),

                // Twitch (Web only)
                if (kIsWeb) ...[
                  const Divider(height: 1),
                  _buildPlatformTile(
                    icon: Icons.stream,
                    iconColor: const Color(0xFF9146FF),
                    title: 'Twitch',
                    subtitle: _profile?['twitch_user_id'] != null
                        ? 'Connected (subscribers get premium!)'
                        : 'Not connected',
                    isConnected: _profile?['twitch_user_id'] != null,
                    onTap: () async {
                      if (_profile?['twitch_user_id'] != null) {
                        // Show subscription status dialog
                        _showTwitchStatusDialog();
                      } else {
                        final result = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const TwitchConnectScreen(),
                          ),
                        );
                        if (result == true && mounted) {
                          // Reload profile to show Twitch connection
                          await _loadProfile();
                        }
                      }
                    },
                    onDisconnect: _profile?['twitch_user_id'] != null
                        ? () => _disconnectPlatform('Twitch')
                        : null,
                  ),
                ],

                const SizedBox(height: 24),

                _buildSectionHeader('App Settings'),

                // Premium
                FutureBuilder<bool>(
                  future: SubscriptionService().isPremiumActive(),
                  builder: (context, snapshot) {
                    final isPremium = snapshot.data ?? false;

                    return ListTile(
                      leading: Icon(
                        Icons.diamond,
                        color: isPremium ? const Color(0xFFFFD700) : accentPrimary,
                      ),
                      title: Text(isPremium ? 'Premium Active' : 'Upgrade to Premium'),
                      subtitle: Text(isPremium ? 'Unlimited AI • Faster syncs' : 'Unlock unlimited features'),
                      trailing: isPremium
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: accentSuccess.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: accentSuccess),
                              ),
                              child: const Text(
                                'ACTIVE',
                                style: TextStyle(
                                  color: accentSuccess,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          : const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const PremiumSubscriptionScreen()),
                        );
                      },
                    );
                  },
                ),

                const Divider(height: 1),

                // Support
                ListTile(
                  leading: const Icon(Icons.favorite, color: Colors.pink),
                  title: const Text('Support Development'),
                  subtitle: const Text('Buy the developer a coffee ☕'),
                  trailing: const Icon(Icons.open_in_new, size: 16),
                  onTap: _showSupportDialog,
                ),

                const Divider(height: 1),

                _buildPreferredPlatformTile(),

                // Biometrics: mobile only, safely hidden on web.
                if (!kIsWeb) ...[
                  const Divider(height: 1),
                  _buildBiometricTile(),
                ],

                const Divider(height: 1),

                // Contact Support
                ListTile(
                  leading: const Icon(Icons.email_outlined),
                  title: const Text('Contact Support'),
                  subtitle: const Text('support@platovalabs.com'),
                  trailing: const Icon(Icons.open_in_new, size: 16),
                  onTap: () async {
                    const email = 'support@platovalabs.com';
                    final emailUri = Uri(
                      scheme: 'mailto',
                      path: email,
                      query: 'subject=StatusXP Support Request',
                    );

                    try {
                      await launchUrl(emailUri);
                    } catch (_) {
                      if (!mounted) return;
                      await Clipboard.setData(const ClipboardData(text: email));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Email copied to clipboard: support@platovalabs.com'),
                          duration: Duration(seconds: 3),
                        ),
                      );
                    }
                  },
                ),

                const Divider(height: 1),

                // About
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('About StatusXP'),
                  subtitle: Text('Version $_appVersion'),
                  onTap: () {
                    showAboutDialog(
                      context: context,
                      applicationName: 'StatusXP',
                      applicationVersion: _appVersion,
                      applicationLegalese:
                          '© 2025 StatusXP\n\nThe ultimate cross-platform achievement tracker',
                      children: const [
                        SizedBox(height: 16),
                        Text('Track your gaming achievements across PlayStation, Xbox, and Steam in one unified app.'),
                      ],
                    );
                  },
                ),

                const Divider(height: 1),

                // Privacy Policy
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Privacy Policy'),
                  trailing: const Icon(Icons.open_in_new, size: 16),
                  onTap: () => _openUrl(
                    'https://raw.githubusercontent.com/platinummorgan/statusxp/refs/heads/main/PRIVACY.md',
                  ),
                ),

                const Divider(height: 1),

                // Terms
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Terms of Service'),
                  trailing: const Icon(Icons.open_in_new, size: 16),
                  onTap: () => _openUrl(
                    'https://raw.githubusercontent.com/platinummorgan/statusxp/refs/heads/main/TERMS_OF_SERVICE.md',
                  ),
                ),

                const Divider(height: 1),

                // Leaderboard privacy
                SwitchListTile(
                  secondary: const Icon(Icons.leaderboard),
                  title: const Text('Show on Leaderboards'),
                  subtitle: const Text('Allow your profile to appear on public leaderboards'),
                  value: _showOnLeaderboard,
                  onChanged: _isLoadingProfile
                      ? null
                      : (value) async {
                          setState(() => _showOnLeaderboard = value);

                          try {
                            final supabase = Supabase.instance.client;
                            final userId = supabase.auth.currentUser?.id;

                            if (userId != null) {
                              await supabase.from('profiles').update({'show_on_leaderboard': value}).eq('id', userId);

                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(value
                                      ? 'You will now appear on leaderboards'
                                      : 'You are now hidden from leaderboards'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          } catch (e) {
                            if (!mounted) return;
                            setState(() => _showOnLeaderboard = !value);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to update setting: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                ),

                const Divider(height: 1),

                // Updates
                ListTile(
                  leading: const Icon(Icons.history, color: Colors.white70),
                  title: const Text('Updates'),
                  subtitle: const Text('View app changelog and recent updates'),
                  trailing: const Icon(Icons.chevron_right, color: Colors.white30),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const UpdatesScreen()),
                    );
                  },
                ),

                const Divider(height: 1),

                // Log Out / Lock
                if (kIsWeb)
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.orange),
                    title: const Text('Log Out', style: TextStyle(color: Colors.orange)),
                    subtitle: const Text('Sign out of this browser'),
                    onTap: _signOut,
                  )
                else
                  ListTile(
                    leading: const Icon(Icons.lock_outline, color: Colors.orange),
                    title: const Text('Log Out', style: TextStyle(color: Colors.orange)),
                    subtitle: const Text('Lock the app - use biometrics to get back in'),
                    onTap: _lockApp,
                  ),

                const Divider(height: 1),

                // Delete
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text('Delete Account', style: TextStyle(color: Colors.red)),
                  subtitle: const Text('Permanently delete your account and all data', style: TextStyle(fontSize: 12)),
                  onTap: _deleteAccount,
                ),
              ],
            ),
    );
  }

  Widget _buildBiometricTile() {
    return FutureBuilder<bool>(
      future: _biometricService.isBiometricAvailable(),
      builder: (context, snapshot) {
        final isAvailable = snapshot.data ?? false;
        if (!isAvailable) return const SizedBox.shrink();

        return FutureBuilder<bool>(
          future: _biometricService.isBiometricEnabled(),
          builder: (context, enabledSnapshot) {
            final isEnabled = enabledSnapshot.data ?? false;

            return ListTile(
              leading: Icon(Icons.fingerprint, color: isEnabled ? accentSuccess : null),
              title: const Text('Biometric Lock'),
              subtitle: FutureBuilder<String>(
                future: _biometricService.getBiometricTypesDescription(),
                builder: (context, typeSnapshot) {
                  final types = typeSnapshot.data ?? 'Loading...';
                  return Text(isEnabled ? 'Enabled ($types)' : 'Require $types to unlock app');
                },
              ),
              trailing: Switch(
                value: isEnabled,
                onChanged: (value) async {
                  if (value) {
                    final bioResult = await _biometricService.authenticate(
                      reason: 'Verify your identity to enable biometric authentication',
                    );

                    if (!bioResult.success) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(bioResult.errorMessage ?? 'Authentication failed'),
                          backgroundColor: Colors.red,
                          duration: const Duration(seconds: 5),
                        ),
                      );
                      return;
                    }

                    if (!mounted) return;
                    final signInMethod = await showDialog<String>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('How do you sign in?'),
                        content: const Text('Choose your sign-in method to set up biometric authentication:'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, 'oauth'),
                            child: const Text('Google / Apple'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, 'email'),
                            child: const Text('Email & Password'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                        ],
                      ),
                    );

                    if (signInMethod == null) return;

                    if (signInMethod == 'email') {
                      final credentials = await _showCredentialDialog();
                      if (credentials == null) return;

                      await _biometricService.storeCredentials(
                        credentials['email']!,
                        credentials['password']!,
                      );
                      await _biometricService.setBiometricEnabled(true);

                      if (!mounted) return;
                      setState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('✅ Biometric sign-in enabled\nYou can now use your fingerprint/face to sign in'),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 3),
                        ),
                      );
                    } else {
                      final session = Supabase.instance.client.auth.currentSession;
                      if (session != null && session.refreshToken != null && session.expiresAt != null) {
                        final expiresAt = DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000);
                        await _biometricService.storeRefreshToken(
                          refreshToken: session.refreshToken!,
                          userId: session.user.id,
                          expiresAt: expiresAt,
                        );
                      }
                      await _biometricService.setBiometricEnabled(true);

                      if (!mounted) return;
                      setState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('✅ Biometric sign-in enabled\nYou can now use your fingerprint/face to sign in'),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 3),
                        ),
                      );
                    }
                  } else {
                    await _biometricService.clearStoredCredentials();
                    await _biometricService.setBiometricEnabled(false);

                    if (!mounted) return;
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Biometric disabled')),
                    );
                  }
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildPlatformTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isConnected,
    String? syncStatus,
    DateTime? lastSyncAt,
    bool isComingSoon = false,
    required VoidCallback onTap,
    VoidCallback? onDisconnect,
  }) {
    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor),
      ),
      title: Row(
        children: [
          Flexible(child: Text(title, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          if (isConnected)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green),
              ),
              child: const Text(
                'Connected',
                style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold),
              ),
            )
          else if (isComingSoon)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange),
              ),
              child: const Text(
                'Coming Soon',
                style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitle),
          if (syncStatus != null) ...[
            const SizedBox(height: 4),
            _buildSyncStatusChip(syncStatus, lastSyncAt),
          ],
        ],
      ),
      trailing: isConnected && onDisconnect != null
          ? IconButton(
              icon: const Icon(Icons.link_off, color: Colors.red),
              tooltip: 'Disconnect',
              onPressed: onDisconnect,
            )
          : const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Widget _buildPreferredPlatformTile() {
    final currentPlatform = _profile?['preferred_display_platform'] as String? ?? 'psn';

    String platformName(String platform) {
      switch (platform) {
        case 'psn':
          return 'PlayStation';
        case 'xbox':
          return 'Xbox';
        case 'steam':
          return 'Steam';
        default:
          return platform;
      }
    }

    return ListTile(
      leading: const Icon(Icons.badge_outlined),
      title: const Text('Display Name'),
      subtitle: Text('Show ${platformName(currentPlatform)} username on dashboard'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        final selected = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Choose Display Platform'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<String>(
                  title: const Text('PlayStation Network'),
                  subtitle: _profile?['psn_online_id'] != null
                      ? Text(_profile!['psn_online_id'])
                      : const Text('Not connected'),
                  value: 'psn',
                  groupValue: currentPlatform,
                  onChanged: _profile?['psn_online_id'] != null ? (v) => Navigator.pop(context, v) : null,
                ),
                RadioListTile<String>(
                  title: const Text('Xbox Live'),
                  subtitle: _profile?['xbox_gamertag'] != null
                      ? Text(_profile!['xbox_gamertag'])
                      : const Text('Not connected'),
                  value: 'xbox',
                  groupValue: currentPlatform,
                  onChanged: _profile?['xbox_gamertag'] != null ? (v) => Navigator.pop(context, v) : null,
                ),
                RadioListTile<String>(
                  title: const Text('Steam'),
                  subtitle: _profile?['steam_display_name'] != null
                      ? Text(_profile!['steam_display_name'])
                      : const Text('Not connected'),
                  value: 'steam',
                  groupValue: currentPlatform,
                  onChanged: _profile?['steam_display_name'] != null ? (v) => Navigator.pop(context, v) : null,
                ),
              ],
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))],
          ),
        );

        if (selected == null || selected == currentPlatform) return;

        try {
          final supabase = Supabase.instance.client;
          final userId = supabase.auth.currentUser?.id;
          if (userId == null) return;

          await supabase.from('profiles').update({'preferred_display_platform': selected}).eq('id', userId);

          await _loadProfile();
          ref.invalidate(dashboardStatsProvider);

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Display platform changed to ${platformName(selected)}')),
          );
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update: $e'), backgroundColor: Colors.red),
          );
        }
      },
    );
  }

  Widget _buildSyncStatusChip(String status, DateTime? lastSyncAt) {
    String formatLastSync(DateTime dt) {
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.month}/${dt.day}/${dt.year}';
    }

    Color color;
    String text;
    IconData icon;

    switch (status) {
      case 'syncing':
      case 'pending':
        color = Colors.blue;
        text = 'Syncing...';
        icon = Icons.sync;
        break;
      case 'success':
        color = Colors.green;
        text = lastSyncAt != null ? 'Synced ${formatLastSync(lastSyncAt)}' : 'Synced';
        icon = Icons.check_circle;
        break;
      case 'error':
        color = Colors.red;
        text = 'Error';
        icon = Icons.error;
        break;
      default:
        color = Colors.grey;
        text = 'Not synced';
        icon = Icons.cloud_off;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Future<Map<String, String>?> _showCredentialDialog() async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enable Biometric Sign-In'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter your credentials to enable secure biometric sign-in.'),
              const SizedBox(height: 16),
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                keyboardType: TextInputType.emailAddress,
                validator: (value) => (value == null || value.isEmpty) ? 'Please enter your email' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: passwordController,
                decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
                obscureText: true,
                validator: (value) => (value == null || value.isEmpty) ? 'Please enter your password' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, {
                  'email': emailController.text.trim(),
                  'password': passwordController.text,
                });
              }
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}
