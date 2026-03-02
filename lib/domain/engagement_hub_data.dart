import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

@immutable
class SocialTarget extends Equatable {
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final int totalStatusXp;
  final int weeklyGain;
  final int monthlyGain;
  final bool isFollowing;
  final bool isRivalWatchlisted;

  const SocialTarget({
    required this.userId,
    required this.displayName,
    required this.avatarUrl,
    required this.totalStatusXp,
    required this.weeklyGain,
    required this.monthlyGain,
    required this.isFollowing,
    required this.isRivalWatchlisted,
  });

  @override
  List<Object?> get props => [
    userId,
    displayName,
    avatarUrl,
    totalStatusXp,
    weeklyGain,
    monthlyGain,
    isFollowing,
    isRivalWatchlisted,
  ];
}

@immutable
class SocialHighlight extends Equatable {
  final int id;
  final String actorUserId;
  final String actorDisplayName;
  final String? actorAvatarUrl;
  final String storyText;
  final String eventType;
  final String? gameTitle;
  final DateTime createdAt;
  final bool isFollowing;
  final bool isRivalWatchlisted;

  const SocialHighlight({
    required this.id,
    required this.actorUserId,
    required this.actorDisplayName,
    required this.actorAvatarUrl,
    required this.storyText,
    required this.eventType,
    required this.gameTitle,
    required this.createdAt,
    required this.isFollowing,
    required this.isRivalWatchlisted,
  });

  @override
  List<Object?> get props => [
    id,
    actorUserId,
    actorDisplayName,
    actorAvatarUrl,
    storyText,
    eventType,
    gameTitle,
    createdAt,
    isFollowing,
    isRivalWatchlisted,
  ];
}

@immutable
class ChallengeProgress extends Equatable {
  final String id;
  final String title;
  final String description;
  final int target;
  final int progress;
  final int rewardXp;
  final bool completed;

  const ChallengeProgress({
    required this.id,
    required this.title,
    required this.description,
    required this.target,
    required this.progress,
    required this.rewardXp,
    required this.completed,
  });

  double get progressFraction {
    if (target <= 0) return 0;
    return (progress / target).clamp(0, 1).toDouble();
  }

  @override
  List<Object?> get props => [
    id,
    title,
    description,
    target,
    progress,
    rewardXp,
    completed,
  ];
}

@immutable
class NotificationPreferences extends Equatable {
  final bool pushEnabled;
  final bool notifyRivalActivity;
  final bool notifyStreakRisk;
  final bool notifyDailyChallenges;
  final bool notifyActivityHighlights;
  final int dailyDigestHour;

  const NotificationPreferences({
    required this.pushEnabled,
    required this.notifyRivalActivity,
    required this.notifyStreakRisk,
    required this.notifyDailyChallenges,
    required this.notifyActivityHighlights,
    required this.dailyDigestHour,
  });

  NotificationPreferences copyWith({
    bool? pushEnabled,
    bool? notifyRivalActivity,
    bool? notifyStreakRisk,
    bool? notifyDailyChallenges,
    bool? notifyActivityHighlights,
    int? dailyDigestHour,
  }) {
    return NotificationPreferences(
      pushEnabled: pushEnabled ?? this.pushEnabled,
      notifyRivalActivity: notifyRivalActivity ?? this.notifyRivalActivity,
      notifyStreakRisk: notifyStreakRisk ?? this.notifyStreakRisk,
      notifyDailyChallenges:
          notifyDailyChallenges ?? this.notifyDailyChallenges,
      notifyActivityHighlights:
          notifyActivityHighlights ?? this.notifyActivityHighlights,
      dailyDigestHour: dailyDigestHour ?? this.dailyDigestHour,
    );
  }

  @override
  List<Object?> get props => [
    pushEnabled,
    notifyRivalActivity,
    notifyStreakRisk,
    notifyDailyChallenges,
    notifyActivityHighlights,
    dailyDigestHour,
  ];
}

@immutable
class EngagementSnapshot extends Equatable {
  final int currentStreak;
  final int longestStreak;
  final int todayUnlocks;
  final int weeklyUnlocks;
  final double todayStatusXp;
  final List<ChallengeProgress> challenges;
  final NotificationPreferences notificationPreferences;

  const EngagementSnapshot({
    required this.currentStreak,
    required this.longestStreak,
    required this.todayUnlocks,
    required this.weeklyUnlocks,
    required this.todayStatusXp,
    required this.challenges,
    required this.notificationPreferences,
  });

  @override
  List<Object?> get props => [
    currentStreak,
    longestStreak,
    todayUnlocks,
    weeklyUnlocks,
    todayStatusXp,
    challenges,
    notificationPreferences,
  ];
}

@immutable
class PlayNextRecommendation extends Equatable {
  final String recommendationType;
  final int platformId;
  final String platformGameId;
  final String gameTitle;
  final double completionPercentage;
  final int remainingAchievements;
  final double remainingStatusXp;
  final double estimatedHours;
  final double xpPerHour;
  final String reason;

  const PlayNextRecommendation({
    required this.recommendationType,
    required this.platformId,
    required this.platformGameId,
    required this.gameTitle,
    required this.completionPercentage,
    required this.remainingAchievements,
    required this.remainingStatusXp,
    required this.estimatedHours,
    required this.xpPerHour,
    required this.reason,
  });

  String get platformLabel {
    if ([1, 2, 5, 9].contains(platformId)) return 'PSN';
    if ([10, 11, 12].contains(platformId)) return 'Xbox';
    if (platformId == 4) return 'Steam';
    return 'Platform $platformId';
  }

  @override
  List<Object?> get props => [
    recommendationType,
    platformId,
    platformGameId,
    gameTitle,
    completionPercentage,
    remainingAchievements,
    remainingStatusXp,
    estimatedHours,
    xpPerHour,
    reason,
  ];
}
