/// Unified achievement model for all platforms (PSN, Xbox, Steam)
class Achievement {
  final int id;
  final int gameTitleId;
  final String platform; // 'psn', 'xbox', 'steam'
  final String platformAchievementId;
  final String name;
  final String? description;
  final String? iconUrl;
  
  // Platform-specific fields
  final String? psnTrophyType; // bronze, silver, gold, platinum
  final String? psnTrophyGroupId;
  final bool? psnIsSecret;
  
  final int? xboxGamerscore;
  final bool? xboxIsSecret;
  final String? xboxProgressionState;
  
  final bool? steamHidden;
  
  // Unified fields
  final double? rarityGlobal;
  final bool isDlc;
  final String? dlcName;
  
  final DateTime createdAt;
  final DateTime updatedAt;

  Achievement({
    required this.id,
    required this.gameTitleId,
    required this.platform,
    required this.platformAchievementId,
    required this.name,
    this.description,
    this.iconUrl,
    this.psnTrophyType,
    this.psnTrophyGroupId,
    this.psnIsSecret,
    this.xboxGamerscore,
    this.xboxIsSecret,
    this.xboxProgressionState,
    this.steamHidden,
    this.rarityGlobal,
    this.isDlc = false,
    this.dlcName,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Achievement.fromMap(Map<String, dynamic> map) {
    return Achievement(
      id: map['id'] as int,
      gameTitleId: map['game_title_id'] as int,
      platform: map['platform'] as String,
      platformAchievementId: map['platform_achievement_id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      iconUrl: map['icon_url'] as String?,
      psnTrophyType: map['psn_trophy_type'] as String?,
      psnTrophyGroupId: map['psn_trophy_group_id'] as String?,
      psnIsSecret: map['psn_is_secret'] as bool?,
      xboxGamerscore: map['xbox_gamerscore'] as int?,
      xboxIsSecret: map['xbox_is_secret'] as bool?,
      xboxProgressionState: map['xbox_progression_state'] as String?,
      steamHidden: map['steam_hidden'] as bool?,
      rarityGlobal: map['rarity_global'] != null 
          ? (map['rarity_global'] as num).toDouble()
          : null,
      isDlc: map['is_dlc'] as bool? ?? false,
      dlcName: map['dlc_name'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'game_title_id': gameTitleId,
      'platform': platform,
      'platform_achievement_id': platformAchievementId,
      'name': name,
      'description': description,
      'icon_url': iconUrl,
      'psn_trophy_type': psnTrophyType,
      'psn_trophy_group_id': psnTrophyGroupId,
      'psn_is_secret': psnIsSecret,
      'xbox_gamerscore': xboxGamerscore,
      'xbox_is_secret': xboxIsSecret,
      'xbox_progression_state': xboxProgressionState,
      'steam_hidden': steamHidden,
      'rarity_global': rarityGlobal,
      'is_dlc': isDlc,
      'dlc_name': dlcName,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Get unified tier/grade for display
  String get tier {
    if (platform == 'psn') return psnTrophyType ?? 'bronze';
    if (platform == 'xbox') {
      // Map gamerscore to tiers for consistency
      if (xboxGamerscore == null) return 'bronze';
      if (xboxGamerscore! >= 100) return 'platinum';
      if (xboxGamerscore! >= 50) return 'gold';
      if (xboxGamerscore! >= 20) return 'silver';
      return 'bronze';
    }
    // Steam doesn't have tiers, default to bronze
    return 'bronze';
  }

  /// Get display value (gamerscore for Xbox, empty for others)
  String? get displayValue {
    if (platform == 'xbox' && xboxGamerscore != null) {
      return '${xboxGamerscore}G';
    }
    return null;
  }

  bool get isSecret {
    if (platform == 'psn') return psnIsSecret ?? false;
    if (platform == 'xbox') return xboxIsSecret ?? false;
    if (platform == 'steam') return steamHidden ?? false;
    return false;
  }
}

/// User's earned achievement
class UserAchievement {
  final int id;
  final String userId;
  final int achievementId;
  final DateTime earnedAt;
  final Map<String, dynamic> platformUnlockData;
  final DateTime createdAt;
  
  // Joined achievement data (when fetched with join)
  final Achievement? achievement;

  UserAchievement({
    required this.id,
    required this.userId,
    required this.achievementId,
    required this.earnedAt,
    this.platformUnlockData = const {},
    required this.createdAt,
    this.achievement,
  });

  factory UserAchievement.fromMap(Map<String, dynamic> map) {
    return UserAchievement(
      id: map['id'] as int,
      userId: map['user_id'] as String,
      achievementId: map['achievement_id'] as int,
      earnedAt: DateTime.parse(map['earned_at'] as String),
      platformUnlockData: map['platform_unlock_data'] as Map<String, dynamic>? ?? {},
      createdAt: DateTime.parse(map['created_at'] as String),
      achievement: map['achievements'] != null 
          ? Achievement.fromMap(map['achievements'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'achievement_id': achievementId,
      'earned_at': earnedAt.toIso8601String(),
      'platform_unlock_data': platformUnlockData,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// Virtual completion for StatusXP scoring
class VirtualCompletion {
  final int id;
  final String userId;
  final int gameTitleId;
  final String platform;
  final String completionType; // 'platinum', '100%', 'both'
  final bool baseGameComplete;
  final bool dlcComplete;
  final double statusXpEarned;
  final double rarityMultiplier;
  final double difficultyMultiplier;
  final DateTime achievedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  VirtualCompletion({
    required this.id,
    required this.userId,
    required this.gameTitleId,
    required this.platform,
    required this.completionType,
    required this.baseGameComplete,
    required this.dlcComplete,
    required this.statusXpEarned,
    required this.rarityMultiplier,
    required this.difficultyMultiplier,
    required this.achievedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VirtualCompletion.fromMap(Map<String, dynamic> map) {
    return VirtualCompletion(
      id: map['id'] as int,
      userId: map['user_id'] as String,
      gameTitleId: map['game_title_id'] as int,
      platform: map['platform'] as String,
      completionType: map['completion_type'] as String,
      baseGameComplete: map['base_game_complete'] as bool? ?? false,
      dlcComplete: map['dlc_complete'] as bool? ?? false,
      statusXpEarned: (map['status_xp_earned'] as num).toDouble(),
      rarityMultiplier: (map['rarity_multiplier'] as num).toDouble(),
      difficultyMultiplier: (map['difficulty_multiplier'] as num).toDouble(),
      achievedAt: DateTime.parse(map['achieved_at'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'game_title_id': gameTitleId,
      'platform': platform,
      'completion_type': completionType,
      'base_game_complete': baseGameComplete,
      'dlc_complete': dlcComplete,
      'status_xp_earned': statusXpEarned,
      'rarity_multiplier': rarityMultiplier,
      'difficulty_multiplier': difficultyMultiplier,
      'achieved_at': achievedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  bool get isPlatinum => completionType == 'platinum' || completionType == 'both';
  bool get is100Percent => completionType == '100%' || completionType == 'both';
}
