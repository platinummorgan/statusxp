import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

/// Dashboard statistics showing cross-platform gaming metrics
/// 
/// Displays StatusXP unified score and platform-specific achievement counts
@immutable
class DashboardStats extends Equatable {
  /// User's selected display name (PSN/Steam/Xbox)
  final String displayName;
  
  /// Platform of the selected display name ('psn', 'steam', 'xbox')
  final String displayPlatform;
  
  /// PSN avatar URL (if available)
  final String? avatarUrl;
  
  /// PlayStation Plus subscription status
  final bool isPsPlus;
  
  /// Total StatusXP across all platforms
  final double totalStatusXP;
  
  /// PSN platform stats
  final PlatformStats psnStats;
  
  /// Xbox platform stats
  final PlatformStats xboxStats;
  
  /// Steam platform stats
  final PlatformStats steamStats;

  const DashboardStats({
    required this.displayName,
    required this.displayPlatform,
    this.avatarUrl,
    this.isPsPlus = false,
    required this.totalStatusXP,
    required this.psnStats,
    required this.xboxStats,
    required this.steamStats,
  });

  /// Creates a copy with the given fields replaced
  DashboardStats copyWith({
    String? displayName,
    String? displayPlatform,
    String? avatarUrl,
    bool? isPsPlus,
    double? totalStatusXP,
    PlatformStats? psnStats,
    PlatformStats? xboxStats,
    PlatformStats? steamStats,
  }) {
    return DashboardStats(
      displayName: displayName ?? this.displayName,
      displayPlatform: displayPlatform ?? this.displayPlatform,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isPsPlus: isPsPlus ?? this.isPsPlus,
      totalStatusXP: totalStatusXP ?? this.totalStatusXP,
      psnStats: psnStats ?? this.psnStats,
      xboxStats: xboxStats ?? this.xboxStats,
      steamStats: steamStats ?? this.steamStats,
    );
  }

  @override
  List<Object?> get props => [
        displayName,
        displayPlatform,
        avatarUrl,
        isPsPlus,
        totalStatusXP,
        psnStats,
        xboxStats,
        steamStats,
      ];

  @override
  bool get stringify => true;
}

/// Platform-specific statistics
@immutable
class PlatformStats extends Equatable {
  /// Number of platinum trophies (PSN only, 0 for other platforms)
  final int platinums;
  
  /// Total achievements/trophies unlocked on this platform
  final int achievementsUnlocked;
  
  /// Number of games with achievements on this platform
  final int gamesCount;
  
  /// StatusXP earned on this platform
  final double statusXP;
  
  /// Average achievements per game (calculated)
  double get averagePerGame => 
      gamesCount > 0 ? achievementsUnlocked / gamesCount : 0.0;

  const PlatformStats({
    this.platinums = 0,
    required this.achievementsUnlocked,
    required this.gamesCount,
    this.statusXP = 0,
  });

  /// Creates empty platform stats
  const PlatformStats.empty()
      : platinums = 0,
        achievementsUnlocked = 0,
        gamesCount = 0,
        statusXP = 0;

  @override
  List<Object?> get props => [platinums, achievementsUnlocked, gamesCount, statusXP];

  @override
  bool get stringify => true;
}
