import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:statusxp/domain/game_overview.dart';
import 'package:statusxp/domain/game_ref.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/ui/screens/game_overview_screen.dart';
import 'package:statusxp/ui/widgets/game_achievement_section.dart';
import 'package:statusxp/ui/widgets/game_completion_award.dart';

void main() {
  for (final policy in ['all_achievements', 'official_base_game', 'no_award']) {
    testWidgets('main game page shows earned $policy completion faithfully', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const game = GameRef(platformId: 4, platformGameId: '5037510');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWithValue('owner'),
            gameOverviewProvider(game).overrideWith(
              (_) async => const GameOverview(
                ref: game,
                name: 'Playrooms',
                isOwned: true,
                achievementsEarned: 30,
                achievementsTotal: 30,
                completionPercentage: 100,
              ),
            ),
            gameAchievementListProvider(game).overrideWith((_) async => []),
            gameCompletionAwardProvider(game).overrideWith(
              (_) async => policy == 'no_award'
                  ? null
                  : {
                      'base_status_xp': 9.31,
                      'estimated_rarity': 8.5,
                      'rarity_source': 'estimated_minimum_$policy',
                    },
            ),
          ],
          child: const MaterialApp(home: GameOverviewScreen(gameRef: game)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('YOUR PROGRESS'), findsOneWidget);
      if (policy == 'no_award') {
        expect(find.textContaining('100% ·'), findsNothing);
      } else {
        expect(
          find.textContaining(
            policy == 'all_achievements'
                ? 'All Achievements 100%'
                : 'Base Game 100%',
          ),
          findsOneWidget,
        );
        expect(find.textContaining('9.31 StatusXP'), findsOneWidget);
        expect(find.textContaining('1× rarity weighting'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
