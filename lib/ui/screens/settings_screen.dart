import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/ui/screens/psn/psn_connect_screen.dart';
import 'package:statusxp/ui/screens/xbox/xbox_connect_screen.dart';
import 'package:statusxp/ui/screens/steam/steam_sync_screen.dart';
import 'package:statusxp/ui/screens/steam/steam_configure_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Settings Screen - Platform connections and app configuration
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isLoadingProfile = true;
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload profile when returning from other screens
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoadingProfile = true);
    
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      
      if (userId != null) {
        final data = await supabase
            .from('profiles')
            .select('psn_account_id, psn_online_id, xbox_xuid, xbox_gamertag, steam_id, steam_api_key, steam_display_name, preferred_display_platform')
            .eq('id', userId)
            .single();
        
        setState(() {
          _profile = data;
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
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
      }

      await supabase
          .from('profiles')
          .update(updates)
          .eq('id', userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$platform disconnected successfully')),
        );
        _loadProfile();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to disconnect: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out?'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to sign out: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final psnSyncStatus = ref.watch(psnSyncStatusProvider);
    final xboxSyncStatus = ref.watch(xboxSyncStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: _isLoadingProfile
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // Platform Connections Section
                _buildSectionHeader('Platform Connections'),
                
                // PlayStation Network
                _buildPlatformTile(
                  icon: Icons.sports_esports,
                  iconColor: const Color(0xFF0070CC), // PlayStation blue
                  title: 'PlayStation Network',
                  subtitle: _profile?['psn_online_id'] != null
                      ? 'Connected as ${_profile!['psn_online_id']}'
                      : 'Not connected',
                  isConnected: _profile?['psn_account_id'] != null,
                  syncStatus: psnSyncStatus.maybeWhen(
                    data: (status) => status.isLinked ? status.status : null,
                    orElse: () => null,
                  ),
                  onTap: () async {
                    if (_profile?['psn_account_id'] != null) {
                      // Already connected - go to sync screen
                      context.push('/psn-sync');
                    } else {
                      // Not connected - go to connect screen
                      final result = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PSNConnectScreen(),
                        ),
                      );
                      if (result == true) {
                        _loadProfile();
                      }
                    }
                  },
                  onDisconnect: _profile?['psn_account_id'] != null
                      ? () => _disconnectPlatform('PlayStation')
                      : null,
                ),

                const Divider(height: 1),

                // Xbox Live
                _buildPlatformTile(
                  icon: Icons.videogame_asset,
                  iconColor: const Color(0xFF107C10), // Xbox green
                  title: 'Xbox Live',
                  subtitle: _profile?['xbox_gamertag'] != null
                      ? 'Connected as ${_profile!['xbox_gamertag']}'
                      : 'Not connected',
                  isConnected: _profile?['xbox_xuid'] != null,
                  syncStatus: xboxSyncStatus.maybeWhen(
                    data: (status) => status.isLinked ? status.status : null,
                    orElse: () => null,
                  ),
                  onTap: () async {
                    if (_profile?['xbox_xuid'] != null) {
                      // Already connected - show sync screen
                      context.push('/xbox-sync');
                    } else {
                      // Not connected - go to connect screen
                      final result = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const XboxConnectScreen(),
                        ),
                      );
                      if (result == true) {
                        _loadProfile();
                      }
                    }
                  },
                  onDisconnect: _profile?['xbox_xuid'] != null
                      ? () => _disconnectPlatform('Xbox')
                      : null,
                ),

                const Divider(height: 1),

                // Steam
                _buildPlatformTile(
                  icon: Icons.cloud,
                  iconColor: const Color(0xFF66C0F4), // Steam blue
                  title: 'Steam',
                  subtitle: _profile?['steam_id'] != null
                      ? 'Connected as ${_profile!['steam_display_name'] ?? 'Unknown'}'
                      : 'Not connected',
                  isConnected: _profile?['steam_id'] != null,
                  onTap: () async {
                    if (_profile?['steam_id'] != null) {
                      // Already connected - go to sync screen
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SteamSyncScreen(),
                        ),
                      );
                    } else {
                      // Not connected - go to configure screen
                      final result = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SteamConfigureScreen(),
                        ),
                      );
                      if (result == true) {
                        _loadProfile();
                      }
                    }
                  },
                  onDisconnect: _profile?['steam_id'] != null
                      ? () => _disconnectPlatform('Steam')
                      : null,
                ),

                const SizedBox(height: 24),

                // App Settings Section
                _buildSectionHeader('App Settings'),
                
                // Preferred Display Platform
                _buildPreferredPlatformTile(),

                const Divider(height: 1),
                
                // About
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('About StatusXP'),
                  subtitle: const Text('Version 1.0.0 Beta'),
                  onTap: () {
                    showAboutDialog(
                      context: context,
                      applicationName: 'StatusXP',
                      applicationVersion: '1.0.0 Beta',
                      applicationLegalese: '© 2025 StatusXP\n\nThe ultimate cross-platform achievement tracker',
                      children: [
                        const SizedBox(height: 16),
                        const Text(
                          'Track your gaming achievements across PlayStation, Xbox, and Steam in one unified app.',
                        ),
                      ],
                    );
                  },
                ),

                const Divider(height: 1),

                // Sign Out
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text(
                    'Sign Out',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: _signOut,
                ),
              ],
            ),
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
          Text(title),
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
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
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
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
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
            _buildSyncStatusChip(syncStatus),
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
        case 'psn': return 'PlayStation';
        case 'xbox': return 'Xbox';
        case 'steam': return 'Steam';
        default: return platform;
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
                  onChanged: _profile?['psn_online_id'] != null
                      ? (value) => Navigator.pop(context, value)
                      : null,
                ),
                RadioListTile<String>(
                  title: const Text('Xbox Live'),
                  subtitle: _profile?['xbox_gamertag'] != null
                      ? Text(_profile!['xbox_gamertag'])
                      : const Text('Not connected'),
                  value: 'xbox',
                  groupValue: currentPlatform,
                  onChanged: _profile?['xbox_gamertag'] != null
                      ? (value) => Navigator.pop(context, value)
                      : null,
                ),
                RadioListTile<String>(
                  title: const Text('Steam'),
                  subtitle: _profile?['steam_display_name'] != null
                      ? Text(_profile!['steam_display_name'])
                      : const Text('Not connected'),
                  value: 'steam',
                  groupValue: currentPlatform,
                  onChanged: _profile?['steam_display_name'] != null
                      ? (value) => Navigator.pop(context, value)
                      : null,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        );

        if (selected != null && selected != currentPlatform) {
          // Update preferred platform in database
          try {
            final supabase = Supabase.instance.client;
            final userId = supabase.auth.currentUser?.id;
            
            if (userId != null) {
              await supabase
                  .from('profiles')
                  .update({'preferred_display_platform': selected})
                  .eq('id', userId);
              
              // Refresh profile and dashboard
              await _loadProfile();
              ref.invalidate(dashboardStatsProvider);
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Display platform changed to ${platformName(selected)}'),
                  ),
                );
              }
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to update: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
      },
    );
  }

  Widget _buildSyncStatusChip(String status) {
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
        text = 'Synced';
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
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
