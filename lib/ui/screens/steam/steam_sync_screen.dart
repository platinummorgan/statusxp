import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:statusxp/ui/widgets/platform_sync_widget.dart';

/// Steam Sync Screen - Manage Steam achievement syncing
class SteamSyncScreen extends ConsumerStatefulWidget {
  const SteamSyncScreen({super.key});

  @override
  ConsumerState<SteamSyncScreen> createState() => _SteamSyncScreenState();
}

class _SteamSyncScreenState extends ConsumerState<SteamSyncScreen> {
  bool _isLoading = true;
  bool _isSyncing = false;
  String? _steamId;
  String? _syncStatus;
  int _syncProgress = 0;
  String? _error;
  DateTime? _lastSyncAt;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      if (userId != null) {
        final data = await supabase
            .from('profiles')
            .select('steam_id, steam_sync_status, steam_sync_progress, steam_sync_error, last_steam_sync_at')
            .eq('id', userId)
            .single();

        setState(() {
          _steamId = data['steam_id'] as String?;
          _syncStatus = data['steam_sync_status'] as String?;
          _syncProgress = data['steam_sync_progress'] as int? ?? 0;
          _lastSyncAt = data['last_steam_sync_at'] != null 
              ? DateTime.parse(data['last_steam_sync_at'] as String)
              : null;
          _isSyncing = _syncStatus == 'syncing' || _syncStatus == 'pending';
          _isLoading = false;
        });

        // If syncing or pending, start polling
        if (_isSyncing) {
          _pollSyncStatus();
        }
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _startSync() async {
    if (_steamId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Steam credentials not configured'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSyncing = true);

    try {
      final supabase = Supabase.instance.client;
      await supabase.functions.invoke('steam-start-sync');

      if (mounted) {
        // Poll for status updates
        _pollSyncStatus();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to start sync: $e';
          _isSyncing = false;
        });
      }
    }
  }

  Future<void> _pollSyncStatus() async {
    while (_isSyncing && mounted) {
      await Future.delayed(const Duration(seconds: 2));
      await _loadProfile();

      // If status is pending, automatically continue sync
      if (_syncStatus == 'pending') {
        try {
          await Supabase.instance.client.functions.invoke('steam-start-sync');
        } catch (e) {
          print('Error continuing sync: $e');
        }
        // Continue polling
        continue;
      }

      if (_syncStatus == 'success' || _syncStatus == 'error') {
        setState(() => _isSyncing = false);
        break;
      }
    }
  }

  Future<void> _stopSync() async {
    try {
      await Supabase.instance.client.functions.invoke('steam-stop-sync');
      setState(() => _isSyncing = false);
      await _loadProfile();
    } catch (e) {
      setState(() {
        _error = 'Failed to stop sync: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Steam Sync')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_steamId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Steam Sync')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              'Steam credentials not configured.\n\nPlease add your Steam ID and API key in Settings.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Steam Sync')),
      body: PlatformSyncWidget(
        platformName: 'Steam',
        platformColor: const Color(0xFF1B2838),
        platformIcon: const Icon(
          Icons.videogame_asset,
          size: 64,
          color: Colors.white,
        ),
        syncStatus: _syncStatus,
        syncProgress: _syncProgress,
        lastSyncAt: _lastSyncAt,
        errorMessage: _error,
        isSyncing: _isSyncing,
        onSyncPressed: _startSync,
        onStopPressed: _stopSync,
        syncDescription: const [
          'Syncs all your Steam games with achievements',
          'Processes 5 games at a time to avoid timeouts',
          'Automatically resumes until all games are synced',
          'Fetches global achievement percentages',
          'You can stop the sync at any time and resume later',
        ],
      ),
    );
  }
}
