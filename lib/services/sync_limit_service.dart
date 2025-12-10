import 'package:supabase_flutter/supabase_flutter.dart';

class SyncLimitStatus {
  final bool canSync;
  final String reason;
  final int waitSeconds;

  SyncLimitStatus({
    required this.canSync,
    required this.reason,
    this.waitSeconds = 0,
  });

  factory SyncLimitStatus.fromJson(Map<String, dynamic> json) {
    return SyncLimitStatus(
      canSync: json['can_sync'] ?? false,
      reason: json['reason'] ?? 'Unknown error',
      waitSeconds: json['wait_seconds'] ?? 0,
    );
  }

  String get waitTimeFormatted {
    if (waitSeconds <= 0) return '';
    
    final hours = waitSeconds ~/ 3600;
    final minutes = (waitSeconds % 3600) ~/ 60;
    final seconds = waitSeconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }
}

class SyncLimitService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Check if user can sync for the given platform
  /// Returns SyncLimitStatus with can_sync, reason, and wait_seconds
  Future<SyncLimitStatus> canUserSync(String platform) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        return SyncLimitStatus(
          canSync: false,
          reason: 'User not authenticated',
        );
      }

      // Call the database function
      final response = await _supabase.rpc(
        'can_user_sync',
        params: {
          'p_user_id': userId,
          'p_platform': platform.toLowerCase(),
        },
      );

      return SyncLimitStatus.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      print('Error checking sync limit: $e');
      return SyncLimitStatus(
        canSync: false,
        reason: 'Error checking sync status: $e',
      );
    }
  }

  /// Record a sync operation in the history
  Future<void> recordSync(String platform, {bool success = true}) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase.from('user_sync_history').insert({
        'user_id': userId,
        'platform': platform.toLowerCase(),
        'synced_at': DateTime.now().toIso8601String(),
        'success': success,
      });
    } catch (e) {
      print('Error recording sync: $e');
    }
  }

  /// Get user premium status
  Future<bool> isPremiumUser() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final response = await _supabase
          .from('user_premium_status')
          .select('is_premium')
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) return false;
      return response['is_premium'] ?? false;
    } catch (e) {
      print('Error checking premium status: $e');
      return false;
    }
  }

  /// Get sync statistics for display
  Future<Map<String, dynamic>> getSyncStats() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return {};

      final response = await _supabase
          .from('user_sync_status')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      return response ?? {};
    } catch (e) {
      print('Error getting sync stats: $e');
      return {};
    }
  }
}
