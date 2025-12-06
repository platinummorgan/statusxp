import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

/// Represents aggregate statistics for a user's gaming achievements.
/// 
/// This model contains high-level metrics about a user's gaming profile,
/// including total platinums, games tracked, and notable accomplishments.
@immutable
class UserStats extends Equatable {
  /// User's display name or gamertag
  final String username;
  
  /// PSN avatar URL (if available)
  final String? avatarUrl;
  
  /// PlayStation Plus subscription status
  final bool isPsPlus;
  
  /// Total number of platinum trophies earned
  final int totalPlatinums;
  
  /// Total number of games being tracked
  final int totalGamesTracked;
  
  /// Total number of trophies/achievements earned across all games
  final int totalTrophies;
  
  /// Number of bronze trophies earned
  final int bronzeTrophies;
  
  /// Number of silver trophies earned
  final int silverTrophies;
  
  /// Number of gold trophies earned
  final int goldTrophies;
  
  /// Number of platinum trophies earned (same as totalPlatinums)
  final int platinumTrophies;
  
  /// Name of the most difficult platinum earned
  final String hardestPlatGame;
  
  /// Name of the rarest trophy earned
  final String rarestTrophyName;
  
  /// Rarity percentage of the rarest trophy (0.0 to 100.0)
  final double rarestTrophyRarity;

  const UserStats({
    required this.username,
    this.avatarUrl,
    this.isPsPlus = false,
    required this.totalPlatinums,
    required this.totalGamesTracked,
    required this.totalTrophies,
    required this.bronzeTrophies,
    required this.silverTrophies,
    required this.goldTrophies,
    required this.platinumTrophies,
    required this.hardestPlatGame,
    required this.rarestTrophyName,
    required this.rarestTrophyRarity,
  });

  /// Creates a copy of this UserStats with the given fields replaced with new values.
  UserStats copyWith({
    String? username,
    String? avatarUrl,
    bool? isPsPlus,
    int? totalPlatinums,
    int? totalGamesTracked,
    int? totalTrophies,
    int? bronzeTrophies,
    int? silverTrophies,
    int? goldTrophies,
    int? platinumTrophies,
    String? hardestPlatGame,
    String? rarestTrophyName,
    double? rarestTrophyRarity,
  }) {
    return UserStats(
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isPsPlus: isPsPlus ?? this.isPsPlus,
      totalPlatinums: totalPlatinums ?? this.totalPlatinums,
      totalGamesTracked: totalGamesTracked ?? this.totalGamesTracked,
      totalTrophies: totalTrophies ?? this.totalTrophies,
      bronzeTrophies: bronzeTrophies ?? this.bronzeTrophies,
      silverTrophies: silverTrophies ?? this.silverTrophies,
      goldTrophies: goldTrophies ?? this.goldTrophies,
      platinumTrophies: platinumTrophies ?? this.platinumTrophies,
      hardestPlatGame: hardestPlatGame ?? this.hardestPlatGame,
      rarestTrophyName: rarestTrophyName ?? this.rarestTrophyName,
      rarestTrophyRarity: rarestTrophyRarity ?? this.rarestTrophyRarity,
    );
  }

  /// Creates a UserStats instance from a JSON map.
  factory UserStats.fromJson(Map<String, dynamic> json) {
    return UserStats(
      username: json['username'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      isPsPlus: json['isPsPlus'] as bool? ?? false,
      totalPlatinums: json['totalPlatinums'] as int,
      totalGamesTracked: json['totalGamesTracked'] as int,
      totalTrophies: json['totalTrophies'] as int,
      bronzeTrophies: json['bronzeTrophies'] as int,
      silverTrophies: json['silverTrophies'] as int,
      goldTrophies: json['goldTrophies'] as int,
      platinumTrophies: json['platinumTrophies'] as int,
      hardestPlatGame: json['hardestPlatGame'] as String,
      rarestTrophyName: json['rarestTrophyName'] as String,
      rarestTrophyRarity: (json['rarestTrophyRarity'] as num).toDouble(),
    );
  }

  /// Converts this UserStats instance to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'avatarUrl': avatarUrl,
      'isPsPlus': isPsPlus,
      'totalPlatinums': totalPlatinums,
      'totalGamesTracked': totalGamesTracked,
      'totalTrophies': totalTrophies,
      'bronzeTrophies': bronzeTrophies,
      'silverTrophies': silverTrophies,
      'goldTrophies': goldTrophies,
      'platinumTrophies': platinumTrophies,
      'hardestPlatGame': hardestPlatGame,
      'rarestTrophyName': rarestTrophyName,
      'rarestTrophyRarity': rarestTrophyRarity,
    };
  }

  @override
  List<Object?> get props => [
        username,
        avatarUrl,
        isPsPlus,
        totalPlatinums,
        totalGamesTracked,
        totalTrophies,
        bronzeTrophies,
        silverTrophies,
        goldTrophies,
        platinumTrophies,
        hardestPlatGame,
        rarestTrophyName,
        rarestTrophyRarity,
      ];

  @override
  bool get stringify => true;
}
