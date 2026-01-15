import 'package:supabase_flutter/supabase_flutter.dart';

/// Achievement Checker Service
/// Automatically detects when users meet achievement conditions and unlocks them
class AchievementCheckerService {
  final SupabaseClient _client;

  AchievementCheckerService(this._client);

  /// Check all achievements for a user and unlock any that are met
  Future<List<String>> checkAndUnlockAchievements(String userId) async {
    final newlyUnlocked = <String>[];

    try {
      // Get user's current stats
      final stats = await _getUserStats(userId);
      // Get already unlocked achievements
      final unlockedIds = await _getUnlockedAchievementIds(userId);
      // Check each category
      final rarityUnlocked = await _checkRarityAchievements(userId, stats, unlockedIds);
      newlyUnlocked.addAll(rarityUnlocked);
      
      final volumeUnlocked = await _checkVolumeAchievements(userId, stats, unlockedIds);
      newlyUnlocked.addAll(volumeUnlocked);
      
      final platformUnlocked = await _checkPlatformAchievements(userId, stats, unlockedIds);
      newlyUnlocked.addAll(platformUnlocked);
      
      final metaUnlocked = await _checkMetaAchievements(userId, stats, unlockedIds);
      newlyUnlocked.addAll(metaUnlocked);
      
      // TODO: Uncomment after running add_achievement_schema.sql migration
      // final completionUnlocked = await _checkCompletionAchievements(userId, stats, unlockedIds);
      // debugPrint('📊 Completion check: ${completionUnlocked.length} new achievements');
      // newlyUnlocked.addAll(completionUnlocked);
      
      // TODO: Uncomment after running add_achievement_schema.sql migration
      // final varietyUnlocked = await _checkVarietyAchievements(userId, stats, unlockedIds);
      // debugPrint('🎭 Variety check: ${varietyUnlocked.length} new achievements');
      // newlyUnlocked.addAll(varietyUnlocked);
      
      final timeUnlocked = await _checkTimeAchievements(userId, stats, unlockedIds);
      newlyUnlocked.addAll(timeUnlocked);
      
      final streakUnlocked = await _checkStreakAchievements(userId, stats, unlockedIds);
      newlyUnlocked.addAll(streakUnlocked);
      return newlyUnlocked;
    } catch (e) {
      return [];
    }
  }  Future<Map<String, dynamic>> _getUserStats(String userId) async {
    // Get total trophy/achievement counts with rarity data
    // PSN trophies from user_trophies table
    final trophyData = await _client
        .from('user_trophies')
        .select('trophy_id, trophies(*)')
        .eq('user_id', userId);

    // Xbox/Steam achievements from user_achievements table
    final achievementData = await _client
        .from('user_achievements')
        .select('achievement_id, achievements(*)')
        .eq('user_id', userId);

    final totalAchievements = trophyData.length + achievementData.length;
    final rarityCounts = <double, int>{};
    
    // Count PSN trophy rarities
    for (final trophy in trophyData) {
      final trophyInfo = trophy['trophies'] as Map<String, dynamic>?;
      final rarity = trophyInfo?['rarity_global'] as num?;
      if (rarity != null && rarity > 0) {
        if (rarity < 1.0) rarityCounts[1.0] = (rarityCounts[1.0] ?? 0) + 1;
        if (rarity < 2.0) rarityCounts[2.0] = (rarityCounts[2.0] ?? 0) + 1;
        if (rarity < 5.0) rarityCounts[5.0] = (rarityCounts[5.0] ?? 0) + 1;
      }
    }
    
    // Count Xbox/Steam achievement rarities
    for (final achievement in achievementData) {
      final achievementInfo = achievement['achievements'] as Map<String, dynamic>?;
      final rarity = achievementInfo?['rarity_global'] as num?;
      if (rarity != null && rarity > 0) {
        if (rarity < 1.0) rarityCounts[1.0] = (rarityCounts[1.0] ?? 0) + 1;
        if (rarity < 2.0) rarityCounts[2.0] = (rarityCounts[2.0] ?? 0) + 1;
        if (rarity < 5.0) rarityCounts[5.0] = (rarityCounts[5.0] ?? 0) + 1;
      }
    }

    // Get platinum/completion counts
    final gameData = await _client
        .from('user_games')
        .select('platform_id, completion_percent, has_platinum')
        .eq('user_id', userId);

    int platinumCount = 0;
    final int totalGames = gameData.length;
    final platformCounts = <int, int>{};

    for (final game in gameData) {
      final platformId = game['platform_id'] as int?;
      final hasPlatinum = game['has_platinum'] as bool?;

      if (platformId != null) {
        platformCounts[platformId] = (platformCounts[platformId] ?? 0) + 1;
      }

      // Only count actual platinums, not 100% completions
      if (hasPlatinum == true) {
        platinumCount++;
      }
    }

    // Check if all three platforms synced
    final profileData = await _client
        .from('profiles')
        .select('last_psn_sync_at, last_xbox_sync_at, last_steam_sync_at')
        .eq('id', userId)
        .single();

    final hasPsnSync = profileData['last_psn_sync_at'] != null;
    final hasXboxSync = profileData['last_xbox_sync_at'] != null;
    final hasSteamSync = profileData['last_steam_sync_at'] != null;

    return {
      'totalAchievements': totalAchievements,
      'rarityCounts': rarityCounts,
      'platinumCount': platinumCount,
      'totalGames': totalGames,
      'platformCounts': platformCounts,
      'hasPsnSync': hasPsnSync,
      'hasXboxSync': hasXboxSync,
      'hasSteamSync': hasSteamSync,
      'allPlatformsSynced': hasPsnSync && hasXboxSync && hasSteamSync,
    };
  }

