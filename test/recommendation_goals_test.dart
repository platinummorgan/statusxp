import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:statusxp/domain/recommendation_goal.dart';
import 'package:statusxp/domain/next_best_action.dart';
import 'package:statusxp/domain/unified_game.dart';
import 'package:statusxp/state/recommendation_preferences.dart';
import 'package:statusxp/ui/widgets/recommendation_goal_controls.dart';

UnifiedGame fixture(
  String title, {
  bool platinum = false,
  int platform = 1,
  double completion = 90,
  DateTime? earned,
}) => UnifiedGame(
  title: title,
  overallCompletion: completion,
  platforms: [
    PlatformGameData(
      platform: platform == 1 ? 'ps5' : 'steam',
      platformId: platform,
      gameId: title,
      achievementsEarned: 9,
      achievementsTotal: 10,
      completion: completion,
      hasPlatinum: platinum,
      lastTrophyEarnedAt: earned,
    ),
  ],
);

void main() {
  const platinumGoals = RecommendationGoals(
    defaultGoal: RecommendationGoal.platinum,
  );
  test(
    'platinum skips earned trophies despite remaining DLC; overrides restore completion',
    () {
      final earned = fixture('Platinum earned', platinum: true, completion: 95);
      final pending = fixture('Still playing', completion: 40);
      expect(
        chooseNextBestAction(
          games: [earned, pending],
          isPremium: true,
          goals: platinumGoals,
        ).game,
        pending,
      );
      final goals = RecommendationGoals(
        defaultGoal: RecommendationGoal.platinum,
        games: {recommendationGameKey(earned): RecommendationGoal.completion},
      );
      expect(
        chooseNextBestAction(
          games: [earned, pending],
          isPremium: true,
          goals: goals,
        ).game,
        earned,
      );
    },
  );
  test(
    'platinum ranks by activity without claiming DLC percentage is platinum progress',
    () {
      final now = DateTime.utc(2026, 9, 14);
      final recent = fixture('Recent', completion: 10, earned: now);
      final action = chooseNextBestAction(
        games: [fixture('DLC heavy', completion: 99), recent],
        isPremium: true,
        goals: platinumGoals,
        now: now,
      );
      expect(action.game, recent);
      expect(action.description, contains('not verified'));
      expect(action.description, isNot(contains('10%')));
    },
  );
  test('Steam keeps completion recommendations with a platinum default', () {
    final action = chooseNextBestAction(
      games: [fixture('Steam game', platform: 4)],
      isPremium: true,
      goals: platinumGoals,
    );
    expect(action.title, 'Continue Steam game');
  });
  testWidgets(
    'default and per-game choices save and survive a reload per account',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final game = fixture('Example');
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: RecommendationGoalControls(
                userId: 'owner',
                games: [game],
                selectedGame: game,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Recommendation goals'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('100% including DLC').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Platinum (PlayStation)').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use account default'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('100% including DLC').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Example'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('None').last);
      await tester.pumpAndSettle();
      expect(find.text('This game’s goal'), findsNothing);
      expect(find.text('None'), findsOneWidget);
      await tester.tap(find.text('Save goals'));
      await tester.pumpAndSettle();
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(recommendationGoalsProvider('owner'));
      container.read(recommendationGoalsProvider('other'));
      await tester.pumpAndSettle();
      final saved = container
          .read(recommendationGoalsProvider('owner'))
          .requireValue;
      expect(saved.defaultGoal, RecommendationGoal.platinum);
      expect(
        saved.forGame(recommendationGameKey(game)),
        RecommendationGoal.completion,
      );
      expect(
        container
            .read(recommendationGoalsProvider('other'))
            .requireValue
            .defaultGoal,
        RecommendationGoal.completion,
      );
    },
  );
}
