import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

/// Complete analytics data for a user
@immutable
class AnalyticsData extends Equatable {
  final TrophyTimelineData timelineData;
  final PlatformDistribution platformDistribution;
  final RarityDistribution rarityDistribution;
  final TrophyTypeBreakdown trophyTypeBreakdown;
  final MonthlyActivity monthlyActivity;
  
  const AnalyticsData({
    required this.timelineData,
    required this.platformDistribution,
    required this.rarityDistribution,
    required this.trophyTypeBreakdown,
    required this.monthlyActivity,
  });
  
  @override
  List<Object?> get props => [
    timelineData,
    platformDistribution,
    rarityDistribution,
    trophyTypeBreakdown,
    monthlyActivity,
  ];
}

/// Trophy timeline data - trophies earned over time
@immutable
class TrophyTimelineData extends Equatable {
  final List<TimelinePoint> psnPoints;
  final List<TimelinePoint> xboxPoints;
  final List<TimelinePoint> steamPoints;
  final int totalTrophies;
  final DateTime? firstTrophy;
  final DateTime? lastTrophy;
  
  const TrophyTimelineData({
    required this.psnPoints,
    required this.xboxPoints,
    required this.steamPoints,
    required this.totalTrophies,
    this.firstTrophy,
    this.lastTrophy,
  });
  
  /// Get days between first and last trophy
  int get daysTracking {
    if (firstTrophy == null || lastTrophy == null) return 0;
    return lastTrophy!.difference(firstTrophy!).inDays;
  }
  
  /// Get average trophies per day
  double get averagePerDay {
    if (daysTracking == 0) return 0;
    return totalTrophies / daysTracking;
  }
  
  @override
  List<Object?> get props => [psnPoints, xboxPoints, steamPoints, totalTrophies, firstTrophy, lastTrophy];
}

/// Single point on the timeline
@immutable
class TimelinePoint extends Equatable {
  final DateTime date;
  final int cumulativeCount;
  
  const TimelinePoint({
    required this.date,
    required this.cumulativeCount,
  });
  
  @override
  List<Object?> get props => [date, cumulativeCount];
}

/// Platform distribution data
@immutable
class PlatformDistribution extends Equatable {
  final int psnCount;
  final int xboxCount;
  final int steamCount;
  
  const PlatformDistribution({
    required this.psnCount,
    required this.xboxCount,
    required this.steamCount,
  });
  
  int get total => psnCount + xboxCount + steamCount;
  
  double get psnPercent => total > 0 ? (psnCount / total) * 100 : 0;
  double get xboxPercent => total > 0 ? (xboxCount / total) * 100 : 0;
  double get steamPercent => total > 0 ? (steamCount / total) * 100 : 0;
  
  String get dominantPlatform {
    if (psnCount >= xboxCount && psnCount >= steamCount) return 'PSN';
    if (xboxCount >= steamCount) return 'Xbox';
    return 'Steam';
  }
  
  @override
  List<Object?> get props => [psnCount, xboxCount, steamCount];
}

/// Rarity distribution - how many trophies in each rarity band
@immutable
class RarityDistribution extends Equatable {
  final int ultraRare;    // < 1%
  final int veryRare;     // 1-5%
  final int rare;         // 5-10%
  final int uncommon;     // 10-25%
  final int common;       // 25-50%
  final int veryCommon;   // > 50%
  
  const RarityDistribution({
    required this.ultraRare,
    required this.veryRare,
    required this.rare,
    required this.uncommon,
    required this.common,
    required this.veryCommon,
  });
  
  int get total => ultraRare + veryRare + rare + uncommon + common + veryCommon;
  
  double get ultraRarePercent => total > 0 ? (ultraRare / total) * 100 : 0;
  double get veryRarePercent => total > 0 ? (veryRare / total) * 100 : 0;
  double get rarePercent => total > 0 ? (rare / total) * 100 : 0;
  double get uncommonPercent => total > 0 ? (uncommon / total) * 100 : 0;
  double get commonPercent => total > 0 ? (common / total) * 100 : 0;
  double get veryCommonPercent => total > 0 ? (veryCommon / total) * 100 : 0;
  
  @override
  List<Object?> get props => [ultraRare, veryRare, rare, uncommon, common, veryCommon];
}

/// Trophy type breakdown (PSN specific)
@immutable
class TrophyTypeBreakdown extends Equatable {
  final int bronze;
  final int silver;
  final int gold;
  final int platinum;
  
  const TrophyTypeBreakdown({
    required this.bronze,
    required this.silver,
    required this.gold,
    required this.platinum,
  });
  
  int get total => bronze + silver + gold + platinum;
  
  double get bronzePercent => total > 0 ? (bronze / total) * 100 : 0;
  double get silverPercent => total > 0 ? (silver / total) * 100 : 0;
  double get goldPercent => total > 0 ? (gold / total) * 100 : 0;
  double get platinumPercent => total > 0 ? (platinum / total) * 100 : 0;
  
  @override
  List<Object?> get props => [bronze, silver, gold, platinum];
}

/// Monthly activity data
@immutable
class MonthlyActivity extends Equatable {
  final List<MonthlyDataPoint> months;
  
  const MonthlyActivity({required this.months});
  
  /// Get the most active month
  MonthlyDataPoint? get mostActiveMonth {
    if (months.isEmpty) return null;
    return months.reduce((curr, next) => 
      curr.totalCount > next.totalCount ? curr : next
    );
  }
  
  /// Get average trophies per month
  double get averagePerMonth {
    if (months.isEmpty) return 0;
    final total = months.fold<int>(0, (sum, month) => sum + month.totalCount);
    return total / months.length;
  }
  
  @override
  List<Object?> get props => [months];
}

/// Single month's data point
@immutable
class MonthlyDataPoint extends Equatable {
  final int year;
  final int month;
  final int psnCount;
  final int xboxCount;
  final int steamCount;
  
  const MonthlyDataPoint({
    required this.year,
    required this.month,
    required this.psnCount,
    required this.xboxCount,
    required this.steamCount,
  });
  
  int get totalCount => psnCount + xboxCount + steamCount;
  
  String get monthName {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }
  
  String get label => '$monthName ${year.toString().substring(2)}';
  
  @override
  List<Object?> get props => [year, month, psnCount, xboxCount, steamCount];
}
