import 'dart:async';
import 'package:statusxp/ui/screens/auth/security_reconnect_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:statusxp/data/repositories/leaderboard_repository.dart' as lb;
import 'package:statusxp/services/auto_sync_service.dart';
import 'package:statusxp/services/sync_reconcile_service.dart';
import 'package:statusxp/services/analytics_service.dart';
import 'package:statusxp/services/premium_trigger_service.dart';
import 'package:statusxp/services/referral_service.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/ui/screens/steam/steam_configure_screen.dart';
import 'package:statusxp/ui/widgets/platform_sync_widget.dart';
import 'package:statusxp/services/sync_limit_service.dart';
import 'package:statusxp/utils/statusxp_logger.dart';
import 'package:statusxp/utils/sync_issue_classifier.dart';

/// Steam Sync Screen - Manage Steam achievement syncing
class SteamSyncScreen extends StatelessWidget {
  const SteamSyncScreen({super.key});
  @override
  Widget build(BuildContext context) => const SecurityReconnectGate(
    platform: 'steam',
    child: _SteamSyncContent(),
  );
}

class _SteamSyncContent extends ConsumerStatefulWidget {
  const _SteamSyncContent();

  @override
  ConsumerState<_SteamSyncContent> createState() => _SteamSyncScreenState();
}

