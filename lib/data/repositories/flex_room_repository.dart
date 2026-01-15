import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:statusxp/domain/flex_room_data.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository for fetching and managing user's Flex Room data
/// Handles featured achievements, superlative wall, and recent flexes
class FlexRoomRepository {
  final SupabaseClient _client;

  FlexRoomRepository(this._client);

  /// Calculate rarity band from rarity percentage
  String _getRarityBand(double? rarityPercent) {
    if (rarityPercent == null) return 'COMMON';
    if (rarityPercent < 1) return 'ULTRA_RARE';
    if (rarityPercent < 5) return 'VERY_RARE';
    if (rarityPercent < 15) return 'RARE';
    if (rarityPercent < 50) return 'UNCOMMON';
    return 'COMMON';
  }

  /// Calculate statusXP from rarity (matches database trigger logic)
  /// Returns the actual XP value (10-30) to match database base_status_xp column
  int _getStatusXP(double? rarityPercent) {
    if (rarityPercent == null) return 10; // COMMON: 10 XP
    
    // Match database trigger logic from 020_rarity_based_statusxp.sql
    if (rarityPercent <= 1.0) {
      return 30; // ULTRA_RARE: 30 XP
    } else if (rarityPercent <= 5.0) {
      return 23; // VERY_RARE: 23 XP
    } else if (rarityPercent <= 10.0) {
      return 18; // RARE: 18 XP
    } else if (rarityPercent <= 25.0) {
      return 13; // UNCOMMON: 13 XP
    } else {
      return 10; // COMMON: 10 XP
    }
  }

  /// Helper to convert achievement response to FlexTile with game data
  Future<FlexTile?> _buildFlexTile(Map<String, dynamic> userAchievementRow) async {
    try {
      final achievement = userAchievementRow['achievements'] as Map<String, dynamic>;
      final gameId = achievement['game_title_id'];
      final rarityPercent = achievement['rarity_global']?.toDouble();
      
      // Extract game data from nested response (no separate query needed)
      final gameData = achievement['game_titles'] as Map<String, dynamic>?;

      return FlexTile(
        achievementId: achievement['id'],
        achievementName: achievement['name'],
        gameName: gameData?['name'] ?? 'Unknown Game',
        gameId: gameId?.toString(),
        gameCoverUrl: gameData?['proxied_cover_url'] ?? gameData?['cover_url'],
        platform: achievement['platform'],
        rarityPercent: rarityPercent,
        rarityBand: _getRarityBand(rarityPercent),
        statusXP: _getStatusXP(rarityPercent),
        earnedAt: DateTime.parse(userAchievementRow['earned_at']),
        iconUrl: achievement['proxied_icon_url'] ?? achievement['icon_url'],
      );
    } catch (e) {
      return null;
    }
  }


