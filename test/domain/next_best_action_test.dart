import 'package:flutter_test/flutter_test.dart';
import 'package:statusxp/domain/next_best_action.dart';
import 'package:statusxp/domain/unified_game.dart';

UnifiedGame game(String title, double completion) => UnifiedGame(
  title: title,
  platforms: const [],
  overallCompletion: completion,
);

void main() {
  test('empty library recommends connecting a platform', () {
    final action = chooseNextBestAction(games: const [], isPremium: false);
    expect(action.type, NextBestActionType.connectPlatform);
  });

  test('recommends the closest eligible game to completion', () {
    final action = chooseNextBestAction(
      games: [
        game('Early Game', 30),
        game('Almost Done', 92),
        game('Done', 100),
      ],
      isPremium: false,
    );
    expect(action.type, NextBestActionType.finishGame);
    expect(action.game?.title, 'Almost Done');
  });

  test('claimable challenge reward takes priority over game progress', () {
    final action = chooseNextBestAction(
      games: [game('Almost Done', 92)],
      isPremium: false,
      availableRewardXp: 250,
    );
    expect(action.type, NextBestActionType.claimReward);
    expect(action.title, contains('250'));
  });

  test('active streak without an unlock today prompts protection', () {
    final action = chooseNextBestAction(
      games: [game('Almost Done', 92)],
      isPremium: false,
      currentStreak: 5,
      todayUnlocks: 0,
    );
    expect(action.type, NextBestActionType.protectStreak);
  });

  test('completed daily activity does not show streak warning', () {
    final action = chooseNextBestAction(
      games: [game('Almost Done', 92)],
      isPremium: false,
      currentStreak: 5,
      todayUnlocks: 1,
    );
    expect(action.type, NextBestActionType.finishGame);
  });

  test('engaged free user receives a premium preview', () {
    final action = chooseNextBestAction(
      games: [game('Just Started', 5)],
      isPremium: false,
    );
    expect(action.type, NextBestActionType.previewPremium);
  });

  test('premium user without an active finish receives discovery action', () {
    final action = chooseNextBestAction(
      games: [game('Completed', 100)],
      isPremium: true,
    );
    expect(action.type, NextBestActionType.browse);
  });
}
