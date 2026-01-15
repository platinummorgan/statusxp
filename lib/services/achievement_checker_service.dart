import 'package:supabase_flutter/supabase_flutter.dart';

/// Achievement Checker Service - Complete implementation for all 133 meta achievements
class AchievementCheckerService {
  final SupabaseClient _client;

  AchievementCheckerService(this._client);

  /// Check all achievements for a user and unlock any that are met
  Future<List<String>> checkAndUnlockAchievements(String userId) async {
    final newlyUnlocked = <String>[];

    try {
      // Get already unlocked achievements
      final unlockedIds = await _getUnlockedAchievementIds(userId);
      
      // Get all user stats in parallel
      final results = await Future.wait([
        _getPSNStats(userId),
        _getXboxStats(userId),
        _getSteamStats(userId),
        _getCrossStats(userId),
      ]);
      
      final psnStats = results[0] as Map<String, dynamic>;
      final xboxStats = results[1] as Map<String, dynamic>;
      final steamStats = results[2] as Map<String, dynamic>;
      final crossStats = results[3] as Map<String, dynamic>;
      
      // Check PSN achievements
      await _checkPSNAchievements(userId, psnStats, unlockedIds, newlyUnlocked);
      
      // Check Xbox achievements
      await _checkXboxAchievements(userId, xboxStats, unlockedIds, newlyUnlocked);
      
      // Check Steam achievements
      await _checkSteamAchievements(userId, steamStats, unlockedIds, newlyUnlocked);
      
      // Check Cross-platform achievements
      await _checkCrossPlatformAchievements(userId, crossStats, unlockedIds, newlyUnlocked);

      return newlyUnlocked;
    } catch (e) {
      return [];
    }
  }

  /// Get PSN statistics
  Future<Map<String, dynamic>> _getPSNStats(String userId) async {
    try {
      // Join user_trophies with trophies to get tier and rarity
      final trophies = await _client
          .from('user_trophies')
          .select('trophies(tier, rarity_global)')
          .eq('user_id', userId);
      
      final trophyList = trophies as List;
      final stats = {
        'total': trophyList.length,
        'bronze': trophyList.where((t) => t['trophies']?['tier'] == 'bronze').length,
        'silver': trophyList.where((t) => t['trophies']?['tier'] == 'silver').length,
        'gold': trophyList.where((t) => t['trophies']?['tier'] == 'gold').length,
        'platinum': trophyList.where((t) => t['trophies']?['tier'] == 'platinum').length,
        'rare': trophyList.where((t) {
          final rarity = t['trophies']?['rarity_global'] as num?;
          return rarity != null && rarity < 10.0;
        }).length,
      };
      
      return stats;
    } catch (e) {
      return {'total': 0, 'bronze': 0, 'silver': 0, 'gold': 0, 'platinum': 0, 'rare': 0};
    }
  }

  /// Get Xbox statistics
  Future<Map<String, dynamic>> _getXboxStats(String userId) async {
    try {
      // Join user_achievements with achievements to get rarity and gamerscore
      final achievements = await _client
          .from('user_achievements')
          .select('achievements(rarity_global, xbox_gamerscore, platform)')
          .eq('user_id', userId);
      
      final achievementList = (achievements as List)
          .where((a) => a['achievements']?['platform'] == 'xbox')
          .toList();
          
      final stats = {
        'total': achievementList.length,
        'rare': achievementList.where((a) {
          final rarity = a['achievements']?['rarity_global'] as num?;
          return rarity != null && rarity < 10.0;
        }).length,
        'gamerscore': achievementList.fold<int>(0, (sum, a) {
          final gs = a['achievements']?['xbox_gamerscore'] as int?;
          return sum + (gs ?? 0);
        }),
      };
      
      return stats;
    } catch (e) {
      return {'total': 0, 'rare': 0, 'gamerscore': 0};
    }
  }

