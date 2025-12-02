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
  
  /// Total number of platinum trophies earned
  final int totalPlatinums;
  
  /// Total number of games being tracked
  final int totalGamesTracked;
  
  /// Total number of trophies/achievements earned across all games
  final int totalTrophies;
  
  /// Name of the most difficult platinum earned
  final String hardestPlatGame;
  
  /// Name of the rarest trophy earned
  final String rarestTrophyName;
  
  /// Rarity percentage of the rarest trophy (0.0 to 100.0)
  final double rarestTrophyRarity;

  const UserStats({
    required this.username,
    required this.totalPlatinums,
    required this.totalGamesTracked,
    required this.totalTrophies,
    required this.hardestPlatGame,
    required this.rarestTrophyName,
    required this.rarestTrophyRarity,
  });

  /// Creates a copy of this UserStats with the given fields replaced with new values.
  UserStats copyWith({
    String? username,
    int? totalPlatinums,
    int? totalGamesTracked,
    int? totalTrophies,
    String? hardestPlatGame,
    String? rarestTrophyName,
    double? rarestTrophyRarity,
  }) {
    return UserStats(
      username: username ?? this.username,
      totalPlatinums: totalPlatinums ?? this.totalPlatinums,
      totalGamesTracked: totalGamesTracked ?? this.totalGamesTracked,
      totalTrophies: totalTrophies ?? this.totalTrophies,
      hardestPlatGame: hardestPlatGame ?? this.hardestPlatGame,
      rarestTrophyName: rarestTrophyName ?? this.rarestTrophyName,
      rarestTrophyRarity: rarestTrophyRarity ?? this.rarestTrophyRarity,
    );
  }

  /// Creates a UserStats instance from a JSON map.
  factory UserStats.fromJson(Map<String, dynamic> json) {
    return UserStats(
      username: json['username'] as String,
      totalPlatinums: json['totalPlatinums'] as int,
      totalGamesTracked: json['totalGamesTracked'] as int,
      totalTrophies: json['totalTrophies'] as int,
      hardestPlatGame: json['hardestPlatGame'] as String,
      rarestTrophyName: json['rarestTrophyName'] as String,
      rarestTrophyRarity: (json['rarestTrophyRarity'] as num).toDouble(),
    );
  }

  /// Converts this UserStats instance to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'totalPlatinums': totalPlatinums,
      'totalGamesTracked': totalGamesTracked,
      'totalTrophies': totalTrophies,
      'hardestPlatGame': hardestPlatGame,
      'rarestTrophyName': rarestTrophyName,
      'rarestTrophyRarity': rarestTrophyRarity,
    };
  }

  @override
  List<Object?> get props => [
        username,
        totalPlatinums,
        totalGamesTracked,
        totalTrophies,
        hardestPlatGame,
        rarestTrophyName,
        rarestTrophyRarity,
      ];

  @override
  bool get stringify => true;
}
