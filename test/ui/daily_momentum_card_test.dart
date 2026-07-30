import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:statusxp/domain/engagement_hub_data.dart';
import 'package:statusxp/ui/widgets/daily_momentum_card.dart';

void main() {
  const preferences = NotificationPreferences(
    pushEnabled: true,
    notifyRivalActivity: false,
    notifyStreakRisk: true,
    notifyDailyChallenges: true,
    notifyActivityHighlights: false,
    dailyDigestHour: 19,
  );

  testWidgets('prioritizes a claimable daily challenge', (tester) async {
    final snapshot = EngagementSnapshot(
      currentStreak: 3,
      longestStreak: 5,
      todayUnlocks: 1,
      weeklyUnlocks: 4,
      todayStatusXp: 12,
      totalRewardXp: 100,
      weeklyRewardXp: 20,
      availableRewardXp: 25,
      notificationPreferences: preferences,
      challenges: [
        ChallengeProgress(
          id: 'progress',
          title: 'Unlock two achievements',
          description: 'Keep moving',
          target: 2,
          progress: 1,
          rewardXp: 10,
          completed: false,
          claimed: false,
          claimedAt: null,
          periodType: 'daily',
          periodStart: DateTime(2026, 7, 30),
          readyToClaim: false,
        ),
        ChallengeProgress(
          id: 'ready',
          title: 'Daily finisher',
          description: 'Complete a daily objective',
          target: 1,
          progress: 1,
          rewardXp: 25,
          completed: true,
          claimed: false,
          claimedAt: null,
          periodType: 'daily',
          periodStart: DateTime(2026, 7, 30),
          readyToClaim: true,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DailyMomentumCard(snapshot: snapshot, onTap: () {}),
        ),
      ),
    );

    expect(find.text('+25 StatusXP ready to claim'), findsOneWidget);
    expect(find.text('CLAIM'), findsOneWidget);
  });
}