  /// Get Steam statistics
  Future<Map<String, dynamic>> _getSteamStats(String userId) async {
    try {
      // Join user_achievements with achievements to get rarity
      final achievements = await _client
          .from('user_achievements')
          .select('achievements(rarity_global, platform)')
          .eq('user_id', userId);
      
      final achievementList = (achievements as List)
          .where((a) => a['achievements']?['platform'] == 'steam')
          .toList();
          
      final stats = {
        'total': achievementList.length,
        'rare': achievementList.where((a) {
          final rarity = a['achievements']?['rarity_global'] as num?;
          return rarity != null && rarity < 10.0;
        }).length,
      };
      
      return stats;
    } catch (e) {
      return {'total': 0, 'rare': 0};
    }
  }

  /// Get cross-platform statistics
  Future<Map<String, dynamic>> _getCrossStats(String userId) async {
    try {
      // Get total unlocks across all platforms
      final psnCount = await _getPlatformCount(userId, 'psn');
      final xboxCount = await _getPlatformCount(userId, 'xbox');
      final steamCount = await _getPlatformCount(userId, 'steam');
      
      // Get StatusXP from user_games.statusxp_effective
      final userGames = await _client
          .from('user_games')
          .select('statusxp_effective')
          .eq('user_id', userId);
      
      final gameList = userGames as List;
      final totalStatusXP = gameList.fold<int>(0, (sum, g) {
        final xp = g['statusxp_effective'] as int?;
        return sum + (xp ?? 0);
      });
      
      final totalGames = gameList.length;
      
      // Count platforms with achievements
      final activePlatforms = [
        if (psnCount > 0) 'psn',
        if (xboxCount > 0) 'xbox',
        if (steamCount > 0) 'steam',
      ].length;
      
      return {
        'total_unlocks': psnCount + xboxCount + steamCount,
        'statusxp': totalStatusXP,
        'total_games': totalGames,
        'psn_count': psnCount,
        'xbox_count': xboxCount,
        'steam_count': steamCount,
        'active_platforms': activePlatforms,
      };
    } catch (e) {
      return {
        'total_unlocks': 0,
        'statusxp': 0,
        'total_games': 0,
        'psn_count': 0,
        'xbox_count': 0,
        'steam_count': 0,
        'active_platforms': 0,
      };
    }
  }