  Future<Set<String>> _getUnlockedAchievementIds(String userId) async {
    final result = await _client
        .from('user_meta_achievements')
        .select('achievement_id')
        .eq('user_id', userId);

    return result.map((row) => row['achievement_id'] as String).toSet();
  }

  Future<List<String>> _checkRarityAchievements(
    String userId,
    Map<String, dynamic> stats,
    Set<String> unlocked,
  ) async {
    final newlyUnlocked = <String>[];
    final rarityCounts = stats['rarityCounts'] as Map<double, int>;

    // Rare Air: 1 trophy < 5%
    if (!unlocked.contains('rare_air') && (rarityCounts[5.0] ?? 0) >= 1) {
      await _unlockAchievement(userId, 'rare_air');
      newlyUnlocked.add('rare_air');
    }

    // Baller: 1 trophy < 2%
    if (!unlocked.contains('baller') && (rarityCounts[2.0] ?? 0) >= 1) {
      await _unlockAchievement(userId, 'baller');
      newlyUnlocked.add('baller');
    }

    // One-Percenter: 1 trophy < 1%
    if (!unlocked.contains('one_percenter') && (rarityCounts[1.0] ?? 0) >= 1) {
      await _unlockAchievement(userId, 'one_percenter');
      newlyUnlocked.add('one_percenter');
    }

    // Diamond Hands: 5 trophies < 5%
    if (!unlocked.contains('diamond_hands') && (rarityCounts[5.0] ?? 0) >= 5) {
      await _unlockAchievement(userId, 'diamond_hands');
      newlyUnlocked.add('diamond_hands');
    }

    // Mythic Hunter: 10 trophies < 5%
    if (!unlocked.contains('mythic_hunter') && (rarityCounts[5.0] ?? 0) >= 10) {
      await _unlockAchievement(userId, 'mythic_hunter');
      newlyUnlocked.add('mythic_hunter');
    }

    // Elite Finish: 1 platinum with rarity < 10%
    if (!unlocked.contains('elite_finish')) {
      // Check achievements table for PSN platinums
      final elitePlatinums = await _client
          .from('user_achievements')
          .select('achievement_id, achievements!inner(is_platinum, rarity_global)')
          .eq('user_id', userId);
      
      final hasElite = elitePlatinums.any((row) {
        final achievement = row['achievements'] as Map<String, dynamic>?;
        if (achievement == null) return false;
        return achievement['is_platinum'] == true &&
               (achievement['rarity_global'] as num?) != null &&
               (achievement['rarity_global'] as num) < 10.0;
      });
      
      if (hasElite) {
        await _unlockAchievement(userId, 'elite_finish');
        newlyUnlocked.add('elite_finish');
      }
    }

    // Sweat Lord: 1 platinum with rarity < 5%
    if (!unlocked.contains('sweat_lord')) {
      // Check achievements table for PSN platinums
      final sweatPlatinums = await _client
          .from('user_achievements')
          .select('achievement_id, achievements!inner(is_platinum, rarity_global)')
          .eq('user_id', userId);
      
      final hasSweat = sweatPlatinums.any((row) {
        final achievement = row['achievements'] as Map<String, dynamic>?;
        if (achievement == null) return false;
        return achievement['is_platinum'] == true &&
               (achievement['rarity_global'] as num?) != null &&
               (achievement['rarity_global'] as num) < 5.0;
      });
      
      if (hasSweat) {
        await _unlockAchievement(userId, 'sweat_lord');
        newlyUnlocked.add('sweat_lord');
      }
    }

    // Never Casual: 25 trophies/achievements all rarer than 20%
    if (!unlocked.contains('never_casual')) {
      // Check PSN trophies
      final psnResult = await _client
          .from('user_trophies')
          .select('trophy_id, trophies(*)')
          .eq('user_id', userId);
      
      final rarePsnTrophies = psnResult.where((row) {
        final trophy = row['trophies'] as Map<String, dynamic>?;
        if (trophy == null) return false;
        return (trophy['rarity_global'] as num?) != null && (trophy['rarity_global'] as num) < 20.0;
      }).toList();
      
      // Check Xbox/Steam achievements
      final achievementsResult = await _client
          .from('user_achievements')
          .select('achievement_id, achievements(*)')
          .eq('user_id', userId);
      
      final rareAchievements = achievementsResult.where((row) {
        final achievement = row['achievements'] as Map<String, dynamic>?;
        if (achievement == null) return false;
        return (achievement['rarity_global'] as num?) != null && (achievement['rarity_global'] as num) < 20.0;
      }).toList();
      
      final totalRare = rarePsnTrophies.length + rareAchievements.length;
      
      if (totalRare >= 25) {
        await _unlockAchievement(userId, 'never_casual');
        newlyUnlocked.add('never_casual');
      }
    }

    // Fresh Flex: Rarest trophy in last 7 days
    if (!unlocked.contains('fresh_flex')) {
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7)).toIso8601String();
      
