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

  /// Helper to convert RPC response to FlexTile with game data already included
  Future<FlexTile?> _buildFlexTile(Map<String, dynamic> rpcRow) async {
    try {
      final platformId = rpcRow['platform_id'] as int?;
      final platformGameId = rpcRow['platform_game_id'] as String?;
      final platformAchievementId = rpcRow['platform_achievement_id'] as String?;
      
      if (platformId == null || platformGameId == null || platformAchievementId == null) {
        return null;
      }

      final rarityPercent = (rpcRow['rarity_global'] as num?)?.toDouble();

      // Get platform code from platform_id
      String platform;
      if (platformId == 1 || platformId == 2 || platformId == 5 || platformId == 9) {
        platform = 'psn'; // PS5=1, PS4=2, PS3=5, Vita=9
      } else if (platformId == 4) {
        platform = 'steam';
      } else if (platformId >= 10 && platformId <= 12) {
        platform = 'xbox';
      } else {
        platform = 'unknown';
      }

      return FlexTile(
        achievementId: 0, // Legacy field, not used in V2
        achievementName: rpcRow['achievement_name'] ?? 'Unknown Achievement',
        gameName: rpcRow['game_name'] ?? 'Unknown Game',
        gameId: platformGameId,
        platformId: platformId,
        platformGameId: platformGameId,
        platformAchievementId: platformAchievementId,
        gameCoverUrl: rpcRow['game_cover_url'],
        platform: platform,
        rarityPercent: rarityPercent,
        rarityBand: _getRarityBand(rarityPercent),
        statusXP: _getStatusXP(rarityPercent),
        earnedAt: DateTime.parse(rpcRow['earned_at']),
        iconUrl: rpcRow['achievement_icon_url'],
      );
    } catch (e) {
      return null;
    }
  }

  /// Helper to build FlexTile from user_achievement row (requires additional queries)
  Future<FlexTile?> _buildFlexTileFromUserAchievement(Map<String, dynamic> userAchievementRow) async {
    try {
      final platformId = userAchievementRow['platform_id'] as int?;
      final platformGameId = userAchievementRow['platform_game_id'] as String?;
      final platformAchievementId = userAchievementRow['platform_achievement_id'] as String?;
      
      if (platformId == null || platformGameId == null || platformAchievementId == null) {
        return null;
      }

      // Query achievement data using V2 composite keys
      final achievementResponse = await _client
          .from('achievements')
          .select('name, icon_url, rarity_global, metadata')
          .eq('platform_id', platformId)
          .eq('platform_game_id', platformGameId)
          .eq('platform_achievement_id', platformAchievementId)
          .maybeSingle();

      if (achievementResponse == null) return null;

      // Query game data using V2 composite keys
      final gameResponse = await _client
          .from('games')
          .select('name, cover_url')
          .eq('platform_id', platformId)
          .eq('platform_game_id', platformGameId)
          .maybeSingle();

      final rarityPercent = (achievementResponse['rarity_global'] as num?)?.toDouble();

      // Get platform code from platform_id
      String platform;
      if (platformId == 1 || platformId == 2 || platformId == 5 || platformId == 9) {
        platform = 'psn'; // PS5=1, PS4=2, PS3=5, Vita=9
      } else if (platformId == 4) {
        platform = 'steam';
      } else if (platformId >= 10 && platformId <= 12) {
        platform = 'xbox';
      } else {
        platform = 'unknown';
      }

      return FlexTile(
        achievementId: 0, // Legacy field, not used in V2
        achievementName: achievementResponse['name'],
        gameName: gameResponse?['name'] ?? 'Unknown Game',
        gameId: platformGameId,
        platformId: platformId,
        platformGameId: platformGameId,
        platformAchievementId: platformAchievementId,
        gameCoverUrl: gameResponse?['cover_url'],
        platform: platform,
        rarityPercent: rarityPercent,
        rarityBand: _getRarityBand(rarityPercent),
        statusXP: _getStatusXP(rarityPercent),
        earnedAt: DateTime.parse(userAchievementRow['earned_at']),
        iconUrl: achievementResponse['icon_url'],
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
          .eq('profile_id', userId) // Use profile_id (profiles.id == auth.users.id)
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
          recentFlexes: (results[3] as List?)?.cast<RecentFlex>() ?? [],
        );
      }

      // If flex room data exists, load the configured tiles
      final data = response;
      final featuredQueries = <Future>[];
      
      // Featured tiles queries using composite keys
      featuredQueries.add(
        data['flex_of_all_time_platform_id'] != null &&
        data['flex_of_all_time_platform_game_id'] != null &&
        data['flex_of_all_time_platform_achievement_id'] != null
            ? _getAchievementTileV2(
                data['flex_of_all_time_platform_id'],
                data['flex_of_all_time_platform_game_id'],
                data['flex_of_all_time_platform_achievement_id'],
                userId)
            : Future.value(null)
      );
      
      featuredQueries.add(
        data['rarest_flex_platform_id'] != null &&
        data['rarest_flex_platform_game_id'] != null &&
        data['rarest_flex_platform_achievement_id'] != null
            ? _getAchievementTileV2(
                data['rarest_flex_platform_id'],
                data['rarest_flex_platform_game_id'],
                data['rarest_flex_platform_achievement_id'],
                userId)
            : _getRarestAchievement(userId)
      );
      
      featuredQueries.add(
        data['most_time_sunk_platform_id'] != null &&
        data['most_time_sunk_platform_game_id'] != null &&
        data['most_time_sunk_platform_achievement_id'] != null
            ? _getAchievementTileV2(
                data['most_time_sunk_platform_id'],
                data['most_time_sunk_platform_game_id'],
                data['most_time_sunk_platform_achievement_id'],
                userId)
            : _getMostTimeSunkGame(userId)
      );
      
      featuredQueries.add(
        data['sweatiest_platinum_platform_id'] != null &&
        data['sweatiest_platinum_platform_game_id'] != null &&
        data['sweatiest_platinum_platform_achievement_id'] != null
            ? _getAchievementTileV2(
                data['sweatiest_platinum_platform_id'],
                data['sweatiest_platinum_platform_game_id'],
                data['sweatiest_platinum_platform_achievement_id'],
                userId)
            : _getSweattiestPlatinum(userId)
      );

      // Add superlatives queries using composite keys
      final superlativesJson = data['superlatives'] as Map<String, dynamic>? ?? {};
      final superlativeKeys = <String>[];
      
      for (final entry in superlativesJson.entries) {
        if (entry.value != null && entry.value is Map) {
          final compositeKey = entry.value as Map<String, dynamic>;
          superlativeKeys.add(entry.key);
          featuredQueries.add(_getAchievementTileV2(
            compositeKey['platform_id'],
            compositeKey['platform_game_id'],
            compositeKey['platform_achievement_id'],
            userId));
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
      var superlatives = <String, FlexTile>{};
      for (var i = 0; i < superlativeKeys.length; i++) {
        final tile = results[4 + i] as FlexTile?;
        if (tile != null) {
          superlatives[superlativeKeys[i]] = tile;
        }
      }
      
      // Auto-fill superlatives if empty or has fewer than 3
      if (superlatives.length < 3) {
        print('🎯 Superlatives mostly empty, auto-filling...');
        final autoFilled = await autofillSuperlatives(userId);
        if (autoFilled.isNotEmpty) {
          // Merge auto-filled with existing (keep existing ones)
          superlatives = {...autoFilled, ...superlatives};
          
          // Save the auto-filled superlatives to database
          final dataToSave = FlexRoomData(
            userId: userId,
            tagline: data['tagline'] ?? 'Completionist',
            lastUpdated: DateTime.now(),
            flexOfAllTime: results[0] as FlexTile?,
            rarestFlex: results[1] as FlexTile?,
            mostTimeSunk: results[2] as FlexTile?,
            sweattiestPlatinum: results[3] as FlexTile?,
            superlatives: superlatives,
            recentFlexes: const [],
          );
          
          // Save asynchronously (don't wait)
          updateFlexRoomData(dataToSave).catchError((e) {
            print('⚠️ Failed to save auto-filled superlatives: $e');
          });
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
    } catch (e, stackTrace) {
      print('❌ Flex Room Error: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Update or create flex room data
  Future<bool> updateFlexRoomData(FlexRoomData data) async {
    try {
      // Convert superlatives to JSONB format with composite keys
      final superlativesJson = <String, Map<String, dynamic>>{};
      for (final entry in data.superlatives.entries) {
        superlativesJson[entry.key] = {
          'platform_id': entry.value.platformId,
          'platform_game_id': entry.value.platformGameId,
          'platform_achievement_id': entry.value.platformAchievementId,
        };
      }

      final payload = {
        'user_id': data.userId, // Primary key (deprecated but still required)
        'profile_id': data.userId, // New column (profiles.id == auth.users.id)
        'tagline': data.tagline,
        'last_updated': data.lastUpdated.toIso8601String(),
        
        // Flex of all time
        'flex_of_all_time_platform_id': data.flexOfAllTime?.platformId,
        'flex_of_all_time_platform_game_id': data.flexOfAllTime?.platformGameId,
        'flex_of_all_time_platform_achievement_id': data.flexOfAllTime?.platformAchievementId,
        
        // Rarest flex
        'rarest_flex_platform_id': data.rarestFlex?.platformId,
        'rarest_flex_platform_game_id': data.rarestFlex?.platformGameId,
        'rarest_flex_platform_achievement_id': data.rarestFlex?.platformAchievementId,
        
        // Most time sunk
        'most_time_sunk_platform_id': data.mostTimeSunk?.platformId,
        'most_time_sunk_platform_game_id': data.mostTimeSunk?.platformGameId,
        'most_time_sunk_platform_achievement_id': data.mostTimeSunk?.platformAchievementId,
        
        // Sweatiest platinum
        'sweatiest_platinum_platform_id': data.sweattiestPlatinum?.platformId,
        'sweatiest_platinum_platform_game_id': data.sweattiestPlatinum?.platformGameId,
        'sweatiest_platinum_platform_achievement_id': data.sweattiestPlatinum?.platformAchievementId,
        
        'superlatives': superlativesJson,
      };
      
      print('💾 Saving flex room with composite keys:');
      print('  - userId: ${data.userId}');
      print('  - flexOfAllTime: ${data.flexOfAllTime?.platformId}/${data.flexOfAllTime?.platformGameId}/${data.flexOfAllTime?.platformAchievementId}');
      print('  - payload: $payload');
      
      await _client.from('flex_room_data').upsert(
        payload,
        onConflict: 'user_id', // Specify primary key for conflict resolution
      );
      
      // Verify the save by fetching it back
      final verify = await _client
          .from('flex_room_data')
          .select()
          .eq('user_id', data.userId)
          .maybeSingle();
      
      print('✅ Flex Room data saved successfully for user: ${data.userId}');
      print('📋 Verification: ${verify != null ? "Found saved data" : "WARNING: Data not found after save!"}');
      return true;
    } catch (e, stackTrace) {
      print('❌ Error saving flex room data: $e');
      print('Stack trace: $stackTrace');
      return false;
    }
  }

  /// Get achievement tile details by composite key (V2)
  Future<FlexTile?> _getAchievementTileV2(int platformId, String platformGameId, String platformAchievementId, String userId) async {
    try {
      final response = await _client
          .from('user_achievements')
          .select('user_id, platform_id, platform_game_id, platform_achievement_id, earned_at')
          .eq('platform_id', platformId)
          .eq('platform_game_id', platformGameId)
          .eq('platform_achievement_id', platformAchievementId)
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) return null;

      return await _buildFlexTileFromUserAchievement(response);
    } catch (e) {
      return null;
    }
  }

  /// DEPRECATED: Get achievement tile by V1 achievement_id (for backwards compatibility with saved flex_room_data)
  /// This is only used when loading saved flex room configurations that still reference V1 achievement_id
  Future<FlexTile?> _getAchievementTile(int achievementId, String userId) async {
    // For now, return null - saved flex room data will need to be regenerated
    // TODO: Either migrate flex_room_data table to V2 composite keys or implement V1->V2 lookup
    return null;
  }

  /// Get user's rarest achievement (auto-suggestion)
  Future<FlexTile?> _getRarestAchievement(String userId) async {
    try {
      final response = await _client
          .rpc('get_rarest_achievement_v2', params: {'p_user_id': userId})
          .maybeSingle();

      if (response == null) return null;

      // RPC returns complete data with JOINs - use it directly
      return _buildFlexTile(response);
    } catch (e) {
      return null;
    }
  }

  /// Get game with most achievements (time-sunk)
  Future<FlexTile?> _getMostTimeSunkGame(String userId) async {
    try {
      final response = await _client
          .rpc('get_most_time_sunk_game_v2', params: {'p_user_id': userId})
          .maybeSingle();

      if (response == null) return null;

      // RPC now returns complete achievement and game data with JOINs
      return _buildFlexTile(response);
    } catch (e) {
      return null;
    }
  }

  /// Get rarest platinum (sweatiest)
  Future<FlexTile?> _getSweattiestPlatinum(String userId) async {
    try {
      final response = await _client
          .rpc('get_sweatiest_platinum_v2', params: {'p_user_id': userId})
          .maybeSingle();

      if (response == null) return null;

      // RPC returns complete data with JOINs - use it directly
      return _buildFlexTile(response);
    } catch (e) {
      return null;
    }
  }

  /// Get recent notable achievements (platinums, ultra-rares, 100% completions)
  Future<List<RecentFlex>> _getRecentNotableAchievements(String userId) async {
    try {
      final response = await _client
          .rpc('get_recent_notable_achievements_v2', params: {
            'p_user_id': userId,
            'p_limit': 5
          });

      final recentFlexes = <RecentFlex>[];

      for (final item in response as List) {
        final platformId = item['platform_id'] as int;
        final rarityPercent = (item['rarity_global'] as num?)?.toDouble() ?? 100.0;
        final isPlatinum = item['is_platinum'] as bool? ?? false;

        // Determine flex type
        String type = 'ultra_rare';
        if (isPlatinum) {
          type = 'platinum';
        } else if (rarityPercent < 1.0) {
          type = 'ultra_rare';
        }

        // Get platform code from platform_id
        String platform;
        if (platformId == 1 || platformId == 2 || platformId == 5 || platformId == 9) {
          platform = 'psn'; // PS5=1, PS4=2, PS3=5, Vita=9
        } else if (platformId == 4) {
          platform = 'steam';
        } else if (platformId >= 10 && platformId <= 12) {
          platform = 'xbox';
        } else {
          platform = 'unknown';
        }

        recentFlexes.add(
          RecentFlex(
            gameName: item['game_name'] ?? 'Unknown Game',
            achievementName: item['achievement_name'] ?? 'Unknown Achievement',
            platform: platform,
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
      final query = _client
          .from('user_achievements')
          .select('user_id, platform_id, platform_game_id, platform_achievement_id, earned_at')
          .eq('user_id', userId);

      // Note: We'll need to filter by rarity in a separate query or join
      // For now, get all and filter client-side (not ideal, but works)
      final response = await query
          .order('earned_at', ascending: false)
          .limit(50);

      final suggestions = <FlexTile>[];

      for (final item in response as List) {
        final tile = await _buildFlexTileFromUserAchievement(item);
        if (tile != null) {
          final rarity = tile.rarityPercent;
          if (rarity != null) {
            final passesMin = minRarity == null || rarity >= minRarity;
            final passesMax = maxRarity == null || rarity <= maxRarity;
            if (passesMin && passesMax) {
              suggestions.add(tile);
              if (suggestions.length >= 5) break;
            }
          }
        }
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

  /// Auto-fill superlatives with smart suggestions
  Future<Map<String, FlexTile>> autofillSuperlatives(String userId) async {
    try {
      print('🤖 Auto-filling superlatives for user $userId');
      final superlatives = <String, FlexTile>{};
      
      // Get suggestions for each category in parallel
      final categories = [
        'hardest',
        'easiest',
        'aggravating',
        'rage_inducing',
        'biggest_grind',
        'most_time',
        'rng_nightmare',
        'never_again',
        'most_proud',
        'clutch',
        'cozy_comfort',
        'hidden_gem',
      ];
      
      final futures = categories.map((category) async {
        try {
          final response = await _client
              .rpc('get_superlative_suggestions_v3', params: {
            'p_user_id': userId,
            'p_category': category,
          });
          
          if (response != null && response is List && response.isNotEmpty) {
            final result = response.first;
            final tile = await _getAchievementTileV2(
              result['platform_id'],
              result['platform_game_id'],
              result['platform_achievement_id'],
              userId,
            );
            return MapEntry(category, tile);
          }
          return null;
        } catch (e) {
          print('⚠️ Failed to get suggestion for $category: $e');
          return null;
        }
      });
      
      final results = await Future.wait(futures);
      
      for (final entry in results) {
        if (entry != null && entry.value != null) {
          superlatives[entry.key] = entry.value!;
        }
      }
      
      print('✅ Auto-filled ${superlatives.length} superlatives');
      return superlatives;
    } catch (e) {
      print('❌ Error auto-filling superlatives: $e');
      return {};
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
          .select('user_id, platform_id, platform_game_id, platform_achievement_id, earned_at')
          .eq('user_id', userId);

      // Apply platform filter if specified
      if (platformFilter != null && platformFilter.isNotEmpty) {
        // Map platform code to platform_id
        int? targetPlatformId;
        if (platformFilter == 'psn') {
          targetPlatformId = 1;
        } else if (platformFilter == 'steam') targetPlatformId = 5;
        else if (platformFilter == 'xbox') targetPlatformId = 10; // or 11, 12 for Xbox One, Series
        
        if (targetPlatformId != null) {
          query = query.eq('platform_id', targetPlatformId);
        }
      }

      // Order by earned date (most recent first), limit to 50 for performance
      final response = await query
          .order('earned_at', ascending: false)
          .limit(50);

      final achievements = <FlexTile>[];

      for (final item in response as List) {
        final tile = await _buildFlexTileFromUserAchievement(item);
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
      // Map platform name to platform_id
      int? targetPlatformId;
      switch (platform.toLowerCase()) {
        case 'psn':
        case 'playstation':
          targetPlatformId = 1;
          break;
        case 'steam':
          targetPlatformId = 5;
          break;
        case 'xbox':
          targetPlatformId = 10;
          break;
      }

      if (targetPlatformId == null) {
        return [];
      }

      // Single efficient query with JOIN and aggregation
      final response = await _client
          .rpc('get_user_games_for_platform', params: {
            'p_user_id': userId,
            'p_platform_id': targetPlatformId,
            'p_search_query': searchQuery
          });

      final games = <Map<String, dynamic>>[];
      for (final row in response as List) {
        games.add({
          'platform_id': row['platform_id'],
          'platform_game_id': row['platform_game_id'],
          'game_id': row['platform_game_id'],
          'game_name': row['game_name'],
          'game_cover_url': row['cover_url'],
          'achievement_count': row['achievement_count'],
        });
      }

      return games;
    } catch (e) {
      print('❌ Error in getGamesForPlatform: $e');
      return [];
    }
  }

  /// Get all achievements for a specific game (V2 with composite keys)
  Future<List<FlexTile>> getAchievementsForGame(
    String userId,
    String? gameId,
    String platform, {
    String? searchQuery,
    int? platformId,
    String? platformGameId,
  }) async {
    try {
      // Map platform name to platform_id
      int? targetPlatformId = platformId;
      final String? targetGameId = platformGameId ?? gameId;

      if (targetPlatformId == null) {
        switch (platform.toLowerCase()) {
          case 'psn':
          case 'playstation':
            targetPlatformId = 1;
            break;
          case 'steam':
            targetPlatformId = 5;
            break;
          case 'xbox':
            targetPlatformId = 10;
            break;
        }
      }

      if (targetPlatformId == null || targetGameId == null) {
        return [];
      }

      // Single efficient query with JOIN
      final response = await _client
          .rpc('get_user_achievements_for_game', params: {
            'p_user_id': userId,
            'p_platform_id': targetPlatformId,
            'p_platform_game_id': targetGameId,
            'p_search_query': searchQuery
          });

      final achievements = <FlexTile>[];
      
      // Get platform code from platform_id
      String platformCode;
      if (targetPlatformId == 1 || targetPlatformId == 2 || targetPlatformId == 5 || targetPlatformId == 9) {
        platformCode = 'psn'; // PS5=1, PS4=2, PS3=5, Vita=9
      } else if (targetPlatformId == 4) {
        platformCode = 'steam';
      } else if (targetPlatformId >= 10 && targetPlatformId <= 12) {
        platformCode = 'xbox';
      } else {
        platformCode = 'unknown';
      }

      for (final row in response as List) {
        final rarityPercent = (row['rarity_global'] as num?)?.toDouble();
        
        final tile = FlexTile(
          achievementId: 0,
          achievementName: row['achievement_name'],
          gameName: row['game_name'],
          gameId: targetGameId,
          platformId: targetPlatformId,
          platformGameId: targetGameId,
          platformAchievementId: row['platform_achievement_id'],
          gameCoverUrl: row['cover_url'],
          platform: platformCode,
          rarityPercent: rarityPercent,
          rarityBand: _getRarityBand(rarityPercent),
          statusXP: _getStatusXP(rarityPercent),
          earnedAt: row['earned_at'] != null ? DateTime.parse(row['earned_at']) : null,
          iconUrl: row['icon_url'],
        );

        achievements.add(tile);
      }

      return achievements;
    } catch (e) {
      print('❌ Error in getAchievementsForGame: $e');
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
