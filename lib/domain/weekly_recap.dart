import 'package:equatable/equatable.dart';
import 'package:statusxp/domain/engagement_hub_data.dart';
import 'package:statusxp/domain/seasonal_user_breakdown.dart';
import 'package:statusxp/domain/trophy_room_data.dart';

class WeeklyRecap extends Equatable {
  const WeeklyRecap({
    required this.periodStart,
    required this.periodEnd,
    required this.statusXpGained,
    required this.unlocks,
    required this.gamesProgressed,
    required this.currentStreak,
    required this.longestStreak,
    required this.topGame,
    required this.rarestUnlock,
    required this.playNext,
  });

  final DateTime periodStart;
  final DateTime periodEnd;
  final int statusXpGained;
  final int unlocks;
  final int gamesProgressed;
  final int currentStreak;
  final int longestStreak;
  final SeasonalGameContribution? topGame;
  final UltraRareTrophy? rarestUnlock;
  final PlayNextRecommendation? playNext;

  @override
  List<Object?> get props => [
    periodStart,
    periodEnd,
    statusXpGained,
    unlocks,
    gamesProgressed,
    currentStreak,
    longestStreak,
    topGame,
    rarestUnlock,
    playNext,
  ];
}

WeeklyRecap buildWeeklyRecap({
  required SeasonalUserBreakdownData breakdown,
  required EngagementSnapshot engagement,
  required TrophyRoomData trophyRoom,
  required List<PlayNextRecommendation> recommendations,
}) {
  final contributions = [...breakdown.contributions]
    ..sort((a, b) => b.periodGain.compareTo(a.periodGain));
  final rareThisWeek =
      trophyRoom.ultraRareTrophies
          .where(
            (trophy) =>
                !trophy.earnedAt.isBefore(breakdown.periodStart) &&
                trophy.earnedAt.isBefore(breakdown.periodEnd),
          )
          .toList()
        ..sort((a, b) => a.rarity.compareTo(b.rarity));

  return WeeklyRecap(
    periodStart: breakdown.periodStart,
    periodEnd: breakdown.periodEnd,
    statusXpGained: breakdown.totalGain,
    unlocks: engagement.weeklyUnlocks,
    gamesProgressed: contributions.where((row) => row.periodGain > 0).length,
    currentStreak: engagement.currentStreak,
    longestStreak: engagement.longestStreak,
    topGame: contributions.isEmpty ? null : contributions.first,
    rarestUnlock: rareThisWeek.isEmpty ? null : rareThisWeek.first,
    playNext: recommendations.isEmpty ? null : recommendations.first,
  );
}