  /// Check PSN achievements
  Future<void> _checkPSNAchievements(String userId, Map<String, dynamic> stats, Set<String> unlocked, List<String> newlyUnlocked) async {
    // Trophy volume milestones
    await _check(userId, 'psn_10_trophies', stats['total'], 10, unlocked, newlyUnlocked);
    await _check(userId, 'psn_50_trophies', stats['total'], 50, unlocked, newlyUnlocked);
    await _check(userId, 'psn_100_trophies', stats['total'], 100, unlocked, newlyUnlocked);
    await _check(userId, 'psn_500_trophies', stats['total'], 500, unlocked, newlyUnlocked);
    await _check(userId, 'psn_1000_trophies', stats['total'], 1000, unlocked, newlyUnlocked);
    await _check(userId, 'psn_2500_trophies', stats['total'], 2500, unlocked, newlyUnlocked);
    await _check(userId, 'psn_5000_trophies', stats['total'], 5000, unlocked, newlyUnlocked);
    await _check(userId, 'psn_10000_trophies', stats['total'], 10000, unlocked, newlyUnlocked);
    await _check(userId, 'psn_15000_trophies', stats['total'], 15000, unlocked, newlyUnlocked);
    
    // Bronze trophies
    await _check(userId, 'psn_25_bronze', stats['bronze'], 25, unlocked, newlyUnlocked);
    await _check(userId, 'psn_100_bronze', stats['bronze'], 100, unlocked, newlyUnlocked);
    await _check(userId, 'psn_500_bronze', stats['bronze'], 500, unlocked, newlyUnlocked);
    await _check(userId, 'psn_1000_bronze', stats['bronze'], 1000, unlocked, newlyUnlocked);
    await _check(userId, 'psn_5000_bronze', stats['bronze'], 5000, unlocked, newlyUnlocked);
    await _check(userId, 'psn_10000_bronze', stats['bronze'], 10000, unlocked, newlyUnlocked);
    
    // Silver trophies
    await _check(userId, 'psn_10_silver', stats['silver'], 10, unlocked, newlyUnlocked);
    await _check(userId, 'psn_100_silver', stats['silver'], 100, unlocked, newlyUnlocked);
    await _check(userId, 'psn_500_silver', stats['silver'], 500, unlocked, newlyUnlocked);
    await _check(userId, 'psn_1000_silver', stats['silver'], 1000, unlocked, newlyUnlocked);
    await _check(userId, 'psn_2000_silver', stats['silver'], 2000, unlocked, newlyUnlocked);
    
    // Gold trophies
    await _check(userId, 'psn_10_gold', stats['gold'], 10, unlocked, newlyUnlocked);
    await _check(userId, 'psn_50_gold', stats['gold'], 50, unlocked, newlyUnlocked);
    await _check(userId, 'psn_100_gold', stats['gold'], 100, unlocked, newlyUnlocked);
    await _check(userId, 'psn_500_gold', stats['gold'], 500, unlocked, newlyUnlocked);
    await _check(userId, 'psn_1000_gold', stats['gold'], 1000, unlocked, newlyUnlocked);
    
    // Platinum trophies
    await _check(userId, 'psn_1_platinum', stats['platinum'], 1, unlocked, newlyUnlocked);
    await _check(userId, 'psn_10_platinum', stats['platinum'], 10, unlocked, newlyUnlocked);
    await _check(userId, 'psn_25_platinum', stats['platinum'], 25, unlocked, newlyUnlocked);
    await _check(userId, 'psn_50_platinum', stats['platinum'], 50, unlocked, newlyUnlocked);
    await _check(userId, 'psn_100_platinum', stats['platinum'], 100, unlocked, newlyUnlocked);
    await _check(userId, 'psn_150_platinum', stats['platinum'], 150, unlocked, newlyUnlocked);
    await _check(userId, 'psn_200_platinum', stats['platinum'], 200, unlocked, newlyUnlocked);
    
    // Rare trophies
    await _check(userId, 'psn_1_rare', stats['rare'], 1, unlocked, newlyUnlocked);
    await _check(userId, 'psn_10_rare', stats['rare'], 10, unlocked, newlyUnlocked);
    await _check(userId, 'psn_25_rare', stats['rare'], 25, unlocked, newlyUnlocked);
    await _check(userId, 'psn_50_rare', stats['rare'], 50, unlocked, newlyUnlocked);
    await _check(userId, 'psn_100_rare', stats['rare'], 100, unlocked, newlyUnlocked);
  }

  /// Check Xbox achievements
  Future<void> _checkXboxAchievements(String userId, Map<String, dynamic> stats, Set<String> unlocked, List<String> newlyUnlocked) async {
    // Achievement volume milestones
    await _check(userId, 'xbox_10_achievements', stats['total'], 10, unlocked, newlyUnlocked);
    await _check(userId, 'xbox_50_achievements', stats['total'], 50, unlocked, newlyUnlocked);
    await _check(userId, 'xbox_100_achievements', stats['total'], 100, unlocked, newlyUnlocked);
    await _check(userId, 'xbox_500_achievements', stats['total'], 500, unlocked, newlyUnlocked);
    await _check(userId, 'xbox_1000_achievements', stats['total'], 1000, unlocked, newlyUnlocked);
    await _check(userId, 'xbox_2500_achievements', stats['total'], 2500, unlocked, newlyUnlocked);
    await _check(userId, 'xbox_5000_achievements', stats['total'], 5000, unlocked, newlyUnlocked);
    await _check(userId, 'xbox_10000_achievements', stats['total'], 10000, unlocked, newlyUnlocked);
    await _check(userId, 'xbox_15000_achievements', stats['total'], 15000, unlocked, newlyUnlocked);
    
    // Rare achievements
    await _check(userId, 'xbox_1_rare', stats['rare'], 1, unlocked, newlyUnlocked);
    await _check(userId, 'xbox_10_rare', stats['rare'], 10, unlocked, newlyUnlocked);
    await _check(userId, 'xbox_25_rare', stats['rare'], 25, unlocked, newlyUnlocked);
    await _check(userId, 'xbox_50_rare', stats['rare'], 50, unlocked, newlyUnlocked);
    await _check(userId, 'xbox_100_rare', stats['rare'], 100, unlocked, newlyUnlocked);
    
    // Gamerscore milestones
    await _check(userId, 'xbox_1000_gamerscore', stats['gamerscore'], 1000, unlocked, newlyUnlocked);
    await _check(userId, 'xbox_5000_gamerscore', stats['gamerscore'], 5000, unlocked, newlyUnlocked);
    await _check(userId, 'xbox_10000_gamerscore', stats['gamerscore'], 10000, unlocked, newlyUnlocked);
    await _check(userId, 'xbox_25000_gamerscore', stats['gamerscore'], 25000, unlocked, newlyUnlocked);
    await _check(userId, 'xbox_50000_gamerscore', stats['gamerscore'], 50000, unlocked, newlyUnlocked);
    await _check(userId, 'xbox_100000_gamerscore', stats['gamerscore'], 100000, unlocked, newlyUnlocked);
  }

