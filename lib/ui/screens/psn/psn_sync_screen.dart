import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:statusxp/data/repositories/leaderboard_repository.dart' as lb;
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/ui/widgets/platform_sync_widget.dart';
import 'package:statusxp/services/sync_limit_service.dart';
import 'package:statusxp/services/auto_sync_service.dart';
import 'package:statusxp/services/sync_reconcile_service.dart';
import 'package:statusxp/ui/screens/psn/psn_connect_screen.dart';
import 'package:statusxp/services/analytics_service.dart';
import 'package:statusxp/utils/statusxp_logger.dart';
import 'package:statusxp/utils/sync_issue_classifier.dart';

/// Screen for managing PSN sync
class PSNSyncScreen extends ConsumerStatefulWidget {
  const PSNSyncScreen({super.key});

  @override
  ConsumerState<PSNSyncScreen> createState() => _PSNSyncScreenState();
}

class _PSNSyncScreenState extends ConsumerState<PSNSyncScreen> {
  bool _isSyncing = false;
  String? _errorMessage;
  bool _relinkDialogShown = false;
  final SyncLimitService _syncLimitService = SyncLimitService();
  SyncLimitStatus? _rateLimitStatus;
  Timer? _countdownTimer;
  DateTime? _nextLiveDataRefreshAt;
  DateTime? _syncStartedAt;
  DateTime? _lastSyncAtBeforeSync;
  bool _suspectNoFreshWrite = false;
  String? _diagnosticWarningMessage;
  static const Duration _liveDataRefreshInterval = Duration(seconds: 8);
  static const String _relinkPromptMessage = 'PlayStation relink required';

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
          .read(psnSyncStatusProvider)
          .valueOrNull
          ?.lastSyncAt;
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
    while (_isSyncing && mounted) {
      await Future.delayed(const Duration(seconds: 2));

      ref.invalidate(psnSyncStatusProvider);
      final statusAsync = ref.read(psnSyncStatusProvider);

      await statusAsync.when(
        data: (status) async {
          if (status.status == 'syncing' || status.status == 'pending') {
            _refreshDataDuringSync();
          }

          if (status.requiresRelink) {
            final issue = SyncIssueClassifier.analyze(
              platformName: 'PlayStation',
              syncStatus: status.status,
              errorMessage: status.error,
              requiresRelinkSignal: true,
            );
            if (mounted) {
              setState(() {
                _isSyncing = false;
                _errorMessage =
                    issue.effectiveErrorMessage ?? _relinkPromptMessage;
                _suspectNoFreshWrite = false;
                _diagnosticWarningMessage = null;
              });
            }
            _logSyncIssue(
              category: issue.category,
              status: status.status,
              requiresRelink: true,
            );
            _showRelinkDialogIfNeeded();
            return;
          }

          // If status is pending, automatically continue sync
          if (status.isPending) {
            try {
              final psnService = ref.read(psnServiceProvider);
              await psnService.startSync(forceResync: false);
            } catch (e) {
              statusxpLog('Failed to continue pending PSN sync: $e');
            }
            return;
          }

          // Check if sync completed or failed
          if (status.status == 'success') {
            // Record MANUAL sync in database for rate limiting
            // (auto-syncs are not recorded to avoid consuming rate limits)
            if (!status.isAutoSync) {
              try {
                final syncLimitService = SyncLimitService();
                await syncLimitService.recordSync('psn', success: true);
                debugPrint('✅ Recorded PSN manual sync in database');
              } catch (e) {
                debugPrint('Failed to record PSN sync in database: $e');
              }
            } else {
              debugPrint('⏩ Skipping rate limit record for auto-sync');
            }

            // Update last sync time for auto-sync tracking
            try {
              final supabase = ref.read(supabaseClientProvider);
              final psnService = ref.read(psnServiceProvider);
              final xboxService = ref.read(xboxServiceProvider);
              final autoSyncService = AutoSyncService(
                supabase,
                psnService,
                xboxService,
              );
              await autoSyncService.updatePSNSyncTime();
            } catch (e) {
              debugPrint('Failed to update PSN sync time: $e');
            }

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
                    ? SyncIssueClassifier.noFreshWriteWarning('PlayStation')
                    : null;
              });

              await SyncReconcileService(
                ref.read(supabaseClientProvider),
              ).reconcileCurrentUser(trigger: 'psn_sync_success_immediate');

              // Force refresh sync status to get updated last_sync_at timestamp
              ref.invalidate(psnSyncStatusProvider);

              // Refresh games list and stats to show updated data
              ref.refreshCoreData();
              // Leaderboards are cached by Riverpod; invalidate them after sync so
              // users don't see stale platinum counts/XP/GS when they navigate.
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
                statusxpLog('Failed checking post-sync achievements (PSN): $e');
              }
            }
            return;
          }

          if (status.status == 'error') {
            final issue = SyncIssueClassifier.analyze(
              platformName: 'PlayStation',
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

      if (!_isSyncing) break;
    }
  }

  Future<void> _stopSync() async {
    // Immediate feedback to confirm function is called
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Stop sync clicked...')));
    }

    try {
      final psnService = ref.read(psnServiceProvider);
      await psnService.stopSync();
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });

        ref.invalidate(psnSyncStatusProvider);

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Sync stopped')));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to stop sync: ${e.toString()}';
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
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
      ).reconcileCurrentUser(trigger: 'psn_sync_t+3s');
      if (!mounted) return;
      ref.refreshCoreData();
      ref.invalidate(lb.leaderboardProvider);
      ref.invalidate(leaderboardRanksProvider);
    });

    Future.delayed(const Duration(seconds: 12), () async {
      if (!mounted) return;
      await SyncReconcileService(
        ref.read(supabaseClientProvider),
      ).reconcileCurrentUser(trigger: 'psn_sync_t+12s');
      if (!mounted) return;
      ref.refreshCoreData();
      ref.invalidate(lb.leaderboardProvider);
      ref.invalidate(lb.seasonalLeaderboardProvider);
      ref.invalidate(leaderboardRanksProvider);
      ref.invalidate(lb.latestPeriodWinnersProvider);
    });
  }

  void _showRelinkDialogIfNeeded() {
    if (!mounted || _relinkDialogShown) return;
    _relinkDialogShown = true;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('PlayStation Relink Required'),
        content: const Text(
          'This sync could not run because your PlayStation session expired. Disconnect and reconnect PlayStation in Settings, then sync again.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (mounted) {
                context.go('/settings');
              }
            },
            child: const Text('Open Settings'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Later'),
          ),
        ],
      ),
    ).whenComplete(() {
      _relinkDialogShown = false;
    });
  }

  Future<void> _reconnectNow() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reconnect PlayStation?'),
        content: const Text(
          'This will disconnect your current PlayStation link and start relinking now.',
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
            'psn_account_id': null,
            'psn_online_id': null,
            'psn_npsso_token': null,
            'psn_access_token': null,
            'psn_refresh_token': null,
            'psn_token_expires_at': null,
            'psn_sync_status': 'never_synced',
            'psn_sync_error': null,
          })
          .eq('id', userId);

      if (!mounted) return;
      final relinked = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (context) => const PSNConnectScreen()),
      );
      if (relinked == true && mounted) {
        ref.invalidate(psnSyncStatusProvider);
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
    final syncStatusAsync = ref.watch(psnSyncStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PlayStation Network Sync'),
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
          final syncIssue = SyncIssueClassifier.analyze(
            platformName: 'PlayStation',
            syncStatus: status.status,
            errorMessage: _errorMessage ?? status.error,
            requiresRelinkSignal: status.requiresRelink,
          );
          final effectiveError =
              syncIssue.effectiveErrorMessage ??
              (status.requiresRelink ? _relinkPromptMessage : null);
          final effectiveStatus = syncIssue.effectiveStatus;
          final effectiveWarning =
              _diagnosticWarningMessage ?? syncIssue.warningMessage;

          // Build rate limit message
          String? rateLimitMessage;
          if (_rateLimitStatus != null && !_rateLimitStatus!.canSync) {
            if (_rateLimitStatus!.waitSeconds > 0) {
              rateLimitMessage =
                  'PSN sync on cooldown. Next sync available in ${_rateLimitStatus!.waitTimeFormatted}';
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
                  platformName: 'PlayStation',
                  platformColor: const Color(0xFF003791),
                  platformIcon: const Icon(
                    Icons.sports_esports,
                    size: 64,
                    color: Colors.white,
                  ),
                  syncStatus: effectiveStatus,
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

  void _logSyncIssue({
    required String category,
    required String status,
    required bool requiresRelink,
  }) {
    unawaited(
      AnalyticsService().logSyncIssue(
        platform: 'psn',
        category: category,
        status: status,
        requiresRelink: requiresRelink,
      ),
    );
  }
}
