import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Platform Achievement Checker Service
/// Checks and unlocks platform-specific achievements (PSN/Xbox/Steam/Cross-platform)
class PlatformAchievementChecker {
  final SupabaseClient _client;

  PlatformAchievementChecker(this._client);

  /// Check all achievements for a user after a sync
  Future<List<String>> checkAndUnlockAchievements(String userId) async {
    final newlyUnlocked = <String>[];

    try {
      debugPrint('🔍 Checking platform achievements for user: $userId');
      
      // Get user's stats
      final stats = await _getUserStats(userId);
      
      // Get already unlocked achievement IDs
      final unlocked = await _getUnlockedAchievementIds(userId);
      
      // Check PSN achievements
      if ((stats['psn_total'] ?? 0) > 0) {
        newlyUnlocked.addAll(await _checkPSNAchievements(userId, stats, unlocked));
      }
      
      // Check Xbox achievements
      if ((stats['xbox_total'] ?? 0) > 0) {
        newlyUnlocked.addAll(await _checkXboxAchievements(userId, stats, unlocked));
      }
      
      // Check Steam achievements
      if ((stats['steam_total'] ?? 0) > 0) {
        newlyUnlocked.addAll(await _checkSteamAchievements(userId, stats, unlocked));
      }
      
      // Check cross-platform achievements (requires all 3)
      if ((stats['psn_total'] ?? 0) > 0 && (stats['xbox_total'] ?? 0) > 0 && (stats['steam_total'] ?? 0) > 0) {
        newlyUnlocked.addAll(await _checkCrossPlatformAchievements(userId, stats, unlocked));
      }
      
      debugPrint('✅ Unlocked ${newlyUnlocked.length} new achievements');
      return newlyUnlocked;
    } catch (e, stackTrace) {
      debugPrint('❌ Error checking achievements: $e\n$stackTrace');
      return [];
    }
  }

  /// Get user's gaming stats
  Future<Map<String, int>> _getUserStats(String userId) async {
    final stats = <String, int>{};
    
    // Get achievement counts from user_achievements
    final achievementData = await _client
        .from('user_achievements')
        .select('achievements(platform, psn_trophy_type, xbox_gamerscore, rarity_global)')
        .eq('user_id', userId);
    
    int psnTotal = 0, psnBronze = 0, psnSilver = 0, psnGold = 0, psnPlatinum = 0, psnRare = 0;
    int xboxTotal = 0, xboxGamerscore = 0, xboxRare = 0;
    int steamTotal = 0, steamRare = 0;
    
    for (final row in achievementData) {
      final achievement = row['achievements'] as Map<String, dynamic>?;
      if (achievement == null) continue;
      
      final platform = achievement['platform'] as String?;
      final rarity = (achievement['rarity_global'] as num?)?.toDouble();
      
      if (platform == 'psn') {
        psnTotal++;
        final trophyType = achievement['psn_trophy_type'] as String?;
        if (trophyType == 'bronze') psnBronze++;
        if (trophyType == 'silver') psnSilver++;
        if (trophyType == 'gold') psnGold++;
        if (trophyType == 'platinum') psnPlatinum++;
        if (rarity != null && rarity < 10) psnRare++;
      } else if (platform == 'xbox') {
        xboxTotal++;
        xboxGamerscore += (achievement['xbox_gamerscore'] as int?) ?? 0;
        if (rarity != null && rarity < 10) xboxRare++;
      } else if (platform == 'steam') {
        steamTotal++;
        if (rarity != null && rarity < 10) steamRare++;
      }
    }
    
    // Get completion counts
    final completionData = await _client.rpc('get_user_completions', params: {
      'p_user_id': userId,
    });
    
    final xboxComplete = (completionData as Map?)? ['xbox_complete'] ?? 0;
    final steamPerfect = (completionData)?['steam_perfect'] ?? 0;
    
    stats['psn_total'] = psnTotal;
    stats['psn_bronze'] = psnBronze;
    stats['psn_silver'] = psnSilver;
    stats['psn_gold'] = psnGold;
    stats['psn_platinum'] = psnPlatinum;
    stats['psn_rare'] = psnRare;
    stats['xbox_total'] = xboxTotal;
    stats['xbox_gamerscore'] = xboxGamerscore;
    stats['xbox_complete'] = xboxComplete;
    stats['xbox_rare'] = xboxRare;
    stats['steam_total'] = steamTotal;
    stats['steam_perfect'] = steamPerfect;
    stats['steam_rare'] = steamRare;
    stats['total_unlocks'] = psnTotal + xboxTotal + steamTotal;
    
    // Calculate StatusXP
    stats['statusxp'] = (psnBronze * 15) + (psnSilver * 30) + (psnGold * 90) + 
                         (psnPlatinum * 300) + (xboxGamerscore ~/ 10);
    
    return stats;
  }

