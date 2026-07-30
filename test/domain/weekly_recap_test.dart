import 'package:flutter_test/flutter_test.dart';
import 'package:statusxp/domain/engagement_hub_data.dart';
import 'package:statusxp/domain/seasonal_user_breakdown.dart';
import 'package:statusxp/domain/trophy_room_data.dart';
import 'package:statusxp/domain/weekly_recap.dart';

void main() {
  test('builds a weekly recap from progress, streak, and rarity data', () {
    final start = DateTime.utc(2026, 7, 27);
    final breakdown = SeasonalUserBreakdownData(
      periodStart: start,
      periodEnd: start.add(const Duration(days: 7)),
      contributions: const [
        SeasonalGameContribution(
          platformId: 1,
          platformGameId: 'game-1',
          gameName: 'First Game',
          coverUrl: null,
          periodGain: 120,
          earnedCount: 4,
        ),
        SeasonalGameContribution(
          platformId: 4,
          platformGameId: 'game-2',
          gameName: 'Top Game',
          coverUrl: null,
          periodGain: 340,
          earnedCount: 8,
        ),
      ],
    );
    const engagement = EngagementSnapshot(
      currentStreak: 5,
      longestStreak: 12,
      todayUnlocks: 2,
      weeklyUnlocks: 12,
      todayStatusXp: 50,
      totalRewardXp: 100,
      weeklyRewardXp: 25,
      availableRewardXp: 0,
      challenges: [],
      notificationPreferences: NotificationPreferences(
        pushEnabled: false,
        notifyRivalActivity: true,
        notifyStreakRisk: true,
        notifyDailyChallenges: true,
        notifyActivityHighlights: true,
        dailyDigestHour: 19,
      ),
    );
    final trophyRoom = TrophyRoomData(
      platinums: const [],
      recentTrophies: const [],
      ultraRareTrophies: [
        UltraRareTrophy(
          trophyId: 1,
          trophyName: 'This Week Rare',
          gameName: 'Top Game',
          tier: 'gold',
          rarity: 0.8,
          earnedAt: start.add(const Duration(days: 2)),
        ),
        UltraRareTrophy(
          trophyId: 2,
          trophyName: 'Old Rare',
          gameName: 'Old Game',
          tier: 'gold',
          rarity: 0.1,
          earnedAt: start.subtract(const Duration(days: 1)),
        ),
      ],
    );
    const recommendation = PlayNextRecommendation(
      recommendationType: 'closest',
      platformId: 4,
      platformGameId: 'game-3',
      gameTitle: 'Next Game',
      completionPercentage: 82,
      remainingAchievements: 3,
      remainingStatusXp: 100,
      estimatedHours: 2,
      xpPerHour: 50,
      reason: 'Almost complete',
    );

    final recap = buildWeeklyRecap(
      breakdown: breakdown,
      engagement: engagement,
      trophyRoom: trophyRoom,
      recommendations: const [recommendation],
    );

    expect(recap.statusXpGained, 460);
    expect(recap.unlocks, 12);
    expect(recap.gamesProgressed, 2);
    expect(recap.currentStreak, 5);
    expect(recap.topGame?.gameName, 'Top Game');
    expect(recap.rarestUnlock?.trophyName, 'This Week Rare');
    expect(recap.playNext?.gameTitle, 'Next Game');
  });
}
