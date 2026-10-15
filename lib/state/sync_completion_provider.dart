import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/utils/supabase_guard.dart';

/// App-wide, credential-free sync status. Kept alive by the root app listener.
final syncCompletionProvider =
    StreamProvider.autoDispose<SyncCompletionSnapshot?>((ref) {
      final userId = ref.watch(currentUserIdProvider);
      ref.watch(
        authStateProvider,
      ); // Reconnect after token refresh or account changes.
      final client = tryGetSupabaseClient();
      if (userId == null || client == null) {
        return Stream.value(null);
      }
      return client
          .from('profile_sync_notifications')
          .stream(primaryKey: ['user_id'])
          .eq('user_id', userId)
          .map(
            (rows) => rows.isEmpty ? null : SyncCompletionSnapshot(rows.first),
          );
    });

class SyncCompletionSnapshot {
  SyncCompletionSnapshot(Map<String, dynamic> row)
    : userId = row['user_id'] as String,
      statuses = [
        for (final p in platforms) row['${p}_sync_status'] as String?,
      ],
      completedAt = [
        for (final p in platforms)
          DateTime.tryParse(row['last_${p}_sync_at']?.toString() ?? ''),
      ];

  static const platforms = ['psn', 'xbox', 'steam'];
  final String userId;
  final List<String?> statuses;
  final List<DateTime?> completedAt;

  bool shouldRefreshAfter(SyncCompletionSnapshot? previous) {
    // Initial/reconnected data also repairs stats cached while the app was away.
    if (previous == null || previous.userId != userId) {
      return true;
    }
    for (var i = 0; i < platforms.length; i++) {
      final completed = completedAt[i];
      final oldCompleted = previous.completedAt[i];
      if (completed != null &&
          (oldCompleted == null || completed.isAfter(oldCompleted))) {
        return true;
      }
      if (const [
            'syncing',
            'pending',
            'cancelling',
          ].contains(previous.statuses[i]) &&
          const [
            'success',
            'completed',
            'error',
            'stopped',
          ].contains(statuses[i])) {
        return true;
      }
    }
    return false;
  }
}
