import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:statusxp/data/repositories/leaderboard_repository.dart' as lb;
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/data/xbox_service.dart';
import 'package:statusxp/services/auto_sync_service.dart';
import 'package:statusxp/services/sync_reconcile_service.dart';
import 'package:statusxp/services/analytics_service.dart';
import 'package:statusxp/ui/screens/xbox/xbox_connect_screen.dart';
import 'package:statusxp/ui/widgets/platform_sync_widget.dart';
import 'package:statusxp/services/sync_limit_service.dart';

import 'package:statusxp/utils/statusxp_logger.dart';
import 'package:statusxp/utils/sync_issue_classifier.dart';

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
  Timer? _countdownTimer;
  DateTime? _nextLiveDataRefreshAt;
  DateTime? _syncStartedAt;
  DateTime? _lastSyncAtBeforeSync;
  bool _suspectNoFreshWrite = false;
  String? _diagnosticWarningMessage;
  static const Duration _liveDataRefreshInterval = Duration(seconds: 8);

  @override
  void initState() {
    super.initState();
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
      _logSyncIssue(
        category: 'rate_limited',
        status: 'error',
        requiresRelink: false,
      );
      setState(() {
        _errorMessage = limitStatus.reason;
      });
      return;
    }
    setState(() {
      _isSyncing = true;
      _errorMessage = null;
      _suspectNoFreshWrite = false;
      _diagnosticWarningMessage = null;
      _syncStartedAt = DateTime.now();
      _lastSyncAtBeforeSync = ref
          .read(xboxSyncStatusProvider)
          .valueOrNull
          ?.lastSyncAt;
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
      _logSyncIssue(
        category: 'rate_limited',
        status: 'error',
        requiresRelink: false,
      );

      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _isSyncing = false;
        });
      }
    } catch (e) {
      // Record failed sync
      await _syncLimitService.recordSync('xbox', success: false);
      _logSyncIssue(
        category: 'start_failed',
        status: 'error',
        requiresRelink: false,
      );

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
          if (status.status == 'syncing' || status.status == 'pending') {
            _refreshDataDuringSync();
          }

          // Only log if status actually changed
          if (lastStatus?.status != status.status ||
              lastStatus?.progress != status.progress) {
            lastStatus = status;
          }

          // If status is pending, automatically continue sync
          if (status.status == 'pending') {
            statusxpLog('Status is PENDING - calling startSync()');
            try {
              final xboxService = ref.read(xboxServiceProvider);
              await xboxService.startSync();
              statusxpLog('startSync() completed successfully');
            } catch (e) {
              // Don't stop polling - keep trying
            }
            return;
          }

          // Check if sync completed or failed
          if (status.status == 'completed' || status.status == 'success') {
            // Record MANUAL sync in database for rate limiting
            // (auto-syncs are not recorded to avoid consuming rate limits)
            if (!status.isAutoSync) {
              try {
                final syncLimitService = SyncLimitService();
                await syncLimitService.recordSync('xbox', success: true);
                debugPrint('✅ Recorded Xbox manual sync in database');
              } catch (e) {
                debugPrint('Failed to record Xbox sync in database: $e');
              }
            } else {
              debugPrint('⏩ Skipping rate limit record for auto-sync');
            }

            // Update last sync time for auto-sync
            final autoSyncService = AutoSyncService(
              ref.read(supabaseClientProvider),
              ref.read(psnServiceProvider),
              ref.read(xboxServiceProvider),
            );
            await autoSyncService.updateXboxSyncTime();

            if (mounted) {
              final suspectNoFreshWrite = SyncIssueClassifier.hasNoFreshWrite(
                syncStartedAt: _syncStartedAt,
                previousLastSyncAt: _lastSyncAtBeforeSync,
                currentLastSyncAt: status.lastSyncAt,
              );
              if (suspectNoFreshWrite) {
                _logSyncIssue(
                  category: 'success_no_fresh_write',
                  status: status.status,
                  requiresRelink: false,
                );
              }
              setState(() {
                _isSyncing = false;
                _suspectNoFreshWrite = suspectNoFreshWrite;
                _diagnosticWarningMessage = suspectNoFreshWrite
                    ? SyncIssueClassifier.noFreshWriteWarning('Xbox')
                    : null;
              });

              await SyncReconcileService(
                ref.read(supabaseClientProvider),
              ).reconcileCurrentUser(trigger: 'xbox_sync_success_immediate');

              // Force refresh sync status to get updated last_sync_at timestamp
              ref.invalidate(xboxSyncStatusProvider);

              // Refresh games list and stats to show updated data
              ref.refreshCoreData();
              // Leaderboards are cached by Riverpod; invalidate them after sync so
              // users don't see stale totals when navigating to leaderboards.
              ref.invalidate(lb.leaderboardProvider);
              ref.invalidate(lb.seasonalLeaderboardProvider);
              ref.invalidate(leaderboardRanksProvider);
              ref.invalidate(lb.latestPeriodWinnersProvider);
              _schedulePostSyncReconciles();

              // Check for newly unlocked achievements
              final userId = ref.read(currentUserIdProvider);
              if (userId == null) return;

              final checker = ref.read(platformAchievementCheckerProvider);
              try {
                final newlyUnlocked = await checker.checkAndUnlockAchievements(
                  userId,
                );
                if (newlyUnlocked.isNotEmpty && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '🎉 Unlocked ${newlyUnlocked.length} achievement(s)!',
                      ),
                      action: SnackBarAction(
                        label: 'View',
                        onPressed: () => context.push('/achievements'),
                      ),
                    ),
                  );
                }
              } catch (e) {
                statusxpLog(
                  'Failed checking post-sync achievements (Xbox): $e',
                );
              }
            }
            return;
          }

          if (status.status == 'error') {
            final issue = SyncIssueClassifier.analyze(
              platformName: 'Xbox',
              syncStatus: status.status,
              errorMessage: status.error,
            );
            _logSyncIssue(
              category: issue.category,
              status: status.status,
              requiresRelink: issue.requiresRelink,
            );
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

  void _refreshDataDuringSync() {
    final now = DateTime.now();
    if (_nextLiveDataRefreshAt != null &&
        now.isBefore(_nextLiveDataRefreshAt!)) {
      return;
    }
    _nextLiveDataRefreshAt = now.add(_liveDataRefreshInterval);

    // Throttled live refresh so visible totals move during long-running syncs.
    ref.invalidate(dashboardStatsProvider);
    ref.invalidate(userStatsProvider);
    ref.invalidate(leaderboardRanksProvider);
    ref.invalidate(lb.leaderboardProvider);
  }

  void _schedulePostSyncReconciles() {
    // Some writes settle a few seconds after sync success; reconcile twice.
    Future.delayed(const Duration(seconds: 3), () async {
      if (!mounted) return;
      await SyncReconcileService(
        ref.read(supabaseClientProvider),
      ).reconcileCurrentUser(trigger: 'xbox_sync_t+3s');
      if (!mounted) return;
      ref.refreshCoreData();
      ref.invalidate(lb.leaderboardProvider);
      ref.invalidate(leaderboardRanksProvider);
    });

    Future.delayed(const Duration(seconds: 12), () async {
      if (!mounted) return;
      await SyncReconcileService(
        ref.read(supabaseClientProvider),
      ).reconcileCurrentUser(trigger: 'xbox_sync_t+12s');
      if (!mounted) return;
      ref.refreshCoreData();
      ref.invalidate(lb.leaderboardProvider);
      ref.invalidate(lb.seasonalLeaderboardProvider);
      ref.invalidate(leaderboardRanksProvider);
      ref.invalidate(lb.latestPeriodWinnersProvider);
    });
  }

  Future<void> _reconnectNow() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reconnect Xbox?'),
        content: const Text(
          'This will disconnect your current Xbox link and start relinking now.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reconnect'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final userId = ref.read(currentUserIdProvider);
      if (userId == null) throw Exception('Not authenticated');

      final supabase = Supabase.instance.client;
      await supabase
          .from('profiles')
          .update({
            'xbox_xuid': null,
            'xbox_gamertag': null,
            'xbox_access_token': null,
            'xbox_refresh_token': null,
            'xbox_token_expires_at': null,
            'xbox_sync_status': 'never_synced',
            'xbox_sync_error': null,
          })
          .eq('id', userId);

      if (!mounted) return;
      final relinked = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (context) => const XboxConnectScreen()),
      );
      if (relinked == true && mounted) {
        ref.invalidate(xboxSyncStatusProvider);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Reconnect failed: $e')));
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
          final isSyncing =
              status.status == 'syncing' ||
              status.status == 'pending' ||
              _isSyncing;

          // Build rate limit message
          String? rateLimitMessage;
          if (_rateLimitStatus != null && !_rateLimitStatus!.canSync) {
            if (_rateLimitStatus!.waitSeconds > 0) {
              rateLimitMessage =
                  'Xbox sync on cooldown. Next sync available in ${_rateLimitStatus!.waitTimeFormatted}';
            } else {
              rateLimitMessage = _rateLimitStatus!.reason;
            }
          }

          final syncIssue = SyncIssueClassifier.analyze(
            platformName: 'Xbox',
            syncStatus: status.status,
            errorMessage: _errorMessage ?? status.error,
          );
          final effectiveError = syncIssue.effectiveErrorMessage;
          final effectiveWarning =
              _diagnosticWarningMessage ?? syncIssue.warningMessage;

          return Column(
            children: [
              if (rateLimitMessage != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.2),
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
                  syncStatus: syncIssue.effectiveStatus,
                  syncProgress: status.progress,
                  lastSyncAt: status.lastSyncAt,
                  errorMessage: effectiveError,
                  warningMessage: effectiveWarning,
                  warningActionLabel: effectiveWarning == null
                      ? null
                      : 'Reconnect Now',
                  onWarningActionPressed: effectiveWarning == null
                      ? null
                      : _reconnectNow,
                  diagnostics: {
                    'Raw status': status.status,
                    'Issue category': _suspectNoFreshWrite
                        ? 'success_no_fresh_write'
                        : syncIssue.category,
                    'Relink required': syncIssue.requiresRelink ? 'Yes' : 'No',
                    'Progress': '${status.progress}%',
                  },
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

  void _logSyncIssue({
    required String category,
    required String status,
    required bool requiresRelink,
  }) {
    unawaited(
      AnalyticsService().logSyncIssue(
        platform: 'xbox',
        category: category,
        status: status,
        requiresRelink: requiresRelink,
      ),
    );
  }
}
