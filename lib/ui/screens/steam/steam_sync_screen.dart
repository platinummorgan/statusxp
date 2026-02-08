import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:statusxp/services/auto_sync_service.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/ui/widgets/platform_sync_widget.dart';
import 'package:statusxp/services/sync_limit_service.dart';

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
  final SyncLimitService _syncLimitService = SyncLimitService();
  SyncLimitStatus? _rateLimitStatus;
  Timer? _countdownTimer;

  String _normalizeSyncStatus(String? status, DateTime? lastSyncAt) {
    if ((status == null || status == 'never_synced') && lastSyncAt != null) {
      return 'success';
    }
    return status ?? 'never_synced';
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _checkRateLimit();
    // Start periodic countdown timer
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        _checkRateLimit();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkRateLimit() async {
    final status = await _syncLimitService.canUserSync('steam');
    if (mounted) {
      setState(() {
        _rateLimitStatus = status;
      });
    }
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

        final lastSyncAt = data['last_steam_sync_at'] != null
            ? DateTime.parse(data['last_steam_sync_at'] as String)
            : null;
        final normalizedStatus = _normalizeSyncStatus(
          data['steam_sync_status'] as String?,
          lastSyncAt,
        );

        setState(() {
          _steamId = data['steam_id'] as String?;
          _syncStatus = normalizedStatus;
          _syncProgress = data['steam_sync_progress'] as int? ?? 0;
          _lastSyncAt = lastSyncAt;
          _isSyncing = normalizedStatus == 'syncing' || normalizedStatus == 'pending';
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

    // Check rate limit first
    final limitStatus = await _syncLimitService.canUserSync('steam');
    if (!limitStatus.canSync) {
      setState(() {
        _error = limitStatus.reason;
      });
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
      await Future.delayed(const Duration(seconds: 3));
      
      // Fetch data without rebuilding UI
      try {
        final supabase = Supabase.instance.client;
        final userId = supabase.auth.currentUser?.id;

        if (userId != null) {
            final data = await supabase
              .from('profiles')
              .select('steam_sync_status, steam_sync_progress, last_steam_sync_at')
              .eq('id', userId)
              .single();

            final lastSyncAt = data['last_steam_sync_at'] != null
              ? DateTime.parse(data['last_steam_sync_at'] as String)
              : null;
            final newStatus = _normalizeSyncStatus(
            data['steam_sync_status'] as String?,
            lastSyncAt,
            );
            final newProgress = data['steam_sync_progress'] as int? ?? 0;

          // Only update UI if status or progress actually changed
          if (newStatus != _syncStatus || newProgress != _syncProgress) {
            setState(() {
              _syncStatus = newStatus;
              _syncProgress = newProgress;
              _lastSyncAt = lastSyncAt;
            });
          }

          // If status is pending, automatically continue sync
          if (newStatus == 'pending') {
            try {
              await Supabase.instance.client.functions.invoke('steam-start-sync');
            } catch (e) {
            }
            continue;
          }

          if (newStatus == 'success' || newStatus == 'error') {
            setState(() => _isSyncing = false);
            
            // Record MANUAL sync completion in database for rate limiting
            // (auto-syncs are not recorded to avoid consuming rate limits)
            if (newStatus == 'success') {
              // Check if this was an auto-sync by looking at profile metadata
              final userId = supabase.auth.currentUser?.id;
              bool isAutoSync = false;
              if (userId != null) {
                try {
                  final profileData = await supabase
                      .from('profiles')
                      .select('steam_sync_metadata')
                      .eq('id', userId)
                      .single();
                  final metadata = profileData['steam_sync_metadata'] as Map<String, dynamic>?;
                  isAutoSync = metadata?['isAutoSync'] as bool? ?? false;
                } catch (e) {
                  debugPrint('Failed to check if auto-sync: $e');
                }
              }
              
              if (!isAutoSync) {
                try {
                  await _syncLimitService.recordSync('steam', success: true);
                  debugPrint('✅ Recorded Steam manual sync in database');
                } catch (e) {
                  debugPrint('Failed to record Steam sync in database: $e');
                }
              } else {
                debugPrint('⏩ Skipping rate limit record for auto-sync');
              }
              
              // Update last sync time for auto-sync tracking
              try {
                final supabase = Supabase.instance.client;
                final autoSyncService = AutoSyncService(
                  supabase,
                  ref.read(psnServiceProvider),
                  ref.read(xboxServiceProvider),
                );
                await autoSyncService.updateSteamSyncTime();
              } catch (e) {
                debugPrint('Failed to update Steam sync time: $e');
              }
            }
            
            await _loadProfile(); // Full reload on completion to get fresh timestamp
            
            // Refresh games list and stats to show updated data
            if (newStatus == 'success') {
              ref.refreshCoreData();
            }
            break;
          }
        }
      } catch (e) {
        // Don't stop polling on connection errors, just retry
        continue;
      }
    }
  }

  Future<void> _stopSync() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Not authenticated');
      }

      await Supabase.instance.client.functions.invoke(
        'steam-stop-sync',
        body: {'userId': userId},
      );
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
        appBar: AppBar(
          title: const Text('Steam Sync'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_steamId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Steam Sync'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
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
    
    // Build rate limit message
    String? rateLimitMessage;
    if (_rateLimitStatus != null && !_rateLimitStatus!.canSync) {
      if (_rateLimitStatus!.waitSeconds > 0) {
        rateLimitMessage = 'Steam sync on cooldown. Next sync available in ${_rateLimitStatus!.waitTimeFormatted}';
      } else {
        rateLimitMessage = _rateLimitStatus!.reason;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Steam Sync'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Try to pop first, but if nothing in stack, go home
            if (Navigator.of(context).canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
      ),
      body: Column(
        children: [
          if (rateLimitMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                border: Border.all(color: Colors.orange),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule, color: Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      rateLimitMessage,
                      style: const TextStyle(color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: PlatformSyncWidget(
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
                    '� IMPORTANT - Privacy Settings:',
                    'Your Steam profile MUST be set to PUBLIC during sync.',
                    'Go to: Profile → Edit Profile → Privacy Settings',
                    'Set "Game details" to Public',
                    '(You can change it back to Private after sync finishes)',
                    '',
                    '💻 How to Sync Steam:',
                    '',
                    '1. Get your Steam ID and API Key from Settings',
                    '2. Make sure your Steam profile is set to Public (see above)',
                    '3. Tap "Start Sync" button above',
                    '4. Sync begins immediately (no browser login needed)',
                    '',
                    '✨ What gets synced:',
                    '• All your Steam games with achievements',
                    '• Achievement unlock dates and progress',
                    '• Global achievement percentages from Steam',
                    '• Processes 5 games at a time (you can stop/resume anytime)',
                  ],

            ),
          ),
        ],
      ),
    );
  }
}
