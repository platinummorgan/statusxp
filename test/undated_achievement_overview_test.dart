import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:statusxp/domain/achievement_overview.dart';
import 'package:statusxp/domain/game_ref.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/ui/screens/achievement_overview_screen.dart';

void main() {
  const ref = AchievementRef(
    gameRef: GameRef(platformId: 10, platformGameId: 'game'),
    platformAchievementId: '1',
  );
  test('confirmed unlock does not require an invented date', () {
    const achievement = AchievementOverview(
      ref: ref,
      name: 'Offline unlock',
      gameName: 'Game',
      hasConfirmedUnlock: true,
    );
    expect(achievement.isEarned, isTrue);
    expect(achievement.earnedAt, isNull);
  });
  test('known date preserves previous earned behaviour', () {
    final achievement = AchievementOverview(
      ref: ref,
      name: 'Online unlock',
      gameName: 'Game',
      earnedAt: DateTime.utc(2025),
    );
    expect(achievement.isEarned, isTrue);
  });
  test('no confirmed record and no date means unearned', () {
    const achievement = AchievementOverview(
      ref: ref,
      name: 'Locked',
      gameName: 'Game',
    );
    expect(achievement.isEarned, isFalse);
  });
  testWidgets('confirmed undated unlock renders without a date or a crash', (
    tester,
  ) async {
    const achievement = AchievementOverview(
      ref: ref,
      name: 'Offline unlock',
      gameName: 'Game',
      hasConfirmedUnlock: true,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          achievementOverviewProvider(
            ref,
          ).overrideWith((_) async => achievement),
          compositeAchievementCommentsProvider(
            ref,
          ).overrideWith((_) async => []),
          currentUserIdProvider.overrideWith((_) => null),
        ],
        child: const MaterialApp(
          home: AchievementOverviewScreen(achievementRef: ref),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Earned — date unavailable'), findsOneWidget);
    expect(find.text('Not earned yet'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