class _SteamSyncScreenState extends ConsumerState<_SteamSyncContent> {
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
  DateTime? _syncStartedAt;
  DateTime? _lastSyncAtBeforeSync;
  bool _suspectNoFreshWrite = false;
  String? _diagnosticWarningMessage;

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
            .select(
              'steam_id, steam_sync_status, steam_sync_progress, steam_sync_error, last_steam_sync_at',
            )
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
          _error = data['steam_sync_error'] as String?;
          _lastSyncAt = lastSyncAt;
          _isSyncing =
              normalizedStatus == 'syncing' || normalizedStatus == 'pending';
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
      if (!mounted) return;
      _logSyncIssue(
        category: 'rate_limited',
        status: 'error',
        requiresRelink: false,
      );
      setState(() {
        _error = limitStatus.reason;
      });
      await PremiumTriggerService().showIfEligible(
        context,
        offer: premiumOfferFor(PremiumTrigger.syncCooldown, platform: 'Steam'),
      );
      return;
    }

    setState(() {
      _isSyncing = true;
      _error = null;
      _suspectNoFreshWrite = false;
      _diagnosticWarningMessage = null;
      _syncStartedAt = DateTime.now();
      _lastSyncAtBeforeSync = _lastSyncAt;
    });

    try {
      final supabase = Supabase.instance.client;
      await supabase.functions.invoke('steam-start-sync');

      if (mounted) {
        // Poll for status updates
        _pollSyncStatus();
      }
    } catch (e) {
      _logSyncIssue(
        category: 'start_failed',
        status: 'error',
        requiresRelink: false,
      );
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
              .select(
                'steam_sync_status, steam_sync_progress, steam_sync_error, last_steam_sync_at',
              )
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
          final newError = data['steam_sync_error'] as String?;

          // Only update UI if state changed.
          if (newStatus != _syncStatus ||
              newProgress != _syncProgress ||
              newError != _error) {
            setState(() {
              _syncStatus = newStatus;
              _syncProgress = newProgress;
              _error = newError;
              _lastSyncAt = lastSyncAt;
            });
          }

          // If status is pending, automatically continue sync
          if (newStatus == 'pending') {
            try {
              await Supabase.instance.client.functions.invoke(
                'steam-start-sync',
              );
            } catch (e) {
              statusxpLog('Failed to continue pending Steam sync: $e');
            }
            continue;
          }

          if (newStatus == 'success' || newStatus == 'error') {
            setState(() => _isSyncing = false);
            var completedAutoSync = false;

            // Record MANUAL sync completion in database for rate limiting
            // (auto-syncs are not recorded to avoid consuming rate limits)
            if (newStatus == 'success') {
              final suspectNoFreshWrite = SyncIssueClassifier.hasNoFreshWrite(
                syncStartedAt: _syncStartedAt,
                previousLastSyncAt: _lastSyncAtBeforeSync,
                currentLastSyncAt: lastSyncAt,
              );
              if (suspectNoFreshWrite) {
                _logSyncIssue(
                  category: 'success_no_fresh_write',
                  status: newStatus,
                  requiresRelink: false,
                );
              }
              setState(() {
                _suspectNoFreshWrite = suspectNoFreshWrite;
                _diagnosticWarningMessage = suspectNoFreshWrite
                    ? SyncIssueClassifier.noFreshWriteWarning('Steam')
                    : null;
              });

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
                  final metadata =
                      profileData['steam_sync_metadata']
                          as Map<String, dynamic>?;
                  isAutoSync = metadata?['isAutoSync'] as bool? ?? false;
                  completedAutoSync = isAutoSync;
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

            if (newStatus == 'error') {
              final issue = SyncIssueClassifier.analyze(
                platformName: 'Steam',
                syncStatus: newStatus,
                errorMessage: newError,
              );
              _logSyncIssue(
                category: issue.category,
                status: newStatus,
                requiresRelink: issue.requiresRelink,
              );
            }

            await _loadProfile(); // Full reload on completion to get fresh timestamp

            // Refresh games list and stats to show updated data
            if (newStatus == 'success') {
              await SyncReconcileService(
                ref.read(supabaseClientProvider),
              ).reconcileCurrentUser(trigger: 'steam_sync_success_immediate');
              ref.refreshCoreData();
              // Invalidate leaderboards so new achievements are visible immediately.
              ref.invalidate(lb.leaderboardProvider);
              ref.invalidate(lb.seasonalLeaderboardProvider);
              ref.invalidate(leaderboardRanksProvider);
              ref.invalidate(lb.latestPeriodWinnersProvider);
              _schedulePostSyncReconciles();
              try {
                await ReferralService(
                  ref.read(supabaseClientProvider),
                ).finalizeAfterFirstSync();
              } catch (_) {
                // Referral rewards retry on a later successful sync.
              }

              if (_lastSyncAtBeforeSync == null &&
                  !completedAutoSync &&
                  !_suspectNoFreshWrite &&
                  mounted) {
                context.go('/sync-results?platform=steam');
              }
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

  void _schedulePostSyncReconciles() {
    Future.delayed(const Duration(seconds: 3), () async {
      if (!mounted) return;
      await SyncReconcileService(
        ref.read(supabaseClientProvider),
      ).reconcileCurrentUser(trigger: 'steam_sync_t+3s');
      if (!mounted) return;
      ref.refreshCoreData();
      ref.invalidate(lb.leaderboardProvider);
      ref.invalidate(leaderboardRanksProvider);
    });

    Future.delayed(const Duration(seconds: 12), () async {
      if (!mounted) return;
      await SyncReconcileService(
        ref.read(supabaseClientProvider),
      ).reconcileCurrentUser(trigger: 'steam_sync_t+12s');
      if (!mounted) return;
      ref.refreshCoreData();
      ref.invalidate(lb.leaderboardProvider);
      ref.invalidate(lb.seasonalLeaderboardProvider);
      ref.invalidate(leaderboardRanksProvider);
      ref.invalidate(lb.latestPeriodWinnersProvider);
    });
  }

  Future<void> _openSteamRepairFlow() async {
    if (!mounted) return;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const SteamConfigureScreen()),
    );
    if (result == true && mounted) {
      await _loadProfile();
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
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
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
        rateLimitMessage =
            'Steam sync on cooldown. Next sync available in ${_rateLimitStatus!.waitTimeFormatted}';
      } else {
        rateLimitMessage = _rateLimitStatus!.reason;
      }
    }
    final syncIssue = SyncIssueClassifier.analyze(
      platformName: 'Steam',
      syncStatus: _syncStatus,
      errorMessage: _error,
    );
    final effectiveWarning =
        _diagnosticWarningMessage ?? syncIssue.warningMessage;

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
              platformName: 'Steam',
              platformColor: const Color(0xFF1B2838),
              platformIcon: const Icon(
                Icons.videogame_asset,
                size: 64,
                color: Colors.white,
              ),
              syncStatus: syncIssue.effectiveStatus,
              syncProgress: _syncProgress,
              lastSyncAt: _lastSyncAt,
              errorMessage: syncIssue.effectiveErrorMessage,
              warningMessage: effectiveWarning,
              warningActionLabel: effectiveWarning == null
                  ? null
                  : 'Repair Setup',
              onWarningActionPressed: effectiveWarning == null
                  ? null
                  : _openSteamRepairFlow,
              diagnostics: {
                'Raw status': _syncStatus ?? 'never_synced',
                'Issue category': _suspectNoFreshWrite
                    ? 'success_no_fresh_write'
                    : syncIssue.category,
                'Relink required': syncIssue.requiresRelink ? 'Yes' : 'No',
                'Progress': '$_syncProgress%',
              },
              isSyncing: _isSyncing,
              onSyncPressed: _startSync,
              onStopPressed: _stopSync,
              syncDescription: const [
                'Configure Steam in Settings first using your Steam ID and API key.',
                'In Steam, go to Profile → Edit Profile → Privacy Settings. Set your profile and "Game details" to Public so StatusXP can read your games.',
                'Keep these settings public for future automatic syncs. If you make them private again, set them to Public before syncing.',
                'Tap "Sync Now". Your saved Steam setup is used automatically; no browser sign-in is needed.',
                'Your Steam games with achievements, earned achievements, unlock dates and rarity are updated where available.',
                'Sync runs in the background. You can return to the dashboard while it finishes.',
                'Tap "Stop Sync" to request a stop. Achievements already imported are kept.',
              ],
            ),
          ),
        ],
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
        platform: 'steam',
        category: category,
        status: status,
        requiresRelink: requiresRelink,
      ),
    );
  }
}
