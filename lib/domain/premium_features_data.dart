import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

enum GoalsMetric { statusxp, platinums, xboxGamerscore, steamAchievements }

@immutable
class GoalsRangeQuery extends Equatable {
  final GoalsMetric metric;
  final DateTime start;
  final DateTime end;

  const GoalsRangeQuery({
    required this.metric,
    required this.start,
    required this.end,
  });

  @override
  List<Object?> get props => [metric, start, end];
}

@immutable
class PaceWindowInsight extends Equatable {
  final String periodLabel;
  final DateTime periodStart;
  final DateTime periodEnd;
  final int currentGain;
  final int projectedGain;
  final int rank;
  final int totalPlayers;
  final int gapToFirst;

  const PaceWindowInsight({
    required this.periodLabel,
    required this.periodStart,
    required this.periodEnd,
    required this.currentGain,
    required this.projectedGain,
    required this.rank,
    required this.totalPlayers,
    required this.gapToFirst,
  });

  int get totalDays {
    final days = periodEnd.difference(periodStart).inDays;
    return days <= 0 ? 1 : days;
  }

  int get elapsedDays {
    final now = DateTime.now().toUtc();
    if (now.isBefore(periodStart)) return 0;
    if (now.isAfter(periodEnd)) return totalDays;
    final days = now.difference(periodStart).inDays + 1;
    return days.clamp(1, totalDays);
  }

  int get remainingDays => (totalDays - elapsedDays).clamp(0, totalDays);

  @override
  List<Object?> get props => [
    periodLabel,
    periodStart,
    periodEnd,
    currentGain,
    projectedGain,
    rank,
    totalPlayers,
    gapToFirst,
  ];
}

@immutable
class GoalsPaceData extends Equatable {
  final int currentValue;
  final PaceWindowInsight weekly;
  final PaceWindowInsight monthly;

  const GoalsPaceData({
    required this.currentValue,
    required this.weekly,
    required this.monthly,
  });

  @override
  List<Object?> get props => [currentValue, weekly, monthly];
}

@immutable
class RivalCompareEntry extends Equatable {
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final int allTimeRank;
  final int allTimeScore;
  final int weeklyGain;
  final int monthlyGain;
  final int gapToYou;
  final bool isYou;

  const RivalCompareEntry({
    required this.userId,
    required this.displayName,
    required this.avatarUrl,
    required this.allTimeRank,
    required this.allTimeScore,
    required this.weeklyGain,
    required this.monthlyGain,
    required this.gapToYou,
    required this.isYou,
  });

  @override
  List<Object?> get props => [
    userId,
    displayName,
    avatarUrl,
    allTimeRank,
    allTimeScore,
    weeklyGain,
    monthlyGain,
    gapToYou,
    isYou,
  ];
}

@immutable
class RivalCompareData extends Equatable {
  final String userId;
  final int yourAllTimeScore;
  final List<RivalCompareEntry> entries;

  const RivalCompareData({
    required this.userId,
    required this.yourAllTimeScore,
    required this.entries,
  });

  @override
  List<Object?> get props => [userId, yourAllTimeScore, entries];
}

@immutable
class RadarGameInsight extends Equatable {
  final int platformId;
  final String platformLabel;
  final String platformGameId;
  final String gameTitle;
  final int earnedCount;
  final int totalCount;
  final int remainingCount;
  final double completionPercent;
  final int currentScore;
  final DateTime? lastPlayedAt;
  final DateTime? lastAchievementAt;
  final DateTime? lastSyncedAt;

  const RadarGameInsight({
    required this.platformId,
    required this.platformLabel,
    required this.platformGameId,
    required this.gameTitle,
    required this.earnedCount,
    required this.totalCount,
    required this.remainingCount,
    required this.completionPercent,
    required this.currentScore,
    required this.lastPlayedAt,
    required this.lastAchievementAt,
    required this.lastSyncedAt,
  });

  @override
  List<Object?> get props => [
    platformId,
    platformLabel,
    platformGameId,
    gameTitle,
    earnedCount,
    totalCount,
    remainingCount,
    completionPercent,
    currentScore,
    lastPlayedAt,
    lastAchievementAt,
    lastSyncedAt,
  ];
}

@immutable
class AchievementRadarData extends Equatable {
  final List<RadarGameInsight> nearCompletion;
  final List<RadarGameInsight> staleProgress;
  final List<RadarGameInsight> highPotential;

  const AchievementRadarData({
    required this.nearCompletion,
    required this.staleProgress,
    required this.highPotential,
  });

  @override
  List<Object?> get props => [nearCompletion, staleProgress, highPotential];
}
