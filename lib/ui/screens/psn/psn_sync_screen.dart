import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/ui/widgets/platform_sync_widget.dart';

/// Screen for managing PSN sync
class PSNSyncScreen extends ConsumerStatefulWidget {
  const PSNSyncScreen({super.key});

  @override
  ConsumerState<PSNSyncScreen> createState() => _PSNSyncScreenState();
}

class _PSNSyncScreenState extends ConsumerState<PSNSyncScreen> {
  bool _isSyncing = false;
  String? _errorMessage;

  Future<void> _startSync() async {
    setState(() {
      _isSyncing = true;
      _errorMessage = null;
    });

    try {
      final psnService = ref.read(psnServiceProvider);
      await psnService.startSync(forceResync: false);

      if (mounted) {
        _pollSyncStatus();
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

      if (!_isSyncing) break;
    }
  }

  Future<void> _stopSync() async {
    try {
      final psnService = ref.read(psnServiceProvider);
      await psnService.stopSync();

      if (mounted) {
        setState(() {
          _isSyncing = false;
        });

        ref.invalidate(psnSyncStatusProvider);
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

          return PlatformSyncWidget(
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
              'Syncs all your PlayStation games with trophies',
              'Processes 5 games at a time to avoid timeouts',
              'Automatically resumes until all games are synced',
              'Fetches global trophy rarity data',
              'You can stop the sync at any time and resume later',
            ],
          );
        },
      ),
    );
  }
}