  Future<Set<String>> _getUnlockedAchievementIds(String userId) async {
    final result = await _client
        .from('user_meta_achievements')
        .select('achievement_id')
        .eq('user_id', userId);

    return result.map((row) => row['achievement_id'] as String).toSet();
  }

  /// Check PSN-specific achievements
  Future<List<String>> _checkPSNAchievements(
    String userId,
    Map<String, int> stats,
    Set<String> unlocked,
  ) async {
    final newlyUnlocked = <String>[];
    
    // Trophy Total Achievements
    final trophyMilestones = {
      'psn_first_trophy': 1, 'psn_10_trophies': 10, 'psn_50_trophies': 50,
      'psn_100_trophies': 100, 'psn_250_trophies': 250, 'psn_500_trophies': 500,
      'psn_1000_trophies': 1000, 'psn_2500_trophies': 2500, 'psn_5000_trophies': 5000,
      'psn_7500_trophies': 7500, 'psn_10000_trophies': 10000, 'psn_15000_trophies': 15000,
    };
    
    for (final entry in trophyMilestones.entries) {
      if (!unlocked.contains(entry.key) && stats['psn_total']! >= entry.value) {
        await _unlockAchievement(userId, entry.key);
        newlyUnlocked.add(entry.key);
      }
    }
    
    // Bronze achievements
    final bronzeMilestones = {
      'psn_25_bronze': 25, 'psn_100_bronze': 100, 'psn_500_bronze': 500,
      'psn_1000_bronze': 1000, 'psn_2500_bronze': 2500, 'psn_5000_bronze': 5000,
      'psn_7500_bronze': 7500, 'psn_10000_bronze': 10000,
    };
    
    for (final entry in bronzeMilestones.entries) {
      if (!unlocked.contains(entry.key) && stats['psn_bronze']! >= entry.value) {
        await _unlockAchievement(userId, entry.key);
        newlyUnlocked.add(entry.key);
      }
    }
    
    // Silver achievements
    final silverMilestones = {
      'psn_25_silver': 25, 'psn_100_silver': 100, 'psn_500_silver': 500,
      'psn_1000_silver': 1000, 'psn_2000_silver': 2000, 'psn_3000_silver': 3000,
    };
    
    for (final entry in silverMilestones.entries) {
      if (!unlocked.contains(entry.key) && stats['psn_silver']! >= entry.value) {
        await _unlockAchievement(userId, entry.key);
        newlyUnlocked.add(entry.key);
      }
    }
    
    // Gold achievements
    final goldMilestones = {
      'psn_10_gold': 10, 'psn_50_gold': 50, 'psn_250_gold': 250,
      'psn_500_gold': 500, 'psn_750_gold': 750, 'psn_1000_gold': 1000,
    };
    
    for (final entry in goldMilestones.entries) {
      if (!unlocked.contains(entry.key) && stats['psn_gold']! >= entry.value) {
        await _unlockAchievement(userId, entry.key);
        newlyUnlocked.add(entry.key);
      }
    }
    
    // Platinum achievements
    final platinumMilestones = {
      'psn_1_platinum': 1, 'psn_10_platinum': 10, 'psn_25_platinum': 25,
      'psn_50_platinum': 50, 'psn_100_platinum': 100, 'psn_150_platinum': 150,
      'psn_200_platinum': 200, 'psn_250_platinum': 250,
    };
    
    for (final entry in platinumMilestones.entries) {
      if (!unlocked.contains(entry.key) && stats['psn_platinum']! >= entry.value) {
        await _unlockAchievement(userId, entry.key);
        newlyUnlocked.add(entry.key);
      }
    }
    
    // Rare achievements
    final rareMilestones = {
      'psn_1_rare': 1, 'psn_10_rare': 10, 'psn_25_rare': 25,
      'psn_50_rare': 50, 'psn_100_rare': 100, 'psn_250_rare': 250,
    };
    
    for (final entry in rareMilestones.entries) {
      if (!unlocked.contains(entry.key) && stats['psn_rare']! >= entry.value) {
        await _unlockAchievement(userId, entry.key);
        newlyUnlocked.add(entry.key);
      }
    }
    
    return newlyUnlocked;
  }

