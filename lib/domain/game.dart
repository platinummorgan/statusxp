import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

/// Represents a video game with trophy/achievement tracking data.
/// 
/// This model stores essential information about a tracked game including
/// platform, trophy progress, platinum status, and rarity metrics.
@immutable
class Game extends Equatable {
  /// Unique identifier for the game
  final String id;
  
  /// Display name of the game
  final String name;
  
  /// Gaming platform (e.g., 'PS5', 'PS4', 'Xbox', 'Steam')
  final String platform;
  
  /// Total number of trophies/achievements available in the game
  final int totalTrophies;
  
  /// Number of trophies/achievements earned by the user
  final int earnedTrophies;
  
  /// Whether the game has a platinum trophy/100% completion
  final bool hasPlatinum;
  
  /// Rarity percentage of the rarest earned trophy (0.0 to 100.0)
  final double rarityPercent;
  
  /// Cover image filename or asset path
  final String cover;

  const Game({
    required this.id,
    required this.name,
    required this.platform,
    required this.totalTrophies,
    required this.earnedTrophies,
    required this.hasPlatinum,
    required this.rarityPercent,
    required this.cover,
  });

  /// Creates a copy of this Game with the given fields replaced with new values.
  Game copyWith({
    String? id,
    String? name,
    String? platform,
    int? totalTrophies,
    int? earnedTrophies,
    bool? hasPlatinum,
    double? rarityPercent,
    String? cover,
  }) {
    return Game(
      id: id ?? this.id,
      name: name ?? this.name,
      platform: platform ?? this.platform,
      totalTrophies: totalTrophies ?? this.totalTrophies,
      earnedTrophies: earnedTrophies ?? this.earnedTrophies,
      hasPlatinum: hasPlatinum ?? this.hasPlatinum,
      rarityPercent: rarityPercent ?? this.rarityPercent,
      cover: cover ?? this.cover,
    );
  }

  /// Creates a Game instance from a JSON map.
  factory Game.fromJson(Map<String, dynamic> json) {
    return Game(
      id: json['id'] as String,
      name: json['name'] as String,
      platform: json['platform'] as String,
      totalTrophies: json['totalTrophies'] as int,
      earnedTrophies: json['earnedTrophies'] as int,
      hasPlatinum: json['hasPlatinum'] as bool,
      rarityPercent: (json['rarityPercent'] as num).toDouble(),
      cover: json['cover'] as String,
    );
  }

  /// Converts this Game instance to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'platform': platform,
      'totalTrophies': totalTrophies,
      'earnedTrophies': earnedTrophies,
      'hasPlatinum': hasPlatinum,
      'rarityPercent': rarityPercent,
      'cover': cover,
    };
  }

  /// Calculates the completion percentage (0.0 to 100.0).
  double get completionPercent {
    if (totalTrophies == 0) return 0.0;
    return (earnedTrophies / totalTrophies) * 100.0;
  }

  @override
  List<Object?> get props => [
        id,
        name,
        platform,
        totalTrophies,
        earnedTrophies,
        hasPlatinum,
        rarityPercent,
        cover,
      ];

  @override
  bool get stringify => true;
}
