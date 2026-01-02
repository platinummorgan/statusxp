import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/data/xbox_service.dart';
import 'package:statusxp/services/auto_sync_service.dart';
import 'package:statusxp/ui/widgets/platform_sync_widget.dart';
import 'package:statusxp/services/sync_limit_service.dart';

/// Screen for syncing Xbox achievements
class XboxSyncScreen extends ConsumerStatefulWidget {
  const XboxSyncScreen({super.key});

  @override
  ConsumerState<XboxSyncScreen> createState() => _XboxSyncScreenState();
}

class _XboxSyncScreenState extends ConsumerState<XboxSyncScreen> {
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
    final status = await _syncLimitService.canUserSync('xbox');
    if (mounted) {
      setState(() {
        _rateLimitStatus = status;
      });
    }
  }

  Future<void> _startSync() async {
    // Check rate limit first
    final limitStatus = await _syncLimitService.canUserSync('xbox');
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
      final xboxService = ref.read(xboxServiceProvider);
      await xboxService.startSync();

      // Record successful sync start
      await _syncLimitService.recordSync('xbox', success: true);
      
      // Refresh rate limit status
      await _checkRateLimit();

      if (mounted) {
        // Start polling for status updates
        _pollSyncStatus();
      }
    } on XboxRateLimitException catch (e) {
      // Record failed sync
      await _syncLimitService.recordSync('xbox', success: false);
      
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _isSyncing = false;
        });
      }
    } catch (e) {
      // Record failed sync
      await _syncLimitService.recordSync('xbox', success: false);
      
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isSyncing = false;
        });
      }
    }
  }

  Future<void> _pollSyncStatus() async {
    XboxSyncStatus? lastStatus;
    
    while (_isSyncing && mounted) {
      await Future.delayed(const Duration(seconds: 3));
      
      // Read status without invalidating (stream will update automatically)
      final statusAsync = ref.read(xboxSyncStatusProvider);
      
      await statusAsync.when(
        data: (status) async {
          // Only log if status actually changed
          if (lastStatus?.status != status.status || lastStatus?.progress != status.progress) {
            lastStatus = status;
          }
          
          // If status is pending, automatically continue sync
          if (status.status == 'pending') {
            print('Status is PENDING - calling startSync()');
            try {
              final xboxService = ref.read(xboxServiceProvider);
              await xboxService.startSync();
              print('startSync() completed successfully');
            } catch (e) {
              // Don't stop polling - keep trying
            }
            return;
          }

          // Check if sync completed or failed
          if (status.status == 'completed' || status.status == 'success') {
            // Update last sync time for auto-sync
            final autoSyncService = AutoSyncService(
              supabase: ref.read(supabaseClientProvider),
              psnService: ref.read(psnServiceProvider),
              xboxService: ref.read(xboxServiceProvider),
            );
            await autoSyncService.updateXboxSyncTime();
            
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
        loading: () async {
        },
        error: (error, stack) async {
          if (mounted) {
            setState(() {
              _isSyncing = false;
              _errorMessage = error.toString();
            });
          }
        },
      );

      // Exit loop if no longer syncing
      if (!_isSyncing) break;
    }
  }

  Future<void> _stopSync() async {
    try {
      final xboxService = ref.read(xboxServiceProvider);
      await xboxService.stopSync();

      if (mounted) {
        setState(() {
          _isSyncing = false;
        });

        // Refresh sync status
        ref.invalidate(xboxSyncStatusProvider);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to stop sync: ${e.toString()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final syncStatusAsync = ref.watch(xboxSyncStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Xbox Sync'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
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
          final isSyncing = status.status == 'syncing' || status.status == 'pending' || _isSyncing;
          
          // Build rate limit message
          String? rateLimitMessage;
          if (_rateLimitStatus != null && !_rateLimitStatus!.canSync) {
            if (_rateLimitStatus!.waitSeconds > 0) {
              rateLimitMessage = 'Xbox sync on cooldown. Next sync available in ${_rateLimitStatus!.waitTimeFormatted}';
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
                      platformName: 'Xbox',
                      platformColor: const Color(0xFF107C10),
                      platformIcon: const Icon(
                        Icons.gamepad,
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
                        '🎮 How to Sync Xbox Live:',
                        '',
                        '1. Tap "Start Sync" button above',
                        '2. Browser will open to Microsoft login page',
                        '3. Sign in with your Microsoft/Xbox account',
                        '4. Authorize StatusXP to access your Xbox achievements',
                        '5. After authorization, click "Click to continue" at the top',
                        '6. Return to StatusXP - sync will begin automatically',
                        '',
                        '✨ What gets synced:',
                        '• All your Xbox games with achievements',
                        '• Achievement unlock dates and progress',
                        '• Global achievement rarity percentages',
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
