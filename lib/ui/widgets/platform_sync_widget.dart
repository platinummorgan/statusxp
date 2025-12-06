import 'package:flutter/material.dart';

/// Unified Platform Sync Screen
/// Used by PSN, Xbox, and Steam for consistent UI/UX
class PlatformSyncWidget extends StatelessWidget {
  final String platformName;
  final Color platformColor;
  final Widget platformIcon;
  final String? syncStatus;
  final int syncProgress;
  final DateTime? lastSyncAt;
  final String? errorMessage;
  final bool isSyncing;
  final VoidCallback onSyncPressed;
  final VoidCallback? onStopPressed;
  final List<String> syncDescription;

  const PlatformSyncWidget({
    super.key,
    required this.platformName,
    required this.platformColor,
    required this.platformIcon,
    required this.syncStatus,
    required this.syncProgress,
    required this.lastSyncAt,
    required this.errorMessage,
    required this.isSyncing,
    required this.onSyncPressed,
    this.onStopPressed,
    required this.syncDescription,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Platform Icon
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: platformColor,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Center(child: platformIcon),
          ),
          
          const SizedBox(height: 24),

          // Title
          Text(
            'Sync $platformName Achievements',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 8),

          Text(
            'Import your $platformName achievements and gaming stats.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 24),

          // Status Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildStatusIcon(),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sync Status',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _getStatusText(),
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: _getStatusColor(),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  if (isSyncing && syncProgress > 0) ...[
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                      value: syncProgress / 100,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(platformColor),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$syncProgress% complete',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],

                  if (lastSyncAt != null && !isSyncing) ...[
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Last synced:',
                          style: theme.textTheme.bodyMedium,
                        ),
                        Text(
                          _formatLastSync(lastSyncAt!),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],

                  if (errorMessage != null) ...[
                    const Divider(height: 24),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error, color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              errorMessage!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Sync Button
          if (!isSyncing) ...[
            ElevatedButton.icon(
              onPressed: onSyncPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: platformColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              icon: const Icon(Icons.sync),
              label: const Text('Sync Now', style: TextStyle(fontSize: 16)),
            ),
          ] else ...[
            if (onStopPressed != null)
              ElevatedButton.icon(
                onPressed: onStopPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: const Icon(Icons.stop),
                label: const Text('Stop Sync', style: TextStyle(fontSize: 16)),
              ),
          ],

          const SizedBox(height: 24),

          // How it works info card
          Card(
            color: platformColor.withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: platformColor),
                      const SizedBox(width: 8),
                      Text(
                        'How $platformName Sync Works',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: platformColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...syncDescription.map((desc) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• ', style: TextStyle(color: platformColor)),
                        Expanded(child: Text(desc)),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon() {
    if (isSyncing) {
      return SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 3,
          valueColor: AlwaysStoppedAnimation<Color>(platformColor),
        ),
      );
    }

    if (syncStatus == 'success') {
      return const Icon(Icons.check_circle, color: Colors.green, size: 24);
    }

    if (syncStatus == 'error' || errorMessage != null) {
      return const Icon(Icons.error, color: Colors.red, size: 24);
    }

    return Icon(Icons.sync_disabled, color: Colors.grey[400], size: 24);
  }

  String _getStatusText() {
    if (isSyncing) return 'Syncing...';
    if (syncStatus == 'success') return 'Synced successfully';
    if (syncStatus == 'error') return 'Sync failed';
    if (syncStatus == 'stopped') return 'Sync stopped';
    return 'Not synced yet';
  }

  Color _getStatusColor() {
    if (isSyncing) return platformColor;
    if (syncStatus == 'success') return Colors.green;
    if (syncStatus == 'error') return Colors.red;
    return Colors.grey;
  }

  String _formatLastSync(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return '1 day ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }
}