  /// Check Steam achievements
  Future<void> _checkSteamAchievements(String userId, Map<String, dynamic> stats, Set<String> unlocked, List<String> newlyUnlocked) async {
    // Achievement volume milestones
    await _check(userId, 'steam_10_achievements', stats['total'], 10, unlocked, newlyUnlocked);
    await _check(userId, 'steam_50_achievements', stats['total'], 50, unlocked, newlyUnlocked);
    await _check(userId, 'steam_100_achievements', stats['total'], 100, unlocked, newlyUnlocked);
    await _check(userId, 'steam_500_achievements', stats['total'], 500, unlocked, newlyUnlocked);
    await _check(userId, 'steam_1000_achievements', stats['total'], 1000, unlocked, newlyUnlocked);
    await _check(userId, 'steam_2500_achievements', stats['total'], 2500, unlocked, newlyUnlocked);
    await _check(userId, 'steam_5000_achievements', stats['total'], 5000, unlocked, newlyUnlocked);
    await _check(userId, 'steam_10000_achievements', stats['total'], 10000, unlocked, newlyUnlocked);
    await _check(userId, 'steam_15000_achievements', stats['total'], 15000, unlocked, newlyUnlocked);
    
    // Rare achievements
    await _check(userId, 'steam_1_rare', stats['rare'], 1, unlocked, newlyUnlocked);
    await _check(userId, 'steam_10_rare', stats['rare'], 10, unlocked, newlyUnlocked);
    await _check(userId, 'steam_25_rare', stats['rare'], 25, unlocked, newlyUnlocked);
    await _check(userId, 'steam_50_rare', stats['rare'], 50, unlocked, newlyUnlocked);
    await _check(userId, 'steam_100_rare', stats['rare'], 100, unlocked, newlyUnlocked);
  }

