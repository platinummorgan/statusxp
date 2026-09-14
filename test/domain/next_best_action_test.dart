import 'package:flutter_test/flutter_test.dart';
import 'package:statusxp/domain/next_best_action.dart';
import 'package:statusxp/domain/unified_game.dart';

UnifiedGame game(String title, double completion) => UnifiedGame(
  title: title,
  platforms: const [],
  overallCompletion: completion,
);

void main() {
  test(
    'skips only affect games and preserve rewards and streak priorities',
    () {
      final candidate = game('First', 90);
      final skipped = {recommendationGameKey(candidate)};
      expect(
        chooseNextBestAction(
          games: [candidate],
          isPremium: false,
          skippedGameKeys: skipped,
        ).type,
        NextBestActionType.browse,
      );
      expect(
        chooseNextBestAction(
          games: [candidate],
          isPremium: false,
          skippedGameKeys: skipped,
          availableRewardXp: 25,
        ).type,
        NextBestActionType.claimReward,
      );
      expect(
        chooseNextBestAction(
          games: [candidate],
          isPremium: false,
          skippedGameKeys: skipped,
          currentStreak: 3,
        ).type,
        NextBestActionType.protectStreak,
      );
    },
  );

  final now = DateTime.utc(2026, 9, 13);
  UnifiedGame active(
    String title,
    double completion, {
    int? days,
    bool syncOnly = false,
  }) => UnifiedGame(
    title: title,
    overallCompletion: completion,
    platforms: [
      PlatformGameData(
        platform: 'steam',
        gameId: title,
        achievementsEarned: 1,
        achievementsTotal: 10,
        completion: completion,
        lastPlayedAt: now,
        lastTrophyEarnedAt: syncOnly || days == null
            ? null
            : now.subtract(Duration(days: days)),
      ),
    ],
  );

  test('recent earned progress can outrank an abandoned near-finish', () {
    final action = chooseNextBestAction(
      games: [game('Old', 95), active('Current', 70, days: 2)],
      isPremium: true,
      now: now,
    );
    expect(action.game?.title, 'Current');
    expect(action.title, 'Continue Current');
    expect(action.description, contains('last 7 days'));
  });

  test('sync-only and future dates do not manufacture recent progress', () {
    for (final candidate in [
      active('Synced', 70, syncOnly: true),
      active('Future', 70, days: -1),
    ]) {
      final action = chooseNextBestAction(
        games: [game('Old', 95), candidate],
        isPremium: true,
        now: now,
      );
      expect(action.game?.title, 'Old');
      expect(action.description, contains('closest unfinished'));
    }
  });

  test('activity bonus decays at seven and thirty days', () {
    String? selected(int age) => chooseNextBestAction(
      games: [
        game('Old', 90),
        active('Current', 70, days: age),
      ],
      isPremium: true,
      now: now,
    ).game?.title;
    expect(selected(6), 'Current');
    expect(selected(7), 'Old');
    final monthly = chooseNextBestAction(
      games: [game('Old', 80), active('Current', 70, days: 29)],
      isPremium: true,
      now: now,
    );
    expect(monthly.description, contains('last 30 days'));
    expect(
      chooseNextBestAction(
        games: [game('Old', 80), active('Current', 70, days: 30)],
        isPremium: true,
        now: now,
      ).game?.title,
      'Old',
    );
  });

  test('invalid completion is excluded and tied input order is stable', () {
    final candidates = [
      game('Broken', double.nan),
      game('Infinite', double.infinity),
      game('Zulu', 80),
      game('Alpha', 80),
    ];
    for (final ordered in [candidates, candidates.reversed.toList()]) {
      expect(
        chooseNextBestAction(
          games: ordered,
          isPremium: true,
          now: now,
        ).game?.title,
        'Alpha',
      );
    }
  });

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
