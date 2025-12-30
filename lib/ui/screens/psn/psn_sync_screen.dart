import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/ui/widgets/platform_sync_widget.dart';
import 'package:statusxp/services/sync_limit_service.dart';

/// Screen for managing PSN sync
class PSNSyncScreen extends ConsumerStatefulWidget {
  const PSNSyncScreen({super.key});

  @override
  ConsumerState<PSNSyncScreen> createState() => _PSNSyncScreenState();
}

class _PSNSyncScreenState extends ConsumerState<PSNSyncScreen> {
  bool _isSyncing = false;
  String? _errorMessage;
  final SyncLimitService _syncLimitService = SyncLimitService();
  SyncLimitStatus? _rateLimitStatus;

  @override
  void initState() {
    super.initState();
    _checkRateLimit();
  }

  Future<void> _checkRateLimit() async {
    final status = await _syncLimitService.canUserSync('psn');
    if (mounted) {
      setState(() {
        _rateLimitStatus = status;
      });
    }
  }

  Future<void> _startSync() async {
    // Check rate limit first
    final limitStatus = await _syncLimitService.canUserSync('psn');
    if (!limitStatus.canSync) {
      setState(() {
        _errorMessage = limitStatus.reason;
      });
      return;
    }
    setState(() {
      _isSyncing = true;
      _errorMessage = null;
    });

    try {
      final psnService = ref.read(psnServiceProvider);
      await psnService.startSync(forceResync: false);

      // Record successful sync start
      await _syncLimitService.recordSync('psn', success: true);
      
      // Refresh rate limit status
      await _checkRateLimit();

      if (mounted) {
        _pollSyncStatus();
      }
    } catch (e) {
      // Record failed sync
      await _syncLimitService.recordSync('psn', success: false);
      
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isSyncing = false;
        });
      }
    }
  }

  Future<void> _pollSyncStatus() async {
    while (_isSyncing && mounted) {
      await Future.delayed(const Duration(seconds: 2));
      
      ref.invalidate(psnSyncStatusProvider);
      final statusAsync = ref.read(psnSyncStatusProvider);
      
      await statusAsync.when(
        data: (status) async {
          // If status is pending, automatically continue sync
          if (status.isPending) {
            try {
              final psnService = ref.read(psnServiceProvider);
              await psnService.startSync(forceResync: false);
            } catch (e) {
            }
            return;
          }

          // Check if sync completed or failed
          if (status.status == 'success') {
            if (mounted) {
              setState(() {
                _isSyncing = false;
              });
              
              // Refresh games list and stats to show updated data
              ref.refreshCoreData();
              
              // Check for newly unlocked achievements
              final userId = ref.read(currentUserIdProvider);
              if (userId == null) return;
              
              final checker = ref.read(platformAchievementCheckerProvider);
              try {
                final newlyUnlocked = await checker.checkAndUnlockAchievements(userId);
                if (newlyUnlocked.isNotEmpty && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('🎉 Unlocked ${newlyUnlocked.length} achievement(s)!'),
                      action: SnackBarAction(
                        label: 'View',
                        onPressed: () => context.push('/achievements'),
                      ),
                    ),
                  );
                }
              } catch (e) {
              }
            }
            return;
          }

          if (status.status == 'error') {
            if (mounted) {
              setState(() {
                _isSyncing = false;
                _errorMessage = status.error ?? 'Sync failed';
              });
            }
            return;
          }
        },
        loading: () async {},
        error: (error, stack) async {
          if (mounted) {
            setState(() {
              _isSyncing = false;
              _errorMessage = error.toString();
            });
          }
        },
      );

      if (!_isSyncing) break;
    }
  }

  Future<void> _stopSync() async {
    // Immediate feedback to confirm function is called
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stop sync clicked...')),
      );
    }
    
    try {
      final psnService = ref.read(psnServiceProvider);
      await psnService.stopSync();
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });

        ref.invalidate(psnSyncStatusProvider);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sync stopped')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to stop sync: ${e.toString()}';
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final syncStatusAsync = ref.watch(psnSyncStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PlayStation Network Sync'),
      ),
      body: syncStatusAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Error loading sync status',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        data: (status) {
          if (!status.isLinked) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'PlayStation Network not linked.\n\nPlease link your PSN account in Settings.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final isSyncing = status.isSyncing || status.isPending || _isSyncing;
          
          // Build rate limit message
          String? rateLimitMessage;
          if (_rateLimitStatus != null && !_rateLimitStatus!.canSync) {
            if (_rateLimitStatus!.waitSeconds > 0) {
              rateLimitMessage = 'PSN sync on cooldown. Next sync available in ${_rateLimitStatus!.waitTimeFormatted}';
            } else {
              rateLimitMessage = _rateLimitStatus!.reason;
            }
          }

          return Column(
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
                      platformName: 'PlayStation',
                      platformColor: const Color(0xFF003791),
                      platformIcon: const Icon(
                        Icons.sports_esports,
                        size: 64,
                        color: Colors.white,
                      ),
                      syncStatus: status.status,
                      syncProgress: status.progress,
                      lastSyncAt: status.lastSyncAt,
                      errorMessage: _errorMessage ?? status.error,
                      isSyncing: isSyncing,
                      onSyncPressed: _startSync,
                      onStopPressed: _stopSync,
                      syncDescription: const [
                        '📱 How to Sync PlayStation Network:',
                        '',
                        '1. Tap "Start Sync" button above',
                        '2. Browser will open to PlayStation login page',
                        '3. Sign in with your PSN account credentials',
                        '4. After login, click "Click to continue" at the top of the page',
                        '5. Return to StatusXP - sync will begin automatically',
                        '',
                        '✨ What gets synced:',
                        '• All your PlayStation games with trophies',
                        '• Trophy unlock dates and progress',
                        '• Global trophy rarity percentages',
                        '• Processes 5 games at a time (you can stop/resume anytime)',
                      ],

                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
