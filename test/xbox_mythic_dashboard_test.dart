import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:statusxp/data/repositories/leaderboard_repository.dart';
import 'package:statusxp/data/repositories/supabase_dashboard_repository.dart';
import 'package:statusxp/domain/dashboard_stats.dart';
import 'package:statusxp/domain/seasonal_leaderboard_entry.dart';
import 'package:statusxp/ui/widgets/dashboard_platform_summary.dart';
import 'package:statusxp/ui/widgets/xbox_mythic_award_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

SupabaseClient clientFor(dynamic Function(http.Request) respond) =>
    SupabaseClient(
      'https://test.invalid',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient(
        (request) async => http.Response(
          jsonEncode(respond(request)),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      ),
    );

void main() {
  testWidgets('Mythic award labels estimated rarity and unavailable rarity', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: XboxMythicAwardCard(points: 56.29, estimatedRarity: 1),
        ),
      ),
    );
    expect(find.textContaining('56.29 StatusXP'), findsOneWidget);
    expect(find.textContaining('Estimated rarity: 1.00%'), findsOneWidget);
    expect(find.textContaining('5× rarity weighting'), findsOneWidget);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: XboxMythicAwardCard(points: 0.5))),
    );
    expect(find.textContaining('Estimated rarity unavailable'), findsOneWidget);
  });
  for (final count in <int?>[null, 0, 13]) {
    test(
      'dashboard preserves Mythic count $count separately from Gamerscore',
      () async {
        final client = clientFor(
          (request) => switch (request.url.path.split('/').last) {
            'calculate_statusxp_with_stacks' => <dynamic>[],
            'get_xbox_mythic_stats' => [
              {'mythic_count': count, 'mythics_synced': count != null},
            ],
            'profiles' => {'xbox_gamertag': 'Player'},
            'leaderboard_cache' => {'total_statusxp': 123},
            'psn_leaderboard_cache' => {'total_games': 0},
            'steam_leaderboard_cache' => {'total_games': 0},
            'xbox_leaderboard_cache' => {
              'gamerscore': 1000000,
              'achievement_count': 50,
              'total_games': 20,
            },
            _ => throw StateError('Unexpected request ${request.url.path}'),
          },
        );
        addTearDown(client.dispose);
        final stats = await SupabaseDashboardRepository(
          client,
        ).getDashboardStats('owner');
        expect(stats.xboxStats.mythics, count);
        expect(stats.xboxStats.gamerscore, 1000000);
        expect(PlatformStats.fromJson(stats.xboxStats.toJson()).mythics, count);
      },
    );
  }
  test(
    'Xbox all-time and seasonal repositories use Mythic APIs and metrics',
    () async {
      final paths = <String>[];
      final client = clientFor((request) {
        paths.add(request.url.path.split('/').last);
        return [
          {
            'user_id': 'owner',
            'display_name': 'Player',
            'mythic_count': 7,
            'gamerscore': 1000000,
            'period_gain': 2,
            'total_games': 20,
            'achievement_count': 50,
          },
        ];
      });
      addTearDown(client.dispose);
      final repository = LeaderboardRepository(client);
      final entries = await repository.getXboxLeaderboard();
      final seasonal = await repository.getXboxSeasonalLeaderboard(
        periodType: LeaderboardPeriodType.weekly,
      );
      expect(entries.single.score, 7);
      expect(entries.single.mythicCount, 7);
      expect(entries.single.potentialScore, isNull);
      expect(seasonal.single.currentScore, 7);
      expect(seasonal.single.baselineScore, 5);
      expect(paths, [
        'get_xbox_mythic_leaderboard',
        'get_xbox_mythic_period_leaderboard',
      ]);
    },
  );
  testWidgets('dashboard shows the unknown state and then confirmed Mythics', (
    tester,
  ) async {
    for (final count in <int?>[null, 0, 13]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardPlatformSummary(
              stats: DashboardStats(
                displayName: 'Player',
                displayPlatform: 'xbox',
                totalStatusXP: 0,
                psnStats: const PlatformStats.empty(),
                steamStats: const PlatformStats.empty(),
                xboxStats: PlatformStats(
                  achievementsUnlocked: 50,
                  gamesCount: 20,
                  gamerscore: 1000000,
                  mythics: count,
                ),
              ),
              circleBuilder:
                  ({
                    required label,
                    required value,
                    required subtitle,
                    required bottomLabel,
                    required color,
                  }) => SizedBox(
                    width: 220,
                    child: Text('$label $value $bottomLabel'),
                  ),
            ),
          ),
        ),
      );
      expect(
        find.textContaining('Xbox Mythics ${count ?? '—'}'),
        findsOneWidget,
      );
      expect(find.textContaining('1000000'), findsNothing);
      if (count == null) {
        expect(find.textContaining('SYNC XBOX'), findsOneWidget);
      } else {
        expect(
          find.textContaining('Xbox Mythics $count 3 AVG/GAME'),
          findsOneWidget,
        );
      }
    }
  });
}