      // Check PSN trophies
      final psnResult = await _client
          .from('user_trophies')
          .select('trophy_id, trophies(*), earned_at')
          .eq('user_id', userId)
          .gte('earned_at', sevenDaysAgo);
      
      final recentPsn = psnResult.where((row) {
        final trophy = row['trophies'] as Map<String, dynamic>?;
        return trophy != null && (trophy['rarity_global'] as num?) != null;
      }).toList();
      
      // Check Xbox/Steam achievements
      final achievementsResult = await _client
          .from('user_achievements')
          .select('achievement_id, achievements(*), earned_at')
          .eq('user_id', userId)
          .gte('earned_at', sevenDaysAgo);
      
      final recentAchievements = achievementsResult.where((row) {
        final achievement = row['achievements'] as Map<String, dynamic>?;
        return achievement != null && (achievement['rarity_global'] as num?) != null;
      }).toList();
      
      // Find rarest recent trophy
      double? rarestRecent;
      for (final row in recentPsn) {
        final trophy = row['trophies'] as Map<String, dynamic>;
        final rarity = (trophy['rarity_global'] as num).toDouble();
        if (rarestRecent == null || rarity < rarestRecent) {
          rarestRecent = rarity;
        }
      }
      for (final row in recentAchievements) {
        final achievement = row['achievements'] as Map<String, dynamic>;
        final rarity = (achievement['rarity_global'] as num).toDouble();
        if (rarestRecent == null || rarity < rarestRecent) {
          rarestRecent = rarity;
        }
      }
      
