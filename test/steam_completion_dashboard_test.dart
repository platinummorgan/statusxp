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
import 'package:statusxp/ui/widgets/steam_completion_award_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

SupabaseClient completionClient(dynamic Function(http.Request) respond) =>
    SupabaseClient(
      'https://test.invalid',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient(
        (r) async => http.Response(
          jsonEncode(respond(r)),
          200,
          headers: {'content-type': 'application/json'},
          request: r,
        ),
      ),
    );

void main() {
  for (final count in <int?>[null, 0, 42]) {
    test(
      'Steam count $count stays distinct from ordinary achievements and preserves coverage',
      () async {
        final client = completionClient(
          (r) => switch (r.url.path.split('/').last) {
            'calculate_statusxp_with_stacks' => <dynamic>[],
            'get_steam_completion_stats' => [
              {
                'completion_count': count,
                'pending_review_count': 12,
                'completions_synced': count != null,
              },
            ],
            'get_xbox_mythic_stats' => [
              {'mythic_count': 13, 'mythics_synced': true},
            ],
            'profiles' => {'psn_online_id': 'Player'},
            'leaderboard_cache' => {'total_statusxp': 100},
            'psn_leaderboard_cache' => {
              'platinum_count': 197,
              'total_games': 200,
            },
            'xbox_leaderboard_cache' => {'total_games': 20},
            'steam_leaderboard_cache' => {
              'achievement_count': 10000,
              'total_games': 100,
            },
            _ => throw StateError('Unexpected request ${r.url.path}'),
          },
        );
        addTearDown(client.dispose);
        final stats = await SupabaseDashboardRepository(
          client,
        ).getDashboardStats('owner');
        expect(stats.steamStats.completions, count);
        expect(stats.steamStats.achievementsUnlocked, 10000);
        expect(stats.totalCompletions, 210 + (count ?? 0));
        expect(stats.completionCountsPending, true);
        final restored = PlatformStats.fromJson(stats.steamStats.toJson());
        expect(restored.completions, count);
        expect(restored.pendingCompletionReviews, count == null ? 0 : 12);
      },
    );
  }
  test(
    'Steam boards request completion metrics instead of achievement counts',
    () async {
      final paths = <String>[];
      final client = completionClient((r) {
        paths.add(r.url.path.split('/').last);
        return [
          {
            'user_id': 'owner',
            'display_name': 'Player',
            'completion_count': 4,
            'achievement_count': 10000,
            'period_gain': 1,
            'total_games': 100,
          },
        ];
      });
      addTearDown(client.dispose);
      final repo = LeaderboardRepository(client);
      final board = await repo.getSteamLeaderboard();
      final seasonal = await repo.getSteamSeasonalLeaderboard(
        periodType: LeaderboardPeriodType.weekly,
      );
      expect(board.single.score, 4);
      expect(board.single.potentialScore, isNull);
      expect(seasonal.single.currentScore, 4);
      expect(seasonal.single.baselineScore, 3);
      expect(paths, [
        'get_steam_completion_leaderboard',
        'get_steam_completion_period_leaderboard',
      ]);
    },
  );
  testWidgets(
    'dashboard names Steam Completions, shows coverage and sums platform milestones',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardPlatformSummary(
              stats: const DashboardStats(
                displayName: 'Player',
                displayPlatform: 'steam',
                totalStatusXP: 0,
                psnStats: PlatformStats(
                  platinums: 197,
                  achievementsUnlocked: 1,
                  gamesCount: 1,
                ),
                xboxStats: PlatformStats(
                  mythics: 13,
                  achievementsUnlocked: 1,
                  gamesCount: 1,
                ),
                steamStats: PlatformStats(
                  completions: 42,
                  pendingCompletionReviews: 12,
                  achievementsUnlocked: 10000,
                  gamesCount: 100,
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
      expect(find.textContaining('Total Completions: 252'), findsOneWidget);
      expect(find.textContaining('Steam Completions 42'), findsOneWidget);
      expect(find.textContaining('12 AWAITING SYNC'), findsOneWidget);
      expect(find.textContaining('10000'), findsNothing);
    },
  );
  testWidgets(
    'earned Steam milestone has a Base Game 100% badge and estimated rarity',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SteamCompletionAwardCard(points: 11.66, estimatedRarity: 1),
          ),
        ),
      );
      expect(find.textContaining('Base Game 100%'), findsOneWidget);
      expect(find.textContaining('Estimated rarity: 1.00%'), findsOneWidget);
      expect(find.textContaining('1× rarity weighting'), findsOneWidget);
    },
  );
  testWidgets('fallback award identifies the full set and unavailable points', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SteamCompletionAwardCard(points: null, allAchievements: true),
        ),
      ),
    );
    expect(find.textContaining('All Achievements 100%'), findsOneWidget);
    expect(find.textContaining('StatusXP unavailable'), findsOneWidget);
    expect(find.textContaining('Estimated rarity unavailable'), findsOneWidget);
    expect(find.textContaining('Base Game 100%'), findsNothing);
  });
}
