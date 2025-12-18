/// Flex Room - Cross-platform achievement showcase
/// User's curated museum of their best gaming moments
library;

// Sentinel value for copyWith to distinguish between null and unset
const _undefined = Object();

/// Main flex room data model
class FlexRoomData {
  final String userId;
  final String tagline;
  final DateTime lastUpdated;
  
  // Cross-Platform Flex Row (4 featured achievements)
  final FlexTile? flexOfAllTime;
  final FlexTile? rarestFlex;
  final FlexTile? mostTimeSunk;
  final FlexTile? sweattiestPlatinum;
  
  // Superlative Wall (customizable tiles)
  final Map<String, FlexTile> superlatives;
  
  // Recent notable unlocks
  final List<RecentFlex> recentFlexes;

  const FlexRoomData({
    required this.userId,
    this.tagline = 'Wall of Fame',
    required this.lastUpdated,
    this.flexOfAllTime,
    this.rarestFlex,
    this.mostTimeSunk,
    this.sweattiestPlatinum,
    this.superlatives = const {},
    this.recentFlexes = const [],
  });

  factory FlexRoomData.fromJson(Map<String, dynamic> json) {
    return FlexRoomData(
      userId: json['user_id'] as String,
      tagline: json['tagline'] as String? ?? 'Wall of Fame',
      lastUpdated: DateTime.parse(json['last_updated'] as String),
      flexOfAllTime: json['flex_of_all_time'] != null
          ? FlexTile.fromJson(json['flex_of_all_time'] as Map<String, dynamic>)
          : null,
      rarestFlex: json['rarest_flex'] != null
          ? FlexTile.fromJson(json['rarest_flex'] as Map<String, dynamic>)
          : null,
      mostTimeSunk: json['most_time_sunk'] != null
          ? FlexTile.fromJson(json['most_time_sunk'] as Map<String, dynamic>)
          : null,
      sweattiestPlatinum: json['sweattiest_platinum'] != null
          ? FlexTile.fromJson(json['sweattiest_platinum'] as Map<String, dynamic>)
          : null,
      superlatives: json['superlatives'] != null
          ? Map<String, FlexTile>.fromEntries(
              (json['superlatives'] as Map<String, dynamic>).entries.map(
                (e) => MapEntry(
                  e.key,
                  FlexTile.fromJson(e.value as Map<String, dynamic>),
                ),
              ),
            )
          : {},
      recentFlexes: json['recent_flexes'] != null
          ? List<RecentFlex>.from(
              (json['recent_flexes'] as List)
                  .map((e) => RecentFlex.fromJson(e as Map<String, dynamic>)),
            )
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'tagline': tagline,
      'last_updated': lastUpdated.toIso8601String(),
      'flex_of_all_time': flexOfAllTime?.toJson(),
      'rarest_flex': rarestFlex?.toJson(),
      'most_time_sunk': mostTimeSunk?.toJson(),
      'sweattiest_platinum': sweattiestPlatinum?.toJson(),
      'superlatives': superlatives.map((key, value) => MapEntry(key, value.toJson())),
      'recent_flexes': recentFlexes.map((e) => e.toJson()).toList(),
    };
  }

  FlexRoomData copyWith({
    String? tagline,
    DateTime? lastUpdated,
    Object? flexOfAllTime = _undefined,
    Object? rarestFlex = _undefined,
    Object? mostTimeSunk = _undefined,
    Object? sweattiestPlatinum = _undefined,
    Map<String, FlexTile>? superlatives,
    List<RecentFlex>? recentFlexes,
  }) {
    return FlexRoomData(
      userId: userId,
      tagline: tagline ?? this.tagline,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      flexOfAllTime: flexOfAllTime == _undefined ? this.flexOfAllTime : flexOfAllTime as FlexTile?,
      rarestFlex: rarestFlex == _undefined ? this.rarestFlex : rarestFlex as FlexTile?,
      mostTimeSunk: mostTimeSunk == _undefined ? this.mostTimeSunk : mostTimeSunk as FlexTile?,
      sweattiestPlatinum: sweattiestPlatinum == _undefined ? this.sweattiestPlatinum : sweattiestPlatinum as FlexTile?,
      superlatives: superlatives ?? this.superlatives,
      recentFlexes: recentFlexes ?? this.recentFlexes,
    );
  }
}

