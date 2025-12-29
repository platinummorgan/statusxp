import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:statusxp/domain/meta_achievement.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final metaAchievementRepositoryProvider = Provider<MetaAchievementRepository>((ref) {
  return MetaAchievementRepository(Supabase.instance.client);
});

class MetaAchievementRepository {
  final SupabaseClient _client;

  MetaAchievementRepository(this._client);

  /// Get all meta-achievements with unlock status for a user
  /// Optionally filter by connected platforms
  Future<List<MetaAchievement>> getAllAchievements(
    String userId, {
    Set<String>? connectedPlatforms,
  }) async {
    try {
      // Get all meta-achievements
      final achievementsResponse = await _client
          .from('meta_achievements')
          .select()
          .order('sort_order', ascending: true);

      // Get user's unlocked achievements
      final unlockedResponse = await _client
          .from('user_meta_achievements')
          .select('achievement_id, unlocked_at, custom_title')
          .eq('user_id', userId);

      // Create a map of unlocked achievements
      final unlockedMap = <String, Map<String, dynamic>>{};
      for (final item in unlockedResponse as List) {
        unlockedMap[item['achievement_id'] as String] = item;
      }

      // Combine data
      final achievements = <MetaAchievement>[];
      for (final achievement in achievementsResponse as List) {
        final id = achievement['id'] as String;
        final unlocked = unlockedMap[id];

        // Check platform requirements if filtering is enabled
        if (connectedPlatforms != null) {
          final requiredPlatforms = achievement['required_platforms'] as List?;
          
          // If achievement has platform requirements, check if user meets them
          if (requiredPlatforms != null && requiredPlatforms.isNotEmpty) {
            // User must have ALL required platforms
            final hasAllRequired = requiredPlatforms.every(
              (platform) => connectedPlatforms.contains(platform as String),
            );
            
            // Skip this achievement if user doesn't have required platforms
            if (!hasAllRequired) continue;
          }
        }

        achievements.add(MetaAchievement(
          id: id,
          category: achievement['category'] as String,
          defaultTitle: achievement['default_title'] as String,
          description: achievement['description'] as String,
          iconEmoji: achievement['icon_emoji'] as String?,
          sortOrder: achievement['sort_order'] as int? ?? 0,
          unlockedAt: unlocked?['unlocked_at'] != null
              ? DateTime.parse(unlocked!['unlocked_at'] as String)
              : null,
          customTitle: unlocked?['custom_title'] as String?,
          requiredPlatforms: achievement['required_platforms'] != null
              ? List<String>.from(achievement['required_platforms'] as List)
              : null,
        ));
      }

      return achievements;
    } catch (e) {
      print('Error loading meta-achievements: $e');
      return [];
    }
  }

  /// Get only unlocked achievements for a user
  Future<List<MetaAchievement>> getUnlockedAchievements(String userId) async {
    final all = await getAllAchievements(userId);
    return all.where((a) => a.isUnlocked).toList();
  }

  /// Select a title to display
  Future<bool> selectTitle(String userId, String achievementId) async {
    try {
      await _client.from('user_selected_title').upsert({
        'user_id': userId,
        'achievement_id': achievementId,
        'updated_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      print('Error selecting title: $e');
      return false;
    }
  }

  /// Manually unlock an achievement (for testing/admin)
  Future<bool> unlockAchievement(String userId, String achievementId) async {
    try {
      await _client.from('user_meta_achievements').insert({
        'user_id': userId,
        'achievement_id': achievementId,
        'unlocked_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      print('Error unlocking achievement: $e');
      return false;
    }
  }
}
