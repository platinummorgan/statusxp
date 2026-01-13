import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:statusxp/domain/achievement_comment.dart';

class AchievementCommentService {
  AchievementCommentService(this._supabase);

  final SupabaseClient _supabase;

  /// Get all comments for a specific achievement
  /// Returns comments sorted by newest first
  Future<List<AchievementComment>> getComments(int achievementId) async {
    final response = await _supabase
        .from('achievement_comments')
        .select('''
          *,
          profiles:user_id (
            username,
            display_name,
            avatar_url
          )
        ''')
        .eq('achievement_id', achievementId)
        .eq('is_hidden', false)
        .order('created_at', ascending: false);

    final List<dynamic> rows = response as List<dynamic>;

    return rows.map((row) {
      // Flatten the nested profile data
      final profile = row['profiles'] as Map<String, dynamic>?;
      final flattenedRow = Map<String, dynamic>.from(row);
      
      if (profile != null) {
        flattenedRow['username'] = profile['username'];
        flattenedRow['display_name'] = profile['display_name'];
        flattenedRow['avatar_url'] = profile['avatar_url'];
      }
      
      return AchievementComment.fromJson(flattenedRow);
    }).toList();
  }

  /// Get the count of comments for an achievement
  Future<int> getCommentCount(int achievementId) async {
    final response = await _supabase
        .from('achievement_comments')
        .select('id', const FetchOptions(count: CountOption.exact))
        .eq('achievement_id', achievementId)
        .eq('is_hidden', false);

    return response.count ?? 0;
  }

  /// Get comments by multiple achievement IDs
  /// Useful for batch loading comment counts
  Future<Map<int, int>> getCommentCounts(List<int> achievementIds) async {
    if (achievementIds.isEmpty) return {};

    final response = await _supabase
        .from('achievement_comments')
        .select('achievement_id')
        .inFilter('achievement_id', achievementIds)
        .eq('is_hidden', false);

    final List<dynamic> rows = response as List<dynamic>;
    
    // Count comments per achievement
    final Map<int, int> counts = {};
    for (final row in rows) {
      final achievementId = row['achievement_id'] as int;
      counts[achievementId] = (counts[achievementId] ?? 0) + 1;
    }
    
    return counts;
  }
}