      // Check if this is the user's overall rarest trophy
      if (rarestRecent != null) {
        // Get all trophies/achievements
        final allPsnResult = await _client
            .from('user_trophies')
            .select('trophy_id, trophies(*)')
            .eq('user_id', userId);
        
        final allAchievementsResult = await _client
            .from('user_achievements')
            .select('achievement_id, achievements(*)')
            .eq('user_id', userId);
        
        double? overallRarest;
        for (final row in allPsnResult) {
          final trophy = row['trophies'] as Map<String, dynamic>?;
          final rarity = trophy?['rarity_global'] as num?;
          if (rarity != null && (overallRarest == null || rarity < overallRarest)) {
            overallRarest = rarity.toDouble();
          }
        }
        for (final row in allAchievementsResult) {
          final achievement = row['achievements'] as Map<String, dynamic>?;
          final rarity = achievement?['rarity_global'] as num?;
          if (rarity != null && (overallRarest == null || rarity < overallRarest)) {
            overallRarest = rarity.toDouble();
          }
        }
        
        if (overallRarest != null && rarestRecent <= overallRarest) {
          await _unlockAchievement(userId, 'fresh_flex');
          newlyUnlocked.add('fresh_flex');
        }
      }
    }

    return newlyUnlocked;
  }

  Future<List<String>> _checkVolumeAchievements(
    String userId,
    Map<String, dynamic> stats,
    Set<String> unlocked,
  ) async {
    final newlyUnlocked = <String>[];
    final total = stats['totalAchievements'] as int;
    final platinums = stats['platinumCount'] as int;

    // Trophy count milestones
    if (!unlocked.contains('warming_up') && total >= 50) {
      await _unlockAchievement(userId, 'warming_up');
      newlyUnlocked.add('warming_up');
    }

    if (!unlocked.contains('on_the_grind') && total >= 250) {
      await _unlockAchievement(userId, 'on_the_grind');
      newlyUnlocked.add('on_the_grind');
    }

    if (!unlocked.contains('xp_machine') && total >= 500) {
      await _unlockAchievement(userId, 'xp_machine');
      newlyUnlocked.add('xp_machine');
    }

    if (!unlocked.contains('achievement_engine') && total >= 1000) {
      await _unlockAchievement(userId, 'achievement_engine');
      newlyUnlocked.add('achievement_engine');
    }

    if (!unlocked.contains('no_life_great_life') && total >= 2500) {
      await _unlockAchievement(userId, 'no_life_great_life');
      newlyUnlocked.add('no_life_great_life');
    }

    // Platinum milestones
    if (!unlocked.contains('double_digits') && platinums >= 10) {
      await _unlockAchievement(userId, 'double_digits');
      newlyUnlocked.add('double_digits');
    }

    if (!unlocked.contains('certified_platinum') && platinums >= 25) {
      await _unlockAchievement(userId, 'certified_platinum');
      newlyUnlocked.add('certified_platinum');
    }

    if (!unlocked.contains('legendary_finisher') && platinums >= 50) {
      await _unlockAchievement(userId, 'legendary_finisher');
      newlyUnlocked.add('legendary_finisher');
    }

    // Spike Week - 3 games to 100% in one week
    final weekCompletions = await _client.rpc('check_spike_week', params: {
      'p_user_id': userId,
    });
    
    if (!unlocked.contains('spike_week') && weekCompletions == true) {
      await _unlockAchievement(userId, 'spike_week');
      newlyUnlocked.add('spike_week');
    }

    // Power Session - 100 trophies in 24 hours
    final powerSession = await _client.rpc('check_power_session', params: {
      'p_user_id': userId,
    });
    
    if (!unlocked.contains('power_session') && powerSession == true) {
      await _unlockAchievement(userId, 'power_session');
      newlyUnlocked.add('power_session');
    }

    return newlyUnlocked;
  }

  Future<List<String>> _checkPlatformAchievements(
    String userId,
    Map<String, dynamic> stats,
    Set<String> unlocked,
  ) async {
    final newlyUnlocked = <String>[];
    final platformCounts = stats['platformCounts'] as Map<int, int>;

    // Platform IDs: PSN=[1,2,5,9], Xbox=[3,10,11,12], Steam=[4]
    final hasPSN = (platformCounts[1] ?? 0) > 0 || (platformCounts[2] ?? 0) > 0 || 
                   (platformCounts[5] ?? 0) > 0 || (platformCounts[9] ?? 0) > 0;
    final hasXbox = (platformCounts[3] ?? 0) > 0 || (platformCounts[10] ?? 0) > 0 || 
                    (platformCounts[11] ?? 0) > 0 || (platformCounts[12] ?? 0) > 0;
    final hasSteam = (platformCounts[4] ?? 0) > 0;

    // Welcome achievements - first trophy on each platform
    if (!unlocked.contains('welcome_trophy_room') && hasPSN) {
      await _unlockAchievement(userId, 'welcome_trophy_room');
      newlyUnlocked.add('welcome_trophy_room');
    }

    if (!unlocked.contains('welcome_gamerscore') && hasXbox) {
      await _unlockAchievement(userId, 'welcome_gamerscore');
      newlyUnlocked.add('welcome_gamerscore');
    }

    if (!unlocked.contains('welcome_pc_grind') && hasSteam) {
      await _unlockAchievement(userId, 'welcome_pc_grind');
      newlyUnlocked.add('welcome_pc_grind');
    }

    // Triforce - achievements on all three platforms
    if (!unlocked.contains('triforce') && hasPSN && hasXbox && hasSteam) {
      await _unlockAchievement(userId, 'triforce');
      newlyUnlocked.add('triforce');
    }

    // Cross-Platform Conqueror - platinum on PS, 1000G on Xbox, 100% on Steam
    if (!unlocked.contains('cross_platform_conqueror')) {
      final hasPSPlatinum = await _client
          .from('user_games')
          .select('id')
          .eq('user_id', userId)
          .inFilter('platform_id', [1, 2, 5, 9])
          .eq('has_platinum', true)
          .limit(1);
      
      final hasXboxCompletion = await _client
          .from('user_games')
          .select('id')
          .eq('user_id', userId)
          .inFilter('platform_id', [3, 10, 11, 12])
          .eq('has_platinum', true)
          .limit(1);
      
      final hasSteamCompletion = await _client
          .from('user_games')
          .select('id')
          .eq('user_id', userId)
          .eq('platform_id', 4)
          .gte('completion_percent', 100)
          .limit(1);
      
      if (hasPSPlatinum.isNotEmpty && hasXboxCompletion.isNotEmpty && hasSteamCompletion.isNotEmpty) {
        await _unlockAchievement(userId, 'cross_platform_conqueror');
        newlyUnlocked.add('cross_platform_conqueror');
      }
    }

    return newlyUnlocked;
  }

  Future<List<String>> _checkMetaAchievements(
    String userId,
    Map<String, dynamic> stats,
    Set<String> unlocked,
  ) async {
    final newlyUnlocked = <String>[];

    // Systems Online - synced all three platforms
    if (!unlocked.contains('systems_online') && stats['allPlatformsSynced'] == true) {
      await _unlockAchievement(userId, 'systems_online');
      newlyUnlocked.add('systems_online');
    }

    // Interior Designer - check if flex room has been customized
    final flexRoomData = await _client
        .from('flex_room_data')
        .select('flex_of_all_time_id, rarest_flex_id, most_time_sunk_id, sweatiest_platinum_id, superlatives')
        .eq('user_id', userId)
        .maybeSingle();

    if (!unlocked.contains('interior_designer') && flexRoomData != null) {
      // Check if at least 3 of the main slots are filled
      int filledSlots = 0;
      if (flexRoomData['flex_of_all_time_id'] != null) filledSlots++;
      if (flexRoomData['rarest_flex_id'] != null) filledSlots++;
      if (flexRoomData['most_time_sunk_id'] != null) filledSlots++;
      if (flexRoomData['sweatiest_platinum_id'] != null) filledSlots++;
      
      // Count superlatives
      final superlatives = flexRoomData['superlatives'] as Map<String, dynamic>?;
      if (superlatives != null && superlatives.isNotEmpty) {
        filledSlots += superlatives.length;
      }

      if (filledSlots >= 3) {
        await _unlockAchievement(userId, 'interior_designer');
        newlyUnlocked.add('interior_designer');
      }
    }

    // Rank Up IRL - 10,000+ total trophies
    final totalAchievements = stats['totalAchievements'] as int;
    if (!unlocked.contains('rank_up_irl') && totalAchievements >= 10000) {
      await _unlockAchievement(userId, 'rank_up_irl');
      newlyUnlocked.add('rank_up_irl');
    }

    // Note: profile_pimp and showboat require features we haven't built yet
    // (custom avatar/banner uploads, and sharing/export functionality)

    return newlyUnlocked;
  }


  Future<List<String>> _checkTimeAchievements(
    String userId,
    Map<String, dynamic> stats,
    Set<String> unlocked,
  ) async {
    final newlyUnlocked = <String>[];

    // Check for time-based achievements using earned_at timestamps
    final trophies = await _client
        .from('user_trophies')
        .select('earned_at')
        .eq('user_id', userId)
        .not('earned_at', 'is', null)
        .order('earned_at', ascending: false)
        .limit(1000);

    for (final trophy in trophies) {
      final earnedAt = DateTime.parse(trophy['earned_at'] as String);
      final hour = earnedAt.hour;

      // Night Owl - between 2-4 AM
      if (!unlocked.contains('night_owl') && hour >= 2 && hour < 4) {
        await _unlockAchievement(userId, 'night_owl');
        newlyUnlocked.add('night_owl');
      }

      // Early Grind - before 7 AM
      if (!unlocked.contains('early_grind') && hour < 7) {
        await _unlockAchievement(userId, 'early_grind');
        newlyUnlocked.add('early_grind');
      }

      // New Year New Flex - first trophy of the year
      if (!unlocked.contains('new_year_new_flex') && 
          earnedAt.month == 1 && earnedAt.day == 1) {
        await _unlockAchievement(userId, 'new_year_new_flex');
        newlyUnlocked.add('new_year_new_flex');
      }
    }

    // TODO: Uncomment after running add_achievement_schema.sql migration
    // Birthday Buff - earned a trophy on your birthday
    // if (!unlocked.contains('birthday_buff')) {
    //   final profile = await _client
    //       .from('profiles')
    //       .select('birthday')
    //       .eq('id', userId)
    //       .single();
    //   
    //   final birthday = profile['birthday'] as String?;
    //   if (birthday != null) {
    //     final birthdayDate = DateTime.parse(birthday);
    //     
    //     for (final trophy in trophies) {
    //       final earnedAt = DateTime.parse(trophy['earned_at'] as String);
    //       if (earnedAt.month == birthdayDate.month && earnedAt.day == birthdayDate.day) {
    //         await _unlockAchievement(userId, 'birthday_buff');
    //         newlyUnlocked.add('birthday_buff');
    //         break;
    //       }
    //     }
    //   }
    // }

    // Note: speedrun_finish requires tracking platinum earn times

    return newlyUnlocked;
  }

  Future<List<String>> _checkStreakAchievements(
    String userId,
    Map<String, dynamic> stats,
    Set<String> unlocked,
  ) async {
    final newlyUnlocked = <String>[];

    // Get all trophy earn dates
    final trophies = await _client
        .from('user_trophies')
        .select('earned_at')
        .eq('user_id', userId)
        .not('earned_at', 'is', null)
        .order('earned_at', ascending: true);

    if (trophies.isEmpty) return newlyUnlocked;

    // Group by date (ignoring time)
    final earnDates = <DateTime>{};
    final earnCountsByDate = <String, int>{};
    
    for (final trophy in trophies) {
      final earnedAt = DateTime.parse(trophy['earned_at'] as String);
      final dateOnly = DateTime(earnedAt.year, earnedAt.month, earnedAt.day);
      earnDates.add(dateOnly);
      
      final dateKey = dateOnly.toIso8601String().substring(0, 10);
      earnCountsByDate[dateKey] = (earnCountsByDate[dateKey] ?? 0) + 1;
    }

    final sortedDates = earnDates.toList()..sort();

    // Check for consecutive day streaks
    int currentStreak = 1;
    int maxStreak = 1;
    
    for (int i = 1; i < sortedDates.length; i++) {
      final diff = sortedDates[i].difference(sortedDates[i - 1]).inDays;
      if (diff == 1) {
        currentStreak++;
        maxStreak = maxStreak > currentStreak ? maxStreak : currentStreak;
      } else {
        currentStreak = 1;
      }
    }

    // One Week Streak - 7 consecutive days
    if (!unlocked.contains('one_week_streak') && maxStreak >= 7) {
      await _unlockAchievement(userId, 'one_week_streak');
      newlyUnlocked.add('one_week_streak');
    }

    // Daily Grinder - 30 consecutive days
    if (!unlocked.contains('daily_grinder') && maxStreak >= 30) {
      await _unlockAchievement(userId, 'daily_grinder');
      newlyUnlocked.add('daily_grinder');
    }

    // No Days Off - 5+ trophies every day for 7 days
    int consecutiveHeavyDays = 0;
    int maxConsecutiveHeavyDays = 0;
    
    for (int i = 0; i < sortedDates.length; i++) {
      final dateKey = sortedDates[i].toIso8601String().substring(0, 10);
      final count = earnCountsByDate[dateKey] ?? 0;
      
      if (count >= 5) {
        consecutiveHeavyDays++;
        if (i > 0 && sortedDates[i].difference(sortedDates[i - 1]).inDays != 1) {
          consecutiveHeavyDays = 1;
        }
        maxConsecutiveHeavyDays = maxConsecutiveHeavyDays > consecutiveHeavyDays 
            ? maxConsecutiveHeavyDays : consecutiveHeavyDays;
      } else {
        consecutiveHeavyDays = 0;
      }
    }
    
    if (!unlocked.contains('no_days_off') && maxConsecutiveHeavyDays >= 7) {
      await _unlockAchievement(userId, 'no_days_off');
      newlyUnlocked.add('no_days_off');
    }

    // Touch Grass - 7 days without earning anything
    int maxGap = 0;
    for (int i = 1; i < sortedDates.length; i++) {
      final gap = sortedDates[i].difference(sortedDates[i - 1]).inDays;
      maxGap = maxGap > gap ? maxGap : gap;
    }
    
    if (!unlocked.contains('touch_grass') && maxGap >= 7) {
      await _unlockAchievement(userId, 'touch_grass');
      newlyUnlocked.add('touch_grass');
    }

    // Note: instant_gratification requires game session tracking
    // which we don't have yet

    return newlyUnlocked;
  }

  Future<void> _unlockAchievement(String userId, String achievementId) async {
    try {
      // Check if already unlocked to avoid unnecessary upserts
      final existing = await _client
          .from('user_meta_achievements')
          .select('achievement_id')
          .eq('user_id', userId)
          .eq('achievement_id', achievementId)
          .maybeSingle();
      
      if (existing != null) {
        return; // Already unlocked, skip
      }

      await _client.from('user_meta_achievements').insert({
        'user_id': userId,
        'achievement_id': achievementId,
        'unlocked_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Silently ignore conflicts - achievement already exists
    }
  }
}