  /// Check Xbox-specific achievements
  Future<List<String>> _checkXboxAchievements(
    String userId,
    Map<String, int> stats,
    Set<String> unlocked,
  ) async {
    final newlyUnlocked = <String>[];
    
    // Achievement total milestones
    final achievementMilestones = {
      'xbox_first_unlock': 1, 'xbox_10_achievements': 10, 'xbox_50_achievements': 50,
      'xbox_100_achievements': 100, 'xbox_250_achievements': 250, 'xbox_500_achievements': 500,
      'xbox_1000_achievements': 1000, 'xbox_2500_achievements': 2500, 'xbox_5000_achievements': 5000,
      'xbox_7500_achievements': 7500, 'xbox_10000_achievements': 10000, 'xbox_15000_achievements': 15000,
    };
    
    for (final entry in achievementMilestones.entries) {
      if (!unlocked.contains(entry.key) && stats['xbox_total']! >= entry.value) {
        await _unlockAchievement(userId, entry.key);
        newlyUnlocked.add(entry.key);
      }
    }
    
    // Gamerscore milestones
    final gamerscoreMilestones = {
      'xbox_1000_gs': 1000, 'xbox_5000_gs': 5000, 'xbox_10000_gs': 10000,
      'xbox_25000_gs': 25000, 'xbox_50000_gs': 50000, 'xbox_75000_gs': 75000,
      'xbox_100000_gs': 100000, 'xbox_150000_gs': 150000, 'xbox_200000_gs': 200000,
      'xbox_250000_gs': 250000, 'xbox_300000_gs': 300000,
    };
    
    for (final entry in gamerscoreMilestones.entries) {
      if (!unlocked.contains(entry.key) && stats['xbox_gamerscore']! >= entry.value) {
        await _unlockAchievement(userId, entry.key);
        newlyUnlocked.add(entry.key);
      }
    }
    
    // Completion milestones
    final completionMilestones = {
      'xbox_1_complete': 1, 'xbox_10_complete': 10, 'xbox_25_complete': 25,
      'xbox_50_complete': 50, 'xbox_100_complete': 100, 'xbox_150_complete': 150,
    };
    
    for (final entry in completionMilestones.entries) {
      if (!unlocked.contains(entry.key) && stats['xbox_complete']! >= entry.value) {
        await _unlockAchievement(userId, entry.key);
        newlyUnlocked.add(entry.key);
      }
    }
    
    // Rare achievements
    final rareMilestones = {
      'xbox_1_rare': 1, 'xbox_10_rare': 10, 'xbox_25_rare': 25,
      'xbox_50_rare': 50, 'xbox_100_rare': 100, 'xbox_250_rare': 250,
    };
    
    for (final entry in rareMilestones.entries) {
      if (!unlocked.contains(entry.key) && stats['xbox_rare']! >= entry.value) {
        await _unlockAchievement(userId, entry.key);
        newlyUnlocked.add(entry.key);
      }
    }
    
    return newlyUnlocked;
  }

  /// Check Steam-specific achievements
  Future<List<String>> _checkSteamAchievements(
    String userId,
    Map<String, int> stats,
    Set<String> unlocked,
  ) async {
    final newlyUnlocked = <String>[];
    
    // Achievement total milestones
    final achievementMilestones = {
      'steam_first_unlock': 1, 'steam_10_achievements': 10, 'steam_50_achievements': 50,
      'steam_100_achievements': 100, 'steam_250_achievements': 250, 'steam_500_achievements': 500,
      'steam_1000_achievements': 1000, 'steam_2500_achievements': 2500, 'steam_5000_achievements': 5000,
      'steam_7500_achievements': 7500, 'steam_10000_achievements': 10000, 'steam_15000_achievements': 15000,
    };
    
    for (final entry in achievementMilestones.entries) {
      if (!unlocked.contains(entry.key) && stats['steam_total']! >= entry.value) {
        await _unlockAchievement(userId, entry.key);
        newlyUnlocked.add(entry.key);
      }
    }
    
    // Perfect game milestones
    final perfectMilestones = {
      'steam_1_perfect': 1, 'steam_10_perfect': 10, 'steam_25_perfect': 25,
      'steam_50_perfect': 50, 'steam_100_perfect': 100, 'steam_150_perfect': 150,
    };
    
    for (final entry in perfectMilestones.entries) {
      if (!unlocked.contains(entry.key) && stats['steam_perfect']! >= entry.value) {
        await _unlockAchievement(userId, entry.key);
        newlyUnlocked.add(entry.key);
      }
    }
    
    // Rare achievements
    final rareMilestones = {
      'steam_1_rare': 1, 'steam_10_rare': 10, 'steam_25_rare': 25,
      'steam_50_rare': 50, 'steam_100_rare': 100, 'steam_250_rare': 250,
    };
    
    for (final entry in rareMilestones.entries) {
      if (!unlocked.contains(entry.key) && stats['steam_rare']! >= entry.value) {
        await _unlockAchievement(userId, entry.key);
        newlyUnlocked.add(entry.key);
      }
    }
    
    return newlyUnlocked;
  }

