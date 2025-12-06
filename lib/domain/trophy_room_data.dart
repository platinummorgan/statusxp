import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

/// Trophy Room data model containing all showcase statistics
@immutable
class TrophyRoomData extends Equatable {
  /// All earned platinum trophies with game details
  final List<PlatinumTrophy> platinums;
  
  /// Ultra-rare trophies (< 2% rarity)
  final List<UltraRareTrophy> ultraRareTrophies;
  
  /// Recent trophy unlocks
  final List<RecentTrophy> recentTrophies;

  const TrophyRoomData({
    required this.platinums,
    required this.ultraRareTrophies,
    required this.recentTrophies,
  });

  /// Get the rarest platinum trophy (lowest rarity percentage)
  PlatinumTrophy? get rarestPlatinum {
    if (platinums.isEmpty) return null;
    
    return platinums.reduce((curr, next) => 
      curr.rarity < next.rarity ? curr : next
    );
  }

  /// Get the hardest platinum trophy (same as rarest for now)
  PlatinumTrophy? get hardestPlatinum => rarestPlatinum;

  /// Get the newest platinum trophy (most recent)
  PlatinumTrophy? get newestPlatinum {
    if (platinums.isEmpty) return null;
    
    return platinums.reduce((curr, next) => 
      curr.earnedAt.isAfter(next.earnedAt) ? curr : next
    );
  }

  @override
  List<Object?> get props => [platinums, ultraRareTrophies, recentTrophies];
}

/// Platinum trophy with game details
@immutable
class PlatinumTrophy extends Equatable {
  final int trophyId;
  final String trophyName;
  final String gameName;
  final String? coverUrl;
  final double rarity;
  final DateTime earnedAt;
  final String? iconUrl;

  const PlatinumTrophy({
    required this.trophyId,
    required this.trophyName,
    required this.gameName,
    this.coverUrl,
    required this.rarity,
    required this.earnedAt,
    this.iconUrl,
  });

  factory PlatinumTrophy.fromMap(Map<String, dynamic> map) {
    return PlatinumTrophy(
      trophyId: map['trophy_id'] as int,
      trophyName: map['trophy_name'] as String,
      gameName: map['game_name'] as String,
      coverUrl: map['cover_url'] as String?,
      rarity: map['rarity'] as double,
      earnedAt: DateTime.parse(map['earned_at'] as String),
      iconUrl: map['icon_url'] as String?,
    );
  }

  @override
  List<Object?> get props => [trophyId, trophyName, gameName, coverUrl, rarity, earnedAt, iconUrl];
}

/// Ultra-rare trophy (< 2% rarity)
@immutable
class UltraRareTrophy extends Equatable {
  final int trophyId;
  final String trophyName;
  final String gameName;
  final String tier;
  final double rarity;
  final DateTime earnedAt;
  final String? iconUrl;

  const UltraRareTrophy({
    required this.trophyId,
    required this.trophyName,
    required this.gameName,
    required this.tier,
    required this.rarity,
    required this.earnedAt,
    this.iconUrl,
  });

  factory UltraRareTrophy.fromMap(Map<String, dynamic> map) {
    return UltraRareTrophy(
      trophyId: map['trophy_id'] as int,
      trophyName: map['trophy_name'] as String,
      gameName: map['game_name'] as String,
      tier: map['tier'] as String,
      rarity: map['rarity'] as double,
      earnedAt: DateTime.parse(map['earned_at'] as String),
      iconUrl: map['icon_url'] as String?,
    );
  }

  @override
  List<Object?> get props => [trophyId, trophyName, gameName, tier, rarity, earnedAt, iconUrl];
}

/// Recent trophy unlock
@immutable
class RecentTrophy extends Equatable {
  final int trophyId;
  final String trophyName;
  final String gameName;
  final String tier;
  final DateTime earnedAt;
  final String? iconUrl;

  const RecentTrophy({
    required this.trophyId,
    required this.trophyName,
    required this.gameName,
    required this.tier,
    required this.earnedAt,
    this.iconUrl,
  });

  factory RecentTrophy.fromMap(Map<String, dynamic> map) {
    return RecentTrophy(
      trophyId: map['trophy_id'] as int,
      trophyName: map['trophy_name'] as String,
      gameName: map['game_name'] as String,
      tier: map['tier'] as String,
      earnedAt: DateTime.parse(map['earned_at'] as String),
      iconUrl: map['icon_url'] as String?,
    );
  }

  @override
  List<Object?> get props => [trophyId, trophyName, gameName, tier, earnedAt, iconUrl];
}
