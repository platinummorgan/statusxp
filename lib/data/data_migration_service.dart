import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/sample_data.dart';

/// Service to handle first-run data migration from sample data to Supabase.
/// 
/// This runs once per user to seed their account with demo games and stats.
class DataMigrationService {
  static const _migrationKey = 'supabase_data_migrated';
  
  final SupabaseClient _client;
  
  DataMigrationService(this._client);
  
  /// Check if migration has already been performed.
  Future<bool> isMigrationComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_migrationKey) ?? false;
  }
  
  /// Mark migration as complete.
  Future<void> _markMigrationComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_migrationKey, true);
  }
  
  /// Perform first-run data migration.
  /// 
  /// Seeds the database with:
  /// 1. Sample platforms (if not exists)
  /// 2. Sample game titles (if not exists)
  /// 3. User profile
  /// 4. User games
  /// 5. User stats
  Future<void> migrateInitialData(String userId) async {
    // Check if already migrated
    if (await isMigrationComplete()) {
      return;
    }
    
    try {
      // 1. Ensure user profile exists
      await _ensureUserProfile(userId);
      
      // 2. Seed platforms if needed
      await _seedPlatforms();
      
      // 3. Seed game titles and create user_games
      await _seedGamesForUser(userId);
      
      // 4. Seed user stats
      await _seedUserStats(userId);
      
      // Mark migration complete
      await _markMigrationComplete();
    } catch (e) {
      // Log error but don't rethrow - app should still work
      // In production, send to error tracking service
      print('Migration error: $e');
    }
  }
  
  /// Ensure user profile exists.
  Future<void> _ensureUserProfile(String userId) async {
    final existing = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    
    if (existing == null) {
      await _client.from('profiles').insert({
        'id': userId,
        'username': sampleStats.username,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
  }
  
  /// Seed platform catalog.
  Future<void> _seedPlatforms() async {
    final platforms = [
      {'code': 'PS5', 'name': 'PlayStation 5'},
      {'code': 'PS4', 'name': 'PlayStation 4'},
      {'code': 'Xbox', 'name': 'Xbox Series X|S'},
      {'code': 'Steam', 'name': 'Steam'},
    ];
    
    for (final platform in platforms) {
      // Check if exists
      final existing = await _client
          .from('platforms')
          .select()
          .eq('code', platform['code']!)
          .maybeSingle();
      
      if (existing == null) {
        await _client.from('platforms').insert(platform);
      }
    }
  }
  
  /// Seed game titles and user games.
  Future<void> _seedGamesForUser(String userId) async {
    // Get platform IDs
    final platforms = await _client.from('platforms').select();
    final platformMap = <String, int>{};
    for (final p in platforms) {
      platformMap[p['code'] as String] = p['id'] as int;
    }
    
    for (final game in sampleGames) {
      // Create or get game_title
      final existingTitle = await _client
          .from('game_titles')
          .select()
          .eq('name', game.name)
          .maybeSingle();
      
      int gameTitleId;
      if (existingTitle == null) {
        final platformId = platformMap[game.platform] ?? 1;
        final newTitle = await _client.from('game_titles').insert({
          'name': game.name,
          'platform_id': platformId,
          'cover_image': game.cover,
        }).select().single();
        gameTitleId = newTitle['id'] as int;
      } else {
        gameTitleId = existingTitle['id'] as int;
      }
      
      // Create user_game
      final platformId = platformMap[game.platform] ?? 1;
      await _client.from('user_games').insert({
        'user_id': userId,
        'game_title_id': gameTitleId,
        'platform_id': platformId,
        'total_trophies': game.totalTrophies,
        'earned_trophies': game.earnedTrophies,
        'has_platinum': game.hasPlatinum,
        'rarest_trophy_rarity': game.rarityPercent,
      });
    }
  }
  
  /// Seed user stats.
  Future<void> _seedUserStats(String userId) async {
    await _client.from('user_stats').upsert({
      'user_id': userId,
      'total_platinums': sampleStats.totalPlatinums,
      'total_games': sampleStats.totalGamesTracked,
      'total_trophies': sampleStats.totalTrophies,
      'hardest_platinum_game': sampleStats.hardestPlatGame,
      'rarest_trophy_name': sampleStats.rarestTrophyName,
      'rarest_trophy_rarity': sampleStats.rarestTrophyRarity,
    });
  }
}