  /// Get complete Flex Room data for a user
  Future<FlexRoomData?> getFlexRoomData(String userId) async {
    try {
      // First, try to fetch existing flex room configuration
      final response = await _client
          .from('flex_room_data')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
        // No flex room data exists yet, return default empty state
        // Load all tiles in parallel for speed
        final results = await Future.wait([
          _getRarestAchievement(userId),
          _getMostTimeSunkGame(userId),
          _getSweattiestPlatinum(userId),
          _getRecentNotableAchievements(userId),
        ]);
        
        return FlexRoomData(
          userId: userId,
          tagline: 'Completionist', // Default tagline
          lastUpdated: DateTime.now(),
          flexOfAllTime: null,
          rarestFlex: results[0] as FlexTile?,
          mostTimeSunk: results[1] as FlexTile?,
          sweattiestPlatinum: results[2] as FlexTile?,
          superlatives: {},
          recentFlexes: (results[3] as List).map((e) => RecentFlex.fromJson(e as Map<String, dynamic>)).toList(),
        );
      }

      // If flex room data exists, load the configured tiles
      final data = response;
      final featuredQueries = <Future>[];
      
      // Featured tiles queries
      featuredQueries.add(
        data['flex_of_all_time_id'] != null
            ? _getAchievementTile(data['flex_of_all_time_id'], userId)
            : Future.value(null)
      );
      
      featuredQueries.add(
        data['rarest_flex_id'] != null
            ? _getAchievementTile(data['rarest_flex_id'], userId)
            : _getRarestAchievement(userId)
      );
      
      featuredQueries.add(
        data['most_time_sunk_id'] != null
            ? _getAchievementTile(data['most_time_sunk_id'], userId)
            : _getMostTimeSunkGame(userId)
      );
      
      featuredQueries.add(
        data['sweatiest_platinum_id'] != null
            ? _getAchievementTile(data['sweatiest_platinum_id'], userId)
            : _getSweattiestPlatinum(userId)
      );

      // Add superlatives queries
      final superlativesJson = data['superlatives'] as Map<String, dynamic>? ?? {};
      final superlativeKeys = <String>[];
      
      for (final entry in superlativesJson.entries) {
        if (entry.value != null) {
          superlativeKeys.add(entry.key);
          featuredQueries.add(_getAchievementTile(entry.value as int, userId));
        }
      }

      // Add recent flexes query
      featuredQueries.add(_getRecentNotableAchievements(userId));

      // Execute all queries in parallel
      final results = await Future.wait(featuredQueries);
      
      // Extract results
      final flexOfAllTime = results[0] as FlexTile?;
      final rarestFlex = results[1] as FlexTile?;
      final mostTimeSunk = results[2] as FlexTile?;
      final sweattiestPlatinum = results[3] as FlexTile?;
      
      // Build superlatives map from remaining results
      final superlatives = <String, FlexTile>{};
      for (var i = 0; i < superlativeKeys.length; i++) {
        final tile = results[4 + i] as FlexTile?;
        if (tile != null) {
          superlatives[superlativeKeys[i]] = tile;
        }
      }
      
      final recentFlexes = results[4 + superlativeKeys.length] as List<RecentFlex>;

      return FlexRoomData(
        userId: userId,
        tagline: data['tagline'] ?? 'Completionist',
        lastUpdated: DateTime.parse(data['last_updated']),
        flexOfAllTime: flexOfAllTime,
        rarestFlex: rarestFlex,
        mostTimeSunk: mostTimeSunk,
        sweattiestPlatinum: sweattiestPlatinum,
        superlatives: superlatives,
        recentFlexes: recentFlexes,
      );
    } catch (e) {
      return null;
    }
  }

  /// Update or create flex room data
  Future<bool> updateFlexRoomData(FlexRoomData data) async {
    try {
      // Convert superlatives to JSONB format (category_id -> achievement_id)
      final superlativesJson = <String, int>{};
      for (final entry in data.superlatives.entries) {
        superlativesJson[entry.key] = entry.value.achievementId;
      }

      final payload = {
        'user_id': data.userId,
        'tagline': data.tagline,
        'last_updated': data.lastUpdated.toIso8601String(),
        'flex_of_all_time_id': data.flexOfAllTime?.achievementId,
        'rarest_flex_id': data.rarestFlex?.achievementId,
        'most_time_sunk_id': data.mostTimeSunk?.achievementId,
        'sweatiest_platinum_id': data.sweattiestPlatinum?.achievementId,
        'superlatives': superlativesJson,
      };
      await _client.from('flex_room_data').upsert(payload);
      print('✅ Flex Room data saved successfully for user: ${data.userId}');
      return true;
    } catch (e) {
      print('❌ Error saving flex room data: $e');
      return false;
    }
  }

  /// Get achievement tile details by ID
  Future<FlexTile?> _getAchievementTile(int achievementId, String userId) async {
    try {
      final response = await _client
          .from('user_achievements')
          .select('''
            id,
            achievement_id,
            user_id,
            earned_at,
            achievements!inner(
              id,
              name,
              description,
              platform,
              icon_url,
              proxied_icon_url,
              rarity_global,
              game_title_id,
              psn_trophy_type,
              game_titles!inner(
                id,
                name,
                cover_url,
                proxied_cover_url
              )
            )
          ''')
          .eq('achievement_id', achievementId)
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) return null;

      return await _buildFlexTile(response);
    } catch (e) {
      return null;
    }
  }

  /// Get user's rarest achievement (auto-suggestion)
  Future<FlexTile?> _getRarestAchievement(String userId) async {
    try {
      // Query from achievements table to enable sorting on rarity
      final response = await _client
          .from('achievements')
          .select('''
            id,
            name,
            description,
            platform,
            icon_url,
            proxied_icon_url,
            rarity_global,
            game_title_id,
            psn_trophy_type,
            game_titles!inner(
              id,
              name,
              cover_url,
              proxied_cover_url
            ),
            user_achievements!inner(
              id,
              user_id,
              earned_at
            )
          ''')
          .eq('user_achievements.user_id', userId)
          .not('rarity_global', 'is', null)
          .order('rarity_global', ascending: true)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;

      // Get game data from nested response (already joined)
      final gameData = response['game_titles'] as Map<String, dynamic>?;

      final userAchievement = (response['user_achievements'] as List).first as Map<String, dynamic>;
      final rarityPercent = response['rarity_global']?.toDouble();

      return FlexTile(
        achievementId: response['id'],
        achievementName: response['name'],
        gameName: gameData?['name'] ?? 'Unknown Game',
        gameId: response['game_title_id']?.toString(),
        gameCoverUrl: gameData?['proxied_cover_url'] ?? gameData?['cover_url'],
        platform: response['platform'],
        rarityPercent: rarityPercent,
        rarityBand: _getRarityBand(rarityPercent),
        statusXP: _getStatusXP(rarityPercent),
        earnedAt: DateTime.parse(userAchievement['earned_at']),
        iconUrl: response['proxied_icon_url'] ?? response['icon_url'],
      );
    } catch (e) {
      return null;
    }
  }

  /// Get game with most achievements (time-sunk)
  Future<FlexTile?> _getMostTimeSunkGame(String userId) async {
    try {
      // Find game with most achievements earned
      final gameResponse = await _client
          .rpc('get_most_time_sunk_game', params: {'p_user_id': userId})
          .maybeSingle();

      if (gameResponse == null) return null;

      final gameId = gameResponse['game_title_id'] as int;

      // Get a representative achievement from that game (preferably a platinum or 100%)
      final achievementResponse = await _client
          .from('user_achievements')
          .select('''
            id,
            achievement_id,
            user_id,
            earned_at,
            achievements!inner(
              id,
              name,
              description,
              platform,
              icon_url,
              rarity_global,
              game_title_id,
              psn_trophy_type
            )
          ''')
          .eq('user_id', userId)
          .eq('achievements.game_title_id', gameId)
          .limit(1)
          .maybeSingle();

      if (achievementResponse == null) return null;

      return await _buildFlexTile(achievementResponse);
    } catch (e) {
      return null;
    }
  }

  /// Get rarest platinum (sweatiest)
  Future<FlexTile?> _getSweattiestPlatinum(String userId) async {
    try {
      final response = await _client
          .from('achievements')
          .select('''
            id,
            name,
            description,
            platform,
            icon_url,
            proxied_icon_url,
            rarity_global,
            game_title_id,
            psn_trophy_type,
            game_titles!inner(
              id,
              name,
              cover_url,
              proxied_cover_url
            ),
            user_achievements!inner(
              id,
              user_id,
              earned_at
            )
          ''')
          .eq('user_achievements.user_id', userId)
          .eq('platform', 'psn')
          .eq('psn_trophy_type', 'platinum')
          .not('rarity_global', 'is', null)
          .order('rarity_global', ascending: true)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;

      // Get game data from nested response (already joined)
      final gameData = response['game_titles'] as Map<String, dynamic>?;

      final userAchievement = (response['user_achievements'] as List).first as Map<String, dynamic>;

      return FlexTile(
        achievementId: response['id'],
        achievementName: response['name'],
        gameName: gameData?['name'] ?? 'Unknown Game',
        gameId: response['game_title_id']?.toString(),
        gameCoverUrl: gameData?['proxied_cover_url'] ?? gameData?['cover_url'],
        platform: response['platform'],
        rarityPercent: response['rarity_global']?.toDouble(),
        rarityBand: _getRarityBand(response['rarity_global']?.toDouble()),
        statusXP: _getStatusXP(response['rarity_global']?.toDouble()),
        earnedAt: DateTime.parse(userAchievement['earned_at']),
        iconUrl: response['proxied_icon_url'] ?? response['icon_url'],
      );
    } catch (e) {
      return null;
    }
  }

  /// Get recent notable achievements (platinums, ultra-rares, 100% completions)
  Future<List<RecentFlex>> _getRecentNotableAchievements(String userId) async {
    try {
      final response = await _client
          .from('user_achievements')
          .select('''
            id,
            achievement_id,
            user_id,
            earned_at,
            achievements!inner(
              id,
              name,
              description,
              platform,
              icon_url,
              rarity_global,
              game_title_id,
              psn_trophy_type,
              game_titles!inner(
                id,
                name,
                cover_url
              )
            )
          ''')
          .eq('user_id', userId)
          .order('earned_at', ascending: false)
          .limit(20);

      final recentFlexes = <RecentFlex>[];

      for (final item in response as List) {
        final achievement = item['achievements'] as Map<String, dynamic>;
        final gameId = achievement['game_title_id'];
        final rarityPercent = achievement['rarity_global']?.toDouble() ?? 100.0;
        
        // Filter: only platinums or ultra-rares (< 5% rarity)
        final isPlatinum = achievement['psn_trophy_type'] == 'platinum';
        final isUltraRare = rarityPercent < 5.0;
        
        if (!isPlatinum && !isUltraRare) continue;
        
        // Stop when we have 5
        if (recentFlexes.length >= 5) break;
        
        // Get game data from nested response (already joined)
        final gameData = achievement['game_titles'] as Map<String, dynamic>?;

        // Determine flex type
        String type = 'ultra_rare';
        if (isPlatinum) {
          type = 'platinum';
        } else if (rarityPercent < 1.0) {
          type = 'ultra_rare';
        }

        recentFlexes.add(
          RecentFlex(
            gameName: gameData?['name'] ?? 'Unknown Game',
            achievementName: achievement['name'],
            platform: achievement['platform'],
            rarityPercent: rarityPercent,
            rarityBand: _getRarityBand(rarityPercent),
            earnedAt: DateTime.parse(item['earned_at']),
            type: type,
          ),
        );
      }

      return recentFlexes;
    } catch (e) {
      return [];
    }
  }

  /// Get smart suggestions for a specific superlative category
  Future<List<FlexTile>> getSmartSuggestions(
    String userId,
    String categoryId,
  ) async {
    try {
      // Different queries based on category
      switch (categoryId) {
        case 'hardest':
          return await _getSuggestionsByRarityAndXP(userId, maxRarity: 5.0);

        case 'easiest':
          return await _getSuggestionsByRarityAndXP(userId, minRarity: 80.0);

        case 'rng_nightmare':
          return await _getSuggestionsByRarityAndXP(userId, maxRarity: 1.0);

        case 'biggest_grind':
          // Games with most achievements
          return await _getSuggestionsByAchievementCount(userId);

        case 'most_time':
          // Same as biggest grind for now
          return await _getSuggestionsByAchievementCount(userId);

        default:
          // Generic rarity-based suggestions
          return await _getSuggestionsByRarityAndXP(userId, maxRarity: 10.0);
      }
    } catch (e) {
      return [];
    }
  }

  /// Get suggestions filtered by rarity and XP
  Future<List<FlexTile>> _getSuggestionsByRarityAndXP(
    String userId, {
    double? minRarity,
    double? maxRarity,
  }) async {
    try {
      var query = _client
          .from('achievements')
          .select('''
            id,
            name,
            description,
            platform,
            icon_url,
            rarity_global,
            game_title_id,
            psn_trophy_type,
            user_achievements!inner(
              id,
              user_id,
              earned_at
            )
          ''')
          .eq('user_achievements.user_id', userId)
          .not('rarity_global', 'is', null);

      if (minRarity != null) {
        query = query.gte('rarity_global', minRarity);
      }
      if (maxRarity != null) {
        query = query.lte('rarity_global', maxRarity);
      }

      final response = await query
          .order('rarity_global', ascending: true)
          .limit(5);

      final suggestions = <FlexTile>[];

      for (final item in response as List) {
        final achievementData = item as Map<String, dynamic>;
        
        // Get game data
        final gameData = await _client
            .from('game_titles')
            .select('name, cover_url, proxied_cover_url')
            .eq('id', achievementData['game_title_id'])
            .maybeSingle();

        final userAchievement = (achievementData['user_achievements'] as List).first as Map<String, dynamic>;

        suggestions.add(
          FlexTile(
            achievementId: achievementData['id'],
            achievementName: achievementData['name'],
            gameName: gameData?['name'] ?? 'Unknown Game',
            gameId: achievementData['game_title_id']?.toString(),
            gameCoverUrl: gameData?['proxied_cover_url'] ?? gameData?['cover_url'],
            platform: achievementData['platform'],
            rarityPercent: achievementData['rarity_global']?.toDouble(),
            rarityBand: _getRarityBand(achievementData['rarity_global']?.toDouble()),
            statusXP: _getStatusXP(achievementData['rarity_global']?.toDouble()),
            earnedAt: DateTime.parse(userAchievement['earned_at']),
            iconUrl: achievementData['icon_url'],
          ),
        );
      }

      return suggestions;
    } catch (e) {
      return [];
    }
  }

  /// Get suggestions for games with most achievements
  Future<List<FlexTile>> _getSuggestionsByAchievementCount(
    String userId,
  ) async {
    try {
      // This requires a custom RPC function - for now return rarity-based
      return await _getSuggestionsByRarityAndXP(userId, maxRarity: 10.0);
    } catch (e) {
      return [];
    }
  }

  /// Get all user achievements with optional filters
  Future<List<FlexTile>> getAllAchievements(
    String userId, {
    String? searchQuery,
    String? platformFilter,
  }) async {
    try {
      var query = _client
          .from('user_achievements')
          .select('''
            id,
            achievement_id,
            user_id,
            earned_at,
            achievements!inner(
              id,
              name,
              description,
              platform,
              icon_url,
              rarity_global,
              game_title_id,
              psn_trophy_type
            )
          ''')
          .eq('user_id', userId);

      // Apply platform filter if specified
      if (platformFilter != null && platformFilter.isNotEmpty) {
        query = query.eq('achievements.platform', platformFilter);
      }

      // Order by earned date (most recent first), limit to 50 for performance
      final response = await query
          .order('earned_at', ascending: false)
          .limit(50);

      final achievements = <FlexTile>[];

      for (final item in response as List) {
        final tile = await _buildFlexTile(item);
        if (tile != null) {
          achievements.add(tile);
        }
      }

      return achievements;
    } catch (e) {
      return [];
    }
  }

  /// Get all games for a specific platform that the user has achievements for
  Future<List<Map<String, dynamic>>> getGamesForPlatform(
    String userId,
    String platform, {
    String? searchQuery,
  }) async {
    try {
      // Use exact same query as unified_games_repository
      final response = await _client
          .from('user_games')
          .select('''
            id,
            game_title_id,
            total_trophies,
            earned_trophies,
            xbox_total_achievements,
            xbox_achievements_earned,
            game_titles!inner(
              id,
              name,
              cover_url
            ),
            platforms(code)
          ''')
          .eq('user_id', userId);

      final List<dynamic> data = response as List;
      if (data.isEmpty) {
        return [];
      }

      // Filter by platform and build game list
      final Map<String, Map<String, dynamic>> gamesMap = {};
      
      for (final row in data) {
        final platformData = row['platforms'] as Map<String, dynamic>?;
        final platformCode = (platformData?['code'] as String? ?? '').toLowerCase();
        // Check if this matches the requested platform
        bool matchesPlatform = false;
        switch (platform.toLowerCase()) {
          case 'psn':
          case 'playstation':
            matchesPlatform = platformCode.contains('ps') || platformCode == 'vita';
            break;
          case 'xbox':
            matchesPlatform = platformCode.contains('xbox');
            break;
          case 'steam':
            matchesPlatform = platformCode == 'steam';
            break;
        }
        if (!matchesPlatform) continue;
        
        final gameTitle = row['game_titles'] as Map<String, dynamic>?;
        if (gameTitle == null) continue;
        
        final gameId = gameTitle['id'].toString();
        final gameName = gameTitle['name'] as String;
        
        // Apply search filter
        if (searchQuery != null && !gameName.toLowerCase().contains(searchQuery.toLowerCase())) {
          continue;
        }

        // Get achievement count
        int totalAchievements = row['total_trophies'] as int? ?? 0;
        if (totalAchievements == 0 && platformCode.contains('xbox')) {
          totalAchievements = row['xbox_total_achievements'] as int? ?? 0;
        }

        // Use unique key combining game_title_id and platform_id
        final uniqueKey = '${gameId}_${row['id']}';
        
        if (!gamesMap.containsKey(uniqueKey)) {
          gamesMap[uniqueKey] = {
            'game_id': gameId,
            'game_name': gameName,
            'game_cover_url': gameTitle['cover_url'],
            'achievement_count': totalAchievements,
          };
        }
      }
      // Convert to list and sort by game name
      final games = gamesMap.values.toList();
      games.sort((a, b) => 
          (a['game_name'] as String).compareTo(b['game_name'] as String));

      return games;
    } catch (e) {
      return [];
    }
  }

  /// Get all achievements for a specific game
  Future<List<FlexTile>> getAchievementsForGame(
    String userId,
    String? gameId,
    String platform, {
    String? searchQuery,
  }) async {
    try {
      // Map platform codes to achievement platform identifiers (same as GameAchievementsScreen)
      String achievementPlatform;
      if (platform.toUpperCase().startsWith('PS') || platform.toLowerCase() == 'psn' || platform.toLowerCase() == 'playstation') {
        achievementPlatform = 'psn';
      } else if (platform.toUpperCase().startsWith('XBOX') || platform.toLowerCase() == 'xbox') {
        achievementPlatform = 'xbox';
      } else if (platform.toUpperCase().startsWith('STEAM') || platform.toLowerCase() == 'steam') {
        achievementPlatform = 'steam';
      } else {
        achievementPlatform = platform.toLowerCase();
      }
      if (gameId == null) {
        return [];
      }

      // Get achievements from the achievements table
      final achievementsResponse = await _client
          .from('achievements')
          .select('''
            id,
            name,
            description,
            icon_url,
            proxied_icon_url,
            rarity_global,
            rarity_band,
            base_status_xp,
            psn_trophy_type,
            xbox_gamerscore,
            is_platinum,
            is_dlc,
            dlc_name,
            game_title_id
          ''')
          .eq('game_title_id', gameId)
          .eq('platform', achievementPlatform)
          .order('is_platinum', ascending: false)
          .order('psn_trophy_type', ascending: true, nullsFirst: false)
          .order('id', ascending: true);

      print('📊 Found ${(achievementsResponse as List).length} achievements');

      // Get user's earned achievements FOR THIS GAME ONLY
      final achievementIds = (achievementsResponse as List)
          .map((a) => a['id'] as int)
          .toList();
      
      final userAchievementsResponse = await _client
          .from('user_achievements')
          .select('achievement_id, earned_at')
          .eq('user_id', userId)
          .inFilter('achievement_id', achievementIds);

      print('🏆 User has earned ${(userAchievementsResponse as List).length} of these achievements');

      final earnedAchievementIds = <int>{};
      final Map<int, DateTime> earnedDates = {};
      
      for (final ua in userAchievementsResponse as List) {
        final achId = ua['achievement_id'] as int;
        earnedAchievementIds.add(achId);
        if (ua['earned_at'] != null) {
          earnedDates[achId] = DateTime.parse(ua['earned_at'] as String);
        }
      }

      // Get game details for cover image
      final gameResponse = await _client
          .from('game_titles')
          .select('name, cover_url, proxied_cover_url')
          .eq('id', gameId)
          .single();

      final gameName = gameResponse['name'] as String;
      final gameCoverUrl = (gameResponse['proxied_cover_url'] ?? gameResponse['cover_url']) as String?;

      final achievements = <FlexTile>[];

      for (final achievement in achievementsResponse) {
        final achId = achievement['id'] as int;
        final achName = achievement['name'] as String;
        
        // Apply search filter
        if (searchQuery != null && !achName.toLowerCase().contains(searchQuery.toLowerCase())) {
          continue;
        }

        // Only include earned achievements
        if (!earnedAchievementIds.contains(achId)) {
          continue;
        }

        final tile = FlexTile(
          achievementId: achId,
          achievementName: achName,
          gameName: gameName,
          gameId: gameId,
          gameCoverUrl: gameCoverUrl,
          platform: achievementPlatform,
          rarityPercent: (achievement['rarity_global'] as num?)?.toDouble(),
          rarityBand: achievement['rarity_band'] as String?,
          statusXP: achievement['base_status_xp'] != null 
              ? (achievement['base_status_xp'] as num).round() // Database stores 10-30 directly
              : _getStatusXP((achievement['rarity_global'] as num?)?.toDouble()),
          earnedAt: earnedDates[achId],
          iconUrl: achievement['icon_url'] as String?,
        );

        achievements.add(tile);
      }
      return achievements;
    } catch (e) {
      return [];
    }
  }
}

// Providers
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final flexRoomRepositoryProvider = Provider<FlexRoomRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return FlexRoomRepository(client);
});

final flexRoomDataProvider = FutureProvider.family<FlexRoomData?, String>((
  ref,
  userId,
) async {
  final repository = ref.watch(flexRoomRepositoryProvider);
  return await repository.getFlexRoomData(userId);
});
