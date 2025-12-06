import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/data/xbox_service.dart';
import 'package:statusxp/ui/widgets/platform_sync_widget.dart';

/// Screen for syncing Xbox achievements
class XboxSyncScreen extends ConsumerStatefulWidget {
  const XboxSyncScreen({super.key});

  @override
  ConsumerState<XboxSyncScreen> createState() => _XboxSyncScreenState();
}

class _XboxSyncScreenState extends ConsumerState<XboxSyncScreen> {
  bool _isSyncing = false;
  String? _errorMessage;

  Future<void> _startSync() async {
    setState(() {
      _isSyncing = true;
      _errorMessage = null;
    });

    try {
      final xboxService = ref.read(xboxServiceProvider);
      await xboxService.startSync();

      if (mounted) {
        // Start polling for status updates
        _pollSyncStatus();
      }
    } on XboxRateLimitException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _isSyncing = false;
        });
      }
    } catch (e) {
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
      
      // Refresh status
      ref.invalidate(xboxSyncStatusProvider);
      final statusAsync = ref.read(xboxSyncStatusProvider);
      
      await statusAsync.when(
        data: (status) async {
          // If status is pending, automatically continue sync
          if (status.status == 'pending') {
            try {
              final xboxService = ref.read(xboxServiceProvider);
              await xboxService.startSync();
            } catch (e) {
              print('Error continuing sync: $e');
            }
            return;
          }

          // Check if sync completed or failed
          if (status.status == 'success') {
            if (mounted) {
              setState(() {
                _isSyncing = false;
              });
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

          return PlatformSyncWidget(
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
              'Syncs all your Xbox games with achievements',
              'Processes 5 games at a time to avoid timeouts',
              'Automatically resumes until all games are synced',
              'Fetches global achievement rarity data',
              'You can stop the sync at any time and resume later',
            ],
          );
        },
      ),
    );
  }
}
