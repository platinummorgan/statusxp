import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:statusxp/domain/dashboard_stats.dart';
import 'package:statusxp/domain/user_stats.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/ui/screens/first_sync_results_screen.dart';

void main() {
  testWidgets('celebrates a first sync with imported profile results', (
    tester,
  ) async {
    const dashboardStats = DashboardStats(
      displayName: 'Player One',
      displayPlatform: 'psn',
      totalStatusXP: 789.4,
      psnStats: PlatformStats(achievementsUnlocked: 120, gamesCount: 10),
      xboxStats: PlatformStats(achievementsUnlocked: 30, gamesCount: 4),
      steamStats: PlatformStats(achievementsUnlocked: 50, gamesCount: 6),
    );
    const userStats = UserStats(
      username: 'Player One',
      totalPlatinums: 1,
      totalGamesTracked: 20,
      totalTrophies: 200,
      bronzeTrophies: 100,
      silverTrophies: 60,
      goldTrophies: 39,
      platinumTrophies: 1,
      hardestPlatGame: 'Hard Game',
      rarestTrophyName: 'Impossible Victory',
      rarestTrophyRarity: 2.4,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardStatsProvider.overrideWith((ref) async => dashboardStats),
          userStatsProvider.overrideWith((ref) async => userStats),
        ],
        child: const MaterialApp(home: FirstSyncResultsScreen(platform: 'psn')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('YOUR GAMING STORY IS LIVE'), findsOneWidget);
    expect(
      find.text('PlayStation sync complete. Here is what StatusXP discovered.'),
      findsOneWidget,
    );
    expect(find.text('20'), findsOneWidget);
    expect(find.text('200'), findsOneWidget);
    expect(find.text('789'), findsOneWidget);
    expect(find.text('Impossible Victory'), findsOneWidget);
    expect(find.text('2.4% of players unlocked this'), findsOneWidget);
  });
}
