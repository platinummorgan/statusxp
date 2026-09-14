import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:statusxp/domain/engagement_hub_data.dart';
import 'package:statusxp/domain/unified_game.dart';
import 'package:statusxp/state/engagement_providers.dart';
import 'package:statusxp/state/recommendation_preferences.dart';
import 'package:statusxp/ui/widgets/desktop_engagement_section.dart';

const snapshot = EngagementSnapshot(
  currentStreak: 3,
  longestStreak: 5,
  todayUnlocks: 1,
  weeklyUnlocks: 8,
  todayStatusXp: 10,
  totalRewardXp: 20,
  weeklyRewardXp: 10,
  availableRewardXp: 25,
  challenges: [],
  notificationPreferences: NotificationPreferences(
    pushEnabled: false,
    notifyRivalActivity: false,
    notifyStreakRisk: false,
    notifyDailyChallenges: false,
    notifyActivityHighlights: false,
    dailyDigestHour: 19,
  ),
);
const games = AsyncData<List<UnifiedGame>>([
  UnifiedGame(title: 'Example', platforms: [], overallCompletion: 100),
]);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<void> showSection(
    WidgetTester tester,
    Future<EngagementSnapshot> Function() fetch, {
    String user = 'a',
    double width = 1240,
    AsyncValue<List<UnifiedGame>> library = games,
  }) async {
    tester.view.physicalSize = Size(width, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: SingleChildScrollView(
              child: DesktopEngagementSection(
                key: ValueKey(user),
                userId: user,
                games: library,
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/engagement-hub',
          builder: (_, _) =>
              const Scaffold(body: Text('Challenge destination')),
        ),
        GoRoute(
          path: '/weekly-recap',
          builder: (_, _) => const Scaffold(body: Text('Recap destination')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [engagementSnapshotProvider.overrideWith((ref) => fetch())],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'another suggestion advances, exhaustion offers reset at phone width',
    (tester) async {
      final noRewards = EngagementSnapshot(
        currentStreak: 0,
        longestStreak: 0,
        todayUnlocks: 0,
        weeklyUnlocks: 0,
        todayStatusXp: 0,
        totalRewardXp: 0,
        weeklyRewardXp: 0,
        availableRewardXp: 0,
        challenges: const [],
        notificationPreferences: snapshot.notificationPreferences,
      );
      await showSection(
        tester,
        () async => noRewards,
        width: 390,
        library: const AsyncData([
          UnifiedGame(title: 'First', platforms: [], overallCompletion: 90),
          UnifiedGame(title: 'Second', platforms: [], overallCompletion: 70),
        ]),
      );
      await tester.pumpAndSettle();
      expect(find.text('Continue First'), findsOneWidget);
      await tester.tap(find.text('Suggest another game'));
      await tester.pumpAndSettle();
      expect(find.text('Continue Second'), findsOneWidget);
      await tester.tap(find.text('Suggest another game'));
      await tester.pumpAndSettle();
      expect(find.text('Explore your next game'), findsOneWidget);
      expect(find.text('Suggest another game'), findsNothing);
      await tester.tap(find.text('Reset suggestions'));
      await tester.pumpAndSettle();
      expect(find.text('Continue First'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test('session choices are isolated by account', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(skippedRecommendationGamesProvider('a').notifier).state = {
      'game',
    };
    expect(container.read(skippedRecommendationGamesProvider('b')), isEmpty);
    expect(container.read(skippedRecommendationGamesProvider('a')), {'game'});
  });

  for (final width in [700.0, 1240.0]) {
    testWidgets('cards fit $width and rewards open challenges', (tester) async {
      await showSection(tester, () async => snapshot, width: width);
      await tester.pumpAndSettle();
      expect(find.text('25 StatusXP ready to claim'), findsOneWidget);
      expect(find.textContaining('8 unlocks'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Claim Reward'));
      await tester.pumpAndSettle();
      expect(find.text('Challenge destination'), findsOneWidget);
    });
  }

  testWidgets('loading does not invent progress; error can retry', (
    tester,
  ) async {
    final pending = Completer<EngagementSnapshot>();
    var calls = 0;
    await showSection(
      tester,
      () => ++calls == 1 ? pending.future : Future.value(snapshot),
    );
    expect(find.text('Your next session'), findsOneWidget);
    expect(find.textContaining('8 unlocks'), findsNothing);
    pending.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(find.text('Retry challenges'), findsOneWidget);
    await tester.tap(find.text('Retry challenges'));
    await tester.pumpAndSettle();
    expect(find.textContaining('8 unlocks'), findsOneWidget);
  });

  testWidgets('dismissal survives revisit and is scoped to account', (
    tester,
  ) async {
    await showSection(tester, () async => snapshot);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Hide until tomorrow'));
    await tester.pumpAndSettle();
    expect(find.text('Claim Reward'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await showSection(tester, () async => snapshot);
    await tester.pumpAndSettle();
    expect(find.text('Claim Reward'), findsNothing);
    expect(find.text('All challenges'), findsOneWidget);
    await tester.tap(find.text('Show recommendations'));
    await tester.pumpAndSettle();
    expect(find.text('Claim Reward'), findsOneWidget);
    expect(find.text('Show recommendations'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await showSection(tester, () async => snapshot);
    await tester.pumpAndSettle();
    expect(find.text('Claim Reward'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await showSection(tester, () async => snapshot, user: 'b');
    await tester.pumpAndSettle();
    expect(find.text('Claim Reward'), findsOneWidget);
    await tester.tap(find.text('Weekly recap'));
    await tester.pumpAndSettle();
    expect(find.text('Recap destination'), findsOneWidget);
  });
}