/// Individual flex tile (achievement/trophy showcase)
class FlexTile {
  final int achievementId;
  final String achievementName;
  final String gameName;
  final String? gameId;
  final String? gameCoverUrl;
  final String platform; // 'psn', 'xbox', 'steam'
  final double? rarityPercent;
  final String? rarityBand; // 'ULTRA_RARE', 'VERY_RARE', etc.
  final int? statusXP;
  final DateTime? earnedAt;
  final String? iconUrl;

  const FlexTile({
    required this.achievementId,
    required this.achievementName,
    required this.gameName,
    this.gameId,
    this.gameCoverUrl,
    required this.platform,
    this.rarityPercent,
    this.rarityBand,
    this.statusXP,
    this.earnedAt,
    this.iconUrl,
  });

  factory FlexTile.fromJson(Map<String, dynamic> json) {
    return FlexTile(
      achievementId: json['achievement_id'] as int,
      achievementName: json['achievement_name'] as String,
      gameName: json['game_name'] as String,
      gameId: json['game_id'] as String?,
      gameCoverUrl: json['game_cover_url'] as String?,
      platform: json['platform'] as String,
      rarityPercent: (json['rarity_percent'] as num?)?.toDouble(),
      rarityBand: json['rarity_band'] as String?,
      statusXP: ((json['status_xp'] as num?)?.toDouble() ?? 0.0).toInt(),
      earnedAt: json['earned_at'] != null
          ? DateTime.parse(json['earned_at'] as String)
          : null,
      iconUrl: json['icon_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'achievement_id': achievementId,
      'achievement_name': achievementName,
      'game_name': gameName,
      'game_id': gameId,
      'game_cover_url': gameCoverUrl,
      'platform': platform,
      'rarity_percent': rarityPercent,
      'rarity_band': rarityBand,
      'status_xp': statusXP,
      'earned_at': earnedAt?.toIso8601String(),
      'icon_url': iconUrl,
    };
  }
}

/// Recent notable achievement unlock
class RecentFlex {
  final String gameName;
  final String achievementName;
  final String platform;
  final double rarityPercent;
  final String rarityBand;
  final DateTime earnedAt;
  final String type; // 'platinum', 'ultra_rare', '100_percent'

  const RecentFlex({
    required this.gameName,
    required this.achievementName,
    required this.platform,
    required this.rarityPercent,
    required this.rarityBand,
    required this.earnedAt,
    required this.type,
  });

  factory RecentFlex.fromJson(Map<String, dynamic> json) {
    return RecentFlex(
      gameName: json['game_name'] as String,
      achievementName: json['achievement_name'] as String,
      platform: json['platform'] as String,
      rarityPercent: (json['rarity_percent'] as num).toDouble(),
      rarityBand: json['rarity_band'] as String,
      earnedAt: DateTime.parse(json['earned_at'] as String),
      type: json['type'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'game_name': gameName,
      'achievement_name': achievementName,
      'platform': platform,
      'rarity_percent': rarityPercent,
      'rarity_band': rarityBand,
      'earned_at': earnedAt.toIso8601String(),
      'type': type,
    };
  }
}

/// Superlative categories for the wall
class SuperlativeCategory {
  static const String hardest = 'hardest';
  static const String easiest = 'easiest';
  static const String aggravating = 'aggravating';
  static const String rageInducing = 'rage_inducing';
  static const String biggestGrind = 'biggest_grind';
  static const String mostTime = 'most_time';
  static const String rngNightmare = 'rng_nightmare';
  static const String neverAgain = 'never_again';
  static const String mostProud = 'most_proud';
  static const String clutch = 'clutch';
  static const String cozyComfort = 'cozy_comfort';
  static const String hiddenGem = 'hidden_gem';

  static const List<Map<String, String>> all = [
    {'id': hardest, 'label': 'Hardest Trophy'},
    {'id': easiest, 'label': 'Easiest Flex'},
    {'id': aggravating, 'label': 'Most Aggravating'},
    {'id': rageInducing, 'label': 'Rage-Inducing'},
    {'id': biggestGrind, 'label': 'Biggest Grind'},
    {'id': mostTime, 'label': 'Most Time-Consuming'},
    {'id': rngNightmare, 'label': 'RNG Nightmare'},
    {'id': neverAgain, 'label': 'Never Again'},
    {'id': mostProud, 'label': 'Most Proud Of'},
    {'id': clutch, 'label': 'Clutch 100%'},
    {'id': cozyComfort, 'label': 'Cozy Comfort Game'},
    {'id': hiddenGem, 'label': 'Hidden Gem'},
  ];
}