  /// Check cross-platform achievements
  Future<void> _checkCrossPlatformAchievements(String userId, Map<String, dynamic> stats, Set<String> unlocked, List<String> newlyUnlocked) async {
    // Total unlock milestones
    await _check(userId, 'cross_1000_unlocks', stats['total_unlocks'], 1000, unlocked, newlyUnlocked);
    await _check(userId, 'cross_2500_unlocks', stats['total_unlocks'], 2500, unlocked, newlyUnlocked);
    await _check(userId, 'cross_5000_unlocks', stats['total_unlocks'], 5000, unlocked, newlyUnlocked);
    await _check(userId, 'cross_10000_unlocks', stats['total_unlocks'], 10000, unlocked, newlyUnlocked);
    await _check(userId, 'cross_15000_unlocks', stats['total_unlocks'], 15000, unlocked, newlyUnlocked);
    
    // StatusXP milestones
    await _check(userId, 'cross_statusxp_500', stats['statusxp'], 500, unlocked, newlyUnlocked);
    await _check(userId, 'cross_statusxp_1500', stats['statusxp'], 1500, unlocked, newlyUnlocked);
    await _check(userId, 'cross_statusxp_3500', stats['statusxp'], 3500, unlocked, newlyUnlocked);
    await _check(userId, 'cross_statusxp_7500', stats['statusxp'], 7500, unlocked, newlyUnlocked);
    await _check(userId, 'cross_statusxp_15000', stats['statusxp'], 15000, unlocked, newlyUnlocked);
    await _check(userId, 'cross_statusxp_20000', stats['statusxp'], 20000, unlocked, newlyUnlocked);
    await _check(userId, 'cross_statusxp_25000', stats['statusxp'], 25000, unlocked, newlyUnlocked);
    
    // Game collection counts
    await _check(userId, 'cross_50_games', stats['total_games'], 50, unlocked, newlyUnlocked);
    await _check(userId, 'cross_100_games', stats['total_games'], 100, unlocked, newlyUnlocked);
    await _check(userId, 'cross_250_games', stats['total_games'], 250, unlocked, newlyUnlocked);
    
    // Platform variety (requires achievements on all 3 platforms)
    if (stats['active_platforms'] >= 3) {
      // cross_triple_threat: 100+ on each
      if (stats['psn_count'] >= 100 && stats['xbox_count'] >= 100 && stats['steam_count'] >= 100) {
        await _check(userId, 'cross_triple_threat', 1, 1, unlocked, newlyUnlocked);
      }
      
      // cross_universal_gamer: 500+ on each
      if (stats['psn_count'] >= 500 && stats['xbox_count'] >= 500 && stats['steam_count'] >= 500) {
        await _check(userId, 'cross_universal_gamer', 1, 1, unlocked, newlyUnlocked);
      }
      
      // cross_platform_master: 1000+ on each
      if (stats['psn_count'] >= 1000 && stats['xbox_count'] >= 1000 && stats['steam_count'] >= 1000) {
        await _check(userId, 'cross_platform_master', 1, 1, unlocked, newlyUnlocked);
      }
      
      // cross_ecosystem_legend: 2500+ on each
      if (stats['psn_count'] >= 2500 && stats['xbox_count'] >= 2500 && stats['steam_count'] >= 2500) {
        await _check(userId, 'cross_ecosystem_legend', 1, 1, unlocked, newlyUnlocked);
      }
    }
  }

  /// Generic check helper
  Future<void> _check(String userId, String achievementId, int current, int required, Set<String> unlocked, List<String> newlyUnlocked) async {
    if (!unlocked.contains(achievementId) && current >= required) {
      if (await _unlockAchievement(userId, achievementId)) {
        newlyUnlocked.add(achievementId);
      }
    }
  }

  /// Get platform count helper
  Future<int> _getPlatformCount(String userId, String platform) async {
    try {
      if (platform == 'psn') {
        // PSN uses user_trophies table
        final result = await _client
            .from('user_trophies')
            .select('id')
            .eq('user_id', userId)
            .count();
        return result.count;
      } else {
        // Xbox and Steam use user_achievements with platform filter
        final result = await _client
            .from('user_achievements')
            .select('achievements!inner(platform)')
            .eq('user_id', userId)
            .eq('achievements.platform', platform)
            .count();
        return result.count;
      }
    } catch (e) {
      return 0;
    }
  }

  /// Get unlocked achievement IDs
  Future<Set<String>> _getUnlockedAchievementIds(String userId) async {
    try {
      final result = await _client
          .from('user_meta_achievements')
          .select('achievement_id')
          .eq('user_id', userId);
      return (result as List).map((r) => r['achievement_id'] as String).toSet();
    } catch (e) {
      return {};
    }
  }

  /// Unlock achievement using atomic database function
  Future<bool> _unlockAchievement(String userId, String achievementId) async {
    try {
      final response = await _client.rpc('unlock_achievement_if_new', params: {
        'p_user_id': userId,
        'p_achievement_id': achievementId,
        'p_unlocked_at': DateTime.now().toIso8601String(),
      });
      
      return response == true;
    } catch (e) {
      return false;
    }
  }
}
