import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/activity_feed_entry.dart';

class ActivityFeedRepository {
  final SupabaseClient _client;

  ActivityFeedRepository(this._client);

  /// Get activity feed grouped by date
  Future<List<ActivityFeedGroup>> getActivityFeedGrouped({
    int limit = 50,
  }) async {
    try {
      final response = await _client.rpc(
        'get_activity_feed_grouped',
        params: {
          'p_user_id': _client.auth.currentUser!.id,
          'p_limit': limit,
        },
      );

      if (response == null) {
        return [];
      }

      final List<dynamic> data = response as List<dynamic>;
      return data
          .map((group) => ActivityFeedGroup.fromJson(group as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('❌ Failed to fetch activity feed: $e');
      rethrow;
    }
  }

  /// Get unread activity count
  Future<int> getUnreadCount() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        return 0;
      }

      final response = await _client.rpc(
        'get_unread_activity_count',
        params: {'p_user_id': userId},
      );

      return (response as num).toInt();
    } catch (e) {
      print('❌ Failed to fetch unread count: $e');
      return 0;
    }
  }

  /// Mark activity feed as viewed
  Future<void> markAsViewed() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        return;
      }

      await _client.rpc(
        'mark_activity_feed_viewed',
        params: {'p_user_id': userId},
      );
    } catch (e) {
      print('❌ Failed to mark feed as viewed: $e');
      rethrow;
    }
  }

  /// Stream activity feed updates (realtime)
  Stream<List<ActivityFeedGroup>> watchActivityFeed() {
    return _client
        .from('activity_feed')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .asyncMap((_) async {
          // When feed updates, re-fetch grouped data
          return await getActivityFeedGrouped();
        });
  }
}
