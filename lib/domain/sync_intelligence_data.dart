import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

@immutable
class SyncIntelligenceData extends Equatable {
  final List<PlatformSyncIntelligence> platforms;
  final List<MissingGameInsight> topMissingGames;
  final SyncRecommendation recommendation;

  const SyncIntelligenceData({
    required this.platforms,
    required this.topMissingGames,
    required this.recommendation,
  });

  int get totalMissingGapScore => platforms.fold<int>(
    0,
    (sum, platform) => sum + platform.estimatedGapScore,
  );

  int get totalMissingGapAchievements => platforms.fold<int>(
    0,
    (sum, platform) => sum + platform.estimatedGapAchievements,
  );

  @override
  List<Object?> get props => [platforms, topMissingGames, recommendation];
}

@immutable
class PlatformSyncIntelligence extends Equatable {
  final String platform;
  final bool linked;
  final String syncStatus;
  final DateTime? lastSyncAt;
  final DateTime? tokenExpiresAt;
  final String? lastError;
  final bool canSyncNow;
  final int waitSeconds;
  final String syncReason;
  final int estimatedGapScore;
  final int estimatedGapAchievements;

  const PlatformSyncIntelligence({
    required this.platform,
    required this.linked,
    required this.syncStatus,
    required this.lastSyncAt,
    required this.tokenExpiresAt,
    required this.lastError,
    required this.canSyncNow,
    required this.waitSeconds,
    required this.syncReason,
    required this.estimatedGapScore,
    required this.estimatedGapAchievements,
  });

  bool get tokenExpired {
    if (tokenExpiresAt == null) return false;
    return tokenExpiresAt!.isBefore(DateTime.now().toUtc());
  }

  bool get tokenNearExpiry {
    if (tokenExpiresAt == null) return false;
    return tokenExpiresAt!.isBefore(
      DateTime.now().toUtc().add(const Duration(hours: 24)),
    );
  }

  bool get staleSync {
    if (lastSyncAt == null) return true;
    return DateTime.now().toUtc().difference(lastSyncAt!).inHours >= 48;
  }

  String get displayName {
    switch (platform) {
      case 'psn':
        return 'PlayStation';
      case 'xbox':
        return 'Xbox';
      case 'steam':
        return 'Steam';
      default:
        return platform;
    }
  }

  @override
  List<Object?> get props => [
    platform,
    linked,
    syncStatus,
    lastSyncAt,
    tokenExpiresAt,
    lastError,
    canSyncNow,
    waitSeconds,
    syncReason,
    estimatedGapScore,
    estimatedGapAchievements,
  ];
}

@immutable
class MissingGameInsight extends Equatable {
  final String platform;
  final String platformGameId;
  final String gameTitle;
  final int apiEarnedCount;
  final int dbEarnedCount;
  final int estimatedMissingAchievements;
  final int estimatedMissingScore;

  const MissingGameInsight({
    required this.platform,
    required this.platformGameId,
    required this.gameTitle,
    required this.apiEarnedCount,
    required this.dbEarnedCount,
    required this.estimatedMissingAchievements,
    required this.estimatedMissingScore,
  });

  @override
  List<Object?> get props => [
    platform,
    platformGameId,
    gameTitle,
    apiEarnedCount,
    dbEarnedCount,
    estimatedMissingAchievements,
    estimatedMissingScore,
  ];
}

@immutable
class SyncRecommendation extends Equatable {
  final String platform;
  final bool canSyncNow;
  final String reason;
  final String actionLabel;
  final int waitSeconds;
  final int estimatedGapScore;
  final int estimatedGapAchievements;

  const SyncRecommendation({
    required this.platform,
    required this.canSyncNow,
    required this.reason,
    required this.actionLabel,
    required this.waitSeconds,
    required this.estimatedGapScore,
    required this.estimatedGapAchievements,
  });

  @override
  List<Object?> get props => [
    platform,
    canSyncNow,
    reason,
    actionLabel,
    waitSeconds,
    estimatedGapScore,
    estimatedGapAchievements,
  ];
}
