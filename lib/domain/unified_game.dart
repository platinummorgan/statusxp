import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

/// Represents a game that may exist across multiple platforms
/// 
/// Groups platform-specific game data under one title for unified display
@immutable
class UnifiedGame extends Equatable {
  /// Game title (normalized across platforms)
  final String title;
  
  /// Cover/icon URL (from any platform, preferring highest quality)
  final String? coverUrl;
  
  /// List of platforms this game is owned on
  final List<PlatformGameData> platforms;
  
  /// Total completion across all platforms (average %)
  final double overallCompletion;
  
  const UnifiedGame({
    required this.title,
    this.coverUrl,
    required this.platforms,
    required this.overallCompletion,
  });
  
  /// Check if game is owned on a specific platform
  bool isOnPlatform(String platform) {
    final searchPlatform = platform.toLowerCase();
    return platforms.any((p) {
      final platformCode = p.platform.toLowerCase();
      // Flexible matching for platform families
      if (searchPlatform == 'playstation') {
        return platformCode.contains('ps') || platformCode == 'playstation';
      } else if (searchPlatform == 'xbox') {
        return platformCode.contains('xbox');
      } else if (searchPlatform == 'steam') {
        return platformCode == 'steam' || platformCode.contains('steam');
      }
      return platformCode == searchPlatform;
    });
  }
  
  /// Get data for a specific platform
  PlatformGameData? getPlatformData(String platform) {
    try {
      return platforms.firstWhere((p) => p.platform == platform);
    } catch (e) {
      return null;
    }
  }
  
  /// Get total StatusXP across all platforms for this game
  int getTotalStatusXP() {
    return platforms.fold<int>(0, (sum, p) => sum + p.statusXP);
  }
  
  /// Get most recent last played timestamp across all platforms
  DateTime? getMostRecentPlayTime() {
    DateTime? mostRecent;
    for (final platform in platforms) {
      if (platform.lastPlayedAt != null) {
        if (mostRecent == null || platform.lastPlayedAt!.isAfter(mostRecent)) {
          mostRecent = platform.lastPlayedAt;
        }
      }
    }
    return mostRecent;
  }
  
  /// Get most recent trophy earned timestamp across all platforms
  DateTime? getMostRecentTrophyTime() {
    DateTime? mostRecent;
    for (final platform in platforms) {
      if (platform.lastTrophyEarnedAt != null) {
        if (mostRecent == null || platform.lastTrophyEarnedAt!.isAfter(mostRecent)) {
          mostRecent = platform.lastTrophyEarnedAt;
        }
      }
    }
    return mostRecent;
  }
  
  /// Get the rarest achievement rarity across all platforms
  /// Returns the lowest rarity percentage (rarest achievement)
  double? getRarestAchievementRarity() {
    double? rarest;
    for (final platform in platforms) {
      if (platform.rarestAchievementRarity != null) {
        if (rarest == null || platform.rarestAchievementRarity! < rarest) {
          rarest = platform.rarestAchievementRarity;
        }
      }
    }
    return rarest;
  }
  
  @override
  List<Object?> get props => [title, coverUrl, platforms, overallCompletion];
}

/// Platform-specific game data
@immutable
class PlatformGameData extends Equatable {
  /// Platform identifier ('psn', 'xbox', 'steam')
  final String platform;
  
  /// Game ID for this platform (V1 compatibility - same as platform_game_id)
  final String gameId;
  
  /// Platform ID (V2 schema)
  final int? platformId;
  
  /// Platform game ID (V2 schema)
  final String? platformGameId;
  
  /// Achievements/trophies earned
  final int achievementsEarned;
  
  /// Total achievements/trophies
  final int achievementsTotal;
  
  /// Completion percentage
  final double completion;
  
  /// Rarity of rarest earned achievement
  final double? rarestAchievementRarity;
  
  /// For PSN: platinum trophy rarity
  final double? platinumRarity;
  
  /// Has platinum trophy (PSN only)
  final bool hasPlatinum;
  
  /// Trophy/achievement breakdown
  final int bronzeCount;
  final int silverCount;
  final int goldCount;
  final int platinumCount;
  
  /// StatusXP earned for this game
  final int statusXP;
  
  /// Current score (gamerscore for Xbox, trophy points for PSN, achievement count for Steam)
  final int currentScore;
  
  /// Total possible score (max gamerscore for Xbox, max trophy points for PSN)
  final int totalScore;
  
  /// Last played/synced timestamp
  final DateTime? lastPlayedAt;
  
  /// Most recent trophy earned timestamp
  final DateTime? lastTrophyEarnedAt;
  
  const PlatformGameData({
    required this.platform,
    required this.gameId,
    this.platformId,
    this.platformGameId,
    required this.achievementsEarned,
    required this.achievementsTotal,
    required this.completion,
    this.rarestAchievementRarity,
    this.platinumRarity,
    this.hasPlatinum = false,
    this.bronzeCount = 0,
    this.silverCount = 0,
    this.goldCount = 0,
    this.platinumCount = 0,
    this.statusXP = 0,
    this.currentScore = 0,
    this.totalScore = 0,
    this.lastPlayedAt,
    this.lastTrophyEarnedAt,
  });
  
  @override
  List<Object?> get props => [
    platform,
    gameId,
    platformId,
    platformGameId,
    achievementsEarned,
    achievementsTotal,
    completion,
    rarestAchievementRarity,
    platinumRarity,
    hasPlatinum,
    bronzeCount,
    silverCount,
    goldCount,
    platinumCount,
    statusXP,
    currentScore,
    totalScore,
    lastPlayedAt,
    lastTrophyEarnedAt,
  ];
}