  /// Check cross-platform achievements (requires all 3 platforms)
  Future<List<String>> _checkCrossPlatformAchievements(
    String userId,
    Map<String, int> stats,
    Set<String> unlocked,
  ) async {
    final newlyUnlocked = <String>[];
    
    // StatusXP milestones
    final statusxpMilestones = {
      'cross_statusxp_500': 500, 'cross_statusxp_1500': 1500, 'cross_statusxp_3500': 3500,
      'cross_statusxp_7500': 7500, 'cross_statusxp_15000': 15000, 'cross_statusxp_20000': 20000,
      'cross_statusxp_25000': 25000,
    };
    
    for (final entry in statusxpMilestones.entries) {
      if (!unlocked.contains(entry.key) && stats['statusxp']! >= entry.value) {
        await _unlockAchievement(userId, entry.key);
        newlyUnlocked.add(entry.key);
      }
    }
    
    // Multi-platform mastery (requires X+ on each platform)
    if (!unlocked.contains('cross_triple_threat') && 
        stats['psn_total']! >= 100 && stats['xbox_total']! >= 100 && stats['steam_total']! >= 100) {
      await _unlockAchievement(userId, 'cross_triple_threat');
      newlyUnlocked.add('cross_triple_threat');
    }
    
    if (!unlocked.contains('cross_universal_gamer') && 
        stats['psn_total']! >= 500 && stats['xbox_total']! >= 500 && stats['steam_total']! >= 500) {
      await _unlockAchievement(userId, 'cross_universal_gamer');
      newlyUnlocked.add('cross_universal_gamer');
    }
    
    if (!unlocked.contains('cross_platform_master') && 
        stats['psn_total']! >= 1000 && stats['xbox_total']! >= 1000 && stats['steam_total']! >= 1000) {
      await _unlockAchievement(userId, 'cross_platform_master');
      newlyUnlocked.add('cross_platform_master');
    }
    
    if (!unlocked.contains('cross_ecosystem_legend') && 
        stats['psn_total']! >= 2500 && stats['xbox_total']! >= 2500 && stats['steam_total']! >= 2500) {
      await _unlockAchievement(userId, 'cross_ecosystem_legend');
      newlyUnlocked.add('cross_ecosystem_legend');
    }
    
    // Combined unlocks
    final combinedMilestones = {
      'cross_1000_unlocks': 1000, 'cross_2500_unlocks': 2500, 'cross_5000_unlocks': 5000,
      'cross_10000_unlocks': 10000, 'cross_15000_unlocks': 15000,
    };
    
    for (final entry in combinedMilestones.entries) {
      if (!unlocked.contains(entry.key) && stats['total_unlocks']! >= entry.value) {
        await _unlockAchievement(userId, entry.key);
        newlyUnlocked.add(entry.key);
      }
    }
    
    // Rare hunter (requires X rare on each platform)
    if (!unlocked.contains('cross_rare_10_each') && 
        stats['psn_rare']! >= 10 && stats['xbox_rare']! >= 10 && stats['steam_rare']! >= 10) {
      await _unlockAchievement(userId, 'cross_rare_10_each');
      newlyUnlocked.add('cross_rare_10_each');
    }
    
    if (!unlocked.contains('cross_rare_25_each') && 
        stats['psn_rare']! >= 25 && stats['xbox_rare']! >= 25 && stats['steam_rare']! >= 25) {
      await _unlockAchievement(userId, 'cross_rare_25_each');
      newlyUnlocked.add('cross_rare_25_each');
    }
    
    if (!unlocked.contains('cross_rare_50_each') && 
        stats['psn_rare']! >= 50 && stats['xbox_rare']! >= 50 && stats['steam_rare']! >= 50) {
      await _unlockAchievement(userId, 'cross_rare_50_each');
      newlyUnlocked.add('cross_rare_50_each');
    }
    
    return newlyUnlocked;
  }

  Future<void> _unlockAchievement(String userId, String achievementId) async {
    await _client.from('user_meta_achievements').upsert({
      'user_id': userId,
      'achievement_id': achievementId,
      'unlocked_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id,achievement_id');
    
    debugPrint('🏆 Unlocked: $achievementId');
  }
}
