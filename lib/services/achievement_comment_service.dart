import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:statusxp/domain/achievement_comment.dart';
import 'package:statusxp/services/content_moderation_service.dart';

class AchievementCommentService {
  AchievementCommentService(this._supabase);

  final SupabaseClient _supabase;
  final _moderationService = ContentModerationService();

  /// Get all comments for a specific achievement
  /// Returns comments sorted by newest first
  Future<List<AchievementComment>> getComments(int achievementId) async {
    final response = await _supabase
        .from('achievement_comments')
        .select('''
          id,
          achievement_id,
          user_id,
          comment_text,
          created_at,
          updated_at,
          is_hidden,
          is_flagged,
          flag_count,
          profiles!inner(
            psn_online_id, 
            psn_avatar_url, 
            steam_display_name, 
            steam_avatar_url, 
            xbox_gamertag, 
            xbox_avatar_url, 
            preferred_display_platform
          )
        ''')
        .eq('achievement_id', achievementId)
        .eq('is_hidden', false)
        .order('created_at', ascending: false);

    final List<dynamic> rows = response as List<dynamic>;

    return rows.map((row) {
      // Flatten the nested profile data
      final profiles = row['profiles'];
      final profile = profiles is List && profiles.isNotEmpty 
          ? profiles[0] as Map<String, dynamic>
          : profiles as Map<String, dynamic>?;
      
      final flattenedRow = Map<String, dynamic>.from(row);
      flattenedRow.remove('profiles');
      
      if (profile != null) {
        // Determine display name and avatar based on preferred platform
        final preferredPlatform = profile['preferred_display_platform'] as String? ?? 'psn';
        
        // Set display name based on preferred platform
        String? displayName;
        String? avatarUrl;
        
        if (preferredPlatform == 'psn' && profile['psn_online_id'] != null) {
          displayName = profile['psn_online_id'] as String;
          avatarUrl = profile['psn_avatar_url'] as String?;
        } else if (preferredPlatform == 'steam' && profile['steam_display_name'] != null) {
          displayName = profile['steam_display_name'] as String;
          avatarUrl = profile['steam_avatar_url'] as String?;
        } else if (preferredPlatform == 'xbox' && profile['xbox_gamertag'] != null) {
          displayName = profile['xbox_gamertag'] as String;
          avatarUrl = profile['xbox_avatar_url'] as String?;
        } else {
          // Fallback logic
          if (profile['psn_online_id'] != null) {
            displayName = profile['psn_online_id'] as String;
            avatarUrl = profile['psn_avatar_url'] as String?;
          } else if (profile['steam_display_name'] != null) {
            displayName = profile['steam_display_name'] as String;
            avatarUrl = profile['steam_avatar_url'] as String?;
          } else if (profile['xbox_gamertag'] != null) {
            displayName = profile['xbox_gamertag'] as String;
            avatarUrl = profile['xbox_avatar_url'] as String?;
          }
        }
        
        flattenedRow['username'] = displayName;
        flattenedRow['display_name'] = displayName;
        flattenedRow['avatar_url'] = avatarUrl;
      }
      
      return AchievementComment.fromJson(flattenedRow);
    }).toList();
  }

  /// Get the count of comments for an achievement
  Future<int> getCommentCount(int achievementId) async {
    final response = await _supabase
        .from('achievement_comments')
        .select('id')
        .eq('achievement_id', achievementId)
        .eq('is_hidden', false)
        .count(CountOption.exact);

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

  /// Post a new comment
  /// Returns the created comment with profile data
  Future<AchievementComment> postComment({
    required int achievementId,
    required String commentText,
  }) async {
    // Get current user
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User must be authenticated to post comments');
    }

    // Moderate content before posting
    final moderationResult = await _moderationService.moderateContent(commentText);
    if (!moderationResult.isSafe) {
      throw Exception(moderationResult.reason ?? 'Comment contains inappropriate content');
    }

    // Insert the comment
    final response = await _supabase
        .from('achievement_comments')
        .insert({
          'achievement_id': achievementId,
          'user_id': userId,
          'comment_text': commentText,
        })
        .select('''
          id,
          achievement_id,
          user_id,
          comment_text,
          created_at,
          updated_at,
          is_hidden,
          is_flagged,
          flag_count,
          profiles!inner(
            psn_online_id, 
            psn_avatar_url, 
            steam_display_name, 
            steam_avatar_url, 
            xbox_gamertag, 
            xbox_avatar_url, 
            preferred_display_platform
          )
        ''')
        .single();

    // Flatten the nested profile data
    final profiles = response['profiles'];
    final profile = profiles is List && profiles.isNotEmpty 
        ? profiles[0] as Map<String, dynamic>
        : profiles as Map<String, dynamic>?;
    
    final flattenedRow = Map<String, dynamic>.from(response);
    flattenedRow.remove('profiles');
    
    if (profile != null) {
      // Determine display name and avatar based on preferred platform
      final preferredPlatform = profile['preferred_display_platform'] as String? ?? 'psn';
      
      String? displayName;
      String? avatarUrl;
      
      if (preferredPlatform == 'psn' && profile['psn_online_id'] != null) {
        displayName = profile['psn_online_id'] as String;
        avatarUrl = profile['psn_avatar_url'] as String?;
      } else if (preferredPlatform == 'steam' && profile['steam_display_name'] != null) {
        displayName = profile['steam_display_name'] as String;
        avatarUrl = profile['steam_avatar_url'] as String?;
      } else if (preferredPlatform == 'xbox' && profile['xbox_gamertag'] != null) {
        displayName = profile['xbox_gamertag'] as String;
        avatarUrl = profile['xbox_avatar_url'] as String?;
      }
      
      flattenedRow['username'] = displayName;
      flattenedRow['display_name'] = displayName;
      flattenedRow['avatar_url'] = avatarUrl;
    }
    
    return AchievementComment.fromJson(flattenedRow);
  }

  /// Delete a comment
  /// Only the comment author can delete their own comment
  Future<void> deleteComment(String commentId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User must be authenticated to delete comments');
    }

    await _supabase
        .from('achievement_comments')
        .delete()
        .eq('id', commentId)
        .eq('user_id', userId); // RLS will enforce this too, but explicit check for better error
  }
}
