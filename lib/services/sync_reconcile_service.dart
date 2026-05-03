import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:statusxp/utils/statusxp_logger.dart';

/// Runs lightweight server-side reconciliation after sync completion.
///
/// This is a safety net when client refresh races with DB writes.
class SyncReconcileService {
  final SupabaseClient _supabase;

  SyncReconcileService(this._supabase);

  Future<void> reconcileCurrentUser({required String trigger}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _supabase.rpc(
        'refresh_statusxp_leaderboard_for_user',
        params: {'p_user_id': userId},
      );
      statusxpLog('Post-sync reconcile complete ($trigger) for $userId');
    } catch (e) {
      statusxpLog('Post-sync reconcile failed ($trigger): $e');
    }
  }
}
